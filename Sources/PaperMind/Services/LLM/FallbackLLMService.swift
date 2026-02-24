import Foundation

struct FallbackLLMService: LLMService {
    let primary: LLMService
    let fallback: LLMService

    func chat(messages: [ChatMessage], context: PaperContext?) async throws -> String {
        do {
            return try await primary.chat(messages: messages, context: context)
        } catch {
            return try await fallback.chat(messages: messages, context: context)
        }
    }
}
