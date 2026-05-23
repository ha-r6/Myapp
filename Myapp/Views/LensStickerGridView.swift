import SwiftUI
import UIKit

struct LensStickerGridView: View {
    let lenses: [Lens]
    let onDelete: (IndexSet) -> Void

    @State private var category: LensColorCategory = .all

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 14)]

    var body: some View {
        let filtered = filteredLenses()
        ScrollView {
            VStack(spacing: 16) {
                StickerHeaderView()

                Picker("分類", selection: $category) {
                    ForEach(LensColorCategory.allCases) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
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
    }

    private func filteredLenses() -> [Lens] {
        guard category != .all else { return lenses }
        return lenses.filter { $0.colorCategory == category }
    }
}

private struct StickerHeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("レンズ")
                .font(.title.bold())
                .foregroundStyle(.primary)

            Text("シール帳みたいに、購入したカラコンを並べて見返せます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }
}

private struct StickerBackgroundView: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AppTheme.background

                // うっすら縦ストライプ（シール帳っぽい）
                Canvas { context, size in
                    let stripeWidth: CGFloat = 18
                    let stripeColor = Color.black.opacity(0.03)
                    var x: CGFloat = 0
                    while x < size.width + stripeWidth {
                        let rect = CGRect(x: x, y: 0, width: stripeWidth, height: size.height)
                        context.fill(Path(rect), with: .color(stripeColor))
                        x += stripeWidth * 2
                    }
                }
                .opacity(0.9)

                // 角にステッカー風のアクセント
                VStack {
                    HStack {
                        AppTheme.accentGradient
                            .frame(width: min(220, proxy.size.width * 0.55), height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .opacity(0.25)
                            .blur(radius: 0.2)
                            .padding(.leading, 10)
                            .padding(.top, 10)
                        Spacer()
                    }
                    Spacer()
                }
            }
            .ignoresSafeArea()
        }
    }
}

private struct LensStickerCard: View {
    let lens: Lens

    @AppStorage(LensCardSettingsKeys.enabledFields) private var enabledFieldsRaw = LensCardDisplaySettings.serialize(LensCardDisplaySettings.defaultEnabled)

    private var accent: Color {
        AppTheme.pastelColor(seed: lens.id.uuidString)
    }

    private var rotation: Angle {
        let v = AppTheme.seededValue(seed: lens.id.uuidString, modulo: 7) // 0...6
        let degrees = Double(v) - 3.0 // -3...3
        return .degrees(degrees)
    }

    var body: some View {
        let enabled = LensCardDisplaySettings.enabledFields(from: enabledFieldsRaw)
        VStack(alignment: .leading, spacing: 12) {
            // 目の画像（大きめ）＋ステッカー枠
            EyeStickerImage(data: lens.stickerEyeJPEG, tint: accent)

            VStack(alignment: .leading, spacing: 4) {
                if enabled.contains(.brand) {
                    Text(lens.brand.isEmpty ? "（ブランド未設定）" : lens.brand)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if enabled.contains(.productName) {
                    Text(lens.productName.isEmpty ? "（品名未設定）" : lens.productName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }

                if enabled.contains(.graphicDiameter), let gd = lens.graphicDiameter {
                    Text("着色直径 \(String(format: "%.2f", gd))mm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                if enabled.contains(.colorCategory) {
                    StickerPill(text: lens.colorCategory.rawValue, color: accent)
                }
                if enabled.contains(.repeatDecision) {
                    StickerPill(text: lens.repeatDecision.rawValue, color: AppTheme.accent)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.surface)
        )
        .overlay(StickerOutlineShape(cornerRadius: 22).stroke(Color.black.opacity(0.10), lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 7)
        .rotationEffect(rotation)
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

            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 132)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                .frame(height: 132)
            }

            // シールっぽいハイライト
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
}

private struct StickerOutlineShape: Shape {
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path(roundedRect: rect, cornerRadius: cornerRadius)

        // 外周に「切り抜き」っぽいギザギザをほんの少し
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
