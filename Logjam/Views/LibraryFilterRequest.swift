import Foundation

enum AppTab: Hashable {
    case home
    case library
    case diary
    case sellQueue
    case stats
}

enum StatusFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case listened = "Listened"
    case notListened = "Not Listened"
    case loved = "Loved"
    var id: String { rawValue }
}

/// Shared cross-tab navigation state: which tab is active, plus one-shot requests other
/// tabs can leave for Library to pick up (a filter from Home's stat tiles, an artist search
/// from an album's detail page) the next time Library becomes active.
@MainActor
final class LibraryFilterRequest: ObservableObject {
    @Published var selectedTab: AppTab = .home
    @Published var pendingStatusFilter: StatusFilter?
    @Published var pendingArtistSearch: String?

    /// The tab we were on before an artist-name tap sent us to Library. Drives the "Back"
    /// affordance that undoes the jump if it was a misclick.
    @Published var artistSearchOriginTab: AppTab?
}
