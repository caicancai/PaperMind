import SwiftUI

struct ReaderPaneView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectionRect: CGRect?
    @State private var showFullTranslation: Bool = false
    @State private var showTranslationDetails: Bool = false
    @State private var outlineItems: [ReaderOutlineItem] = []
    @State private var showOutlinePanel: Bool = true
    @State private var outlinePanelWidth: CGFloat = 220
    @State private var outlineDragStartWidth: CGFloat?
    @State private var outlineJumpItemID: String?
    @State private var outlineSelectedItemID: String?
    @State private var outlineJumpPageIndex: Int?
    @State private var outlineJumpTick: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            if let paper = viewModel.selectedPaper {
                VStack(spacing: 0) {
                    readerHeader(paper: paper)
                    Divider()

                    GeometryReader { proxy in
                        let clampedOutlineWidth = clampedOutlineWidth(for: proxy.size.width)
                        HStack(spacing: 0) {
                            if showOutlinePanel {
                                outlinePanel
                                    .frame(width: clampedOutlineWidth)

                                Divider()
                                    .frame(width: 5)
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

                            GeometryReader { readerProxy in
                                let popoverWidth = selectionPopoverWidth(for: readerProxy.size.width)
                                let popoverHeight = selectionPopoverHeight

                                ZStack(alignment: .topLeading) {
                                    PDFReaderView(
                                        fileURL: paper.fileURL,
                                        threadAnchors: viewModel.notes,
                                        focusedThreadID: viewModel.focusedThreadID,
                                        focusThreadTick: viewModel.focusThreadTick,
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
                                        viewModel.handleThreadAnnotationTapped(threadID)
                                    } onOutlineChange: { items in
                                        outlineItems = items
                                    }

                                    if viewModel.currentSelection != nil {
                                        selectionPopover
                                            .frame(width: popoverWidth)
                                            .position(
                                                popupPosition(
                                                    in: readerProxy.size,
                                                    popupWidth: popoverWidth,
                                                    popupHeight: popoverHeight
                                                )
                                            )
                                            .transition(.opacity)
                                    }
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
        .background(PaperTheme.canvas(for: colorScheme))
        .onChange(of: viewModel.selectedTextPreview) { _ in
            showFullTranslation = false
            showTranslationDetails = false
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

    private func selectionPopoverWidth(for availableWidth: CGFloat) -> CGFloat {
        min(440, max(320, availableWidth - 28))
    }

    private var selectionPopoverHeight: CGFloat {
        showTranslationDetails ? 258 : 42
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
        HStack(spacing: 8) {
            Button {
                showOutlinePanel.toggle()
            } label: {
                Label("目录", systemImage: "list.bullet.indent")
            }
            .buttonStyle(.borderless)

            Spacer()

            Text("第 \(viewModel.currentReaderPageIndex + 1) 页")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !viewModel.notes.isEmpty {
                Label("\(viewModel.notes.count)", systemImage: "highlighter")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .paperSurface()
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
                                        .fill(activeOutlineItemID == item.id ? PaperTheme.selection(for: colorScheme) : .clear)
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
        .paperSurface()
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

    private var selectionPopover: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                selectionAction("翻译", systemImage: "character.book.closed") {
                    withAnimation(.easeOut(duration: 0.14)) {
                        showTranslationDetails.toggle()
                    }
                }

                selectionAction("Add Chat", systemImage: "bubble.left.and.bubble.right") {
                    viewModel.prepareChatDraftFromSelection()
                }

                selectionAction("笔记", systemImage: "note.text.badge.plus") {
                    Task { await viewModel.createNoteFromCurrentSelection() }
                }

                if viewModel.isMathSelection {
                    selectionAction("公式", systemImage: "function") {
                        viewModel.submitFormulaExplanation()
                    }
                }

                Spacer(minLength: 4)

                Button {
                    viewModel.updateSelection(text: "", pageIndex: 0)
                    selectionRect = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 7)
            .frame(height: 42)

            if showTranslationDetails {
                Divider()
                translationPanel
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            PaperTheme.raisedSheet(for: colorScheme),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(PaperTheme.rule(for: colorScheme).opacity(0.7), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
    }

    private func selectionAction(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11.5, weight: .medium))
                .padding(.horizontal, 7)
                .frame(height: 28)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private var translationPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("翻译")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
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
                .controlSize(.small)
            }

            Group {
                switch viewModel.translationState {
                case .idle:
                    Text("准备翻译…")
                        .foregroundStyle(.secondary)
                case .loading:
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("翻译中…")
                            .foregroundStyle(.secondary)
                    }
                case .success:
                    translationResultView
                case .failure(let message):
                    VStack(alignment: .leading, spacing: 6) {
                        Text(message)
                            .foregroundStyle(.red)
                        Button("重试") {
                            Task { await viewModel.translateSelection() }
                        }
                    }
                }
            }
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .frame(height: 215, alignment: .top)
    }

    @ViewBuilder
    private var translationResultView: some View {
        let displayText = displayTranslationText(viewModel.translationResult)
        let isLong = displayText.count > 280
        let displayedText = showFullTranslation ? displayText : String(displayText.prefix(280))

        VStack(alignment: .leading, spacing: 6) {
            ScrollView {
                Text(isLong && !showFullTranslation ? "\(displayedText)..." : displayedText)
                    .font(.callout)
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: showFullTranslation ? 160 : 130)

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

    private func displayTranslationText(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return normalized }

        // Treat blank lines with spaces as paragraph separators and keep original paragraph layout.
        let normalizedParagraphBreaks = normalized.replacingOccurrences(
            of: #"\n[ \t]*\n+"#,
            with: "\n\n",
            options: .regularExpression
        )

        // Prevent excessive blank lines.
        return normalizedParagraphBreaks.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )
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
