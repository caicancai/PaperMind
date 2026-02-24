import Foundation

enum AppDirectories {
    static func appSupportDirectory() -> URL {
        let fallback = FileManager.default.temporaryDirectory.appendingPathComponent("PaperMind", isDirectory: true)

        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return fallback
        }

        return base.appendingPathComponent("PaperMind", isDirectory: true)
    }
}
