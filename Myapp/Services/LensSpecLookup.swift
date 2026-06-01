import Foundation

struct LensSpecLookupResult: Codable, Hashable {
    var brand: String?
    var bc: Double?
    var dia: Double?
    var graphicDiameter: Double?
    var waterContentPercent: Double?
    var replacementDays: Int?
    var quantity: Int?

    var sourceURL: String?
    var note: String?
}

enum LensSpecLookupError: Error, LocalizedError {
    case endpointNotConfigured
    case invalidEndpoint
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .endpointNotConfigured:
            "自動入力は現在利用できません（開発者設定が未設定です）"
        case .invalidEndpoint:
            "自動入力の接続先が正しくありません"
        case .invalidResponse:
            "自動入力の結果を読み取れませんでした"
        }
    }
}

struct LensSpecLookupClient {
    /// `endpoint` は例: `https://your-domain.example/api/lens-lookup`
    /// レスポンスは `LensSpecLookupResult` のJSONを想定します。
    let endpoint: String

    func lookup(query: String) async throws -> LensSpecLookupResult {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return LensSpecLookupResult()
        }

        let endpointTrimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        if endpointTrimmed.isEmpty {
            throw LensSpecLookupError.endpointNotConfigured
        }
        guard var components = URLComponents(string: endpointTrimmed) else {
            throw LensSpecLookupError.invalidEndpoint
        }

        var items = components.queryItems ?? []
        items.removeAll(where: { $0.name == "q" })
        items.append(URLQueryItem(name: "q", value: trimmed))
        components.queryItems = items

        guard let url = components.url else {
            throw LensSpecLookupError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw LensSpecLookupError.invalidResponse
        }
        guard let decoded = try? JSONDecoder().decode(LensSpecLookupResult.self, from: data) else {
            throw LensSpecLookupError.invalidResponse
        }
        return decoded
    }
}
