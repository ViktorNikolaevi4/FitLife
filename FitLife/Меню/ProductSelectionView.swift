import SwiftUI
import SwiftData

struct ProductSelectionView: View {
    @State private var customProducts: [CustomProduct] = []
    let mealType: MealType
    let date: Date
    @State var productLoader = ProductLoader()
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var selectedFilter: FilterType = .all
    @State private var isCreatingProduct: Bool = false
    @State private var cachedFilteredProducts: [Product] = []

    var onProductSelected: (Product) -> Void
    var onCustomProductSelected: (CustomProduct) -> Void

    @Environment(\.modelContext) private var modelContext

    enum FilterType: String, CaseIterable {
        case all = "Общие"
        case favorites = "Любимые"
        case custom = "Свои"
    }

    var filteredProducts: [Product] {
        let baseList = selectedFilter == .favorites
            ? cachedFilteredProducts
            : productLoader.products

        let filteredList = searchText.isEmpty ? baseList : baseList.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        return Array(filteredList.prefix(300))
    }

    var filteredCustomProducts: [CustomProduct] {
        searchText.isEmpty ? customProducts : customProducts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            VStack {
                VStack {
                    Text("Таблица калорийности продуктов питания")
                    Text("(данные указаны на 100 г продукта)")
                }.foregroundStyle(.black)

                Picker("Выберите категорию", selection: $selectedFilter) {
                    ForEach(FilterType.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)

                TextField("Поиск еды...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                List {
                    if selectedFilter != .custom {
                        Section(header: Text("Общие продукты")) {
                            ForEach(filteredProducts, id: \.id) { product in
                                productRow(product: product)
                            }
                        }
                    }

                    if selectedFilter == .custom {
                        Section(header: Text("Свои продукты")) {
                            ForEach(filteredCustomProducts, id: \.id) { customProduct in
                                customProductRow(customProduct: customProduct)
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Создать") {
                        isCreatingProduct = true
                    }
                    .foregroundColor(.blue)
                }
                ToolbarItem(placement: .principal) {
                    VStack {
                        Text(mealType.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(formattedDate)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .onAppear {
                loadFavorites()
                loadCustomProducts()
                cachedFilteredProducts = productLoader.products.filter { $0.isFavorite }
            }
            .sheet(isPresented: $isCreatingProduct) {
                CustomProductCreationView { newProduct in
                    customProducts.append(newProduct)
                }
            }
        }
    }

    private func productRow(product: Product) -> some View {
        Button(action: {
            onProductSelected(product)
            dismiss()
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.headline)
                    Text("На 100 г: \(product.calories) ккал, Б \(String(format: "%.1f", product.protein)) г., Ж \(String(format: "%.1f", product.fat)) г., У \(String(format: "%.1f", product.carbs)) г.")
                        .font(.caption)
                }
                .foregroundColor(.black)
                Spacer()
                Button(action: {
                    Task {
                        if let index = productLoader.products.firstIndex(where: { $0.id == product.id }) {
                            productLoader.products[index].isFavorite.toggle()
                            await saveFavoriteStatus(for: productLoader.products[index])
                        }
                    }
                }) {
                    Image(systemName: product.isFavorite ? "star.fill" : "star")
                        .foregroundColor(product.isFavorite ? .yellow : .gray)
                }
                .buttonStyle(BorderlessButtonStyle())
                .padding(.vertical, 4)
            }
        }
    }

    private func customProductRow(customProduct: CustomProduct) -> some View {
        Button(action: {
            onCustomProductSelected(customProduct)
            dismiss()
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(customProduct.name)
                        .font(.headline)
                    Text("На 100 г: \(customProduct.calories) ккал, Б \(String(format: "%.1f", customProduct.protein)) г., Ж \(String(format: "%.1f", customProduct.fat)) г., У \(String(format: "%.1f", customProduct.carbs)) г.")
                        .font(.caption)
                }.foregroundStyle(.black)
                Spacer()
                Button(action: {
                    deleteCustomProduct(customProduct)
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    private func saveFavoriteStatus(for product: Product) async {
        let fetchDescriptor = FetchDescriptor<FoodEntry>()
        do {
            let foodEntries = try modelContext.fetch(fetchDescriptor)
            if let entry = foodEntries.first(where: { $0.product.name == product.name }) {
                entry.isFavorite = product.isFavorite
            } else {
                let newEntry = FoodEntry(
                    date: Date(),
                    mealType: mealType.rawValue,
                    product: product,
                    portion: 100,
                    gender: .male,
                    isFavorite: product.isFavorite
                )
                modelContext.insert(newEntry)
            }
            try modelContext.save()
            await MainActor.run {
                self.cachedFilteredProducts = self.productLoader.products.filter { $0.isFavorite }
                print("Статус избранного сохранен для продукта: \(product.name)")
            }
        } catch {
            await MainActor.run {
                print("Ошибка сохранения избранного статуса: \(error)")
            }
        }
    }

    private func deleteCustomProduct(_ customProduct: CustomProduct) {
        let fetchDescriptor = FetchDescriptor<CustomProduct>()
        do {
            let allCustomProducts = try modelContext.fetch(fetchDescriptor)
            if let productToDelete = allCustomProducts.first(where: { $0.id == customProduct.id }) {
                modelContext.delete(productToDelete)
                try modelContext.save()
                if let index = customProducts.firstIndex(where: { $0.id == customProduct.id }) {
                    customProducts.remove(at: index)
                }
                print("Продукт успешно удалён: \(customProduct.name)")
            } else {
                print("Продукт не найден для удаления: \(customProduct.name)")
            }
        } catch {
            print("Ошибка при удалении продукта: \(error)")
        }
    }

    private func loadCustomProducts() {
        DispatchQueue.global(qos: .background).async {
            let fetchDescriptor = FetchDescriptor<CustomProduct>()
            do {
                let products = try modelContext.fetch(fetchDescriptor)
                DispatchQueue.main.async {
                    self.customProducts = products
                    print("Загружены пользовательские продукты: \(products.map { $0.name })")
                }
            } catch {
                DispatchQueue.main.async {
                    print("Ошибка загрузки пользовательских продуктов: \(error)")
                }
            }
        }
    }

    private func loadFavorites() {
        DispatchQueue.global(qos: .background).async {
            let fetchDescriptor = FetchDescriptor<FoodEntry>()
            do {
                let foodEntries = try self.modelContext.fetch(fetchDescriptor)
                let uniqueEntries = Dictionary(grouping: foodEntries, by: { $0.product.name })
                    .compactMapValues { $0.first }
                let favoritesDict = uniqueEntries.mapValues { $0.isFavorite }

                DispatchQueue.main.async {
                    for productIndex in self.productLoader.products.indices {
                        if let isFavorite = favoritesDict[self.productLoader.products[productIndex].name] {
                            self.productLoader.products[productIndex].isFavorite = isFavorite
                        }
                    }
                    self.cachedFilteredProducts = self.productLoader.products.filter { $0.isFavorite }
                    print("Избранные продукты обновлены.")
                }
            } catch {
                DispatchQueue.main.async {
                    print("Ошибка загрузки избранных продуктов: \(error)")
                }
            }
        }
    }
}

// CustomProductCreationView
struct CustomProductCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var calories = ""
    @State private var protein  = ""
    @State private var fat      = ""
    @State private var carbs    = ""

    var onProductCreated: (CustomProduct) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(footer: Text("БЖУ указывайте на 100 г продукта")) {
                    TextField("Наименование", text: $name)
                        .textInputAutocapitalization(.never)

                    TextField("Энергия, ккал", text: $calories)
                        .keyboardType(.decimalPad)

                    HStack {
                        TextField("Белки, г.", text: $protein)
                            .keyboardType(.decimalPad)
                        TextField("Жиры, г.", text: $fat)
                            .keyboardType(.decimalPad)
                        TextField("Углеводы, г.", text: $carbs)
                            .keyboardType(.decimalPad)
                    }
                }

                Section {
                    // СОЗДАТЬ — синий, становится активной когда все поля валидны
                    Button {
                        submit()
                    } label: {
                        Text("Создать")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.large)
                    .disabled(!isValid)

                    // ОТМЕНА — красная
                    Button(role: .destructive) {
                        dismiss()
                    } label: {
                        Text("Отмена")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.large)
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Новый продукт")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") { hideKeyboard() }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var isValid: Bool {
        !name.isEmpty &&
        Double(calories.replacingOccurrences(of: ",", with: ".")) != nil &&
        Double(protein .replacingOccurrences(of: ",", with: ".")) != nil &&
        Double(fat     .replacingOccurrences(of: ",", with: ".")) != nil &&
        Double(carbs   .replacingOccurrences(of: ",", with: ".")) != nil
    }

    private func submit() {
        guard
            let kcal = Double(calories.replacingOccurrences(of: ",", with: ".")),
            let p    = Double(protein .replacingOccurrences(of: ",", with: ".")),
            let f    = Double(fat     .replacingOccurrences(of: ",", with: ".")),
            let c    = Double(carbs   .replacingOccurrences(of: ",", with: "."))
        else { return }

        let newItem = CustomProduct(name: name,
                                    protein: p, fat: f, carbs: c,
                                    calories: Int(kcal))
        do {
            modelContext.insert(newItem)
            try modelContext.save()
            onProductCreated(newItem)
            dismiss()
        } catch {
            print("Ошибка сохранения: \(error)")
        }
    }

    private func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}
