import SwiftUI
import UIKit

struct WearLogDetailView: View {
    @EnvironmentObject private var store: AppStore
    let wearLogId: UUID

    var body: some View {
        List {
            if let wearLog = store.wearLogs.first(where: { $0.id == wearLogId }) {
                Section("基本") {
                    LabeledContent("日付") { Text(AppDateFormatters.day.string(from: wearLog.day)) }
                    LabeledContent("レンズ") { Text(store.lens(id: wearLog.lensId)?.displayName ?? "（未設定）") }
                }

                Section("メモ") {
                    if wearLog.memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("—")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(wearLog.memo)
                    }
                }

                Section("着画（屋内）") {
                    PhotoDataView(data: wearLog.indoorPhotoData)
                }

                Section("着画（屋外）") {
                    PhotoDataView(data: wearLog.outdoorPhotoData)
                }
            } else {
                ContentUnavailableView("記録が見つかりません", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle("記録詳細")
        .scrollContentBackground(.hidden)
        .background(AppTheme.subtleBackgroundGradient)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
    }
}

private struct PhotoDataView: View {
    let data: Data?

    var body: some View {
        if let data, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            Text("—")
                .foregroundStyle(.secondary)
        }
    }
}

// Previews are intentionally omitted in this repository environment.
