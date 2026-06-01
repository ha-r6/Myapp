import UIKit
import UniformTypeIdentifiers
import ImageIO

final class ShareViewController: UIViewController {
    private static let appGroupId = "group.app.yamazaki.ha-san.Myapp"

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let stackView = UIStackView()
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
        stackView.spacing = 10
        stackView.alignment = .fill

        closeButton.setTitle("閉じる", for: .normal)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        let root = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, stackView, closeButton])
        root.axis = .vertical
        root.spacing = 14
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            root.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
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
        let names = dayLogs.compactMap { log -> String? in
            guard let id = log.lensId, let lens = lensMap[id] else { return nil }
            return lens.displayName
        }
        let uniqueNames = Array(NSOrderedSet(array: names)) as? [String] ?? []

        if uniqueNames.isEmpty {
            addEmptyCard("この日に記録されたカラコンはありません。")
        } else {
            uniqueNames.forEach { addLensCard(title: "この日のカラコンは \($0) です") }
        }
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

    private func addLensCard(title: String) {
        let card = UIView()
        card.backgroundColor = UIColor.secondarySystemBackground
        card.layer.cornerRadius = 12

        let label = UILabel()
        label.text = title
        label.numberOfLines = 2
        label.font = .preferredFont(forTextStyle: .headline)
        label.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
        ])

        stackView.addArrangedSubview(card)
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
