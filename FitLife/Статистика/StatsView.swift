//
//  StatsView.swift
//  FitLife
//
//  Created by Виктор Корольков on 29.12.2024.
import SwiftUI
import Charts
import SwiftData

struct StatsView: View {
    @State private var selectedTimeFrame: TimeFrame = .week
    @State private var selectedDataType: DataType = .calories
    @Environment(\.modelContext) private var modelContext
    @Bindable var userData: UserData

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

                // Используем StatsChartView для отображения графика
                StatsChartView(
                    data: getData(for: selectedTimeFrame, selectedDataType: selectedDataType, modelContext: modelContext),
                    unit: .day,
                    chartHeight: 200
                )

                // Подпись к графику
                Text("График построен исходя из средних значений за выбранный период")
                    .font(.caption)
                    .foregroundStyle(.white)

                // Средние значения за день
                VStack {
                    Text("Среднее значение за день")
                        .font(.headline)
                        .foregroundStyle(.white)

                    switch selectedDataType {
                    case .calories:
                        Text("\(calculateAverageCalories(for: selectedTimeFrame)) ккал")
                            .font(.largeTitle)
                            .foregroundStyle(.white)
                    case .macros:
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
                    case .water:
                        Text(String(format: "%.2f л", calculateAverageWaterIntake(for: selectedTimeFrame)))
                            .font(.largeTitle)
                            .foregroundStyle(.blue)
                    case .weight:
                        Text(String(format: "%.1f кг", calculateAverageWeight(for: selectedTimeFrame)))
                            .font(.largeTitle)
                            .foregroundStyle(.gray)
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
    func getData(for timeFrame: TimeFrame, selectedDataType: DataType, modelContext: ModelContext) -> [ChartData] {
        let calendar = Calendar.current
        let today = Date()
        var data: [ChartData] = []

        // Получение диапазона дат
        let dateRanges = getDateRanges(for: timeFrame, calendar: calendar, today: today)

        for date in dateRanges {
            if selectedDataType == .macros {
                // Получение средних значений БЖУ за день
                let macros = calculateDailyMacros(for: date, modelContext: modelContext)
                data.append(contentsOf: [
                    ChartData(date: date, value: macros["proteins"] ?? 0, color: .purple, lineType: "Белки"),
                    ChartData(date: date, value: macros["fats"] ?? 0, color: .red, lineType: "Жиры"),
                    ChartData(date: date, value: macros["carbs"] ?? 0, color: .green, lineType: "Углеводы")
                ])
            } else {
                // Получение среднего значения за день
                let average = calculateDailyAverage(for: date, dataType: selectedDataType, modelContext: modelContext)
                data.append(ChartData(date: date, value: average, color: .blue, lineType: selectedDataType.rawValue))
            }
        }
        return data
    }

    // Функция для расчета среднего значения БЖУ за конкретный день
    func calculateDailyMacros(for date: Date, modelContext: ModelContext) -> [String: Double] {
        do {
            let foodEntries = try modelContext.fetch(FetchDescriptor<FoodEntry>())
            let filteredEntries = foodEntries.filter {
                Calendar.current.isDate($0.date, inSameDayAs: date)
            }

            let totalProteins = filteredEntries.reduce(0.0) { $0 + Double($1.product.protein) }
            let totalFats = filteredEntries.reduce(0.0) { $0 + Double($1.product.fat) }
            let totalCarbs = filteredEntries.reduce(0.0) { $0 + Double($1.product.carbs) }

            return [
                "proteins": totalProteins,
                "fats": totalFats,
                "carbs": totalCarbs
            ]
        } catch {
            print("Ошибка загрузки данных БЖУ: \(error)")
            return ["proteins": 0, "fats": 0, "carbs": 0]
        }
    }

    // Функция для расчета среднего значения (например, калорий, воды, веса) за конкретный день
    func calculateDailyAverage(for date: Date, dataType: DataType, modelContext: ModelContext) -> Double {
        do {
            switch dataType {
            case .calories:
                let foodEntries = try modelContext.fetch(FetchDescriptor<FoodEntry>())
                let filteredEntries = foodEntries.filter {
                    Calendar.current.isDate($0.date, inSameDayAs: date)
                }
                return filteredEntries.reduce(0.0) { $0 + Double($1.product.calories) }
            case .water:
                let waterEntries = try modelContext.fetch(FetchDescriptor<WaterIntake>())
                let filteredEntries = waterEntries.filter {
                    Calendar.current.isDate($0.date, inSameDayAs: date)
                }
                return filteredEntries.reduce(0.0) { $0 + $1.intake }
            case .weight:
                let weightEntries = try modelContext.fetch(FetchDescriptor<UserData>())
                let filteredEntries = weightEntries.filter {
                    Calendar.current.isDate($0.weightDate, inSameDayAs: date)
                }
                return filteredEntries.last?.weight ?? 0.0
            default:
                return 0.0
            }
        } catch {
            print("Ошибка загрузки данных: \(error)")
            return 0.0
        }
    }
    func getDateRanges(for timeFrame: TimeFrame, calendar: Calendar, today: Date) -> [Date] {
        switch timeFrame {
        case .week:
            guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else { return [] }
            return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
        case .month:
            guard let range = calendar.range(of: .day, in: .month, for: today) else { return [] }
            return range.compactMap { calendar.date(bySetting: .day, value: $0, of: today) }
        case .halfYear:
            return (-5...0).compactMap { calendar.date(byAdding: .month, value: $0, to: today) }
        case .year:
            return (-11...0).compactMap { calendar.date(byAdding: .month, value: $0, to: today) }
        }
    }

    func getAverage(for dataType: DataType, in timeFrame: TimeFrame, date: Date, modelContext: ModelContext) -> Double {
        switch dataType {
        case .calories:
            return Double(calculateAverageCalories(for: timeFrame))
        case .macros:
            let macros = calculateAverageMacros(for: timeFrame)
            return Double(macros["proteins"] ?? 0) // Например, возвращаем только белки
        case .water:
            return calculateAverageWaterIntake(for: timeFrame)
        case .weight:
            return calculateAverageWeight(for: timeFrame)
        }
    }    // Расчёт среднего значения калорий
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

    // Расчёт среднего значения выпитой воды
    func calculateAverageWaterIntake(for timeFrame: TimeFrame) -> Double {
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

        guard let startDate = startDate else { return 0.0 }

        do {
            let waterEntries = try modelContext.fetch(FetchDescriptor<WaterIntake>())
            let filteredEntries = waterEntries.filter {
                $0.date >= startDate && $0.date <= endDate
            }

            let totalWater = filteredEntries.reduce(into: 0.0) { $0 += $1.intake }
            let daysCount = calendar.dateComponents([.day], from: startDate, to: endDate).day! + 1
            return totalWater / Double(max(daysCount, 1))
        } catch {
            print("Ошибка загрузки данных воды: \(error)")
            return 0.0
        }
    }

    // Расчёт среднего значения веса
    func calculateAverageWeight(for timeFrame: TimeFrame) -> Double {
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

        guard let startDate = startDate else { return 0.0 }

        do {
            let predicate = #Predicate<UserData> { user in
                user.weight > 0
            }

            let fetchDescriptor = FetchDescriptor<UserData>(predicate: predicate)
            let weightEntries = try modelContext.fetch(fetchDescriptor)

            let filteredEntries = weightEntries.filter {
                $0.weightDate >= startDate && $0.weightDate <= endDate
            }

            let totalWeight = filteredEntries.reduce(into: 0.0) { $0 += $1.weight }
            let count = filteredEntries.count
            return totalWeight / Double(max(count, 1))
        } catch {
            print("Ошибка загрузки данных веса: \(error)")
            return 0.0
        }
    }
}

struct StatsChartView: View {
    let data: [ChartData]
    let unit: Calendar.Component
    let chartHeight: CGFloat

    var body: some View {
        VStack {
            // График с тремя линиями для БЖУ
            Chart {
                ForEach(data) { item in
                    LineMark(
                        x: .value("Дата", item.date, unit: unit),
                        y: .value("Значение", item.value),
                        series: .value("Тип", item.lineType)
                    )
                    .symbol(Circle())
                    .foregroundStyle(by: .value("Тип", item.lineType))
                }
            }
            .frame(height: chartHeight)
            .padding(.horizontal)

            // Легенда
            HStack {
                LegendItem(color: .purple, text: "Белки")
                LegendItem(color: .red, text: "Жиры")
                LegendItem(color: .green, text: "Углеводы")
            }
            .padding(.top, 10)
        }
    }

    // Компонент легенды
    private struct LegendItem: View {
        let color: Color
        let text: String

        var body: some View {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text(text)
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
    }
}


struct ChartData: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let color: Color
    let lineType: String // Тип линии (например, "Белки", "Жиры", "Углеводы")

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

extension UserData {
    var weightDate: Date {
        return Date()
    }
}
