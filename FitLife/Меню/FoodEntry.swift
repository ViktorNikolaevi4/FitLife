import SwiftData
import Foundation

@Model
class FoodEntry {
    @Attribute(.unique) var id: UUID = UUID()
    var date: Date = Foundation.Date.now
    var mealType: String = ""
    var portion: Double = 0
    var gender: Gender = FitLife.Gender.male
    var isFavorite: Bool = false

    @Relationship var product: Product?

    init(date: Date, mealType: String, product: Product, portion: Double, gender: Gender, isFavorite: Bool = false) {
        self.date = date
        self.mealType = mealType
        self.product = product
        self.portion = portion
        self.gender = gender
        self.isFavorite = isFavorite
    }
}
extension FoodEntry {
    var caloriesSafe: Int   { product?.calories ?? 0 }
    var proteinSafe: Double { product?.protein  ?? 0 }
    var fatSafe: Double     { product?.fat      ?? 0 }
    var carbsSafe: Double   { product?.carbs    ?? 0 }
}
