//
//import SwiftUI
//import Charts
//import SwiftData
//
//struct StatsChartView: View {
//    let data: [ChartData]
//    //   let title: String
//    let unit: Calendar.Component
//    let chartHeight: CGFloat
//
//    @Environment(\.modelContext) private var modelContext
//
//    var body: some View {
//        VStack {
//            Chart(data) { item in
//                LineMark(
//                    x: .value("Date", item.date, unit: unit),
//                    y: .value("Value", item.value)
//                )
//                .symbol(Circle())
//                .foregroundStyle(item.color)
//            }
//            .frame(height: chartHeight)
//            .padding(.horizontal)
//            
//            //            // Подпись к графику
//            //            Text(title)
//            //                .font(.caption)
//            //                .foregroundStyle(.white)
//        }
//    }
//    
//    // Получение данных для графика
//
//    func getAverage(for dataType: DataType, in timeFrame: TimeFrame, date: Date, modelContext: ModelContext) -> Double {
//        switch dataType {
//        case .calories:
//            return Double(calculateAverageCalories(for: timeFrame))
//        case .macros:
//            let macros = calculateAverageMacros(for: timeFrame)
//            return Double(macros["proteins"] ?? 0) // Например, возвращаем только белки
//        case .water:
//            return calculateAverageWaterIntake(for: timeFrame)
//        case .weight:
//            return calculateAverageWeight(for: timeFrame)
//        }
//    }
//    // Расчёт среднего значения калорий
//    func calculateAverageCalories(for timeFrame: TimeFrame) -> Int {
//        let calendar = Calendar.current
//        let today = Date()
//        var startDate: Date?
//        let endDate: Date = today
//        
//        switch timeFrame {
//        case .week:
//            startDate = calendar.date(byAdding: .day, value: -6, to: today)
//        case .month:
//            startDate = calendar.date(byAdding: .month, value: -1, to: today)
//        case .halfYear:
//            startDate = calendar.date(byAdding: .month, value: -6, to: today)
//        case .year:
//            startDate = calendar.date(byAdding: .year, value: -1, to: today)
//        }
//        
//        guard let startDate = startDate else { return 0 }
//        
//        do {
//            let foodEntries = try modelContext.fetch(FetchDescriptor<FoodEntry>())
//            let filteredEntries = foodEntries.filter {
//                $0.date >= startDate && $0.date <= endDate
//            }
//            
//            let totalCalories = filteredEntries.reduce(into: 0) { $0 += $1.product.calories }
//            let daysCount = calendar.dateComponents([.day], from: startDate, to: endDate).day! + 1
//            return totalCalories / max(daysCount, 1)
//        } catch {
//            print("Ошибка загрузки данных: \(error)")
//            return 0
//        }
//    }
//    // Расчёт среднего значения БЖУ
//    func calculateAverageMacros(for timeFrame: TimeFrame) -> [String: Int] {
//        let calendar = Calendar.current
//        let today = Date()
//        var startDate: Date?
//        let endDate: Date = today
//        
//        switch timeFrame {
//        case .week:
//            startDate = calendar.date(byAdding: .day, value: -6, to: today)
//        case .month:
//            startDate = calendar.date(byAdding: .month, value: -1, to: today)
//        case .halfYear:
//            startDate = calendar.date(byAdding: .month, value: -6, to: today)
//        case .year:
//            startDate = calendar.date(byAdding: .year, value: -1, to: today)
//        }
//        
//        guard let startDate = startDate else { return [:] }
//        
//        do {
//            let foodEntries = try modelContext.fetch(FetchDescriptor<FoodEntry>())
//            let filteredEntries = foodEntries.filter {
//                $0.date >= startDate && $0.date <= endDate
//            }
//            
//            let totalProteins = filteredEntries.reduce(into: 0) { $0 += $1.product.protein }
//            let totalFats = filteredEntries.reduce(into: 0) { $0 += $1.product.fat }
//            let totalCarbs = filteredEntries.reduce(into: 0) { $0 += $1.product.carbs }
//            let daysCount = calendar.dateComponents([.day], from: startDate, to: endDate).day! + 1
//            
//            return [
//                "proteins": Int(totalProteins) / max(daysCount, 1),
//                "fats": Int(totalFats) / max(daysCount, 1),
//                "carbs": Int(totalCarbs) / max(daysCount, 1)
//            ]
//        } catch {
//            print("Ошибка загрузки данных: \(error)")
//            return [:]
//        }
//    }
//    // Расчёт среднего значения выпитой воды
//    func calculateAverageWaterIntake(for timeFrame: TimeFrame) -> Double {
//        let calendar = Calendar.current
//        let today = Date()
//        var startDate: Date?
//        let endDate: Date = today
//        
//        switch timeFrame {
//        case .week:
//            startDate = calendar.date(byAdding: .day, value: -6, to: today)
//        case .month:
//            startDate = calendar.date(byAdding: .month, value: -1, to: today)
//        case .halfYear:
//            startDate = calendar.date(byAdding: .month, value: -6, to: today)
//        case .year:
//            startDate = calendar.date(byAdding: .year, value: -1, to: today)
//        }
//        
//        guard let startDate = startDate else { return 0.0 }
//        
//        do {
//            let waterEntries = try modelContext.fetch(FetchDescriptor<WaterIntake>())
//            let filteredEntries = waterEntries.filter {
//                $0.date >= startDate && $0.date <= endDate
//            }
//            
//            let totalWater = filteredEntries.reduce(into: 0.0) { $0 += $1.intake }
//            let daysCount = calendar.dateComponents([.day], from: startDate, to: endDate).day! + 1
//            return totalWater / Double(max(daysCount, 1))
//        } catch {
//            print("Ошибка загрузки данных воды: \(error)")
//            return 0.0
//        }
//    }
//    
//    // Расчёт среднего значения веса
//    func calculateAverageWeight(for timeFrame: TimeFrame) -> Double {
//        let calendar = Calendar.current
//        let today = Date()
//        var startDate: Date?
//        let endDate: Date = today
//        
//        switch timeFrame {
//        case .week:
//            startDate = calendar.date(byAdding: .day, value: -6, to: today)
//        case .month:
//            startDate = calendar.date(byAdding: .month, value: -1, to: today)
//        case .halfYear:
//            startDate = calendar.date(byAdding: .month, value: -6, to: today)
//        case .year:
//            startDate = calendar.date(byAdding: .year, value: -1, to: today)
//        }
//        
//        guard let startDate = startDate else { return 0.0 }
//        
//        do {
//            // Создаём предикат для фильтрации данных
//            let predicate = #Predicate<UserData> { user in
//                user.weight > 0 // Проверяем, что вес указан корректно
//            }
//            
//            // Используем FetchDescriptor с предикатом
//            let fetchDescriptor = FetchDescriptor<UserData>(predicate: predicate)
//            
//            // Выполняем запрос
//            let weightEntries = try modelContext.fetch(fetchDescriptor)
//            
//            // Фильтруем данные по дате вручную
//            let filteredEntries = weightEntries.filter {
//                ($0.weightDate) >= startDate && ($0.weightDate) <= endDate
//            }
//            
//            // Вычисляем средний вес
//            let totalWeight = filteredEntries.reduce(into: 0.0) { $0 += $1.weight }
//            let count = filteredEntries.count
//            return totalWeight / Double(max(count, 1)) // Возвращаем средний вес
//        } catch {
//            print("Ошибка загрузки данных веса: \(error)")
//            return 0.0
//        }
//    }
//}
