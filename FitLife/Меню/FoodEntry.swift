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
    var customProductID: UUID?

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
        aiMealName: String? = nil,
        customProductID: UUID? = nil
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
        self.customProductID = customProductID
    }
}
extension FoodEntry {
    var caloriesSafe: Int { max(product?.calories ?? 0, 0) }
    var proteinSafe: Double { max((product?.protein ?? 0).safeFinite, 0) }
    var fatSafe: Double { max((product?.fat ?? 0).safeFinite, 0) }
    var carbsSafe: Double { max((product?.carbs ?? 0).safeFinite, 0) }
    var portionSafe: Double { max(portion.safeFinite, 0) }
}
