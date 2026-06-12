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
    @State private var waterContentCategorySelection: LensWaterContentCategory? = nil

    @State private var isPrescription: Bool = false
    @State private var leftPowerText: String = ""
    @State private var rightPowerText: String = ""
    @State private var replacementDaysText: String = ""

    @State private var repeatDecision: RepeatDecision = .yes
    @State private var repeatMemo: String = ""
    @State private var memo: String = ""

    @State private var validationErrorMessage: String? = nil
    @State private var stickerPickerItem: PhotosPickerItem?
    @State private var stickerEyeJPEGData: Data?
    @State private var showingCamera = false
    @State private var stickerEditingSourceImage: EditableSourceImage?
    @State private var pendingCapturedImage: UIImage?
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

        func label(fractionDigits: Int) -> String {
            switch self {
            case .unselected: "選択する"
            case .manual: "手入力"
            case .value(let v): String(format: "%.\(fractionDigits)f", v)
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

    private struct EditableSourceImage: Identifiable {
        let id = UUID()
        let image: UIImage
        let wasAutoDetected: Bool
        let initialFocusRect: CGRect?
    }

    private enum FormStep: Int, CaseIterable, Identifiable {
        case photo
        case name
        case specs
        case usage

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .photo: "写真"
            case .name: "カラコン名"
            case .specs: "スペック"
            case .usage: "使い方メモ"
            }
        }

        var prompt: String {
            switch self {
            case .photo: "図鑑に使う目元写真を設定します。"
            case .name: "ブランド名、商品名、カラー名と分類をまとめて入力します。"
            case .specs: "着色直径やBCなどのスペックをまとめて登録します。"
            case .usage: "度数、使用期間、購入場所、メモをまとめて残します。"
            }
        }

        var requirementText: String {
            switch self {
            case .name, .specs:
                return "必須"
            case .usage, .photo:
                return "任意"
            }
        }

        var isRequired: Bool {
            switch self {
            case .name, .specs, .usage:
                return true
            default:
                return false
            }
        }

        var showsStepRequirementBadge: Bool {
            false
        }

        var showsPrompt: Bool {
            switch self {
            case .photo:
                return true
            default:
                return false
            }
        }
    }

    @State private var bcChoice: DoubleInputChoice = .unselected
    @State private var diaChoice: DoubleInputChoice = .unselected
    @State private var graphicDiameterChoice: DoubleInputChoice = .unselected
    @State private var leftPowerChoice: DoubleInputChoice = .unselected
    @State private var rightPowerChoice: DoubleInputChoice = .unselected
    @State private var replacementPreset: ReplacementPreset = .oneDay
    @State private var currentStep: FormStep = .photo

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
    private var bcChoiceOptions: [DoubleInputChoice] {
        [.unselected] + bcOptions.map(DoubleInputChoice.value) + [.manual]
    }
    private var diaChoiceOptions: [DoubleInputChoice] {
        [.unselected] + diaOptions.map(DoubleInputChoice.value) + [.manual]
    }
    private var graphicDiameterChoiceOptions: [DoubleInputChoice] {
        [.unselected] + graphicDiameterOptions.map(DoubleInputChoice.value) + [.manual]
    }
    private var powerChoiceOptions: [DoubleInputChoice] {
        [.unselected] + powerOptions.map(DoubleInputChoice.value) + [.manual]
    }
    private var waterContentChoiceOptions: [LensWaterContentCategory?] {
        [nil] + LensWaterContentCategory.allCases.map(Optional.some)
    }
    private var selectableColorCategories: [LensColorCategory] {
        LensColorCategory.allCases.filter { $0 != .all }
    }

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
        return replacementDaysInt
    }
    private var hasResolvedFixedPowers: Bool {
        fixedPowerEnabled &&
            resolvedFixedLeftPowerDouble != nil &&
            resolvedFixedRightPowerDouble != nil
    }
    private var leftPowerForSave: Double? {
        hasResolvedFixedPowers ? resolvedFixedLeftPowerDouble : leftPowerDouble
    }
    private var rightPowerForSave: Double? {
        hasResolvedFixedPowers ? resolvedFixedRightPowerDouble : rightPowerDouble
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
    private var showsPurchaseSuggestionTray: Bool {
        currentStep == .usage && isPurchasePlaceFocused && purchasePlaceSuggestions.isEmpty == false
    }

    private var isFormValid: Bool {
        if brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        if productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        if graphicDiameterDouble == nil { return false }
        if isPrescription {
            return leftPowerForSave != nil && rightPowerForSave != nil
        }
        return true
    }

    private var missingRequiredFields: [String] {
        var fields: [String] = []

        if brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fields.append("ブランド名")
        }
        if productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fields.append("商品名")
        }
        if graphicDiameterDouble == nil {
            fields.append("着色直径")
        }
        if isPrescription {
            if leftPowerForSave == nil {
                fields.append("左の度数")
            }
            if rightPowerForSave == nil {
                fields.append("右の度数")
            }
        }

        return fields
    }

    private var photoPickerLabelText: String {
        stickerEyeJPEGData == nil ? "写真を選ぶ" : "選び直す"
    }

    private var purchasePlaceGridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 88), spacing: 8)]
    }

    private var validationAlertBinding: Binding<Bool> {
        Binding(
            get: { validationErrorMessage != nil },
            set: { isPresented in
                if isPresented == false { validationErrorMessage = nil }
            }
        )
    }

    private var visibleSteps: [FormStep] {
        FormStep.allCases
    }

    private var currentStepIndex: Int {
        visibleSteps.firstIndex(of: currentStep) ?? 0
    }

    private var isLastStep: Bool {
        currentStepIndex == visibleSteps.count - 1
    }

    private var canProceedFromCurrentStep: Bool {
        switch currentStep {
        case .name:
            return brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
                productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .specs:
            return graphicDiameterDouble != nil
        case .usage:
            if isPrescription == false { return true }
            return leftPowerForSave != nil && rightPowerForSave != nil
        default:
            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            stepProgressHeader

            ScrollView {
                VStack(spacing: 16) {
                    stepCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .scrollDismissesKeyboard(.interactively)

            stepFooter
        }
        .navigationTitle(editingLens == nil ? "カラコン追加" : "カラコン編集")
        .background(AppTheme.subtleBackgroundGradient)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsPurchaseSuggestionTray {
                purchasePlaceSuggestionsTray
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
        .alert("入力エラー", isPresented: validationAlertBinding) {
            Button("OK", role: .cancel) { validationErrorMessage = nil }
        } message: {
            Text(validationErrorMessage ?? "")
        }
        .sheet(isPresented: $showingCamera, onDismiss: {
            guard let image = pendingCapturedImage else { return }
            pendingCapturedImage = nil
            prepareEditableSourceImage(from: image)
        }) {
            EyeGuideCameraCaptureView(
                onCapture: { image in
                    pendingCapturedImage = normalizedImage(from: image) ?? image
                    showingCamera = false
                },
                onCancel: { showingCamera = false }
            )
        }
        .sheet(item: $stickerEditingSourceImage) { source in
            EyeEllipseEditorView(
                sourceImage: source.image,
                wasAutoDetected: source.wasAutoDetected,
                initialFocusRect: source.initialFocusRect,
                onCancel: {
                    stickerEditingSourceImage = nil
                },
                onSave: { data in
                    stickerEyeJPEGData = data
                    stickerEditingSourceImage = nil
                }
            )
        }
        .onChange(of: stickerPickerItem) { _, next in handleStickerPickerItemChange(next) }
        .onAppear(perform: handleOnAppear)
        .onChange(of: isPrescription) { _, _ in
            syncCurrentStepIfNeeded()
        }
        .onChange(of: bcChoice) { _, next in handleBCChoiceChange(next) }
        .onChange(of: bcText) { _, next in handleBCTextChange(next) }
        .onChange(of: diaChoice) { _, next in handleDIAChoiceChange(next) }
        .onChange(of: diaText) { _, next in handleDIATextChange(next) }
        .onChange(of: graphicDiameterChoice) { _, next in handleGraphicDiameterChoiceChange(next) }
        .onChange(of: graphicDiameterText) { _, next in handleGraphicDiameterTextChange(next) }
        .onChange(of: leftPowerChoice) { _, next in handleLeftPowerChoiceChange(next) }
        .onChange(of: rightPowerChoice) { _, next in handleRightPowerChoiceChange(next) }
        .onChange(of: replacementPreset) { _, next in handleReplacementPresetChange(next) }
        .onChange(of: isPrescription) { _, next in handlePrescriptionChange(next) }
    }

    @ViewBuilder
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
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

            Text("枠に合わせて撮影。図鑑の代表写真にします。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var purchaseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("購入場所", text: $purchasePlace)
                .focused($isPurchasePlaceFocused)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var purchasePlaceSuggestionsTray: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("履歴")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: purchasePlaceGridColumns, alignment: .leading, spacing: 8) {
                ForEach(purchasePlaceSuggestions, id: \.self) { suggestion in
                    purchasePlaceSuggestionButton(suggestion)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        )
        .shadow(color: AppTheme.elevatedShadow, radius: 12, x: 0, y: 4)
    }

    private func purchasePlaceSuggestionButton(_ suggestion: String) -> some View {
        Button(suggestion) {
            purchasePlace = suggestion
            isPurchasePlaceFocused = false
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var repeatSection: some View {
        Picker("判断", selection: $repeatDecision) {
            ForEach(RepeatDecision.allCases) { decision in
                Text(decision.rawValue).tag(decision)
            }
        }
        .pickerStyle(.segmented)
    }

    private var memoSection: some View {
        TextField("自由メモ", text: $memo, axis: .vertical)
            .textFieldStyle(.roundedBorder)
            .lineLimit(4...8)
    }

    private var colorCategorySection: some View {
        Picker("分類", selection: $colorCategorySelection) {
            Text("選択する").tag(Optional<LensColorCategory>.none)
            ForEach(selectableColorCategories) { category in
                colorCategoryOptionView(for: category)
            }
        }
        .pickerStyle(.menu)
    }

    @ViewBuilder
    private var prescriptionPowerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            fieldBlock("度数（左右）", isRequired: true) {
                if hasResolvedFixedPowers {
                    LabeledContent("固定度数") {
                        Text(fixedPowerSummaryText)
                    }
                } else {
                    powerChoicePicker(
                        title: "左",
                        selection: $leftPowerChoice,
                        text: $leftPowerText,
                        placeholder: "左（例: -3.25）"
                    )
                    powerChoicePicker(
                        title: "右",
                        selection: $rightPowerChoice,
                        text: $rightPowerText,
                        placeholder: "右（例: -3.25）"
                    )
                }
            }

            if hasResolvedFixedPowers {
                Text("設定している固定度数を自動で使います。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if fixedPowerEnabled {
                Text("固定度数が未設定のため、このレンズでは左右の度数入力が必要です。")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var replacementDaysSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("", selection: $replacementPreset) {
                ForEach(ReplacementPreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .pickerStyle(.segmented)

            if replacementPreset == .other {
                TextField("日数（例: 45）", text: $replacementDaysText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var waterContentPicker: some View {
        Picker("含水率", selection: $waterContentCategorySelection) {
            ForEach(waterContentChoiceOptions, id: \.self) { category in
                waterContentOptionView(for: category)
            }
        }
        .pickerStyle(.menu)
    }

    private var fixedPowerSummaryText: String {
        let left = resolvedFixedLeftPowerDouble.map { String(format: "%.2f", $0) } ?? "—"
        let right = resolvedFixedRightPowerDouble.map { String(format: "%.2f", $0) } ?? "—"
        return "左 \(left) / 右 \(right)"
    }

    private func waterContentOptionView(for category: LensWaterContentCategory?) -> some View {
        let label = category.map(\.rawValue) ?? "選択する"
        return Text(label).tag(category)
    }

    private func colorCategoryOptionView(for category: LensColorCategory) -> some View {
        Text(category.rawValue).tag(Optional(category))
    }

    @ViewBuilder
    private func doubleChoicePicker(
        title: String,
        selection: Binding<DoubleInputChoice>,
        options: [DoubleInputChoice],
        text: Binding<String>,
        placeholder: String
    ) -> some View {
        Picker(title, selection: selection) {
            ForEach(options) { choice in
                Text(choice.label(fractionDigits: 1)).tag(choice)
            }
        }
        .pickerStyle(.menu)

        if selection.wrappedValue == .manual {
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private func powerChoicePicker(
        title: String,
        selection: Binding<DoubleInputChoice>,
        text: Binding<String>,
        placeholder: String
    ) -> some View {
        Picker(title, selection: selection) {
            ForEach(powerChoiceOptions) { choice in
                Text(choice.label(fractionDigits: 2)).tag(choice)
            }
        }
        .pickerStyle(.menu)

        if selection.wrappedValue == .manual {
            TextField(placeholder, text: text)
                .keyboardType(.numbersAndPunctuation)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var stepProgressHeader: some View {
        VStack(spacing: 10) {
            ProgressView(value: Double(currentStepIndex + 1), total: Double(max(visibleSteps.count, 1)))
                .tint(AppTheme.accent)

            HStack {
                Spacer()
                Text("\(currentStepIndex + 1) / \(visibleSteps.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(AppTheme.surface)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(AppTheme.background.opacity(0.96))
    }

    private var stepCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if currentStep.showsPrompt {
                Text(currentStep.prompt)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            stepContent(for: currentStep)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    @ViewBuilder
    private func stepContent(for step: FormStep) -> some View {
        switch step {
        case .photo:
            photoSection
        case .name:
            VStack(alignment: .leading, spacing: 12) {
                fieldBlock("ブランド名", isRequired: true) {
                    TextField("ブランド", text: $brand)
                        .textFieldStyle(.roundedBorder)
                }
                fieldBlock("商品名", isRequired: true) {
                    TextField("商品名", text: $productName)
                        .textFieldStyle(.roundedBorder)
                }
                fieldBlock("カラー名", isRequired: false) {
                    TextField("カラー", text: $colorName)
                        .textFieldStyle(.roundedBorder)
                }
                fieldBlock("カラー分類", isRequired: false) {
                    colorCategorySection
                }
            }
        case .specs:
            VStack(alignment: .leading, spacing: 16) {
                fieldBlock("着色直径", isRequired: true) {
                    doubleChoicePicker(
                        title: "着色直径",
                        selection: $graphicDiameterChoice,
                        options: graphicDiameterChoiceOptions,
                        text: $graphicDiameterText,
                        placeholder: "着色直径（例: 13.2）"
                    )
                }
                fieldBlock("BC", isRequired: false) {
                    doubleChoicePicker(
                        title: "BC",
                        selection: $bcChoice,
                        options: bcChoiceOptions,
                        text: $bcText,
                        placeholder: "BC（例: 8.6）"
                    )
                }
                fieldBlock("DIA", isRequired: false) {
                    doubleChoicePicker(
                        title: "DIA",
                        selection: $diaChoice,
                        options: diaChoiceOptions,
                        text: $diaText,
                        placeholder: "DIA（例: 14.2）"
                    )
                }
                fieldBlock("含水率", isRequired: false) {
                    waterContentPicker
                }
            }
        case .usage:
            VStack(alignment: .leading, spacing: 20) {
                fieldBlock("度あり/度なし", isRequired: false) {
                    Toggle("度あり", isOn: $isPrescription)
                        .toggleStyle(.switch)
                        .padding(.top, 2)
                        .padding(.bottom, 2)
                }
                if isPrescription {
                    prescriptionPowerSection
                }
                fieldBlock("使用期間", isRequired: false) {
                    replacementDaysSection
                }
                fieldBlock("リピ判断", isRequired: false) {
                    repeatSection
                }
                fieldBlock("購入場所", isRequired: false) {
                    purchaseSection
                }
                fieldBlock("メモ", isRequired: false) {
                    memoSection
                }
            }
        }
    }

    private var stepFooter: some View {
        HStack(spacing: 12) {
            Button {
                goToPreviousStep()
            } label: {
                Text("戻る")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 76)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(AppTheme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(AppTheme.accent.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: AppTheme.accent.opacity(0.08), radius: 10, x: 0, y: 5)
            }
            .foregroundStyle(AppTheme.accent)
            .opacity(currentStepIndex == 0 ? 0.45 : 1)
            .disabled(currentStepIndex == 0)

            Button {
                if isLastStep {
                    attemptSave()
                } else {
                    goToNextStep()
                }
            } label: {
                Text(isLastStep ? "保存" : "次へ")
                    .font(.headline.weight(.bold))
                    .tracking(0.2)
                    .frame(maxWidth: .infinity, minHeight: 76)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                canProceedFromCurrentStep
                                    ? Color(red: 0.84, green: 0.30, blue: 0.45)
                                    : Color(red: 0.72, green: 0.72, blue: 0.76)
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                canProceedFromCurrentStep
                                    ? Color(red: 0.67, green: 0.20, blue: 0.34)
                                    : Color.gray.opacity(0.18),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(
                        color: canProceedFromCurrentStep ? Color.black.opacity(0.16) : Color.clear,
                        radius: 12,
                        x: 0,
                        y: 7
                    )
            }
            .foregroundStyle(.white)
            .disabled(canProceedFromCurrentStep == false)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(AppTheme.background.opacity(0.98))
    }

    private func goToNextStep() {
        guard canProceedFromCurrentStep else { return }
        let steps = visibleSteps
        guard let index = steps.firstIndex(of: currentStep), index + 1 < steps.count else { return }
        currentStep = steps[index + 1]
    }

    private func goToPreviousStep() {
        let steps = visibleSteps
        guard let index = steps.firstIndex(of: currentStep), index > 0 else { return }
        currentStep = steps[index - 1]
    }

    private func syncCurrentStepIfNeeded() {
        let steps = visibleSteps
        if steps.contains(currentStep) == false {
            currentStep = steps.last ?? .photo
        }
    }

    private func attemptSave() {
        if isFormValid == false {
            validationErrorMessage = "次の必須項目を入力してください: \(missingRequiredFields.joined(separator: "、"))"
            return
        }
        save()
        dismiss()
    }

    private func handleStickerPickerItemChange(_ next: PhotosPickerItem?) {
        Task {
            await MainActor.run {
                preparingStickerImage = true
            }

            let editableSource = await loadEditableSourceImage(from: next)

            await MainActor.run {
                preparingStickerImage = false
                if let editableSource {
                    stickerEditingSourceImage = editableSource
                }
            }
        }
    }

    private func handleOnAppear() {
        isInitializing = true

        if let lens = editingLens {
            populateFromLens(lens)
            isInitializing = false
            return
        }

        if let suggestion = prefillSuggestion {
            applySuggestion(suggestion)
        }

        isInitializing = false
        syncCurrentStepIfNeeded()
    }

    private func applySuggestion(_ suggestion: LensSuggestion) {
        brand = suggestion.brand
        productName = suggestion.productName
        colorName = suggestion.colorName
        replacementDaysText = suggestion.replacementDays.map { String($0) } ?? ""
        isPrescription = suggestion.isPrescription

        if let days = suggestion.replacementDays {
            replacementPreset = replacementPreset(for: days)
        }

        guard suggestion.isPrescription,
              let fixedLeft = resolvedFixedLeftPowerDouble,
              let fixedRight = resolvedFixedRightPowerDouble else {
            return
        }

        leftPowerText = String(format: "%.2f", fixedLeft)
        rightPowerText = String(format: "%.2f", fixedRight)
    }

    private func handleBCChoiceChange(_ next: DoubleInputChoice) {
        if isInitializing { return }
        if let value = next.doubleValue {
            bcText = String(format: "%.1f", value)
        } else {
            bcText = ""
        }
        if next == .manual {
            bcText = ""
        }
    }

    private func handleBCTextChange(_ next: String) {
        guard bcChoice == .manual else { return }
        let normalized = normalizedDecimalText(next, maxFractionDigits: 1)
        if normalized != next {
            bcText = normalized
        }
    }

    private func handleDIAChoiceChange(_ next: DoubleInputChoice) {
        if isInitializing { return }
        if let value = next.doubleValue {
            diaText = String(format: "%.1f", value)
        } else {
            diaText = ""
        }
        if next == .manual {
            diaText = ""
        }
    }

    private func handleDIATextChange(_ next: String) {
        guard diaChoice == .manual else { return }
        let normalized = normalizedDecimalText(next, maxFractionDigits: 1)
        if normalized != next {
            diaText = normalized
        }
    }

    private func handleGraphicDiameterChoiceChange(_ next: DoubleInputChoice) {
        if isInitializing { return }
        if let value = next.doubleValue {
            graphicDiameterText = String(format: "%.1f", value)
        } else {
            graphicDiameterText = ""
        }
        if next == .manual {
            graphicDiameterText = ""
        }
    }

    private func handleGraphicDiameterTextChange(_ next: String) {
        guard graphicDiameterChoice == .manual else { return }
        let normalized = normalizedDecimalText(next, maxFractionDigits: 1)
        if normalized != next {
            graphicDiameterText = normalized
        }
    }

    private func handleLeftPowerChoiceChange(_ next: DoubleInputChoice) {
        if isInitializing { return }
        if let value = next.doubleValue {
            leftPowerText = String(format: "%.2f", value)
        } else {
            leftPowerText = ""
        }
        if next == .manual {
            leftPowerText = ""
        }
    }

    private func handleRightPowerChoiceChange(_ next: DoubleInputChoice) {
        if isInitializing { return }
        if let value = next.doubleValue {
            rightPowerText = String(format: "%.2f", value)
        } else {
            rightPowerText = ""
        }
        if next == .manual {
            rightPowerText = ""
        }
    }

    private func handleReplacementPresetChange(_ next: ReplacementPreset) {
        if let days = next.days {
            replacementDaysText = String(days)
        } else {
            replacementDaysText = ""
        }
    }

    private func handlePrescriptionChange(_ next: Bool) {
        if next == false {
            leftPowerText = ""
            rightPowerText = ""
            leftPowerChoice = .unselected
            rightPowerChoice = .unselected
            return
        }

        guard fixedPowerEnabled,
              let fixedLeft = resolvedFixedLeftPowerDouble,
              let fixedRight = resolvedFixedRightPowerDouble else {
            return
        }

        leftPowerText = String(format: "%.2f", fixedLeft)
        rightPowerText = String(format: "%.2f", fixedRight)
    }

    private func save() {
        let bc = rounded(bcDouble, digits: 1)
        let dia = rounded(diaDouble, digits: 1)
        let graphicDiameter = rounded(graphicDiameterDouble, digits: 1)
        let leftPower = leftPowerForSave
        let rightPower = rightPowerForSave
        let replacementDays = replacementDaysForSave ?? replacementDaysInt

        var lens = editingLens ?? Lens()
        lens.brand = brand
        lens.productName = productName
        lens.colorName = colorName
        lens.colorCategory = colorCategorySelection ?? .other
        lens.waterContentCategory = waterContentCategorySelection
        lens.purchasePlace = purchasePlace
        lens.bc = bc
        lens.dia = dia
        lens.graphicDiameter = graphicDiameter
        lens.isPrescription = isPrescription
        lens.leftPower = isPrescription ? leftPower : nil
        lens.rightPower = isPrescription ? rightPower : nil
        lens.power = nil
        lens.replacementDays = replacementDays
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

    @ViewBuilder
    private func fieldBlock<Content: View>(
        _ title: String,
        isRequired: Bool,
        showsBadge: Bool = true,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if showsBadge {
                    requirementBadge(for: isRequired ? "必須" : "任意", isRequired: isRequired)
                }
            }

            content()
        }
    }

    private func requirementBadge(for text: String, isRequired: Bool) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(isRequired ? AppTheme.accent : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(isRequired ? AppTheme.accent.opacity(0.12) : Color.secondary.opacity(0.12))
            )
    }

    private func normalizedDecimalText(_ value: String, maxFractionDigits: Int) -> String {
        let filtered = value.filter { $0.isNumber || $0 == "." }
        var result = ""
        var sawSeparator = false
        var fractionDigits = 0

        for char in filtered {
            if char == "." {
                if sawSeparator { continue }
                sawSeparator = true
                if result.isEmpty { result = "0" }
                result.append(char)
                continue
            }

            if sawSeparator {
                guard fractionDigits < maxFractionDigits else { continue }
                fractionDigits += 1
            }

            result.append(char)
        }

        return result
    }

    private func rounded(_ value: Double?, digits: Int) -> Double? {
        guard let value else { return nil }
        let scale = pow(10.0, Double(digits))
        return (value * scale).rounded() / scale
    }

    private func populateFromLens(_ lens: Lens) {
        brand = lens.brand
        productName = lens.productName
        colorName = lens.colorName
        colorCategorySelection = lens.colorCategory
        waterContentCategorySelection = lens.waterContentCategory
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
        } else {
            replacementPreset = .other
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

    private func prepareEditableSourceImage(from image: UIImage) {
        Task {
            await MainActor.run {
                preparingStickerImage = true
            }

            let editableSource = await makeEditableSourceImage(from: image, originalData: image.jpegData(compressionQuality: 0.95))

            await MainActor.run {
                preparingStickerImage = false
                if let editableSource {
                    stickerEditingSourceImage = editableSource
                }
            }
        }
    }

    private func loadEditableSourceImage(from item: PhotosPickerItem?) async -> EditableSourceImage? {
        guard let item else { return nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
        let image = downsampledImage(from: data, maxPixel: 2200) ?? UIImage(data: data)
        guard let image else { return nil }
        return await makeEditableSourceImage(from: image, originalData: data)
    }

    private func makeEditableSourceImage(from image: UIImage, originalData: Data?) async -> EditableSourceImage? {
        let normalized = normalizedImage(from: image) ?? image
        let detectionData = normalized.jpegData(compressionQuality: 0.95) ?? originalData

        if let detectionData,
           let focusRect = await EyeCropper.detectMostProminentEyeRect(from: detectionData) {
            return EditableSourceImage(
                image: normalized,
                wasAutoDetected: true,
                initialFocusRect: focusRect
            )
        }

        return EditableSourceImage(
            image: normalized,
            wasAutoDetected: false,
            initialFocusRect: nil
        )
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
    let wasAutoDetected: Bool
    let initialFocusRect: CGRect?
    let onCancel: () -> Void
    let onSave: (Data?) -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var rotation: Angle = .zero
    @State private var lastRotation: Angle = .zero
    @State private var viewportSize: CGSize = CGSize(width: 340, height: 220)
    @State private var didApplyAutoFocus = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if wasAutoDetected {
                    Label("目の位置を自動で検出しました。必要なら微調整してください。", systemImage: "sparkles")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                }

                GeometryReader { geo in
                    let viewWidth = min(geo.size.width - 24, 380)
                    let viewHeight = viewWidth * 0.62
                    let baseRect = aspectFillRect(
                        contentSize: sourceImage.size,
                        boundsSize: CGSize(width: viewWidth, height: viewHeight)
                    )

                    ZStack {
                        Color.black.opacity(0.85).ignoresSafeArea()

                        ZStack {
                            Image(uiImage: sourceImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: baseRect.width * scale, height: baseRect.height * scale)
                                .rotationEffect(rotation)
                                .offset(offset)
                                .contentShape(Rectangle())
                                .highPriorityGesture(dragGesture)
                                .simultaneousGesture(magnifyGesture)
                                .simultaneousGesture(rotationGesture)

                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.95), lineWidth: 2)
                                .frame(width: viewWidth, height: viewHeight)
                                .allowsHitTesting(false)
                        }
                        .frame(width: viewWidth, height: viewHeight)
                        .clipped()
                        .onAppear {
                            viewportSize = CGSize(width: viewWidth, height: viewHeight)
                            applyAutoFocusIfNeeded(in: viewportSize)
                        }
                        .onChange(of: viewWidth) { _, _ in
                            viewportSize = CGSize(width: viewWidth, height: viewHeight)
                            applyAutoFocusIfNeeded(in: viewportSize)
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
                        onSave(renderMaskedImageData())
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
        let base = aspectFillRect(contentSize: sourceImage.size, boundsSize: cropSize)
        let maxX = max(0, (base.width * scale - cropSize.width) * 0.5)
        let maxY = max(0, (base.height * scale - cropSize.height) * 0.5)
        offset.width = min(max(offset.width, -maxX), maxX)
        offset.height = min(max(offset.height, -maxY), maxY)
    }

    private func applyAutoFocusIfNeeded(in cropSize: CGSize) {
        guard cropSize.width > 0, cropSize.height > 0 else { return }
        guard didApplyAutoFocus == false else {
            clamp(in: cropSize)
            return
        }

        guard let initialFocusRect else {
            clamp(in: cropSize)
            return
        }

        let base = aspectFillRect(contentSize: sourceImage.size, boundsSize: cropSize)
        let widthRatio = initialFocusRect.width / max(sourceImage.size.width, 1)
        let heightRatio = initialFocusRect.height / max(sourceImage.size.height, 1)
        let focusWidth = base.width * widthRatio
        let focusHeight = base.height * heightRatio

        let targetWidth = cropSize.width * 0.72
        let targetHeight = cropSize.height * 0.72
        let computedScale = min(max(min(targetWidth / max(focusWidth, 1), targetHeight / max(focusHeight, 1)), 1), 6)
        scale = computedScale
        lastScale = computedScale

        let focusCenter = CGPoint(
            x: base.minX + base.width * (initialFocusRect.midX / max(sourceImage.size.width, 1)),
            y: base.minY + base.height * (initialFocusRect.midY / max(sourceImage.size.height, 1))
        )
        let viewportCenter = CGPoint(x: cropSize.width * 0.5, y: cropSize.height * 0.5)
        offset = CGSize(
            width: -(focusCenter.x - viewportCenter.x) * computedScale,
            height: -(focusCenter.y - viewportCenter.y) * computedScale
        )
        clamp(in: cropSize)
        lastOffset = offset
        didApplyAutoFocus = true
    }

    private func renderMaskedImageData() -> Data? {
        let baseWidth: CGFloat = 960
        let viewportAspect = max(viewportSize.height, 1) / max(viewportSize.width, 1)
        let canvasSize = CGSize(width: baseWidth, height: baseWidth * viewportAspect)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        let rendered = renderer.image { ctx in
            let clipRect = CGRect(origin: .zero, size: canvasSize)
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

        return rendered.pngData()
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
                            .fill(.white.opacity(camera.isCaptureButtonEnabled ? 0.25 : 0.12))
                            .frame(width: 74, height: 74)
                        Circle()
                            .fill(.white.opacity(camera.isCaptureButtonEnabled ? 1 : 0.65))
                            .frame(width: 58, height: 58)
                    }
                }
                .disabled(camera.isCaptureButtonEnabled == false)
                .padding(.bottom, 28)
            }

            if camera.isReady == false || camera.isCapturing {
                VStack {
                    Spacer()

                    Label(
                        camera.isCapturing ? "撮影中…" : "カメラを準備中…",
                        systemImage: camera.isCapturing ? "photo" : "camera.aperture"
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 126)
                }
                .transition(.opacity)
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

                Text("枠に目を合わせたらカメラ目線にしてください")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .position(
                        x: size.width * 0.5,
                        y: min(size.height - 72, ovalRect.maxY + 44)
                    )
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
    @Published private(set) var isReady = false
    @Published private(set) var isCapturing = false
    @Published private(set) var isWarmedUp = false

    private let startupStabilizationDelay: TimeInterval = 1.5
    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "LensFormView.CameraModel.session")
    private var onCapture: ((UIImage?) -> Void)?
    private var activeCameraPosition: AVCaptureDevice.Position = .unspecified
    private var isConfigured = false

    var isCaptureButtonEnabled: Bool {
        isReady && isWarmedUp && isCapturing == false
    }

    func start() {
        Task { @MainActor in
            isReady = false
            isCapturing = false
            isWarmedUp = false
        }

        sessionQueue.async {
            self.configureSessionIfNeeded()
            guard self.session.isRunning == false else {
                Task { @MainActor in self.isReady = true }
                self.markWarmupCompletion()
                return
            }

            self.session.startRunning()
            Task { @MainActor in self.isReady = self.session.isRunning }
            self.markWarmupCompletion()
        }
    }

    func stop() {
        Task { @MainActor in
            isReady = false
            isCapturing = false
            isWarmedUp = false
        }

        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func capture(completion: @escaping (UIImage?) -> Void) {
        guard isCaptureButtonEnabled else { return }
        onCapture = completion

        Task { @MainActor in
            isCapturing = true
            isReady = false
        }

        sessionQueue.async {
            guard self.session.isRunning else {
                Task { @MainActor in
                    self.isCapturing = false
                    self.isReady = false
                }
                self.onCapture?(nil)
                self.onCapture = nil
                return
            }

            let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            settings.flashMode = .off
            settings.photoQualityPrioritization = .balanced
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            finishCapture(with: nil)
            return
        }
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            finishCapture(with: nil)
            return
        }
        finishCapture(with: correctedImageIfNeeded(image))
    }

    private func configureSessionIfNeeded() {
        guard isConfigured == false else { return }

        session.beginConfiguration()
        session.sessionPreset = .photo

        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) ??
            AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            session.commitConfiguration()
            return
        }
        configure(device: device)
        activeCameraPosition = device.position

        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            return
        }
        session.addOutput(output)
        output.isHighResolutionCaptureEnabled = false

        session.commitConfiguration()
        isConfigured = true
    }

    private func markWarmupCompletion() {
        let delay = DispatchTime.now() + startupStabilizationDelay
        sessionQueue.asyncAfter(deadline: delay) {
            Task { @MainActor in
                guard self.session.isRunning else { return }
                self.isWarmedUp = true
            }
        }
    }

    private func configure(device: AVCaptureDevice) {
        guard (try? device.lockForConfiguration()) != nil else { return }
        defer { device.unlockForConfiguration() }

        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        if device.isSmoothAutoFocusSupported {
            device.isSmoothAutoFocusEnabled = true
        }
        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }
        if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
            device.whiteBalanceMode = .continuousAutoWhiteBalance
        }
        device.isSubjectAreaChangeMonitoringEnabled = true
    }

    private func correctedImageIfNeeded(_ image: UIImage) -> UIImage {
        guard activeCameraPosition == .front else { return image }
        return horizontallyFlippedImage(from: image) ?? image
    }

    private func finishCapture(with image: UIImage?) {
        let completion = onCapture
        onCapture = nil

        Task { @MainActor in
            self.isCapturing = false
            self.isReady = self.session.isRunning
            completion?(image)
        }
    }

    private func horizontallyFlippedImage(from image: UIImage) -> UIImage? {
        let normalized = normalizedImage(from: image) ?? image
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = normalized.scale
        let renderer = UIGraphicsImageRenderer(size: normalized.size, format: format)
        return renderer.image { context in
            context.cgContext.translateBy(x: normalized.size.width, y: 0)
            context.cgContext.scaleBy(x: -1, y: 1)
            normalized.draw(in: CGRect(origin: .zero, size: normalized.size))
        }
    }

    private func normalizedImage(from image: UIImage) -> UIImage? {
        if image.imageOrientation == .up { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}
