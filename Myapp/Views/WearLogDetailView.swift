import SwiftUI
import UIKit

struct WearLogDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    let wearLogId: UUID
    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false

    var body: some View {
        ZStack {
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("編集") { showingEdit = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .accessibilityLabel("削除")
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .sheet(isPresented: $showingEdit) {
                NavigationStack {
                    if let log = store.wearLogs.first(where: { $0.id == wearLogId }) {
                        WearLogFormView(initialDay: log.day, editing: log)
                    } else {
                        Text("記録が見つかりません")
                    }
                }
            }

            if showingDeleteConfirm {
                DestructiveConfirmationDialog(
                    title: "この記録を削除しますか？",
                    message: "削除した記録は元に戻せません。",
                    cancelTitle: "キャンセル",
                    destructiveTitle: "削除する",
                    onCancel: {
                        showingDeleteConfirm = false
                    },
                    onConfirm: {
                        store.deleteWearLogs([wearLogId])
                        showingDeleteConfirm = false
                        dismiss()
                    }
                )
            }
        }
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
