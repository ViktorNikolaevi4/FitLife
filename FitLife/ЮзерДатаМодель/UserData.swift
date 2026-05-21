import SwiftUI
import SwiftData
import Foundation
import Observation

enum NutritionGoalMode: String, CaseIterable, Codable {
    case automatic
    case manual

    var titleKey: String {
        switch self {
        case .automatic:
            return "nutrition.goal_mode.auto"
        case .manual:
            return "nutrition.goal_mode.manual"
        }
    }
}

@Model
class UserData {
    var ownerId: String = ""
    @Relationship(deleteRule: .cascade, inverse: \WaterIntake.user) var waterEntries: [WaterIntake]? = []

    var weight: Double = 0
    var height: Double = 0
    var age: Int = 0
    var activityLevelRawValue: String = FitLife.ActivityLevel.none.rawValue
    var goalRawValue: String = FitLife.WeightGoal.currentWeight.rawValue
    var genderRawValue: String = FitLife.Gender.male.rawValue

    var calories: Int = 0
    var proteins: Int = 0
    var fats: Int = 0
    var carbs: Int = 0
    var nutritionGoalModeRawValue: String = FitLife.NutritionGoalMode.automatic.rawValue

    var activityLevel: ActivityLevel {
        get { ActivityLevel(rawValue: activityLevelRawValue) ?? .none }
        set { activityLevelRawValue = newValue.rawValue }
    }

    var goal: WeightGoal {
        get { WeightGoal(rawValue: goalRawValue) ?? .currentWeight }
        set { goalRawValue = newValue.rawValue }
    }

    var gender: Gender {
        get { Gender(rawValue: genderRawValue) ?? .male }
        set { genderRawValue = newValue.rawValue }
    }

    var nutritionGoalMode: NutritionGoalMode {
        get { NutritionGoalMode(rawValue: nutritionGoalModeRawValue) ?? .automatic }
        set { nutritionGoalModeRawValue = newValue.rawValue }
    }

    init(weight: Double = 0,
         height: Double = 0,
         age: Int = 0,
         ownerId: String = "",
         activityLevel: ActivityLevel = FitLife.ActivityLevel.none,
         goal: WeightGoal = FitLife.WeightGoal.currentWeight,
         gender: Gender = FitLife.Gender.male,
         calories: Int = 0,
         proteins: Int = 0,
         fats: Int = 0,
         carbs: Int = 0,
         nutritionGoalMode: NutritionGoalMode = FitLife.NutritionGoalMode.automatic) {

        self.ownerId = ownerId
        self.weight = weight
        self.height = height
        self.age = age
        self.activityLevelRawValue = activityLevel.rawValue
        self.goalRawValue = goal.rawValue
        self.genderRawValue = gender.rawValue
        self.calories = calories
        self.proteins = proteins
        self.fats = fats
        self.carbs = carbs
        self.nutritionGoalModeRawValue = nutritionGoalMode.rawValue
    }
}

extension UserData {
    var macros: (proteins: Int, fats: Int, carbs: Int) {
        get { (proteins, fats, carbs) }
        set {
            proteins = newValue.proteins
            fats = newValue.fats
            carbs = newValue.carbs
        }
    }
}
