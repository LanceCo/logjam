import Foundation
import SwiftData

@MainActor
final class SyncService: ObservableObject {
    @Published var isSyncing = false
    @Published var lastError: String?

    private let client: DiscogsClient

    init(client: DiscogsClient = DiscogsClient()) {
        self.client = client
    }

    func sync(context: ModelContext) async {
        guard let username = try? KeychainStore.shared.readDiscogsUsername(), !username.isEmpty else {
            lastError = "Set your Discogs username in Settings first."
            return
        }
        isSyncing = true
        defer { isSyncing = false }

        do {
            var page = 1
            var seenReleaseIDs = Set<Int>()
            while true {
                let response = try await client.fetchCollectionPage(username: username, page: page)
                for item in response.releases {
                    guard Self.isVinyl(item.basicInformation.formats) else { continue }
                    seenReleaseIDs.insert(item.id)
                    upsert(item: item, context: context)
                }
                if page >= response.pagination.pages { break }
                page += 1
            }
            markRemovedReleases(excluding: seenReleaseIDs, context: context)
            try context.save()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private static func isVinyl(_ formats: [DiscogsFormat]) -> Bool {
        formats.contains { $0.name.caseInsensitiveCompare("Vinyl") == .orderedSame }
    }

    private static let dateAddedFormatter = ISO8601DateFormatter()

    private func upsert(item: DiscogsCollectionItem, context: ModelContext) {
        let releaseID = item.id
        let descriptor = FetchDescriptor<Release>(predicate: #Predicate { $0.discogsReleaseID == releaseID })
        let existing = try? context.fetch(descriptor).first

        let info = item.basicInformation
        let artistName = info.artists.first?.name ?? "Unknown Artist"
        let formatDescriptions = info.formats.flatMap { $0.descriptions ?? [] }
        let dateAdded = item.dateAdded.flatMap { Self.dateAddedFormatter.date(from: $0) }

        if let release = existing {
            release.title = info.title
            release.artistName = artistName
            release.artistSortName = Self.sortName(for: artistName)
            release.year = info.year
            release.coverImageURL = info.coverImage
            release.genres = info.genres ?? []
            release.styles = info.styles ?? []
            release.formatDescriptions = formatDescriptions
            release.isRemovedFromDiscogs = false
            release.lastSyncedAt = .now
            release.dateAdded = dateAdded
        } else {
            let release = Release(
                discogsReleaseID: releaseID,
                discogsInstanceID: item.instanceId,
                title: info.title,
                artistName: artistName,
                artistSortName: Self.sortName(for: artistName),
                year: info.year,
                coverImageURL: info.coverImage,
                genres: info.genres ?? [],
                styles: info.styles ?? [],
                formatDescriptions: formatDescriptions,
                dateAdded: dateAdded
            )
            context.insert(release)
        }
    }

    private func markRemovedReleases(excluding seenIDs: Set<Int>, context: ModelContext) {
        let descriptor = FetchDescriptor<Release>()
        guard let all = try? context.fetch(descriptor) else { return }
        for release in all where !seenIDs.contains(release.discogsReleaseID) {
            release.isRemovedFromDiscogs = true
        }
    }

    private static func sortName(for artistName: String) -> String {
        let prefixes = ["The ", "A ", "An "]
        for prefix in prefixes where artistName.hasPrefix(prefix) {
            let remainder = artistName.dropFirst(prefix.count)
            return "\(remainder), \(prefix.trimmingCharacters(in: .whitespaces))"
        }
        return artistName
    }
}
