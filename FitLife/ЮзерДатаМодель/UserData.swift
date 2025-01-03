
import SwiftUI
import SwiftData
import Foundation
import Observation

@Model
class UserData {
    // Основные параметры
    var weight: Double
    var height: Double
    var age: Int
    var activityLevel: ActivityLevel
    var goal: WeightGoal
    var gender: Gender

    // Ранее вы хранили это так:
    // var macros: (proteins: Int, fats: Int, carbs: Int)

    // Теперь сохраняем как отдельные поля
    var calories: Int
    var proteins: Int
    var fats: Int
    var carbs: Int

    // Инициализатор
    init(weight: Double = 0,
         height: Double = 0,
         age: Int = 0,
         activityLevel: ActivityLevel = .none,
         goal: WeightGoal = .currentWeight,
         gender: Gender = .male,
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

// При этом, если нужно работать с кортежем:
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
