import SwiftUI
import SwiftData

private let productSelectionCardBackground = Color(.secondarySystemBackground)
private let productSelectionInsetBackground = Color(.tertiarySystemBackground)
private let productSelectionCardBorder = Color(.separator).opacity(0.40)

actor ProductUsageCache {
    static let shared = ProductUsageCache()

    private var countsByOwnerId: [String: [String: Int]] = [:]

    func counts(for ownerId: String) -> [String: Int]? {
        countsByOwnerId[ownerId]
    }

    func store(_ counts: [String: Int], for ownerId: String) {
        countsByOwnerId[ownerId] = counts
    }

    func increment(productName: String, for ownerId: String) {
        let key = productName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        countsByOwnerId[ownerId, default: [:]][key, default: 0] += 1
    }

    func decrement(productName: String, for ownerId: String) {
        let key = productName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }

        var counts = countsByOwnerId[ownerId, default: [:]]
        let nextValue = max(0, (counts[key] ?? 0) - 1)
        if nextValue == 0 {
            counts.removeValue(forKey: key)
        } else {
            counts[key] = nextValue
        }
        countsByOwnerId[ownerId] = counts
    }
}

struct ProductSelectionView: View {
    private static let favoriteNamesKey = "favoriteProductNames"
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue

    @State private var customProducts: [CustomProduct] = []
    let mealType: MealType
    let date: Date
    let selectedGender: Gender

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var productCatalogStore: ProductCatalogStore
    @EnvironmentObject private var sessionStore: AppSessionStore

    @State private var searchText: String = ""
    @State private var selectedFilter: FilterType = .all
    @State private var isCreatingProduct: Bool = false
    @State private var networkMonitor = NetworkMonitor()
    @State private var remoteProducts: [Product] = []
    @State private var isSearchingRemotely = false
    @State private var remoteSearchMessage: String?
    @State private var currentSearchRoute: ProductSearchRoute = .offlineLocal
    @State private var searchTask: Task<Void, Never>?
    @State private var isShowingBarcodeScanner = false
    @State private var isShowingAIMealRecognition = false
    @State private var scannerErrorMessage: String?
    @FocusState private var isSearchFocused: Bool

    // кэш «Любимых»
    @State private var cachedFilteredProducts: [Product] = []
    @State private var filteredProductsCache: [Product] = []
    @State private var filteredCustomProductsCache: [CustomProduct] = []

    // частоты использования по имени продукта
    @State private var usageCounts: [String: Int] = [:]
    @State private var usageCountsTask: Task<Void, Never>?
    @State private var expandsResultsTask: Task<Void, Never>?
    @State private var showsExpandedResults = false

    var onProductSelected: (Product) -> Void
    var onCustomProductSelected: (CustomProduct) -> Void
    var onRecognizedMealSaved: (() -> Void)? = nil
    /// Если экран встроен в уже открытый лист — передайте onClose, чтобы свернуть список (а не dismiss всего листа).
    var onClose: (() -> Void)? = nil

    enum FilterType: String, CaseIterable {
        case all = "Общие"
        case favorites = "Любимые"
        case custom = "Свои"
    }

    private var appLanguage: AppLanguage {
        AppLanguage.from(rawValue: appLanguageRaw)
    }

    private var searchLanguage: FoodSearchLanguage {
        FoodSearchLanguage.from(locale: locale)
    }

    // MARK: - Списки (фильтр + сортировка: usage desc → name asc)

    var filteredProducts: [Product] { filteredProductsCache }

    var filteredCustomProducts: [CustomProduct] { filteredCustomProductsCache }

    private var initialLocalRenderLimit: Int { 30 }
    private var initialRemoteRenderLimit: Int { 12 }

