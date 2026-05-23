import Foundation

enum LensColorCategory: String, CaseIterable, Identifiable, Codable {
    case all = "すべて"
    case brown = "ブラウン系"
    case gray = "グレー系"
    case olive = "オリーブ系"
    case other = "その他"

    var id: String { rawValue }
}

struct Lens: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var createdAt: Date = .now

    var brand: String = ""
    var productName: String = ""
    var colorName: String = ""

    var colorCategoryRaw: String = LensColorCategory.other.rawValue

    var bc: Double? = nil
    var dia: Double? = nil
    var graphicDiameter: Double? = nil

    var isPrescription: Bool = false
    var power: Double? = nil
    var replacementDays: Int? = nil

    var purchasePlace: String = ""

    var repeatDecisionRaw: String = RepeatDecision.maybe.rawValue
    var repeatMemo: String = ""

    var memo: String = ""

    /// レンズ一覧（シール帳）で使う代表画像（目の切り抜き）
    var stickerEyeJPEG: Data? = nil

    var displayName: String {
        let base = [brand.trimmedOrNil, productName.trimmedOrNil].compactMap { $0 }.joined(separator: " ")
        if colorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return base.isEmpty ? "（名称未設定）" : base
        }
        return base.isEmpty ? colorName : "\(base) / \(colorName)"
    }

    var repeatDecision: RepeatDecision {
        get { RepeatDecision(rawValue: repeatDecisionRaw) ?? .maybe }
        set { repeatDecisionRaw = newValue.rawValue }
    }

    var colorCategory: LensColorCategory {
        get { LensColorCategory(rawValue: colorCategoryRaw) ?? .other }
        set { colorCategoryRaw = newValue.rawValue }
    }
}

private extension String {
    var trimmedOrNil: String? {
        let s = trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? nil : s
    }
}
