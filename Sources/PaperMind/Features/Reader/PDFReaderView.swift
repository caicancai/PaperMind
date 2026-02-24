import SwiftUI
import PDFKit

struct PDFReaderView: NSViewRepresentable {
    let fileURL: URL
    let threadAnchors: [Note]
    let focusedThreadID: UUID?
    let focusThreadTick: Int
    var onSelectionChange: (String, Int, CGRect?, CGRect?) -> Void
    var onPageChange: (Int) -> Void
    var onThreadAnnotationTap: (UUID) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onSelectionChange: onSelectionChange,
            onPageChange: onPageChange,
            onThreadAnnotationTap: onThreadAnnotationTap
        )
    }

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displaysAsBook = false
        view.displayMode = .singlePageContinuous
        view.document = makeDocument(from: fileURL)

        context.coordinator.bind(to: view)
        context.coordinator.syncThreadAnnotations(view: view, threads: threadAnchors, focusedThreadID: focusedThreadID)
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        if nsView.document?.documentURL != fileURL {
            nsView.document = makeDocument(from: fileURL)
        }

        context.coordinator.syncThreadAnnotations(view: nsView, threads: threadAnchors, focusedThreadID: focusedThreadID)
        context.coordinator.navigateIfNeeded(
            view: nsView,
            focusThreadTick: focusThreadTick,
            focusedThreadID: focusedThreadID,
            threads: threadAnchors
        )
    }

    private func makeDocument(from url: URL) -> PDFDocument? {
        guard let data = try? Data(contentsOf: url) else {
            return PDFDocument(url: url)
        }
        return PDFDocument(data: data)
    }

    final class Coordinator: NSObject {
        private var observer: NSObjectProtocol?
        private var pageObserver: NSObjectProtocol?
        private var clickGesture: NSClickGestureRecognizer?
        private let onSelectionChange: (String, Int, CGRect?, CGRect?) -> Void
        private let onPageChange: (Int) -> Void
        private let onThreadAnnotationTap: (UUID) -> Void
        private var lastFocusThreadTick: Int = -1

        init(
            onSelectionChange: @escaping (String, Int, CGRect?, CGRect?) -> Void,
            onPageChange: @escaping (Int) -> Void,
            onThreadAnnotationTap: @escaping (UUID) -> Void
        ) {
            self.onSelectionChange = onSelectionChange
            self.onPageChange = onPageChange
            self.onThreadAnnotationTap = onThreadAnnotationTap
        }

        deinit {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
            if let pageObserver {
                NotificationCenter.default.removeObserver(pageObserver)
            }
        }

        func bind(to view: PDFView) {
            observer = NotificationCenter.default.addObserver(
                forName: Notification.Name.PDFViewSelectionChanged,
                object: view,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }

                guard let selection = view.currentSelection,
                      let text = selection.string,
                      let document = view.document,
                      let page = selection.pages.first else {
                    self.onSelectionChange("", 0, nil, nil)
                    return
                }

                let pageIndex = document.index(for: page)
                let boundsInPage = selection.bounds(for: page)
                let boundsInView = view.convert(boundsInPage, from: page)
                self.onSelectionChange(text, pageIndex, boundsInView, boundsInPage)
            }

            let gesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
            gesture.buttonMask = 0x1
            view.addGestureRecognizer(gesture)
            clickGesture = gesture

            pageObserver = NotificationCenter.default.addObserver(
                forName: Notification.Name.PDFViewPageChanged,
                object: view,
                queue: .main
            ) { [weak self] _ in
                guard let self,
                      let document = view.document,
                      let currentPage = view.currentPage else { return }
                self.onPageChange(document.index(for: currentPage))
            }
        }

        @objc
        private func handleClick(_ recognizer: NSClickGestureRecognizer) {
            guard let view = recognizer.view as? PDFView else { return }
            let pointInView = recognizer.location(in: view)

            guard let page = view.page(for: pointInView, nearest: true) else { return }
            let pointInPage = view.convert(pointInView, to: page)

            for annotation in page.annotations where annotation.fieldName?.hasPrefix("pm-thread-") == true {
                if annotation.bounds.contains(pointInPage),
                   let fieldName = annotation.fieldName,
                   let id = UUID(uuidString: fieldName.replacingOccurrences(of: "pm-thread-", with: "")) {
                    onThreadAnnotationTap(id)
                    break
                }
            }
        }

        func syncThreadAnnotations(view: PDFView, threads: [Note], focusedThreadID: UUID?) {
            guard let document = view.document else { return }

            for index in 0..<document.pageCount {
                guard let page = document.page(at: index) else { continue }
                let removable = page.annotations.filter { $0.fieldName?.hasPrefix("pm-thread-") == true }
                removable.forEach { page.removeAnnotation($0) }
            }

            for thread in threads {
                guard let pageIndex = thread.pageIndex,
                      let page = document.page(at: pageIndex),
                      let anchor = thread.anchorRect?.cgRect else {
                    continue
                }

                let annotation = PDFAnnotation(bounds: anchor, forType: .highlight, withProperties: nil)
                annotation.fieldName = "pm-thread-\(thread.id.uuidString)"

                if thread.id == focusedThreadID {
                    annotation.color = NSColor.systemBlue.withAlphaComponent(0.55)
                } else if thread.status == .resolved {
                    annotation.color = NSColor.systemGreen.withAlphaComponent(0.35)
                } else {
                    annotation.color = NSColor.systemOrange.withAlphaComponent(0.38)
                }

                page.addAnnotation(annotation)
            }
        }

        func navigateIfNeeded(view: PDFView, focusThreadTick: Int, focusedThreadID: UUID?, threads: [Note]) {
            guard focusThreadTick != lastFocusThreadTick else { return }
            lastFocusThreadTick = focusThreadTick

            guard let focusedThreadID,
                  let thread = threads.first(where: { $0.id == focusedThreadID }),
                  let pageIndex = thread.pageIndex,
                  let document = view.document,
                  let page = document.page(at: pageIndex) else {
                return
            }

            view.go(to: page)
        }
    }
}
