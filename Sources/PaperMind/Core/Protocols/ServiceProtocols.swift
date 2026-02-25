import Foundation

protocol TranslationService {
    func translate(text: String, source: String?, target: String) async throws -> String
}

protocol LLMService {
    func chat(messages: [ChatMessage], context: PaperContext?) async throws -> String
    func chatStream(
        messages: [ChatMessage],
        context: PaperContext?,
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws -> String
}

extension LLMService {
    func chatStream(
        messages: [ChatMessage],
        context: PaperContext?,
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        let full = try await chat(messages: messages, context: context)
        onDelta(full)
        return full
    }
}

protocol PaperContextBuilderService {
    func buildKnowledge(for paper: Paper) async throws -> PaperKnowledge
}

protocol PaperRepository {
    func listPapers() async throws -> [Paper]
    func addPaper(fileURL: URL) async throws -> Paper
    func removePaper(id: UUID) async throws
}

protocol NoteRepository {
    func listNotes(paperID: UUID) async throws -> [Note]
    func save(note: Note) async throws
    func delete(noteID: UUID) async throws
}
