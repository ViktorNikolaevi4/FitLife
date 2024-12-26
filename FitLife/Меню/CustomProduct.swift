//
//  CustomProduct.swift
//  FitLife
//
//  Created by Виктор Корольков on 25.12.2024.
//

import Foundation
import SwiftData

@Model
class CustomProduct {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String
    var protein: Double
    var fat: Double
    var carbs: Double
    var calories: Int
    var isFavorite: Bool = false

    init(name: String, protein: Double, fat: Double, carbs: Double, calories: Int, isFavorite: Bool = false) {
        self.name = name
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.calories = calories
        self.isFavorite = isFavorite
    }
}

