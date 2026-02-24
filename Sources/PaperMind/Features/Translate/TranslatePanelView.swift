import SwiftUI

struct TranslatePanelView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("划词翻译")
                .font(.headline)

            GroupBox("选中文本") {
                ScrollView {
                    Text(viewModel.selectedTextPreview.isEmpty ? "请在阅读区选择文本" : viewModel.selectedTextPreview)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(minHeight: 100)
            }

            Button("翻译为中文") {
                Task { await viewModel.translateSelection(target: "zh") }
            }
            .disabled(viewModel.currentSelection == nil || viewModel.translationState == .loading)

            statusView

            GroupBox("翻译结果") {
                ScrollView {
                    Text(viewModel.translationResult.isEmpty ? "暂无结果" : viewModel.translationResult)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(minHeight: 120)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch viewModel.translationState {
        case .idle:
            EmptyView()
        case .loading:
            HStack { ProgressView(); Text("翻译中...") }
        case .success:
            Text("翻译完成")
                .foregroundStyle(.green)
        case .failure(let message):
            Text(message)
                .foregroundStyle(.red)
        }
    }
}
