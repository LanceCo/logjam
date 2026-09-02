import SwiftUI

/// Subtle scale + opacity press feedback for tappable cover art in free-floating
/// grids (Library grid, Home posters, Stats poster grid) — these don't get the
/// native press highlight that `List` rows get for free, so without this they
/// have no visual response to a tap at all.
struct LJPressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == LJPressableStyle {
    static var ljPressable: LJPressableStyle { LJPressableStyle() }
}
