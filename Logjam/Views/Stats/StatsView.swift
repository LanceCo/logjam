import SwiftUI
import SwiftData

struct StatsView: View {
    @Query private var releases: [Release]
    @Query(sort: [SortDescriptor(\ListenLogEntry.date)])
    private var logEntries: [ListenLogEntry]

    private var stats: StatsAggregator {
        StatsAggregator(releases: releases, logEntries: logEntries)
    }

    var body: some View {
        NavigationStack {
            Group {
                if logEntries.isEmpty {
                    ContentUnavailableView(
                        "No Stats Yet",
                        systemImage: "chart.bar",
                        description: Text("Log a listen from an album page to start building your stats.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 32) {
                            summaryTiles

                            if !stats.genreCounts.isEmpty {
                                loggedPosterGrid
                            }

                            sectionDivider
                            activitySection

                            if let collectionGrowth = stats.collectionGrowth {
                                sectionDivider
                                growthSection(collectionGrowth)
                            }

                            if !stats.genreCounts.isEmpty {
                                sectionDivider
                                genresSection
                            }

                            if stats.averageRating != nil {
                                sectionDivider
                                ratingsSection
                            }

                            if !stats.topArtists.isEmpty {
                                sectionDivider
                                topArtistsSection
                            }

                            sectionDivider
                            collectionSection

                            sectionDivider
                            milestonesSection
                        }
                        .padding()
                    }
                }
            }
            .background(LJTheme.background)
            .navigationTitle("Stats")
            .navigationDestination(for: Release.self) { release in
                AlbumDetailView(release: release)
            }
        }
    }

    // MARK: - Sections

    private var summaryTiles: some View {
        HStack(spacing: 0) {
            statTile(value: stats.collectionSize, label: "Albums")
            statTile(value: stats.totalAlbumsLogged, label: "Logged")
            statTile(value: stats.totalPlays, label: "Plays")
            statTile(value: stats.lovedCount, label: "Loved")
            if let hours = stats.totalHoursListened {
                statTile(text: String(format: "%.1f", hours), label: "Hours")
            }
        }
    }

    private var loggedPosterGrid: some View {
        let loggedReleases = releases
            .filter { !$0.isRemovedFromDiscogs && $0.isListened }
            .sorted { ($0.logEntries?.map(\.date).max() ?? .distantPast) > ($1.logEntries?.map(\.date).max() ?? .distantPast) }

        return VStack(alignment: .leading, spacing: 8) {
            Text("Logged Albums").font(.displayHeadline())
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 8)], spacing: 8) {
                ForEach(loggedReleases) { release in
                    NavigationLink(value: release) {
                        CachedAsyncImage(url: release.coverImageURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            LJTheme.surface
                        }
                        .aspectRatio(1, contentMode: .fill)
                        .coverArtStyle()
                    }
                }
            }
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Listening Activity").font(.displayHeadline())
            MonthlyBarChart(data: stats.activityByMonth)
        }
    }

    private func growthSection(_ data: [(month: Date, total: Int)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Collection Growth").font(.displayHeadline())
            CollectionGrowthChart(data: data)
        }
    }

    private var genresSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Genres").font(.displayHeadline())
            GenreBarChart(data: stats.genreCounts)
        }
    }

    private var ratingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Top Artists").font(.displayHeadline())
            VStack(spacing: 6) {
                ForEach(Array(stats.topArtists.enumerated()), id: \.offset) { index, entry in
                    HStack {
                        Text("\(index + 1).")
                            .foregroundStyle(LJTheme.textSecondary)
                            .frame(width: 24, alignment: .leading)
                        Text(entry.artist)
                            .foregroundStyle(LJTheme.textPrimary)
                        Spacer()
                        Text("\(entry.count)")
                            .foregroundStyle(LJTheme.accent)
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    private var collectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
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

    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Milestones").font(.displayHeadline())

            if let first = stats.firstLogged {
                albumHighlightRow(entry: first, caption: "First Logged")
            }
            ForEach(stats.milestoneEntries, id: \.index) { milestone in
                albumHighlightRow(entry: milestone.entry, caption: "\(milestone.index)th Listen")
            }
            if let recent = stats.mostRecentLogged, recent.persistentModelID != stats.firstLogged?.persistentModelID {
                albumHighlightRow(entry: recent, caption: "Most Recent")
            }
        }
    }

    // MARK: - Shared bits

    private func statTile(value: Int, label: String) -> some View {
        statTile(text: "\(value)", label: label)
    }

    private func statTile(text: String, label: String) -> some View {
        VStack(spacing: 2) {
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

    private func albumHighlightRow(entry: ListenLogEntry, caption: String) -> some View {
        Group {
            if let release = entry.release {
                NavigationLink(value: release) {
                    HStack(spacing: 12) {
                        CachedAsyncImage(url: release.coverImageURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            LJTheme.surface
                        }
                        .frame(width: 44, height: 44)
                        .coverArtStyle()

                        VStack(alignment: .leading, spacing: 2) {
                            Text(release.title).font(.subheadline).bold().foregroundStyle(LJTheme.textPrimary)
                            Text(release.artistName).font(.caption).foregroundStyle(LJTheme.textSecondary)
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
