import Foundation
import SwiftData

@Model
class CustomProduct {
    var id: UUID = UUID()
    var name: String = ""
    var protein: Double = 0
    var fat: Double = 0
    var carbs: Double = 0
    var calories: Int = 0
    var isFavorite: Bool = false
    var isAIGenerated: Bool = false

    init(
        name: String,
        protein: Double,
        fat: Double,
        carbs: Double,
        calories: Int,
        isFavorite: Bool = false,
        isAIGenerated: Bool = false
    ) {
        self.name = name
        self.protein = max(protein.safeFinite, 0)
        self.fat = max(fat.safeFinite, 0)
        self.carbs = max(carbs.safeFinite, 0)
        self.calories = max(calories, 0)
        self.isFavorite = isFavorite
        self.isAIGenerated = isAIGenerated
    }
}
