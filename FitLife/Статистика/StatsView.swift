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
                    data: getData(for: selectedTimeFrame),
                  //  title: "График построен исходя из средних значений за выбранный период",
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
                        Text("\(calculateAverageWaterIntake(for: selectedTimeFrame), specifier: "%.2f") л")
                            .font(.largeTitle)
                            .foregroundStyle(.blue)
                    case .weight:
                        Text("\(calculateAverageWeight(for: selectedTimeFrame), specifier: "%.1f") кг")
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
            // Создаём предикат для фильтрации данных
            let predicate = #Predicate<UserData> { user in
                user.weight > 0 // Проверяем, что вес указан корректно
            }

            // Используем FetchDescriptor с предикатом
            let fetchDescriptor = FetchDescriptor<UserData>(predicate: predicate)

            // Выполняем запрос
            let weightEntries = try modelContext.fetch(fetchDescriptor)

            // Фильтруем данные по дате вручную
            let filteredEntries = weightEntries.filter {
                ($0.weightDate) >= startDate && ($0.weightDate) <= endDate
            }

            // Вычисляем средний вес
            let totalWeight = filteredEntries.reduce(into: 0.0) { $0 += $1.weight }
            let count = filteredEntries.count
            return totalWeight / Double(max(count, 1)) // Возвращаем средний вес
        } catch {
            print("Ошибка загрузки данных веса: \(error)")
            return 0.0
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
extension UserData {
    /// Дата последнего изменения веса пользователя
    var weightDate: Date {
        // Если нужно хранить дату в базе данных, нужно добавить `storedWeightDate` как свойство модели.
        // Здесь для примера просто возвращаем текущую дату.
        // Для баз данных стоит заменить на реальное значение.
        return Date() // Верните реальную дату изменения веса, если она хранится
    }
}
#Preview {
    StatsView()
}
