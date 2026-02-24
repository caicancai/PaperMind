import SwiftUI

struct ChatPanelView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("论文对话")
                    .font(.headline)

                Spacer()

                Picker("模式", selection: $viewModel.chatMode) {
                    ForEach(ChatMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }

            GroupBox("消息") {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.chatMessages) { message in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(message.role.rawValue.uppercased())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(message.content)
                                    .textSelection(.enabled)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(message.role == .user ? .blue.opacity(0.1) : .gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
                }
                .frame(minHeight: 260)
            }

            HStack {
                TextField("输入你的问题...", text: $viewModel.chatInput)
                    .textFieldStyle(.roundedBorder)

                Button("发送") {
                    Task { await viewModel.sendChatFromInput() }
                }
                .disabled(viewModel.chatState == .loading)
            }

            statusView

            Spacer()
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch viewModel.chatState {
        case .idle:
            EmptyView()
        case .loading:
            HStack { ProgressView(); Text("思考中...") }
        case .success:
            Text("回答完成")
                .foregroundStyle(.green)
        case .failure(let message):
            Text(message)
                .foregroundStyle(.red)
        }
    }
}
