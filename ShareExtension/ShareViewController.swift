import UIKit
import UniformTypeIdentifiers
import ImageIO

final class ShareViewController: UIViewController {
    private static let appGroupId = "group.app.yamazaki.ha-san.Myapp"

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let stackView = UIStackView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let closeButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        loadAndRender()
    }

    private func configureUI() {
        view.backgroundColor = .systemBackground

        titleLabel.text = "この日のカラコン"
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.numberOfLines = 1

        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 2

        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.alignment = .fill

        closeButton.setTitle("閉じる", for: .normal)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        let root = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, scrollView, closeButton])
        root.axis = .vertical
        root.spacing = 14
        root.translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)

        view.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            root.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            root.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    @objc private func closeTapped() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func loadAndRender() {
        let targetDay = resolveTargetDay()
        subtitleLabel.text = DateFormatter.localizedString(from: targetDay, dateStyle: .medium, timeStyle: .none)

        let payload = loadStorePayload()
        let dayLogs = payload.wearLogs.filter { Calendar.current.isDate($0.day, inSameDayAs: targetDay) }
        let lensMap = Dictionary(uniqueKeysWithValues: payload.lenses.map { ($0.id, $0) })
        let lenses = dayLogs.compactMap { log -> ShareLens? in
            guard let id = log.lensId, let lens = lensMap[id] else { return nil }
            return lens
        }
        let uniqueLenses = uniqueById(lenses)

        if uniqueLenses.isEmpty {
            addEmptyCard("この日に記録されたカラコンはありません。")
        } else {
            uniqueLenses.forEach { addLensCard($0) }
        }
    }

    private func uniqueById(_ lenses: [ShareLens]) -> [ShareLens] {
        var seen = Set<UUID>()
        var result: [ShareLens] = []
        for lens in lenses {
            if seen.contains(lens.id) { continue }
            seen.insert(lens.id)
            result.append(lens)
        }
        return result
    }

    private func resolveTargetDay() -> Date {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments, attachments.isEmpty == false else {
            return Calendar.current.startOfDay(for: Date())
        }

        let providers = attachments
        let group = DispatchGroup()
        var resolvedDate: Date?

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, _ in
                defer { group.leave() }
                if let url = item as? URL,
                   let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                   let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                   let date = Self.extractDate(from: metadata) {
                    resolvedDate = Calendar.current.startOfDay(for: date)
                    return
                }
                if let image = item as? UIImage,
                   let data = image.jpegData(compressionQuality: 1.0),
                   let source = CGImageSourceCreateWithData(data as CFData, nil),
                   let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                   let date = Self.extractDate(from: metadata) {
                    resolvedDate = Calendar.current.startOfDay(for: date)
                }
            }
            break
        }

        _ = group.wait(timeout: .now() + 1.2)
        return resolvedDate ?? Calendar.current.startOfDay(for: Date())
    }

    private static func extractDate(from metadata: [CFString: Any]) -> Date? {
        let exif = metadata[kCGImagePropertyExifDictionary] as? [CFString: Any]
        guard let raw = exif?[kCGImagePropertyExifDateTimeOriginal] as? String ?? exif?[kCGImagePropertyExifDateTimeDigitized] as? String else {
            return nil
        }
        let df = DateFormatter()
        df.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return df.date(from: raw)
    }

    private func loadStorePayload() -> StorePayload {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupId)?
            .appendingPathComponent("colorcon_store.json"),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(StorePayload.self, from: data) else {
            return StorePayload(lenses: [], wearLogs: [])
        }
        return payload
    }

    private func addLensCard(_ lens: ShareLens) {
        let card = UIView()
        card.backgroundColor = UIColor.systemBackground
        card.layer.cornerRadius = 16

        let imageArea = UIView()
        imageArea.backgroundColor = UIColor.systemGray6
        imageArea.layer.cornerRadius = 12
        imageArea.clipsToBounds = true
        imageArea.translatesAutoresizingMaskIntoConstraints = false

        if let data = lens.stickerEyeJPEG, let image = UIImage(data: data) {
            let iv = UIImageView(image: image)
            iv.contentMode = .scaleAspectFill
            iv.clipsToBounds = true
            iv.layer.cornerRadius = 10
            iv.translatesAutoresizingMaskIntoConstraints = false
            imageArea.addSubview(iv)
            NSLayoutConstraint.activate([
                iv.leadingAnchor.constraint(equalTo: imageArea.leadingAnchor),
                iv.trailingAnchor.constraint(equalTo: imageArea.trailingAnchor),
                iv.topAnchor.constraint(equalTo: imageArea.topAnchor),
                iv.bottomAnchor.constraint(equalTo: imageArea.bottomAnchor),
            ])
        } else {
            let empty = UILabel()
            empty.text = "目の写真がありません"
            empty.font = .preferredFont(forTextStyle: .caption1)
            empty.textColor = .secondaryLabel
            empty.translatesAutoresizingMaskIntoConstraints = false
            imageArea.addSubview(empty)
            NSLayoutConstraint.activate([
                empty.centerXAnchor.constraint(equalTo: imageArea.centerXAnchor),
                empty.centerYAnchor.constraint(equalTo: imageArea.centerYAnchor),
            ])
        }

        let brand = UILabel()
        brand.text = lens.brand.trimmedOrNil ?? ""
        brand.textColor = .secondaryLabel
        brand.font = .preferredFont(forTextStyle: .caption1)

        let title = UILabel()
        title.text = lens.displayName
        title.numberOfLines = 2
        title.font = .preferredFont(forTextStyle: .headline)

        let pillRow = UIStackView()
        pillRow.axis = .horizontal
        pillRow.spacing = 8
        pillRow.alignment = .leading

        if let gd = lens.graphicDiameter {
            pillRow.addArrangedSubview(makePill("着色直径 \(String(format: "%.1f", gd))mm"))
        }
        pillRow.addArrangedSubview(makePill(lens.colorCategoryRaw))
        pillRow.addArrangedSubview(makePill(lens.repeatDecisionRaw))

        let v = UIStackView(arrangedSubviews: [imageArea, brand, title, pillRow])
        v.axis = .vertical
        v.spacing = 8
        v.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(v)
        NSLayoutConstraint.activate([
            v.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            v.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            v.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            v.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            imageArea.heightAnchor.constraint(equalToConstant: 124),
        ])

        stackView.addArrangedSubview(card)
    }

    private func makePill(_ text: String) -> UIView {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .caption2)
        label.textColor = .label
        label.setContentCompressionResistancePriority(.required, for: .horizontal)

        let container = UIView()
        container.backgroundColor = UIColor.systemGray6
        container.layer.cornerRadius = 12
        container.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 5),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -5),
        ])
        return container
    }

    private func addEmptyCard(_ message: String) {
        let label = UILabel()
        label.text = message
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .body)
        stackView.addArrangedSubview(label)
    }
}

private struct StorePayload: Codable {
    var lenses: [ShareLens]
    var wearLogs: [ShareWearLog]
}

private struct ShareLens: Codable {
    var id: UUID
    var brand: String
    var productName: String
    var colorName: String
    var colorCategoryRaw: String
    var repeatDecisionRaw: String
    var graphicDiameter: Double?
    var stickerEyeJPEG: Data?

    var displayName: String {
        let base = [brand.trimmedOrNil, productName.trimmedOrNil].compactMap { $0 }.joined(separator: " ")
        if colorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return base.isEmpty ? "（名称未設定）" : base
        }
        return base.isEmpty ? colorName : "\(base) / \(colorName)"
    }
}

private struct ShareWearLog: Codable {
    var id: UUID
    var day: Date
    var lensId: UUID?
}

private extension String {
    var trimmedOrNil: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
