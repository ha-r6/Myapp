import SwiftUI

struct LensFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    private let editingLens: Lens?

    @State private var brand: String = ""
    @State private var productName: String = ""
    @State private var colorName: String = ""
    @State private var purchasePlace: String = ""

    @State private var bcText: String = ""
    @State private var diaText: String = ""
    @State private var graphicDiameterText: String = ""

    @State private var colorCategory: LensColorCategory = .other

    @State private var isPrescription: Bool = false
    @State private var powerText: String = ""
    @State private var replacementDaysText: String = ""

    @State private var repeatDecision: RepeatDecision = .maybe
    @State private var repeatMemo: String = ""
    @State private var memo: String = ""

    init(editing: Lens? = nil) {
        self.editingLens = editing
    }

    var body: some View {
        Form {
            Section("名称") {
                TextField("ブランド", text: $brand)
                TextField("商品名", text: $productName)
                TextField("カラー", text: $colorName)
            }

            Section("カラー分類") {
                Picker("分類", selection: $colorCategory) {
                    ForEach(LensColorCategory.allCases.filter { $0 != .all }) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
            }

            Section("購入") {
                TextField("購入場所（例: Qoo10 / 楽天 / 店舗名）", text: $purchasePlace)
            }

            Section("スペック") {
                TextField("BC（例: 8.60）", text: $bcText)
                    .keyboardType(.decimalPad)
                TextField("DIA（例: 14.20）", text: $diaText)
                    .keyboardType(.decimalPad)
                TextField("着色直径（例: 13.20）", text: $graphicDiameterText)
                    .keyboardType(.decimalPad)

                Toggle("度あり", isOn: $isPrescription)
                if isPrescription {
                    TextField("度数（例: -3.25）", text: $powerText)
                        .keyboardType(.numbersAndPunctuation)
                }
                TextField("使用期間（日数。例: 30）", text: $replacementDaysText)
                    .keyboardType(.numberPad)
            }

            Section("リピ") {
                Picker("判断", selection: $repeatDecision) {
                    ForEach(RepeatDecision.allCases) { decision in
                        Text(decision.rawValue).tag(decision)
                    }
                }
                TextField("理由メモ（任意）", text: $repeatMemo, axis: .vertical)
            }

            Section("メモ") {
                TextField("自由メモ（任意）", text: $memo, axis: .vertical)
            }
        }
        .navigationTitle(editingLens == nil ? "レンズ追加" : "レンズ編集")
        .scrollContentBackground(.hidden)
        .background(AppTheme.subtleBackgroundGradient)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    save()
                    dismiss()
                }
            }
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .onAppear {
            guard let lens = editingLens else { return }
            brand = lens.brand
            productName = lens.productName
            colorName = lens.colorName
            colorCategory = lens.colorCategory
            purchasePlace = lens.purchasePlace

            bcText = lens.bc.map { String($0) } ?? ""
            diaText = lens.dia.map { String($0) } ?? ""
            graphicDiameterText = lens.graphicDiameter.map { String($0) } ?? ""

            isPrescription = lens.isPrescription
            powerText = lens.power.map { String($0) } ?? ""
            replacementDaysText = lens.replacementDays.map { String($0) } ?? ""

            repeatDecision = lens.repeatDecision
            repeatMemo = lens.repeatMemo
            memo = lens.memo
        }
    }

    private func save() {
        let bc = Double(bcText.trimmingCharacters(in: .whitespacesAndNewlines))
        let dia = Double(diaText.trimmingCharacters(in: .whitespacesAndNewlines))
        let graphicDiameter = Double(graphicDiameterText.trimmingCharacters(in: .whitespacesAndNewlines))
        let power = Double(powerText.trimmingCharacters(in: .whitespacesAndNewlines))
        let replacementDays = Int(replacementDaysText.trimmingCharacters(in: .whitespacesAndNewlines))

        var lens = editingLens ?? Lens()
        lens.brand = brand
        lens.productName = productName
        lens.colorName = colorName
        lens.colorCategory = colorCategory
        lens.purchasePlace = purchasePlace
        lens.bc = bc
        lens.dia = dia
        lens.graphicDiameter = graphicDiameter
        lens.isPrescription = isPrescription
        lens.power = isPrescription ? power : nil
        lens.replacementDays = replacementDays
        lens.repeatDecision = repeatDecision
        lens.repeatMemo = repeatMemo
        lens.memo = memo

        store.upsertLens(lens)
    }
}

// Previews are intentionally omitted in this repository environment.
