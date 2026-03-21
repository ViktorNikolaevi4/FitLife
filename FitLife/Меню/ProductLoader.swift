
import SwiftUI
import Foundation
import SwiftCSV

@Observable
class ProductLoader {
     var products: [Product] = []

    init() {
        loadCSV()
    }

    func loadCSV() {
        let bundle = Bundle.main
        let path =
            bundle.url(forResource: "Products_template_en", withExtension: "csv") ??
            bundle.url(forResource: "Продукты", withExtension: "csv")

        guard let path else { return }

        do {
            let csv = try CSV<Named>(url: path)
            products.removeAll()

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
                let cleanedName = row["Name_RU"] ?? row["Продукты"] ?? "Неизвестно"
                let cleanedEnglishName = row["Name_EN"]
                let cleanedProtein = row["Protein"] ?? row["Белки"] ?? "Неизвестно"
                let cleanedFat = row["Fat"] ?? row["Жиры"] ?? "Неизвестно"
                let cleanedCarbs = row["Carbs"] ?? row["Углеводы"] ?? "Неизвестно"
                let cleanedCalories = row["Calories"] ?? row["Калории"] ?? "Неизвестно"

                if let protein = Double(cleanedProtein),
                   let fat = Double(cleanedFat),
                   let carbs = Double(cleanedCarbs),
                   let calories = Int(cleanedCalories) {
                    let product = Product(
                        name: cleanedName,
                        nameEN: cleanedEnglishName?.isEmpty == false ? cleanedEnglishName : nil,
                        protein: protein,
                        fat: fat,
                        carbs: carbs,
                        calories: calories
                    )
                    self.products.append(product)
                }
            }
        } catch {}
    }
}
