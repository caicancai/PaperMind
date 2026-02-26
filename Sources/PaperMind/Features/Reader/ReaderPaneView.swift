import SwiftUI

struct ReaderPaneView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selectionRect: CGRect?
    @State private var showFullTranslation: Bool = false

    var body: some View {
        VStack(spacing: 10) {
            if let paper = viewModel.selectedPaper {
                GeometryReader { proxy in
                    ZStack(alignment: .topLeading) {
                        PDFReaderView(
                            fileURL: paper.fileURL,
                            threadAnchors: [],
                            focusedThreadID: nil,
                            focusThreadTick: 0
                        ) { text, pageIndex, viewRect, pageRect in
                            selectionRect = viewRect
                            viewModel.handleSelectionChanged(text: text, pageIndex: pageIndex, anchorRect: pageRect)
                        } onPageChange: { pageIndex in
                            viewModel.currentReaderPageIndex = pageIndex
                        } onThreadAnnotationTap: { threadID in
                            _ = threadID
                        }

                        if viewModel.currentSelection != nil {
                            floatingTranslationCard
                                .frame(width: popupWidth)
                                .position(popupPosition(in: proxy.size, popupWidth: popupWidth, popupHeight: popupHeight))
                                .transition(.opacity)
                        }

                    }
                    .animation(.spring(response: 0.24, dampingFraction: 0.88), value: selectionRect)
                    .animation(.easeOut(duration: 0.18), value: viewModel.currentSelection != nil)
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 30))
                        .foregroundStyle(.secondary)
                    Text("请选择或导入论文")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(4)
        .onChange(of: viewModel.selectedTextPreview) { _ in
            showFullTranslation = false
        }
    }

    private var popupWidth: CGFloat {
        360
    }

    private var popupHeight: CGFloat {
        240
    }

    private var floatingTranslationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("翻译")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    viewModel.updateSelection(text: "", pageIndex: 0)
                    selectionRect = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                Text("目标语言")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Picker("目标语言", selection: Binding(
                    get: { viewModel.translationTargetLanguage },
                    set: { newValue in
                        Task { await viewModel.updateTranslationTargetLanguage(newValue) }
                    }
                )) {
                    Text("中文").tag("zh")
                    Text("English").tag("en")
                    Text("日本語").tag("ja")
                    Text("한국어").tag("ko")
                }
                .pickerStyle(.menu)
                .font(.caption)

                Spacer()
            }

            if !viewModel.selectedTextPreview.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.selectedTextPreview)
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundStyle(.secondary)
                    if viewModel.isMathSelection {
                        Text("检测到公式")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.14), in: Capsule())
                    }
                }
            }

            Group {
                switch viewModel.translationState {
                case .idle:
                    Text("正在准备翻译...")
                        .font(.callout)
                case .loading:
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("翻译中...")
                    }
                    .font(.callout)
                case .success:
                    translationResultView
                case .failure(let message):
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Button("重试翻译") {
                    Task { await viewModel.translateSelection() }
                }
                Button("Add Chat") {
                    viewModel.prepareChatDraftFromSelection()
                }
                Button("解释公式") {
                    Task { await viewModel.explainFormulaUsingSelection() }
                }
                .disabled(viewModel.currentSelection == nil)

                Spacer()
            }
            .font(.caption)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.gray.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    }

    @ViewBuilder
    private var translationResultView: some View {
        let paragraphs = normalizedTranslationParagraphs(viewModel.translationResult)
        let isLong = viewModel.translationResult.count > 280 || paragraphs.count > 3
        let visibleParagraphs = showFullTranslation ? paragraphs : Array(paragraphs.prefix(3))

        VStack(alignment: .leading, spacing: 6) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(visibleParagraphs.enumerated()), id: \.offset) { index, paragraph in
                            Text(paragraph)
                                .font(.callout)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.45), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .id(index)
                        }
                    }
                }
                .onChange(of: viewModel.translationResult) { _ in
                    guard let last = visibleParagraphs.indices.last else { return }
                    withAnimation(.easeOut(duration: 0.16)) {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
                .onChange(of: showFullTranslation) { _ in
                    guard let last = visibleParagraphs.indices.last else { return }
                    withAnimation(.easeOut(duration: 0.16)) {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
            .frame(maxHeight: showFullTranslation ? 180 : 120)

            if isLong {
                Button(showFullTranslation ? "收起" : "展开全文") {
                    showFullTranslation.toggle()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func normalizedTranslationParagraphs(_ text: String) -> [String] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let paragraphs = normalized
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return paragraphs.isEmpty ? [normalized] : paragraphs
    }

    private func popupPosition(in size: CGSize, popupWidth: CGFloat, popupHeight: CGFloat) -> CGPoint {
        guard let rect = selectionRect else {
            return CGPoint(x: size.width * 0.5, y: 140)
        }

        let horizontalPadding: CGFloat = 12
        let verticalPadding: CGFloat = 12
        let sideGap: CGFloat = 18
        let verticalGap: CGFloat = 12

        let minX = popupWidth * 0.5 + horizontalPadding
        let maxX = size.width - popupWidth * 0.5 - horizontalPadding
        let minY = popupHeight * 0.5 + verticalPadding
        let maxY = size.height - popupHeight * 0.5 - verticalPadding

        func clamp(_ point: CGPoint) -> CGPoint {
            CGPoint(
                x: min(max(point.x, minX), maxX),
                y: min(max(point.y, minY), maxY)
            )
        }

        func popupRect(center: CGPoint) -> CGRect {
            CGRect(
                x: center.x - popupWidth * 0.5,
                y: center.y - popupHeight * 0.5,
                width: popupWidth,
                height: popupHeight
            )
        }

        func overlapArea(_ a: CGRect, _ b: CGRect) -> CGFloat {
            let intersection = a.intersection(b)
            if intersection.isNull || intersection.isEmpty { return 0 }
            return intersection.width * intersection.height
        }

        let candidates: [CGPoint] = [
            CGPoint(x: rect.maxX + popupWidth * 0.5 + sideGap, y: rect.midY), // right
            CGPoint(x: rect.minX - popupWidth * 0.5 - sideGap, y: rect.midY), // left
            CGPoint(x: rect.midX, y: rect.minY - popupHeight * 0.5 - verticalGap), // top
            CGPoint(x: rect.midX, y: rect.maxY + popupHeight * 0.5 + verticalGap)  // bottom
        ]

        let scored = candidates.map { raw -> (CGPoint, CGFloat) in
            let point = clamp(raw)
            let area = overlapArea(popupRect(center: point), rect)
            return (point, area)
        }

        if let bestNonOverlapping = scored.first(where: { $0.1 <= 0.5 }) {
            return bestNonOverlapping.0
        }

        if let leastOverlap = scored.min(by: { $0.1 < $1.1 }) {
            return leastOverlap.0
        }

        return CGPoint(x: size.width * 0.5, y: 140)
    }
}
