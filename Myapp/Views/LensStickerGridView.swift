import SwiftUI
import UIKit

struct LensStickerGridView: View {
    let lenses: [Lens]
    let onDelete: (IndexSet) -> Void

    @State private var filter = LensStickerFilter()
    @State private var showingFilterSheet = false

    private let repeatDecisionOptions: [RepeatDecisionChoice] = [.all] + RepeatDecision.allCases.map { .value($0) }

    private var bcOptions: [OptionalDoubleChoice] {
        let choices = lenses.map { OptionalDoubleChoice.from($0.bc) }
        let unique = Array(Set(choices)).sorted()
        return [.all] + unique
    }

    private var graphicDiameterOptions: [OptionalDoubleChoice] {
        let choices = lenses.map { OptionalDoubleChoice.from($0.graphicDiameter) }
        let unique = Array(Set(choices)).sorted()
        return [.all] + unique
    }

    private var colorCategoryOptions: [LensColorCategory] {
        LensColorCategory.allCases
    }

    private let columns = [
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 14),
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 14),
    ]

    var body: some View {
        let filtered = filteredLenses()
        ScrollView {
            VStack(spacing: 16) {
                StickerPageHeaderView(
                    title: "図鑑"
                )

                HStack(spacing: 10) {
                    if let facet = filter.activeFacet {
                        ScrollView(.horizontal, showsIndicators: false) {
                            Group {
                                switch facet {
                                case .repeatDecision:
                                    Picker("リピ", selection: $filter.repeatDecision) {
                                        ForEach(repeatDecisionOptions) { option in
                                            Text(option.label).tag(option)
                                        }
                                    }

                                case .bc:
                                    Picker("BC", selection: $filter.bcChoice) {
                                        ForEach(bcOptions) { option in
                                            Text(option.label).tag(option)
                                        }
                                    }

                                case .graphicDiameter:
                                    Picker("着色直径", selection: $filter.graphicDiameterChoice) {
                                        ForEach(graphicDiameterOptions) { option in
                                            Text(option.label).tag(option)
                                        }
                                    }

                                case .colorCategory:
                                    Picker("色系統", selection: $filter.colorCategory) {
                                        ForEach(colorCategoryOptions) { cat in
                                            Text(cat.rawValue).tag(cat)
                                        }
                                    }
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.leading, 12)
                            .padding(.vertical, 4)
                        }
                    } else {
                        Text("絞り込み")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 12)
                            .padding(.vertical, 12)
                    }

                    Button {
                        showingFilterSheet = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .imageScale(.large)
                            .accessibilityLabel("絞り込み")
                            .padding(.trailing, 12)
                    }
                }
                .appCard()
                .padding(.horizontal, 16)

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(filtered) { lens in
                        NavigationLink {
                            LensDetailView(lensId: lens.id)
                        } label: {
                            LensStickerCard(lens: lens)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                if let index = lenses.firstIndex(where: { $0.id == lens.id }) {
                                    onDelete(IndexSet(integer: index))
                                }
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(StickerBackgroundView())
        .sheet(isPresented: $showingFilterSheet) {
            NavigationStack {
                LensStickerFilterSheet(
                    lenses: lenses,
                    filter: $filter
                )
            }
        }
    }

    private func filteredLenses() -> [Lens] {
        lenses
            .filter { filter.matches($0) }
    }
}

private struct LensStickerFilter: Hashable {
    var activeFacet: LensStickerFilterFacet? = nil
    var repeatDecision: RepeatDecisionChoice = .all
    var bcChoice: OptionalDoubleChoice = .all
    var graphicDiameterChoice: OptionalDoubleChoice = .all
    var colorCategory: LensColorCategory = .all

    var isDefault: Bool {
        repeatDecision == .all
            && bcChoice == .all
            && graphicDiameterChoice == .all
            && colorCategory == .all
    }

    var summaryText: String {
        isDefault ? "すべて" : "絞り込み中"
    }

    func matches(_ lens: Lens) -> Bool {
        if repeatDecision != .all, repeatDecision.value != lens.repeatDecision {
            return false
        }
        if bcChoice != .all, bcChoice != OptionalDoubleChoice.from(lens.bc) {
            return false
        }
        if graphicDiameterChoice != .all, graphicDiameterChoice != OptionalDoubleChoice.from(lens.graphicDiameter) {
            return false
        }
        if colorCategory != .all, colorCategory != lens.colorCategory {
            return false
        }
        return true
    }
}

private enum LensStickerFilterFacet: String, CaseIterable, Identifiable {
    case repeatDecision = "リピ"
    case bc = "BC"
    case graphicDiameter = "着色直径"
    case colorCategory = "色系統"

    var id: String { rawValue }
}

private enum RepeatDecisionChoice: Hashable, Identifiable {
    case all
    case value(RepeatDecision)

    var id: String {
        switch self {
        case .all:
            return "all"
        case .value(let v):
            return v.id
        }
    }

    var label: String {
        switch self {
        case .all:
            return "すべて"
        case .value(let v):
            return v.rawValue
        }
    }

    var value: RepeatDecision? {
        switch self {
        case .all:
            return nil
        case .value(let v):
            return v
        }
    }
}

private enum OptionalDoubleChoice: Hashable, Comparable, Identifiable {
    case all
    case unset
    case value(Double)

    var id: String {
        switch self {
        case .all:
            return "all"
        case .unset:
            return "unset"
        case .value(let v):
            return String(format: "%.2f", v)
        }
    }

    var label: String {
        switch self {
        case .all:
            return "すべて"
        case .unset:
            return "未設定"
        case .value(let v):
            return String(format: "%.2f", v)
        }
    }

    static func from(_ value: Double?) -> Self {
        guard let value else { return .unset }
        return .value(value.roundedTo2())
    }

    static func < (lhs: OptionalDoubleChoice, rhs: OptionalDoubleChoice) -> Bool {
        switch (lhs, rhs) {
        case (.all, .all):
            return false
        case (.all, _):
            return true
        case (_, .all):
            return false
        case (.value(let a), .value(let b)):
            return a < b
        case (.value, .unset):
            return true
        case (.unset, .value):
            return false
        case (.unset, .unset):
            return false
        }
    }
}

private extension Double {
    func roundedTo2() -> Double {
        (self * 100).rounded() / 100
    }
}

private struct LensStickerFilterSheet: View {
    let lenses: [Lens]
    @Binding var filter: LensStickerFilter
    @Environment(\.dismiss) private var dismiss

    private var repeatDecisionOptions: [RepeatDecisionChoice] {
        [.all] + RepeatDecision.allCases.map { .value($0) }
    }

    private var bcOptions: [OptionalDoubleChoice] {
        let choices = lenses.map { OptionalDoubleChoice.from($0.bc) }
        let unique = Array(Set(choices)).sorted()
        return [.all] + unique
    }

    private var graphicDiameterOptions: [OptionalDoubleChoice] {
        let choices = lenses.map { OptionalDoubleChoice.from($0.graphicDiameter) }
        let unique = Array(Set(choices)).sorted()
        return [.all] + unique
    }

    private var colorCategoryOptions: [LensColorCategory] {
        LensColorCategory.allCases
    }

    var body: some View {
        List {
            Section("表示する項目（1つ）") {
                ForEach(LensStickerFilterFacet.allCases) { facet in
                    Button {
                        if filter.activeFacet == facet {
                            filter.activeFacet = nil
                        } else {
                            filter.activeFacet = facet
                        }
                    } label: {
                        HStack {
                            Text(facet.rawValue)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: filter.activeFacet == facet ? "checkmark.square.fill" : "square")
                                .foregroundStyle(filter.activeFacet == facet ? AppTheme.accent : .secondary)
                                .imageScale(.large)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("絞り込み")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("閉じる") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") { dismiss() }
            }
        }
    }
}

// MARK: - Shared "Sticker" UI components

struct StickerPageHeaderView: View {
    let title: String
    let subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title.bold())
                .foregroundStyle(.primary)

            if let subtitle, subtitle.isEmpty == false {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }
}

struct StickerBackgroundView: View {
    var body: some View {
        GeometryReader { _ in
            ZStack {
                AppTheme.background

                Canvas { context, size in
                    let stripeWidth: CGFloat = 18
                    let stripeColor = Color.black.opacity(0.02)
                    var x: CGFloat = 0
                    while x < size.width + stripeWidth {
                        let rect = CGRect(x: x, y: 0, width: stripeWidth, height: size.height)
                        context.fill(Path(rect), with: .color(stripeColor))
                        x += stripeWidth * 2
                    }
                }
            }
            .ignoresSafeArea()
        }
    }
}

struct LensStickerCard: View {
    let lens: Lens

    @AppStorage(LensCardSettingsKeys.enabledFields) private var enabledFieldsRaw = LensCardDisplaySettings.serialize(LensCardDisplaySettings.defaultEnabled)

    private var accent: Color {
        AppTheme.pastelColor(seed: lens.id.uuidString)
    }

    var body: some View {
        let enabled = LensCardDisplaySettings.enabledFields(from: enabledFieldsRaw)
        VStack(alignment: .leading, spacing: 12) {
            EyeStickerImage(data: lens.stickerEyeJPEG, tint: accent)

            VStack(alignment: .leading, spacing: 4) {
                if enabled.contains(.brand) {
                    Text(lens.brand.isEmpty ? "（ブランド未設定）" : lens.brand)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if enabled.contains(.productName) || lens.colorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        if enabled.contains(.productName) {
                            Text(lens.productName.isEmpty ? "（品名未設定）" : lens.productName)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .layoutPriority(2)
                        }
                        if lens.colorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                            Text(lens.colorName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .layoutPriority(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // 着色直径はピル表示へ
            }

            VStack(alignment: .leading, spacing: 8) {
                if enabled.contains(.graphicDiameter), let gd = lens.graphicDiameter {
                    HStack(spacing: 8) {
                        StickerPill(text: "着色直径 \(String(format: "%.1f", gd))mm", color: accent)
                        Spacer(minLength: 0)
                    }
                }

                HStack(spacing: 8) {
                    if enabled.contains(.colorCategory) {
                        StickerPill(text: lens.colorCategory.rawValue, color: accent)
                    }
                    if enabled.contains(.repeatDecision) {
                        StickerPill(text: lens.repeatDecision.rawValue, color: AppTheme.accent)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 294, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.surface)
        )
        .overlay(StickerOutlineShape(cornerRadius: 22).stroke(Color.black.opacity(0.10), lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 7)
    }
}

private struct EyeStickerImage: View {
    let data: Data?
    let tint: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tint.opacity(0.10))

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white)
                .padding(6)

            if let data, let image = UIImage(data: data), let stickerImage = normalizedImage(from: image) {
                Image(uiImage: stickerImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, minHeight: 132, maxHeight: 132, alignment: .center)
                    .clipShape(Ellipse())
                    .padding(10)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "camera.macro")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(tint)
                    Text("目の写真がありません")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 132, maxHeight: 132, alignment: .center)
            }

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.65), Color.white.opacity(0.0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.softLight)
                .opacity(0.7)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 148)
        .overlay(StickerOutlineShape(cornerRadius: 18).stroke(Color.black.opacity(0.10), lineWidth: 1))
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

private struct StickerOutlineShape: Shape {
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path(roundedRect: rect, cornerRadius: cornerRadius)

        let teeth: Int = 18
        let depth: CGFloat = 3
        let insetRect = rect.insetBy(dx: 2, dy: 2)
        let step = insetRect.width / CGFloat(teeth)

        for i in 0..<teeth {
            let x = insetRect.minX + CGFloat(i) * step + step * 0.5
            let yTop = insetRect.minY
            p.addEllipse(in: CGRect(x: x - depth, y: yTop - depth * 0.6, width: depth * 2, height: depth * 2))
        }
        return p
    }
}

private struct StickerPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.primary.opacity(0.8))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.16), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.25), lineWidth: 1))
            .lineLimit(1)
    }
}
