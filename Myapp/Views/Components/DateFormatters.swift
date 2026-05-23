import Foundation

enum AppDateFormatters {
    static let day: DateFormatter = {
        let df = DateFormatter()
        df.locale = .current
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()
}

