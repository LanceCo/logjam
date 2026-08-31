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

/// Lets Home's stat tiles deep-link into Library with a filter and grid view pre-applied.
@MainActor
final class LibraryFilterRequest: ObservableObject {
    @Published var pendingStatusFilter: StatusFilter?
}
