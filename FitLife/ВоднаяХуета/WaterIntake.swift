import SwiftData
import Foundation

enum WaterPortionPreference {
    static let appStorageKey = "water.selectedPortionML"
    static let defaultML = 250
}

@Model
class WaterIntake {
    var id: UUID = UUID()
    var ownerId: String = ""
    var date: Date = Foundation.Date.now
    var intake: Double = 0
    var user: UserData? = nil
    var genderRawValue: String = FitLife.Gender.male.rawValue

    var gender: Gender {
        get { Gender(rawValue: genderRawValue) ?? .male }
        set { genderRawValue = newValue.rawValue }
    }

    init(date: Date, intake: Double, gender: Gender, ownerId: String = "") {
        self.ownerId = ownerId
        self.date = date
        self.intake = intake
        self.genderRawValue = gender.rawValue
    }
}
