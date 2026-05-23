import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var store: AppStore

    @State private var selectedDay: Date = Calendar.current.startOfDay(for: .now)
    @State private var showingAdd = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("カレンダー")
                        .font(.title.bold())
                    Text("装着した日を記録して、あとで写真を見返しやすく。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 14)

                DatePicker(
                    "日付",
                    selection: $selectedDay,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal, 16)
                .appCard()
                .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 10) {
                    Text("この日の記録")
                        .font(.headline)

                    let logs = store.wearLogs(for: selectedDay)
                    if logs.isEmpty {
                        ContentUnavailableView("記録がありません", systemImage: "calendar.badge.clock")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(logs) { log in
                            NavigationLink {
                                WearLogDetailView(wearLogId: log.id)
                            } label: {
                                WearLogRow(wearLog: log)
                                    .appCard()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("カレンダー")
        .background(AppTheme.subtleBackgroundGradient.ignoresSafeArea())
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
                WearLogFormView(initialDay: selectedDay)
            }
        }
    }
}

// Previews are intentionally omitted in this repository environment.
