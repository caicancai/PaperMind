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

            if !viewModel.selectedTextPreview.isEmpty {
                GroupBox("当前选区") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(viewModel.selectedTextPreview)
                            .font(.caption)
                            .lineLimit(5)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack {
                            Button("解释选区") {
                                viewModel.chatMode = .explain
                                Task { await viewModel.askAIUsingSelection() }
                            }
                            .disabled(viewModel.currentSelection == nil)

                            Button("总结选区") {
                                viewModel.chatMode = .summarize
                                Task { await viewModel.askAIUsingSelection() }
                            }
                            .disabled(viewModel.currentSelection == nil)

                            if viewModel.isMathSelection {
                                Button("解释公式") {
                                    Task { await viewModel.explainFormulaUsingSelection() }
                                }
                                .disabled(viewModel.currentSelection == nil)
                            }
                        }
                        .font(.caption)
                    }
                }
            }

            ChatPanelView(viewModel: viewModel)
        }
        .padding(10)
    }
}
