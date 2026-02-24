import Foundation

struct AppDependencies {
    var paperRepository: PaperRepository
    var noteRepository: NoteRepository
    var translationService: TranslationService
    var llmService: LLMService
    var paperContextBuilder: PaperContextBuilderService

    static func makeLive() -> AppDependencies {
        let baseURL = AppDirectories.appSupportDirectory()
        let store = JSONFileStore()
        let mockTranslation = MockTranslationService()
        let translationService = FallbackTranslationService(
            primary: GoogleTranslationService(),
            fallback: mockTranslation
        )

        let llmService = makeLLMService()

        return AppDependencies(
            paperRepository: JSONPaperRepository(store: store, fileURL: baseURL.appendingPathComponent("papers.json")),
            noteRepository: JSONNoteRepository(store: store, fileURL: baseURL.appendingPathComponent("notes.json")),
            translationService: translationService,
            llmService: llmService,
            paperContextBuilder: PDFPaperContextBuilderService()
        )
    }

    private static func makeLLMService() -> LLMService {
        let env = effectiveEnvironment()
        let requested = env["AI_PROVIDER"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "auto"

        if requested == "auto" {
            for provider in ["openai", "deepseek", "kimi"] {
                if let service = buildProvider(provider: provider, env: env) {
                    return service
                }
            }
            return UnavailableLLMService(
                reason: "未对接 AI：请配置 AI_PROVIDER 与对应 API Key（OPENAI_API_KEY / DEEPSEEK_API_KEY / KIMI_API_KEY）"
            )
        }

        if let service = buildProvider(provider: requested, env: env) {
            return service
        }

        return UnavailableLLMService(reason: unavailableReason(for: requested))
    }

    private static func buildProvider(provider: String, env: [String: String]) -> LLMService? {
        switch provider {
        case "openai":
            guard let key = cleanKey(env["OPENAI_API_KEY"]) else { return nil }
            let model = env["OPENAI_MODEL"]?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "gpt-4o-mini"
            let timeout = Double(env["OPENAI_TIMEOUT_SECONDS"] ?? "") ?? 40
            return OpenAILLMService(
                providerName: "openai",
                apiKey: key,
                model: model,
                endpoint: URL(string: "https://api.openai.com/v1/chat/completions")!,
                timeoutSeconds: timeout
            )
        case "deepseek":
            guard let key = cleanKey(env["DEEPSEEK_API_KEY"]) else { return nil }
            let model = env["DEEPSEEK_MODEL"]?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "deepseek-chat"
            let timeout = Double(env["DEEPSEEK_TIMEOUT_SECONDS"] ?? "") ?? 60
            return OpenAILLMService(
                providerName: "deepseek",
                apiKey: key,
                model: model,
                endpoint: URL(string: "https://api.deepseek.com/chat/completions")!,
                timeoutSeconds: timeout
            )
        case "kimi":
            guard let key = cleanKey(env["KIMI_API_KEY"]) else { return nil }
            let model = env["KIMI_MODEL"]?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "moonshot-v1-8k"
            let timeout = Double(env["KIMI_TIMEOUT_SECONDS"] ?? "") ?? 40
            return OpenAILLMService(
                providerName: "kimi",
                apiKey: key,
                model: model,
                endpoint: URL(string: "https://api.moonshot.cn/v1/chat/completions")!,
                timeoutSeconds: timeout
            )
        default:
            return nil
        }
    }

    private static func cleanKey(_ value: String?) -> String? {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    private static func unavailableReason(for provider: String) -> String {
        switch provider {
        case "openai":
            return "未对接 AI：缺少 OPENAI_API_KEY（可选 OPENAI_MODEL）"
        case "deepseek":
            return "未对接 AI：缺少 DEEPSEEK_API_KEY（可选 DEEPSEEK_MODEL）"
        case "kimi":
            return "未对接 AI：缺少 KIMI_API_KEY（可选 KIMI_MODEL）"
        default:
            return "未对接 AI：不支持的 AI_PROVIDER=\(provider)，可选 openai/deepseek/kimi/auto"
        }
    }

    private static func effectiveEnvironment() -> [String: String] {
        let runtime = ProcessInfo.processInfo.environment
        let local = LocalEnvLoader.load(candidates: envCandidateURLs())
        return runtime.merging(local) { current, _ in current }
    }

    private static func envCandidateURLs() -> [URL] {
        var urls: [URL] = []
        let fileManager = FileManager.default

        let cwd = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        urls.append(cwd.appendingPathComponent(".env.local"))

        let execURL = URL(fileURLWithPath: CommandLine.arguments.first ?? fileManager.currentDirectoryPath, isDirectory: false)
        var base = execURL.deletingLastPathComponent()
        for _ in 0..<6 {
            urls.append(base.appendingPathComponent(".env.local"))
            let parent = base.deletingLastPathComponent()
            if parent.path == base.path { break }
            base = parent
        }

        return urls
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}

private enum LocalEnvLoader {
    static func load(candidates: [URL]) -> [String: String] {
        for url in candidates {
            if let parsed = parseSingleFile(url: url) {
                return parsed
            }
        }
        return [:]
    }

    private static func parseSingleFile(url: URL) -> [String: String]? {
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }

        var values: [String: String] = [:]
        for rawLine in content.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") { continue }

            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }

            let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            var value = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
                value.removeFirst()
                value.removeLast()
            }
            if !key.isEmpty {
                values[key] = value
            }
        }

        return values
    }
}
