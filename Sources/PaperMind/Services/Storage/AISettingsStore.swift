import Foundation

final class AISettingsStore {
    private let store: JSONFileStore
    private let fileURL: URL

    init(store: JSONFileStore, fileURL: URL) {
        self.store = store
        self.fileURL = fileURL
    }

    func load() throws -> AISettings {
        try store.load(AISettings.self, from: fileURL, defaultValue: .default)
    }

    func save(_ settings: AISettings) throws {
        try store.save(settings, to: fileURL)
    }
}
