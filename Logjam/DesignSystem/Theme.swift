import SwiftUI

/// Shared design tokens: colors, type, and cover-art treatment.
/// Logjam is dark-only by design — there is no light-mode variant of these colors.
enum LJTheme {
    static let background = Color(red: 0.043, green: 0.043, blue: 0.051)
    static let surface = Color(red: 0.102, green: 0.102, blue: 0.114)
    static let textPrimary = Color(red: 0.949, green: 0.941, blue: 0.925)
    static let textSecondary = Color(white: 0.62)
    static let accent = Color(red: 0.910, green: 0.639, blue: 0.239)
    static let loved = Color(red: 0.878, green: 0.231, blue: 0.231)

    static let coverCornerRadius: CGFloat = 0
    static let coverShadowRadius: CGFloat = 6
    static let coverShadowOpacity: Double = 0.45
    static let coverShadowYOffset: CGFloat = 4
}

extension LJTheme {
    /// 4pt-based spacing scale, matching the values already in circulation across the app.
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 32
    }

    /// Corner radius for non-cover-art chrome. Cover art has its own sharp-corner
    /// treatment (`coverCornerRadius`) — this is a separate, smaller family.
    enum Corner {
        static let sm: CGFloat = 8
    }
}

extension Font {
    /// Bold condensed display style for album titles and hero headers.
    static func displayTitle(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .bold, design: .default).width(.condensed)
    }

    /// Semibold condensed display style for section headers.
    static func displayHeadline(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .semibold, design: .default).width(.condensed)
    }
}

extension View {
    /// Sharp corners + drop shadow, applied everywhere cover art appears.
    func coverArtStyle() -> some View {
        self
            .clipShape(RoundedRectangle(cornerRadius: LJTheme.coverCornerRadius))
            .shadow(
                color: .black.opacity(LJTheme.coverShadowOpacity),
                radius: LJTheme.coverShadowRadius,
                x: 0,
                y: LJTheme.coverShadowYOffset
            )
    }
}
