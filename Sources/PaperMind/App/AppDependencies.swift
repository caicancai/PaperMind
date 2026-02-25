import Foundation

struct AppDependencies {
    var paperRepository: PaperRepository
    var noteRepository: NoteRepository
    var translationService: TranslationService
    var llmService: LLMService
    var paperContextBuilder: PaperContextBuilderService
    var aiSettingsStore: AISettingsStore
    var environment: [String: String]

    static func makeLive() -> AppDependencies {
        let baseURL = AppDirectories.appSupportDirectory()
        let store = JSONFileStore()
        let env = ProcessInfo.processInfo.environment
        let aiSettingsStore = AISettingsStore(store: store, fileURL: baseURL.appendingPathComponent("ai-settings.json"))
        let mockTranslation = MockTranslationService()
        let translationService = FallbackTranslationService(
            primary: GoogleTranslationService(),
            fallback: mockTranslation
        )

        let aiSettings = resolveInitialSettings(store: aiSettingsStore, env: env)
        let llmService = makeLLMService(settings: aiSettings, env: env)

        return AppDependencies(
            paperRepository: JSONPaperRepository(store: store, fileURL: baseURL.appendingPathComponent("papers.json")),
            noteRepository: JSONNoteRepository(store: store, fileURL: baseURL.appendingPathComponent("notes.json")),
            translationService: translationService,
            llmService: llmService,
            paperContextBuilder: PDFPaperContextBuilderService(),
            aiSettingsStore: aiSettingsStore,
            environment: env
        )
    }

    func loadAISettings() -> AISettings {
        (try? aiSettingsStore.load()) ?? .default
    }

    func saveAISettings(_ settings: AISettings) throws {
        try aiSettingsStore.save(settings)
    }

    func makeLLMService(settings: AISettings) -> LLMService {
        Self.makeLLMService(settings: settings, env: environment)
    }

    private static func makeLLMService(settings: AISettings, env: [String: String]) -> LLMService {
        if settings.provider == .auto {
            for provider in [AIProvider.openai, .deepseek, .kimi] {
                if let service = buildProvider(provider: provider, settings: settings, env: env) {
                    return service
                }
            }
            return UnavailableLLMService(
                reason: "未对接 AI：请在设置中配置 API Key（OpenAI / DeepSeek / Kimi）"
            )
        }

        if let service = buildProvider(provider: settings.provider, settings: settings, env: env) {
            return service
        }

        return UnavailableLLMService(reason: unavailableReason(for: settings.provider))
    }

    private static func buildProvider(provider: AIProvider, settings: AISettings, env: [String: String]) -> LLMService? {
        let apiKey = resolveAPIKey(for: provider, settings: settings, env: env)
        guard let key = cleanKey(apiKey) else { return nil }

        switch provider {
        case .openai:
            let model = cleanModel(settings.openAIModel, env["OPENAI_MODEL"], fallback: "gpt-4o-mini")
            let timeout = Double(env["OPENAI_TIMEOUT_SECONDS"] ?? "") ?? 40
            return OpenAILLMService(
                providerName: "openai",
                apiKey: key,
                model: model,
                endpoint: URL(string: "https://api.openai.com/v1/chat/completions")!,
                timeoutSeconds: timeout
            )
        case .deepseek:
            let model = cleanModel(settings.deepSeekModel, env["DEEPSEEK_MODEL"], fallback: "deepseek-chat")
            let timeout = Double(env["DEEPSEEK_TIMEOUT_SECONDS"] ?? "") ?? 60
            return OpenAILLMService(
                providerName: "deepseek",
                apiKey: key,
                model: model,
                endpoint: URL(string: "https://api.deepseek.com/v1/chat/completions")!,
                timeoutSeconds: timeout
            )
        case .kimi:
            let model = cleanModel(settings.kimiModel, env["KIMI_MODEL"], fallback: "kimi-2.5")
            let timeout = Double(env["KIMI_TIMEOUT_SECONDS"] ?? "") ?? 40
            return OpenAILLMService(
                providerName: "kimi",
                apiKey: key,
                model: model,
                endpoint: URL(string: "https://api.moonshot.cn/v1/chat/completions")!,
                timeoutSeconds: timeout
            )
        case .auto:
            return nil
        }
    }

    private static func resolveInitialSettings(store: AISettingsStore, env: [String: String]) -> AISettings {
        if let persisted = try? store.load() {
            return persisted
        }

        let settings = AISettings(
            provider: .auto,
            theme: .light,
            openAIModel: AISettings.default.openAIModel,
            deepSeekModel: AISettings.default.deepSeekModel,
            kimiModel: AISettings.default.kimiModel,
            openAIAPIKey: "",
            deepSeekAPIKey: "",
            kimiAPIKey: ""
        )

        try? store.save(settings)
        return settings
    }

    private static func resolveAPIKey(for provider: AIProvider, settings: AISettings, env: [String: String]) -> String? {
        _ = env
        switch provider {
        case .openai:
            return cleanKey(settings.openAIAPIKey)
        case .deepseek:
            return cleanKey(settings.deepSeekAPIKey)
        case .kimi:
            return cleanKey(settings.kimiAPIKey)
        case .auto:
            return nil
        }
    }

    private static func cleanKey(_ value: String?) -> String? {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    private static func cleanModel(_ preferred: String?, _ fallbackValue: String?, fallback: String) -> String {
        if let preferred = preferred?.trimmingCharacters(in: .whitespacesAndNewlines), !preferred.isEmpty {
            return preferred
        }
        if let fallbackValue = fallbackValue?.trimmingCharacters(in: .whitespacesAndNewlines), !fallbackValue.isEmpty {
            return fallbackValue
        }
        return fallback
    }

    private static func unavailableReason(for provider: AIProvider) -> String {
        switch provider {
        case .openai:
            return "未对接 AI：缺少 OpenAI API Key"
        case .deepseek:
            return "未对接 AI：缺少 DeepSeek API Key"
        case .kimi:
            return "未对接 AI：缺少 Kimi API Key"
        case .auto:
            return "未对接 AI：请先配置至少一个 Provider 的 API Key"
        }
    }

}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
