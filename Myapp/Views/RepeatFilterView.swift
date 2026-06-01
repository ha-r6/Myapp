import SwiftUI

struct RepeatFilterView: View {
    @EnvironmentObject private var store: AppStore

    @State private var selection: RepeatDecision = .yes
    private let columns = [
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 14),
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 14),
    ]

    private var filtered: [Lens] {
        store.lenses.filter { $0.repeatDecision == selection }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                StickerPageHeaderView(
                    title: "リピ判定",
                    subtitle: "リピあり / リピなし / 迷う をサクッと見返せます。"
                )

                Picker("絞り込み", selection: $selection) {
                    Text(RepeatDecision.yes.rawValue).tag(RepeatDecision.yes)
                    Text(RepeatDecision.no.rawValue).tag(RepeatDecision.no)
                    Text(RepeatDecision.maybe.rawValue).tag(RepeatDecision.maybe)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                if filtered.isEmpty {
                    ContentUnavailableView("該当するレンズがありません", systemImage: "line.3.horizontal.decrease.circle")
                        .padding(.top, 24)
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(filtered) { lens in
                            NavigationLink {
                                LensDetailView(lensId: lens.id)
                            } label: {
                                LensStickerCard(lens: lens)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(StickerBackgroundView())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}
