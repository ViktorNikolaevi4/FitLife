import SwiftUI
import SwiftData
import Foundation
import Observation

@Model
class UserData {
    var weight: Double = 0
    var height: Double = 0
    var age: Int = 0
    var activityLevel: ActivityLevel = FitLife.ActivityLevel.none
    var goal: WeightGoal = FitLife.WeightGoal.currentWeight
    var gender: Gender = FitLife.Gender.male

    var calories: Int = 0
    var proteins: Int = 0
    var fats: Int = 0
    var carbs: Int = 0

    init(weight: Double = 0,
         height: Double = 0,
         age: Int = 0,
         activityLevel: ActivityLevel = FitLife.ActivityLevel.none,
         goal: WeightGoal = FitLife.WeightGoal.currentWeight,
         gender: Gender = FitLife.Gender.male,
         calories: Int = 0,
         proteins: Int = 0,
         fats: Int = 0,
         carbs: Int = 0) {

        self.weight = weight
        self.height = height
        self.age = age
        self.activityLevel = activityLevel
        self.goal = goal
        self.gender = gender
        self.calories = calories
        self.proteins = proteins
        self.fats = fats
        self.carbs = carbs
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
