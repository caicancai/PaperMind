import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published var papers: [Paper] = []
    @Published var selectedPaperID: UUID?

    @Published var currentSelection: TextSelection?
    @Published var currentSelectionAnchor: NoteAnchorRect?
    @Published var currentReaderPageIndex: Int = 0
    @Published var selectedTextPreview: String = ""
    @Published var isMathSelection: Bool = false

    @Published var translationState: RequestState = .idle
    @Published var translationResult: String = ""
    @Published var translationTargetLanguage: String = "zh"
    @Published var paperContextState: RequestState = .idle

    @Published var chatSessionID: UUID = UUID()
    @Published var chatMode: ChatMode = .explain
    @Published var thinkingMode: ThinkingMode = .fast
    @Published var chatMessages: [ChatMessage] = []
    @Published var chatInput: String = ""
    @Published var chatState: RequestState = .idle
    @Published var chatProviderOverride: AIProvider = .auto
    @Published var streamingAssistantMessageID: UUID?
    @Published var pinnedChatSelectionSummary: String?
    @Published var aiProvider: AIProvider = .auto
    @Published var appTheme: AppTheme = .light
    @Published var openAIModel: String = AISettings.default.openAIModel
    @Published var deepSeekModel: String = AISettings.default.deepSeekModel
    @Published var kimiModel: String = AISettings.default.kimiModel
    @Published var openAIAPIKeyDraft: String = ""
    @Published var deepSeekAPIKeyDraft: String = ""
    @Published var kimiAPIKeyDraft: String = ""
    @Published var aiConfigState: RequestState = .idle

    @Published var notes: [Note] = []
    @Published var activeThreadID: UUID?
    @Published var focusedThreadID: UUID?
    @Published var focusThreadTick: Int = 0
    @Published var showCommentsPanel: Bool = true
    @Published var newThreadTitleDraft: String = ""
    @Published var newThreadCommentDraft: String = ""
    @Published var replyDraft: String = ""
    @Published var showResolvedThreads: Bool = false
    @Published var noteState: RequestState = .idle

    private let dependencies: AppDependencies
    private var llmService: LLMService
    private var autoTranslateTask: Task<Void, Never>?
    private var paperKnowledgePreloadTask: Task<Void, Never>?
    private var paperKnowledgeCache: [UUID: PaperKnowledge] = [:]
    private var translationCache: [String: String] = [:]
    private var pinnedChatSelection: TextSelection?
    private var latestTranslationRequestID: UInt64 = 0
    private var latestChatRequestID: UInt64 = 0
    private let translationCacheLimit = 200

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        self.llmService = dependencies.llmService
        loadAIConfiguration()
    }

    var selectedPaper: Paper? {
        papers.first { $0.id == selectedPaperID }
    }

    func bootstrap() async {
        await refreshPapers()
    }

    func saveAIConfiguration() {
        aiConfigState = .loading
        let settings = normalizedAISettings()
        sanitizeChatProviderOverride()

        do {
            try dependencies.saveAISettings(settings)
            llmService = dependencies.makeLLMService(settings: settings)
            aiConfigState = .success
        } catch {
            aiConfigState = .failure(error.localizedDescription)
        }
    }

    func applyTheme(_ theme: AppTheme) {
        guard appTheme != theme else { return }
        appTheme = theme

        do {
            var settings = dependencies.loadAISettings()
            settings.theme = theme
            try dependencies.saveAISettings(settings)
        } catch {
            // Keep UI responsive even if persistence fails.
        }
    }

    func refreshPapers() async {
        do {
            papers = try await dependencies.paperRepository.listPapers()
            if selectedPaperID == nil {
                selectedPaperID = papers.first?.id
            }
            await refreshNotesForSelectedPaper()
        } catch {
            chatState = .failure(error.localizedDescription)
        }
    }

    func importPaper(from url: URL) async {
        do {
            let paper = try await dependencies.paperRepository.addPaper(fileURL: url)
            await refreshPapers()
            selectedPaperID = paper.id
        } catch {
            chatState = .failure(error.localizedDescription)
        }
    }

    func removeSelectedPaper() async {
        guard let id = selectedPaperID else { return }

        do {
            try await dependencies.paperRepository.removePaper(id: id)
            cancelTransientTasks()
            selectedPaperID = nil
            resetSelectionAndTranslationState(resetReaderPage: false)
            paperContextState = .idle
            await refreshPapers()
        } catch {
            chatState = .failure(error.localizedDescription)
        }
    }

    func closeCurrentPaper() {
        cancelTransientTasks()
        selectedPaperID = nil
        resetSelectionAndTranslationState(resetReaderPage: true)
        paperContextState = .idle
    }

    func didSelectPaper(id: UUID?) async {
        cancelTransientTasks()
        selectedPaperID = id
        resetSelectionAndTranslationState(resetReaderPage: false)
        paperContextState = .idle
        await refreshNotesForSelectedPaper()
    }

    func handleSelectionChanged(text: String, pageIndex: Int, anchorRect: CGRect?) {
        currentReaderPageIndex = pageIndex
        updateSelection(text: text, pageIndex: pageIndex, anchorRect: anchorRect)

        autoTranslateTask?.cancel()
        guard currentSelection != nil else { return }

        if let selection = currentSelection,
           let cached = translationCache[
            translationCacheKey(
                for: normalizedTextForTranslation(selection.selectedText),
                target: translationTargetLanguage
            )
           ] {
            translationResult = cached
            translationState = .success
            return
        }

        translationResult = ""
        translationState = .loading
        let requestID = beginTranslationRequest()

        autoTranslateTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }
            await self?.performTranslateSelection(target: nil, requestID: requestID)
        }
    }

    func updateSelection(text: String, pageIndex: Int, anchorRect: CGRect? = nil) {
        guard let paper = selectedPaper else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            autoTranslateTask?.cancel()
            invalidateTranslationRequests()
            currentSelection = nil
            currentSelectionAnchor = nil
            selectedTextPreview = ""
            isMathSelection = false
            translationResult = ""
            translationState = .idle
            return
        }

        currentSelection = TextSelection(
            paperID: paper.id,
            pageIndex: pageIndex,
            selectedText: trimmed,
            contextBefore: nil,
            contextAfter: nil
        )
        currentSelectionAnchor = anchorRect.map(NoteAnchorRect.init(rect:))
        selectedTextPreview = trimmed
        isMathSelection = FormulaDetector.isLikelyFormula(trimmed)
        invalidateTranslationRequests()

        if let cached = translationCache[
            translationCacheKey(
                for: normalizedTextForTranslation(trimmed),
                target: translationTargetLanguage
            )
        ] {
            translationResult = cached
            translationState = .success
        } else {
            translationResult = ""
            translationState = .idle
        }
    }

    func translateSelection(target: String? = nil) async {
        let requestID = beginTranslationRequest()
        await performTranslateSelection(target: target, requestID: requestID)
    }

    func updateTranslationTargetLanguage(_ target: String) async {
        let trimmed = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        translationTargetLanguage = trimmed
        guard currentSelection != nil else { return }
        await translateSelection(target: trimmed)
    }

    func askAIUsingSelection(question: String? = nil) async {
        guard ensureChatIdle() else { return }
        guard let selection = currentSelection else {
            chatState = .failure("请先选择论文片段")
            return
        }

        let input = (question ?? chatInput).trimmingCharacters(in: .whitespacesAndNewlines)
        let finalInput = input.isEmpty
            ? "请结合我选中的内容解释关键点，并说明它在论文中的作用。"
            : input

        chatMode = .explain
        let requestID = beginChatRequest()
        await sendChatMessage(input: finalInput, selection: selection, requestID: requestID)
    }

    func prepareChatDraftFromSelection() {
        guard let selection = currentSelection else {
            chatState = .failure("请先选择论文片段")
            return
        }

        pinnedChatSelection = selection
        pinnedChatSelectionSummary = "已附加选区 P\(selection.pageIndex + 1) · \(selection.selectedText.count) 字"
        chatMode = .explain
        chatState = .idle
        if chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            chatInput = ""
        }
    }

    func clearPinnedChatSelection() {
        pinnedChatSelection = nil
        pinnedChatSelectionSummary = nil
    }

    func explainFormulaUsingSelection() async {
        guard ensureChatIdle() else { return }
        guard let selection = currentSelection else {
            chatState = .failure("请先选择公式")
            return
        }

        chatMode = .explain
        let hiddenPrompt = """
        请用中文解释下面这个数学公式，回答尽量自然、清晰、易读。
        优先说明：
        - 这个公式在表达什么
        - 关键符号或项分别代表什么
        - 它在论文里起到什么作用
        - 如果合适，给一个简短例子帮助理解

        公式：
        \(selection.selectedText)
        """
        let displayPrompt = "请解释这段公式，结合当前选区与论文上下文。"
        let requestID = beginChatRequest()
        await sendChatMessage(
            input: hiddenPrompt,
            selection: selection,
            requestID: requestID,
            displayInput: displayPrompt
        )
    }

    func sendChatFromInput(text: String? = nil) async {
        guard ensureChatIdle() else { return }
        let input = (text ?? chatInput).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            chatState = .failure("请输入问题")
            return
        }
        let selectionForMessage = pinnedChatSelection ?? currentSelection
        let usedPinnedSelection = pinnedChatSelection != nil
        let requestID = beginChatRequest()
        await sendChatMessage(input: input, selection: selectionForMessage, requestID: requestID)
        if usedPinnedSelection, chatState == .success {
            clearPinnedChatSelection()
        }
    }

    var chatSelectableProviders: [AIProvider] {
        AIProvider.allCases
    }

    var isCurrentChatProviderUsable: Bool {
        isChatProviderSelectable(chatProviderOverride)
    }

    func isChatProviderSelectable(_ provider: AIProvider) -> Bool {
        switch provider {
        case .auto:
            return true
        case .openai:
            return !normalizeAPIKey(openAIAPIKeyDraft).isEmpty
        case .deepseek:
            return !normalizeAPIKey(deepSeekAPIKeyDraft).isEmpty
        case .kimi:
            return !normalizeAPIKey(kimiAPIKeyDraft).isEmpty
        }
    }

    func chatProviderOptionTitle(_ provider: AIProvider) -> String {
        switch provider {
        case .auto:
            return "Auto"
        case .openai:
            return "OpenAI · \(normalizeModel(openAIModel, fallback: AISettings.default.openAIModel))"
        case .deepseek:
            return "DeepSeek · \(normalizeModel(deepSeekModel, fallback: AISettings.default.deepSeekModel))"
        case .kimi:
            return "Kimi · \(normalizeModel(kimiModel, fallback: AISettings.default.kimiModel))"
        }
    }

    func createCommentThreadFromDraft() async {
        guard let paper = selectedPaper else {
            noteState = .failure("请先选择论文")
            return
        }

        let title = newThreadTitleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let comment = newThreadCommentDraft.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !title.isEmpty || !comment.isEmpty else {
            noteState = .failure("评论标题或内容至少填写一项")
            return
        }

        noteState = .loading
        let now = Date()
        let note = Note(
            id: UUID(),
            paperID: paper.id,
            title: title.isEmpty ? "未命名评论" : title,
            content: comment,
            quote: currentSelection?.selectedText,
            pageIndex: currentSelection?.pageIndex,
            anchorRect: currentSelectionAnchor,
            tags: [],
            status: .open,
            comments: [
                NoteComment(id: UUID(), role: .author, content: comment.isEmpty ? "（空评论）" : comment, createdAt: now)
            ],
            createdAt: now,
            updatedAt: now
        )

        do {
            try await dependencies.noteRepository.save(note: note)
            activeThreadID = note.id
            focusThread(note.id)
            newThreadTitleDraft = ""
            newThreadCommentDraft = ""
            noteState = .success
            await refreshNotesForSelectedPaper()
        } catch {
            noteState = .failure(error.localizedDescription)
        }
    }

    func addReplyToActiveThread() async {
        guard let activeThreadID else {
            noteState = .failure("请先选择评论线程")
            return
        }

        let content = replyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            noteState = .failure("回复内容不能为空")
            return
        }

        guard let current = notes.first(where: { $0.id == activeThreadID }) else {
            noteState = .failure("评论线程不存在")
            return
        }

        var updated = current
        updated.comments.append(
            NoteComment(id: UUID(), role: .reply, content: content, createdAt: Date())
        )
        updated.updatedAt = Date()
        updated.status = .open

        do {
            try await dependencies.noteRepository.save(note: updated)
            replyDraft = ""
            noteState = .success
            await refreshNotesForSelectedPaper()
            self.activeThreadID = updated.id
            focusThread(updated.id)
        } catch {
            noteState = .failure(error.localizedDescription)
        }
    }

    func setThreadResolved(_ resolved: Bool, threadID: UUID) async {
        guard let current = notes.first(where: { $0.id == threadID }) else { return }
        var updated = current
        updated.status = resolved ? .resolved : .open
        updated.updatedAt = Date()

        do {
            try await dependencies.noteRepository.save(note: updated)
            await refreshNotesForSelectedPaper()
            focusThread(updated.id)
        } catch {
            noteState = .failure(error.localizedDescription)
        }
    }

    func deleteNote(id: UUID) async {
        do {
            try await dependencies.noteRepository.delete(noteID: id)
            if activeThreadID == id {
                activeThreadID = nil
                focusedThreadID = nil
            }
            await refreshNotesForSelectedPaper()
        } catch {
            noteState = .failure(error.localizedDescription)
        }
    }

    func fillDraftFromSelection() {
        guard let selection = currentSelection else { return }

        if newThreadTitleDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            newThreadTitleDraft = "P\(selection.pageIndex + 1) 评论"
        }
        if newThreadCommentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            newThreadCommentDraft = selection.selectedText
        }
    }

    func beginCommentFromSelection() {
        fillDraftFromSelection()
        showCommentsPanel = true
        noteState = .idle
    }

    func focusThread(_ id: UUID?) {
        activeThreadID = id
        focusedThreadID = id
        if id != nil {
            showCommentsPanel = true
        }
        focusThreadTick += 1
    }

    func handleThreadAnnotationTapped(_ id: UUID) {
        focusThread(id)
    }

    private func refreshNotesForSelectedPaper() async {
        guard let paper = selectedPaper else {
            notes = []
            return
        }

        do {
            notes = try await dependencies.noteRepository.listNotes(paperID: paper.id)
            if activeThreadID == nil || !notes.contains(where: { $0.id == activeThreadID }) {
                activeThreadID = notes.first?.id
                focusedThreadID = activeThreadID
            }
        } catch {
            noteState = .failure(error.localizedDescription)
        }
    }

    private func sendChatMessage(
        input: String,
        selection: TextSelection?,
        requestID: UInt64,
        displayInput: String? = nil
    ) async {
        let visibleInput = (displayInput ?? input).trimmingCharacters(in: .whitespacesAndNewlines)
        let userMessage = ChatMessage(
            id: UUID(),
            sessionID: chatSessionID,
            role: .user,
            content: visibleInput,
            createdAt: Date()
        )
        chatMessages.append(userMessage)
        var requestMessages = chatMessages
        if visibleInput != input,
           let index = requestMessages.lastIndex(where: { $0.id == userMessage.id }) {
            requestMessages[index].content = input
        }

        let assistantMessageID = UUID()
        chatMessages.append(
            ChatMessage(
                id: assistantMessageID,
                sessionID: chatSessionID,
                role: .assistant,
                content: "",
                createdAt: Date()
            )
        )
        guard isLatestChatRequest(requestID) else { return }
        chatInput = ""
        streamingAssistantMessageID = assistantMessageID
        chatState = .loading

        do {
            let chatService = makeChatServiceForCurrentSelection()
            if let paper = selectedPaper {
                if thinkingMode == .deep {
                    paperKnowledgePreloadTask?.cancel()
                    paperKnowledgePreloadTask = nil
                    _ = await loadPaperKnowledgeIfNeeded(for: paper)
                } else {
                    schedulePaperKnowledgePreload(for: paper)
                }
            }

            let response = try await chatService.chatStream(
                messages: requestMessages,
                context: buildContext(selection: selection)
            ) { [weak self] delta in
                Task { @MainActor [weak self] in
                    guard let self,
                          self.isLatestChatRequest(requestID),
                          let index = self.chatMessages.firstIndex(where: { $0.id == assistantMessageID }) else { return }
                    self.chatMessages[index].content += delta
                }
            }

            guard isLatestChatRequest(requestID) else { return }
            if let index = chatMessages.firstIndex(where: { $0.id == assistantMessageID }) {
                chatMessages[index].content = response
            } else {
                chatMessages.append(
                    ChatMessage(
                        id: assistantMessageID,
                        sessionID: chatSessionID,
                        role: .assistant,
                        content: response,
                        createdAt: Date()
                    )
                )
            }
            if let index = chatMessages.firstIndex(where: { $0.id == assistantMessageID }),
               chatMessages[index].content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                chatMessages.remove(at: index)
                streamingAssistantMessageID = nil
                throw PMError.network("AI 未返回有效内容")
            }

            streamingAssistantMessageID = nil
            chatState = .success
        } catch {
            guard isLatestChatRequest(requestID) else { return }
            if let index = chatMessages.firstIndex(where: { $0.id == assistantMessageID }),
               chatMessages[index].content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                chatMessages.remove(at: index)
            }
            streamingAssistantMessageID = nil
            chatState = .failure(error.localizedDescription)
        }
    }

    private func buildContext(selection: TextSelection?) -> PaperContext? {
        guard let paper = selectedPaper else { return nil }
        let knowledge = paperKnowledgeCache[paper.id]
        return PaperContext(paper: paper, selection: selection, knowledge: knowledge)
    }

    private func loadPaperKnowledgeIfNeeded(for paper: Paper) async -> PaperKnowledge? {
        if let cached = paperKnowledgeCache[paper.id] {
            if case .idle = paperContextState {
                paperContextState = .success
            }
            return cached
        }

        paperContextState = .loading
        do {
            let knowledge = try await dependencies.paperContextBuilder.buildKnowledge(for: paper)
            paperKnowledgeCache[paper.id] = knowledge
            paperContextState = .success
            return knowledge
        } catch {
            paperContextState = .failure("论文预读失败：\(error.localizedDescription)")
            return nil
        }
    }

    var visibleThreads: [Note] {
        notes.filter { showResolvedThreads || $0.status == .open }
    }

    var activeThread: Note? {
        guard let activeThreadID else { return nil }
        return notes.first(where: { $0.id == activeThreadID })
    }

    private func translationCacheKey(for text: String, target: String) -> String {
        "\(target)|\(text)"
    }

    private func beginTranslationRequest() -> UInt64 {
        latestTranslationRequestID &+= 1
        return latestTranslationRequestID
    }

    private func beginChatRequest() -> UInt64 {
        latestChatRequestID &+= 1
        return latestChatRequestID
    }

    private func invalidateTranslationRequests() {
        latestTranslationRequestID &+= 1
    }

    private func isLatestTranslationRequest(_ requestID: UInt64) -> Bool {
        requestID == latestTranslationRequestID
    }

    private func isLatestChatRequest(_ requestID: UInt64) -> Bool {
        requestID == latestChatRequestID
    }

    private func performTranslateSelection(target: String?, requestID: UInt64) async {
        guard let selection = currentSelection else {
            if isLatestTranslationRequest(requestID) {
                translationState = .failure("请先选择文本")
            }
            return
        }

        let resolvedTarget = (target ?? translationTargetLanguage).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !resolvedTarget.isEmpty else {
            if isLatestTranslationRequest(requestID) {
                translationState = .failure("目标语言不能为空")
            }
            return
        }

        let translationParagraphs = paragraphBlocksForTranslation(selection.selectedText)
        let normalizedSelectionText = translationParagraphs.joined(separator: "\n\n")
        let cacheKey = translationCacheKey(for: normalizedSelectionText, target: resolvedTarget)
        if let cached = translationCache[cacheKey] {
            if isLatestTranslationRequest(requestID) {
                translationResult = cached
                translationState = .success
            }
            return
        }

        if isLatestTranslationRequest(requestID) {
            translationState = .loading
        }

        do {
            let result: String
            if translationParagraphs.count <= 1 {
                result = try await dependencies.translationService.translate(
                    text: normalizedSelectionText,
                    source: nil,
                    target: resolvedTarget
                )
            } else {
                var translatedParagraphs: [String] = []
                translatedParagraphs.reserveCapacity(translationParagraphs.count)

                for paragraph in translationParagraphs {
                    guard isLatestTranslationRequest(requestID), !Task.isCancelled else {
                        throw CancellationError()
                    }
                    let translated = try await dependencies.translationService.translate(
                        text: paragraph,
                        source: nil,
                        target: resolvedTarget
                    )
                    translatedParagraphs.append(translated.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                result = translatedParagraphs.joined(separator: "\n\n")
            }
            cacheTranslation(result, for: cacheKey)

            guard isLatestTranslationRequest(requestID) else { return }
            translationResult = result
            translationState = .success
        } catch is CancellationError {
            guard isLatestTranslationRequest(requestID) else { return }
            translationState = .idle
        } catch {
            guard isLatestTranslationRequest(requestID) else { return }
            translationState = .failure(error.localizedDescription)
        }
    }

    private func cacheTranslation(_ result: String, for cacheKey: String) {
        if translationCache.count >= translationCacheLimit {
            translationCache.removeAll(keepingCapacity: true)
        }
        translationCache[cacheKey] = result
    }

    private func normalizedTextForTranslation(_ text: String) -> String {
        paragraphBlocksForTranslation(text).joined(separator: "\n\n")
    }

    private func paragraphBlocksForTranslation(_ text: String) -> [String] {
        let unixNewline = text.replacingOccurrences(of: "\r\n", with: "\n")
        let normalizedParagraphBreaks = unixNewline.replacingOccurrences(
            of: #"\n[ \t]*\n+"#,
            with: "\n\n",
            options: .regularExpression
        )

        return normalizedParagraphBreaks
            .components(separatedBy: "\n\n")
            .map { paragraph in
                paragraph
                    .components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
            }
            .filter { !$0.isEmpty }
    }

    private func cancelTransientTasks() {
        autoTranslateTask?.cancel()
        autoTranslateTask = nil
        paperKnowledgePreloadTask?.cancel()
        paperKnowledgePreloadTask = nil
    }

    private func resetSelectionAndTranslationState(resetReaderPage: Bool) {
        invalidateTranslationRequests()
        currentSelection = nil
        currentSelectionAnchor = nil
        if resetReaderPage {
            currentReaderPageIndex = 0
        }
        selectedTextPreview = ""
        isMathSelection = false
        translationResult = ""
        translationState = .idle
    }

    private func schedulePaperKnowledgePreload(for paper: Paper) {
        paperKnowledgePreloadTask?.cancel()
        let paperID = paper.id
        paperKnowledgePreloadTask = Task { [weak self] in
            guard let self else { return }
            await self.preloadKnowledgeIfCurrentPaper(expectedPaperID: paperID)
        }
    }

    private func preloadKnowledgeIfCurrentPaper(expectedPaperID: UUID) async {
        guard let paper = selectedPaper, paper.id == expectedPaperID else { return }
        _ = await loadPaperKnowledgeIfNeeded(for: paper)
    }

    private func ensureChatIdle() -> Bool {
        guard chatState == .loading else { return true }
        chatState = .failure("请等待当前回答完成")
        return false
    }

    private func makeChatServiceForCurrentSelection() -> LLMService {
        let settings = normalizedAISettings()
        let provider = resolvedChatProvider(using: settings)
        var requestSettings = settings
        requestSettings.provider = provider
        return dependencies.makeLLMService(settings: requestSettings)
    }

    private func resolvedChatProvider(using settings: AISettings) -> AIProvider {
        let preferred = chatProviderOverride
        if preferred != .auto, hasConfiguredKey(for: preferred, settings: settings) {
            return preferred
        }
        return settings.provider
    }

    private func hasConfiguredKey(for provider: AIProvider, settings: AISettings) -> Bool {
        switch provider {
        case .openai:
            return !normalizeAPIKey(settings.openAIAPIKey).isEmpty
        case .deepseek:
            return !normalizeAPIKey(settings.deepSeekAPIKey).isEmpty
        case .kimi:
            return !normalizeAPIKey(settings.kimiAPIKey).isEmpty
        case .auto:
            return true
        }
    }

    private func loadAIConfiguration() {
        let settings = dependencies.loadAISettings()
        aiProvider = settings.provider
        appTheme = settings.theme
        openAIModel = settings.openAIModel
        deepSeekModel = settings.deepSeekModel
        kimiModel = settings.kimiModel

        openAIAPIKeyDraft = settings.openAIAPIKey
        deepSeekAPIKeyDraft = settings.deepSeekAPIKey
        kimiAPIKeyDraft = settings.kimiAPIKey

        llmService = dependencies.makeLLMService(settings: settings)
        sanitizeChatProviderOverride()
    }

    private func normalizedAISettings() -> AISettings {
        AISettings(
            provider: aiProvider,
            theme: appTheme,
            openAIModel: normalizeModel(openAIModel, fallback: AISettings.default.openAIModel),
            deepSeekModel: normalizeModel(deepSeekModel, fallback: AISettings.default.deepSeekModel),
            kimiModel: normalizeModel(kimiModel, fallback: AISettings.default.kimiModel),
            openAIAPIKey: normalizeAPIKey(openAIAPIKeyDraft),
            deepSeekAPIKey: normalizeAPIKey(deepSeekAPIKeyDraft),
            kimiAPIKey: normalizeAPIKey(kimiAPIKeyDraft)
        )
    }

    private func normalizeModel(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func normalizeAPIKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sanitizeChatProviderOverride() {
        if !isChatProviderSelectable(chatProviderOverride) {
            chatProviderOverride = .auto
        }
    }
}
