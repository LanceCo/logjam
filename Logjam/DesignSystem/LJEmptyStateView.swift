import SwiftUI

/// Themed replacement for `ContentUnavailableView`, which offers no hooks to
/// override its icon color, title font, or text color.
struct LJEmptyStateView: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: LJTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(LJTheme.accent)
            Text(title)
                .font(.displayHeadline(20))
                .foregroundStyle(LJTheme.textPrimary)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(LJTheme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, LJTheme.Spacing.xxl)
        .frame(maxWidth: .infinity)
    }
}
