import SwiftUI
import UIKit

struct LensStickerGridView: View {
    let lenses: [Lens]
    let onDelete: (IndexSet) -> Void

    @State private var filter = LensStickerFilter()
    @State private var showingFilterSheet = false
    @State private var pendingDeleteLens: Lens?

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

    private let horizontalPadding: CGFloat = 16
    private let cardSpacing: CGFloat = 12

    private var cardWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let available = screenWidth - (horizontalPadding * 2) - cardSpacing
        return floor(available / 2)
    }

    private var columns: [GridItem] {
        [
            GridItem(.fixed(cardWidth), spacing: cardSpacing, alignment: .top),
            GridItem(.fixed(cardWidth), spacing: cardSpacing, alignment: .top),
        ]
    }

    var body: some View {
        let filtered = filteredLenses()
        ZStack {
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
                                    case .none:
                                        EmptyView()
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

                    LazyVGrid(columns: columns, spacing: cardSpacing) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, lens in
                            NavigationLink {
                                LensDetailView(lensId: lens.id)
                            } label: {
                                LensStickerCard(lens: lens, paletteIndex: index)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    pendingDeleteLens = lens
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
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

            if let lens = pendingDeleteLens {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .onTapGesture {
                        pendingDeleteLens = nil
                    }

                VStack(spacing: 12) {
                    Text("このカラコンを削除しますか？")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("削除すると、このカラコンの情報は元に戻せません。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 12) {
                        Button("キャンセル") {
                            pendingDeleteLens = nil
                        }
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())

                        Button("削除する") {
                            if let index = lenses.firstIndex(where: { $0.id == lens.id }) {
                                onDelete(IndexSet(integer: index))
                            }
                            pendingDeleteLens = nil
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .clipShape(Capsule())
                    }
                }
                .padding(20)
                .frame(maxWidth: 320)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
                .padding(.horizontal, 24)
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
        switch activeFacet {
        case nil:
            return true
        case .some(.none):
            return true
        case .repeatDecision:
            return repeatDecision == .all
        case .bc:
            return bcChoice == .all
        case .graphicDiameter:
            return graphicDiameterChoice == .all
        case .colorCategory:
            return colorCategory == .all
        }
    }

    var summaryText: String {
        isDefault ? "すべて" : "絞り込み中"
    }

    func matches(_ lens: Lens) -> Bool {
        switch activeFacet {
        case nil:
            return true
        case .some(.none):
            return true
        case .repeatDecision:
            if repeatDecision != .all, repeatDecision.value != lens.repeatDecision {
                return false
            }
        case .bc:
            if bcChoice != .all, bcChoice != OptionalDoubleChoice.from(lens.bc) {
                return false
            }
        case .graphicDiameter:
            if graphicDiameterChoice != .all, graphicDiameterChoice != OptionalDoubleChoice.from(lens.graphicDiameter) {
                return false
            }
        case .colorCategory:
            if colorCategory != .all, colorCategory != lens.colorCategory {
                return false
            }
        }
        return true
    }
}

private enum LensStickerFilterFacet: String, CaseIterable, Identifiable {
    case none = "絞り込みなし"
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

    private var facetOptions: [LensStickerFilterFacet] {
        [.none, .repeatDecision, .bc, .graphicDiameter, .colorCategory]
    }

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
                ForEach(facetOptions) { facet in
                    Button {
                        if facet == .none {
                            filter.activeFacet = nil
                        } else if filter.activeFacet == facet {
                            filter.activeFacet = nil
                        } else {
                            filter.activeFacet = facet
                        }
                    } label: {
                        HStack {
                            Text(facet.rawValue)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: isFacetSelected(facet) ? "checkmark.square.fill" : "square")
                                .foregroundStyle(isFacetSelected(facet) ? AppTheme.accent : .secondary)
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

    private func isFacetSelected(_ facet: LensStickerFilterFacet) -> Bool {
        if facet == .none {
            return filter.activeFacet == nil
        }
        return filter.activeFacet == facet
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
    let paletteIndex: Int?
    private let cardHeight: CGFloat = 294

    private var accent: Color {
        if let paletteIndex {
            return AppTheme.pastelColor(index: paletteIndex)
        }
        return AppTheme.pastelColor(seed: lens.id.uuidString)
    }

    private var colorCategoryColor: Color {
        switch lens.colorCategory {
        case .all:
            return accent
        case .black:
            return Color(red: 0.74, green: 0.76, blue: 0.80)
        case .brown:
            return Color(red: 0.82, green: 0.69, blue: 0.56)
        case .gray:
            return Color(red: 0.70, green: 0.85, blue: 0.96)
        case .olive:
            return Color(red: 0.77, green: 0.88, blue: 0.50)
        case .other:
            return Color(red: 0.88, green: 0.72, blue: 0.90)
        }
    }

    private var repeatDecisionColor: Color {
        switch lens.repeatDecision {
        case .yes:
            return Color(red: 0.98, green: 0.72, blue: 0.84)
        case .no:
            return Color(red: 0.69, green: 0.88, blue: 0.98)
        case .maybe:
            return Color(red: 0.98, green: 0.90, blue: 0.56)
        }
    }

    private var graphicDiameterColor: Color {
        guard let gd = lens.graphicDiameter else { return accent }
        switch gd {
        case ..<13.0:
            return Color(red: 0.84, green: 0.78, blue: 0.97)
        case 13.0..<13.5:
            return Color(red: 0.98, green: 0.79, blue: 0.87)
        default:
            return Color(red: 0.99, green: 0.83, blue: 0.67)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            EyeStickerImage(data: lens.stickerEyeJPEG, tint: accent)

            VStack(alignment: .leading, spacing: 6) {
                Text(lens.brand.isEmpty ? "（ブランド未設定）" : lens.brand)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if lens.productName.isEmpty == false || lens.colorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(lens.productName.isEmpty ? "（品名未設定）" : lens.productName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .minimumScaleFactor(0.82)
                            .layoutPriority(2)

                        if lens.colorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                            Text(lens.colorName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .minimumScaleFactor(0.85)
                                .layoutPriority(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipped()
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                if let gd = lens.graphicDiameter {
                    HStack(spacing: 8) {
                        StickerPill(text: "着色直径 \(String(format: "%.1f", gd))mm", color: graphicDiameterColor)
                        Spacer(minLength: 0)
                    }
                }

                HStack(spacing: 6) {
                    StickerPill(text: lens.colorCategory.rawValue, color: colorCategoryColor)
                    StickerPill(text: lens.repeatDecision.rawValue, color: repeatDecisionColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .frame(height: cardHeight, alignment: .topLeading)
        .clipped()
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.surface)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(StickerOutlineShape(cornerRadius: 22).stroke(Color.black.opacity(0.10), lineWidth: 1))
        .shadow(color: .black.opacity(0.01), radius: 1, x: 0, y: 1)
    }
}

private struct EyeStickerImage: View {
    let data: Data?
    let tint: Color
    private let imageAreaHeight: CGFloat = 126

    private var placeholderBackgroundOpacity: Double {
        0.16
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tint.opacity(placeholderBackgroundOpacity))

            Group {
                if let data, let image = UIImage(data: data), let stickerImage = normalizedImage(from: image) {
                    Image(uiImage: stickerImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, minHeight: imageAreaHeight - 14, maxHeight: imageAreaHeight - 14, alignment: .center)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "camera.macro")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(tint)
                        Text("目の写真がありません")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: imageAreaHeight - 14, maxHeight: imageAreaHeight - 14, alignment: .center)
                }
            }
            .padding(8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: imageAreaHeight)
        .clipped()
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
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 30)
            .background(color.opacity(0.24), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.45), lineWidth: 1))
            .lineLimit(1)
    }
}
