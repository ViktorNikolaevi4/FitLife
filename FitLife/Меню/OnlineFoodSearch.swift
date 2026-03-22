import Foundation
import Network
import Observation

enum FoodSearchLanguage: String {
    case ru
    case en

    static func from(locale: Locale) -> FoodSearchLanguage {
        let code = locale.language.languageCode?.identifier ?? locale.identifier
        return code.hasPrefix("ru") ? .ru : .en
    }
}

enum ProductSearchRoute {
    case offlineLocal
    case barcodeOpenFoodFacts
    case englishUSDAThenLocal
    case russianLocalThenOpenFoodFacts
}

struct ProductSearchResponse {
    let remoteProducts: [Product]
    let route: ProductSearchRoute
    let messageKey: String?
}

enum USDAServiceError: Error {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case emptyFoods
    case decodingFailed
}

@MainActor
@Observable
final class NetworkMonitor {
    var isConnected = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "FitLife.NetworkMonitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isConnected = (path.status == .satisfied)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}

actor ProductSearchCoordinator {
    static let shared = ProductSearchCoordinator()

    private let usdaService = USDAFoodService()
    private let openFoodFactsService = OpenFoodFactsService()

    func search(
        query: String,
        localProducts: [Product],
        language: FoodSearchLanguage,
        hasInternet: Bool
    ) async -> ProductSearchResponse {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return ProductSearchResponse(remoteProducts: [], route: .offlineLocal, messageKey: nil)
        }

        if !hasInternet {
            return ProductSearchResponse(
                remoteProducts: [],
                route: .offlineLocal,
                messageKey: "search.message.offline_local"
            )
        }

        if Self.looksLikeBarcode(trimmedQuery) {
            let barcodeMatches = await openFoodFactsService.product(byBarcode: trimmedQuery)
            return ProductSearchResponse(
                remoteProducts: barcodeMatches,
                route: .barcodeOpenFoodFacts,
                messageKey: barcodeMatches.isEmpty
                    ? "search.message.barcode_not_found"
                    : "search.message.barcode_checked"
            )
        }

        switch language {
        case .en:
            let usdaResult = await usdaService.searchFoods(matching: trimmedQuery)
            let remoteProducts = (try? usdaResult.get()) ?? []
            return ProductSearchResponse(
                remoteProducts: remoteProducts,
                route: .englishUSDAThenLocal,
                messageKey: {
                    switch usdaResult {
                    case .success(let products):
                        return products.isEmpty
                            ? "search.message.usda_empty"
                            : "search.message.usda_then_local"
                    case .failure:
                        return "search.message.usda_error"
                    }
                }()
            )

        case .ru:
            let hasLocalMatches = localProducts.contains { $0.matches(trimmedQuery) }
            guard !hasLocalMatches, trimmedQuery.count >= 4 else {
                return ProductSearchResponse(
                    remoteProducts: [],
                    route: .russianLocalThenOpenFoodFacts,
                    messageKey: hasLocalMatches ? "search.message.local_first" : nil
                )
            }

            let remoteProducts = await openFoodFactsService.textSearch(query: trimmedQuery, language: language)
            return ProductSearchResponse(
                remoteProducts: remoteProducts,
                route: .russianLocalThenOpenFoodFacts,
                messageKey: remoteProducts.isEmpty
                    ? "search.message.local_and_off_empty"
                    : "search.message.local_empty_off_results"
            )
        }
    }

    nonisolated static func looksLikeBarcode(_ query: String) -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (8...14).contains(trimmedQuery.count) else { return false }
        return trimmedQuery.allSatisfy(\.isNumber)
    }
}

