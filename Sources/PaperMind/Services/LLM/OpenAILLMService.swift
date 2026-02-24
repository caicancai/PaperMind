import Foundation

struct OpenAILLMService: LLMService {
    let apiKey: String
    let model: String
    let session: URLSession
    let timeoutSeconds: TimeInterval

    init(apiKey: String, model: String = "gpt-4o-mini", session: URLSession = .shared, timeoutSeconds: TimeInterval = 15) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
        self.timeoutSeconds = timeoutSeconds
    }

    func chat(messages: [ChatMessage], context: PaperContext?) async throws -> String {
        let userMessages = messages.map { message in
            OpenAIMessage(role: message.role.rawValue, content: message.content)
        }

        let systemPrompt = buildSystemPrompt(context: context)
        let payload = OpenAIChatRequest(
            model: model,
            messages: [OpenAIMessage(role: "system", content: systemPrompt)] + userMessages,
            temperature: 0.3
        )

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutSeconds
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw PMError.network("LLM 请求失败: \(body)")
        }

        let decoded = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PMError.network("LLM 响应为空")
        }

        return content
    }

    private func buildSystemPrompt(context: PaperContext?) -> String {
        let paperTitle = context?.paper.title ?? "未知论文"
        let selection = context?.selection?.selectedText ?? ""

        if selection.isEmpty {
            return "你是论文阅读助手。当前论文：\(paperTitle)。如果用户问题缺少上下文，请明确回复“依据不足”，并指出需要用户先选中论文片段。"
        }

        return "你是论文阅读助手。当前论文：\(paperTitle)。当前选中片段：\(selection)。回答应优先基于该片段，并在信息不足时明确说明“依据不足”。"
    }
}

private struct OpenAIChatRequest: Encodable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double
}

private struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

private struct OpenAIChatResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String
    }
}
