import SwiftUI
import AppKit

struct ChatPanelView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var draftInput = ""
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            conversationHeader
            Divider()
            chatTimeline
            errorBanner
            composer
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

    private var conversationHeader: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text("论文对话")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(viewModel.selectedPaper == nil ? "未选择论文" : "基于当前论文")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.startNewChat()
                draftInput = ""
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .buttonStyle(.borderless)
            .help("新对话")
        }
        .padding(.bottom, 10)
    }

    private var chatTimeline: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if viewModel.chatMessages.isEmpty {
                        emptyConversation
                    } else {
                        ForEach(viewModel.chatMessages) { message in
                            messageRow(message)
                                .id(message.id)
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 2)
            }
            .frame(minHeight: 280)
            .onChange(of: viewModel.chatMessages.count) { _ in
                scrollToLatest(proxy)
            }
            .onChange(of: latestMessageScrollToken) { _ in
                scrollToLatest(proxy, animated: false)
            }
        }
    }

    private var emptyConversation: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(.secondary)
                Text("你想了解什么？")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("可以直接提问，也可以先在 PDF 中选择一段内容。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                suggestionButton("总结这篇论文的核心贡献", symbol: "text.alignleft")
                suggestionButton("解释论文的方法和关键假设", symbol: "gearshape.2")
                suggestionButton("实验结果是否支持作者的结论？", symbol: "chart.bar.xaxis")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 36)
    }

    private func suggestionButton(_ title: String, symbol: String) -> some View {
        Button {
            draftInput = title
            viewModel.chatComposerFocusTick &+= 1
        } label: {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text(title)
                    .font(.callout)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.left")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(
                PaperTheme.sheet(for: colorScheme),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(PaperTheme.rule(for: colorScheme).opacity(0.45), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func messageRow(_ message: ChatMessage) -> some View {
        let isUser = message.role == .user
        let isStreaming = viewModel.streamingAssistantMessageID == message.id

        return VStack(alignment: isUser ? .trailing : .leading, spacing: 7) {
            if isUser {
                Text(message.content)
                    .font(.system(size: 13.5))
                    .textSelection(.enabled)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(
                        PaperTheme.selection(for: colorScheme),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .frame(maxWidth: 285, alignment: .trailing)
            } else {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 20)

                    VStack(alignment: .leading, spacing: 8) {
                        if isStreaming && message.content.isEmpty {
                            HStack(spacing: 7) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(viewModel.thinkingMode == .deep ? "正在深入阅读论文…" : "正在思考…")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        } else if isStreaming {
                            Text(message.content)
                                .font(.system(size: 13.5))
                                .lineSpacing(3)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            MarkdownContentView(markdown: message.content)
                        }

                        if !isStreaming {
                            assistantActions(message)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private func assistantActions(_ message: ChatMessage) -> some View {
        HStack(spacing: 12) {
            actionButton("复制", symbol: "doc.on.doc") {
                copyToPasteboard(message.content)
            }

            actionButton("存为笔记", symbol: "note.text.badge.plus") {
                Task { await viewModel.saveChatMessageAsNote(messageID: message.id) }
            }

            if message.id == latestAssistantMessageID, viewModel.canRetryLatestChatResponse {
                actionButton("重新生成", symbol: "arrow.clockwise") {
                    viewModel.retryLatestChatResponse()
                }
            }
        }
    }

    private func actionButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.caption2)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var errorBanner: some View {
        if case .failure(let message) = viewModel.chatState {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Spacer()
                if viewModel.canRetryLatestChatResponse {
                    Button("重试") {
                        viewModel.retryLatestChatResponse()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                }
            }
            .padding(9)
            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            .padding(.bottom, 8)
        }
    }

    private var composer: some View {
        VStack(spacing: 0) {
            if let pinned = viewModel.pinnedChatSelectionSummary {
                selectionAttachment(pinned)
                    .padding(.horizontal, 10)
                    .padding(.top, 9)
            }

            ZStack(alignment: .topLeading) {
                ChatInputTextView(
                    text: $draftInput,
                    focusTick: viewModel.chatComposerFocusTick,
                    onSubmit: sendCurrentInput
                )
                .frame(minHeight: 54, maxHeight: 130)
                .padding(.horizontal, 8)
                .padding(.top, 7)
                .padding(.bottom, 3)

                if draftInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(viewModel.pinnedChatSelectionSummary == nil ? "询问这篇论文…" : "询问所选内容…")
                        .font(.system(size: 13.5))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }

            HStack(spacing: 10) {
                providerMenu
                thinkingMenu

                Spacer()

                Text(composerHint)
                    .font(.caption2)
                    .foregroundStyle(
                        viewModel.isCurrentChatProviderUsable
                        ? Color.secondary.opacity(0.72)
                        : Color.orange
                    )

                if viewModel.chatState == .loading {
                    Button {
                        viewModel.stopChatResponse()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.borderedProminent)
                    .clipShape(Circle())
                    .help("停止生成")
                } else {
                    Button {
                        sendCurrentInput()
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.borderedProminent)
                    .clipShape(Circle())
                    .disabled(
                        draftInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || !viewModel.isCurrentChatProviderUsable
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 9)
        }
        .background(
            inputFill,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.16 : 0.06), radius: 8, y: 3)
        .padding(.top, 10)
    }

    private func selectionAttachment(_ title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "text.quote")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text("已附加 PDF 选区")
                    .font(.caption2)
                    .fontWeight(.semibold)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                viewModel.clearPinnedChatSelection()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private var providerMenu: some View {
        Menu {
            ForEach(viewModel.chatSelectableProviders) { provider in
                Button {
                    viewModel.chatProviderOverride = provider
                } label: {
                    if viewModel.chatProviderOverride == provider {
                        Label(viewModel.chatProviderOptionTitle(provider), systemImage: "checkmark")
                    } else {
                        Text(viewModel.chatProviderOptionTitle(provider))
                    }
                }
                .disabled(!viewModel.isChatProviderSelectable(provider))
            }
        } label: {
            Label(providerShortTitle, systemImage: "cpu")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var thinkingMenu: some View {
        Menu {
            Button {
                viewModel.thinkingMode = .fast
            } label: {
                Label("Fast", systemImage: viewModel.thinkingMode == .fast ? "checkmark" : "bolt")
            }
            Button {
                viewModel.thinkingMode = .deep
            } label: {
                Label("Deep", systemImage: viewModel.thinkingMode == .deep ? "checkmark" : "brain")
            }
        } label: {
            Label(viewModel.thinkingMode.rawValue, systemImage: viewModel.thinkingMode == .deep ? "brain" : "bolt")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func sendCurrentInput() {
        guard viewModel.isCurrentChatProviderUsable else { return }
        let text = draftInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, viewModel.chatState != .loading else { return }
        draftInput = ""
        viewModel.submitChat(text: text)
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy, animated: Bool = true) {
        guard let latest = viewModel.chatMessages.last else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.18)) {
                proxy.scrollTo(latest.id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(latest.id, anchor: .bottom)
        }
    }

    private var latestAssistantMessageID: UUID? {
        viewModel.chatMessages.last(where: { $0.role == .assistant })?.id
    }

    private var latestMessageScrollToken: String {
        guard let latest = viewModel.chatMessages.last else { return "empty" }
        return "\(latest.id.uuidString)-\(latest.content.count)"
    }

    private var providerShortTitle: String {
        switch viewModel.chatProviderOverride {
        case .auto: return "Auto"
        case .openai: return "OpenAI"
        case .deepseek: return "DeepSeek"
        case .kimi: return "Kimi"
        }
    }

    private var composerHint: String {
        viewModel.isCurrentChatProviderUsable ? "↩︎ 发送" : "请配置 API Key"
    }

    private var inputFill: Color {
        PaperTheme.raisedSheet(for: colorScheme)
    }
}

private struct ChatInputTextView: NSViewRepresentable {
    @Binding var text: String
    var focusTick: Int
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
        textView.font = NSFont.systemFont(ofSize: 13.5)
        textView.textContainerInset = NSSize(width: 5, height: 6)
        textView.string = text
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        if context.coordinator.lastFocusTick != focusTick {
            context.coordinator.lastFocusTick = focusTick
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ChatInputTextView
        weak var textView: NSTextView?
        var lastFocusTick: Int

        init(_ parent: ChatInputTextView) {
            self.parent = parent
            lastFocusTick = parent.focusTick
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            parent.text = textView.string
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard commandSelector == #selector(NSResponder.insertNewline(_:)) else {
                return false
            }
            if NSApp.currentEvent?.modifierFlags.contains(.shift) == true || textView.hasMarkedText() {
                return false
            }
            guard !textView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return true
            }
            parent.onSubmit()
            return true
        }
    }
}

private struct MarkdownContentView: View {
    let markdown: String

    var body: some View {
        if let attributed = try? AttributedString(
            markdown: normalizedMarkdown,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .full,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        ) {
            Text(attributed)
                .font(.system(size: 13.5))
                .lineSpacing(3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(normalizedMarkdown)
                .font(.system(size: 13.5))
                .lineSpacing(3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var normalizedMarkdown: String {
        markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