actor USDAFoodService {
    private var cache: [String: [Product]] = [:]

    func searchFoods(matching query: String) async -> Result<[Product], USDAServiceError> {
        let cacheKey = query.lowercased()
        if let cached = cache[cacheKey] {
            return .success(cached)
        }

        guard let url = URL(string: "https://api.nal.usda.gov/fdc/v1/foods/search?api_key=\(USDAConfiguration.apiKey)") else {
            return .failure(.invalidURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = USDAFoodSearchRequest(
            query: query,
            pageSize: 20,
            dataType: ["Foundation", "SR Legacy", "Survey (FNDDS)"]
        )

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                return .failure(.httpStatus(status))
            }

            let decoded: USDAFoodSearchResponse
            do {
                decoded = try JSONDecoder().decode(USDAFoodSearchResponse.self, from: data)
            } catch {
                return .failure(.decodingFailed)
            }

            let products = deduplicated(decoded.foods.compactMap { $0.makeProduct() })
            guard !products.isEmpty else {
                return .failure(.emptyFoods)
            }
            cache[cacheKey] = products
            return .success(products)
        } catch {
            return .failure(.invalidResponse)
        }
    }

    private func deduplicated(_ products: [Product]) -> [Product] {
        var seen: Set<String> = []
        var result: [Product] = []

        for product in products {
            let key = "\(product.name.lowercased())|\(product.calories)|\(Int(product.protein))|\(Int(product.carbs))"
            if seen.insert(key).inserted {
                result.append(product)
            }
        }

        return result
    }
}

actor OpenFoodFactsService {
    private var barcodeCache: [String: [Product]] = [:]
    private var textCache: [String: [Product]] = [:]

    func product(byBarcode barcode: String) async -> [Product] {
        if let cached = barcodeCache[barcode] {
            return cached
        }

        let path = "https://world.openfoodfacts.org/api/v2/product/\(barcode).json?fields=code,product_name,product_name_en,product_name_ru,nutriments"
        guard let url = URL(string: path) else {
            return []
        }

        do {
            let request = makeRequest(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return []
            }

            let decoded = try JSONDecoder().decode(OpenFoodFactsProductResponse.self, from: data)
            let products = decoded.product.map { [$0.makeProduct()] } ?? []
            barcodeCache[barcode] = products
            return products
        } catch {
            return []
        }
    }

    func textSearch(query: String, language: FoodSearchLanguage) async -> [Product] {
        let cacheKey = "\(language.rawValue)|\(query.lowercased())"
        if let cached = textCache[cacheKey] {
            return cached
        }

        var components = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")
        components?.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "20"),
            URLQueryItem(name: "lc", value: language.rawValue)
        ]

        guard let url = components?.url else {
            return []
        }

        do {
            let request = makeRequest(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return []
            }

            let decoded = try JSONDecoder().decode(OpenFoodFactsSearchResponse.self, from: data)
            let products = deduplicated(decoded.products.compactMap { $0.makeProduct() })
            textCache[cacheKey] = products
            return products
        } catch {
            return []
        }
    }

    private func makeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue(OpenFoodFactsConfiguration.userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    private func deduplicated(_ products: [Product]) -> [Product] {
        var seen: Set<String> = []
        var result: [Product] = []

        for product in products {
            let key = product.barcode ?? product.name.lowercased()
            if seen.insert(key).inserted {
                result.append(product)
            }
        }

        return result
    }
}

private enum USDAConfiguration {
    // Do not ship a production API key in a public repository; move this to a secret before release.
    static let apiKey = "5Q0RqjPgXeOkogE6rB5JdchNPoP8WBS1AWnMYlOi"
}

private enum OpenFoodFactsConfiguration {
    static let userAgent = "FitLife/1.0 (iOS)"
}

private struct USDAFoodSearchRequest: Encodable {
    let query: String
    let pageSize: Int
    let dataType: [String]
}

private struct USDAFoodSearchResponse: Decodable {
    let foods: [USDAFood]
}

private struct USDAFood: Decodable {
    let description: String
    let foodNutrients: [USDAFoodNutrient]?
    let labelNutrients: USDALabelNutrients?

    func makeProduct() -> Product? {
        let calories = labelNutrients?.calories?.value
            ?? nutrientValue(numbers: ["1008", "208"], nameCandidates: ["energy"])
        let protein = labelNutrients?.protein?.value
            ?? nutrientValue(numbers: ["1003", "203"], nameCandidates: ["protein"])
        let fat = labelNutrients?.fat?.value
            ?? nutrientValue(numbers: ["1004", "204"], nameCandidates: ["total lipid", "fat"])
        let carbs = labelNutrients?.carbohydrates?.value
            ?? nutrientValue(numbers: ["1005", "205"], nameCandidates: ["carbohydrate"])

        guard let calories else { return nil }

        return Product(
            name: description.capitalized,
            nameEN: description.capitalized,
            protein: protein ?? 0,
            fat: fat ?? 0,
            carbs: carbs ?? 0,
            calories: Int(calories.rounded()),
            source: .usda
        )
    }

