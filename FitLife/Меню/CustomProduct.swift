import Foundation
import SwiftData

@Model
class CustomProduct {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    var protein: Double = 0
    var fat: Double = 0
    var carbs: Double = 0
    var calories: Int = 0
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


