import SwiftUI
import AppKit

struct ChatPanelView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var draftInput: String = ""
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("论文对话")
                .font(.system(.headline, design: .rounded, weight: .semibold))

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if viewModel.chatMessages.isEmpty {
                        Text("你可以直接提问，或先选中一段内容再深入讨论。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(panelFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        ForEach(viewModel.chatMessages) { message in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: message.role == .assistant ? "sparkles" : "person.fill")
                                        .font(.caption)
                                        .foregroundStyle(message.role == .assistant ? .teal : .blue)
                                    Text(message.role == .assistant ? "Assistant" : "You")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                if message.role == .assistant {
                                    if viewModel.streamingAssistantMessageID == message.id {
                                        Text(message.content)
                                            .font(.system(.body, design: .serif))
                                            .textSelection(.enabled)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    } else {
                                        MarkdownContentView(markdown: message.content)
                                    }
                                } else {
                                    Text(message.content)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(10)
                            .background(
                                message.role == .assistant
                                ? panelFill
                                : (colorScheme == .dark
                                   ? Color(red: 0.19, green: 0.26, blue: 0.37)
                                   : Color(red: 0.88, green: 0.94, blue: 1.00))
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(.white.opacity(0.65), lineWidth: 1)
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
                        }
                    }
                }
            }
            .frame(minHeight: 260)
            .padding(10)
            .background(sectionFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text("输入问题")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                providerSelector

                ZStack(alignment: .topLeading) {
                    ChatInputTextView(
                        text: $draftInput,
                        onSubmit: sendCurrentInput
                    )
                        .frame(minHeight: 44, maxHeight: 92)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(inputFill)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.03), radius: 4, y: 1)

                    if draftInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("输入问题，`Enter` 发送，`Shift + Enter` 换行")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                }

                HStack {
                    Text(chatHintText)
                        .font(.caption2)
                        .foregroundStyle(chatHintColor)
                    Spacer()
                    Button {
                        sendCurrentInput()
                    } label: {
                        Label("发送", systemImage: "arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .tint(Color(red: 0.15, green: 0.43, blue: 0.88))
                    .disabled(
                        viewModel.chatState == .loading
                        || draftInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || !viewModel.isCurrentChatProviderUsable
                    )
                }
            }
            .padding(10)
            .background(sectionFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            statusView
        }
        .onAppear {
            draftInput = viewModel.chatInput
        }
        .onChange(of: viewModel.chatInput) { newValue in
            if draftInput != newValue {
                draftInput = newValue
            }
        }
    }

    private func sendCurrentInput() {
        guard viewModel.isCurrentChatProviderUsable else { return }
        let text = draftInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draftInput = ""
        Task { await viewModel.sendChatFromInput(text: text) }
    }

    @ViewBuilder
    private var statusView: some View {
        switch viewModel.chatState {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                Text("思考中...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(panelFill, in: Capsule())
        case .success:
            Text("回答完成")
                .font(.caption)
                .foregroundStyle(Color(red: 0.12, green: 0.55, blue: 0.30))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(panelFill, in: Capsule())
        case .failure(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(panelFill, in: Capsule())
        }
    }

    private var sectionFill: Color {
        colorScheme == .dark ? Color.black.opacity(0.24) : Color.white.opacity(0.56)
    }

    private var panelFill: Color {
        colorScheme == .dark ? Color.black.opacity(0.30) : Color.white.opacity(0.70)
    }

    private var inputFill: Color {
        colorScheme == .dark ? Color.black.opacity(0.34) : Color.white.opacity(0.82)
    }

    private var providerSelector: some View {
        HStack(spacing: 8) {
            Text("回答模型")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Picker("回答模型", selection: $viewModel.chatProviderOverride) {
                ForEach(viewModel.chatSelectableProviders) { provider in
                    Text(viewModel.chatProviderOptionTitle(provider))
                        .tag(provider)
                        .disabled(!viewModel.isChatProviderSelectable(provider))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            Spacer()
        }
    }

    private var chatHintText: String {
        viewModel.isCurrentChatProviderUsable
            ? "支持自由提问，也可结合当前选区讨论"
            : "当前模型未配置 API Key，请先到设置页配置"
    }

    private var chatHintColor: Color {
        viewModel.isCurrentChatProviderUsable ? .secondary : .orange
    }
}

private struct ChatInputTextView: NSViewRepresentable {
    @Binding var text: String
    var onSubmit: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.drawsBackground = false
        textView.font = preferredChatInputFont()
        textView.textContainerInset = NSSize(width: 6, height: 7)
        textView.string = text

        context.coordinator.textView = textView
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ChatInputTextView
        weak var textView: NSTextView?

        init(_ parent: ChatInputTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            parent.text = textView.string
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard commandSelector == #selector(NSResponder.insertNewline(_:)) else {
                return false
            }

            let flags = NSApp.currentEvent?.modifierFlags ?? []
            if flags.contains(.shift) {
                return false
            }

            if textView.hasMarkedText() {
                return false
            }

            let trimmed = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return true
            }

            parent.onSubmit()
            textView.window?.makeFirstResponder(textView)
            return true
        }
    }

    private func preferredChatInputFont() -> NSFont {
        let size: CGFloat = 13
        let base = NSFont.systemFont(ofSize: size, weight: .regular)
        if let descriptor = base.fontDescriptor.withDesign(.rounded) {
            return NSFont(descriptor: descriptor, size: size) ?? base
        }
        return base
    }
}

private struct MarkdownContentView: View {
    let markdown: String

    var body: some View {
        let normalized = normalizeMarkdown(markdown)
        if let attributed = try? AttributedString(
            markdown: normalized,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .full,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        ) {
            Text(attributed)
                .font(.system(.body, design: .serif))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(normalized)
                .font(.system(.body, design: .serif))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func normalizeMarkdown(_ raw: String) -> String {
        let t = raw.replacingOccurrences(of: "\r\n", with: "\n")
        let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.contains("\n"), trimmed.count > 220 else {
            return trimmed
        }

        // Only apply lightweight line breaking for very long single-line Chinese output.
        if trimmed.contains("。") || trimmed.contains("；") || trimmed.contains("！") || trimmed.contains("？") {
            return trimmed
                .replacingOccurrences(of: "。", with: "。\n")
                .replacingOccurrences(of: "；", with: "；\n")
                .replacingOccurrences(of: "！", with: "！\n")
                .replacingOccurrences(of: "？", with: "？\n")
                .replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        return trimmed
    }
}
