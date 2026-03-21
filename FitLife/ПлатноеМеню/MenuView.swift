//
//  MenuView.swift
//  FitLife
//
//  Created by Виктор Корольков on 01.01.2025.
//
// MenuView.swift
import SwiftUI

struct MenuView: View {
    @Environment(\.dismiss) private var dismiss

    private let weekDays = [
        ("Понедельник", "weekday.monday"),
        ("Вторник", "weekday.tuesday"),
        ("Среда", "weekday.wednesday"),
        ("Четверг", "weekday.thursday"),
        ("Пятница", "weekday.friday"),
        ("Суббота", "weekday.saturday"),
        ("Воскресенье", "weekday.sunday")
    ]

    var body: some View {
        ZStack {
            GradientView().ignoresSafeArea()
            VStack {
                Text(AppLocalizer.string("menu.choose")).foregroundStyle(.white).font(.title)
                Text(AppLocalizer.string("menu.program")).foregroundStyle(.white).font(.title).padding()

                NavigationLink(destination: WeekView(calories: AppLocalizer.format("menu.plan.kcal", 1300), dailyTexts: uniqueTextsFor1300)) {
                    RoundedTextView(text: AppLocalizer.format("menu.plan.kcal", 1300))
                }
                NavigationLink(destination: WeekView(calories: AppLocalizer.format("menu.plan.kcal", 1700), dailyTexts: uniqueTextsFor1700)) {
                    RoundedTextView(text: AppLocalizer.format("menu.plan.kcal", 1700))
                }
                NavigationLink(destination: WeekView(calories: AppLocalizer.format("menu.plan.kcal", 2100), dailyTexts: uniqueTextsFor2100)) {
                    RoundedTextView(text: AppLocalizer.format("menu.plan.kcal", 2100))
                }

                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)         // прячем «Back»
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                }
                .tint(.white)                         // цвет стрелки
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar) // градиент под навбаром
    }
}


// WeekView — список дней
struct WeekView: View {
    @Environment(\.dismiss) private var dismiss
    var calories: String
    var dailyTexts: [String: String]

    private let weekDays = [
        ("Понедельник", "weekday.monday"),
        ("Вторник", "weekday.tuesday"),
        ("Среда", "weekday.wednesday"),
        ("Четверг", "weekday.thursday"),
        ("Пятница", "weekday.friday"),
        ("Суббота", "weekday.saturday"),
        ("Воскресенье", "weekday.sunday")
    ]

