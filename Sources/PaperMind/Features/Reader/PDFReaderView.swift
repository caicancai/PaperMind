import SwiftUI
import PDFKit

enum ReaderOutlineSource: String, Equatable {
    case embedded
    case inferred

    var displayTitle: String {
        switch self {
        case .embedded: return "内置目录"
        case .inferred: return "推断目录"
        }
    }
}

struct ReaderOutlineItem: Identifiable, Equatable {
    let id: String
    let title: String
    let pageIndex: Int
    let level: Int
    let source: ReaderOutlineSource
}

struct PDFReaderView: NSViewRepresentable {
    let fileURL: URL
    let threadAnchors: [Note]
    let focusedThreadID: UUID?
    let focusThreadTick: Int
    let jumpToPageIndex: Int?
    let jumpToPageTick: Int
    let jumpToOutlineItemID: String?
    let jumpToOutlineTick: Int
    var onSelectionChange: (String, Int, CGRect?, CGRect?) -> Void
    var onPageChange: (Int) -> Void
    var onThreadAnnotationTap: (UUID) -> Void
    var onOutlineChange: ([ReaderOutlineItem]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onSelectionChange: onSelectionChange,
            onPageChange: onPageChange,
            onThreadAnnotationTap: onThreadAnnotationTap,
            onOutlineChange: onOutlineChange
        )
    }

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displaysAsBook = false
        view.displayMode = .singlePageContinuous
        view.document = makeDocument(from: fileURL)

        context.coordinator.bind(to: view)
        context.coordinator.publishOutline(document: view.document)
        context.coordinator.syncThreadAnnotations(view: view, threads: threadAnchors, focusedThreadID: focusedThreadID)
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        let currentURL = nsView.document?.documentURL?.standardizedFileURL
        if currentURL != fileURL.standardizedFileURL {
            nsView.document = makeDocument(from: fileURL)
        }
        context.coordinator.publishOutline(document: nsView.document)

        context.coordinator.syncThreadAnnotations(view: nsView, threads: threadAnchors, focusedThreadID: focusedThreadID)
        context.coordinator.navigateIfNeeded(
            view: nsView,
            focusThreadTick: focusThreadTick,
            focusedThreadID: focusedThreadID,
            threads: threadAnchors
        )
        context.coordinator.navigateToPageIfNeeded(
            view: nsView,
            jumpToPageIndex: jumpToPageIndex,
            jumpToPageTick: jumpToPageTick,
            hasOutlineTarget: jumpToOutlineItemID != nil
        )
        context.coordinator.navigateToOutlineIfNeeded(
            view: nsView,
            jumpToOutlineItemID: jumpToOutlineItemID,
            jumpToOutlineTick: jumpToOutlineTick
        )
    }

    private func makeDocument(from url: URL) -> PDFDocument? {
        PDFDocument(url: url)
    }

    final class Coordinator: NSObject {
        private var observer: NSObjectProtocol?
        private var pageObserver: NSObjectProtocol?
        private var clickGesture: NSClickGestureRecognizer?
        private let onSelectionChange: (String, Int, CGRect?, CGRect?) -> Void
        private let onPageChange: (Int) -> Void
        private let onThreadAnnotationTap: (UUID) -> Void
        private let onOutlineChange: ([ReaderOutlineItem]) -> Void
        private var lastFocusThreadTick: Int = -1
        private var lastJumpToPageTick: Int = -1
        private var lastJumpToOutlineTick: Int = -1
        private var outlineDestinationByID: [String: PDFDestination] = [:]

        init(
            onSelectionChange: @escaping (String, Int, CGRect?, CGRect?) -> Void,
            onPageChange: @escaping (Int) -> Void,
            onThreadAnnotationTap: @escaping (UUID) -> Void,
            onOutlineChange: @escaping ([ReaderOutlineItem]) -> Void
        ) {
            self.onSelectionChange = onSelectionChange
            self.onPageChange = onPageChange
            self.onThreadAnnotationTap = onThreadAnnotationTap
            self.onOutlineChange = onOutlineChange
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
                    return
                }
            }

            // Clicking a non-annotation area should dismiss the floating selection tools.
            guard let document = view.document else { return }
            let pageIndex = view.currentPage.map { document.index(for: $0) } ?? 0
            view.clearSelection()
            onSelectionChange("", pageIndex, nil, nil)
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

        func navigateToPageIfNeeded(
            view: PDFView,
            jumpToPageIndex: Int?,
            jumpToPageTick: Int,
            hasOutlineTarget: Bool
        ) {
            guard jumpToPageTick != lastJumpToPageTick else { return }
            lastJumpToPageTick = jumpToPageTick
            guard !hasOutlineTarget else { return }

            guard let jumpToPageIndex,
                  let document = view.document,
                  let page = document.page(at: jumpToPageIndex) else {
                return
            }

            view.go(to: page)
        }

        func navigateToOutlineIfNeeded(view: PDFView, jumpToOutlineItemID: String?, jumpToOutlineTick: Int) {
            guard jumpToOutlineTick != lastJumpToOutlineTick else { return }
            lastJumpToOutlineTick = jumpToOutlineTick
            guard let jumpToOutlineItemID,
                  let destination = outlineDestinationByID[jumpToOutlineItemID] else {
                return
            }
            if let page = destination.page {
                let point = destination.point
                let pageBounds = page.bounds(for: .mediaBox)
                let targetPoint = CGPoint(
                    x: 0,
                    y: min(pageBounds.maxY - 24, max(0, point.y + 140))
                )
                let targetDestination = PDFDestination(page: page, at: targetPoint)
                view.go(to: targetDestination)
            } else {
                view.go(to: destination)
            }
        }

        func publishOutline(document: PDFDocument?) {
            let payload = outlinePayload(from: document)
            let items = payload.items
            outlineDestinationByID = payload.destinations
            onOutlineChange(items)

            // Some PDFs expose outline metadata slightly after initial load.
            if items.isEmpty, let document {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    guard let self else { return }
                    let retryPayload = self.outlinePayload(from: document)
                    self.outlineDestinationByID = retryPayload.destinations
                    self.onOutlineChange(retryPayload.items)
                }
            }
        }

        private func outlinePayload(from document: PDFDocument?) -> (items: [ReaderOutlineItem], destinations: [String: PDFDestination]) {
            guard let document else { return (items: [], destinations: [:]) }

            let embedded = embeddedOutlineItems(from: document)
            if !embedded.items.isEmpty {
                return embedded
            }
            let inferred = inferredOutlineItems(from: document)
            return (items: inferred, destinations: [:])
        }

        private func embeddedOutlineItems(from document: PDFDocument) -> (items: [ReaderOutlineItem], destinations: [String: PDFDestination]) {
            guard let root = document.outlineRoot else {
                return (items: [], destinations: [:])
            }

            var items: [ReaderOutlineItem] = []
            var destinations: [String: PDFDestination] = [:]

            func traverse(item: PDFOutline?, level: Int) {
                guard let item else { return }

                let title = (item.label ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty,
                   let destination = outlineDestination(for: item),
                   let page = destination.page,
                   document.index(for: page) >= 0 {
                    let pageIndex = document.index(for: page)
                    let id = makeEmbeddedOutlineID(
                        title: title,
                        level: level,
                        pageIndex: pageIndex,
                        point: destination.point
                    )
                    items.append(
                        ReaderOutlineItem(
                            id: id,
                            title: title,
                            pageIndex: pageIndex,
                            level: level,
                            source: .embedded
                        )
                    )
                    destinations[id] = destination
                }

                for childIndex in 0..<item.numberOfChildren {
                    traverse(item: item.child(at: childIndex), level: level + 1)
                }
            }

            for rootIndex in 0..<root.numberOfChildren {
                traverse(item: root.child(at: rootIndex), level: 0)
            }

            return (items: items, destinations: destinations)
        }

        private func makeEmbeddedOutlineID(
            title: String,
            level: Int,
            pageIndex: Int,
            point: CGPoint
        ) -> String {
            let normalizedTitle = title
                .lowercased()
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: #"[^a-z0-9\u4e00-\u9fa5 ]+"#, with: "", options: .regularExpression)
            return "embedded-\(pageIndex)-\(level)-\(Int(point.x.rounded()))-\(Int(point.y.rounded()))-\(normalizedTitle)"
        }

        private func inferredOutlineItems(from document: PDFDocument) -> [ReaderOutlineItem] {
            let numberedHeadingRegex = try! NSRegularExpression(
                pattern: #"^\s*(\d{1,2}(?:\.\d+){0,3})[\.\)]?\s+([^\n]{2,100})\s*$"#
            )
            let romanHeadingRegex = try! NSRegularExpression(
                pattern: #"^\s*([IVX]{1,8})[\.\)]\s+([^\n]{2,100})\s*$"#,
                options: [.caseInsensitive]
            )
            let englishSectionRegex = try! NSRegularExpression(
                pattern: #"^\s*(Abstract|Introduction|Background|Related Work|Method(?:ology)?|Approach|Experiments?|Results?|Discussion|Conclusion|Conclusions|References|Acknowledg(e)?ments?|Appendix(?:\s+[A-Z0-9])?)\s*[:.]?\s*$"#,
                options: [.caseInsensitive]
            )
            let chineseSectionRegex = try! NSRegularExpression(
                pattern: #"^\s*(摘要|引言|前言|背景|相关工作|方法|实验|结果|讨论|结论|参考文献|附录[A-Z0-9一二三四五六七八九十]*)\s*$"#
            )
            let tocLineRegex = try! NSRegularExpression(pattern: #"\.{3,}\s*\d+\s*$"#)
            var items: [ReaderOutlineItem] = []
            var seenTitles = Set<String>()

            for pageIndex in 0..<document.pageCount {
                guard let page = document.page(at: pageIndex),
                      let text = page.string else { continue }

                let lines = text
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty && $0.count <= 120 }

                for (lineIndex, line) in lines.enumerated() {
                    let normalized = line
                        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    guard normalized.count >= 2 else { continue }

                    let nsRange = NSRange(location: 0, length: normalized.utf16.count)
                    if tocLineRegex.firstMatch(in: normalized, options: [], range: nsRange) != nil {
                        continue
                    }

                    let isNumbered = numberedHeadingRegex.firstMatch(in: normalized, options: [.anchored], range: nsRange) != nil
                    let isRoman = romanHeadingRegex.firstMatch(in: normalized, options: [.anchored], range: nsRange) != nil
                    let isEnglishSection = englishSectionRegex.firstMatch(in: normalized, options: [.anchored], range: nsRange) != nil
                    let isChineseSection = chineseSectionRegex.firstMatch(in: normalized, options: [.anchored], range: nsRange) != nil

                    guard isNumbered || isRoman || isEnglishSection || isChineseSection else { continue }
                    guard inferredHeadingScore(
                        line: normalized,
                        lineIndex: lineIndex,
                        isNumbered: isNumbered || isRoman,
                        isNamedSection: isEnglishSection || isChineseSection
                    ) >= 3 else {
                        continue
                    }

                    let canonical = normalized
                        .lowercased()
                        .replacingOccurrences(of: #"[[:punct:]\s]+"#, with: "", options: .regularExpression)
                    guard !seenTitles.contains(canonical) else { continue }
                    seenTitles.insert(canonical)

                    let level = inferredLevel(from: normalized)
                    items.append(
                        ReaderOutlineItem(
                            id: "inferred-\(pageIndex)-\(items.count)",
                            title: normalized,
                            pageIndex: pageIndex,
                            level: level,
                            source: .inferred
                        )
                    )

                    if items.count >= 120 {
                        return items
                    }
                }
            }
            return compactInferredItems(items)
        }

        private func inferredLevel(from title: String) -> Int {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if let match = trimmed.range(of: #"^\d+(?:\.\d+){1,}"#, options: .regularExpression) {
                let prefix = String(trimmed[match])
                return max(0, prefix.split(separator: ".").count - 1)
            }
            return 0
        }

        private func inferredHeadingScore(
            line: String,
            lineIndex: Int,
            isNumbered: Bool,
            isNamedSection: Bool
        ) -> Int {
            var score = 0
            if lineIndex <= 20 { score += 3 }
            if lineIndex <= 40 { score += 1 }
            if isNumbered { score += 3 }
            if isNamedSection { score += 2 }
            if line.count <= 72 { score += 1 }
            if line.range(of: #"[=+\-*/<>]{2,}|[_]{2,}"#, options: .regularExpression) != nil { score -= 3 }
            if line.range(of: #"[。！？!?;；:]$"#, options: .regularExpression) != nil { score -= 2 }
            if line.range(of: #"[a-z]{4,}\s+[a-z]{4,}\s+[a-z]{4,}"#, options: .regularExpression) != nil { score -= 2 }
            return score
        }

        private func compactInferredItems(_ items: [ReaderOutlineItem]) -> [ReaderOutlineItem] {
            guard items.count > 2 else { return items }
            var compacted: [ReaderOutlineItem] = []
            var lastPageIndex: Int?
            for item in items {
                if let lastPageIndex, item.pageIndex == lastPageIndex, item.level > 1 {
                    continue
                }
                compacted.append(item)
                lastPageIndex = item.pageIndex
            }
            return compacted
        }

        private func outlineDestination(for item: PDFOutline) -> PDFDestination? {
            if let destination = item.destination {
                return destination
            }
            if let action = item.action as? PDFActionGoTo {
                return action.destination
            }
            return nil
        }
    }
}
