import SwiftUI

/// Drop-in replacement for `AsyncImage` backed by `ImageCache` — same
/// `url:content:placeholder:` shape, but persists across scrolling and relaunches.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let uiImage {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            uiImage = nil
            guard let url else { return }
            uiImage = try? await ImageCache.shared.image(for: url)
        }
    }
}
