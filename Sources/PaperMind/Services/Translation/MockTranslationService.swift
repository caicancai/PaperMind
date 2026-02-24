import Foundation

struct MockTranslationService: TranslationService {
    let delayNanoseconds: UInt64

    init(delayNanoseconds: UInt64 = 600_000_000) {
        self.delayNanoseconds = delayNanoseconds
    }

    func translate(text: String, source: String?, target: String) async throws -> String {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw PMError.invalidInput("请选择需要翻译的文本")
        }

        try await Task.sleep(nanoseconds: delayNanoseconds)

        if Task.isCancelled {
            throw CancellationError()
        }

        let sourceLabel = source ?? "auto"
        return "[\(sourceLabel)->\(target)] \(value)"
    }
}
