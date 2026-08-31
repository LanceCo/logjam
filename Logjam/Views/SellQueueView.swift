import SwiftUI
import SwiftData

struct SellQueueView: View {
    @Query(sort: [SortDescriptor(\Release.artistSortName)])
    private var releases: [Release]

    private let client = DiscogsClient()
    private let statsCacheTTL: TimeInterval = 60 * 60 * 24

    private var sellReleases: [Release] {
        releases.filter { $0.keepSellStatus == .sell }
    }

    var body: some View {
        NavigationStack {
            List(sellReleases) { release in
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
                            Text(release.artistName).font(.subheadline).foregroundStyle(LJTheme.textSecondary)
                            if let value = release.cachedLowestPriceValue, let currency = release.cachedLowestPriceCurrency {
                                Text("Lowest listed: \(value, format: .currency(code: currency))")
                                    .font(.caption)
                                    .foregroundStyle(LJTheme.accent)
                            }
                        }
                    }
                }
                .task {
                    await loadStatsIfNeeded(for: release)
                }
            }
            .scrollContentBackground(.hidden)
            .background(LJTheme.background)
            .navigationTitle("Sell Queue")
            .navigationDestination(for: Release.self) { release in
                AlbumDetailView(release: release)
            }
            .overlay {
                if sellReleases.isEmpty {
                    ContentUnavailableView(
                        "Crate's Clean",
                        systemImage: "tag",
                        description: Text("Flag a record as \"Sell\" from its album page to add it here.")
                    )
                }
            }
        }
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
