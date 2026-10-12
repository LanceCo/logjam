import SwiftUI
import SwiftData

struct SellQueueView: View {
    @Query(sort: [SortDescriptor(\Release.artistSortName)])
    private var releases: [Release]

    private let client = DiscogsClient()
    private let statsCacheTTL: TimeInterval = 60 * 60 * 24

    private var sellReleases: [Release] {
        releases
            .filter { $0.keepSellStatus == .sell }
            .sorted { $0.artistSortName.localizedCaseInsensitiveCompare($1.artistSortName) == .orderedAscending }
    }

    /// Sums each release's lowest listed price, grouped by currency (Discogs marketplace
    /// stats are per-release and can in principle come back in different currencies).
    private var totalsByCurrency: [(currency: String, total: Double, count: Int)] {
        let priced = sellReleases.compactMap { release -> (currency: String, value: Double)? in
            guard let value = release.cachedLowestPriceValue, let currency = release.cachedLowestPriceCurrency else {
                return nil
            }
            return (currency, value)
        }
        let grouped = Dictionary(grouping: priced, by: \.currency)
        return grouped
            .map { (currency: $0.key, total: $0.value.reduce(0) { $0 + $1.value }, count: $0.value.count) }
            .sorted { $0.currency < $1.currency }
    }

    /// Releases we've actually checked with Discogs, whether or not they came back with a
    /// live listing — distinct from `cachedLowestPriceValue != nil`, which would otherwise
    /// conflate "no one's selling this" with "haven't asked yet" and never settle for records
    /// with zero listings.
    private var checkedCount: Int {
        sellReleases.filter { $0.statsFetchedAt != nil }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LJTheme.Spacing.lg) {
                    if !sellReleases.isEmpty {
                        overviewSection
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: LJTheme.Spacing.md)], spacing: LJTheme.Spacing.lg) {
                        ForEach(sellReleases) { release in
                            NavigationLink(value: release) {
                                SellQueueGridCell(release: release)
                            }
                            .buttonStyle(.ljPressable)
                            .task {
                                await loadStatsIfNeeded(for: release)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(LJTheme.background)
            .navigationTitle("Sell Queue")
            .navigationDestination(for: Release.self) { release in
                AlbumDetailView(release: release)
            }
            .overlay {
                if sellReleases.isEmpty {
                    LJEmptyStateView(
                        icon: "tag",
                        title: "Crate's Clean",
                        description: "Flag a record as \"Sell\" from its album page to add it here."
                    )
                }
            }
            .task {
                for release in sellReleases {
                    await loadStatsIfNeeded(for: release)
                }
            }
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: LJTheme.Spacing.sm) {
            HStack(spacing: 0) {
                statTile(value: "\(sellReleases.count)", label: "In Queue")
                if totalsByCurrency.isEmpty {
                    statTile(value: "—", label: "Listed Value")
                } else {
                    ForEach(totalsByCurrency, id: \.currency) { entry in
                        let average = entry.total / Double(entry.count)
                        statTile(
                            value: entry.total.formatted(.currency(code: entry.currency)),
                            label: totalsByCurrency.count > 1 ? "Listed (\(entry.currency))" : "Listed Value",
                            caption: "avg. \(average.formatted(.currency(code: entry.currency)))/record"
                        )
                    }
                }
            }
            if checkedCount < sellReleases.count {
                Text("Checked \(checkedCount) of \(sellReleases.count) — still fetching the rest from Discogs.")
                    .font(.caption)
                    .foregroundStyle(LJTheme.textSecondary)
            }
            Rectangle()
                .fill(LJTheme.accent)
                .frame(height: 1)
        }
    }

    private func statTile(value: String, label: String, caption: String? = nil) -> some View {
        VStack(spacing: LJTheme.Spacing.xxs) {
            Text(value).font(.displayTitle(22))
            Text(label).font(.caption).foregroundStyle(LJTheme.textSecondary)
            if let caption {
                Text(caption).font(.caption2).foregroundStyle(LJTheme.textSecondary.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func loadStatsIfNeeded(for release: Release) async {
        if let fetchedAt = release.statsFetchedAt, Date.now.timeIntervalSince(fetchedAt) < statsCacheTTL {
            return
        }
        if let result = try? await client.fetchMarketplaceStats(releaseID: release.discogsReleaseID) {
            release.cachedLowestPriceValue = result.lowestPrice?.value
            release.cachedLowestPriceCurrency = result.lowestPrice?.currency
            release.cachedNumForSale = result.numForSale
            release.statsFetchedAt = .now
        }
    }
}

private struct SellQueueGridCell: View {
    let release: Release

    var body: some View {
        VStack(alignment: .leading, spacing: LJTheme.Spacing.xs) {
            CachedAsyncImage(url: release.coverImageURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                LJTheme.surface
            }
            .aspectRatio(1, contentMode: .fill)
            .coverArtStyle()

            VStack(alignment: .leading, spacing: 2) {
                Text(release.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(LJTheme.textPrimary)
                    .lineLimit(1)
                Text(release.displayArtistName)
                    .font(.caption2)
                    .foregroundStyle(LJTheme.textSecondary)
                    .lineLimit(1)
                if let value = release.cachedLowestPriceValue, let currency = release.cachedLowestPriceCurrency {
                    Text(value.formatted(.currency(code: currency)))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(LJTheme.accent)
                } else if release.statsFetchedAt != nil {
                    Text("No listings")
                        .font(.caption2)
                        .foregroundStyle(LJTheme.textSecondary)
                }
            }
        }
    }
}
