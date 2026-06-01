import SwiftUI

struct LensDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    let lensId: UUID
    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false

    var body: some View {
        List {
            if let lens = store.lens(id: lensId) {
                Section("基本") {
                    LabeledContent("名称") { Text(lens.displayName) }
                    LabeledContent("購入場所") { Text(lens.purchasePlace.isEmpty ? "—" : lens.purchasePlace) }
                }

                Section("スペック") {
                    LabeledContent("BC") { Text(lens.bc.map { String(format: "%.1f", $0) } ?? "—") }
                    LabeledContent("DIA") { Text(lens.dia.map { String(format: "%.1f", $0) } ?? "—") }
                    LabeledContent("着色直径") { Text(lens.graphicDiameter.map { String(format: "%.1f", $0) } ?? "—") }
                    LabeledContent("度あり/なし") { Text(lens.isPrescription ? "度あり" : "度なし") }
                    if lens.isPrescription {
                        LabeledContent("度数") {
                            Text(powerDisplayText(for: lens))
                        }
                    }
                    LabeledContent("使用期間") {
                        if let days = lens.replacementDays {
                            Text(replacementLabel(days: days))
                        } else {
                            Text("—")
                        }
                    }
                }

                Section("リピ") {
                    LabeledContent("判断") { Text(lens.repeatDecision.rawValue) }
                    if !lens.repeatMemo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(lens.repeatMemo)
                    }
                }

                Section("メモ") {
                    if lens.memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("—")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(lens.memo)
                    }
                }

                Section("装着記録") {
                    let logs = store.wearLogs(for: lensId)
                    if logs.isEmpty {
                        Text("まだ記録がありません")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(logs) { log in
                            NavigationLink {
                                WearLogDetailView(wearLogId: log.id)
                            } label: {
                                WearLogRow(wearLog: log)
                                    .appCard()
                            }
                        }
                        .onDelete { indexSet in
                            let ids = indexSet.map { logs[$0].id }
                            store.deleteWearLogs(ids)
                        }
                    }
                }
            } else {
                ContentUnavailableView("レンズが見つかりません", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle("レンズ詳細")
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
        .alert("このカラコンを削除しますか？", isPresented: $showingDeleteConfirm) {
            Button("キャンセル", role: .cancel) {}
            Button("削除する", role: .destructive) {
                let relatedLogIds = store.wearLogs(for: lensId).map(\.id)
                if relatedLogIds.isEmpty == false {
                    store.deleteWearLogs(relatedLogIds)
                }
                store.deleteLens(id: lensId)
                dismiss()
            }
        } message: {
            Text("このカラコンに紐づく記録もすべて削除されます。")
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .sheet(isPresented: $showingEdit) {
            NavigationStack {
                if let lens = store.lens(id: lensId) {
                    LensFormView(editing: lens)
                } else {
                    Text("レンズが見つかりません")
                }
            }
        }
    }

    private func powerDisplayText(for lens: Lens) -> String {
        let left = lens.leftPower ?? lens.power
        let right = lens.rightPower ?? lens.power
        if let left, let right {
            return "左 \(String(format: "%.2f", left)) / 右 \(String(format: "%.2f", right))"
        }
        if let left { return "左 \(String(format: "%.2f", left))" }
        if let right { return "右 \(String(format: "%.2f", right))" }
        return "—"
    }

    private func replacementLabel(days: Int) -> String {
        switch days {
        case 1: return "1day"
        case 14: return "2weeks"
        case 30: return "1month"
        default: return "\(days)日"
        }
    }
}

// Previews are intentionally omitted in this repository environment.
