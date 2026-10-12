import SwiftUI
import SwiftData

struct HomeView: View {
    @EnvironmentObject private var filterRequest: LibraryFilterRequest

    @Query(sort: [SortDescriptor(\ListenLogEntry.date, order: .reverse)])
    private var logEntries: [ListenLogEntry]

    @Query private var releases: [Release]

    @State private var isShowingSettings = false
    @State private var pickFormatFilter: PickFormat?
    @State private var showNoMatchesAlert = false
    @State private var navigationPath = NavigationPath()

    private var activeReleases: [Release] {
        releases.filter { !$0.isRemovedFromDiscogs }
    }

    private var listenedCount: Int {
        activeReleases.filter(\.isListened).count
    }

    private var lovedCount: Int {
        Set(logEntries.filter(\.loved).compactMap { $0.release?.persistentModelID }).count
    }

    private var recentLovedReleases: [Release] {
        var seen = Set<PersistentIdentifier>()
        var result: [Release] = []
        for entry in logEntries where entry.loved {
            guard let release = entry.release, seen.insert(release.persistentModelID).inserted else { continue }
            result.append(release)
            if result.count == 4 { break }
        }
        return result
    }

    private var recentlyAddedReleases: [Release] {
        activeReleases
            .filter { $0.dateAdded != nil }
            .sorted { ($0.dateAdded ?? .distantPast) > ($1.dateAdded ?? .distantPast) }
            .prefix(5)
            .map { $0 }
    }

    private var recentLogEntries: [ListenLogEntry] {
        Array(logEntries.prefix(5))
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: LJTheme.Spacing.xxl) {
                    HStack(spacing: 10) {
                        Image("AppLogo")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: LJTheme.Corner.sm))
                        Text("Logjam").font(.displayTitle(32)).foregroundStyle(LJTheme.textPrimary)
                    }

                    HStack(spacing: 0) {
                        statTile(value: activeReleases.count, label: "Albums")

                        Button {
                            showFiltered(.listened)
                        } label: {
                            statTile(value: listenedCount, label: "Listened")
                        }
                        .buttonStyle(.plain)

                        Button {
                            showFiltered(.loved)
                        } label: {
                            statTile(value: lovedCount, label: "Loved")
                        }
                        .buttonStyle(.plain)
                    }
                    sectionDivider

                    if !recentLovedReleases.isEmpty {
                        VStack(alignment: .leading, spacing: LJTheme.Spacing.sm) {
                            Text("Recently Loved").font(.displayHeadline())
                            posterGrid(recentLovedReleases, columns: 4)
                        }
                    }

                    if !recentlyAddedReleases.isEmpty {
                        VStack(alignment: .leading, spacing: LJTheme.Spacing.sm) {
                            Text("Recently Added").font(.displayHeadline())
                            posterGrid(recentlyAddedReleases, columns: 5)
                        }
                    }

                    VStack(alignment: .leading, spacing: LJTheme.Spacing.sm) {
                        HStack {
                            Text("Recent Activity").font(.displayHeadline())
                            Spacer()
                            Button {
                                filterRequest.selectedTab = .diary
                            } label: {
                                Image(systemName: "arrow.right")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(LJTheme.accent)
                            }
                        }
                        if recentLogEntries.isEmpty {
                            Text("Nothing spinning yet — log a listen from an album page to see it here.")
                                .font(.subheadline)
                                .foregroundStyle(LJTheme.textSecondary)
                        } else {
                            ForEach(recentLogEntries) { entry in
                                if let release = entry.release {
                                    NavigationLink(value: release) {
                                        DiaryRow(entry: entry, release: release)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: LJTheme.Spacing.lg) {
                        sectionDivider
                        pickForMeButton
                    }
                }
                .padding()
            }
            .background(LJTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Release.self) { release in
                AlbumDetailView(release: release)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
            .alert("No Records Found", isPresented: $showNoMatchesAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("No unlistened records match that format.")
            }
        }
    }

    private func statTile(value: Int, label: String) -> some View {
        VStack(spacing: LJTheme.Spacing.xxs) {
            Text("\(value)").font(.displayTitle(22))
            Text(label).font(.caption).foregroundStyle(LJTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func posterGrid(_ releases: [Release], columns: Int) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: LJTheme.Spacing.sm), count: columns), spacing: LJTheme.Spacing.sm) {
            ForEach(releases) { release in
                NavigationLink(value: release) {
                    CachedAsyncImage(url: release.coverImageURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        LJTheme.surface
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .clipped()
                    .coverArtStyle()
                }
                .buttonStyle(.ljPressable)
            }
        }
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(LJTheme.accent)
            .frame(height: 1)
    }

    private var pickForMeButton: some View {
        GeometryReader { geo in
            let buttonWidth = geo.size.width * 0.75
            let buttonHeight: CGFloat = 37.5

            HStack {
                Spacer()
                HStack(spacing: 0) {
                    Button(action: pickForMe) {
                        HStack(spacing: LJTheme.Spacing.sm) {
                            Image(systemName: "shuffle")
                            Text("Pick for Me").fontWeight(.semibold)
                        }
                        .frame(width: buttonWidth * 0.75, height: buttonHeight)
                    }
                    .buttonStyle(.plain)

                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 1, height: buttonHeight * 0.5)

                    Menu {
                        Button("Any Format") { pickFormatFilter = nil }
                        ForEach(PickFormat.allCases) { format in
                            Button(format.rawValue) { pickFormatFilter = format }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text(pickFormatFilter?.rawValue ?? "Any")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .frame(width: buttonWidth * 0.25 - 1, height: buttonHeight)
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: buttonWidth, height: buttonHeight)
                .foregroundStyle(.white)
                .background(LJTheme.accent)
                .clipShape(Capsule())
                Spacer()
            }
        }
        .frame(height: 37.5)
    }

    private func showFiltered(_ status: StatusFilter) {
        filterRequest.pendingStatusFilter = status
        filterRequest.selectedTab = .library
    }

    private func pickForMe() {
        let candidates = activeReleases.filter { release in
            !release.isListened && (pickFormatFilter?.matches(release.formatDescriptions) ?? true)
        }
        guard let picked = candidates.randomElement() else {
            showNoMatchesAlert = true
            return
        }
        navigationPath.append(picked)
    }
}
