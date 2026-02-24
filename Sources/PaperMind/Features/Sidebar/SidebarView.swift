import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("AI 讨论")
                    .font(.headline)
                Spacer()
            }

            HStack {
                Text("思考模式")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("思考模式", selection: $viewModel.thinkingMode) {
                    ForEach(ThinkingMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
            }

            paperReadStatus

            if !viewModel.selectedTextPreview.isEmpty {
                GroupBox("当前选区") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(viewModel.selectedTextPreview)
                            .font(.caption)
                            .lineLimit(5)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack {
                            Button("解释选区") {
                                Task { await viewModel.askAIUsingSelection() }
                            }
                            .disabled(viewModel.currentSelection == nil)

                            Button("解释公式") {
                                Task { await viewModel.explainFormulaUsingSelection() }
                            }
                            .disabled(viewModel.currentSelection == nil)
                        }
                        .font(.caption)
                    }
                }
            }

            ChatPanelView(viewModel: viewModel)
        }
        .padding(10)
    }

    @ViewBuilder
    private var paperReadStatus: some View {
        switch viewModel.paperContextState {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("AI 正在阅读当前论文...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .success:
            Text("论文上下文已加载")
                .font(.caption)
                .foregroundStyle(.green)
        case .failure(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

}
