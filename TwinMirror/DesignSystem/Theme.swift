import SwiftUI

enum Theme {
    enum Colors {
        static let primary = Color(red: 1.0, green: 0.667, blue: 0.882)
        static let primaryDeep = Color(red: 0.95, green: 0.45, blue: 0.75)
        static let accent = Color(red: 0.45, green: 0.75, blue: 1.0)
        static let cream = Color(red: 1.0, green: 0.97, blue: 0.93)
        static let textPrimary = Color(red: 0.15, green: 0.10, blue: 0.20)
        static let textSecondary = Color(red: 0.45, green: 0.40, blue: 0.50)
    }

    enum Gradients {
        static let background = LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.94, blue: 0.96),
                Color(red: 0.96, green: 0.92, blue: 1.0),
                Color(red: 0.92, green: 0.96, blue: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let ctaButton = LinearGradient(
            colors: [Colors.primary, Colors.primaryDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 40
    }

    enum Radius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 20
        static let large: CGFloat = 28
    }
}
