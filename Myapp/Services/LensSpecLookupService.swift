import Foundation

struct LensSpecLookupResult: Decodable {
    let brand: String?
    let bc: Double?
    let dia: Double?
    let graphicDiameter: Double?
    let waterContentPercent: Double?
    let replacementDays: Int?
    let quantity: Int?
    let sourceURL: String?
    let note: String?

    private enum CodingKeys: String, CodingKey {
        case brand
        case bc
        case dia
        case graphicDiameter
        case waterContentPercent
        case replacementDays
        case quantity
        case sourceURL
        case note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        brand = try Self.decodeString(forKey: .brand, container: container)
        bc = try Self.decodeDouble(forKey: .bc, container: container)
        dia = try Self.decodeDouble(forKey: .dia, container: container)
        graphicDiameter = try Self.decodeDouble(forKey: .graphicDiameter, container: container)
        waterContentPercent = try Self.decodeDouble(forKey: .waterContentPercent, container: container)
        replacementDays = try Self.decodeInt(forKey: .replacementDays, container: container)
        quantity = try Self.decodeInt(forKey: .quantity, container: container)
        sourceURL = try Self.decodeString(forKey: .sourceURL, container: container)
        note = try Self.decodeString(forKey: .note, container: container)
    }

    private static func decodeString(forKey key: CodingKeys, container: KeyedDecodingContainer<CodingKeys>) throws -> String? {
        if let value = try container.decodeIfPresent(String.self, forKey: key) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    private static func decodeDouble(forKey key: CodingKeys, container: KeyedDecodingContainer<CodingKeys>) throws -> Double? {
        if let value = try container.decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let value = try container.decodeIfPresent(String.self, forKey: key) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return Double(trimmed)
        }
        return nil
    }

    private static func decodeInt(forKey key: CodingKeys, container: KeyedDecodingContainer<CodingKeys>) throws -> Int? {
        if let value = try container.decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try container.decodeIfPresent(Double.self, forKey: key) {
            return Int(value)
        }
        if let value = try container.decodeIfPresent(String.self, forKey: key) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return Int(trimmed)
        }
        return nil
    }
}

enum LensSpecLookupServiceError: LocalizedError {
    case missingEndpoint
    case missingQuery
    case invalidEndpoint
    case invalidResponse
    case httpStatus(Int, String?)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .missingEndpoint:
            return "AIエンドポイントが未設定です。"
        case .missingQuery:
            return "検索する文字がありません。"
        case .invalidEndpoint:
            return "AIエンドポイントのURLが正しくありません。"
        case .invalidResponse:
            return "AIサーバーからの応答を読み取れませんでした。"
        case .httpStatus(let status, let body):
            if let body, body.isEmpty == false {
                return "AIサーバーでエラーが発生しました（\(status)）。\(body)"
            }
            return "AIサーバーでエラーが発生しました（\(status)）。"
        case .decodingFailed:
            return "AIの返答をスペックとして読み取れませんでした。"
        }
    }
}

enum LensSpecLookupService {
    static func lookup(endpoint: String, query: String, colorName: String? = nil) async throws -> LensSpecLookupResult {
        let trimmedEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedEndpoint.isEmpty == false else {
            throw LensSpecLookupServiceError.missingEndpoint
        }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else {
            throw LensSpecLookupServiceError.missingQuery
        }

        guard var components = URLComponents(string: trimmedEndpoint) else {
            throw LensSpecLookupServiceError.invalidEndpoint
        }

        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "q", value: trimmedQuery))
        if let colorName {
            let trimmedColor = colorName.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedColor.isEmpty == false {
                queryItems.append(URLQueryItem(name: "colorName", value: trimmedColor))
            }
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw LensSpecLookupServiceError.invalidEndpoint
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LensSpecLookupServiceError.invalidResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            let body = String(data: data, encoding: .utf8)
            throw LensSpecLookupServiceError.httpStatus(httpResponse.statusCode, body)
        }

        do {
            return try JSONDecoder().decode(LensSpecLookupResult.self, from: data)
        } catch {
            throw LensSpecLookupServiceError.decodingFailed
        }
    }
}
