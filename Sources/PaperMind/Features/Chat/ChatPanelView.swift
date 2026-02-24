import SwiftUI

struct ChatPanelView: View {
    @ObservedObject var viewModel: AppViewModel
    @FocusState private var isInputFocused: Bool

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
                                if message.role == .assistant {
                                    MarkdownContentView(markdown: message.content)
                                } else {
                                    Text(message.content)
                                        .textSelection(.enabled)
                                }
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

            VStack(alignment: .leading, spacing: 8) {
                Text("输入问题")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $viewModel.chatInput)
                    .frame(minHeight: 72, maxHeight: 120)
                    .focused($isInputFocused)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.gray.opacity(0.35), lineWidth: 1)
                    )

                HStack {
                    Text("支持自由提问，也可结合当前选区讨论")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("发送") {
                        Task { await viewModel.sendChatFromInput() }
                    }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(viewModel.chatState == .loading)
                }
            }

            statusView

            Spacer()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isInputFocused = true
            }
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

private struct MarkdownContentView: View {
    let markdown: String

    var body: some View {
        if let attributed = try? AttributedString(
            markdown: markdown,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .full,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        ) {
            Text(attributed)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(markdown)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
