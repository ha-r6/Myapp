import Foundation
import SwiftUI

enum LensCardField: String, CaseIterable, Identifiable {
    case brand
    case productName
    case graphicDiameter
    case colorCategory
    case repeatDecision

    var id: String { rawValue }

    var label: String {
        switch self {
        case .brand: "ブランド"
        case .productName: "品名"
        case .graphicDiameter: "着色直径"
        case .colorCategory: "カラー分類"
        case .repeatDecision: "リピ判定"
        }
    }
}

enum LensCardSettingsKeys {
    static let enabledFields = "lensCardEnabledFields"
}

struct LensCardDisplaySettings {
    static let defaultEnabled: Set<LensCardField> = [.brand, .productName, .graphicDiameter, .colorCategory, .repeatDecision]

    static func enabledFields(from raw: String) -> Set<LensCardField> {
        let parts = raw.split(separator: ",").map { String($0) }
        let fields = parts.compactMap { LensCardField(rawValue: $0) }
        return Set(fields).isEmpty ? defaultEnabled : Set(fields)
    }

    static func serialize(_ fields: Set<LensCardField>) -> String {
        fields.map(\.rawValue).sorted().joined(separator: ",")
    }
}

