import SwiftUI

struct ReaderPaneView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selectionRect: CGRect?
    @State private var showFullTranslation: Bool = false
    @State private var outlineItems: [ReaderOutlineItem] = []
    @State private var showOutlinePanel: Bool = true
    @State private var outlinePanelWidth: CGFloat = 220
    @State private var outlineDragStartWidth: CGFloat?
    @State private var outlineJumpItemID: String?
    @State private var outlineSelectedItemID: String?
    @State private var outlineJumpPageIndex: Int?
    @State private var outlineJumpTick: Int = 0

    var body: some View {
        VStack(spacing: 10) {
            if let paper = viewModel.selectedPaper {
                VStack(spacing: 8) {
                    readerHeader(paper: paper)

                    GeometryReader { proxy in
                        let clampedOutlineWidth = clampedOutlineWidth(for: proxy.size.width)
                        HStack(spacing: 8) {
                            if showOutlinePanel {
                                outlinePanel
                                    .frame(width: clampedOutlineWidth)

                                Rectangle()
                                    .fill(Color.primary.opacity(0.08))
                                    .frame(width: 4)
                                    .overlay(
                                        Capsule()
                                            .fill(Color.primary.opacity(0.22))
                                            .frame(width: 2, height: 42)
                                    )
                                    .contentShape(Rectangle())
                                    .gesture(
                                        DragGesture()
                                            .onChanged { value in
                                                let range = outlineWidthRange(totalWidth: proxy.size.width)
                                                let base = outlineDragStartWidth ?? outlinePanelWidth
                                                if outlineDragStartWidth == nil {
                                                    outlineDragStartWidth = outlinePanelWidth
                                                }
                                                let next = base + value.translation.width
                                                outlinePanelWidth = min(max(next, range.lowerBound), range.upperBound)
                                            }
                                            .onEnded { _ in
                                                outlineDragStartWidth = nil
                                            }
                                    )
                            }

                            ZStack(alignment: .topLeading) {
                                PDFReaderView(
                                    fileURL: paper.fileURL,
                                    threadAnchors: [],
                                    focusedThreadID: nil,
                                    focusThreadTick: 0,
                                    jumpToPageIndex: outlineJumpPageIndex,
                                    jumpToPageTick: outlineJumpTick,
                                    jumpToOutlineItemID: outlineJumpItemID,
                                    jumpToOutlineTick: outlineJumpTick
                                ) { text, pageIndex, viewRect, pageRect in
                                    selectionRect = viewRect
                                    viewModel.handleSelectionChanged(text: text, pageIndex: pageIndex, anchorRect: pageRect)
                                } onPageChange: { pageIndex in
                                    viewModel.currentReaderPageIndex = pageIndex
                                    if let selectedID = outlineSelectedItemID,
                                       let selectedItem = outlineItems.first(where: { $0.id == selectedID }),
                                       selectedItem.pageIndex != pageIndex {
                                        outlineSelectedItemID = nil
                                    }
                                } onThreadAnnotationTap: { threadID in
                                    _ = threadID
                                } onOutlineChange: { items in
                                    outlineItems = items
                                }

                                if viewModel.currentSelection != nil {
                                    floatingTranslationCard
                                        .frame(width: popupWidth)
                                        .position(popupPosition(in: proxy.size, popupWidth: popupWidth, popupHeight: popupHeight))
                                        .transition(.opacity)
                                }
                            }
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
        .onChange(of: viewModel.selectedPaperID) { _ in
            outlineItems = []
            showOutlinePanel = true
            outlinePanelWidth = 220
            outlineDragStartWidth = nil
            outlineJumpItemID = nil
            outlineSelectedItemID = nil
            outlineJumpPageIndex = nil
            outlineJumpTick = 0
        }
    }

    private var popupWidth: CGFloat {
        360
    }

    private var popupHeight: CGFloat {
        240
    }

    private func outlineWidthRange(totalWidth: CGFloat) -> ClosedRange<CGFloat> {
        let minWidth: CGFloat = totalWidth < 980 ? 170 : 190
        let maxWidth: CGFloat = min(340, max(minWidth + 20, totalWidth * 0.36))
        return minWidth...maxWidth
    }

    private func clampedOutlineWidth(for totalWidth: CGFloat) -> CGFloat {
        let range = outlineWidthRange(totalWidth: totalWidth)
        return min(max(outlinePanelWidth, range.lowerBound), range.upperBound)
    }

    private func readerHeader(paper: Paper) -> some View {
        HStack(spacing: 10) {
            Text(paper.title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Button {
                showOutlinePanel.toggle()
            } label: {
                Label(showOutlinePanel ? "隐藏目录" : "显示目录", systemImage: "sidebar.left")
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
    }

    private var outlinePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("目录")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                if let source = outlineItems.first?.source {
                    Text(source.displayTitle)
                        .font(.caption2)
                        .foregroundStyle(source == .embedded ? Color.secondary : Color.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            (source == .embedded ? Color.gray.opacity(0.16) : Color.orange.opacity(0.16)),
                            in: Capsule()
                        )
                }
                Spacer()
                Text("\(outlineItems.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if outlineItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("未检测到目录")
                        .font(.callout)
                    Text("这篇 PDF 可能没有嵌入目录书签，且未识别出稳定章节标题。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(outlineItems) { item in
                            Button {
                                outlineSelectedItemID = item.id
                                outlineJumpItemID = item.source == .embedded ? item.id : nil
                                outlineJumpPageIndex = item.pageIndex
                                outlineJumpTick += 1
                            } label: {
                                HStack(spacing: 8) {
                                    Text(item.title)
                                        .font(.system(size: 12, weight: activeOutlineItemID == item.id ? .semibold : .regular))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .foregroundStyle(.primary)

                                    Spacer(minLength: 4)

                                    Text("P\(item.pageIndex + 1)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.leading, CGFloat(item.level) * 12 + 8)
                                .padding(.trailing, 8)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(activeOutlineItemID == item.id ? Color.accentColor.opacity(0.14) : .clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var activeOutlineItemID: String? {
        if let selectedID = outlineSelectedItemID,
           outlineItems.contains(where: { $0.id == selectedID }) {
            return selectedID
        }
        return outlineItems
            .filter { $0.pageIndex <= viewModel.currentReaderPageIndex }
            .last?
            .id
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

                Picker("", selection: Binding(
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
                .labelsHidden()
                .accessibilityLabel("目标语言")
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
        let normalized = normalizedTranslationText(viewModel.translationResult)
        let isLong = normalized.count > 280
        let displayedText = showFullTranslation ? normalized : String(normalized.prefix(280))

        VStack(alignment: .leading, spacing: 6) {
            ScrollView {
                Text(isLong && !showFullTranslation ? "\(displayedText)..." : displayedText)
                    .font(.callout)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.45), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
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

    private func normalizedTranslationText(_ text: String) -> String {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let paragraphs = normalized
            .components(separatedBy: "\n\n")
            .map { paragraph in
                paragraph
                    .components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
            }
            .filter { !$0.isEmpty }
        return paragraphs.joined(separator: "\n\n")
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
