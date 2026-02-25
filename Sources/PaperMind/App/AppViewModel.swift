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
    @Published var streamingAssistantMessageID: UUID?
    @Published var aiProvider: AIProvider = .auto
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
    private var paperKnowledgeCache: [UUID: PaperKnowledge] = [:]
    private var translationCache: [String: String] = [:]

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

        do {
            try dependencies.saveAISettings(settings)
            llmService = dependencies.makeLLMService(settings: settings)
            aiConfigState = .success
        } catch {
            aiConfigState = .failure(error.localizedDescription)
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
            autoTranslateTask?.cancel()
            selectedPaperID = nil
            currentSelection = nil
            currentSelectionAnchor = nil
            selectedTextPreview = ""
            isMathSelection = false
            translationResult = ""
            translationState = .idle
            paperContextState = .idle
            await refreshPapers()
        } catch {
            chatState = .failure(error.localizedDescription)
        }
    }

    func closeCurrentPaper() {
        autoTranslateTask?.cancel()
        selectedPaperID = nil
        currentSelection = nil
        currentSelectionAnchor = nil
        currentReaderPageIndex = 0
        selectedTextPreview = ""
        isMathSelection = false
        translationResult = ""
        translationState = .idle
        paperContextState = .idle
    }

    func didSelectPaper(id: UUID?) async {
        autoTranslateTask?.cancel()
        selectedPaperID = id
        currentSelection = nil
        currentSelectionAnchor = nil
        selectedTextPreview = ""
        isMathSelection = false
        translationResult = ""
        translationState = .idle
        paperContextState = .idle
        await refreshNotesForSelectedPaper()
    }

    func handleSelectionChanged(text: String, pageIndex: Int, anchorRect: CGRect?) {
        currentReaderPageIndex = pageIndex
        updateSelection(text: text, pageIndex: pageIndex, anchorRect: anchorRect)

        autoTranslateTask?.cancel()
        guard currentSelection != nil else { return }

        if let selection = currentSelection,
           let cached = translationCache[translationCacheKey(for: selection.selectedText, target: translationTargetLanguage)] {
            translationResult = cached
            translationState = .success
            return
        }

        translationResult = ""
        translationState = .loading

        autoTranslateTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }
            await self?.translateSelection()
        }
    }

    func updateSelection(text: String, pageIndex: Int, anchorRect: CGRect? = nil) {
        guard let paper = selectedPaper else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
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

        if let cached = translationCache[translationCacheKey(for: trimmed, target: translationTargetLanguage)] {
            translationResult = cached
            translationState = .success
        } else {
            translationResult = ""
            translationState = .idle
        }
    }

    func translateSelection(target: String? = nil) async {
        guard let selection = currentSelection else {
            translationState = .failure("请先选择文本")
            return
        }

        let target = (target ?? translationTargetLanguage).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else {
            translationState = .failure("目标语言不能为空")
            return
        }

        let cacheKey = translationCacheKey(for: selection.selectedText, target: target)
        if let cached = translationCache[cacheKey] {
            translationResult = cached
            translationState = .success
            return
        }

        translationState = .loading
        do {
            let result = try await dependencies.translationService.translate(
                text: selection.selectedText,
                source: nil,
                target: target
            )
            translationResult = result
            translationCache[cacheKey] = result
            translationState = .success
        } catch is CancellationError {
            translationState = .idle
        } catch {
            translationState = .failure(error.localizedDescription)
        }
    }

    func updateTranslationTargetLanguage(_ target: String) async {
        let trimmed = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        translationTargetLanguage = trimmed
        guard currentSelection != nil else { return }
        await translateSelection(target: trimmed)
    }

    func askAIUsingSelection(question: String? = nil) async {
        guard let selection = currentSelection else {
            chatState = .failure("请先选择论文片段")
            return
        }

        let input = (question ?? chatInput).trimmingCharacters(in: .whitespacesAndNewlines)
        let finalInput = input.isEmpty
            ? "请结合我选中的内容解释关键点，并说明它在论文中的作用。"
            : input

        chatMode = .explain
        await sendChatMessage(input: finalInput, selection: selection)
    }

    func explainFormulaUsingSelection() async {
        guard let selection = currentSelection else {
            chatState = .failure("请先选择公式")
            return
        }

        chatMode = .explain
        let prompt = """
        Explain Formula:
        请用中文解释下面这个数学公式，并严格按以下结构输出：
        1) 一句话直觉
        2) 符号对照表（逐项解释）
        3) 公式作用（在论文中解决什么问题）
        4) 一个简单代入示例

        公式：
        \(selection.selectedText)
        """
        await sendChatMessage(input: prompt, selection: selection)
    }

    func sendChatFromInput(text: String? = nil) async {
        let input = (text ?? chatInput).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            chatState = .failure("请输入问题")
            return
        }
        await sendChatMessage(input: input, selection: currentSelection)
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

    private func sendChatMessage(input: String, selection: TextSelection?) async {
        let userMessage = ChatMessage(
            id: UUID(),
            sessionID: chatSessionID,
            role: .user,
            content: input,
            createdAt: Date()
        )
        chatMessages.append(userMessage)
        let requestMessages = chatMessages

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
        chatInput = ""
        streamingAssistantMessageID = assistantMessageID
        chatState = .loading

        do {
            if let paper = selectedPaper {
                if thinkingMode == .deep {
                    _ = await loadPaperKnowledgeIfNeeded(for: paper)
                } else {
                    Task { [weak self] in
                        guard let self else { return }
                        _ = await self.loadPaperKnowledgeIfNeeded(for: paper)
                    }
                }
            }

            let response = try await llmService.chatStream(
                messages: requestMessages,
                context: buildContext(selection: selection)
            ) { [weak self] delta in
                Task { @MainActor [weak self] in
                    guard let self,
                          let index = self.chatMessages.firstIndex(where: { $0.id == assistantMessageID }) else { return }
                    self.chatMessages[index].content += delta
                }
            }

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

    private func loadAIConfiguration() {
        let settings = dependencies.loadAISettings()
        aiProvider = settings.provider
        openAIModel = settings.openAIModel
        deepSeekModel = settings.deepSeekModel
        kimiModel = settings.kimiModel

        openAIAPIKeyDraft = settings.openAIAPIKey
        deepSeekAPIKeyDraft = settings.deepSeekAPIKey
        kimiAPIKeyDraft = settings.kimiAPIKey

        llmService = dependencies.makeLLMService(settings: settings)
    }

    private func normalizedAISettings() -> AISettings {
        AISettings(
            provider: aiProvider,
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
}
