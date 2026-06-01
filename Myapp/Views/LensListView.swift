import SwiftUI

struct LensListView: View {
    @EnvironmentObject private var store: AppStore

    @State private var showingAdd = false
    @State private var selectedSuggestion: LensSuggestion? = nil

    var body: some View {
        Group {
            if store.lenses.isEmpty {
                ScrollView {
                    VStack(spacing: 14) {
                        StickerPageHeaderView(
                            title: "図鑑"
                        )
                        ContentUnavailableView(
                            "レンズがありません",
                            systemImage: "circle.dotted",
                            description: Text("まずは購入したカラコンを登録しましょう。")
                        )
                        .padding(.top, 24)
                    }
                }
                .background(StickerBackgroundView())
            } else {
                LensStickerGridView(
                    lenses: store.lenses,
                    onDelete: { indexSet in store.deleteLenses(at: indexSet) }
                )
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Label("追加", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack {
                LensFormView(prefillSuggestion: selectedSuggestion)
            }
            .onDisappear { selectedSuggestion = nil }
        }
    }
}

// Previews are intentionally omitted in this repository environment.

struct LensSuggestion: Identifiable, Hashable {
    let id: String
    let brand: String
    let productName: String
    let colorName: String
    let replacementDays: Int?
    let isPrescription: Bool

    init(from lens: Lens) {
        self.brand = lens.brand.trimmingCharacters(in: .whitespacesAndNewlines)
        self.productName = lens.productName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.colorName = lens.colorName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.replacementDays = lens.replacementDays
        self.isPrescription = lens.isPrescription
        self.id = "\(brand)|\(productName)|\(colorName)|\(replacementDays ?? 0)|\(isPrescription)"
    }

    var title: String {
        let merged = [brand, productName].filter { $0.isEmpty == false }.joined(separator: " ")
        return merged.isEmpty ? "（名称未設定）" : merged
    }

    var subtitle: String {
        var details: [String] = []
        if colorName.isEmpty == false { details.append(colorName) }
        if let days = replacementDays { details.append("\(days)日") }
        details.append(isPrescription ? "度あり" : "度なし")
        return details.joined(separator: " / ")
    }
}
