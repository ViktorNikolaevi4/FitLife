//
//  FoodEntry.swift
//  FitLife
//
//  Created by Виктор Корольков on 21.12.2024.
//

import SwiftData
import Foundation

@Model
class FoodEntry {
    @Attribute(.unique) var id: UUID = UUID() // Уникальный идентификатор
    var date: Date // Дата записи (например, 21 декабря 2024)
    var mealType: String // Тип приема пищи (Завтрак, Обед, Ужин, Перекус)
    var productName: String // Название продукта
    var protein: Double // Белки
    var fat: Double // Жиры
    var carbs: Double // Углеводы
    var calories: Int // Калории
    var portion: Double // Порция в граммах
    var gender: Gender // Пол пользователя (мужской/женский)
    var isFavorite: Bool = false // Новый флаг для избранного

    init(date: Date, mealType: MealType, product: Product, portion: Double, gender: Gender, isFavorite: Bool = false) {
        self.date = date
        self.mealType = mealType.rawValue
        self.productName = product.name
        self.protein = product.protein * (portion / 100)
        self.fat = product.fat * (portion / 100)
        self.carbs = product.carbs * (portion / 100)
        self.calories = Int(Double(product.calories))
        self.portion = portion
        self.gender = gender
        self.isFavorite = isFavorite
    }
}
