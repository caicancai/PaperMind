import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published var papers: [Paper] = []
    @Published var selectedPaperID: UUID?

    @Published var currentSelection: TextSelection?
    @Published var currentSelectionAnchor: NoteAnchorRect?
    @Published var selectedTextPreview: String = ""
    @Published var isMathSelection: Bool = false

    @Published var translationState: RequestState = .idle
    @Published var translationResult: String = ""
    @Published var paperContextState: RequestState = .idle

    @Published var chatSessionID: UUID = UUID()
    @Published var chatMode: ChatMode = .explain
    @Published var chatMessages: [ChatMessage] = []
    @Published var chatInput: String = ""
    @Published var chatState: RequestState = .idle

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
    private var autoTranslateTask: Task<Void, Never>?
    private var paperKnowledgeCache: [UUID: PaperKnowledge] = [:]

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    var selectedPaper: Paper? {
        papers.first { $0.id == selectedPaperID }
    }

    func bootstrap() async {
        await refreshPapers()
    }

    func refreshPapers() async {
        do {
            papers = try await dependencies.paperRepository.listPapers()
            if selectedPaperID == nil {
                selectedPaperID = papers.first?.id
            }
            await refreshNotesForSelectedPaper()
            Task { [weak self] in
                await self?.prefetchPaperKnowledgeForSelectedPaper()
            }
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
        Task { [weak self] in
            await self?.prefetchPaperKnowledgeForSelectedPaper()
        }
    }

    func handleSelectionChanged(text: String, pageIndex: Int, anchorRect: CGRect?) {
        updateSelection(text: text, pageIndex: pageIndex, anchorRect: anchorRect)

        autoTranslateTask?.cancel()
        guard currentSelection != nil else { return }

        autoTranslateTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 220_000_000)
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
    }

    func translateSelection(target: String = "zh") async {
        guard let selection = currentSelection else {
            translationState = .failure("请先选择文本")
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
            translationState = .success
        } catch is CancellationError {
            translationState = .idle
        } catch {
            translationState = .failure(error.localizedDescription)
        }
    }

    func askAIUsingSelection() async {
        guard let selection = currentSelection else {
            chatState = .failure("请先选择论文片段")
            return
        }

        if chatMode == .summarize {
            chatInput = "Summarize: 请总结这段内容的核心要点，并给出 3 条关键结论。"
        } else {
            chatInput = "Explain: 请解释这段内容的核心含义，并说明它在论文中的作用。"
        }
        await sendChatMessage(selection: selection)
    }

    func explainFormulaUsingSelection() async {
        guard let selection = currentSelection else {
            chatState = .failure("请先选择公式")
            return
        }

        guard isMathSelection else {
            chatState = .failure("当前选区看起来不像公式，可用“解释选区”继续")
            return
        }

        chatMode = .explain
        chatInput = """
        Explain Formula:
        请用中文解释下面这个数学公式，并严格按以下结构输出：
        1) 一句话直觉
        2) 符号对照表（逐项解释）
        3) 公式作用（在论文中解决什么问题）
        4) 一个简单代入示例

        公式：
        \(selection.selectedText)
        """
        await sendChatMessage(selection: selection)
    }

    func sendChatFromInput() async {
        await sendChatMessage(selection: currentSelection)
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

    private func sendChatMessage(selection: TextSelection?) async {
        let input = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            chatState = .failure("请输入问题")
            return
        }

        let userMessage = ChatMessage(
            id: UUID(),
            sessionID: chatSessionID,
            role: .user,
            content: input,
            createdAt: Date()
        )
        chatMessages.append(userMessage)
        chatInput = ""
        chatState = .loading

        do {
            if let paper = selectedPaper {
                _ = await loadPaperKnowledgeIfNeeded(for: paper)
            }

            let response = try await dependencies.llmService.chat(
                messages: chatMessages,
                context: buildContext(selection: selection)
            )

            let assistantMessage = ChatMessage(
                id: UUID(),
                sessionID: chatSessionID,
                role: .assistant,
                content: response,
                createdAt: Date()
            )
            chatMessages.append(assistantMessage)
            chatState = .success
        } catch {
            chatState = .failure(error.localizedDescription)
        }
    }

    private func buildContext(selection: TextSelection?) -> PaperContext? {
        guard let paper = selectedPaper else { return nil }
        let knowledge = paperKnowledgeCache[paper.id]
        return PaperContext(paper: paper, selection: selection, knowledge: knowledge)
    }

    private func prefetchPaperKnowledgeForSelectedPaper() async {
        guard let paper = selectedPaper else { return }
        _ = await loadPaperKnowledgeIfNeeded(for: paper)
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
}
