import Foundation
import SwiftData

@Model
final class ListenLogEntry {
    var date: Date = Date.now
    /// Half-star units, 0...10 (e.g. 7 == 3.5 stars). Stored as an `Int` rather than the
    /// stars value itself so the persisted type never changes — avoids a CloudKit schema
    /// migration. Use `stars` to read/write in star units.
    var starRating: Int = 0
    var loved: Bool = false
    var release: Release?

    init(date: Date = .now, starRating: Int = 0, loved: Bool = false, release: Release? = nil) {
        self.date = date
        self.starRating = starRating
        self.loved = loved
        self.release = release
    }

    /// Rating expressed in stars: 0.0...5.0, in steps of 0.5.
    var stars: Double {
        get { Double(starRating) / 2 }
        set { starRating = Int((newValue * 2).rounded()) }
    }
}
