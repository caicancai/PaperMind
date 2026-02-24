import Foundation

struct AppDependencies {
    var paperRepository: PaperRepository
    var noteRepository: NoteRepository
    var translationService: TranslationService
    var llmService: LLMService

    static func makeLive() -> AppDependencies {
        let baseURL = AppDirectories.appSupportDirectory()
        let store = JSONFileStore()
        let mockTranslation = MockTranslationService()
        let translationService = FallbackTranslationService(
            primary: GoogleTranslationService(),
            fallback: mockTranslation
        )

        let llmService: LLMService
        if let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
           !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            llmService = FallbackLLMService(
                primary: OpenAILLMService(apiKey: apiKey),
                fallback: MockLLMService()
            )
        } else {
            llmService = MockLLMService()
        }

        return AppDependencies(
            paperRepository: JSONPaperRepository(store: store, fileURL: baseURL.appendingPathComponent("papers.json")),
            noteRepository: JSONNoteRepository(store: store, fileURL: baseURL.appendingPathComponent("notes.json")),
            translationService: translationService,
            llmService: llmService
        )
    }
}
