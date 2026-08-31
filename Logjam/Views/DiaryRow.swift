import SwiftUI

struct DiaryRow: View {
    let entry: ListenLogEntry
    let release: Release
    var showDate: Bool = true

    var body: some View {
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

            VStack(alignment: .trailing, spacing: 2) {
                if showDate {
                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundStyle(LJTheme.textSecondary)
                }
                HStack(spacing: 2) {
                    if entry.loved {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(LJTheme.loved)
                            .font(.caption2)
                    }
                    ForEach(0..<Int(entry.stars.rounded(.down)), id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .foregroundStyle(LJTheme.accent)
                            .font(.caption2)
                    }
                    if entry.stars.truncatingRemainder(dividingBy: 1) != 0 {
                        Image(systemName: "star.leadinghalf.filled")
                            .foregroundStyle(LJTheme.accent)
                            .font(.caption2)
                    }
                }
            }
        }
    }
}
