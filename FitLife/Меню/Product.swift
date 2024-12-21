import SwiftUI
import Foundation
import SwiftCSV

struct Product: Identifiable, Decodable {
    let id = UUID()
    var name: String
    var protein: Double
    var fat: Double
    var carbs: Double
    var calories: Int
//    var portion: Double = 100 
    var isFavorite: Bool = false
    var isCustom: Bool = false

    enum CodingKeys: String, CodingKey {
        case name = "Продукт"
        case protein = "Белки"
        case fat = "Жиры"
        case carbs = "Углеводы"
        case calories = "Калл" // Новый ключ для калорий
    }
}
