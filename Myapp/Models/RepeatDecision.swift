import Foundation

enum RepeatDecision: String, CaseIterable, Identifiable, Codable {
    case yes = "リピあり"
    case no = "リピなし"
    case maybe = "迷う"

    var id: String { rawValue }
}

