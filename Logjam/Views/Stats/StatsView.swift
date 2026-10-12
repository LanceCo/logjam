import SwiftUI
import SwiftData

struct StatsView: View {
    @Query private var releases: [Release]
    @Query(sort: [SortDescriptor(\ListenLogEntry.date)])
    private var logEntries: [ListenLogEntry]

    @State private var section: StatsSection = .listening
    @State private var selectedYear: Int?

    private enum StatsSection: String, CaseIterable, Identifiable {
        case listening = "Listening"
        case collection = "Collection"
        var id: String { rawValue }
    }

    private var stats: StatsAggregator {
        StatsAggregator(releases: releases, logEntries: logEntries, year: selectedYear)
    }

    var body: some View {
        NavigationStack {
            Group {
                if logEntries.isEmpty {
                    LJEmptyStateView(
                        icon: "chart.bar",
                        title: "No Stats Yet",
                        description: "Log a listen from an album page to start building your stats."
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: LJTheme.Spacing.xxl) {
                            switch section {
                            case .listening:
                                listeningStats
                            case .collection:
                                collectionStats
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(LJTheme.background)
            .navigationTitle(section == .listening ? "Listening Stats" : "Collection Stats")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    sectionToggle
                }
            }
            .navigationDestination(for: Release.self) { release in
                AlbumDetailView(release: release)
            }
            .navigationDestination(for: CreditedAlbumsFilter.self) { filter in
                CreditedAlbumsView(filter: filter, allReleases: releases)
            }
        }
    }

    // MARK: - Top-level layout

    /// Mirrors Library's grid/list toggle: one icon button, showing the icon for where
    /// tapping it takes you next, rather than a segmented control eating up width that the
    /// year picker can use instead.
    private var sectionToggle: some View {
        Button {
            section = (section == .listening) ? .collection : .listening
        } label: {
            Image(systemName: section == .listening ? "square.stack" : "waveform")
        }
        .foregroundStyle(LJTheme.accent)
    }

    @ViewBuilder
    private var listeningStats: some View {
        yearPicker

        summaryTiles
        milestonesSection

        sectionDivider
        activitySection

        if stats.averageRating != nil {
            sectionDivider
            ratingsSection
        }

        if !stats.topArtists.isEmpty {
            sectionDivider
            topArtistsSection
        }

        if hasPersonnelData {
            sectionDivider
            personnelSection
        }

        if !stats.loggedReleases.isEmpty {
            sectionDivider
            loggedPosterGrid
        }
    }

    @ViewBuilder
    private var collectionStats: some View {
        collectionSummaryTiles

        if let collectionGrowth = stats.collectionGrowth {
            sectionDivider
            growthSection(collectionGrowth)
        }

        if !stats.genreCounts.isEmpty {
            sectionDivider
            genresSection
        }

        if !stats.formatCounts.isEmpty {
            sectionDivider
            formatsSection
        }

        sectionDivider
        collectionSection
    }

    private var hasPersonnelData: Bool {
        !stats.producerCounts.isEmpty || !stats.engineerCounts.isEmpty
            || !stats.writerCounts.isEmpty || !stats.labelCounts.isEmpty
    }

    // MARK: - Listening stats sections

    private var yearPicker: some View {
        Menu {
            Button("All Time") { selectedYear = nil }
            ForEach(stats.availableYears, id: \.self) { year in
                Button("\(String(year))") { selectedYear = year }
            }
        } label: {
            HStack(spacing: LJTheme.Spacing.sm) {
                Text(selectedYear.map(String.init) ?? "All Time")
                    .font(.system(size: 28, weight: .bold, design: .default).width(.expanded))
                Image(systemName: "chevron.down")
                    .font(.body)
            }
            .foregroundStyle(LJTheme.accent)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var summaryTiles: some View {
        HStack(spacing: 0) {
            statTile(value: stats.totalAlbumsLogged, label: "Logged")
            statTile(value: stats.totalPlays, label: "Plays")
            statTile(value: stats.lovedCount, label: "Loved")
            if let hours = stats.totalHoursListened {
                statTile(text: String(format: "%.1f", hours), label: "Hours")
            }
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: LJTheme.Spacing.sm) {
            Text("Listening Activity").font(.displayHeadline())
            MonthlyBarChart(data: stats.activityByMonth)
        }
    }

    private var ratingsSection: some View {
        VStack(alignment: .leading, spacing: LJTheme.Spacing.md) {
            Text("Ratings").font(.displayHeadline())

            if let average = stats.averageRating {
                Text(String(format: "Average rating: %.1f★", average))
                    .font(.subheadline)
                    .foregroundStyle(LJTheme.textSecondary)
            }

            RatingHistogramChart(histogram: stats.ratingHistogram)

            if let highest = stats.highestRated {
                albumHighlightRow(entry: highest, caption: "Highest Rated")
            }
            if let lowest = stats.lowestRated, lowest.release?.persistentModelID != stats.highestRated?.release?.persistentModelID {
                albumHighlightRow(entry: lowest, caption: "Lowest Rated")
            }
        }
    }

    private var topArtistsSection: some View {
        rankedList(
            title: "Top Artists",
            entries: stats.topArtists.map { (display: Release.stripArtistDisambiguator(from: $0.artist), key: $0.artist, count: $0.count) }
        ) { rawArtistName in
            CreditedAlbumsFilter(title: Release.stripArtistDisambiguator(from: rawArtistName), kind: .artist(rawArtistName))
        }
    }

    private var personnelSection: some View {
        VStack(alignment: .leading, spacing: LJTheme.Spacing.lg) {
            Text("Personnel").font(.displayHeadline())
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .top), GridItem(.flexible(), alignment: .top)], alignment: .leading, spacing: LJTheme.Spacing.lg) {
                if !stats.producerCounts.isEmpty {
                    personnelList(title: "Producers", entries: stats.producerCounts, roleSubstring: "producer")
                }
                if !stats.engineerCounts.isEmpty {
                    personnelList(title: "Engineers", entries: stats.engineerCounts, roleSubstring: "engineer")
                }
                if !stats.writerCounts.isEmpty {
                    personnelList(title: "Writers", entries: stats.writerCounts, roleSubstring: "written")
                }
                if !stats.labelCounts.isEmpty {
                    rankedList(
                        title: "Labels",
                        entries: stats.labelCounts.map { (display: $0.name, key: $0.name, count: $0.count) },
                        titleStyle: .subsection
                    ) { label in
                        CreditedAlbumsFilter(title: label, kind: .label(label))
                    }
                }
            }
        }
    }

    private func personnelList(title: String, entries: [(name: String, count: Int)], roleSubstring: String) -> some View {
        rankedList(
            title: title,
            entries: entries.map { (display: Release.stripArtistDisambiguator(from: $0.name), key: $0.name, count: $0.count) },
            titleStyle: .subsection
        ) { rawName in
            CreditedAlbumsFilter(
                title: Release.stripArtistDisambiguator(from: rawName),
                kind: .credit(name: rawName, roleSubstring: roleSubstring)
            )
        }
    }

    private var loggedPosterGrid: some View {
        VStack(alignment: .leading, spacing: LJTheme.Spacing.sm) {
            Text("Logged Albums").font(.displayHeadline())
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: LJTheme.Spacing.sm)], spacing: LJTheme.Spacing.sm) {
                ForEach(stats.loggedReleases) { release in
                    NavigationLink(value: release) {
                        CachedAsyncImage(url: release.coverImageURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            LJTheme.surface
                        }
                        .aspectRatio(1, contentMode: .fill)
                        .coverArtStyle()
                    }
                    .buttonStyle(.ljPressable)
                }
            }
        }
    }

    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: LJTheme.Spacing.sm) {
            Text("Milestones").font(.displayHeadline())

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: LJTheme.Spacing.md)], spacing: LJTheme.Spacing.lg) {
                if let first = stats.firstLogged {
                    milestoneCard(entry: first, caption: "First Logged")
                }
                ForEach(stats.milestoneEntries, id: \.index) { milestone in
                    milestoneCard(entry: milestone.entry, caption: "\(milestone.index)th Listen")
                }
                if let recent = stats.mostRecentLogged, recent.persistentModelID != stats.firstLogged?.persistentModelID {
                    milestoneCard(entry: recent, caption: "Most Recent")
                }
            }
        }
    }

    @ViewBuilder
    private func milestoneCard(entry: ListenLogEntry, caption: String) -> some View {
        if let release = entry.release {
            NavigationLink(value: release) {
                VStack(alignment: .leading, spacing: LJTheme.Spacing.xxs) {
                    Text(caption)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(LJTheme.accent)
                    CachedAsyncImage(url: release.coverImageURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        LJTheme.surface
                    }
                    .aspectRatio(1, contentMode: .fill)
                    .coverArtStyle()
                    Text(release.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(LJTheme.textPrimary)
                        .lineLimit(1)
                    Text(release.displayArtistName)
                        .font(.caption2)
                        .foregroundStyle(LJTheme.textSecondary)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.ljPressable)
        }
    }

    // MARK: - Collection stats sections

    private var collectionSummaryTiles: some View {
        HStack(spacing: 0) {
            statTile(value: stats.collectionSize, label: "Albums")
            statTile(value: stats.distinctGenreCount, label: "Genres")
        }
    }

    private func growthSection(_ data: [(month: Date, total: Int)]) -> some View {
        VStack(alignment: .leading, spacing: LJTheme.Spacing.sm) {
            Text("Collection Growth").font(.displayHeadline())
            CollectionGrowthChart(data: data)
        }
    }

    private var genresSection: some View {
        VStack(alignment: .leading, spacing: LJTheme.Spacing.sm) {
            Text("Genres").font(.displayHeadline())
            GenreBarChart(data: stats.genreCounts)
        }
    }

    private var formatsSection: some View {
        VStack(alignment: .leading, spacing: LJTheme.Spacing.sm) {
            Text("Formats").font(.displayHeadline())
            FormatPieChart(data: stats.formatCounts)
        }
    }

    private var collectionSection: some View {
        VStack(alignment: .leading, spacing: LJTheme.Spacing.lg) {
            Text("Collection Breakdown").font(.displayHeadline())
            SplitProportionBar(
                leftLabel: "Listened",
                leftCount: stats.listenedVsUnlistened.listened,
                rightLabel: "Unlistened",
                rightCount: stats.listenedVsUnlistened.unlistened
            )
            SplitProportionBar(
                leftLabel: "Keep",
                leftCount: stats.keepVsSell.keep,
                rightLabel: "Sell",
                rightCount: stats.keepVsSell.sell
            )
        }
    }

    // MARK: - Shared bits

    private func statTile(value: Int, label: String) -> some View {
        statTile(text: "\(value)", label: label)
    }

    private func statTile(text: String, label: String) -> some View {
        VStack(spacing: LJTheme.Spacing.xxs) {
            Text(text).font(.displayTitle(22))
            Text(label).font(.caption).foregroundStyle(LJTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(LJTheme.accent)
            .frame(height: 1)
    }

    private enum RankedListTitleStyle {
        case section
        case subsection
    }

    /// `entries.key` is the raw (un-stripped) value used to build a drill-down filter;
    /// `entries.display` is what's actually shown. When `filter` is nil, rows are inert text.
    private func rankedList(
        title: String,
        entries: [(display: String, key: String, count: Int)],
        titleStyle: RankedListTitleStyle = .section,
        filter: ((String) -> CreditedAlbumsFilter)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: LJTheme.Spacing.sm) {
            Group {
                switch titleStyle {
                case .section:
                    Text(title).font(.displayHeadline())
                case .subsection:
                    Text(title).font(.subheadline).fontWeight(.semibold).foregroundStyle(LJTheme.textSecondary)
                }
            }
            VStack(spacing: 6) {
                ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                    rankedRow(entry: entry, filter: filter)
                }
            }
        }
    }

    @ViewBuilder
    private func rankedRow(
        entry: (display: String, key: String, count: Int),
        filter: ((String) -> CreditedAlbumsFilter)?
    ) -> some View {
        let row = HStack {
            Text(entry.display)
                .foregroundStyle(filter != nil ? LJTheme.accent : LJTheme.textPrimary)
                .lineLimit(1)
            Spacer(minLength: LJTheme.Spacing.xs)
            Text("\(entry.count)")
                .foregroundStyle(LJTheme.textSecondary)
        }
        .font(.subheadline)

        if let filter {
            NavigationLink(value: filter(entry.key)) { row }
                .buttonStyle(.plain)
        } else {
            row
        }
    }

    private func albumHighlightRow(entry: ListenLogEntry, caption: String) -> some View {
        Group {
            if let release = entry.release {
                NavigationLink(value: release) {
                    HStack(spacing: LJTheme.Spacing.md) {
                        CachedAsyncImage(url: release.coverImageURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            LJTheme.surface
                        }
                        .frame(width: 44, height: 44)
                        .coverArtStyle()

                        VStack(alignment: .leading, spacing: LJTheme.Spacing.xxs) {
                            Text(release.title).font(.subheadline).bold().foregroundStyle(LJTheme.textPrimary)
                            Text(release.displayArtistName).font(.caption).foregroundStyle(LJTheme.textSecondary)
                        }

                        Spacer()

                        Text(caption)
                            .font(.caption2)
                            .foregroundStyle(LJTheme.accent)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Identifies which albums to show on the drill-down pushed from a Stats ranked-list row.
struct CreditedAlbumsFilter: Hashable {
    let title: String
    let kind: Kind

    enum Kind: Hashable {
        /// Exact match against `Release.artistName` (the raw, un-stripped value) — covers
        /// the whole synced collection, since artist name doesn't require a per-album fetch.
        case artist(String)
        /// Match against cached `extraartists` credits whose role contains `roleSubstring`.
        /// Only covers releases whose detail page has been opened at least once.
        case credit(name: String, roleSubstring: String)
        /// Match against cached label names. Same per-album-fetch caveat as `.credit`.
        case label(String)
    }
}

/// Albums tied to a person, label, or artist — pushed from a Stats ranked-list row.
/// Searches the whole collection, not just logged albums, per `kind`'s own scope.
private struct CreditedAlbumsView: View {
    let filter: CreditedAlbumsFilter
    let allReleases: [Release]

    private var matches: [Release] {
        allReleases
            .filter { release in
                guard !release.isRemovedFromDiscogs else { return false }
                switch filter.kind {
                case .artist(let name):
                    return release.artistName == name
                case .credit(let name, let roleSubstring):
                    return (release.cachedCredits ?? []).contains {
                        $0.name == name && $0.role.localizedCaseInsensitiveContains(roleSubstring)
                    }
                case .label(let name):
                    return (release.cachedLabels ?? []).contains(name)
                }
            }
            .sorted { $0.artistSortName.localizedCaseInsensitiveCompare($1.artistSortName) == .orderedAscending }
    }

    var body: some View {
        List(matches) { release in
            NavigationLink(value: release) {
                HStack {
                    CachedAsyncImage(url: release.coverImageURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        LJTheme.surface
                    }
                    .frame(width: 50, height: 50)
                    .coverArtStyle()

                    VStack(alignment: .leading) {
                        Text(release.title).font(.headline).foregroundStyle(LJTheme.textPrimary)
                        Text(release.displayArtistName).font(.subheadline).foregroundStyle(LJTheme.textSecondary)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(LJTheme.background)
        .navigationTitle(filter.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
