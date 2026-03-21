import SwiftUI
import Foundation
import SwiftCSV
import SwiftData

enum ProductSource: String, Codable {
    case localCSV
    case usda
    case openFoodFacts
}

@Model
class Product {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    var nameEN: String?
    var protein: Double = 0
    var fat: Double = 0
    var carbs: Double = 0
    var calories: Int = 0
    var isFavorite: Bool = false
    var isCustom: Bool = false
    var barcode: String?
    var sourceRawValue: String = ProductSource.localCSV.rawValue

    init(
        name: String,
        nameEN: String? = nil,
        protein: Double,
        fat: Double,
        carbs: Double,
        calories: Int,
        isFavorite: Bool = false,
        isCustom: Bool = false,
        barcode: String? = nil,
        source: ProductSource = .localCSV
    ) {
        self.name = name
        self.nameEN = nameEN
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.calories = calories
        self.isFavorite = isFavorite
        self.isCustom = isCustom
        self.barcode = barcode
        self.sourceRawValue = source.rawValue
    }

    var source: ProductSource {
        get { ProductSource(rawValue: sourceRawValue) ?? .localCSV }
        set { sourceRawValue = newValue.rawValue }
    }

    func displayName(preferredLanguageCode: String) -> String {
        if preferredLanguageCode == "en",
           let englishName = nameEN?.trimmingCharacters(in: .whitespacesAndNewlines),
           !englishName.isEmpty {
            return englishName
        }
        return name
    }

    func matches(_ query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }

        if name.localizedCaseInsensitiveContains(needle) {
            return true
        }

        if let englishName = nameEN,
           englishName.localizedCaseInsensitiveContains(needle) {
            return true
        }

        if let barcode,
           barcode.localizedCaseInsensitiveContains(needle) {
            return true
        }

        return false
    }
}
