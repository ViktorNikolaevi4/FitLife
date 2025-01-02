//
//  MenuView.swift
//  FitLife
//
//  Created by Виктор Корольков on 01.01.2025.
//
import SwiftUI

struct MenuView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                GradientView()
                    .ignoresSafeArea()
                VStack {
                    Text("Выберите")
                        .foregroundStyle(.white)
                        .font(.title)

                    Text("Программу питания")
                        .foregroundStyle(.white)
                        .font(.title)
                        .padding()

                    // RoundedTextView с переходами
                    NavigationLink(destination: WeekView(calories: "1300 Ккалорий", dailyTexts: uniqueTextsFor1300)) {
                        RoundedTextView(text: "1300 Ккалорий")
                    }
                    NavigationLink(destination: WeekView(calories: "1700 Ккалорий", dailyTexts: uniqueTextsFor1700)) {
                        RoundedTextView(text: "1700 Ккалорий")
                    }
                    NavigationLink(destination: WeekView(calories: "2100 Ккалорий", dailyTexts: uniqueTextsFor2100)) {
                        RoundedTextView(text: "2100 Ккалорий")
                    }

                    Spacer()
                }
            }
        }
    }
}

// Представление с днями недели
struct WeekView: View {
    var calories: String // Количество калорий для отображения
    var dailyTexts: [String: String] // Уникальные тексты для каждого дня недели

    var body: some View {
        List {
            Section(header: Text("\(calories) - Дни недели").font(.headline)) {
                ForEach(["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"], id: \.self) { day in
                    NavigationLink(destination: DetailView(day: day, text: dailyTexts[day] ?? "Нет данных")) {
                        Text(day)
                            .padding()
                    }
                }
            }
        }
        .navigationTitle("Дни недели")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Детальное представление для каждого дня
struct DetailView: View {
    var day: String
    var text: String

    var body: some View {
        VStack {
            Text(day)
                .font(.largeTitle)
                .padding()

            Text(text)
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding()

            Spacer()
        }
        .navigationTitle(day)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Уникальные тексты для каждого варианта калорий
let uniqueTextsFor1300 = [
    "Понедельник": "1300 Ккалорий - Понедельник. Завтрак: каша.",
    "Вторник": "1300 Ккалорий - Вторник. Обед: салат.",
    "Среда": "1300 Ккалорий - Среда. Ужин: овощи.",
    "Четверг": "1300 Ккалорий - Четверг. Рыба.",
    "Пятница": "1300 Ккалорий - Пятница. Омлет.",
    "Суббота": "1300 Ккалорий - Суббота. Паста.",
    "Воскресенье": "1300 Ккалорий - Воскресенье. Курица."
]

let uniqueTextsFor1700 = [
    "Понедельник": "1700 Ккалорий - Понедельник. Завтрак: овсянка.",
    "Вторник": "1700 Ккалорий - Вторник. Обед: суп.",
    "Среда": "1700 Ккалорий - Среда. Ужин: стейк.",
    "Четверг": "1700 Ккалорий - Четверг. Плов.",
    "Пятница": "1700 Ккалорий - Пятница. Шашлык.",
    "Суббота": "1700 Ккалорий - Суббота. Салат.",
    "Воскресенье": "1700 Ккалорий - Воскресенье. Котлеты."
]

let uniqueTextsFor2100 = [
    "Понедельник": "2100 Ккалорий - Понедельник. Завтрак: тосты.",
    "Вторник": "2100 Ккалорий - Вторник. Обед: паста.",
    "Среда": "2100 Ккалорий - Среда. Ужин: бургер.",
    "Четверг": "2100 Ккалорий - Четверг. Лазанья.",
    "Пятница": "2100 Ккалорий - Пятница. Рис.",
    "Суббота": "2100 Ккалорий - Суббота. Гречка.",
    "Воскресенье": "2100 Ккалорий - Воскресенье. Борщ."
]

#Preview {
    MenuView()
}
