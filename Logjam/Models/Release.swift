import Foundation
import SwiftData

@Model
final class Release {
    var discogsReleaseID: Int = 0
    var discogsInstanceID: Int = 0
    var title: String = ""
    var artistName: String = ""
    var artistSortName: String = ""
    var year: Int?
    var coverImageURL: URL?
    var genres: [String] = []
    var styles: [String] = []
    var formatDescriptions: [String] = []
    var isRemovedFromDiscogs: Bool = false
    var keepSellStatus: KeepSellStatus = KeepSellStatus.keep
    var lastSyncedAt: Date = Date.now
    var dateAdded: Date?

    @Relationship(deleteRule: .cascade, inverse: \ListenLogEntry.release)
    var logEntries: [ListenLogEntry]? = []

    // Cached Discogs release detail — tracklist/credits don't change, so this is fetched once.
    var cachedTracklist: [DiscogsTrack]?
    var cachedCredits: [DiscogsCredit]?
    var detailFetchedAt: Date?

    // Cached Discogs marketplace stats — prices move, so SellQueueView refreshes this on a TTL.
    var cachedLowestPriceValue: Double?
    var cachedLowestPriceCurrency: String?
    var cachedNumForSale: Int?
    var statsFetchedAt: Date?

    init(
        discogsReleaseID: Int,
        discogsInstanceID: Int,
        title: String,
        artistName: String,
        artistSortName: String,
        year: Int? = nil,
        coverImageURL: URL? = nil,
        genres: [String] = [],
        styles: [String] = [],
        formatDescriptions: [String] = [],
        keepSellStatus: KeepSellStatus = .keep,
        lastSyncedAt: Date = .now,
        dateAdded: Date? = nil
    ) {
        self.discogsReleaseID = discogsReleaseID
        self.discogsInstanceID = discogsInstanceID
        self.title = title
        self.artistName = artistName
        self.artistSortName = artistSortName
        self.year = year
        self.coverImageURL = coverImageURL
        self.genres = genres
        self.styles = styles
        self.formatDescriptions = formatDescriptions
        self.isRemovedFromDiscogs = false
        self.keepSellStatus = keepSellStatus
        self.lastSyncedAt = lastSyncedAt
        self.dateAdded = dateAdded
    }

    var isListened: Bool { !(logEntries ?? []).isEmpty }
    var isLoved: Bool { (logEntries ?? []).contains { $0.loved } }

    private static let vinylTypeTokens: Set<String> = ["LP", "12\"", "10\"", "7\"", "EP"]

    var vinylType: String? {
        formatDescriptions.first { Self.vinylTypeTokens.contains($0) }
    }
}

enum KeepSellStatus: String, Codable {
    case keep
    case sell
}

enum PickFormat: String, CaseIterable, Identifiable {
    case sevenInch = "7\""
    case tenInch = "10\""
    case twelveInchOrLP = "12\"/LP"

    var id: String { rawValue }

    func matches(_ formatDescriptions: [String]) -> Bool {
        switch self {
        case .sevenInch:
            return formatDescriptions.contains("7\"")
        case .tenInch:
            return formatDescriptions.contains("10\"")
        case .twelveInchOrLP:
            return formatDescriptions.contains("12\"") || formatDescriptions.contains("LP")
        }
    }
}
