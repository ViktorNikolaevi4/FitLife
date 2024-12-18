
import SwiftUI
import Foundation
import SwiftCSV

class ProductLoader: ObservableObject {
    @Published var products: [Product] = []

    init() {
        loadCSV()
    }

    func loadCSV() {
        guard let path = Bundle.main.url(forResource: "Продукты", withExtension: "csv") else {
            print("CSV file not found")
            return
        }

        do {
            let csv = try CSV<Named>(url: path)

            // Создаём словарь с очищенными заголовками для ключей
            var cleanedRows: [[String: String]] = []
            for row in csv.rows {
                var cleanedRow: [String: String] = [:]
                for (key, value) in row {
                    let cleanedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
                    let cleanedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    cleanedRow[cleanedKey] = cleanedValue
                }
                cleanedRows.append(cleanedRow)
            }

            // Обрабатываем очищенные строки
            for row in cleanedRows {
                let cleanedName = row["Продукты"] ?? "Неизвестно"
                let cleanedProtein = row["Белки"] ?? "Неизвестно"
                let cleanedFat = row["Жиры"] ?? "Неизвестно"
                let cleanedCarbs = row["Углеводы"] ?? "Неизвестно"
                let cleanedCalories = row["Калории"] ?? "Неизвестно"

                if let protein = Double(cleanedProtein),
                   let fat = Double(cleanedFat),
                   let carbs = Double(cleanedCarbs),
                   let calories = Int(cleanedCalories) {
                    let product = Product(
                        name: cleanedName,
                        protein: protein,
                        fat: fat,
                        carbs: carbs,
                        calories: calories
                    )
                    self.products.append(product)
                }
            }
        } catch {
            print("Error parsing CSV: \(error)")
        }
    }
}
