import SwiftUI
import SwiftData

struct AlbumDetailView: View {
    @Bindable var release: Release
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var filterRequest: LibraryFilterRequest
    @State private var isShowingAddLog = false
    @State private var isLoadingDetail = false
    @State private var entryPendingDeletion: ListenLogEntry?
    @State private var entryBeingEdited: ListenLogEntry?
    @State private var isTracklistExpanded = false
    @State private var isCreditsExpanded = false

    private let client = DiscogsClient()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LJTheme.Spacing.lg) {
                ZStack(alignment: .bottomLeading) {
                    GeometryReader { geo in
                        CachedAsyncImage(url: release.coverImageURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            LJTheme.surface
                        }
                        .frame(width: geo.size.width, height: geo.size.width)
                        .clipped()
                    }
                    .aspectRatio(1, contentMode: .fit)

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.85)],
                        startPoint: .center,
                        endPoint: .bottom
                    )

                    VStack(alignment: .leading, spacing: LJTheme.Spacing.xs) {
                        Text(release.title)
                            .font(.displayTitle(30))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Button {
                            searchForArtist()
                        } label: {
                            HStack(spacing: LJTheme.Spacing.sm) {
                                Text(release.displayArtistName)
                                    .font(.title3)
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineLimit(1)
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
                .coverArtStyle()

                HStack {
                    if let year = release.year {
                        Text(String(year))
                    }
                    if let vinylType = release.vinylType {
                        Text("· \(vinylType)")
                    }
                    if let genre = release.genres.first {
                        Text("· \(genre)")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(LJTheme.textSecondary)

                Link(destination: release.discogsURL) {
                    Label("View on Discogs", systemImage: "arrow.up.right.square")
                }
                .font(.subheadline)
                .foregroundStyle(LJTheme.accent)

                Picker("Status", selection: $release.keepSellStatus) {
                    Text("Keep").tag(KeepSellStatus.keep)
                    Text("Sell").tag(KeepSellStatus.sell)
                }
                .pickerStyle(.segmented)

                if isLoadingDetail {
                    ProgressView()
                } else {
                    if let tracklist = release.cachedTracklist, !tracklist.isEmpty {
                        VStack(alignment: .leading, spacing: LJTheme.Spacing.sm) {
                            disclosureHeader("Tracklist", isExpanded: $isTracklistExpanded)
                            if isTracklistExpanded {
                                ForEach(tracklist, id: \.position) { track in
                                    HStack(alignment: .top) {
                                        Text(track.position)
                                            .foregroundStyle(LJTheme.textSecondary)
                                            .frame(width: 36, alignment: .leading)
                                        Text(track.title)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        if let duration = track.duration {
                                            Text(duration).foregroundStyle(LJTheme.textSecondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if let credits = release.cachedCredits, !credits.isEmpty {
                        VStack(alignment: .leading, spacing: LJTheme.Spacing.sm) {
                            disclosureHeader("Production Credits", isExpanded: $isCreditsExpanded)
                            if isCreditsExpanded {
                                ForEach(Array(credits.enumerated()), id: \.offset) { _, credit in
                                    HStack(alignment: .top) {
                                        Text(credit.name)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text(credit.role)
                                            .foregroundStyle(LJTheme.textSecondary)
                                            .multilineTextAlignment(.trailing)
                                    }
                                }
                            }
                        }
                    }
                }

                Divider()

                HStack {
                    Text("Listen Log").font(.displayHeadline())
                    Spacer()
                    Button {
                        isShowingAddLog = true
                    } label: {
                        Label("Log a Listen", systemImage: "plus.circle.fill")
                    }
                }

                ForEach((release.logEntries ?? []).sorted(by: { $0.date > $1.date })) { entry in
                    LogEntryRow(entry: entry) {
                        entryPendingDeletion = entry
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        entryBeingEdited = entry
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(LJTheme.background)
        .navigationTitle(release.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(LJTheme.accent)
                }
            }
        }
        .sheet(isPresented: $isShowingAddLog) {
            AddLogEntryView(release: release)
        }
        .sheet(item: $entryBeingEdited) { entry in
            AddLogEntryView(release: release, entryToEdit: entry)
        }
        .task {
            await loadDetailIfNeeded()
        }
        .alert(
            "Delete this log entry?",
            isPresented: Binding(
                get: { entryPendingDeletion != nil },
                set: { isPresented in if !isPresented { entryPendingDeletion = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let entry = entryPendingDeletion {
                    modelContext.delete(entry)
                }
                entryPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                entryPendingDeletion = nil
            }
        } message: {
            Text("This can't be undone.")
        }
    }

    private func searchForArtist() {
        filterRequest.artistSearchOriginTab = filterRequest.selectedTab
        filterRequest.pendingArtistSearch = release.displayArtistName
        filterRequest.selectedTab = .library
    }

    private func loadDetailIfNeeded() async {
        guard release.detailFetchedAt == nil || release.cachedLabels == nil else { return }
        isLoadingDetail = true
        defer { isLoadingDetail = false }
        if let result = try? await client.fetchReleaseDetail(releaseID: release.discogsReleaseID) {
            release.cachedTracklist = result.tracklist
            release.cachedCredits = result.extraartists
            release.cachedLabels = result.labels?.map(\.name) ?? []
            release.detailFetchedAt = .now
        }
    }

    private func disclosureHeader(_ title: String, isExpanded: Binding<Bool>) -> some View {
        Button {
            withAnimation { isExpanded.wrappedValue.toggle() }
        } label: {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
            }
        }
        .foregroundStyle(LJTheme.accent)
    }
}

private struct LogEntryRow: View {
    let entry: ListenLogEntry
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
            Spacer()
            StarRatingView(rating: .constant(entry.stars), isInteractive: false, iconSize: 13, spacing: 2, color: LJTheme.accent)
            if entry.loved {
                Image(systemName: "heart.fill").foregroundStyle(LJTheme.loved)
            }
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(LJTheme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .font(.subheadline)
    }
}
