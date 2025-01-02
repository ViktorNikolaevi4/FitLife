
import SwiftUI
import SwiftData

struct ProductSelectionView: View {
    @State private var customProducts: [CustomProduct] = []
    let mealType: MealType // Тип приема пищи (Завтрак, Обед и т.д.)
    let date: Date           // Текущая дата
    @State var productLoader = ProductLoader()
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var selectedFilter: FilterType = .all // Управление текущим фильтром
    @State private var isCreatingProduct: Bool = false // Управление формой создания продукта
    @State private var customProductName: String = ""
    @State private var customProductCalories: String = ""
    @State private var customProductProtein: String = ""
    @State private var customProductFat: String = ""
    @State private var customProductCarbs: String = ""
    var onProductSelected: (Product) -> Void
    var onCustomProductSelected: (CustomProduct) -> Void

    @Environment(\.modelContext) private var modelContext

    enum FilterType: String, CaseIterable {
        case all = "Общие"
        case favorites = "Любимые"
        case custom = "Свои"
    }

    @State private var cachedFilteredProducts: [Product] = []

    var filteredProducts: [Product] {
        let baseList = selectedFilter == .favorites
            ? cachedFilteredProducts
            : productLoader.products

        let filteredList = searchText.isEmpty ? baseList : baseList.filter { $0.name.localizedCaseInsensitiveContains(searchText) }

        // Ограничиваем количество элементов до 100
        return Array(filteredList.prefix(300))
    }



//    .onAppear {
//        cachedFilteredProducts = productLoader.products.filter { $0.isFavorite }
//    }


