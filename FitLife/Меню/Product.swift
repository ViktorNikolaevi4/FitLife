import SwiftUI
import Foundation
import SwiftCSV
import SwiftData

@Model
class Product {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    var protein: Double = 0
    var fat: Double = 0
    var carbs: Double = 0
    var calories: Int = 0
    var isFavorite: Bool = false
    var isCustom: Bool = false

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
