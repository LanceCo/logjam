import Foundation
import SwiftData

/// Pure computation over the collection + listening history — no persistence, no side effects.
/// Recomputed fresh each time `StatsView` re-renders off its `@Query` results.
struct StatsAggregator {
    private let activeReleases: [Release]
    /// Full listening history, ascending by date, never filtered by the selected year —
    /// milestones ("10th listen ever") and the genre breakdown (a collection stat, not a
    /// listening-year stat) need the complete picture regardless of `year`.
    private let allLogEntries: [ListenLogEntry]
    /// Listening history scoped to `year` (or all-time when nil), ascending by date.
    private let logEntries: [ListenLogEntry]

    init(releases: [Release], logEntries: [ListenLogEntry], year: Int? = nil) {
        self.activeReleases = releases.filter { !$0.isRemovedFromDiscogs }
        self.allLogEntries = logEntries
        if let year {
            let calendar = Calendar.current
            self.logEntries = logEntries.filter { calendar.component(.year, from: $0.date) == year }
        } else {
            self.logEntries = logEntries
        }
    }

    /// Years with at least one listen logged, newest first, for the listening-stats year picker.
    var availableYears: [Int] {
        let calendar = Calendar.current
        let years = Set(allLogEntries.map { calendar.component(.year, from: $0.date) })
        return years.sorted(by: >)
    }

    var collectionSize: Int { activeReleases.count }

    var totalAlbumsLogged: Int {
        Set(logEntries.compactMap { $0.release?.persistentModelID }).count
    }

    var totalPlays: Int { logEntries.count }

    var lovedCount: Int {
        Set(logEntries.filter(\.loved).compactMap { $0.release?.persistentModelID }).count
    }

    /// nil when no logged release has any parseable track duration data — Discogs doesn't
    /// always list durations, so this is a lower-bound estimate, not an exact total.
    var totalHoursListened: Double? {
        let seconds = logEntries.compactMap { $0.release.flatMap(Self.totalDurationSeconds(for:)) }
        guard !seconds.isEmpty else { return nil }
        return seconds.reduce(0, +) / 3600
    }

    var activityByMonth: [(month: Date, count: Int)] {
        Self.bucketByMonth(logEntries.map(\.date))
    }

    /// Running total of collection size over time, rather than additions-per-month: a
    /// single bulk import (e.g. cataloging an existing physical collection all at once)
    /// would otherwise produce one bar that dwarfs every other month. As a cumulative
    /// total, that same import just reads as one steep step in an otherwise-legible curve.
    var collectionGrowth: [(month: Date, total: Int)]? {
        let dates = activeReleases.compactMap(\.dateAdded)
        guard !dates.isEmpty else { return nil }
        var runningTotal = 0
        return Self.bucketByMonth(dates).map { entry in
            runningTotal += entry.count
            return (month: entry.month, total: runningTotal)
        }
    }

