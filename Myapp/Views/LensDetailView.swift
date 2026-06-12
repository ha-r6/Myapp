import SwiftUI

struct LensDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    let lensId: UUID
    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false

    var body: some View {
        ZStack {
            if let lens = store.lens(id: lensId) {
                let logs = store.wearLogs(for: lensId)
                let memoLogs = logs.filter {
                    $0.memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                }
                let lensMemo = lens.memo.trimmingCharacters(in: .whitespacesAndNewlines)

                ScrollView {
                    VStack(spacing: 18) {
                        LensDetailHeroCard(lens: lens)

                        LensDetailSectionCard(
                            title: "基本",
                            tint: heroAccent(for: lens).opacity(0.30)
                        ) {
                            VStack(spacing: 12) {
                                LensDetailRow(label: "名称", value: lens.displayName)
                                LensDetailRow(label: "購入場所", value: lens.purchasePlace.isEmpty ? "—" : lens.purchasePlace)
                            }
                        }

                        LensDetailSectionCard(
                            title: "スペック",
                            tint: specAccent(for: lens).opacity(0.26)
                        ) {
                            VStack(spacing: 12) {
                                LensDetailRow(label: "着色直径", value: lens.graphicDiameter.map { String(format: "%.1f", $0) } ?? "—")
                                LensDetailRow(label: "BC", value: lens.bc.map { String(format: "%.1f", $0) } ?? "—")
                                LensDetailRow(label: "DIA", value: lens.dia.map { String(format: "%.1f", $0) } ?? "—")
                                LensDetailRow(label: "含水率", value: lens.waterContentCategory?.rawValue ?? "—")
                                LensDetailRow(label: "度あり/なし", value: lens.isPrescription ? "度あり" : "度なし")
                                if lens.isPrescription {
                                    LensDetailRow(label: "度数", value: powerDisplayText(for: lens))
                                }
                                LensDetailRow(
                                    label: "使用期間",
                                    value: lens.replacementDays.map(replacementLabel(days:)) ?? "—"
                                )
                            }
                        }

                        LensDetailSectionCard(
                            title: "リピ",
                            tint: repeatAccent(for: lens).opacity(0.28)
                        ) {
                            VStack(alignment: .leading, spacing: 12) {
                                LensDetailRow(label: "判断", value: lens.repeatDecision.rawValue)
                                if lens.repeatMemo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                                    LensDetailNote(text: lens.repeatMemo)
                                }
                            }
                        }

                        LensDetailSectionCard(
                            title: "メモ",
                            tint: AppTheme.pastelColor(seed: lens.id.uuidString).opacity(0.24)
                        ) {
                            if lensMemo.isEmpty, memoLogs.isEmpty {
                                Text("まだメモはありません")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                VStack(alignment: .leading, spacing: 14) {
                                    if lensMemo.isEmpty == false {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("レンズメモ")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                            LensDetailNote(text: lensMemo)
                                        }
                                    }

                                    if memoLogs.isEmpty == false {
                                        VStack(alignment: .leading, spacing: 10) {
                                            Text("装着日のメモ")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.secondary)

                                            ForEach(memoLogs) { log in
                                                VStack(alignment: .leading, spacing: 6) {
                                                    Text(AppDateFormatters.day.string(from: log.day))
                                                        .font(.headline)
                                                    Text(log.memo)
                                                        .font(.subheadline)
                                                        .foregroundStyle(.secondary)
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                }
                                                .padding(12)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                        .fill(AppTheme.surface)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                        .stroke(AppTheme.hairline, lineWidth: 1)
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        LensDetailSectionCard(
                            title: "装着記録",
                            tint: Color(red: 0.76, green: 0.86, blue: 0.99).opacity(0.26)
                        ) {
                            if logs.isEmpty {
                                Text("まだ記録がありません")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(logs) { log in
                                        NavigationLink {
                                            WearLogDetailView(wearLogId: log.id)
                                        } label: {
                                            HStack(spacing: 12) {
                                                Circle()
                                                    .fill(heroAccent(for: lens))
                                                    .frame(width: 10, height: 10)
                                                Text(AppDateFormatters.day.string(from: log.day))
                                                    .font(.headline)
                                                    .foregroundStyle(.primary)
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.caption.weight(.bold))
                                                    .foregroundStyle(.secondary)
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 14)
                                            .background(
                                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                    .fill(AppTheme.surface)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                    .stroke(AppTheme.hairline, lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
            } else {
                ContentUnavailableView("レンズが見つかりません", systemImage: "exclamationmark.triangle")
            }

            if showingDeleteConfirm {
                DestructiveConfirmationDialog(
                    title: "このカラコンを削除しますか？",
                    message: "このカラコンに紐づく記録もすべて削除されます。",
                    cancelTitle: "キャンセル",
                    destructiveTitle: "削除する",
                    onCancel: {
                        showingDeleteConfirm = false
                    },
                    onConfirm: {
                        let relatedLogIds = store.wearLogs(for: lensId).map(\.id)
                        if relatedLogIds.isEmpty == false {
                            store.deleteWearLogs(relatedLogIds)
                        }
                        store.deleteLens(id: lensId)
                        showingDeleteConfirm = false
                        dismiss()
                    }
                )
            }
        }
        .navigationTitle("レンズ詳細")
        .background(
            LinearGradient(
                colors: [
                    AppTheme.background,
                    Color(red: 0.99, green: 0.95, blue: 0.97).opacity(0.55),
                    AppTheme.background
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("編集") { showingEdit = true }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showingDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .accessibilityLabel("削除")
                }
            }
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .sheet(isPresented: $showingEdit) {
            NavigationStack {
                if let lens = store.lens(id: lensId) {
                    LensFormView(editing: lens)
                } else {
                    Text("レンズが見つかりません")
                }
            }
        }
    }

    private func powerDisplayText(for lens: Lens) -> String {
        let left = lens.leftPower ?? lens.power
        let right = lens.rightPower ?? lens.power
        if let left, let right {
            return "左 \(String(format: "%.2f", left)) / 右 \(String(format: "%.2f", right))"
        }
        if let left { return "左 \(String(format: "%.2f", left))" }
        if let right { return "右 \(String(format: "%.2f", right))" }
        return "—"
    }

    private func replacementLabel(days: Int) -> String {
        switch days {
        case 1: return "1day"
        case 14: return "2weeks"
        case 30: return "1month"
        default: return "\(days)日"
        }
    }

    private func heroAccent(for lens: Lens) -> Color {
        switch lens.colorCategory {
        case .all:
            return AppTheme.pastelColor(seed: lens.id.uuidString)
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

    private func repeatAccent(for lens: Lens) -> Color {
        switch lens.repeatDecision {
        case .yes:
            return Color(red: 0.98, green: 0.72, blue: 0.84)
        case .no:
            return Color(red: 0.69, green: 0.88, blue: 0.98)
        case .maybe:
            return Color(red: 0.98, green: 0.90, blue: 0.56)
        }
    }

    private func specAccent(for lens: Lens) -> Color {
        guard let gd = lens.graphicDiameter else { return heroAccent(for: lens) }
        switch gd {
        case ..<13.0:
            return Color(red: 0.84, green: 0.78, blue: 0.97)
        case 13.0..<13.5:
            return Color(red: 0.98, green: 0.79, blue: 0.87)
        default:
            return Color(red: 0.99, green: 0.83, blue: 0.67)
        }
    }
}

private struct LensDetailHeroCard: View {
    let lens: Lens

    private var accent: Color {
        switch lens.colorCategory {
        case .all:
            return AppTheme.pastelColor(seed: lens.id.uuidString)
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

    private var repeatColor: Color {
        switch lens.repeatDecision {
        case .yes:
            return Color(red: 0.98, green: 0.72, blue: 0.84)
        case .no:
            return Color(red: 0.69, green: 0.88, blue: 0.98)
        case .maybe:
            return Color(red: 0.98, green: 0.90, blue: 0.56)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                LensDetailStickerPreview(data: lens.stickerEyeJPEG)
                    .frame(width: 138, height: 164)

                VStack(alignment: .leading, spacing: 10) {
                    Text(lens.brand.isEmpty ? "（ブランド未設定）" : lens.brand)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    Text(lens.productName.isEmpty ? "（品名未設定）" : lens.productName)
                        .font(.title2.weight(.black))
                        .foregroundStyle(.primary)

                    if lens.colorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                        Text(lens.colorName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    HStack(spacing: 8) {
                        LensDetailPill(text: lens.colorCategory.rawValue, color: accent)
                        LensDetailPill(text: lens.repeatDecision.rawValue, color: repeatColor)
                    }
                }
            }

            if let gd = lens.graphicDiameter {
                Text("着色直径 \(String(format: "%.1f", gd))mm")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(accent.opacity(0.20), in: Capsule())
                    .overlay(Capsule().stroke(accent.opacity(0.55), lineWidth: 1.5))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.22),
                            repeatColor.opacity(0.16),
                            AppTheme.surface
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(accent.opacity(0.30), lineWidth: 1)
        )
        .shadow(color: accent.opacity(0.12), radius: 16, x: 0, y: 8)
    }
}

private struct LensDetailSectionCard<Content: View>: View {
    let title: String
    let tint: Color
    let content: Content

    init(title: String, tint: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Circle()
                    .fill(tint)
                    .frame(width: 12, height: 12)

                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(tint.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: tint.opacity(0.10), radius: 12, x: 0, y: 6)
    }
}

private struct LensDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)

            Text(value)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct LensDetailPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(color.opacity(0.24), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.45), lineWidth: 1))
            .lineLimit(1)
    }
}

private struct LensDetailNote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.hairline, lineWidth: 1)
            )
    }
}

private struct LensDetailStickerPreview: View {
    let data: Data?

    var body: some View {
        if let data, let uiImage = UIImage(data: data) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(AppTheme.hairline, lineWidth: 1)
                    )

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
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(AppTheme.hairline, lineWidth: 1)
                    )

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

// Previews are intentionally omitted in this repository environment.
