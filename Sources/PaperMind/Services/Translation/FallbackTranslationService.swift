import Foundation

struct FallbackTranslationService: TranslationService {
    let primary: TranslationService
    let fallback: TranslationService

    func translate(text: String, source: String?, target: String) async throws -> String {
        do {
            return try await primary.translate(text: text, source: source, target: target)
        } catch {
            return try await fallback.translate(text: text, source: source, target: target)
        }
    }
}