    private func nutrientValue(numbers: [String], nameCandidates: [String]) -> Double? {
        foodNutrients?.first(where: {
            if let nutrientNumber = $0.nutrientNumber,
               numbers.contains(nutrientNumber) {
                return true
            }

            guard let nutrientName = $0.nutrientName?.lowercased() else {
                return false
            }
            return nameCandidates.contains(where: { nutrientName.contains($0) })
        })?.value
    }
}

private struct USDAFoodNutrient: Decodable {
    let nutrientNumber: String?
    let nutrientName: String?
    let value: Double?
}

private struct USDALabelNutrients: Decodable {
    let fat: USDAValueContainer?
    let protein: USDAValueContainer?
    let carbohydrates: USDAValueContainer?
    let calories: USDAValueContainer?
}

private struct USDAValueContainer: Decodable {
    let value: Double?
}

private struct OpenFoodFactsProductResponse: Decodable {
    let product: OpenFoodFactsProduct?
}

private struct OpenFoodFactsSearchResponse: Decodable {
    let products: [OpenFoodFactsProduct]
}

private struct OpenFoodFactsProduct: Decodable {
    let code: String?
    let productName: String?
    let productNameEn: String?
    let productNameRu: String?
    let nutriments: OpenFoodFactsNutriments?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case productNameEn = "product_name_en"
        case productNameRu = "product_name_ru"
        case nutriments
    }

    func makeProduct() -> Product {
        let russianName = cleaned(productNameRu) ?? cleaned(productName) ?? cleaned(productNameEn) ?? "Unknown product"
        let englishName = cleaned(productNameEn) ?? cleaned(productName)

        return Product(
            name: russianName,
            nameEN: englishName,
            protein: nutriments?.resolvedProtein ?? 0,
            fat: nutriments?.resolvedFat ?? 0,
            carbs: nutriments?.resolvedCarbohydrates ?? 0,
            calories: Int((nutriments?.resolvedEnergyKcal ?? 0).rounded()),
            barcode: code,
            source: .openFoodFacts
        )
    }

    private func cleaned(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }
}

private struct OpenFoodFactsNutriments: Decodable {
    let proteins100g: Double?
    let proteins: Double?
    let proteinsValue: Double?
    let fat100g: Double?
    let fat: Double?
    let fatValue: Double?
    let carbohydrates100g: Double?
    let carbohydrates: Double?
    let carbohydratesValue: Double?
    let energyKcal100g: Double?
    let energyKcal: Double?
    let energyKcalValue: Double?
    let energyKj100g: Double?
    let energyKj: Double?

    enum CodingKeys: String, CodingKey {
        case proteins100g = "proteins_100g"
        case proteins
        case proteinsValue = "proteins_value"
        case fat100g = "fat_100g"
        case fat
        case fatValue = "fat_value"
        case carbohydrates100g = "carbohydrates_100g"
        case carbohydrates
        case carbohydratesValue = "carbohydrates_value"
        case energyKcal100g = "energy-kcal_100g"
        case energyKcal = "energy-kcal"
        case energyKcalValue = "energy-kcal_value"
        case energyKj100g = "energy_100g"
        case energyKj = "energy"
    }

    var resolvedProtein: Double? {
        firstMeaningfulValue([proteins100g, proteins, proteinsValue])
    }

    var resolvedFat: Double? {
        firstMeaningfulValue([fat100g, fat, fatValue])
    }

    var resolvedCarbohydrates: Double? {
        firstMeaningfulValue([carbohydrates100g, carbohydrates, carbohydratesValue])
    }

    var resolvedEnergyKcal: Double? {
        if let kcal = firstMeaningfulValue([energyKcal100g, energyKcal, energyKcalValue]) {
            return kcal
        }

        if let kj = firstMeaningfulValue([energyKj100g, energyKj]) {
            return kj / 4.184
        }

        return nil
    }

    private func firstMeaningfulValue(_ values: [Double?]) -> Double? {
        values
            .compactMap { $0 }
            .first(where: { $0 > 0 })
    }
}
