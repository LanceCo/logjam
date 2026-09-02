import SwiftUI

/// A row of 5 stars supporting half-star precision (0.0...5.0, steps of 0.5).
/// When `isInteractive`, dragging/tapping across the row sets `rating` based on
/// horizontal position — left half of a star for a half rating, right half for a full one.
struct StarRatingView: View {
    @Binding var rating: Double
    var isInteractive: Bool = true
    var iconSize: CGFloat = 22
    var spacing: CGFloat = LJTheme.Spacing.xs
    var color: Color = LJTheme.accent

    private var starWidth: CGFloat { iconSize + spacing }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1...5, id: \.self) { index in
                image(for: index)
                    .font(.system(size: iconSize))
                    .foregroundStyle(color)
            }
        }
        .contentShape(Rectangle())
        .gesture(isInteractive ? dragGesture : nil)
        .sensoryFeedback(.selection, trigger: rating) { _, _ in isInteractive }
    }

    private func image(for index: Int) -> Image {
        let threshold = Double(index)
        if rating >= threshold {
            return Image(systemName: "star.fill")
        } else if rating >= threshold - 0.5 {
            return Image(systemName: "star.leadinghalf.filled")
        } else {
            return Image(systemName: "star")
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in setRating(fromX: value.location.x) }
    }

    private func setRating(fromX x: CGFloat) {
        let raw = x / starWidth
        let stepped = (raw * 2).rounded() / 2
        rating = min(5, max(0, stepped))
    }
}
