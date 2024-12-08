//
//  MacrosCalculator.swift
//  FitLife
//
//  Created by Виктор Корольков on 08.12.2024.
//

import Foundation

struct MacrosCalculator {
    // Создаём структуру `MacrosCalculator`, которая содержит методы для расчёта калорий и БЖУ.

    static func calculateCaloriesMifflin(gender: Gender, weight: Double, height: Double, age: Int, activityLevel: ActivityLevel) -> Int {
        // Метод для расчёта суточной нормы калорий по формуле Миффлина-Сан Жеора.
        // - `gender`: Пол пользователя (мужчина или женщина).
        // - `weight`: Вес в килограммах.
        // - `height`: Рост в сантиметрах.
        // - `age`: Возраст в годах.
        // - `activityLevel`: Уровень физической активности.
        // Возвращает суточную норму калорий (целое число).

        let bmr: Double
        // Переменная для базового метаболизма (BMR — базовый уровень калорий, которые тратятся в состоянии покоя).

        if gender == .male {
            // Проверяем, является ли пользователь мужчиной.
            bmr = 10 * weight + 6.25 * height - 5 * Double(age) + 5
            // Формула для расчёта BMR для мужчин:
            // 10 × вес (кг) + 6.25 × рост (см) − 5 × возраст (лет) + 5.
        } else {
            // Если пользователь — женщина.
            bmr = 10 * weight + 6.25 * height - 5 * Double(age) - 161
            // Формула для расчёта BMR для женщин:
            // 10 × вес (кг) + 6.25 × рост (см) − 5 × возраст (лет) − 161.
        }

        let activityMultiplier: Double
        // Переменная для коэффициента физической активности.

        switch activityLevel {
        // Определяем коэффициент активности в зависимости от выбранного уровня:
        case .none:
            activityMultiplier = 1.2
            // Минимальная активность (сидячий образ жизни).
        case .light:
            activityMultiplier = 1.375
            // Лёгкая активность (легкие тренировки 1–3 раза в неделю).
        case .moderate:
            activityMultiplier = 1.55
            // Умеренные тренировки 3–5 раз в неделю.
        case .pro:
            activityMultiplier = 1.725
            // Высокая активность (интенсивные тренировки 6–7 раз в неделю).
        }

        return Int(bmr * activityMultiplier)
        // Возвращаем итоговое значение калорий, умножив BMR на коэффициент активности.
        // Результат приводим к целому числу (`Int`).
    }

    static func calculateMacros(calories: Int) -> (proteins: Int, fats: Int, carbs: Int) {
        // Метод для расчёта распределения калорий на белки, жиры и углеводы.
        // Принимает:
        // - `calories`: Общее количество калорий.
        // Возвращает кортеж с количеством граммов белков, жиров и углеводов.

        let proteinCalories = Int(Double(calories) * 0.25)
        // Вычисляем калории, выделенные на белки (25% от общего числа калорий).

        let fatCalories = Int(Double(calories) * 0.30)
        // Вычисляем калории, выделенные на жиры (30% от общего числа калорий).

        let carbCalories = calories - proteinCalories - fatCalories
        // Остаток калорий выделяем на углеводы.

        return (
            proteins: proteinCalories / 4,
            // Преобразуем калории, выделенные на белки, в граммы (1 г белка = 4 калории).

            fats: fatCalories / 9,
            // Преобразуем калории, выделенные на жиры, в граммы (1 г жира = 9 калорий).

            carbs: carbCalories / 4
            // Преобразуем калории, выделенные на углеводы, в граммы (1 г углеводов = 4 калории).
        )
    }
}