    private var visibleRemoteProducts: [Product] {
        if showsExpandedResults || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return remoteProducts
        }
        return Array(remoteProducts.prefix(initialRemoteRenderLimit))
    }

    private var visibleFilteredProducts: [Product] {
        if showsExpandedResults || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return filteredProducts
        }
        return Array(filteredProducts.prefix(initialLocalRenderLimit))
    }

    private var visibleFilteredCustomProducts: [CustomProduct] {
        if showsExpandedResults || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return filteredCustomProducts
        }
        return Array(filteredCustomProducts.prefix(initialLocalRenderLimit))
    }

    private var shouldShowRemoteSection: Bool {
        selectedFilter == .all && !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !remoteProducts.isEmpty
    }

    private var shouldShowLocalProductsSection: Bool {
        switch selectedFilter {
        case .all:
            return appLanguage != .english
        case .favorites:
            return true
        case .custom:
            return false
        }
    }

    private var shouldShowEnglishCustomSectionInAll: Bool {
        selectedFilter == .all && appLanguage == .english && !filteredCustomProducts.isEmpty
    }

    private var shouldShowEnglishAllEmptyState: Bool {
        selectedFilter == .all
            && appLanguage == .english
            && !shouldShowRemoteSection
            && filteredCustomProducts.isEmpty
    }

    private var localSectionTitle: String {
        switch selectedFilter {
        case .all:
            return shouldShowRemoteSection ? appLanguage.localized("search.section.local_database") : appLanguage.localized("search.section.common_products")
        case .favorites:
            return appLanguage.localized("search.filter.favorites")
        case .custom:
            return appLanguage.localized("search.section.custom_products")
        }
    }

    private var remoteSectionTitle: String {
        switch currentSearchRoute {
        case .barcodeOpenFoodFacts:
            return "Open Food Facts"
        case .englishUSDAThenLocal:
            return "USDA"
        case .russianLocalThenOpenFoodFacts:
            return "Open Food Facts"
        case .offlineLocal:
            return appLanguage.localized("search.section.online")
        }
    }

    private var searchStatusText: String? {
        if isSearchingRemotely {
            switch currentSearchRoute {
            case .barcodeOpenFoodFacts:
                return appLanguage.localized("search.status.barcode")
            case .englishUSDAThenLocal:
                return appLanguage.localized("search.status.usda")
            case .russianLocalThenOpenFoodFacts:
                return appLanguage.localized("search.status.off")
            case .offlineLocal:
                return appLanguage.localized("search.status.source")
            }
        }

        return remoteSearchMessage.flatMap { appLanguage.localized($0) }
    }

    // MARK: - UI

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(appLanguage.localized("search.prompt"))
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(appLanguage.localized("search.subtitle"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Picker(appLanguage.localized("search.category"), selection: $selectedFilter) {
                        ForEach(FilterType.allCases, id: \.self) { filter in
                            Text(title(for: filter)).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)

                        TextField(appLanguage.localized("search.placeholder"), text: $searchText)
                            .textInputAutocapitalization(.never)
                            .focused($isSearchFocused)
                            .onSubmit {
                                scheduleHybridSearch(immediate: true)
                            }

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                scheduleHybridSearch(immediate: true)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(productSelectionCardBackground, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(productSelectionCardBorder)
                    )

                    HStack(spacing: 10) {
                        actionPill(
                            title: AppLocalizer.string("ai.meal.action"),
                            systemImage: "camera.viewfinder"
                        ) {
                            isShowingAIMealRecognition = true
                        }

                        actionPill(
                            title: appLanguage.localized("common.scan"),
                            systemImage: "barcode.viewfinder"
                        ) {
                            isShowingBarcodeScanner = true
                        }

                        actionPill(
                            title: appLanguage.localized("common.create"),
                            systemImage: "plus"
                        ) {
                            isCreatingProduct = true
                        }
                    }

                    if let searchStatusText {
                        HStack(spacing: 8) {
                            if isSearchingRemotely {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(searchStatusText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if shouldShowRemoteSection {
                            sectionHeader(remoteSectionTitle)

                            if remoteProducts.isEmpty {
                                emptyStateRow(message: appLanguage.localized("search.empty.all"))
                            } else {
                                ForEach(visibleRemoteProducts, id: \.id) { product in
                                    productRow(product: product)
                                }
                            }
                        }

                        if shouldShowLocalProductsSection {
                            sectionHeader(localSectionTitle)

                            if filteredProducts.isEmpty {
                                emptyStateRow(message: emptyMessageForCurrentFilter)
                            } else {
                                ForEach(visibleFilteredProducts, id: \.id) { product in
                                    productRow(product: product)
                                }
                            }
                        }

                        if shouldShowEnglishAllEmptyState {
                            emptyStateRow(message: emptyMessageForCurrentFilter)
                        }

                        if shouldShowEnglishCustomSectionInAll || selectedFilter == .custom {
                            sectionHeader(appLanguage.localized("search.section.custom_products"))

                            if filteredCustomProducts.isEmpty {
                                emptyStateRow(message: emptyMessageForCurrentFilter)
                            } else {
                                ForEach(visibleFilteredCustomProducts, id: \.id) { customProduct in
                                    customProductRow(customProduct: customProduct)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(appLanguage.localized("common.close")) {
                        if let onClose { onClose() } else { dismiss() }
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
            }
            .onAppear {
                productCatalogStore.preloadIfNeeded()
                loadFavorites()
                loadCustomProducts()
                cachedFilteredProducts = productCatalogStore.products.filter { $0.isFavorite }
                refreshVisibleProducts()
                scheduleExpandedResults()
                scheduleHybridSearch()
                loadUsageCountsIfNeeded()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isSearchFocused = true
                }
            }
            .onChange(of: productCatalogStore.products.count) { _, _ in
                loadFavorites()
                refreshVisibleProducts()
                scheduleHybridSearch(immediate: true)
            }
            .onDisappear {
                usageCountsTask?.cancel()
                expandsResultsTask?.cancel()
            }
            .onChange(of: searchText) { _, _ in
                refreshVisibleProducts()
                scheduleExpandedResults()
                scheduleHybridSearch()
            }
            .onChange(of: selectedFilter) { _, _ in
                refreshVisibleProducts()
                scheduleExpandedResults()
                scheduleHybridSearch(immediate: true)
            }
            .onChange(of: networkMonitor.isConnected) { _, _ in
                scheduleHybridSearch(immediate: true)
            }
            .sheet(isPresented: $isCreatingProduct) {
                CustomProductCreationView { newProduct in
                    customProducts.append(newProduct)
                    refreshVisibleProducts()
                }
            }
            .sheet(isPresented: $isShowingBarcodeScanner) {
                BarcodeScannerView(
                    onScanned: { code in
                        searchText = code
                        scheduleHybridSearch(immediate: true)
                    },
                    onFailure: { error in
                        scannerErrorMessage = error.localizedDescription
                        isShowingBarcodeScanner = false
                    }
                )
            }
            .sheet(isPresented: $isShowingAIMealRecognition) {
                AIMealRecognitionFlowView(
                    selectedDate: date,
                    selectedGender: selectedGender,
                    preselectedMeal: mealType,
                    onSaved: {
                        isShowingAIMealRecognition = false
                        onRecognizedMealSaved?()
                    }
                )
            }
            .alert(
                appLanguage.localized("search.scan.alert.title"),
                isPresented: Binding(
                    get: { scannerErrorMessage != nil },
                    set: { if !$0 { scannerErrorMessage = nil } }
                ),
                actions: {
                    Button(appLanguage.localized("common.ok"), role: .cancel) {
                        scannerErrorMessage = nil
                    }
                },
                message: {
                    Text(scannerErrorMessage ?? "")
                }
            )
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
    }

    // MARK: - Rows

    private func productRow(product: Product) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(product.displayName(preferredLanguageCode: searchLanguage.rawValue))
                    .font(.body.weight(.semibold))
                    .multilineTextAlignment(.leading)

                Text(appLanguage.localized("search.per_100g"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    metricTag(text: "\(product.calories) \(appLanguage.localized("unit.kcal"))")
                    metricTag(text: macroShort("macro.protein.short", value: product.protein))
                    metricTag(text: macroShort("macro.fat.short", value: product.fat))
                    metricTag(text: macroShort("macro.carbs.short", value: product.carbs))
                }
            }
            .foregroundColor(.primary)

            Spacer()

            VStack(alignment: .trailing, spacing: 10) {
                Button(action: {
                    onProductSelected(product)
                }) {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 36, height: 36)
                        .background(Color.blue.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)

                if let index = productCatalogStore.products.firstIndex(where: { $0.id == product.id }) {
                    Button(action: {
                        productCatalogStore.products[index].isFavorite.toggle()
                        persistFavorites()
                        cachedFilteredProducts = productCatalogStore.products.filter { $0.isFavorite }
                        refreshVisibleProducts()
                    }) {
                        Image(systemName: product.isFavorite ? "star.fill" : "star")
                            .foregroundColor(product.isFavorite ? .yellow : .gray)
                            .frame(width: 36, height: 36)
                            .background(Color(.secondarySystemBackground), in: Circle())
                    }
                    .buttonStyle(.borderless)
                } else {
                    Text(sourceLabel(for: product.source))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.secondarySystemBackground), in: Capsule())
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(productSelectionCardBackground, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(productSelectionCardBorder)
        )
    }

    private func customProductRow(customProduct: CustomProduct) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Text(customProduct.name)
                        .font(.body.weight(.semibold))
                        .multilineTextAlignment(.leading)

                    if customProduct.isAIGenerated {
                        Text(AppLocalizer.string("ai.meal.badge"))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.12), in: Capsule())
                    }
                }

                Text(appLanguage.localized("search.per_100g"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    metricTag(text: "\(customProduct.calories) \(appLanguage.localized("unit.kcal"))")
                    metricTag(text: macroShort("macro.protein.short", value: customProduct.protein))
                    metricTag(text: macroShort("macro.fat.short", value: customProduct.fat))
                    metricTag(text: macroShort("macro.carbs.short", value: customProduct.carbs))
                }
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 10) {
                Button(action: {
                    onCustomProductSelected(customProduct)
                }) {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 36, height: 36)
                        .background(Color.blue.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    deleteCustomProduct(customProduct)
                } label: {
                    Image(systemName: "trash")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(width: 36, height: 36)
                        .background(Color.red.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(productSelectionCardBackground, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(productSelectionCardBorder)
        )
    }


    // MARK: - Utils

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    private func refreshVisibleProducts() {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        let baseProducts = selectedFilter == .favorites ? cachedFilteredProducts : productCatalogStore.products
        let localMatches = trimmedSearch.isEmpty
            ? baseProducts
            : baseProducts.filter { $0.matches(trimmedSearch) }

        filteredProductsCache = Array(sortedProducts(localMatches).prefix(300))

        let customMatches = trimmedSearch.isEmpty
            ? customProducts
            : customProducts.filter { $0.name.localizedCaseInsensitiveContains(trimmedSearch) }

        filteredCustomProductsCache = sortedCustomProducts(customMatches)
    }

    private func scheduleExpandedResults() {
        expandsResultsTask?.cancel()
        showsExpandedResults = false

        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showsExpandedResults = true
            return
        }

        expandsResultsTask = Task {
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                showsExpandedResults = true
            }
        }
    }

    private func sortedProducts(_ products: [Product]) -> [Product] {
        products.sorted { a, b in
            let ca = usageCounts[a.name] ?? 0
            let cb = usageCounts[b.name] ?? 0
            if ca != cb { return ca > cb }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    private func sortedCustomProducts(_ products: [CustomProduct]) -> [CustomProduct] {
        products.sorted { a, b in
            let ca = usageCounts[a.name] ?? 0
            let cb = usageCounts[b.name] ?? 0
            if ca != cb { return ca > cb }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    // Частоты использования по FoodEntry (по имени продукта)
    private func loadUsageCountsIfNeeded() {
        guard let ownerId = sessionStore.firebaseUser?.uid, !ownerId.isEmpty else {
            usageCounts = [:]
            refreshVisibleProducts()
            return
        }

        usageCountsTask?.cancel()

        usageCountsTask = Task {
            if let cachedCounts = await ProductUsageCache.shared.counts(for: ownerId) {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    usageCounts = cachedCounts
                    refreshVisibleProducts()
                }
                return
            }

            await Task.yield()
            guard !Task.isCancelled else { return }

            let predicate = #Predicate<FoodEntry> {
                $0.ownerId == ownerId
            }

            let counts: [String: Int]
            do {
                let entries = try modelContext.fetch(FetchDescriptor<FoodEntry>(predicate: predicate))
                var map: [String: Int] = [:]
                for entry in entries {
                    let key = (entry.product?.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !key.isEmpty else { continue }
                    map[key, default: 0] += 1
                }
                counts = map
            } catch {
                counts = [:]
            }

            await ProductUsageCache.shared.store(counts, for: ownerId)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                usageCounts = counts
                refreshVisibleProducts()
            }
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
                refreshVisibleProducts()
            }
        } catch {}
    }

    private func loadCustomProducts() {
        let fd = FetchDescriptor<CustomProduct>()
        do {
            customProducts = try modelContext.fetch(fd)
            refreshVisibleProducts()
        } catch {}
    }

    private func loadFavorites() {
        let names = favoriteProductNames()
        for i in productCatalogStore.products.indices {
            productCatalogStore.products[i].isFavorite = names.contains(productCatalogStore.products[i].name)
        }
        cachedFilteredProducts = productCatalogStore.products.filter { $0.isFavorite }
        refreshVisibleProducts()
    }

    private func persistFavorites() {
        let names = Set(
            productCatalogStore.products
                .filter(\.isFavorite)
                .map(\.name)
        )
        UserDefaults.standard.set(Array(names).sorted(), forKey: Self.favoriteNamesKey)
    }

    private func favoriteProductNames() -> Set<String> {
        let names = UserDefaults.standard.stringArray(forKey: Self.favoriteNamesKey) ?? []
        return Set(names)
    }

    private func scheduleHybridSearch(immediate: Bool = false) {
        searchTask?.cancel()

        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty, selectedFilter == .all else {
            remoteProducts = []
            remoteSearchMessage = nil
            isSearchingRemotely = false
            currentSearchRoute = networkMonitor.isConnected ? .russianLocalThenOpenFoodFacts : .offlineLocal
            return
        }

        if !ProductSearchCoordinator.looksLikeBarcode(trimmedSearch), searchLanguage == .en, trimmedSearch.count < 3 {
            remoteProducts = []
            remoteSearchMessage = nil
            isSearchingRemotely = false
            currentSearchRoute = .englishUSDAThenLocal
            return
        }

        let delayNanoseconds: UInt64
        if immediate {
            delayNanoseconds = 0
        } else if ProductSearchCoordinator.looksLikeBarcode(trimmedSearch) {
            delayNanoseconds = 150_000_000
        } else if searchLanguage == .ru {
            delayNanoseconds = 900_000_000
        } else {
            delayNanoseconds = 500_000_000
        }

        let language = searchLanguage
        let localProducts = productCatalogStore.products
        let hasInternet = networkMonitor.isConnected

        searchTask = Task {
            if delayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }

            guard !Task.isCancelled else { return }

            await MainActor.run {
                isSearchingRemotely = hasInternet
                remoteSearchMessage = nil

                if ProductSearchCoordinator.looksLikeBarcode(trimmedSearch) {
                    currentSearchRoute = .barcodeOpenFoodFacts
                } else {
                    currentSearchRoute = language == .en ? .englishUSDAThenLocal : .russianLocalThenOpenFoodFacts
                }
            }

            let response = await ProductSearchCoordinator.shared.search(
                query: trimmedSearch,
                localProducts: localProducts,
                language: language,
                hasInternet: hasInternet
            )

            guard !Task.isCancelled else { return }

            await MainActor.run {
                remoteProducts = response.remoteProducts
                remoteSearchMessage = response.messageKey
                currentSearchRoute = response.route
                isSearchingRemotely = false
            }
        }
    }

    private func title(for filter: FilterType) -> String {
        switch filter {
        case .all:
            return appLanguage.localized("search.filter.all")
        case .favorites:
            return appLanguage.localized("search.filter.favorites")
        case .custom:
            return appLanguage.localized("search.filter.custom")
        }
    }

    private func nutritionSummary(for product: Product) -> String {
        nutritionSummary(
            calories: product.calories,
            protein: product.protein,
            fat: product.fat,
            carbs: product.carbs
        )
    }

    private func nutritionSummary(calories: Int, protein: Double, fat: Double, carbs: Double) -> String {
        String(
            format: appLanguage.localized("search.nutrition.summary"),
            locale: appLanguage.locale,
            calories,
            String(format: "%.1f", locale: appLanguage.locale, protein),
            String(format: "%.1f", locale: appLanguage.locale, fat),
            String(format: "%.1f", locale: appLanguage.locale, carbs)
        )
    }

    private func sourceLabel(for source: ProductSource) -> String {
        switch source {
        case .localCSV:
            return "CSV"
        case .usda:
            return "USDA"
        case .openFoodFacts:
            return "OFF"
        }
    }

    private var emptyMessageForCurrentFilter: String {
        switch selectedFilter {
        case .all:
            return appLanguage.localized("search.empty.all")
        case .favorites:
            return appLanguage.localized("search.empty.favorites")
        case .custom:
            return appLanguage.localized("search.empty.custom")
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(nil)
            .padding(.top, 8)
    }

    private func emptyStateRow(message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if selectedFilter == .custom {
                Button(appLanguage.localized("common.create")) {
                    isCreatingProduct = true
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(productSelectionCardBackground, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(productSelectionCardBorder)
        )
    }

    private func metricTag(text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(productSelectionInsetBackground, in: Capsule())
    }

    private func macroShort(_ key: String, value: Double) -> String {
        let formatted = String(format: "%.1f", locale: appLanguage.locale, value)
        return "\(appLanguage.localized(key)) \(formatted)"
    }

    private func actionPill(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(productSelectionCardBackground, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(productSelectionCardBorder)
                )
        }
        .buttonStyle(.plain)
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
                    Text(AppLocalizer.string("custom_product.new")).font(.largeTitle.bold())
                    Text(AppLocalizer.string("custom_product.subtitle"))
                        .font(.caption).foregroundStyle(.secondary)

                    field(AppLocalizer.string("custom_product.name"), text: $name, field: .name, kb: .default, submit: .next)
                        .onSubmit { focusedField = .calories }

                    field(AppLocalizer.string("custom_product.calories"), text: $calories, field: .calories, kb: .decimalPad, submit: .next)
                        .onSubmit { focusedField = .protein }

                    HStack(spacing: 12) {
                        field(AppLocalizer.string("custom_product.protein"), text: $protein, field: .protein, kb: .decimalPad, submit: .next)
                            .onSubmit { focusedField = .fat }
                        field(AppLocalizer.string("custom_product.fat"), text: $fat, field: .fat, kb: .decimalPad, submit: .next)
                            .onSubmit { focusedField = .carbs }
                        field(AppLocalizer.string("custom_product.carbs"), text: $carbs, field: .carbs, kb: .decimalPad, submit: .done)
                            .onSubmit { focusedField = nil }
                    }

                    VStack(spacing: 10) {
                        Button(AppLocalizer.string("common.create"), action: submit)
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .disabled(!isValid)
                            .frame(maxWidth: .infinity)

                        Button(AppLocalizer.string("common.cancel"), role: .destructive) { dismiss() }
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
                    Button(AppLocalizer.string("common.back")) { prev() }.disabled(focusedField == .name)
                    Button(AppLocalizer.string("common.next")) { next() }.disabled(focusedField == .carbs)
                    Spacer()
                    Button(AppLocalizer.string("common.done")) { focusedField = nil }
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
            .background(productSelectionCardBackground, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(focusedField == field ? Color.blue : productSelectionCardBorder,
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
        } catch {}
    }
}
