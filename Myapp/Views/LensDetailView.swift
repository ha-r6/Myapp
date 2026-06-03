import SwiftUI

struct LensDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    let lensId: UUID
    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false

    var body: some View {
        ZStack {
            List {
                if let lens = store.lens(id: lensId) {
                    Section("基本") {
                        LabeledContent("名称") { Text(lens.displayName) }
                        LabeledContent("購入場所") { Text(lens.purchasePlace.isEmpty ? "—" : lens.purchasePlace) }
                    }

                    Section("スペック") {
                        LabeledContent("着色直径") { Text(lens.graphicDiameter.map { String(format: "%.1f", $0) } ?? "—") }
                        LabeledContent("BC") { Text(lens.bc.map { String(format: "%.1f", $0) } ?? "—") }
                        LabeledContent("DIA") { Text(lens.dia.map { String(format: "%.1f", $0) } ?? "—") }
                        LabeledContent("含水率") { Text(lens.waterContentCategory?.rawValue ?? "—") }
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
                                    Text(AppDateFormatters.day.string(from: log.day))
                                        .font(.headline)
                                        .frame(maxWidth: .infinity, alignment: .leading)
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

            if showingDeleteConfirm {
                DestructiveConfirmationDialog(
                    title: "このカラコンを削除しますか？",
                    message: "このカラコンに紐づく記録もすべて削除されます。",
                    cancelTitle: "キャンセル",
                    destructiveTitle: "削除する",
                    onCancel: {
                        showingDeleteConfirm = false
                    },
                    onConfirm: {
                        let relatedLogIds = store.wearLogs(for: lensId).map(\.id)
                        if relatedLogIds.isEmpty == false {
                            store.deleteWearLogs(relatedLogIds)
                        }
                        store.deleteLens(id: lensId)
                        showingDeleteConfirm = false
                        dismiss()
                    }
                )
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
