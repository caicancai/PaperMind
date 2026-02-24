import Foundation

struct UnavailableLLMService: LLMService {
    let reason: String

    func chat(messages: [ChatMessage], context: PaperContext?) async throws -> String {
        _ = messages
        _ = context
        throw PMError.network(reason)
    }
}
