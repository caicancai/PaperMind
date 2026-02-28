import SwiftUI
import AppKit

struct ChatPanelView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var draftInput: String = ""
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerBar
            chatTimeline
            composerPanel
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

    private var headerBar: some View {
        HStack(spacing: 6) {
            Label("论文对话", systemImage: "bubble.left.and.bubble.right.fill")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
            Spacer()
            providerBadge
            chatStateBadge
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(sectionFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var chatTimeline: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if viewModel.chatMessages.isEmpty {
                        Text("你可以直接提问，或先选中一段内容再深入讨论。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(panelFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        ForEach(viewModel.chatMessages) { message in
                            messageRow(for: message)
                                .id(message.id)
                        }
                    }
                }
                .padding(8)
            }
            .frame(minHeight: 260)
            .background(sectionFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onChange(of: viewModel.chatMessages.count) { _ in
                scrollToLatestMessage(proxy: proxy)
            }
            .onChange(of: viewModel.streamingAssistantMessageID) { _ in
                scrollToLatestMessage(proxy: proxy, animated: false)
            }
            .onChange(of: latestMessageScrollToken) { _ in
                scrollToLatestMessage(proxy: proxy, animated: false)
            }
        }
    }

    private func messageRow(for message: ChatMessage) -> some View {
        let isUser = message.role == .user
        return HStack(alignment: .bottom, spacing: 6) {
            if !isUser {
                bubbleAvatar(isUser: false)
            }
            if isUser {
                Spacer(minLength: 20)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(isUser ? "You" : "PaperMind")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(formatMessageTime(message.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if !isUser && viewModel.streamingAssistantMessageID == message.id {
                    Text(message.content)
                        .font(.system(size: 13.5, weight: .regular, design: .default))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if isUser {
                    Text(message.content)
                        .font(.system(size: 13.5, weight: .regular, design: .default))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    MarkdownContentView(markdown: message.content)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: 300, alignment: .leading)
            .background(isUser ? userBubbleFill : assistantBubbleFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(bubbleStroke(isUser: isUser), lineWidth: 1)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.12 : 0.04), radius: 2, y: 1)

            if !isUser {
                Spacer(minLength: 20)
            }
            if isUser {
                bubbleAvatar(isUser: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var composerPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            providerSelector
            if let pinned = viewModel.pinnedChatSelectionSummary {
                HStack(spacing: 8) {
                    Label(pinned, systemImage: "paperclip")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        viewModel.clearPinnedChatSelection()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(panelFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            ZStack(alignment: .topLeading) {
                ChatInputTextView(
                    text: $draftInput,
                    onSubmit: sendCurrentInput
                )
                .frame(minHeight: 42, maxHeight: 88)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(inputFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.black.opacity(colorScheme == .dark ? 0.20 : 0.08), lineWidth: 1)
                )

                if draftInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("输入问题，`Enter` 发送，`Shift + Enter` 换行")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
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
                .tint(Color(red: 0.17, green: 0.41, blue: 0.89))
                .disabled(
                    viewModel.chatState == .loading
                    || draftInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || !viewModel.isCurrentChatProviderUsable
                )
            }
        }
        .padding(8)
        .background(sectionFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func bubbleAvatar(isUser: Bool) -> some View {
        Image(systemName: isUser ? "person.fill" : "sparkles")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(isUser ? Color.white.opacity(0.9) : Color.white.opacity(0.86))
            .frame(width: 18, height: 18)
            .background(
                Circle()
                    .fill(isUser ? Color(red: 0.23, green: 0.47, blue: 0.88) : Color(red: 0.18, green: 0.47, blue: 0.49))
            )
    }

    private var chatStateBadge: some View {
        Group {
            switch viewModel.chatState {
            case .idle:
                badge(title: "空闲", symbol: "checkmark.circle", tint: .secondary)
            case .loading:
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.65)
                    Text("思考中")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(panelFill, in: Capsule())
            case .success:
                badge(title: "已完成", symbol: "checkmark.circle.fill", tint: Color(red: 0.14, green: 0.57, blue: 0.34))
            case .failure:
                badge(title: "失败", symbol: "exclamationmark.triangle.fill", tint: .orange)
            }
        }
    }

    private var providerBadge: some View {
        badge(
            title: viewModel.chatProviderOptionTitle(viewModel.chatProviderOverride),
            symbol: "cpu",
            tint: .secondary
        )
    }

    private func badge(title: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.caption2)
            Text(title)
                .font(.caption2)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(panelFill, in: Capsule())
    }

    private func scrollToLatestMessage(proxy: ScrollViewProxy, animated: Bool = true) {
        guard let latest = viewModel.chatMessages.last else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.16)) {
                proxy.scrollTo(latest.id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(latest.id, anchor: .bottom)
        }
    }

    private func formatMessageTime(_ date: Date) -> String {
        messageTimeFormatter.string(from: date)
    }

    private var latestMessageScrollToken: String {
        guard let latest = viewModel.chatMessages.last else { return "empty" }
        return "\(latest.id.uuidString)-\(latest.content.count)"
    }

    private var sectionFill: Color {
        colorScheme == .dark ? Color.black.opacity(0.22) : Color.white.opacity(0.54)
    }

    private var panelFill: Color {
        colorScheme == .dark ? Color.black.opacity(0.28) : Color.white.opacity(0.68)
    }

    private var assistantBubbleFill: Color {
        colorScheme == .dark ? Color(red: 0.13, green: 0.16, blue: 0.19) : Color(red: 0.96, green: 0.97, blue: 0.99)
    }

    private var userBubbleFill: Color {
        colorScheme == .dark ? Color(red: 0.18, green: 0.29, blue: 0.44) : Color(red: 0.86, green: 0.91, blue: 0.98)
    }

    private func bubbleStroke(isUser: Bool) -> Color {
        if isUser {
            return colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.70)
        }
        return colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
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

    private var messageTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
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
                .font(.system(size: 13.5, weight: .regular, design: .default))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(normalized)
                .font(.system(size: 13.5, weight: .regular, design: .default))
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
