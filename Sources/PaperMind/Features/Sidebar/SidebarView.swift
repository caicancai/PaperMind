import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("AI 讨论", systemImage: "bubble.left.and.bubble.right.fill")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
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
                    .frame(width: 190)
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.64), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            paperReadStatus

            if !viewModel.selectedTextPreview.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("当前选区")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(viewModel.selectedTextPreview)
                        .font(.callout)
                        .lineLimit(5)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack {
                        Button("带选区提问") {
                            Task { await viewModel.askAIUsingSelection() }
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.currentSelection == nil)

                        Button("解释公式") {
                            Task { await viewModel.explainFormulaUsingSelection() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.13, green: 0.49, blue: 0.73))
                        .disabled(viewModel.currentSelection == nil)
                    }
                    .font(.caption)
                }
                .padding(12)
                .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            ChatPanelView(viewModel: viewModel)
        }
        .padding(8)
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
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.55), in: Capsule())
        case .success:
            Text("论文上下文已加载")
                .font(.caption2)
                .foregroundStyle(Color(red: 0.12, green: 0.55, blue: 0.30))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.55), in: Capsule())
        case .failure(let message):
            Text(message)
                .font(.caption2)
                .foregroundStyle(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.55), in: Capsule())
        }
    }

}
