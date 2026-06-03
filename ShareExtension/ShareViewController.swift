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
        subtitleLabel.text = Self.japaneseDayFormatter.string(from: targetDay)

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

        let group = DispatchGroup()
        var resolvedDate: Date?

        for provider in attachments where provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            group.enter()
            resolveCaptureDate(from: provider) { date in
                if let date, resolvedDate == nil {
                    resolvedDate = Calendar.current.startOfDay(for: date)
                }
                group.leave()
            }
            break
        }

        _ = group.wait(timeout: .now() + 2.5)
        return resolvedDate ?? Calendar.current.startOfDay(for: Date())
    }

    private func resolveCaptureDate(from provider: NSItemProvider, completion: @escaping (Date?) -> Void) {
        let candidateTypes: [UTType] = [.heic, .jpeg, .png, .image]
        loadCaptureDateUsingFileRepresentation(from: provider, candidateTypes: candidateTypes) { date in
            if let date {
                completion(date)
                return
            }

            provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, _ in
                if let url = item as? URL,
                   let date = Self.captureDate(fromImageAt: url) {
                    completion(date)
                    return
                }

                if let image = item as? UIImage,
                   let data = image.jpegData(compressionQuality: 1.0),
                   let date = Self.captureDate(fromImageData: data) {
                    completion(date)
                    return
                }

                completion(nil)
            }
        }
    }

    private func loadCaptureDateUsingFileRepresentation(
        from provider: NSItemProvider,
        candidateTypes: [UTType],
        completion: @escaping (Date?) -> Void
    ) {
        guard let type = candidateTypes.first(where: { provider.hasItemConformingToTypeIdentifier($0.identifier) }) else {
            completion(nil)
            return
        }

        provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, _ in
            if let url, let date = Self.captureDate(fromImageAt: url) {
                completion(date)
                return
            }

            let remaining = candidateTypes.filter { $0 != type }
            if remaining.isEmpty {
                completion(nil)
            } else {
                self.loadCaptureDateUsingFileRepresentation(from: provider, candidateTypes: remaining, completion: completion)
            }
        }
    }

    private static func captureDate(fromImageAt url: URL) -> Date? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }
        if let date = extractDate(from: metadata) {
            return date
        }
        let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        return values?.creationDate ?? values?.contentModificationDate
    }

    private static func captureDate(fromImageData data: Data) -> Date? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }
        return extractDate(from: metadata)
    }

    private static func extractDate(from metadata: [CFString: Any]) -> Date? {
        let exif = metadata[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = metadata[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        guard let raw = exif?[kCGImagePropertyExifDateTimeOriginal] as? String
            ?? exif?[kCGImagePropertyExifDateTimeDigitized] as? String
            ?? tiff?[kCGImagePropertyTIFFDateTime] as? String else {
            return nil
        }
        let df = DateFormatter()
        df.dateFormat = "yyyy:MM:dd HH:mm:ss"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df.date(from: raw)
    }

    private static let japaneseDayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ja_JP")
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()

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
        card.layer.cornerRadius = 22
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.black.withAlphaComponent(0.10).cgColor

        let imageArea = UIView()
        imageArea.backgroundColor = backgroundAccentColor(for: lens).withAlphaComponent(0.10)
        imageArea.layer.cornerRadius = 18
        imageArea.clipsToBounds = true
        imageArea.translatesAutoresizingMaskIntoConstraints = false
        imageArea.layer.borderWidth = 1
        imageArea.layer.borderColor = UIColor.black.withAlphaComponent(0.10).cgColor

        if let data = lens.stickerEyeJPEG, let image = UIImage(data: data) {
            let iv = UIImageView(image: image)
            iv.contentMode = .scaleAspectFit
            iv.clipsToBounds = true
            iv.layer.cornerRadius = 14
            iv.translatesAutoresizingMaskIntoConstraints = false
            imageArea.addSubview(iv)
            NSLayoutConstraint.activate([
                iv.leadingAnchor.constraint(equalTo: imageArea.leadingAnchor, constant: 8),
                iv.trailingAnchor.constraint(equalTo: imageArea.trailingAnchor, constant: -8),
                iv.topAnchor.constraint(equalTo: imageArea.topAnchor, constant: 8),
                iv.bottomAnchor.constraint(equalTo: imageArea.bottomAnchor, constant: -8),
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
        title.numberOfLines = 1
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.78
        title.attributedText = makeTitleText(productName: lens.productNameDisplay, colorName: lens.colorName.trimmedOrNil)

        let pillRow = UIStackView(arrangedSubviews: [
            makePill(lens.colorCategoryRaw, color: pillColor(for: lens.colorCategoryRaw)),
            makePill(lens.repeatDecisionRaw, color: pillColor(for: lens.repeatDecisionRaw))
        ])
        pillRow.axis = .horizontal
        pillRow.spacing = 6
        pillRow.alignment = .fill
        pillRow.distribution = .fillEqually

        if let gd = lens.graphicDiameter {
            let diameterRow = UIStackView(arrangedSubviews: [
                makePill("着色直径 \(String(format: "%.1f", gd))mm", color: graphicDiameterPillColor(for: gd)),
                UIView()
            ])
            diameterRow.axis = .horizontal
            diameterRow.spacing = 8
            diameterRow.alignment = .fill
            diameterRow.distribution = .fill
            let v = UIStackView(arrangedSubviews: [imageArea, brand, title, diameterRow, pillRow])
            v.axis = .vertical
            v.spacing = 10
            v.translatesAutoresizingMaskIntoConstraints = false

            card.addSubview(v)
            NSLayoutConstraint.activate([
                v.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
                v.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
                v.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
                v.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
                imageArea.heightAnchor.constraint(equalToConstant: 126),
            ])

            stackView.addArrangedSubview(card)
            return
        }

        let v = UIStackView(arrangedSubviews: [imageArea, brand, title, pillRow])
        v.axis = .vertical
        v.spacing = 10
        v.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(v)
        NSLayoutConstraint.activate([
            v.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            v.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            v.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            v.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            imageArea.heightAnchor.constraint(equalToConstant: 126),
        ])

        stackView.addArrangedSubview(card)
    }

    private func makePill(_ text: String, color: UIColor) -> UIView {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .caption2)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.82

        let container = UIView()
        container.backgroundColor = color.withAlphaComponent(0.24)
        container.layer.cornerRadius = 15
        container.layer.borderWidth = 1
        container.layer.borderColor = color.withAlphaComponent(0.45).cgColor
        container.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 30),
        ])
        return container
    }

    private func makeTitleText(productName: String, colorName: String?) -> NSAttributedString {
        let title = NSMutableAttributedString(
            string: productName,
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .headline),
                .foregroundColor: UIColor.label
            ]
        )
        if let colorName, colorName.isEmpty == false {
            title.append(
                NSAttributedString(
                    string: " \(colorName)",
                    attributes: [
                        .font: UIFont.preferredFont(forTextStyle: .caption1),
                        .foregroundColor: UIColor.secondaryLabel
                    ]
                )
            )
        }
        return title
    }

    private func backgroundAccentColor(for lens: ShareLens) -> UIColor {
        let palette: [UIColor] = [
            UIColor(red: 0.97, green: 0.74, blue: 0.82, alpha: 1),
            UIColor(red: 0.99, green: 0.83, blue: 0.67, alpha: 1),
            UIColor(red: 0.76, green: 0.90, blue: 0.86, alpha: 1),
            UIColor(red: 0.76, green: 0.86, blue: 0.99, alpha: 1),
            UIColor(red: 0.84, green: 0.78, blue: 0.97, alpha: 1),
            UIColor(red: 0.98, green: 0.84, blue: 0.86, alpha: 1),
        ]
        return palette[abs(lens.id.uuidString.hashValue) % palette.count]
    }

    private func graphicDiameterPillColor(for value: Double) -> UIColor {
        switch value {
        case ..<13.0:
            return UIColor(red: 0.84, green: 0.78, blue: 0.97, alpha: 1)
        case 13.0..<13.5:
            return UIColor(red: 0.98, green: 0.79, blue: 0.87, alpha: 1)
        default:
            return UIColor(red: 0.99, green: 0.83, blue: 0.67, alpha: 1)
        }
    }

    private func pillColor(for rawValue: String) -> UIColor {
        switch rawValue {
        case "ブラック系":
            return UIColor(red: 0.74, green: 0.76, blue: 0.80, alpha: 1)
        case "ブラウン系":
            return UIColor(red: 0.82, green: 0.69, blue: 0.56, alpha: 1)
        case "グレー系":
            return UIColor(red: 0.70, green: 0.85, blue: 0.96, alpha: 1)
        case "オリーブ系":
            return UIColor(red: 0.77, green: 0.88, blue: 0.50, alpha: 1)
        case "その他":
            return UIColor(red: 0.88, green: 0.72, blue: 0.90, alpha: 1)
        case "リピあり":
            return UIColor(red: 0.98, green: 0.72, blue: 0.84, alpha: 1)
        case "リピなし":
            return UIColor(red: 0.69, green: 0.88, blue: 0.98, alpha: 1)
        case "迷う":
            return UIColor(red: 0.98, green: 0.90, blue: 0.56, alpha: 1)
        default:
            return backgroundAccentColor(for: ShareLens.placeholder)
        }
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

    var productNameDisplay: String {
        productName.trimmedOrNil ?? "（品名未設定）"
    }

    static let placeholder = ShareLens(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID(),
        brand: "",
        productName: "",
        colorName: "",
        colorCategoryRaw: "",
        repeatDecisionRaw: "",
        graphicDiameter: nil,
        stickerEyeJPEG: nil
    )
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
