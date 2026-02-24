import Foundation

struct MockLLMService: LLMService {
    let delayNanoseconds: UInt64

    init(delayNanoseconds: UInt64 = 800_000_000) {
        self.delayNanoseconds = delayNanoseconds
    }

    func chat(messages: [ChatMessage], context: PaperContext?) async throws -> String {
        guard let last = messages.last(where: { $0.role == .user }) else {
            throw PMError.invalidInput("请先输入问题")
        }

        try await Task.sleep(nanoseconds: delayNanoseconds)

        let prompt = last.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            throw PMError.invalidInput("问题不能为空")
        }

        let selectionText = context?.selection?.selectedText.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if selectionText.isEmpty {
            return "依据不足：当前没有选中文本。请先在论文中选择一段内容，再让我进行解释或总结。"
        }

        return "基于你选中的内容“\(selectionText.prefix(120))”，我对“\(prompt)”的回答是：这是一个 MVP 阶段的模拟回答，建议你继续追问具体术语或方法细节。"
    }
}
