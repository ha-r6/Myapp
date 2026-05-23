import SwiftUI

struct LensDetailView: View {
    @EnvironmentObject private var store: AppStore

    let lensId: UUID
    @State private var showingEdit = false

    var body: some View {
        List {
            if let lens = store.lens(id: lensId) {
                Section("基本") {
                    LabeledContent("名称") { Text(lens.displayName) }
                    LabeledContent("購入場所") { Text(lens.purchasePlace.isEmpty ? "—" : lens.purchasePlace) }
                }

                Section("スペック") {
                    LabeledContent("BC") { Text(lens.bc.map { String(format: "%.2f", $0) } ?? "—") }
                    LabeledContent("DIA") { Text(lens.dia.map { String(format: "%.2f", $0) } ?? "—") }
                    LabeledContent("着色直径") { Text(lens.graphicDiameter.map { String(format: "%.2f", $0) } ?? "—") }
                    LabeledContent("度あり/なし") { Text(lens.isPrescription ? "度あり" : "度なし") }
                    if lens.isPrescription {
                        LabeledContent("度数") { Text(lens.power.map { String(format: "%.2f", $0) } ?? "—") }
                    }
                    LabeledContent("使用期間") {
                        if let days = lens.replacementDays {
                            Text("\(days) 日")
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
}

// Previews are intentionally omitted in this repository environment.
