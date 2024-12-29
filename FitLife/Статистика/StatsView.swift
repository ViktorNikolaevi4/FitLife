//
//  StatsView.swift
//  FitLife
//
//  Created by Виктор Корольков on 29.12.2024.
import SwiftUI
import Charts
import SwiftData

struct StatsView: View {
    @State private var selectedTimeFrame: TimeFrame = .year
    @State private var selectedDataType: DataType = .calories
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            GradientView()
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Заголовок
                HStack {
                    Spacer()
                    Text("Статистика")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Spacer()
                }

                // Пикер интервалов времени
                Picker("Выберите интервал", selection: $selectedTimeFrame) {
                    ForEach(TimeFrame.allCases, id: \.self) { timeFrame in
                        Text(timeFrame.rawValue).tag(timeFrame)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Линейный график
                Chart(getData(for: selectedTimeFrame)) { item in
                    LineMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Value", item.value)
                    )
                    .symbol(Circle())
                    .foregroundStyle(item.color)
                }
                .frame(height: 200)
                .padding(.horizontal)

                // Подпись к графику
                Text("График построен исходя из средних значений за выбранный период")
                    .font(.caption)
                    .foregroundStyle(.white)

                // Средние значения за день
                VStack {
                    Text("Среднее значение за день")
                        .font(.headline)
                        .foregroundStyle(.white)

                    if selectedDataType == .calories {
                        Text("\(calculateAverageCalories(for: selectedTimeFrame)) ккал")
                            .font(.largeTitle)
                            .foregroundStyle(.white)
                    } else if selectedDataType == .macros {
                        let averageMacros = calculateAverageMacros(for: selectedTimeFrame)
                        Text("Белки: \(averageMacros["proteins"] ?? 0) г")
                            .font(.headline)
                            .foregroundStyle(.purple)
                        Text("Жиры: \(averageMacros["fats"] ?? 0) г")
                            .font(.headline)
                            .foregroundStyle(.red)
                        Text("Углеводы: \(averageMacros["carbs"] ?? 0) г")
                            .font(.headline)
                            .foregroundStyle(.green)
                    }
                }

                Spacer()

                // Пикер типа данных (Ккал, БЖУ, Вес, Вода)
                Picker("Выберите тип данных", selection: $selectedDataType) {
                    ForEach(DataType.allCases, id: \.self) { dataType in
                        Text(dataType.rawValue).tag(dataType)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
            }
            .padding()
        }
    }

    // Получение данных для графика
    func getData(for timeFrame: TimeFrame) -> [ChartData] {
        let calendar = Calendar.current
        let today = Date()
        var data: [ChartData] = []

        switch timeFrame {
        case .week:
            if let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) {
                for dayOffset in 0..<7 {
                    if let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek) {
                        data.append(ChartData(date: date, value: Double.random(in: 100...500), color: .blue))
                    }
                }
            }
        case .month:
            if let range = calendar.range(of: .day, in: .month, for: today) {
                for day in range {
                    if let date = calendar.date(bySetting: .day, value: day, of: today) {
                        data.append(ChartData(date: date, value: Double.random(in: 100...500), color: .blue))
                    }
                }
            }
        case .halfYear:
            for monthOffset in -5...0 {
                if let date = calendar.date(byAdding: .month, value: monthOffset, to: today) {
                    data.append(ChartData(date: date, value: Double.random(in: 100...500), color: .blue))
                }
            }
        case .year:
            for monthOffset in -11...0 {
                if let date = calendar.date(byAdding: .month, value: monthOffset, to: today) {
                    data.append(ChartData(date: date, value: Double.random(in: 100...500), color: .blue))
                }
            }
        }
        return data
    }
    // Расчёт среднего значения калорий
    func calculateAverageCalories(for timeFrame: TimeFrame) -> Int {
        let calendar = Calendar.current
        let today = Date()
        var startDate: Date?
        let endDate: Date = today

        switch timeFrame {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -6, to: today)
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: today)
        case .halfYear:
            startDate = calendar.date(byAdding: .month, value: -6, to: today)
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: today)
        }

        guard let startDate = startDate else { return 0 }

        do {
            let foodEntries = try modelContext.fetch(FetchDescriptor<FoodEntry>())
            let filteredEntries = foodEntries.filter {
                $0.date >= startDate && $0.date <= endDate
            }

            let totalCalories = filteredEntries.reduce(into: 0) { $0 += $1.product.calories }
            let daysCount = calendar.dateComponents([.day], from: startDate, to: endDate).day! + 1
            return totalCalories / max(daysCount, 1)
        } catch {
            print("Ошибка загрузки данных: \(error)")
            return 0
        }
    }
    // Расчёт среднего значения БЖУ
    func calculateAverageMacros(for timeFrame: TimeFrame) -> [String: Int] {
        let calendar = Calendar.current
        let today = Date()
        var startDate: Date?
        let endDate: Date = today

        switch timeFrame {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -6, to: today)
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: today)
        case .halfYear:
            startDate = calendar.date(byAdding: .month, value: -6, to: today)
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: today)
        }

        guard let startDate = startDate else { return [:] }

        do {
            let foodEntries = try modelContext.fetch(FetchDescriptor<FoodEntry>())
            let filteredEntries = foodEntries.filter {
                $0.date >= startDate && $0.date <= endDate
            }

            let totalProteins = filteredEntries.reduce(into: 0) { $0 += $1.product.protein }
            let totalFats = filteredEntries.reduce(into: 0) { $0 += $1.product.fat }
            let totalCarbs = filteredEntries.reduce(into: 0) { $0 += $1.product.carbs }
            let daysCount = calendar.dateComponents([.day], from: startDate, to: endDate).day! + 1

            return [
                "proteins": Int(totalProteins) / max(daysCount, 1),
                "fats": Int(totalFats) / max(daysCount, 1),
                "carbs": Int(totalCarbs) / max(daysCount, 1)
            ]
        } catch {
            print("Ошибка загрузки данных: \(error)")
            return [:]
        }
    }
}

struct ChartData: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let color: Color
}

enum TimeFrame: String, CaseIterable {
    case week = "Неделя"
    case month = "Месяц"
    case halfYear = "Полгода"
    case year = "Год"
}

enum DataType: String, CaseIterable {
    case calories = "Ккал"
    case macros = "БЖУ"
    case weight = "Вес"
    case water = "Вода"
}

#Preview {
    StatsView()
}
