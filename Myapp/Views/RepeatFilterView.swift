import SwiftUI

struct RepeatFilterView: View {
    @EnvironmentObject private var store: AppStore

    @State private var selection: RepeatDecision = .yes

    private var filtered: [Lens] {
        store.lenses.filter { $0.repeatDecision == selection }
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("リピ判定")
                    .font(.title.bold())
                Text("リピあり / リピなし / 迷う をサクッと見返せます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 14)

            Picker("絞り込み", selection: $selection) {
                Text(RepeatDecision.yes.rawValue).tag(RepeatDecision.yes)
                Text(RepeatDecision.no.rawValue).tag(RepeatDecision.no)
                Text(RepeatDecision.maybe.rawValue).tag(RepeatDecision.maybe)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)

            if filtered.isEmpty {
                Spacer(minLength: 0)
                ContentUnavailableView("該当するレンズがありません", systemImage: "line.3.horizontal.decrease.circle")
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filtered) { lens in
                            NavigationLink {
                                LensDetailView(lensId: lens.id)
                            } label: {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(AppTheme.pastelColor(seed: lens.id.uuidString).opacity(0.25))
                                        .overlay(
                                            Image(systemName: "arrow.triangle.2.circlepath")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(AppTheme.accent)
                                        )
                                        .frame(width: 34, height: 34)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(lens.displayName)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                            .lineLimit(2)
                                        if !lens.repeatMemo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            Text(lens.repeatMemo)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                    Spacer()
                                }
                                .appCard()
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(AppTheme.subtleBackgroundGradient.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
    }
}

