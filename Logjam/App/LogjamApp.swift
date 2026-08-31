import SwiftUI
import SwiftData

@main
struct LogjamApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([Release.self, ListenLogEntry.self])
            let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
        Self.migrateToHalfStarRatingsIfNeeded(modelContainer: modelContainer)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }

    /// One-time migration: `starRating` used to store whole stars (0...5). It now stores
    /// half-star units (0...10) so the log form can offer half-star precision. Existing
    /// values are doubled once, in place, so past ratings keep their original meaning.
    private static func migrateToHalfStarRatingsIfNeeded(modelContainer: ModelContainer) {
        let key = "hasMigratedToHalfStarRatings"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let context = ModelContext(modelContainer)
        let entries = (try? context.fetch(FetchDescriptor<ListenLogEntry>())) ?? []
        for entry in entries {
            entry.starRating *= 2
        }
        if context.hasChanges {
            try? context.save()
        }
        UserDefaults.standard.set(true, forKey: key)
    }
}
