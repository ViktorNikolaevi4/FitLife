import SwiftUI
import SwiftData

struct ProductSelectionView: View {
    @State private var customProducts: [CustomProduct] = []
    let mealType: MealType
    let date: Date
    @State var productLoader = ProductLoader()

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var searchText: String = ""
    @State private var selectedFilter: FilterType = .all
    @State private var isCreatingProduct: Bool = false

    // кэш «Любимых»
    @State private var cachedFilteredProducts: [Product] = []

    // частоты использования по имени продукта
    @State private var usageCounts: [String: Int] = [:]

    var onProductSelected: (Product) -> Void
    var onCustomProductSelected: (CustomProduct) -> Void
    /// Если экран встроен в уже открытый лист — передайте onClose, чтобы свернуть список (а не dismiss всего листа).
    var onClose: (() -> Void)? = nil

    enum FilterType: String, CaseIterable {
        case all = "Общие"
        case favorites = "Любимые"
        case custom = "Свои"
    }

    // MARK: - Списки (фильтр + сортировка: usage desc → name asc)

    var filteredProducts: [Product] {
        let base = (selectedFilter == .favorites ? cachedFilteredProducts : productLoader.products)
        let filtered = searchText.isEmpty
            ? base
            : base.filter { $0.name.localizedCaseInsensitiveContains(searchText) }

        let sorted = filtered.sorted { a, b in
            let ca = usageCounts[a.name] ?? 0
            let cb = usageCounts[b.name] ?? 0
            if ca != cb { return ca > cb }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        return Array(sorted.prefix(300))
    }

    var filteredCustomProducts: [CustomProduct] {
        let base = searchText.isEmpty
            ? customProducts
            : customProducts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }

        return base.sorted { a, b in
            let ca = usageCounts[a.name] ?? 0
            let cb = usageCounts[b.name] ?? 0
            if ca != cb { return ca > cb }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    // MARK: - UI

    var body: some View {
        NavigationStack {
            VStack {
                VStack {
                    Text("Таблица калорийности продуктов питания")
                        .foregroundStyle(.primary)
                    Text("(данные указаны на 100 г продукта)")
                        .foregroundStyle(.secondary)
                }

                Picker("Выберите категорию", selection: $selectedFilter) {
                    ForEach(FilterType.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                TextField("Поиск еды...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
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
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            deleteCustomProduct(customProduct)
                                        } label: {
                                            Label("Удалить", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Создать") { isCreatingProduct = true }
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
                        if let onClose { onClose() } else { dismiss() }
                    }
                    .foregroundColor(.blue)
                }
            }
            .onAppear {
                loadFavorites()
                loadCustomProducts()
                cachedFilteredProducts = productLoader.products.filter { $0.isFavorite }
                loadUsageCounts() // ← важно: посчитать частоты
            }
            .sheet(isPresented: $isCreatingProduct) {
                CustomProductCreationView { newProduct in
                    customProducts.append(newProduct)
                }
            }
            .background(Color(.systemBackground).ignoresSafeArea())
        }
    }

    // MARK: - Rows

    private func productRow(product: Product) -> some View {
        Button(action: {
            onProductSelected(product)   // ⬅️ НЕ dismiss — поверх откроется оверлей граммов
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name).font(.headline)
                    Text("На 100 г: \(product.calories) ккал, Б \(String(format: "%.1f", product.protein)) г., Ж \(String(format: "%.1f", product.fat)) г., У \(String(format: "%.1f", product.carbs)) г.")
                        .font(.caption)
                }
                .foregroundColor(.primary)
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
                .buttonStyle(.borderless)
                .padding(.vertical, 4)
            }
        }
    }

    private func customProductRow(customProduct: CustomProduct) -> some View {
        Button(action: {
            onCustomProductSelected(customProduct) // по тапу выбираем продукт
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(customProduct.name).font(.headline)
                    Text("На 100 г: \(customProduct.calories) ккал, " +
                         "Б \(String(format: "%.1f", customProduct.protein)) г, " +
                         "Ж \(String(format: "%.1f", customProduct.fat)) г, " +
                         "У \(String(format: "%.1f", customProduct.carbs)) г")
                        .font(.caption)
                }
                .foregroundStyle(.primary)
                Spacer()
            }
        }
    }


    // MARK: - Utils

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    // Частоты использования по FoodEntry (по имени продукта)
    private func loadUsageCounts() {
        let fd = FetchDescriptor<FoodEntry>()
        do {
            let entries = try modelContext.fetch(fd)
            var map: [String: Int] = [:]
            for e in entries {
                let key = (e.product?.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty else { continue }
                map[key, default: 0] += 1
            }
            usageCounts = map
        } catch {
            print("Ошибка чтения usageCounts:", error)
            usageCounts = [:]
        }
    }

    private func saveFavoriteStatus(for product: Product) async {
        let fd = FetchDescriptor<FoodEntry>()
        do {
            let entries = try modelContext.fetch(fd)

            if let entry = entries.first(where: { $0.product?.id == product.id }) {
                entry.isFavorite = product.isFavorite
            } else {
                let newEntry = FoodEntry(
                    date: Date(),
                    mealType: mealType.rawValue,
                    product: product,
                    portion: 100,
                    gender: .male,              // TODO: подставить актуальный пол
                    isFavorite: product.isFavorite
                )
                modelContext.insert(newEntry)
            }

            try modelContext.save()
            await MainActor.run {
                self.cachedFilteredProducts = self.productLoader.products.filter { $0.isFavorite }
                print("Статус избранного сохранён: \(product.name)")
            }
        } catch {
            await MainActor.run { print("Ошибка сохранения избранного: \(error)") }
        }
    }

    private func deleteCustomProduct(_ customProduct: CustomProduct) {
        let fd = FetchDescriptor<CustomProduct>()
        do {
            let all = try modelContext.fetch(fd)
            if let toDelete = all.first(where: { $0.id == customProduct.id }) {
                modelContext.delete(toDelete)
                try modelContext.save()
                if let idx = customProducts.firstIndex(where: { $0.id == customProduct.id }) {
                    customProducts.remove(at: idx)
                }
                print("Пользовательский продукт удалён: \(customProduct.name)")
            }
        } catch {
            print("Ошибка удаления: \(error)")
        }
    }

    private func loadCustomProducts() {
        DispatchQueue.global(qos: .background).async {
            let fd = FetchDescriptor<CustomProduct>()
            do {
                let products = try modelContext.fetch(fd)
                DispatchQueue.main.async { self.customProducts = products }
            } catch {
                DispatchQueue.main.async { print("Ошибка загрузки своих продуктов: \(error)") }
            }
        }
    }

    private func loadFavorites() {
        DispatchQueue.global(qos: .background).async {
            let fd = FetchDescriptor<FoodEntry>()
            do {
                let entries = try self.modelContext.fetch(fd)

                // словарь: id продукта -> isFavorite (по последней записи)
                let dict: [UUID: Bool] = entries.reduce(into: [:]) { acc, e in
                    guard let id = e.product?.id else { return }
                    acc[id] = e.isFavorite
                }

                DispatchQueue.main.async {
                    for i in self.productLoader.products.indices {
                        let id = self.productLoader.products[i].id
                        if let fav = dict[id] {
                            self.productLoader.products[i].isFavorite = fav
                        }
                    }
                    self.cachedFilteredProducts = self.productLoader.products.filter { $0.isFavorite }
                }
            } catch {
                DispatchQueue.main.async { print("Ошибка загрузки избранного: \(error)") }
            }
        }
    }
}

// MARK: - CustomProductCreationView (как было)

struct CustomProductCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var calories = ""
    @State private var protein  = ""
    @State private var fat      = ""
    @State private var carbs    = ""

    private enum Field: Hashable { case name, calories, protein, fat, carbs }
    @FocusState private var focusedField: Field?

    var onProductCreated: (CustomProduct) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Новый продукт").font(.largeTitle.bold())
                    Text("БЖУ указывайте на 100 г продукта")
                        .font(.caption).foregroundStyle(.secondary)

                    field("Наименование", text: $name, field: .name, kb: .default, submit: .next)
                        .onSubmit { focusedField = .calories }

                    field("Энергия, ккал", text: $calories, field: .calories, kb: .decimalPad, submit: .next)
                        .onSubmit { focusedField = .protein }

                    HStack(spacing: 12) {
                        field("Белки, г.", text: $protein, field: .protein, kb: .decimalPad, submit: .next)
                            .onSubmit { focusedField = .fat }
                        field("Жиры, г.", text: $fat, field: .fat, kb: .decimalPad, submit: .next)
                            .onSubmit { focusedField = .carbs }
                        field("Углеводы, г.", text: $carbs, field: .carbs, kb: .decimalPad, submit: .done)
                            .onSubmit { focusedField = nil }
                    }

                    VStack(spacing: 10) {
                        Button("Создать", action: submit)
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .disabled(!isValid)
                            .frame(maxWidth: .infinity)

                        Button("Отмена", role: .destructive) { dismiss() }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Button("Назад") { prev() }.disabled(focusedField == .name)
                    Button("Далее") { next() }.disabled(focusedField == .carbs)
                    Spacer()
                    Button("Готово") { focusedField = nil }
                }
            }
            .onAppear { focusedField = .name }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func field(_ title: String, text: Binding<String>, field: Field, kb: UIKeyboardType, submit: SubmitLabel) -> some View {
        TextField(title, text: text)
            .keyboardType(kb)
            .textInputAutocapitalization(.never)
            .focused($focusedField, equals: field)
            .submitLabel(submit)
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(focusedField == field ? Color.blue : Color.gray.opacity(0.35),
                            lineWidth: focusedField == field ? 2 : 1)
            )
            .animation(.easeInOut(duration: 0.15), value: focusedField == field)
    }

    private var isValid: Bool {
        !name.isEmpty &&
        Double(calories.replacingOccurrences(of: ",", with: ".")) != nil &&
        Double(protein .replacingOccurrences(of: ",", with: ".")) != nil &&
        Double(fat     .replacingOccurrences(of: ",", with: ".")) != nil &&
        Double(carbs   .replacingOccurrences(of: ",", with: ".")) != nil
    }

    private func next() {
        switch focusedField {
        case .name:     focusedField = .calories
        case .calories: focusedField = .protein
        case .protein:  focusedField = .fat
        case .fat:      focusedField = .carbs
        default:        focusedField = nil
        }
    }
    private func prev() {
        switch focusedField {
        case .carbs:    focusedField = .fat
        case .fat:      focusedField = .protein
        case .protein:  focusedField = .calories
        case .calories: focusedField = .name
        default:        break
        }
    }

    private func submit() {
        guard
            let k = Double(calories.replacingOccurrences(of: ",", with: ".")),
            let p = Double(protein .replacingOccurrences(of: ",", with: ".")),
            let f = Double(fat     .replacingOccurrences(of: ",", with: ".")),
            let c = Double(carbs   .replacingOccurrences(of: ",", with: "."))
        else { return }

        let item = CustomProduct(name: name, protein: p, fat: f, carbs: c, calories: Int(k))
        do {
            modelContext.insert(item)
            try modelContext.save()
            onProductCreated(item)
            dismiss()
        } catch {
            print("Ошибка сохранения: \(error)")
        }
    }
}
