import SwiftData
import Foundation

@Model
class FoodEntry {
    var id: UUID = UUID()
    var ownerId: String = ""
    var date: Date = Foundation.Date.now
    var mealType: String = ""
    var portion: Double = 0
    var gender: Gender = FitLife.Gender.male
    var isFavorite: Bool = false
    var aiMealGroupID: String?
    var aiMealName: String?

    var product: Product?

    init(
        date: Date,
        mealType: String,
        product: Product,
        portion: Double,
        gender: Gender,
        ownerId: String = "",
        isFavorite: Bool = false,
        aiMealGroupID: String? = nil,
        aiMealName: String? = nil
    ) {
        self.ownerId = ownerId
        self.date = date
        self.mealType = mealType
        self.product = product
        self.portion = portion
        self.gender = gender
        self.isFavorite = isFavorite
        self.aiMealGroupID = aiMealGroupID
        self.aiMealName = aiMealName
    }
}
extension FoodEntry {
    var caloriesSafe: Int   { product?.calories ?? 0 }
    var proteinSafe: Double { product?.protein  ?? 0 }
    var fatSafe: Double     { product?.fat      ?? 0 }
    var carbsSafe: Double   { product?.carbs    ?? 0 }
}
