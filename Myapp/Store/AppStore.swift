import Foundation
import Combine

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var lenses: [Lens] = []
    @Published private(set) var wearLogs: [WearLog] = []

    private let saveURL: URL

    init(saveURL: URL? = nil) {
        if let saveURL {
            self.saveURL = saveURL
        } else {
            self.saveURL = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)
                .first!
                .appendingPathComponent("colorcon_store.json")
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

    // MARK: - Mutations (WearLog)

    func addWearLog(_ log: WearLog) {
        wearLogs.insert(log, at: 0)
        updateStickerImageIfNeeded(from: log)
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

    private func updateStickerImageIfNeeded(from log: WearLog) {
        guard let lensId = log.lensId else { return }
        guard let index = lenses.firstIndex(where: { $0.id == lensId }) else { return }
        guard lenses[index].stickerEyeJPEG == nil else { return }

        // すでに切り抜かれたデータが入っている想定（なければ元画像のまま）
        let candidate = log.indoorPhotoData ?? log.outdoorPhotoData
        guard let candidate else { return }
        lenses[index].stickerEyeJPEG = candidate
    }
}
