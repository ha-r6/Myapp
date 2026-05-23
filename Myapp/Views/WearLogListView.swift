import SwiftUI

struct WearLogListView: View {
    @EnvironmentObject private var store: AppStore

    @State private var showingAdd = false

    var body: some View {
        List {
            let logs = store.wearLogs.sorted(by: { $0.day > $1.day })
            if logs.isEmpty {
                ContentUnavailableView(
                    "記録がありません",
                    systemImage: "list.bullet.rectangle",
                    description: Text("装着した日を記録すると、後で写真を見返しやすくなります。")
                )
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
        .navigationTitle("記録")
        .scrollContentBackground(.hidden)
        .background(AppTheme.subtleBackgroundGradient)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Label("追加", systemImage: "plus")
                }
            }
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .sheet(isPresented: $showingAdd) {
            NavigationStack {
                WearLogFormView(initialDay: Calendar.current.startOfDay(for: .now))
            }
        }
    }
}

// Previews are intentionally omitted in this repository environment.
