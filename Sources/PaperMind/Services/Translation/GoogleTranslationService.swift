import Foundation

struct GoogleTranslationService: TranslationService {
    private let session: URLSession
    private let timeoutSeconds: TimeInterval

    init(session: URLSession = .shared, timeoutSeconds: TimeInterval = 8) {
        self.session = session
        self.timeoutSeconds = timeoutSeconds
    }

    func translate(text: String, source: String?, target: String) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PMError.invalidInput("请选择需要翻译的文本")
        }

        var components = URLComponents(string: "https://translate.googleapis.com/translate_a/single")
        components?.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: (source?.isEmpty == false ? source : "auto")),
            URLQueryItem(name: "tl", value: target),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: trimmed)
        ]

        guard let url = components?.url else {
            throw PMError.network("翻译请求 URL 无效")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeoutSeconds
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PMError.network("Google 翻译请求失败")
        }

        guard let translated = Self.parseGoogleResponse(data: data) else {
            throw PMError.network("Google 翻译响应解析失败")
        }

        return translated
    }

    static func parseGoogleResponse(data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let top = json.first as? [Any] else {
            return nil
        }

        let parts: [String] = top.compactMap { item in
            guard let tuple = item as? [Any],
                  let translated = tuple.first as? String else {
                return nil
            }
            return translated
        }

        let text = parts.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
