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
    var date: Date // Дата записи
    var mealType: String // Тип приема пищи (Завтрак, Обед, Ужин, Перекус)
    var portion: Double // Порция в граммах
    var gender: Gender // Пол пользователя (мужской/женский)
    var isFavorite: Bool = false // Новый флаг для избранного

    @Relationship var product: Product // Ссылка на продукт

    init(date: Date, mealType: String, product: Product, portion: Double, gender: Gender, isFavorite: Bool = false) {
        self.date = date
        self.mealType = mealType
        self.product = product
        self.portion = portion
        self.gender = gender
        self.isFavorite = isFavorite
    }
}

