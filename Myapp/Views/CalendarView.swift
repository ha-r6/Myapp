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
                                if let lensId = log.lensId, let lens = store.lens(id: lensId) {
                                    CalendarLensCard(lens: lens)
                                } else {
                                    UnselectedLensCard()
                                }
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

private struct UnselectedLensCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "circle.dotted")
                    .foregroundStyle(.secondary)
                Text("レンズ未選択")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
            }
            Text("図鑑から選ぶと、カードで見返しやすくなります。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.surface)
        )
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.black.opacity(0.10), lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
    }
}

private struct CalendarLensCard: View {
    let lens: Lens

    var body: some View {
        LensStickerCard(lens: lens)
            .scaleEffect(0.92)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
    }
}
