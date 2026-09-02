import SwiftUI
import SwiftData

struct DiaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\ListenLogEntry.date, order: .reverse)])
    private var logEntries: [ListenLogEntry]
    @State private var entryBeingEdited: ListenLogEntry?

    private var groupedByDay: [(day: Date, entries: [ListenLogEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: logEntries) { calendar.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { day in
            (day, grouped[day]!.sorted { $0.date > $1.date })
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedByDay, id: \.day) { group in
                    Section {
                        ForEach(group.entries) { entry in
                            if let release = entry.release {
                                NavigationLink(value: release) {
                                    DiaryRow(entry: entry, release: release, showDate: false)
                                }
                                .swipeActions {
                                    Button(role: .destructive) {
                                        modelContext.delete(entry)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    Button {
                                        entryBeingEdited = entry
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(LJTheme.accent)
                                }
                            }
                        }
                    } header: {
                        Text(group.day.formatted(date: .abbreviated, time: .omitted))
                            .font(.displayHeadline(15))
                            .foregroundStyle(LJTheme.textPrimary)
                            .textCase(nil)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(LJTheme.background)
            .navigationTitle("Diary")
            .navigationDestination(for: Release.self) { release in
                AlbumDetailView(release: release)
            }
            .sheet(item: $entryBeingEdited) { entry in
                if let release = entry.release {
                    AddLogEntryView(release: release, entryToEdit: entry)
                }
            }
            .overlay {
                if logEntries.isEmpty {
                    LJEmptyStateView(
                        icon: "book.closed",
                        title: "Nothing Spinning Yet",
                        description: "Log a listen from an album page to start your diary."
                    )
                }
            }
        }
    }
}
