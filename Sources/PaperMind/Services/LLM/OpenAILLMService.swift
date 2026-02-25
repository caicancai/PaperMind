import Foundation

struct OpenAILLMService: LLMService {
    let providerName: String
    let apiKey: String
    let model: String
    let endpoint: URL
    let session: URLSession
    let timeoutSeconds: TimeInterval
    let maxContextCharacters: Int
    let retryCount: Int

    init(
        providerName: String = "openai",
        apiKey: String,
        model: String = "gpt-4o-mini",
        endpoint: URL = URL(string: "https://api.openai.com/v1/chat/completions")!,
        session: URLSession = .shared,
        timeoutSeconds: TimeInterval = 40,
        maxContextCharacters: Int = 8_000,
        retryCount: Int = 2
    ) {
        self.providerName = providerName
        self.apiKey = apiKey
        self.model = model
        self.endpoint = endpoint
        self.session = session
        self.timeoutSeconds = timeoutSeconds
        self.maxContextCharacters = maxContextCharacters
        self.retryCount = retryCount
    }

    func chat(messages: [ChatMessage], context: PaperContext?) async throws -> String {
        let userMessages = messages.map { message in
            OpenAIMessage(role: message.role.rawValue, content: message.content)
        }

        let systemPrompt = buildSystemPrompt(context: context)
        let payload = OpenAIChatRequest(
            model: model,
            messages: [OpenAIMessage(role: "system", content: systemPrompt)] + userMessages,
            temperature: 0.55,
            stream: nil
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutSeconds
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await sendWithRetry(request: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw PMError.network("\(providerName) LLM 请求失败（HTTP \(status)）: \(body)")
        }

        let decoded = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PMError.network("LLM 响应为空")
        }

        return content
    }

    func chatStream(
        messages: [ChatMessage],
        context: PaperContext?,
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        let userMessages = messages.map { message in
            OpenAIMessage(role: message.role.rawValue, content: message.content)
        }

        let systemPrompt = buildSystemPrompt(context: context)
        let payload = OpenAIChatRequest(
            model: model,
            messages: [OpenAIMessage(role: "system", content: systemPrompt)] + userMessages,
            temperature: 0.55,
            stream: true
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutSeconds
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PMError.network("\(providerName) LLM 流式请求失败（HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)）")
        }

        var fullContent = ""
        for try await line in bytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("data:") else { continue }

            let dataPart = trimmed.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines)
            if dataPart == "[DONE]" { break }
            guard let data = dataPart.data(using: .utf8) else { continue }

            if let chunk = try? JSONDecoder().decode(OpenAIChatStreamChunk.self, from: data),
               let delta = chunk.choices.first?.delta.content,
               !delta.isEmpty {
                fullContent += delta
                onDelta(delta)
            }
        }

        let result = fullContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else {
            throw PMError.network("LLM 流式响应为空")
        }
        return result
    }

    private func buildSystemPrompt(context: PaperContext?) -> String {
        let paperTitle = context?.paper.title ?? "未知论文"
        let selection = context?.selection?.selectedText ?? ""
        let knowledge = context?.knowledge

        var base = "你是论文阅读助手。当前论文：\(paperTitle)。请使用自然、流畅、易读的中文回答，优先短段落，避免僵硬模板语气。"

        if let knowledge {
            base += "你在回答前已经阅读过这篇论文的本地抽取上下文（页数：\(knowledge.pageCount)，采样字符：\(knowledge.sampledCharacterCount)）。请优先基于该上下文回答。"
            if !knowledge.sampledText.isEmpty {
                let clipped = String(knowledge.sampledText.prefix(maxContextCharacters))
                let clippedHint = knowledge.sampledText.count > clipped.count ? "\n[注] 上下文过长，已截断。" : ""
                base += "\n\n[论文上下文摘录]\n\(clipped)\(clippedHint)"
            }
        } else {
            base += "当前尚未获取完整论文上下文。请先尽力回答，并明确不确定性。"
        }

        if selection.isEmpty {
            return base + "用户不一定会选中文本。即使没有选区，也要先基于已有论文上下文尽量回答；只有在确实无法判断时，再简要说明还需要哪些具体片段。"
        }

        return base + "\n\n当前选中片段：\(selection)。回答应优先基于该片段，并可结合整篇上下文组织更完整结论。"
    }

    private func sendWithRetry(request: URLRequest) async throws -> (Data, URLResponse) {
        var lastError: Error?
        for attempt in 0...retryCount {
            do {
                return try await session.data(for: request)
            } catch {
                lastError = error
                let isLast = attempt == retryCount
                guard !isLast, isTransient(error) else {
                    throw error
                }
                let delay = UInt64((attempt + 1) * 400_000_000)
                try? await Task.sleep(nanoseconds: delay)
            }
        }
        throw lastError ?? PMError.network("\(providerName) LLM 请求失败")
    }

    private func isTransient(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost, .notConnectedToInternet:
            return true
        default:
            return false
        }
    }
}

private struct OpenAIChatRequest: Encodable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double
    let stream: Bool?
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

private struct OpenAIChatStreamChunk: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let delta: Delta
    }

    struct Delta: Decodable {
        let content: String?
    }
}
