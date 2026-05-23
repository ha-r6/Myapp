import Foundation
struct WearLog: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var createdAt: Date = .now

    /// Calendar.current.startOfDay(for:) を入れる（1日の記録をまとめやすくする）
    var day: Date

    var lensId: UUID? = nil
    var memo: String = ""

    var indoorPhotoData: Data? = nil
    var outdoorPhotoData: Data? = nil
}
