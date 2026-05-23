import SwiftUI

struct LensListView: View {
    @EnvironmentObject private var store: AppStore

    @State private var showingAdd = false

    var body: some View {
        Group {
            if store.lenses.isEmpty {
                ScrollView {
                    VStack(spacing: 14) {
                        StickerHeaderViewInline()
                        ContentUnavailableView(
                            "レンズがありません",
                            systemImage: "circle.dotted",
                            description: Text("まずは購入したカラコンを登録しましょう。")
                        )
                        .padding(.top, 24)
                    }
                }
                .background(AppTheme.background)
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
                LensFormView()
            }
        }
    }
}

// Previews are intentionally omitted in this repository environment.

private struct StickerHeaderViewInline: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("レンズ")
                .font(.title.bold())
            Text("シール帳みたいに、購入したカラコンを並べて見返せます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }
}
