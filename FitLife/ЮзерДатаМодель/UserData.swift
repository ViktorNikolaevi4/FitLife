
import SwiftData
import Foundation
import SwiftUI
import Observation

@Model
class UserData {
    var id: UUID = UUID() // Уникальный идентификатор пользователя
    var weight: Double
    var height: Double
    var age: Int
    var activityLevel: ActivityLevel
    var goal: WeightGoal
    var gender: Gender // Пол пользователя для фильтрации
    var waterIntakes: [WaterIntake] = [] // Связанные записи о воде

    func calculateCalories() async -> Int {
        guard weight > 0, height > 0, age > 0 else { return 0 }
        return await MacrosCalculator.calculateCaloriesMifflin(
            gender: gender,
            weight: weight,
            height: height,
            age: age,
            activityLevel: activityLevel,
            goal: goal
        )
    }

    func calculateMacros() async -> (proteins: Int, fats: Int, carbs: Int) {
        let calories = await calculateCalories()
        return await MacrosCalculator.calculateMacros(calories: calories, goal: goal)
    }

    init(
        weight: Double = 0,
        height: Double = 0,
        age: Int = 0,
        activityLevel: ActivityLevel = ActivityLevel.none, // Полностью квалифицированное имя
        goal: WeightGoal = WeightGoal.currentWeight,      // Полностью квалифицированное имя
    //    selectedGender: Gender = Gender.male,
        gender: Gender = .male
    ) {
        self.weight = weight
        self.height = height
        self.age = age
        self.activityLevel = activityLevel
        self.goal = goal
     //   self.selectedGender = selectedGender
        self.gender = gender
    }
}

