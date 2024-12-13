////
////  ProductListView.swift
////  FitLife
////
////  Created by Виктор Корольков on 11.12.2024.
////
//import SwiftUI
//import OpenFoodFactsSDK
//
//struct ProductListView: View {
//    @State private var products: [Product] = [] // Хранилище для продуктов
//    @State private var searchText: String = "" // Текст для поиска
//    @State private var isLoading: Bool = false // Индикатор загрузки
//
//    var body: some View {
//        NavigationView {
//            VStack {
//                SearchBar(text: $searchText, onSearch: fetchProducts) // Кастомный SearchBar
//
//                if isLoading {
//                    ProgressView("Загрузка продуктов...")
//                        .padding()
//                } else if products.isEmpty {
//                    Text("Продукты не найдены.")
//                        .foregroundColor(.gray)
//                        .padding()
//                } else {
//                    List(products, id: \.id) { product in
//                        ProductRow(product: product) // Отдельная View для отображения продукта
//                    }
//                }
//            }
//            .navigationTitle("Список продуктов")
//            .navigationBarTitleDisplayMode(.inline)
//        }
//    }
//
//    private func fetchProducts() {
//        isLoading = true
//
//        // Подготовка строки запроса
//        guard let query = searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
//              let url = URL(string: "https://world.openfoodfacts.org/cgi/search.pl?search_terms=\(query)&search_simple=1&json=1") else {
//            print("Некорректный URL")
//            isLoading = false
//            return
//        }
//
//        // Выполнение запроса
//        URLSession.shared.dataTask(with: url) { data, response, error in
//            DispatchQueue.main.async {
//                isLoading = false
//                if let error = error {
//                    print("Ошибка выполнения запроса: \(error.localizedDescription)")
//                    return
//                }
//
//                // Проверка статуса HTTP
//                if let httpResponse = response as? HTTPURLResponse {
//                    print("HTTP-статус: \(httpResponse.statusCode)")
//                    if httpResponse.statusCode != 200 {
//                        print("Ошибка HTTP: \(httpResponse.statusCode)")
//                        return
//                    }
//                }
//
//                guard let data = data else {
//                    print("Нет данных в ответе")
//                    return
//                }
//
//                // Выводим JSON-ответ
//                if let jsonString = String(data: data, encoding: .utf8) {
//                    print("JSON-ответ: \(jsonString)")
//                }
//
//                do {
//                    let apiResponse = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)
//                    self.products = apiResponse.products.compactMap { Product(from: $0) }
//                    print("Загружено продуктов: \(self.products.count)")
//                } catch {
//                    print("Ошибка декодирования: \(error.localizedDescription)")
//                }
//            }
//        }.resume()
//    }
//
//
//
//}
//
//struct OpenFoodFactsResponse: Codable {
//    let products: [APIProduct]
//}
//
//struct APIProduct: Codable {
//    let code: String?
//    let productName: String?
//    let brands: String?
//    let nutriments: [String: Double]?
//
//    // Если API возвращает другие данные, добавьте соответствующие свойства
//}
//
//
//struct ProductRow: View {
//    let product: Product
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 5) {
//            Text(product.name ?? "Без названия")
//                .font(.headline)
//            if let brands = product.brands {
//                Text("Бренд: \(brands)")
//                    .font(.subheadline)
//                    .foregroundColor(.secondary)
//            }
//            if let calories = product.calories {
//                Text("Калорийность: \(calories) ккал")
//                    .font(.footnote)
//            }
//        }
//        .padding(.vertical, 5)
//    }
//}
//
//struct SearchBar: View {
//    @Binding var text: String
//    var onSearch: () -> Void
//
//    var body: some View {
//        HStack {
//            TextField("Поиск продуктов...", text: $text)
//                .textFieldStyle(RoundedBorderTextFieldStyle())
//                .padding(.leading, 10)
//            Button(action: onSearch) {
//                Image(systemName: "magnifyingglass")
//                    .padding(.trailing, 10)
//            }
//        }
//        .padding()
//    }
//}
//
//// Модель для продуктов
//struct Product: Identifiable {
//    let id: String
//    let name: String?
//    let brands: String?
//    let calories: Double?
//
//    init(from apiProduct: APIProduct) {
//        self.id = apiProduct.code ?? UUID().uuidString
//        self.name = apiProduct.productName
//        self.brands = apiProduct.brands
//        self.calories = apiProduct.nutriments?["energy-kcal_100g"] as? Double
//    }
//}
//
//// Пример использования
//#Preview {
//    ProductListView()
//}
//
//