    var filteredCustomProducts: [CustomProduct] {
        if searchText.isEmpty {
            return customProducts
        } else {
            return customProducts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }


    var body: some View {
        NavigationStack {
            VStack {
                VStack {
                    Text("Таблица калорийности продуктов питания")
                    Text("(данные указаны на 100 г продукта)")
                }.foregroundStyle(.black)

                // Picker для фильтров
                Picker("Выберите категорию", selection: $selectedFilter) {
                    ForEach(FilterType.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle()) // Сегментированный стиль
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

                if isCreatingProduct {
                    ZStack {
                        Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)

                        VStack(spacing: 16) {
                            Text("Новый продукт")
                                .font(.headline)
                            Text("(БЖУ указывайте на 100 г продукта)")
                                .font(.caption)

                            TextField("Наименование", text: $customProductName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)

                            TextField("Энергия, ккал", text: $customProductCalories)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)

                            HStack(spacing: 16) {
                                TextField("Белки, г.", text: $customProductProtein)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                TextField("Жиры, г.", text: $customProductFat)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                TextField("Углеводы, г.", text: $customProductCarbs)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            .padding(.horizontal)

                            HStack {
                                Button("Создать") {
                                    createCustomProduct()
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)

                                Button("Отмена") {
                                    isCreatingProduct = false
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .padding(.horizontal)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 10)
                    }
                }
            }
            // Навигационный заголовок с приемом пищи и датой
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Кнопка "Создать" слева
                ToolbarItem(placement: .topBarLeading) {
                    Button("Создать") {
                        // Логика для кнопки "Создать"
                        isCreatingProduct = true
                    }
                    .foregroundColor(.blue)
                }
                // Кастомный заголовок с VStack
                ToolbarItem(placement: .principal) {
                    VStack {
                        Text(mealType.displayName) // Название приема пищи
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(formattedDate) // Отформатированная дата
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // Кнопка "Закрыть" в правом углу
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .onAppear {
              //  cachedFilteredProducts = productLoader.products.filter { $0.isFavorite }
                loadFavorites()
                loadCustomProducts()
                cachedFilteredProducts = productLoader.products.filter { $0.isFavorite }
            }
        }
    }
    private  func productRow(product: Product) -> some View {
        Button(action: {
            onProductSelected(product) // Передаем выбранный продукт
            dismiss()
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    // Название продукта
                    Text(product.name)
                        .font(.headline)
                    // Дополнительная информация
                    Text("На 100 г: \(product.calories) ккал, Б \(String(format: "%.1f", product.protein)) г., Ж \(String(format: "%.1f", product.fat)) г., У \(String(format: "%.1f", product.carbs)) г.")
                        .font(.caption)
                }
                .foregroundColor(.black)
                Spacer()
                // Кнопка "звезда" для добавления в избранное
                Button(action: {
                    Task {
                        if let index = productLoader.products.firstIndex(where: { $0.id == product.id }) {
                            productLoader.products[index].isFavorite.toggle() // Переключение избранного
                            await  saveFavoriteStatus(for: productLoader.products[index])
                        }
                    }
                }) {
                    Image(systemName: product.isFavorite ? "star.fill" : "star")
                        .foregroundColor(product.isFavorite ? .yellow : .gray)
                }
                .buttonStyle(BorderlessButtonStyle())
                .padding(.vertical, 4) // Отступы сверху и снизу для читаемости
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
                // Кнопка удаления
                Button(action: {
                    deleteCustomProduct(customProduct) // Удаляем продукт
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(BorderlessButtonStyle()) // Убирает стандартный стиль кнопки
            }
        }
    }
    // Форматирование даты
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
    private func createCustomProduct() {
        guard
            let calories = Double(customProductCalories),
            let protein = Double(customProductProtein),
            let fat = Double(customProductFat),
            let carbs = Double(customProductCarbs),
            !customProductName.isEmpty
        else {
            print("Ошибка: Пожалуйста, заполните все поля корректно.")
            return
        }

        let newCustomProduct = CustomProduct(
            name: customProductName,
            protein: protein,
            fat: fat,
            carbs: carbs,
            calories: Int(calories)
        )

        do {
            modelContext.insert(newCustomProduct) // Добавляем объект в базу данных
            try modelContext.save() // Сохраняем изменения
            print("Пользовательский продукт сохранен!")
            isCreatingProduct = false // Закрываем форму создания
            clearCustomProductFields() // Очищаем поля формы
        } catch {
            print("Ошибка при сохранении пользовательского продукта: \(error)")
        }
    }


    private func clearCustomProductFields() {
        customProductName = ""
        customProductCalories = ""
        customProductProtein = ""
        customProductFat = ""
        customProductCarbs = ""
    }
    private func saveFavoriteStatus(for product: Product) async {
        let fetchDescriptor = FetchDescriptor<FoodEntry>()
        do {
            // Выполняем асинхронный запрос на получение записей
            let foodEntries = try  modelContext.fetch(fetchDescriptor)

            // Обновляем или создаем запись
            if let entry = foodEntries.first(where: { $0.product.name == product.name }) {
                entry.isFavorite = product.isFavorite
            } else {
                let newEntry = FoodEntry(
                    date: Date(),
                    mealType: mealType.rawValue,
                    product: product,
                    portion: 100,
                    gender: .male, // Здесь укажите текущий пол пользователя
                    isFavorite: product.isFavorite
                )
                modelContext.insert(newEntry)
            }

            // Сохраняем изменения
            try modelContext.save()

            // Обновляем cachedFilteredProducts
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
            // Загружаем все пользовательские продукты
            let allCustomProducts = try modelContext.fetch(fetchDescriptor)
            // Ищем продукт, который нужно удалить
            if let productToDelete = allCustomProducts.first(where: { $0.id == customProduct.id }) {
                modelContext.delete(productToDelete) // Удаляем продукт из базы
                try modelContext.save() // Сохраняем изменения
                // Удаляем продукт из локального массива
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

                // Убираем дубликаты, оставляя только первый элемент с уникальным именем
                let uniqueEntries = Dictionary(grouping: foodEntries, by: { $0.product.name })
                    .compactMapValues { $0.first }

                // Создаем словарь из уникальных значений
                let favoritesDict = uniqueEntries.mapValues { $0.isFavorite }

                DispatchQueue.main.async {
                    for productIndex in self.productLoader.products.indices {
                        if let isFavorite = favoritesDict[self.productLoader.products[productIndex].name] {
                            self.productLoader.products[productIndex].isFavorite = isFavorite
                        }
                    }

                    // Обновляем cachedFilteredProducts
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
