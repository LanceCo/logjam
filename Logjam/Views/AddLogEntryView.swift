import SwiftUI

struct AddLogEntryView: View {
    let release: Release
    var entryToEdit: ListenLogEntry?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date
    @State private var stars: Double
    @State private var loved: Bool

    init(release: Release, entryToEdit: ListenLogEntry? = nil) {
        self.release = release
        self.entryToEdit = entryToEdit
        _date = State(initialValue: entryToEdit?.date ?? .now)
        _stars = State(initialValue: entryToEdit?.stars ?? 0)
        _loved = State(initialValue: entryToEdit?.loved ?? false)
    }

    private var isEditing: Bool { entryToEdit != nil }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $date, displayedComponents: .date)

                HStack {
                    Text("Rating")
                    Spacer()
                    StarRatingView(rating: $stars)
                }

                Toggle(isOn: $loved) {
                    Label("Loved it", systemImage: "heart.fill")
                }
            }
            .navigationTitle(isEditing ? "Edit Listen" : "Log a Listen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let entry = entryToEdit {
                            entry.date = date
                            entry.stars = stars
                            entry.loved = loved
                        } else {
                            let entry = ListenLogEntry(date: date, loved: loved)
                            entry.stars = stars
                            modelContext.insert(entry)
                            entry.release = release
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}
