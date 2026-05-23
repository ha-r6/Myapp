import SwiftUI

enum AppTheme {
    // 白基調 + ほんのりインスタっぽいアクセント
    static let accent = Color(red: 0.93, green: 0.27, blue: 0.56) // pink
    static let accent2 = Color(red: 0.62, green: 0.25, blue: 0.95) // purple
    static let accent3 = Color(red: 1.00, green: 0.60, blue: 0.20) // orange

    static let background = Color(red: 0.99, green: 0.99, blue: 1.00) // almost white
    static let surface = Color.white
    static let hairline = Color.black.opacity(0.08)

    static var subtleBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                background,
                Color(red: 0.98, green: 0.98, blue: 0.99),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accent2, accent, accent3],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func seededValue(seed: String, modulo: Int) -> Int {
        let hash = seed.utf8.reduce(0) { ($0 &* 31) &+ Int($1) }
        return abs(hash) % max(1, modulo)
    }

    static func pastelColor(seed: String) -> Color {
        let palette: [Color] = [
            Color(red: 0.97, green: 0.65, blue: 0.79), // pink
            Color(red: 0.80, green: 0.72, blue: 0.98), // lavender
            Color(red: 0.99, green: 0.80, blue: 0.61), // peach
            Color(red: 0.72, green: 0.90, blue: 0.86), // mint
            Color(red: 0.76, green: 0.86, blue: 0.99), // sky
            Color(red: 0.92, green: 0.88, blue: 0.99), // lilac
        ]
        return palette[seededValue(seed: seed, modulo: palette.count)]
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.hairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 6)
    }
}

extension View {
    func appCard() -> some View { modifier(CardModifier()) }
}