    var body: some View {
        ZStack {
            GradientView().ignoresSafeArea()
            VStack {
                List {
                    Section(header: Text("\(calories)").font(.headline)) {
                        ForEach(weekDays, id: \.0) { day in
                            NavigationLink(destination: DetailView(day: AppLocalizer.string(day.1), text: dailyTexts[day.0] ?? AppLocalizer.string("data.not_found"))) {
                                Text(AppLocalizer.string(day.1)).padding()
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden) // чтобы фон списка не был белым
            }
        }
        .navigationTitle(AppLocalizer.string("menu.weekdays"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                }
                .tint(.white)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}


// DetailView — экран дня
struct DetailView: View {
    @Environment(\.dismiss) private var dismiss
    var day: String
    var text: String

    var body: some View {
        ZStack {
            GradientView().ignoresSafeArea()
            VStack {
                Text(day).font(.largeTitle).padding()
                Text(text).font(.title2).multilineTextAlignment(.center).padding()
                Spacer()
            }
        }
        .navigationTitle(day)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                }
                .tint(.white) // любой цвет
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}


// Уникальные тексты для каждого варианта калорий
let uniqueTextsFor1300 = [
    "Понедельник": "1300 Ккалорий.\n\nЗавтрак:\nБелковый блин с творогом.\nОбед:\nКрем суп из брокколи\n(250 грамм)\nСтейк из говядины с гречей\n(250 грамм).\nУжин:\nКамбалла с овощным салатом\n(400 грамм).",
    "Вторник": "1300 Ккалорий.\n\nЗавтрак:\nОмлет с зелеными овощами\n(150 грамм).\nОбед:\nКуриные рулеты с рисом\n(300 грамм).\nУжин:\nФиле трески с булгуром\n(250 грамм).",
    "Среда": "1300 Ккалорий.\n\nЗавтрак:\nКаша геркулесовая с бананом\n(200 грамм).\nОбед:\nКотлеты из индейки с фетучини\n(250 грамм).\nУжин:\nКальмары отварные с овощами\n(350 грамм).",
    "Четверг": "1300 Ккалорий.\n\nЗавтрак:\nТворожные маффины\n(150 грамм).\nОбед:\nСуп пюре из зеленого горошка с шампиньонами\n(200 грамм)\nКуриные котлеты с овощами и булгуром\n(450 грамм).\nУжин:\nЗеленый салат с тунцом\n(300 грамм).",
    "Пятница": "1300 Ккалорий.\n\nЗавтрак:\nГречневая каша с семенами льна\n(200 грамм).\nОбед:\nФиле трески с пенне с соусом песто\n(350 грамм).\nУжин:\nСалат из кальмара, огурцов и редиса\n(300 грамм).",
    "Суббота": "1300 Ккалорий.\n\nЗавтрак:\nОмлет с томатами и моцареллой\n(250 грамм).\nОбед:\nФиле горбуши с грибами и свежим салатом\n(200 грамм).\nУжин:\nРагу из индейки с баклажанами и болгарским перцем\n(250 грамм).",
    "Воскресенье": "1300 Ккалорий.\n\nЗавтрак:\nОвсяные панкейки с джемом\n(300 грамм).\nОбед:\nКотлеты из куры с ризотто и тыквой\n(350 грамм).\nУжин:\nТворожная запеканка с черносливом\n(300 грамм)."
]


let uniqueTextsFor1700 = [
    "Понедельник": "1700 Ккалорий.\n\nЗавтрак:\nОмлет с томатами\n(400 грамм).\nОбед:\nКрем суп из чечевицы с зеленью\n(250 грамм)\nКотлета из лосося с гречей\n(300 грамм).\nУжин:\nКальмары отварные с овощами\n(400 грамм).",
    "Вторник": "1700 Ккалорий.\n\nЗавтрак:\nОвсянная каша с бананом\n(400 грамм).\nОбед:\nКуриные котлеты с булгуром\n(450 грамм).\nУжин:\nТворожная запеканка с черносливом\n(300 грамм).\nПерекусы:\nОвсяное печенье.",
    "Среда": "1700 Ккалорий.\n\nЗавтрак:\nБелковые блины с творогом и бананом\n(200 грамм).\nОбед:\nКуриный бульон с яйцом и гренками\n(250 грамм)\nКотлета из телятины с пенне\n(300 грамм).\nУжин:\nСалат из свеклы с сыром и грецким орехом\n(350 грамм).",
    "Четверг": "1700 Ккалорий.\n\nЗавтрак:\nТворожные маффины\n(150 грамм).\nОбед:\nФиле трески с пенне с соусом песто\n(500 грамм).\nУжин:\nЗапеканка из овсянки с яблоком\n(200 грамм).\nПерекусы:\nФруктовый смузи.",
    "Пятница": "1700 Ккалорий.\n\nЗавтрак:\nОмлет с зелеными овощами\n(200 грамм).\nОбед:\nКуриные рулеты с зеленью, орехами и гречей\n(500 грамм).\nУжин:\nРисовая запеканка с яблоком\n(300 грамм).\nПерекусы:\nОвсяные оладьи.",
    "Суббота": "1700 Ккалорий.\n\nЗавтрак:\nГречневая каша с семенами льна\n(200 грамм).\nОбед:\nСтейк из говядины\n(100 грамм).\nСалат Свежий\n(300 грамм).\nУжин:\nЗапеканка из овсянки с яблоком\n(200 грамм).",
    "Воскресенье": "1700 Ккалорий.\n\nЗавтрак:\nОвсяные панкейки с джемом\n(300 грамм).\nОбед:\nФиле горбуши с грибами и свежими овощами\n(200 грамм).\nУжин:\nЗеленый салат с тунцом и булгуромм\n(550 грамм).\nПерекусы:\nФруктовый смузи."
]

let uniqueTextsFor2100 = [
    "Понедельник": "2100 Ккалорий.\n\nЗавтрак:\nОвсяная каша с яблоком и вишней\n(650 грамм).\nОбед:\nКуриное филе с соусом терияки и гречей\n(500 грамм).\nУжин:\nЗеленый салат с тунцом\n(600 грамм).\nПерекусы:\nЧизбургер с куриной котлетой",
    "Вторник": "2100 Ккалорий.\n\nЗавтрак:\nГречневая каша с семенами льна\n(400 грамм).\nОбед:\nФиле трески с пенне с соусом песто\n(450 грамм).\nУжин:\nКАльмары отварные\n(400 грамм).\nПерекусы:\nОвсяное печенье.",
    "Среда": "2100 Ккалорий.\n\nЗавтрак:\nТворожные маффины\n(200 грамм).\nОбед:\nКотлеты из телятины с фетучини\n(500 грамм).\nУжин:\nЗапеканка из овсянки с яблоком\n(300 грамм).\nОвсяное печенье.",
    "Четверг": "2100 Ккалорий.\n\nЗавтрак:\nОвсяные панкейки с джемом\n(300 грамм).\nОбед:\nСуп пюро из зеленого горошка с шампиньонами\n(200 грамм)\nКуриные котлеты с овощами и булгуром\n(600 грамм).\nУжин:\nРисовая запеканка с яблоком\n(500 грамм).",
    "Пятница": "2100 Ккалорий.\n\nЗавтрак:\nБелковые блины с творогм и бананом\n(800 грамм).\nОбед:\nКотлета из лосося и гречей\n(350 грамм).\nУжин:\nСтейк из говядины с вермишелью\n(350 грамм).\nПерекусы:\nРизотто с шампиньонами.",
    "Суббота": "2100 Ккалорий.\n\nЗавтрак:\nОмлет с томатами и моцареллой\n(250 грамм).\nОбед:\nКуриные рулеты с зеленью, орехами и булгуром\n(500 грамм).\nУжин:\nСалат из морепродуктов\n(500 грамм).\nЧизбургеры с куриной котлетой.",
    "Воскресенье": "2100 Ккалорий.\n\nЗавтрак:\nТворожные маффины\n(200 грамм).\nОбед:\nФиле трески с пенне с соусом песто\n(450 грамм).\nУжин:\nКуриные котлеты с овощами и булгуромм\n(450 грамм).\nПерекусы:\nФруктовый смузи."
]

#Preview {
    MenuView()
}
