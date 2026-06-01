import Foundation
import Combine

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var lenses: [Lens] = []
    @Published private(set) var wearLogs: [WearLog] = []

    private let saveURL: URL
    static let appGroupId = "group.app.yamazaki.ha-san.Myapp"

    init(saveURL: URL? = nil) {
        if let saveURL {
            self.saveURL = saveURL
        } else {
            if let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupId) {
                self.saveURL = sharedURL.appendingPathComponent("colorcon_store.json")
            } else {
                self.saveURL = FileManager.default
                    .urls(for: .documentDirectory, in: .userDomainMask)
                    .first!
                    .appendingPathComponent("colorcon_store.json")
            }
        }
        load()
    }

    // MARK: - Query helpers

    func lens(id: UUID?) -> Lens? {
        guard let id else { return nil }
        return lenses.first(where: { $0.id == id })
    }

    func wearLogs(for day: Date) -> [WearLog] {
        let d = Calendar.current.startOfDay(for: day)
        return wearLogs
            .filter { $0.day == d }
            .sorted(by: { $0.createdAt > $1.createdAt })
    }

    func wearLogs(for lensId: UUID) -> [WearLog] {
        wearLogs
            .filter { $0.lensId == lensId }
            .sorted(by: { $0.day > $1.day })
    }

    // MARK: - Mutations (Lens)

    func upsertLens(_ lens: Lens) {
        if let index = lenses.firstIndex(where: { $0.id == lens.id }) {
            lenses[index] = lens
        } else {
            lenses.insert(lens, at: 0)
        }
        persist()
    }

    func deleteLenses(at offsets: IndexSet) {
        let ids = offsets.map { lenses[$0].id }
        for index in offsets.sorted(by: >) {
            lenses.remove(at: index)
        }
        // レンズ削除時は紐付く記録の lensId も外す（記録自体は残す）
        wearLogs = wearLogs.map { log in
            var updated = log
            if let lid = updated.lensId, ids.contains(lid) {
                updated.lensId = nil
            }
            return updated
        }
        persist()
    }

    func deleteLens(id: UUID) {
        guard let index = lenses.firstIndex(where: { $0.id == id }) else { return }
        deleteLenses(at: IndexSet(integer: index))
    }

    // MARK: - Mutations (WearLog)

    func addWearLog(_ log: WearLog) {
        wearLogs.insert(log, at: 0)
        persist()
    }

    func upsertWearLog(_ log: WearLog) {
        if let index = wearLogs.firstIndex(where: { $0.id == log.id }) {
            wearLogs[index] = log
        } else {
            wearLogs.insert(log, at: 0)
        }
        persist()
    }

    func deleteWearLogs(_ ids: [UUID]) {
        wearLogs.removeAll(where: { ids.contains($0.id) })
        persist()
    }

    // MARK: - Persistence

    private struct StorePayload: Codable {
        var lenses: [Lens]
        var wearLogs: [WearLog]
    }

    private func load() {
        migrateLegacyStoreIfNeeded()
        guard let data = try? Data(contentsOf: saveURL) else { return }
        guard let payload = try? JSONDecoder().decode(StorePayload.self, from: data) else { return }
        lenses = payload.lenses.sorted(by: { $0.createdAt > $1.createdAt })
        wearLogs = payload.wearLogs.sorted(by: { $0.day > $1.day })
    }

    private func persist() {
        let payload = StorePayload(lenses: lenses, wearLogs: wearLogs)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: saveURL, options: [.atomic])
    }

    private func migrateLegacyStoreIfNeeded() {
        guard FileManager.default.fileExists(atPath: saveURL.path) == false else { return }
        let legacy = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("colorcon_store.json")
        guard let legacy, FileManager.default.fileExists(atPath: legacy.path) else { return }
        try? FileManager.default.copyItem(at: legacy, to: saveURL)
    }

    // 図鑑の代表画像はレンズ登録時に設定した `stickerEyeJPEG` のみを使用する。
}
