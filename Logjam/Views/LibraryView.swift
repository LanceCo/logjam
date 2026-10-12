import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Release.artistSortName), SortDescriptor(\Release.year)])
    private var releases: [Release]

    @StateObject private var syncService = SyncService()
    @EnvironmentObject private var filterRequest: LibraryFilterRequest

    @State private var searchText = ""
    @State private var genreFilter: String?
    @State private var formatFilter: String?
    @State private var listenedFilter: StatusFilter = .all
    @State private var viewMode: ViewMode = .list
    @State private var isShowingSettings = false
    @State private var navigationPath = NavigationPath()

    enum ViewMode {
        case list
        case grid
    }

    private var filteredReleases: [Release] {
        releases.filter { release in
            !release.isRemovedFromDiscogs
                && (genreFilter == nil || release.genres.contains(genreFilter!))
                && (formatFilter == nil || release.formatDescriptions.contains(formatFilter!))
                && statusMatches(release)
                && (searchText.isEmpty
                    || Self.searchNormalized(release.artistName).contains(Self.searchNormalized(searchText))
                    || Self.searchNormalized(release.title).contains(Self.searchNormalized(searchText)))
        }
    }

    /// iOS's keyboard "Smart Punctuation" turns a typed straight apostrophe (') into a
    /// curly one (’) as you type, so a search for "D'Angelo" doesn't match Discogs' stored
    /// straight-quote data. Fold both sides to a common form — case, diacritics, and quote
    /// style — before comparing.
    private static func searchNormalized(_ string: String) -> String {
        string
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    private func statusMatches(_ release: Release) -> Bool {
        switch listenedFilter {
        case .all: return true
        case .listened: return release.isListened
        case .notListened: return !release.isListened
        case .loved: return release.isLoved
        }
    }

    private var hasActiveFilters: Bool {
        genreFilter != nil || formatFilter != nil || listenedFilter != .all
    }

    private func clearFilters() {
        genreFilter = nil
        formatFilter = nil
        listenedFilter = .all
    }

    private var groupedReleases: [(letter: String, releases: [Release])] {
        let grouped = Dictionary(grouping: filteredReleases) { release -> String in
            guard let first = release.artistSortName.first, first.isLetter else { return "#" }
            return String(first).uppercased()
        }
        return grouped.keys.sorted().map { letter in
            (letter, grouped[letter]!.sorted {
                $0.artistSortName.localizedCaseInsensitiveCompare($1.artistSortName) == .orderedAscending
            })
        }
    }

    private var availableGenres: [String] {
        Array(Set(releases.flatMap { $0.genres })).sorted()
    }

    private var availableFormats: [String] {
        Array(Set(releases.flatMap { $0.formatDescriptions })).sorted()
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                filterBar

                ScrollViewReader { proxy in
                ZStack(alignment: .trailing) {
                    Group {
                        switch viewMode {
                        case .list:
                            List {
                                ForEach(groupedReleases, id: \.letter) { group in
                                    Section {
                                        ForEach(group.releases) { release in
                                            Button {
                                                navigationPath.append(release)
                                            } label: {
                                                LibraryRow(release: release)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    } header: {
                                        Text(group.letter)
                                            .font(.displayHeadline())
                                            .foregroundStyle(LJTheme.textSecondary)
                                            .textCase(nil)
                                    }
                                    .id(group.letter)
                                }
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                            .background(LJTheme.background)
                        case .grid:
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: LJTheme.Spacing.xl) {
                                    ForEach(groupedReleases, id: \.letter) { group in
                                        VStack(alignment: .leading, spacing: LJTheme.Spacing.sm) {
                                            Text(group.letter)
                                                .font(.displayHeadline())
                                                .foregroundStyle(LJTheme.textSecondary)
                                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: LJTheme.Spacing.md)], spacing: LJTheme.Spacing.md) {
                                                ForEach(group.releases) { release in
                                                    NavigationLink(value: release) {
                                                        LibraryGridCell(release: release)
                                                    }
                                                    .buttonStyle(.ljPressable)
                                                }
                                            }
                                        }
                                        .id(group.letter)
                                    }
                                }
                                .padding()
                            }
                            .background(LJTheme.background)
                        }
                    }
                    // Reserve room for AlphabetIndexView (20pt wide, floating on top) plus a
                    // visible gap, so row/cell content — especially the trailing "listened"
                    // checkmark — doesn't sit flush against the index strip.
                    .padding(.trailing, 20 + LJTheme.Spacing.sm)

                    if groupedReleases.count > 1 {
                        AlphabetIndexView(letters: groupedReleases.map(\.letter)) { letter in
                            proxy.scrollTo(letter, anchor: .top)
                        }
                    }
                }
                .overlay {
                    if groupedReleases.isEmpty {
                        LJEmptyStateView(
                            icon: "magnifyingglass",
                            title: hasActiveFilters || !searchText.isEmpty ? "No Matches" : "No Records Yet",
                            description: hasActiveFilters || !searchText.isEmpty
                                ? "Try adjusting your filters or search."
                                : "Sync your Discogs collection to see it here."
                        )
                    }
                }
                }
            }
            .navigationTitle("Library")
            .navigationDestination(for: Release.self) { release in
                AlbumDetailView(release: release)
            }
            .searchable(text: $searchText, prompt: "Search artist or album")
            .toolbar {
                if let originTab = filterRequest.artistSearchOriginTab {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            searchText = ""
                            filterRequest.artistSearchOriginTab = nil
                            filterRequest.selectedTab = originTab
                        } label: {
                            Image(systemName: "chevron.left")
                                .foregroundStyle(LJTheme.accent)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewMode = (viewMode == .list) ? .grid : .list
                    } label: {
                        Image(systemName: viewMode == .list ? "square.grid.2x2" : "list.bullet")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Section(lastSyncedLabel) {
                            Button {
                                Task { await syncService.sync(context: modelContext) }
                            } label: {
                                Label("Resync", systemImage: "arrow.triangle.2.circlepath")
                            }
                        }
                        Button {
                            isShowingSettings = true
                        } label: {
                            Label("Settings", systemImage: "slider.horizontal.3")
                        }
                    } label: {
                        if syncService.isSyncing {
                            ProgressView()
                        } else {
                            Image(systemName: "gearshape")
                        }
                    }
                    .disabled(syncService.isSyncing)
                }
            }
            .refreshable {
                await syncService.sync(context: modelContext)
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
            .alert("Sync Error", isPresented: .constant(syncService.lastError != nil), actions: {
                Button("OK") { syncService.lastError = nil }
            }, message: {
                Text(syncService.lastError ?? "")
            })
            .alert("Discogs Not Connected", isPresented: $syncService.needsCredentials) {
                Button("Go to Settings") { isShowingSettings = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Add your Discogs username and personal access token in Settings, then sync again.")
            }
            .sensoryFeedback(.success, trigger: syncService.isSyncing) { old, new in
                old && !new && syncService.lastError == nil
            }
            .sensoryFeedback(.error, trigger: syncService.lastError)
            .onChange(of: filterRequest.selectedTab) { _, newTab in
                guard newTab == .library else { return }
                if let pending = filterRequest.pendingStatusFilter {
                    listenedFilter = pending
                    viewMode = .grid
                    filterRequest.pendingStatusFilter = nil
                    filterRequest.artistSearchOriginTab = nil
                } else if filterRequest.pendingArtistSearch == nil {
                    clearFilters()
                    filterRequest.artistSearchOriginTab = nil
                }
            }
            .onChange(of: filterRequest.pendingArtistSearch) { _, newValue in
                guard let artist = newValue else { return }
                clearFilters()
                navigationPath = NavigationPath()
                searchText = artist
                viewMode = .list
                filterRequest.pendingArtistSearch = nil
            }
            .onChange(of: searchText) { _, newValue in
                if newValue.isEmpty {
                    filterRequest.artistSearchOriginTab = nil
                }
            }
        }
    }

    private var lastSyncedLabel: String {
        guard let date = syncService.lastSyncedAt else { return "Never synced" }
        return "Last synced \(date.formatted(.relative(presentation: .named)))"
    }

    private var filterBar: some View {
        HStack(spacing: LJTheme.Spacing.sm) {
            Menu {
                Picker("Genre", selection: $genreFilter) {
                    Text("All Genres").tag(String?.none)
                    ForEach(availableGenres, id: \.self) { genre in
                        Text(genre).tag(String?.some(genre))
                    }
                }
            } label: {
                filterChip(genreFilter ?? "Genre", isActive: genreFilter != nil)
            }

            Menu {
                Picker("Format", selection: $formatFilter) {
                    Text("All Formats").tag(String?.none)
                    ForEach(availableFormats, id: \.self) { format in
                        Text(format).tag(String?.some(format))
                    }
                }
            } label: {
                filterChip(formatFilter ?? "Format", isActive: formatFilter != nil)
            }

            Menu {
                Picker("Status", selection: $listenedFilter) {
                    ForEach(StatusFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
            } label: {
                filterChip(listenedFilter == .all ? "Status" : listenedFilter.rawValue, isActive: listenedFilter != .all)
            }

            if hasActiveFilters {
                Button(action: clearFilters) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(LJTheme.textSecondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, LJTheme.Spacing.sm)
        .background(LJTheme.background)
    }

    private func filterChip(_ title: String, isActive: Bool) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(width: 108)
            .padding(.vertical, 6)
            .background(isActive ? LJTheme.accent.opacity(0.18) : LJTheme.surface)
            .foregroundStyle(isActive ? LJTheme.accent : LJTheme.textSecondary)
            .clipShape(Capsule())
    }
}

private struct LibraryRow: View {
    let release: Release

    var body: some View {
        HStack {
            CachedAsyncImage(url: release.coverImageURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                LJTheme.surface
            }
            .frame(width: 50, height: 50)
            .coverArtStyle()

            VStack(alignment: .leading) {
                Text(release.displayArtistName).font(.headline).foregroundStyle(LJTheme.textPrimary)
                Text(release.title).font(.subheadline).foregroundStyle(LJTheme.textSecondary)
            }

            Spacer()

            if release.isListened {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(LJTheme.accent)
            }
        }
        .listRowBackground(LJTheme.background)
    }
}

private struct LibraryGridCell: View {
    let release: Release

    var body: some View {
        VStack(alignment: .leading, spacing: LJTheme.Spacing.xs) {
            ZStack(alignment: .topTrailing) {
                CachedAsyncImage(url: release.coverImageURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    LJTheme.surface
                }
                .aspectRatio(1, contentMode: .fill)
                .coverArtStyle()

                if release.isListened {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(LJTheme.accent)
                        .padding(LJTheme.Spacing.xs)
                }
            }
            Text(release.displayArtistName)
                .font(.caption)
                .foregroundStyle(LJTheme.textPrimary)
                .lineLimit(1)
        }
    }
}
