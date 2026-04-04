import SwiftData
import Foundation

@Model
class WaterIntake {
    var id: UUID = UUID()
    var ownerId: String = ""
    var date: Date = Foundation.Date.now
    var intake: Double = 0
    var user: UserData? = nil
    var gender: Gender = FitLife.Gender.male

    init(date: Date, intake: Double, gender: Gender, ownerId: String = "") {
        self.ownerId = ownerId
        self.date = date
        self.intake = intake
        self.gender = gender
    }
}
