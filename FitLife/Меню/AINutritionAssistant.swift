import Foundation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

private struct AINutritionSuggestionIngredient: Decodable, Identifiable {
    let name: String
    let grams: Double
    let calories: Int
    let protein: Double
    let fat: Double
    let carbs: Double

    var id: String { "\(name)-\(grams)" }
}

private struct AINutritionSuggestion: Decodable, Identifiable {
    let name: String
    let summary: String
    let ingredients: [AINutritionSuggestionIngredient]
    let steps: [String]?

    var id: String { name }
    var calories: Int { ingredients.reduce(0) { $0 + max($1.calories, 0) } }
    var protein: Int { Int(ingredients.reduce(0) { $0 + max($1.protein, 0) }.rounded()) }
    var fat: Int { Int(ingredients.reduce(0) { $0 + max($1.fat, 0) }.rounded()) }
    var carbs: Int { Int(ingredients.reduce(0) { $0 + max($1.carbs, 0) }.rounded()) }
}

private struct AINutritionSuggestionResponse: Decodable {
    let suggestions: [AINutritionSuggestion]
}

private enum AINutritionAssistantError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case network
    case api

    var errorDescription: String? {
        let isRussian = AppLocalizer.currentLanguage == .russian
        switch self {
        case .missingAPIKey:
            return isRussian ? "Не настроен ключ AI-сервиса." : "The AI service key is not configured."
        case .invalidResponse:
            return isRussian ? "Не удалось разобрать рекомендации. Попробуйте ещё раз." : "The recommendations could not be read. Please try again."
        case .network:
            return isRussian ? "Не удалось связаться с AI-сервисом." : "The AI service could not be reached."
        case .api:
            return isRussian ? "AI-сервис временно недоступен." : "The AI service is temporarily unavailable."
        }
    }
}

private actor AINutritionSuggestionService {
    func suggestions(
        calories: Int,
        protein: Int,
        fat: Int,
        carbs: Int,
        meal: String,
        preference: String,
        availableProducts: [String],
        allowAdditionalProducts: Bool,
        language: AppLanguage
    ) async throws -> [AINutritionSuggestion] {
        try await requestSuggestions(body: [
            "mode": "plan",
            "calories": calories,
            "protein": protein,
            "fat": fat,
            "carbs": carbs,
            "meal": meal,
            "preference": preference,
            "availableProducts": Array(availableProducts.prefix(50)),
            "allowAdditionalProducts": allowAdditionalProducts,
            "language": language == .english ? "en" : "ru"
        ])
    }

    func suggestionsFromMenu(
        imageData: Data,
        calories: Int,
        protein: Int,
        fat: Int,
        carbs: Int,
        meal: String,
        preference: String,
        language: AppLanguage
    ) async throws -> [AINutritionSuggestion] {
        try await requestSuggestions(body: [
            "mode": "menu_image",
            "calories": calories,
            "protein": protein,
            "fat": fat,
            "carbs": carbs,
            "meal": meal,
            "preference": preference,
            "imageBase64": imageData.base64EncodedString(),
            "language": language == .english ? "en" : "ru"
        ])
    }

    private func requestSuggestions(body: [String: Any]) async throws -> [AINutritionSuggestion] {
        do {
            let data = try await FirebaseAIClient.post(
                functionName: "suggestMeals",
                body: body,
                timeout: 90
            )
            let decoded = try JSONDecoder().decode(AINutritionSuggestionResponse.self, from: data)
            guard decoded.suggestions.isEmpty == false else {
                throw AINutritionAssistantError.invalidResponse
            }
            return Array(decoded.suggestions.prefix(3))
        } catch is URLError {
            throw AINutritionAssistantError.network
        } catch let error as FirebaseAIClientError {
            if case .requestFailed(let code, _) = error, code == "missing_openai_key" {
                throw AINutritionAssistantError.missingAPIKey
            }
            throw AINutritionAssistantError.api
        } catch is DecodingError {
            throw AINutritionAssistantError.invalidResponse
        } catch {
            throw error
        }
    }
}

private struct AINutritionRecipeView: View {
    let suggestion: AINutritionSuggestion

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue

    private var theme: AppTheme { AppTheme(colorScheme) }
    private var isRussian: Bool { AppLanguage.from(rawValue: appLanguageRaw) == .russian }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(suggestion.name)
                        .font(.title2.bold())

