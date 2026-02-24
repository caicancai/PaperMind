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
        let hasKnowledge = !(context?.knowledge?.sampledText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

        if selectionText.isEmpty {
            if hasKnowledge {
                return "我已基于整篇论文的预读上下文回答“\(prompt)”。如果你希望更精准，我可以再结合你选中的具体段落深入解释。"
            }
            return "我先按你的问题“\(prompt)”给出通用解释。若你选中具体段落，我可以提供更精确的逐句分析。"
        }

        return "基于你选中的内容“\(selectionText.prefix(120))”，我对“\(prompt)”的回答是：这是一个 MVP 阶段的模拟回答，建议你继续追问具体术语或方法细节。"
    }
}
