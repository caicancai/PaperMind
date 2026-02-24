import Foundation

final class JSONFileStore {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func load<T: Codable>(_ type: T.Type, from url: URL, defaultValue: T) throws -> T {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: url.path) {
            return defaultValue
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode(type, from: data)
    }

    func save<T: Codable>(_ value: T, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }
}
