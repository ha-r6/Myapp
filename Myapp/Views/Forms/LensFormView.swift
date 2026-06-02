import SwiftUI
import PhotosUI
import UIKit
import AVFoundation
import Combine
import ImageIO

struct LensFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    @AppStorage(AppSettingsKeys.fixedPowerEnabled) private var fixedPowerEnabled = false
    @AppStorage(AppSettingsKeys.fixedPowerValue) private var fixedPowerValue = ""
    @AppStorage(AppSettingsKeys.fixedLeftPowerValue) private var fixedLeftPowerValue = ""
    @AppStorage(AppSettingsKeys.fixedRightPowerValue) private var fixedRightPowerValue = ""
    @AppStorage(AppSettingsKeys.recentPurchasePlaces) private var recentPurchasePlacesRaw = ""
    @AppStorage(AppSettingsKeys.lastLeftPower) private var lastLeftPowerRaw = ""
    @AppStorage(AppSettingsKeys.lastRightPower) private var lastRightPowerRaw = ""

    private let editingLens: Lens?
    private let prefillSuggestion: LensSuggestion?

    @State private var brand: String = ""
    @State private var productName: String = ""
    @State private var colorName: String = ""
    @State private var purchasePlace: String = ""

    @State private var bcText: String = ""
    @State private var diaText: String = ""
    @State private var graphicDiameterText: String = ""

    @State private var colorCategorySelection: LensColorCategory? = nil

    @State private var isPrescription: Bool = false
    @State private var leftPowerText: String = ""
    @State private var rightPowerText: String = ""
    @State private var replacementDaysText: String = ""

    @State private var repeatDecision: RepeatDecision = .maybe
    @State private var repeatMemo: String = ""
    @State private var memo: String = ""

    @State private var validationErrorMessage: String? = nil
    @State private var stickerPickerItem: PhotosPickerItem?
    @State private var stickerEyeJPEGData: Data?
    @State private var showingCamera = false
    @State private var showingStickerEditor = false
    @State private var stickerEditingSourceImage: UIImage?
    @State private var preparingStickerImage = false

    private enum DoubleInputChoice: Hashable, Identifiable {
        case unselected
        case manual
        case value(Double)

        var id: String {
            switch self {
            case .unselected: "unselected"
            case .manual: "manual"
            case .value(let v): "value:\(String(format: "%.2f", v))"
            }
        }

        var label: String {
            switch self {
            case .unselected: "選択する"
            case .manual: "手入力"
            case .value(let v): String(format: "%.2f", v)
            }
        }

        var doubleValue: Double? {
            switch self {
            case .unselected: nil
            case .manual: nil
            case .value(let v): v
            }
        }
    }

    private enum ReplacementPreset: String, CaseIterable, Identifiable {
        case oneDay = "1day"
        case twoWeeks = "2weeks"
        case oneMonth = "1month"
        case other = "その他"

        var id: String { rawValue }

        var days: Int? {
            switch self {
            case .oneDay: 1
            case .twoWeeks: 14
            case .oneMonth: 30
            case .other: nil
            }
        }
    }

    @State private var bcChoice: DoubleInputChoice = .unselected
    @State private var diaChoice: DoubleInputChoice = .unselected
    @State private var graphicDiameterChoice: DoubleInputChoice = .unselected
    @State private var leftPowerChoice: DoubleInputChoice = .unselected
    @State private var rightPowerChoice: DoubleInputChoice = .unselected
    @State private var replacementPreset: ReplacementPreset = .other

    @FocusState private var isPurchasePlaceFocused: Bool
    @State private var isInitializing = true

    init(editing: Lens? = nil, prefillSuggestion: LensSuggestion? = nil) {
        self.editingLens = editing
        self.prefillSuggestion = prefillSuggestion
    }

    private var bcOptions: [Double] { stride(from: 8.3, through: 9.0, by: 0.1).map { ($0 * 10).rounded() / 10 } }
    private var diaOptions: [Double] { stride(from: 13.8, through: 15.0, by: 0.1).map { ($0 * 10).rounded() / 10 } }
    private var graphicDiameterOptions: [Double] { stride(from: 12.5, through: 15.0, by: 0.1).map { ($0 * 10).rounded() / 10 } }
    private var powerOptions: [Double] { stride(from: 0.0, through: -10.0, by: -0.25).map { ($0 * 100).rounded() / 100 } }

    private var legacyFixedPowerDouble: Double? {
        let trimmed = fixedPowerValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        return Double(trimmed)
    }

    private var fixedLeftPowerDouble: Double? {
        guard fixedPowerEnabled else { return nil }
        let trimmed = fixedLeftPowerValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return legacyFixedPowerDouble }
        return Double(trimmed)
    }

    private var fixedRightPowerDouble: Double? {
        guard fixedPowerEnabled else { return nil }
        let trimmed = fixedRightPowerValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return legacyFixedPowerDouble }
        return Double(trimmed)
    }

    // 度数固定ON時は、設定値が空でも直近入力をフォールバックとして使う。
    private var resolvedFixedLeftPowerDouble: Double? {
        if let v = fixedLeftPowerDouble { return v }
        let trimmed = lastLeftPowerRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(trimmed)
    }

    private var resolvedFixedRightPowerDouble: Double? {
        if let v = fixedRightPowerDouble { return v }
        let trimmed = lastRightPowerRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(trimmed)
    }

    private var bcDouble: Double? { Double(bcText.trimmingCharacters(in: .whitespacesAndNewlines)) }
    private var diaDouble: Double? { Double(diaText.trimmingCharacters(in: .whitespacesAndNewlines)) }
    private var graphicDiameterDouble: Double? { Double(graphicDiameterText.trimmingCharacters(in: .whitespacesAndNewlines)) }
    private var leftPowerDouble: Double? { Double(leftPowerText.trimmingCharacters(in: .whitespacesAndNewlines)) }
    private var rightPowerDouble: Double? { Double(rightPowerText.trimmingCharacters(in: .whitespacesAndNewlines)) }
    private var replacementDaysInt: Int? { Int(replacementDaysText.trimmingCharacters(in: .whitespacesAndNewlines)) }
    private var replacementDaysForSave: Int? {
        if let days = replacementPreset.days { return days }
        return nil
    }

    private var recentPurchasePlaces: [String] {
        recentPurchasePlacesRaw
            .split(separator: "\n")
            .map { String($0) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }

    private var purchasePlaceSuggestions: [String] {
        let q = purchasePlace.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return Array(recentPurchasePlaces.prefix(8)) }
        return recentPurchasePlaces
            .filter { $0.localizedCaseInsensitiveContains(q) }
            .prefix(8)
            .map { $0 }
    }

    private var isFormValid: Bool {
        if bcDouble == nil || diaDouble == nil || graphicDiameterDouble == nil { return false }
        if replacementPreset != .other, replacementDaysForSave == nil { return false }
        if isPrescription {
            if fixedPowerEnabled { return true }
            return leftPowerDouble != nil && rightPowerDouble != nil
        }
        return true
    }

    private var photoPickerLabelText: String {
        stickerEyeJPEGData == nil ? "写真を選ぶ" : "選び直す"
    }

    var body: some View {
        Form {
            photoSection

            Section("名称") {
                TextField("ブランド", text: $brand)
                TextField("商品名", text: $productName)
                TextField("カラー", text: $colorName)
            }

            Section("カラー分類") {
                Picker("分類", selection: $colorCategorySelection) {
                    Text("選択する").tag(Optional<LensColorCategory>.none)
                    ForEach(LensColorCategory.allCases.filter { $0 != .all }) { cat in
                        Text(cat.rawValue).tag(Optional<LensColorCategory>.some(cat))
                    }
                }
            }

            Section("購入") {
                TextField("購入場所（例: Qoo10 / 楽天 / 店舗名）", text: $purchasePlace)
                    .focused($isPurchasePlaceFocused)

                if isPurchasePlaceFocused, purchasePlaceSuggestions.isEmpty == false {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("履歴")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        let columns = [GridItem(.adaptive(minimum: 88), spacing: 8)]
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                            ForEach(purchasePlaceSuggestions, id: \.self) { suggestion in
                                Button(suggestion) {
                                    purchasePlace = suggestion
                                    isPurchasePlaceFocused = false
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }

            Section("スペック") {
                Picker("BC", selection: $bcChoice) {
                    Text(DoubleInputChoice.unselected.label).tag(DoubleInputChoice.unselected)
                    ForEach(bcOptions, id: \.self) { v in
                        Text(String(format: "%.1f", v)).tag(DoubleInputChoice.value(v))
                    }
                    Text(DoubleInputChoice.manual.label).tag(DoubleInputChoice.manual)
                }
                .pickerStyle(.menu)
                if bcChoice == .manual {
                    TextField("BC（例: 8.6）", text: $bcText)
                        .keyboardType(.decimalPad)
                }

                Picker("DIA", selection: $diaChoice) {
                    Text(DoubleInputChoice.unselected.label).tag(DoubleInputChoice.unselected)
                    ForEach(diaOptions, id: \.self) { v in
                        Text(String(format: "%.1f", v)).tag(DoubleInputChoice.value(v))
                    }
                    Text(DoubleInputChoice.manual.label).tag(DoubleInputChoice.manual)
                }
                .pickerStyle(.menu)
                if diaChoice == .manual {
                    TextField("DIA（例: 14.2）", text: $diaText)
                        .keyboardType(.decimalPad)
                }

                Picker("着色直径", selection: $graphicDiameterChoice) {
                    Text(DoubleInputChoice.unselected.label).tag(DoubleInputChoice.unselected)
                    ForEach(graphicDiameterOptions, id: \.self) { v in
                        Text(String(format: "%.1f", v)).tag(DoubleInputChoice.value(v))
                    }
                    Text(DoubleInputChoice.manual.label).tag(DoubleInputChoice.manual)
                }
                .pickerStyle(.menu)
                if graphicDiameterChoice == .manual {
                    TextField("着色直径（例: 13.2）", text: $graphicDiameterText)
                        .keyboardType(.decimalPad)
                }

                Toggle("度あり", isOn: $isPrescription)
                if isPrescription {
                    if fixedPowerEnabled {
                        LabeledContent("度数（左右）") {
                            let left = resolvedFixedLeftPowerDouble.map { String(format: "%.2f", $0) } ?? "—"
                            let right = resolvedFixedRightPowerDouble.map { String(format: "%.2f", $0) } ?? "—"
                            Text("左 \(left) / 右 \(right)")
                        }
                    } else {
                        Group {
                            Picker("左", selection: $leftPowerChoice) {
                                Text(DoubleInputChoice.unselected.label).tag(DoubleInputChoice.unselected)
                                ForEach(powerOptions, id: \.self) { v in
                                    Text(String(format: "%.2f", v)).tag(DoubleInputChoice.value(v))
                                }
                                Text(DoubleInputChoice.manual.label).tag(DoubleInputChoice.manual)
                            }
                            .pickerStyle(.menu)
                            if leftPowerChoice == .manual {
                                TextField("左（例: -3.25）", text: $leftPowerText)
                                    .keyboardType(.numbersAndPunctuation)
                            }

                            Picker("右", selection: $rightPowerChoice) {
                                Text(DoubleInputChoice.unselected.label).tag(DoubleInputChoice.unselected)
                                ForEach(powerOptions, id: \.self) { v in
                                    Text(String(format: "%.2f", v)).tag(DoubleInputChoice.value(v))
                                }
                                Text(DoubleInputChoice.manual.label).tag(DoubleInputChoice.manual)
                            }
                            .pickerStyle(.menu)
                            if rightPowerChoice == .manual {
                                TextField("右（例: -3.25）", text: $rightPowerText)
                                    .keyboardType(.numbersAndPunctuation)
                            }
                        }
                    }
                }
                Text("日数")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("", selection: $replacementPreset) {
                    ForEach(ReplacementPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
            }
            .onChange(of: bcChoice) { _, next in
                if isInitializing { return }
                if let v = next.doubleValue { bcText = String(format: "%.1f", v) } else { bcText = "" }
                if next == .manual { bcText = "" }
            }
            .onChange(of: diaChoice) { _, next in
                if isInitializing { return }
                if let v = next.doubleValue { diaText = String(format: "%.1f", v) } else { diaText = "" }
                if next == .manual { diaText = "" }
            }
            .onChange(of: graphicDiameterChoice) { _, next in
                if isInitializing { return }
                if let v = next.doubleValue { graphicDiameterText = String(format: "%.1f", v) } else { graphicDiameterText = "" }
                if next == .manual { graphicDiameterText = "" }
            }
            .onChange(of: leftPowerChoice) { _, next in
                if isInitializing { return }
                if let v = next.doubleValue { leftPowerText = String(format: "%.2f", v) } else { leftPowerText = "" }
                if next == .manual { leftPowerText = "" }
            }
            .onChange(of: rightPowerChoice) { _, next in
                if isInitializing { return }
                if let v = next.doubleValue { rightPowerText = String(format: "%.2f", v) } else { rightPowerText = "" }
                if next == .manual { rightPowerText = "" }
            }
            .onChange(of: replacementPreset) { _, next in
                if let days = next.days {
                    replacementDaysText = String(days)
                } else {
                    replacementDaysText = ""
                }
            }
            .onChange(of: isPrescription) { _, next in
                if next == false {
                    leftPowerText = ""
                    rightPowerText = ""
                    leftPowerChoice = .unselected
                    rightPowerChoice = .unselected
                } else if fixedPowerEnabled, let fixedL = resolvedFixedLeftPowerDouble, let fixedR = resolvedFixedRightPowerDouble {
                    leftPowerText = String(format: "%.2f", fixedL)
                    rightPowerText = String(format: "%.2f", fixedR)
                }
            }

            Section("リピ") {
                Picker("判断", selection: $repeatDecision) {
                    ForEach(RepeatDecision.allCases) { decision in
                        Text(decision.rawValue).tag(decision)
                    }
                }
                .pickerStyle(.segmented)
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
                    if isFormValid == false {
                        validationErrorMessage = "スペック（BC/DIA/着色直径/使用期間）と必須項目を入力してください。"
                        return
                    }
                    save()
                    dismiss()
                }
                .disabled(isFormValid == false)
            }
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .alert("入力エラー", isPresented: Binding(
            get: { validationErrorMessage != nil },
            set: { isPresented in
                if isPresented == false { validationErrorMessage = nil }
            }
        )) {
            Button("OK", role: .cancel) { validationErrorMessage = nil }
        } message: {
            Text(validationErrorMessage ?? "")
        }
        .sheet(isPresented: $showingCamera) {
            EyeGuideCameraCaptureView(
                onCapture: { image in
                    stickerEditingSourceImage = normalizedImage(from: image) ?? image
                    showingStickerEditor = true
                    showingCamera = false
                },
                onCancel: { showingCamera = false }
            )
        }
        .sheet(isPresented: $showingStickerEditor) {
            if let source = stickerEditingSourceImage {
                EyeEllipseEditorView(
                    sourceImage: source,
                    onCancel: {
                        showingStickerEditor = false
                    },
                    onSave: { data in
                        stickerEyeJPEGData = data
                        showingStickerEditor = false
                    }
                )
            }
        }
        .onChange(of: stickerPickerItem) { _, next in
            Task {
                await MainActor.run { preparingStickerImage = true }
                let image = await loadSourceImage(from: next)
                await MainActor.run {
                    preparingStickerImage = false
                    if let image {
                        stickerEditingSourceImage = image
                        showingStickerEditor = true
                    }
                }
            }
        }
        .onAppear {
            isInitializing = true
            if let lens = editingLens {
                populateFromLens(lens)
                isInitializing = false
                return
            }

            if let suggestion = prefillSuggestion {
                brand = suggestion.brand
                productName = suggestion.productName
                colorName = suggestion.colorName
                replacementDaysText = suggestion.replacementDays.map { String($0) } ?? ""
                isPrescription = suggestion.isPrescription

                if let days = suggestion.replacementDays {
                    replacementPreset = replacementPreset(for: days)
                }

                if suggestion.isPrescription, let fixedL = resolvedFixedLeftPowerDouble, let fixedR = resolvedFixedRightPowerDouble {
                    leftPowerText = String(format: "%.2f", fixedL)
                    rightPowerText = String(format: "%.2f", fixedR)
                }
            }
            isInitializing = false
        }
    }

    @ViewBuilder
    private var photoSection: some View {
        Section {
            PhotosPicker(selection: $stickerPickerItem, matching: .images) {
                Label(photoPickerLabelText, systemImage: "photo")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                showingCamera = true
            } label: {
                Label("カメラで撮影", systemImage: "camera")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if preparingStickerImage {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("写真を準備中…")
                        .foregroundStyle(.secondary)
                }
            }

            if stickerEyeJPEGData != nil {
                Button(role: .destructive) {
                    stickerEyeJPEGData = nil
                    stickerPickerItem = nil
                } label: {
                    Label("写真を削除", systemImage: "trash")
                }
            }

            EyeStickerPreview(data: stickerEyeJPEGData)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 6)
        } header: {
            Text("写真")
        } footer: {
            Text("枠に合わせて撮影 → カード向けの四角形で切り抜いて、図鑑の代表画像として表示します。")
                .foregroundStyle(.secondary)
        }
    }

    private func save() {
        let bc = bcDouble
        let dia = diaDouble
        let graphicDiameter = graphicDiameterDouble
        let leftPower = fixedPowerEnabled ? (resolvedFixedLeftPowerDouble ?? leftPowerDouble) : leftPowerDouble
        let rightPower = fixedPowerEnabled ? (resolvedFixedRightPowerDouble ?? rightPowerDouble) : rightPowerDouble
        let replacementDays = replacementDaysForSave ?? replacementDaysInt

        var lens = editingLens ?? Lens()
        lens.brand = brand
        lens.productName = productName
        lens.colorName = colorName
        lens.colorCategory = colorCategorySelection ?? .other
        lens.purchasePlace = purchasePlace
        lens.bc = bc
        lens.dia = dia
        lens.graphicDiameter = graphicDiameter
        lens.isPrescription = isPrescription
        lens.leftPower = isPrescription ? leftPower : nil
        lens.rightPower = isPrescription ? rightPower : nil
        lens.power = nil
        lens.replacementDays = replacementPreset == .other ? nil : replacementDays
        lens.repeatDecision = repeatDecision
        lens.repeatMemo = repeatMemo
        lens.memo = memo
        lens.stickerEyeJPEG = stickerEyeJPEGData

        store.upsertLens(lens)

        rememberPurchasePlace(purchasePlace)
        if isPrescription {
            if let l = leftPower { lastLeftPowerRaw = String(format: "%.2f", l) }
            if let r = rightPower { lastRightPowerRaw = String(format: "%.2f", r) }
        }
    }

    private func populateFromLens(_ lens: Lens) {
        brand = lens.brand
        productName = lens.productName
        colorName = lens.colorName
        colorCategorySelection = lens.colorCategory
        purchasePlace = lens.purchasePlace

        bcText = lens.bc.map { String(format: "%.1f", $0) } ?? ""
        diaText = lens.dia.map { String(format: "%.1f", $0) } ?? ""
        graphicDiameterText = lens.graphicDiameter.map { String(format: "%.1f", $0) } ?? ""

        isPrescription = lens.isPrescription
        let l = lens.leftPower ?? lens.power
        let r = lens.rightPower ?? lens.power
        leftPowerText = l.map { String(format: "%.2f", $0) } ?? ""
        rightPowerText = r.map { String(format: "%.2f", $0) } ?? ""
        replacementDaysText = lens.replacementDays.map { String($0) } ?? ""

        repeatDecision = lens.repeatDecision
        repeatMemo = lens.repeatMemo
        memo = lens.memo
        stickerEyeJPEGData = lens.stickerEyeJPEG

        bcChoice = choice(for: lens.bc, options: bcOptions)
        diaChoice = choice(for: lens.dia, options: diaOptions)
        graphicDiameterChoice = choice(for: lens.graphicDiameter, options: graphicDiameterOptions)
        leftPowerChoice = choice(for: l, options: powerOptions)
        rightPowerChoice = choice(for: r, options: powerOptions)

        if let days = lens.replacementDays {
            replacementPreset = replacementPreset(for: days)
        }
    }

    private func choice(for value: Double?, options: [Double]) -> DoubleInputChoice {
        guard let value else { return .unselected }
        let matched = options.contains(where: { abs($0 - value) < 0.001 })
        return matched ? .value(value) : .manual
    }

    private func replacementPreset(for days: Int) -> ReplacementPreset {
        if days == ReplacementPreset.oneDay.days { return .oneDay }
        if days == ReplacementPreset.twoWeeks.days { return .twoWeeks }
        if days == ReplacementPreset.oneMonth.days { return .oneMonth }
        return .other
    }

    private func rememberPurchasePlace(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        var items = recentPurchasePlaces
        items.removeAll(where: { $0 == trimmed })
        items.insert(trimmed, at: 0)
        recentPurchasePlacesRaw = items.prefix(30).joined(separator: "\n")
    }

    private func loadSourceImage(from item: PhotosPickerItem?) async -> UIImage? {
        guard let item else { return nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
        let image = downsampledImage(from: data, maxPixel: 2200) ?? UIImage(data: data)
        guard let image else { return nil }
        return normalizedImage(from: image) ?? image
    }

    private func downsampledImage(from data: Data, maxPixel: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxPixel)
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private func normalizedImage(from image: UIImage) -> UIImage? {
        if image.imageOrientation == .up { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let normalized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        return normalized
    }
}

// Previews are intentionally omitted in this repository environment.

private struct EyeStickerPreview: View {
    let data: Data?

    var body: some View {
        if let data, let uiImage = UIImage(data: data) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.black.opacity(0.10), lineWidth: 1))

                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(14)
            }
            .frame(height: 164)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.black.opacity(0.10), lineWidth: 1))
                VStack(spacing: 6) {
                    Image(systemName: "eye")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("目の写真がありません")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 164)
        }
    }
}

