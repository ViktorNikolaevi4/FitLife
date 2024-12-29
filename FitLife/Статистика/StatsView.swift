//
//  StatsView.swift
//  FitLife
//
//  Created by Виктор Корольков on 29.12.2024.
//

import SwiftUI
import Charts

struct StatsView: View {
    @State private var selectedTimeFrame: TimeFrame = .year
    @State private var selectedDataType: DataType = .macros

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
                Spacer()
                // Пикер интервалов времени
                Picker("Выберите интервал", selection: $selectedTimeFrame) {
                    ForEach(TimeFrame.allCases, id: \.self) { timeFrame in
                        Text(timeFrame.rawValue).tag(timeFrame)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                Spacer()
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
                Spacer()
                // Средние значения за день
                Text("Среднее значение за день")
                    .font(.headline)
                    .foregroundStyle(.white)
                HStack {
                    VStack {
                        Text("Белки, г")
                            .font(.subheadline)
                            .foregroundStyle(.purple)
                        Text("17.8")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    VStack {
                        Text("Жиры, г")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                        Text("7.8")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    VStack {
                        Text("Углеводы, г")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                        Text("69.4")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal)

                // Пикер типа данных
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
            } else {
                for day in 1..<31 { // Здесь используется Range вместо ClosedRange
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
}

// Вспомогательные модели данных
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

struct ChartData: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let color: Color
}

#Preview {
    StatsView()
}
