import SwiftUI
import Foundation
import SwiftCSV

struct Product: Identifiable, Decodable {
    let id = UUID()
    let name: String
    let protein: Double
    let fat: Double
    let carbs: Double
    let calories: Int
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
