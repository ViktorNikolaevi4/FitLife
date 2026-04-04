import Foundation
import SwiftData

@Model
final class BodyMeasurements {
    var id: UUID = UUID()
    var ownerId: String = ""
    var date: Date = Foundation.Date.now               // дата замера
    var chest: Double = 0               // грудь, см
    var waist: Double = 0               // талия (самое узкое), см
    var belly: Double = 0               // живот (на уровне пупка), см
    var hips: Double = 0                // бёдра, см

    init(ownerId: String = "",
         date: Date = Foundation.Date.now,
         chest: Double,
         waist: Double,
         belly: Double,
         hips: Double
    ) {
        self.ownerId = ownerId
        self.date = date
        self.chest = chest
        self.waist = waist
        self.belly = belly
        self.hips = hips
    }
}
