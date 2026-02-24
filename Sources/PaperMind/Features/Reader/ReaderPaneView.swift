import SwiftUI

struct ReaderPaneView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selectionRect: CGRect?

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
                                .transition(.opacity.combined(with: .scale))
                        }

                    }
                    .animation(.spring(response: 0.24, dampingFraction: 0.88), value: selectionRect)
                    .animation(.easeOut(duration: 0.18), value: viewModel.currentSelection != nil)
                    .animation(.easeOut(duration: 0.18), value: viewModel.translationState)
                    .animation(.easeOut(duration: 0.18), value: viewModel.translationResult)
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
    }

    private var popupWidth: CGFloat {
        let selectionCount = viewModel.selectedTextPreview.count
        let translationCount = viewModel.translationResult.count
        let basis = max(selectionCount, translationCount)
        let width = 280 + CGFloat(min(max(basis, 0), 220)) * 0.8
        return min(max(width, 280), 460)
    }

    private var popupHeight: CGFloat {
        var height: CGFloat = 148
        if viewModel.translationState == .loading { height += 12 }
        if !viewModel.selectedTextPreview.isEmpty { height += 14 }
        height += CGFloat(min(viewModel.translationResult.count, 280)) * 0.22
        return min(max(height, 150), 300)
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
                    Text(viewModel.translationResult)
                        .font(.callout)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
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
                Button("问 AI") {
                    Task { await viewModel.askAIUsingSelection() }
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

    private func popupPosition(in size: CGSize, popupWidth: CGFloat, popupHeight: CGFloat) -> CGPoint {
        guard let rect = selectionRect else {
            return CGPoint(x: size.width * 0.5, y: 140)
        }

        let horizontalPadding: CGFloat = 12
        let verticalPadding: CGFloat = 12
        let sideGap: CGFloat = 16

        let minX = popupWidth * 0.5 + horizontalPadding
        let maxX = size.width - popupWidth * 0.5 - horizontalPadding
        let minY = popupHeight * 0.5 + verticalPadding
        let maxY = size.height - popupHeight * 0.5 - verticalPadding

        // Prefer placing the popup on the side of selection to avoid blocking the selected paragraph.
        let rightX = rect.maxX + popupWidth * 0.5 + sideGap
        if rightX <= maxX {
            let y = min(max(rect.midY, minY), maxY)
            return CGPoint(x: rightX, y: y)
        }

        let leftX = rect.minX - popupWidth * 0.5 - sideGap
        if leftX >= minX {
            let y = min(max(rect.midY, minY), maxY)
            return CGPoint(x: leftX, y: y)
        }

        // Fallback to above/below when horizontal space is not enough.
        let centerX = min(max(rect.midX, minX), maxX)
        let topY = rect.minY - popupHeight * 0.5 - 10
        if topY >= minY {
            return CGPoint(x: centerX, y: topY)
        }

        let bottomY = rect.maxY + popupHeight * 0.5 + 10
        return CGPoint(x: centerX, y: min(max(bottomY, minY), maxY))
    }
}
