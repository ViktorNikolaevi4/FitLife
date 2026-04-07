import SwiftUI
import Foundation
import SwiftCSV

struct ProductCatalogRow: Sendable {
    let name: String
    let nameEN: String?
    let protein: Double
    let fat: Double
    let carbs: Double
    let calories: Int
}

actor ProductCatalogCache {
    static let shared = ProductCatalogCache()

    private var cachedRows: [ProductCatalogRow]?
    private var loadingTask: Task<[ProductCatalogRow], Never>?

    func rows() async -> [ProductCatalogRow] {
        if let cachedRows {
            return cachedRows
        }

        if let loadingTask {
            return await loadingTask.value
        }

        let task = Task { ProductCatalogStore.loadRowsFromCSV() }
        loadingTask = task

        let rows = await task.value
        cachedRows = rows
        loadingTask = nil
        return rows
    }
}

@MainActor
final class ProductCatalogStore: ObservableObject {
    @Published var products: [Product] = []
    @Published private(set) var isLoaded = false

    private var preloadTask: Task<Void, Never>?

    init() {
        preloadIfNeeded()
    }

    func preloadIfNeeded() {
        guard !isLoaded, preloadTask == nil else { return }

        preloadTask = Task { [weak self] in
            let rows = await ProductCatalogCache.shared.rows()
            guard let self, !Task.isCancelled else { return }

            self.products = rows.map {
                Product(
                    name: $0.name,
                    nameEN: $0.nameEN,
                    protein: $0.protein,
                    fat: $0.fat,
                    carbs: $0.carbs,
                    calories: $0.calories
                )
            }
            self.isLoaded = true
            self.preloadTask = nil
        }
    }

    nonisolated static func loadRowsFromCSV() -> [ProductCatalogRow] {
        let bundle = Bundle.main
        let path =
            bundle.url(forResource: "Products_template_en", withExtension: "csv") ??
            bundle.url(forResource: "Продукты", withExtension: "csv")

        guard let path else { return [] }

        do {
            let csv = try CSV<Named>(url: path)
            var rows: [ProductCatalogRow] = []
            rows.reserveCapacity(csv.rows.count)

            for row in csv.rows {
                let name = (row["Name_RU"] ?? row["Продукты"] ?? "Неизвестно")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let nameEN = row["Name_EN"]?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let proteinText = (row["Protein"] ?? row["Белки"] ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let fatText = (row["Fat"] ?? row["Жиры"] ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let carbsText = (row["Carbs"] ?? row["Углеводы"] ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let caloriesText = (row["Calories"] ?? row["Калории"] ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if let protein = Double(proteinText),
                   let fat = Double(fatText),
                   let carbs = Double(carbsText),
                   let calories = Int(caloriesText) {
                    rows.append(
                        ProductCatalogRow(
                            name: name,
                            nameEN: nameEN?.isEmpty == false ? nameEN : nil,
                            protein: protein,
                            fat: fat,
                            carbs: carbs,
                            calories: calories
                        )
                    )
                }
            }

            return rows
        } catch {
            return []
        }
    }
}
