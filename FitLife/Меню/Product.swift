import SwiftUI
import Foundation
import SwiftCSV
import SwiftData

@Model
class Product {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String
    var protein: Double
    var fat: Double
    var carbs: Double
    var calories: Int
    var isFavorite: Bool = false
    var isCustom: Bool = false

  //  @Relationship(inverse: \FoodEntry.product) var entries: [FoodEntry] = [] // Обратная связь

    init(name: String, protein: Double, fat: Double, carbs: Double, calories: Int, isFavorite: Bool = false, isCustom: Bool = false) {
        self.name = name
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.calories = calories
        self.isFavorite = isFavorite
        self.isCustom = isCustom
    }
}

