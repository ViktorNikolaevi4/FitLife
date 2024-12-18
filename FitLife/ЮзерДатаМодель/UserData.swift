//
//  UserData.swift
//  FitLife
//
//  Created by Виктор Корольков on 10.12.2024.
//

import Foundation
import SwiftUI
import Observation

@Observable
class UserData {
     var weight: Double = 0
     var height: Double = 0
     var age: Int = 0
    var activityLevel: ActivityLevel = .none
    var goal: WeightGoal = .currentWeight
    var selectedGender: Gender = .male

    var calories: Int {
        guard weight > 0, height > 0, age > 0 else { return 0 }
        return MacrosCalculator.calculateCaloriesMifflin(
            gender: selectedGender,
            weight: weight,
            height: height,
            age: age,
            activityLevel: activityLevel,
            goal: goal
        )
    }

    var macros: (proteins: Int, fats: Int, carbs: Int) {
        return MacrosCalculator.calculateMacros(calories: calories, goal: goal)
    }
}