                    Text(suggestion.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 14) {
                        Text("\(suggestion.calories) \(isRussian ? "ккал" : "kcal")")
                        Text("\(isRussian ? "Б" : "P") \(suggestion.protein)")
                        Text("\(isRussian ? "Ж" : "F") \(suggestion.fat)")
                        Text("\(isRussian ? "У" : "C") \(suggestion.carbs)")
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 22).fill(theme.card))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(theme.border))

                VStack(alignment: .leading, spacing: 12) {
                    Label(isRussian ? "Ингредиенты" : "Ingredients", systemImage: "basket.fill")
                        .font(.headline)

                    ForEach(suggestion.ingredients) { ingredient in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(ingredient.name)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text("\(Int(ingredient.grams.rounded())) \(isRussian ? "г" : "g")")
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .font(.subheadline)

                        if ingredient.id != suggestion.ingredients.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 22).fill(theme.card))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(theme.border))

                if let steps = suggestion.steps, steps.isEmpty == false {
                    VStack(alignment: .leading, spacing: 16) {
                        Label(isRussian ? "Приготовление" : "Preparation", systemImage: "list.number")
                            .font(.headline)

                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(theme.accent)
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(theme.accent.opacity(0.12)))

                                Text(step)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(18)
                    .background(RoundedRectangle(cornerRadius: 22).fill(theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(theme.border))
                }
            }
            .padding(16)
        }
        .background(theme.bg.ignoresSafeArea())
        .navigationTitle(isRussian ? "Рецепт" : "Recipe")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AINutritionPantryView: View {
    @Binding var products: [String]
    @Binding var allowAdditionalProducts: Bool

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue
    @State private var productDraft = ""

    private var theme: AppTheme { AppTheme(colorScheme) }
    private var isRussian: Bool { AppLanguage.from(rawValue: appLanguageRaw) == .russian }

    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    TextField(
                        isRussian ? "Например, картошка" : "For example, potatoes",
                        text: $productDraft
                    )
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .onSubmit(addProducts)

                    Button(action: addProducts) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(theme.accent.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)
                    .disabled(productDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel(isRussian ? "Добавить продукт" : "Add product")
                }
            } header: {
                Text(isRussian ? "Добавить продукт" : "Add a product")
            } footer: {
                Text(isRussian
                     ? "Можно ввести несколько продуктов через запятую."
                     : "You can enter several products separated by commas.")
            }

            Section(isRussian ? "В наличии" : "Available") {
                if products.isEmpty {
                    Label(
                        isRussian ? "Продукты пока не добавлены" : "No products added yet",
                        systemImage: "basket"
                    )
                    .foregroundStyle(.secondary)
                } else {
                    ForEach(products, id: \.self) { product in
                        Label(product, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.primary)
                    }
                    .onDelete(perform: deleteProducts)
                }
            }

            Section {
                Toggle(
                    isRussian ? "Можно добавить другие продукты" : "Allow additional products",
                    isOn: $allowAdditionalProducts
                )
                .tint(theme.accent)
            } footer: {
                Text(isRussian
                     ? "AI будет использовать продукты из списка и при необходимости добавит минимум недостающих ингредиентов."
                     : "AI will use the listed products and add only the minimum missing ingredients when needed.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.bg.ignoresSafeArea())
        .navigationTitle(isRussian ? "Продукты дома" : "Products at home")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if products.isEmpty == false {
                EditButton()
            }
        }
        .onChange(of: products) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "aiNutritionAvailableProducts")
        }
    }

    private func addProducts() {
        let separators = CharacterSet(charactersIn: ",;\n")
        let candidates = productDraft
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        for candidate in candidates where products.contains(where: {
            $0.localizedCaseInsensitiveCompare(candidate) == .orderedSame
        }) == false {
            products.append(candidate)
        }
        productDraft = ""
    }

    private func deleteProducts(at offsets: IndexSet) {
        products.remove(atOffsets: offsets)
    }
}

struct AINutritionAssistantView: View {
    let selectedDate: Date
    let selectedGender: Gender
    let ownerId: String
    let remainingCalories: Int
    let remainingProtein: Int
    let remainingFat: Int
    let remainingCarbs: Int
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue
    @AppStorage("aiNutritionAllowAdditionalProducts") private var allowAdditionalProducts = true
    @AppStorage("aiNutritionUseAvailableProducts") private var useAvailableProducts = true

    @State private var selectedMeal = MealType.lunch
    @State private var preference = ""
    @State private var availableProducts = UserDefaults.standard.stringArray(forKey: "aiNutritionAvailableProducts") ?? []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var suggestions: [AINutritionSuggestion] = []
    @State private var savedSuggestionIDs: Set<String> = []
    @State private var selectedMenuPhotoItem: PhotosPickerItem?
    @State private var isShowingMenuPhotoPicker = false
    @State private var isShowingMenuCamera = false
    @State private var isLoadingMenuPhoto = false
    @State private var isRestaurantMenuResult = false

