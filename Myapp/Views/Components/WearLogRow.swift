import SwiftUI

struct WearLogRow: View {
    let wearLog: WearLog
    @EnvironmentObject private var store: AppStore

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppDateFormatters.day.string(from: wearLog.day))
                    .font(.headline)
                Text(store.lens(id: wearLog.lensId)?.displayName ?? "（レンズ未選択）")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if wearLog.indoorPhotoData != nil || wearLog.outdoorPhotoData != nil {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// Previews are intentionally omitted in this repository environment.
