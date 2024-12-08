//
//  MacrosCalculator.swift
//  FitLife
//
//  Created by Виктор Корольков on 08.12.2024.
//

import Foundation

// Макрос-калькулятор для расчёта калорий и распределения БЖУ (белки, жиры, углеводы)

struct MacrosCalculator {
    // Метод для расчёта калорий по формуле Миффлина-Сан Жеора
    static func calculateCaloriesMifflin(
        gender: Gender,
        weight: Double,
        height: Double,
        age: Int,
        activityLevel: ActivityLevel,
        goal: WeightGoal
    ) -> Int {
        // Метод принимает параметры:
        // - `gender`: Пол пользователя (мужчина или женщина).
        // - `weight`: Вес в килограммах.
        // - `height`: Рост в сантиметрах.
        // - `age`: Возраст в годах.
        // - `activityLevel`: Уровень физической активности.
        // - `goal`: Цель — снижение веса, сохранение текущего веса или набор массы.
        // Возвращает суточную норму калорий как целое число.

        let bmr: Double
        // Переменная для базового метаболизма (BMR).

        if gender == .male {
            // Если пол пользователя — мужской.
            bmr = 10 * weight + 6.25 * height - 5 * Double(age) + 5
            // Формула для расчёта BMR для мужчин:
            // 10 × вес (кг) + 6.25 × рост (см) − 5 × возраст (лет) + 5.
        } else {
            // Если пол пользователя — женский.
            bmr = 10 * weight + 6.25 * height - 5 * Double(age) - 161
            // Формула для расчёта BMR для женщин:
            // 10 × вес (кг) + 6.25 × рост (см) − 5 × возраст (лет) − 161.
        }

        let activityMultiplier: Double
        // Переменная для коэффициента физической активности.

        switch activityLevel {
        // Устанавливаем коэффициент в зависимости от уровня активности.
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

        let maintenanceCalories = bmr * activityMultiplier
        // Поддержание веса — это уровень калорий при данном BMR и активности.

        switch goal {
        case .loseWeight:
            return Int(maintenanceCalories * 0.8)
            // Снижение веса: уменьшаем калории на 20%.
        case .currentWeight:
            return Int(maintenanceCalories)
            // Сохранение веса: без изменений.
        case .gainWeight:
            return Int(maintenanceCalories * 1.2)
            // Набор веса: увеличиваем калории на 20%.
        }
    }

    // Метод для расчёта БЖУ
    static func calculateMacros(
        calories: Int,
        goal: WeightGoal
    ) -> (proteins: Int, fats: Int, carbs: Int) {
        // Метод принимает:
        // - `calories`: Общее количество калорий.
        // - `goal`: Цель — снижение веса, сохранение текущего веса или набор массы.
        // Возвращает кортеж с количеством граммов белков, жиров и углеводов.

        let proteinCalories: Int
        let fatCalories: Int
        let carbCalories: Int
        // Переменные для хранения калорий, выделенных на белки, жиры и углеводы.

        switch goal {
        case .loseWeight:
            proteinCalories = Int(Double(calories) * 0.35)
            // Для снижения веса: 35% калорий выделяется на белки.
            fatCalories = Int(Double(calories) * 0.25)
            // 25% калорий выделяется на жиры.
        case .currentWeight:
            proteinCalories = Int(Double(calories) * 0.25)
            // Для сохранения веса: 25% калорий выделяется на белки.
            fatCalories = Int(Double(calories) * 0.30)
            // 30% калорий выделяется на жиры.
        case .gainWeight:
            proteinCalories = Int(Double(calories) * 0.20)
            // Для набора веса: 20% калорий выделяется на белки.
            fatCalories = Int(Double(calories) * 0.35)
            // 35% калорий выделяется на жиры.
        }

        carbCalories = calories - proteinCalories - fatCalories
        // Оставшиеся калории выделяются на углеводы.

        return (
            proteins: proteinCalories / 4,
            // Переводим калории белков в граммы (1 г белка = 4 калории).
            fats: fatCalories / 9,
            // Переводим калории жиров в граммы (1 г жира = 9 калорий).
            carbs: carbCalories / 4
            // Переводим калории углеводов в граммы (1 г углеводов = 4 калории).
        )
    }
}