private struct EyeEllipseEditorView: View {
    let sourceImage: UIImage
    let onCancel: () -> Void
    let onSave: (Data?) -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var rotation: Angle = .zero
    @State private var lastRotation: Angle = .zero
    @State private var viewportSize: CGSize = CGSize(width: 340, height: 220)

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                GeometryReader { geo in
                    let viewWidth = min(geo.size.width - 24, 380)
                    let viewHeight = viewWidth * 0.62

                    ZStack {
                        Color.black.opacity(0.85).ignoresSafeArea()

                        ZStack {
                            Image(uiImage: sourceImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: viewWidth * scale, height: viewHeight * scale)
                                .rotationEffect(rotation)
                                .offset(offset)
                                .contentShape(Rectangle())
                                .highPriorityGesture(dragGesture)
                                .simultaneousGesture(magnifyGesture)
                                .simultaneousGesture(rotationGesture)

                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.95), lineWidth: 2)
                                .frame(width: viewWidth * 0.92, height: viewHeight * 0.86)
                                .allowsHitTesting(false)
                        }
                        .frame(width: viewWidth, height: viewHeight)
                        .clipped()
                        .onAppear {
                            viewportSize = CGSize(width: viewWidth, height: viewHeight)
                            clamp(in: viewportSize)
                        }
                        .onChange(of: viewWidth) { _, _ in
                            viewportSize = CGSize(width: viewWidth, height: viewHeight)
                            clamp(in: viewportSize)
                        }
                    }
                }
                .frame(height: 340)

                Text("ピンチで拡大、ドラッグで位置調整")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
            .navigationTitle("目の位置を調整")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        onSave(renderMaskedJPEG())
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(width: lastOffset.width + value.translation.width, height: lastOffset.height + value.translation.height)
                clamp(in: viewportSize)
            }
            .onEnded { _ in
                clamp(in: viewportSize)
                lastOffset = offset
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(max(lastScale * value.magnification, 1), 6)
                clamp(in: viewportSize)
            }
            .onEnded { _ in
                lastScale = scale
                clamp(in: viewportSize)
            }
    }

    private var rotationGesture: some Gesture {
        RotationGesture()
            .onChanged { value in
                rotation = lastRotation + value
            }
            .onEnded { _ in
                lastRotation = rotation
            }
    }

    private func clamp(in cropSize: CGSize) {
        let movePadding: CGFloat = 60
        let maxX = max(movePadding, (cropSize.width * scale - cropSize.width) * 0.5 + movePadding)
        let maxY = max(movePadding, (cropSize.height * scale - cropSize.height) * 0.5 + movePadding)
        offset.width = min(max(offset.width, -maxX), maxX)
        offset.height = min(max(offset.height, -maxY), maxY)
    }

    private func renderMaskedJPEG() -> Data? {
        let baseWidth: CGFloat = 960
        let viewportAspect = max(viewportSize.height, 1) / max(viewportSize.width, 1)
        let canvasSize = CGSize(width: baseWidth, height: baseWidth * viewportAspect)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        let rendered = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: canvasSize))

            let clipWidth = canvasSize.width * 0.92
            let clipHeight = canvasSize.height * 0.86
            let clipRect = CGRect(
                x: (canvasSize.width - clipWidth) * 0.5,
                y: (canvasSize.height - clipHeight) * 0.5,
                width: clipWidth,
                height: clipHeight
            )
            let clipPath = UIBezierPath(roundedRect: clipRect, cornerRadius: 36)
            clipPath.addClip()

            let base = aspectFillRect(contentSize: sourceImage.size, boundsSize: canvasSize)
            let sx = canvasSize.width / max(viewportSize.width, 1)
            let sy = canvasSize.height / max(viewportSize.height, 1)

            ctx.cgContext.saveGState()
            ctx.cgContext.translateBy(x: base.midX + offset.width * sx, y: base.midY + offset.height * sy)
            ctx.cgContext.rotate(by: CGFloat(rotation.radians))
            ctx.cgContext.scaleBy(x: scale, y: scale)
            sourceImage.draw(in: CGRect(
                x: -base.width * 0.5,
                y: -base.height * 0.5,
                width: base.width,
                height: base.height
            ))
            ctx.cgContext.restoreGState()
        }

        return rendered.jpegData(compressionQuality: 0.92)
    }

    private func aspectFillRect(contentSize: CGSize, boundsSize: CGSize) -> CGRect {
        guard contentSize.width > 0, contentSize.height > 0 else { return CGRect(origin: .zero, size: boundsSize) }
        let fillScale = max(boundsSize.width / contentSize.width, boundsSize.height / contentSize.height)
        let scaled = CGSize(width: contentSize.width * fillScale, height: contentSize.height * fillScale)
        return CGRect(
            x: (boundsSize.width - scaled.width) * 0.5,
            y: (boundsSize.height - scaled.height) * 0.5,
            width: scaled.width,
            height: scaled.height
        )
    }
}