    private let service = AINutritionSuggestionService()
    private var theme: AppTheme { AppTheme(colorScheme) }
    private var language: AppLanguage { AppLanguage.from(rawValue: appLanguageRaw) }
    private var isRussian: Bool { language == .russian }
    private var hasRemainingMacroTarget: Bool {
        remainingProtein > 0 || remainingFat > 0 || remainingCarbs > 0
    }
    private var canGenerateSuggestions: Bool {
        remainingCalories > 0 || hasRemainingMacroTarget
    }
    private var needsCalorieOverageWarning: Bool {
        remainingCalories <= 0 && hasRemainingMacroTarget
    }
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    remainingCard
                    quickActionsCard
                    settingsCard

                    if needsCalorieOverageWarning {
                        Label {
                            Text(isRussian
                                 ? "Цель по калориям достигнута. Для добора КБЖУ потребуется превысить калории."
                                 : "Your calorie goal is reached. Completing the remaining macros will require exceeding it.")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                        }
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.orange.opacity(0.11)))
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }

                    Button {
                        generateSuggestions()
                    } label: {
                        HStack(spacing: 10) {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "sparkles")
                            }
                            Text(isLoading
                                 ? (isRussian ? "Подбираю блюда…" : "Finding meals…")
                                 : (isRussian ? "Подобрать блюда" : "Suggest meals"))
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 18).fill(HomeColors.primaryActionGradient))
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading || canGenerateSuggestions == false)
                    .opacity(canGenerateSuggestions ? 1 : 0.5)

                    ForEach(suggestions) { suggestion in
                        suggestionCard(suggestion)
                    }

                    if suggestions.isEmpty && isLoading == false {
                        ContentUnavailableView(
                            isRussian ? "Что вам приготовить?" : "What should you eat?",
                            systemImage: "fork.knife.circle",
                            description: Text(isRussian
                                              ? "Помощник учтёт оставшиеся КБЖУ и предложит три блюда."
                                              : "The assistant will use your remaining macros to suggest three meals.")
                        )
                        .padding(.vertical, 20)
                    }
                }
                .padding(16)
            }
            .background(theme.bg.ignoresSafeArea())
            .navigationTitle(isRussian ? "AI-помощник" : "AI Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isRussian ? "Закрыть" : "Close") { dismiss() }
                }
            }
        }
        .fullScreenCover(isPresented: $isShowingMenuCamera) {
            AIMenuCameraCaptureView(
                onImageCaptured: { image in
                    isShowingMenuCamera = false
                    analyzeRestaurantMenu(image)
                },
                onCancel: {
                    isShowingMenuCamera = false
                }
            )
            .ignoresSafeArea()
        }
        .photosPicker(
            isPresented: $isShowingMenuPhotoPicker,
            selection: $selectedMenuPhotoItem,
            matching: .images
        )
        .onChange(of: selectedMenuPhotoItem) { _, item in
            guard let item else { return }
            loadRestaurantMenuPhoto(item)
        }
    }

    private var remainingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isRussian ? "Осталось сегодня" : "Remaining today")
                .font(.headline)

            HStack(spacing: 8) {
                remainingMetric("\(remainingCalories)", isRussian ? "ккал" : "kcal", theme.accent)
                remainingMetric("\(remainingProtein)", isRussian ? "белки" : "protein", theme.protein)
                remainingMetric("\(remainingFat)", isRussian ? "жиры" : "fat", theme.fat)
                remainingMetric("\(remainingCarbs)", isRussian ? "углеводы" : "carbs", theme.carb)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22).fill(theme.card))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(theme.border))
    }

    private func remainingMetric(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
    }

    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isRussian ? "Что сделать?" : "What would you like?")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                quickMealButton(.breakfast, systemImage: "sunrise.fill")
                quickMealButton(.lunch, systemImage: "fork.knife")
                quickMealButton(.dinner, systemImage: "moon.stars.fill")

                Menu {
                    Button {
                        openMenuCamera()
                    } label: {
                        Label(
                            isRussian ? "Сфотографировать" : "Take a photo",
                            systemImage: "camera.fill"
                        )
                    }

                    Button {
                        isShowingMenuPhotoPicker = true
                    } label: {
                        Label(
                            isRussian ? "Выбрать из галереи" : "Choose from library",
                            systemImage: "photo.on.rectangle"
                        )
                    }
                } label: {
                    quickActionLabel(
                        title: isRussian ? "Фото меню" : "Menu photo",
                        systemImage: "camera.viewfinder",
                        tint: .purple,
                        isLoading: isLoadingMenuPhoto
                    )
                }
                .buttonStyle(.plain)
                .disabled(isLoading || isLoadingMenuPhoto)
            }

            Text(isRussian
                 ? "Сфотографируйте меню ресторана — помощник выберет подходящие позиции и оценит КБЖУ."
                 : "Photograph a restaurant menu and the assistant will choose suitable dishes and estimate their macros.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22).fill(theme.card))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(theme.border))
    }

    private func quickMealButton(_ meal: MealType, systemImage: String) -> some View {
        Button {
            generateSuggestions(for: meal)
        } label: {
            quickActionLabel(
                title: isRussian ? "Подобрать: \(meal.displayName.lowercased())" : "Suggest \(meal.displayName.lowercased())",
                systemImage: systemImage,
                tint: theme.accent,
                isLoading: false
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading || isLoadingMenuPhoto || canGenerateSuggestions == false)
    }

    private func quickActionLabel(
        title: String,
        systemImage: String,
        tint: Color,
        isLoading: Bool
    ) -> some View {
        HStack(spacing: 10) {
            if isLoading {
                ProgressView()
                    .tint(tint)
            } else {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
            }

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 15).fill(tint.opacity(0.11)))
    }

    private var settingsCard: some View {
        VStack(spacing: 14) {
            HStack {
                Label(isRussian ? "Приём пищи" : "Meal", systemImage: "fork.knife")
                Spacer()
                Picker("", selection: $selectedMeal) {
                    ForEach(MealType.allCases) { meal in
                        Text(meal.displayName).tag(meal)
                    }
                }
                .labelsHidden()
            }

            Divider()

            TextField(
                isRussian ? "Например: быстро, без готовки, сладкое" : "For example: quick, no cooking, something sweet",
                text: $preference,
                axis: .vertical
            )
            .lineLimit(2...4)

            Divider()

            NavigationLink {
                AINutritionPantryView(
                    products: $availableProducts,
                    allowAdditionalProducts: $allowAdditionalProducts
                )
            } label: {
                HStack(spacing: 12) {
                    Label(isRussian ? "Продукты дома" : "Products at home", systemImage: "cabinet.fill")

                    Spacer()

                    Text(availableProducts.isEmpty
                         ? (isRussian ? "Добавить" : "Add")
                         : "\(availableProducts.count)")
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if availableProducts.isEmpty == false {
                Divider()

                Toggle(
                    isRussian ? "Учитывать продукты дома" : "Use products at home",
                    isOn: $useAvailableProducts
                )
                .font(.subheadline)
                .tint(theme.accent)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22).fill(theme.card))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(theme.border))
    }

    private func suggestionCard(_ suggestion: AINutritionSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if isRestaurantMenuResult {
                Label(
                    isRussian ? "Выбор из меню · оценка" : "From menu · estimate",
                    systemImage: "camera.viewfinder"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.purple)
            }

            Text(suggestion.name)
                .font(.headline)
            Text(suggestion.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(suggestion.ingredients.map { "\($0.name) \(Int($0.grams.rounded())) г" }.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)

            if suggestion.steps?.isEmpty == false {
                NavigationLink {
                    AINutritionRecipeView(suggestion: suggestion)
                } label: {
                    HStack {
                        Label(isRussian ? "Как приготовить" : "How to prepare", systemImage: "list.number")
                            .font(.subheadline.weight(.semibold))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
            }

            HStack(spacing: 10) {
                Text("\(suggestion.calories) \(isRussian ? "ккал" : "kcal")")
                Text("Б \(suggestion.protein)")
                Text("Ж \(suggestion.fat)")
                Text("У \(suggestion.carbs)")
            }
            .font(.caption.weight(.semibold))

            Button {
                save(suggestion)
            } label: {
                Label(
                    savedSuggestionIDs.contains(suggestion.id)
                        ? (isRussian ? "Добавлено" : "Added")
                        : (isRussian ? "Добавить в рацион" : "Add to diary"),
                    systemImage: savedSuggestionIDs.contains(suggestion.id) ? "checkmark" : "plus"
                )
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14).fill(theme.accent.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.accent)
            .disabled(savedSuggestionIDs.contains(suggestion.id))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22).fill(theme.card))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(theme.border))
    }

    private func generateSuggestions(for meal: MealType? = nil) {
        let targetMeal = meal ?? selectedMeal
        selectedMeal = targetMeal
        isLoading = true
        errorMessage = nil
        suggestions = []
        isRestaurantMenuResult = false

        Task {
            do {
                let result = try await service.suggestions(
                    calories: remainingCalories,
                    protein: remainingProtein,
                    fat: remainingFat,
                    carbs: remainingCarbs,
                    meal: targetMeal.displayName,
                    preference: preference,
                    availableProducts: useAvailableProducts ? availableProducts : [],
                    allowAdditionalProducts: allowAdditionalProducts,
                    language: language
                )
                await MainActor.run {
                    suggestions = result
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func openMenuCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            errorMessage = isRussian
                ? "Камера недоступна. Выберите фотографию меню из галереи."
                : "The camera is unavailable. Choose a menu photo from your library."
            return
        }
        isShowingMenuCamera = true
    }

    private func loadRestaurantMenuPhoto(_ item: PhotosPickerItem) {
        isLoadingMenuPhoto = true
        errorMessage = nil

        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    throw AINutritionAssistantError.invalidResponse
                }
                await MainActor.run {
                    selectedMenuPhotoItem = nil
                    analyzeRestaurantMenu(image)
                }
            } catch {
                await MainActor.run {
                    selectedMenuPhotoItem = nil
                    isLoadingMenuPhoto = false
                    errorMessage = isRussian
                        ? "Не удалось открыть фотографию меню."
                        : "The menu photo could not be opened."
                }
            }
        }
    }

    private func analyzeRestaurantMenu(_ image: UIImage) {
        guard let imageData = preparedMenuImageData(from: image) else {
            isLoadingMenuPhoto = false
            errorMessage = isRussian
                ? "Не удалось подготовить фотографию меню."
                : "The menu photo could not be prepared."
            return
        }

        isLoadingMenuPhoto = true
        isLoading = true
        errorMessage = nil
        suggestions = []
        isRestaurantMenuResult = true

        Task {
            do {
                let result = try await service.suggestionsFromMenu(
                    imageData: imageData,
                    calories: remainingCalories,
                    protein: remainingProtein,
                    fat: remainingFat,
                    carbs: remainingCarbs,
                    meal: selectedMeal.displayName,
                    preference: preference,
                    language: language
                )
                await MainActor.run {
                    suggestions = result
                    isLoading = false
                    isLoadingMenuPhoto = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                    isLoadingMenuPhoto = false
                }
            }
        }
    }

    private func preparedMenuImageData(from image: UIImage) -> Data? {
        let maxDimension: CGFloat = 2_000
        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }

        let scale = min(1, maxDimension / max(sourceSize.width, sourceSize.height))
        let targetSize = CGSize(
            width: max(1, (sourceSize.width * scale).rounded()),
            height: max(1, (sourceSize.height * scale).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.78)
    }

    private func save(_ suggestion: AINutritionSuggestion) {
        let validIngredients = suggestion.ingredients.filter {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && $0.grams > 0
        }
        guard validIngredients.isEmpty == false else { return }

        let groupID = UUID().uuidString
        for ingredient in validIngredients {
            let product = Product(
                name: ingredient.name,
                protein: ingredient.protein,
                fat: ingredient.fat,
                carbs: ingredient.carbs,
                calories: ingredient.calories,
                isFavorite: false,
                isCustom: true
            )
            let entry = FoodEntry(
                date: selectedDate,
                mealType: selectedMeal.rawValue,
                product: product,
                portion: min(max(ingredient.grams.safeFinite, 1), 10_000),
                gender: selectedGender,
                ownerId: ownerId,
                aiMealGroupID: groupID,
                aiMealName: suggestion.name
            )
            modelContext.insert(entry)
        }

        do {
            try modelContext.save()
            savedSuggestionIDs.insert(suggestion.id)
            onSaved()
            LocalReminderScheduler.rescheduleMealRemindersIfEnabled(
                modelContext: modelContext,
                ownerId: ownerId,
                gender: selectedGender
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AIMenuCameraCaptureView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageCaptured: onImageCaptured, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.cameraCaptureMode = .photo
        controller.delegate = context.coordinator
        controller.modalPresentationStyle = .fullScreen
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImageCaptured: (UIImage) -> Void
        let onCancel: () -> Void

        init(onImageCaptured: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImageCaptured = onImageCaptured
            self.onCancel = onCancel
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage else {
                onCancel()
                return
            }
            onImageCaptured(image)
        }
    }
}
