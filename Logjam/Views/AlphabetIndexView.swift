import SwiftUI

struct AlphabetIndexView: View {
    let letters: [String]
    let onSelect: (String) -> Void

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ForEach(letters, id: \.self) { letter in
                    Text(letter)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(LJTheme.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard !letters.isEmpty else { return }
                        let rowHeight = geometry.size.height / CGFloat(letters.count)
                        let index = min(max(Int(value.location.y / rowHeight), 0), letters.count - 1)
                        onSelect(letters[index])
                    }
            )
        }
        .frame(width: 20)
    }
}