private struct EyeGuideCameraCaptureView: View {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    @StateObject private var camera = CameraModel()

    var body: some View {
        ZStack {
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()

            EyeGuideOverlay()
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button("キャンセル") {
                        camera.stop()
                        onCancel()
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.leading, 16)
                    .padding(.top, 12)

                    Spacer()
                }

                Spacer()

                Button {
                    camera.capture { image in
                        guard let image else { return }
                        onCapture(image)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.25))
                            .frame(width: 74, height: 74)
                        Circle()
                            .fill(.white)
                            .frame(width: 58, height: 58)
                    }
                }
                .padding(.bottom, 28)
            }
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
    }
}

// FlowWrap removed (use LazyVGrid for suggestions)

private struct EyeGuideOverlay: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let minSide = min(size.width, size.height)
            let ovalWidth = minSide * 0.78
            let ovalHeight = ovalWidth * 0.58
            let ovalRect = CGRect(
                x: (size.width - ovalWidth) * 0.5,
                y: (size.height - ovalHeight) * 0.42,
                width: ovalWidth,
                height: ovalHeight
            )

            ZStack {
                Canvas { context, canvasSize in
                    var path = Path(CGRect(origin: .zero, size: canvasSize))
                    path.addEllipse(in: ovalRect)
                    context.fill(path, with: .color(.black.opacity(0.45)), style: FillStyle(eoFill: true))
                }

                Ellipse()
                    .stroke(.white.opacity(0.9), lineWidth: 3)
                    .frame(width: ovalRect.width, height: ovalRect.height)
                    .position(x: ovalRect.midX, y: ovalRect.midY)

                VStack(spacing: 6) {
                    Text("枠に目を合わせて撮影")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("撮影後に楕円形で切り抜きます")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 90)
            }
        }
    }
}

private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

private final class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var onCapture: ((UIImage?) -> Void)?

    func start() {
        if session.isRunning { return }

        session.beginConfiguration()
        session.sessionPreset = .photo

        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) ??
            AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            session.commitConfiguration()
            return
        }

        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        session.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }

    func stop() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.stopRunning()
        }
    }

    func capture(completion: @escaping (UIImage?) -> Void) {
        onCapture = completion
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        output.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        defer { onCapture = nil }
        guard error == nil else {
            onCapture?(nil)
            return
        }
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            onCapture?(nil)
            return
        }
        onCapture?(image)
    }
}