    /// Genre breakdown is a collection stat — across every active release, not just the
    /// ones you've logged, and not scoped to the selected listening year.
    var genreCounts: [(genre: String, count: Int)] {
        let grouped = Dictionary(grouping: activeReleases.flatMap(\.genres)) { $0 }
        return grouped.map { (genre: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    /// Distinct logged releases within the selected year, most-recently-logged first.
    var loggedReleases: [Release] {
        Self.distinctReleases(from: Array(logEntries.reversed()))
    }

    var ratedEntries: [ListenLogEntry] {
        logEntries.filter { $0.starRating > 0 }
    }

    var ratingHistogram: [Double: Int] {
        Dictionary(grouping: ratedEntries, by: \.stars).mapValues(\.count)
    }

    var averageRating: Double? {
        let rated = ratedEntries
        guard !rated.isEmpty else { return nil }
        return rated.reduce(0) { $0 + $1.stars } / Double(rated.count)
    }

    var highestRated: ListenLogEntry? {
        ratedEntries.max { $0.starRating < $1.starRating }
    }

    var lowestRated: ListenLogEntry? {
        ratedEntries.min { $0.starRating < $1.starRating }
    }

    var topArtists: [(artist: String, count: Int)] {
        let loggedReleases = Self.distinctReleases(from: logEntries)
        let grouped = Dictionary(grouping: loggedReleases, by: \.artistName)
        return grouped.map { (artist: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(10)
            .map { $0 }
    }

    // Milestones are all-time ("your 10th listen ever"), so they ignore the selected year.
    var firstLogged: ListenLogEntry? { allLogEntries.first }
    var mostRecentLogged: ListenLogEntry? { allLogEntries.last }

    /// Round-number crossings (10th, 25th, 50th, 100th, 250th, 500th, 1000th listen) already reached.
    var milestoneEntries: [(index: Int, entry: ListenLogEntry)] {
        let thresholds = [10, 25, 50, 100, 250, 500, 1000]
        return thresholds
            .filter { $0 <= allLogEntries.count }
            .map { (index: $0, entry: allLogEntries[$0 - 1]) }
    }

    /// Producers credited on distinct logged releases within the selected year, ranked by
    /// how many logged albums they appear on. Matches any Discogs role containing
    /// "Producer" (e.g. "Producer", "Co-producer", "Executive Producer").
    var producerCounts: [(name: String, count: Int)] {
        personnelCounts(matchingRoleSubstring: "producer")
    }

    /// Same as `producerCounts`, for roles containing "Engineer".
    var engineerCounts: [(name: String, count: Int)] {
        personnelCounts(matchingRoleSubstring: "engineer")
    }

    /// Songwriters credited (role containing "Written", e.g. Discogs' "Written-By").
    var writerCounts: [(name: String, count: Int)] {
        personnelCounts(matchingRoleSubstring: "written")
    }

    /// Record labels on distinct logged releases within the selected year, ranked by album count.
    var labelCounts: [(name: String, count: Int)] {
        let names = Self.distinctReleases(from: logEntries).flatMap { $0.cachedLabels ?? [] }
        return Self.rankedCounts(of: names)
    }

    /// Raw (un-stripped) credit names, so a same-named-but-distinct Discogs credit doesn't
    /// get merged with another — matches how `topArtists` already keys off raw `artistName`.
    /// Callers strip the Discogs disambiguator suffix for display only.
    private func personnelCounts(matchingRoleSubstring substring: String) -> [(name: String, count: Int)] {
        let names = Self.distinctReleases(from: logEntries).flatMap { release in
            (release.cachedCredits ?? [])
                .filter { $0.role.localizedCaseInsensitiveContains(substring) }
                .map { $0.name }
        }
        return Self.rankedCounts(of: names)
    }

    private static func rankedCounts(of names: [String]) -> [(name: String, count: Int)] {
        let grouped = Dictionary(grouping: names) { $0 }
        return grouped.map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(5)
            .map { $0 }
    }

    var listenedVsUnlistened: (listened: Int, unlistened: Int) {
        let listened = activeReleases.filter(\.isListened).count
        return (listened, activeReleases.count - listened)
    }

    var keepVsSell: (keep: Int, sell: Int) {
        let sell = activeReleases.filter { $0.keepSellStatus == .sell }.count
        return (activeReleases.count - sell, sell)
    }

    var distinctGenreCount: Int {
        Set(activeReleases.flatMap(\.genres)).count
    }

    /// Vinyl format breakdown across the active collection (LP, 7", 10", etc.), most common first.
    var formatCounts: [(format: String, count: Int)] {
        Self.rankedCounts(of: activeReleases.compactMap(\.vinylType))
            .map { (format: $0.name, count: $0.count) }
    }

    private static func distinctReleases(from entries: [ListenLogEntry]) -> [Release] {
        var seen = Set<PersistentIdentifier>()
        var result: [Release] = []
        for entry in entries {
            guard let release = entry.release, seen.insert(release.persistentModelID).inserted else { continue }
            result.append(release)
        }
        return result
    }

    private static func totalDurationSeconds(for release: Release) -> TimeInterval? {
        guard let tracklist = release.cachedTracklist, !tracklist.isEmpty else { return nil }
        let seconds = tracklist.compactMap { parseDuration($0.duration) }
        guard !seconds.isEmpty else { return nil }
        return seconds.reduce(0, +)
    }

    /// Parses Discogs' "M:SS" (or occasionally "H:MM:SS") track duration strings.
    private static func parseDuration(_ duration: String?) -> TimeInterval? {
        guard let duration, !duration.isEmpty else { return nil }
        let parts = duration.split(separator: ":").compactMap { Int($0) }
        guard !parts.isEmpty, parts.count == duration.split(separator: ":").count else { return nil }
        let seconds = parts.reduce(0) { $0 * 60 + $1 }
        return TimeInterval(seconds)
    }

    private static func bucketByMonth(_ dates: [Date]) -> [(month: Date, count: Int)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: dates) { date in
            calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        }
        return grouped.map { (month: $0.key, count: $0.value.count) }
            .sorted { $0.month < $1.month }
    }
}
