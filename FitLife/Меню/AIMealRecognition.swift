import SwiftUI
import SwiftData
import UIKit

private enum OpenAIConfiguration {
    static var apiKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "OpenAIAPIKey") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

private enum AIMealRecognitionError: LocalizedError {
    case missingAPIKey
    case invalidImage
    case invalidResponse
    case emptyIngredients
    case cameraUnavailable
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return AppLocalizer.string("ai.meal.error.missing_key")
        case .invalidImage:
            return AppLocalizer.string("ai.meal.error.image")
        case .invalidResponse:
            return AppLocalizer.string("ai.meal.error.response")
        case .emptyIngredients:
            return AppLocalizer.string("ai.meal.error.empty")
        case .cameraUnavailable:
            return AppLocalizer.string("ai.meal.error.camera")
        case .apiError(let message):
            return message
        }
    }
}

private struct AIMealRecognitionResponse: Decodable {
    let dishName: String
    let ingredients: [AIMealRecognitionIngredient]
    let notes: String?
    let isBeverage: Bool?
    let portionSizeGuess: String?

    enum CodingKeys: String, CodingKey {
        case dishName = "dish_name"
        case ingredients
        case notes
        case isBeverage = "is_beverage"
        case portionSizeGuess = "portion_size_guess"
    }
}

private struct AIMealRecognitionIngredient: Decodable {
    let name: String
    let grams: Double
    let calories: Int
    let protein: Double
    let fat: Double
    let carbs: Double
    let confidence: String?
}

private struct AIMealIngredientDraft: Identifiable, Hashable {
    let id: UUID
    var name: String
    var gramsText: String
    var calories: Int
    var protein: Double
    var fat: Double
    var carbs: Double
    var confidence: String
    private let baseGrams: Double
    private let baseCalories: Int
    private let baseProtein: Double
    private let baseFat: Double
    private let baseCarbs: Double

    init(
        id: UUID = UUID(),
        name: String,
        gramsText: String,
        calories: Int,
        protein: Double,
        fat: Double,
        carbs: Double,
        confidence: String
    ) {
        self.id = id
        self.name = name
        self.gramsText = gramsText
        self.calories = calories
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.confidence = confidence
        self.baseGrams = Double(gramsText.replacingOccurrences(of: ",", with: ".")) ?? 0
        self.baseCalories = calories
        self.baseProtein = protein
        self.baseFat = fat
        self.baseCarbs = carbs
    }

    var gramsValue: Double {
        Double(gramsText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    mutating func applyMultiplier(_ multiplier: Double) {
        let scaledGrams = max(baseGrams * multiplier, 0)
        gramsText = Self.formattedDecimalString(scaledGrams)
        calories = max(Int((Double(baseCalories) * multiplier).rounded()), 0)
        protein = max(baseProtein * multiplier, 0)
        fat = max(baseFat * multiplier, 0)
        carbs = max(baseCarbs * multiplier, 0)
    }

    private static func formattedDecimalString(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded.rounded(.towardZero) == rounded {
            return String(Int(rounded))
        }
        return String(format: "%.1f", rounded).replacingOccurrences(of: ".", with: ",")
    }
}

private struct AIMealDraft {
    var dishName: String
    var notes: String
    var items: [AIMealIngredientDraft]
    var isBeverage: Bool
    var portionSize: AIPortionSize
    var sugarOption: AIBeverageSugarOption
}

private enum AIPortionSize: String, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var multiplier: Double {
        switch self {
        case .small: 0.8
        case .medium: 1.0
        case .large: 1.25
        }
    }

    var localizationKey: String {
        switch self {
        case .small: "ai.meal.portion.small"
        case .medium: "ai.meal.portion.medium"
        case .large: "ai.meal.portion.large"
        }
    }

    init(guess: String?) {
        switch guess?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "small":
            self = .small
        case "large":
            self = .large
        default:
            self = .medium
        }
    }
}

private enum AIBeverageSugarOption: String, CaseIterable, Identifiable {
    case none
    case oneSpoon
    case twoSpoons

    var id: String { rawValue }

    var grams: Double {
        switch self {
        case .none: 0
        case .oneSpoon: 5
        case .twoSpoons: 10
        }
    }

    var localizationKey: String {
        switch self {
        case .none: "ai.meal.sugar.none"
        case .oneSpoon: "ai.meal.sugar.one"
        case .twoSpoons: "ai.meal.sugar.two"
        }
    }
}

private actor OpenAIMealRecognitionService {
    func recognizeMeal(from imageData: Data, language: AppLanguage) async throws -> AIMealRecognitionResponse {
        let apiKey = OpenAIConfiguration.apiKey
        guard !apiKey.isEmpty else {
            throw AIMealRecognitionError.missingAPIKey
        }

        let base64Image = imageData.base64EncodedString()
        let promptLanguage = language == .russian ? "Russian" : "English"
        let systemPrompt = """
        Return JSON only. Analyze a single meal photo and estimate the visible edible components.
        Respond in \(promptLanguage).
        Return an object with:
        - dish_name: short meal name
        - ingredients: array of 1 to 8 items
        - notes: short uncertainty note
        - is_beverage: boolean
        - portion_size_guess: one of small, medium, large

        Each ingredient must contain:
        - name
        - grams
        - calories
        - protein
        - fat
        - carbs
        - confidence

        Rules:
        - exclude plate, tableware, background, packaging
        - calories and macros must describe the estimated ingredient portion on the plate, not per 100 g
        - grams must be a realistic number
        - if the photo is a drink, set is_beverage to true
        - choose portion_size_guess based on the visible serving size
        - include sugar, syrup, sauce, oil, butter or milk when they are likely present
        - if unsure, still make the best estimate and lower confidence
        """

        let payload: [String: Any] = [
            "model": "gpt-4.1-mini",
            "input": [
                [
                    "role": "system",
                    "content": [
                        [
                            "type": "input_text",
                            "text": systemPrompt
                        ]
                    ]
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "input_text",
                            "text": "Analyze this food photo and return JSON."
                        ],
                        [
                            "type": "input_image",
                            "image_url": "data:image/jpeg;base64,\(base64Image)",
                            "detail": "high"
                        ]
                    ]
                ]
            ],
            "text": [
                "format": [
                    "type": "json_object"
                ]
            ]
        ]

        let body = try JSONSerialization.data(withJSONObject: payload)
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIMealRecognitionError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = Self.apiErrorMessage(from: data) ?? AppLocalizer.string("ai.meal.error.request")
            throw AIMealRecognitionError.apiError(message)
        }

        guard let text = Self.extractOutputText(from: data),
              let jsonData = text.data(using: .utf8) else {
            throw AIMealRecognitionError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(AIMealRecognitionResponse.self, from: jsonData)
        guard !decoded.ingredients.isEmpty else {
            throw AIMealRecognitionError.emptyIngredients
        }
        return decoded
    }

    private static func extractOutputText(from data: Data) -> String? {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let outputText = jsonObject["output_text"] as? String,
           !outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return outputText
        }

        if let outputs = jsonObject["output"] as? [[String: Any]] {
            for output in outputs {
                if let contents = output["content"] as? [[String: Any]] {
                    for content in contents {
                        if let text = content["text"] as? String,
                           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            return text
                        }
                    }
                }
            }
        }

        return nil
    }

    private static func apiErrorMessage(from data: Data) -> String? {
        guard
            let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let error = jsonObject["error"] as? [String: Any],
            let message = error["message"] as? String
        else {
            return nil
        }

        return message
    }
}

struct AIMealRecognitionFlowView: View {
    let selectedDate: Date
    let selectedGender: Gender
    let preselectedMeal: MealType?
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var sessionStore: AppSessionStore
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue

    @State private var selectedMeal: MealType
    @State private var step: Step = .camera
    @State private var draft: AIMealDraft?
    @State private var capturedImage: UIImage?
    @State private var isShowingCamera = false
    @State private var isSaving = false

    private let recognitionService = OpenAIMealRecognitionService()

    init(
        selectedDate: Date,
        selectedGender: Gender,
        preselectedMeal: MealType? = nil,
        onSaved: @escaping () -> Void
    ) {
        self.selectedDate = selectedDate
        self.selectedGender = selectedGender
        self.preselectedMeal = preselectedMeal
        self.onSaved = onSaved
        _selectedMeal = State(initialValue: preselectedMeal ?? .breakfast)
    }

    private enum Step: Equatable {
        case camera
        case analyzing
        case confirmation
        case error(String)
    }

    private var appLanguage: AppLanguage {
        AppLanguage.from(rawValue: appLanguageRaw)
    }

    private var hasValidItems: Bool {
        guard let draft else { return false }
        return draft.items.contains {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.gramsValue > 0
        }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(AppLocalizer.string("ai.meal.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(AppLocalizer.string("common.close")) {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        if step == .confirmation {
                            Button(AppLocalizer.string("ai.meal.retake")) {
                                reopenCamera()
                            }
                        }
                    }
                }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            AICameraCaptureView(
                onImageCaptured: { image in
                    isShowingCamera = false
                    handleCapturedImage(image)
                },
                onCancel: {
                    isShowingCamera = false
                    if draft == nil {
                        dismiss()
                    }
                }
            )
            .ignoresSafeArea()
        }
        .onAppear {
            if case .camera = step {
                presentCameraIfPossible()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .camera, .analyzing:
            VStack(spacing: 18) {
                Spacer()
                ProgressView()
                    .controlSize(.large)
                Text(AppLocalizer.string("ai.meal.analyzing"))
                    .font(.headline)
                Text(AppLocalizer.string("ai.meal.analyzing.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
            }

        case .error(let message):
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 42))
                    .foregroundStyle(.orange)
                Text(AppLocalizer.string("ai.meal.error.title"))
                    .font(.title3.weight(.bold))
                Text(message)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                Button(AppLocalizer.string("ai.meal.retry")) {
                    reopenCamera()
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }

        case .confirmation:
            if let draft {
                confirmationContent(draft: draft)
            }
        }
    }

    private func confirmationContent(draft: AIMealDraft) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if let capturedImage {
                    Image(uiImage: capturedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(AppLocalizer.string("ai.meal.dish_name"))
                        .font(.subheadline.weight(.semibold))

                    TextField(AppLocalizer.string("ai.meal.dish_name.placeholder"), text: binding(\.dishName))
                        .textFieldStyle(.roundedBorder)

                    if preselectedMeal == nil {
                        Picker(AppLocalizer.string("ai.meal.meal_picker"), selection: $selectedMeal) {
                            ForEach(MealType.allCases) { meal in
                                Text(meal.displayName).tag(meal)
                            }
                        }
                        .pickerStyle(.segmented)
                    } else {
                        mealBadge(selectedMeal.displayName)
                    }

                    if !draft.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(draft.notes)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))

                VStack(alignment: .leading, spacing: 12) {
                    Text(AppLocalizer.string("ai.meal.clarify.title"))
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(AppLocalizer.string("ai.meal.portion.title"))
                            .font(.subheadline.weight(.semibold))

                        HStack(spacing: 8) {
                            ForEach(AIPortionSize.allCases) { portion in
                                quickOptionChip(
                                    title: AppLocalizer.string(portion.localizationKey),
                                    isSelected: draft.portionSize == portion
                                ) {
                                    applyPortionSize(portion)
                                }
                            }
                        }
                    }

                    if draft.isBeverage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(AppLocalizer.string("ai.meal.sugar.title"))
                                .font(.subheadline.weight(.semibold))

                            HStack(spacing: 8) {
                                ForEach(AIBeverageSugarOption.allCases) { option in
                                    quickOptionChip(
                                        title: AppLocalizer.string(option.localizationKey),
                                        isSelected: draft.sugarOption == option
                                    ) {
                                        applySugarOption(option)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))

                VStack(alignment: .leading, spacing: 12) {
                    Text(AppLocalizer.string("ai.meal.ingredients"))
                        .font(.headline)

                    ForEach(Array(binding(\.items).wrappedValue.enumerated()), id: \.element.id) { index, item in
                        AIMealIngredientCard(
                            item: itemBinding(at: index),
                            onRemove: {
                                self.draft?.items.removeAll { $0.id == item.id }
                            }
                        )
                    }

                    Button {
                        self.draft?.items.append(
                            AIMealIngredientDraft(
                                name: "",
                                gramsText: "100",
                                calories: 0,
                                protein: 0,
                                fat: 0,
                                carbs: 0,
                                confidence: "low"
                            )
                        )
                    } label: {
                        Label(AppLocalizer.string("ai.meal.add_ingredient"), systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    saveRecognizedMeal()
                } label: {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(AppLocalizer.string("ai.meal.save"))
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving || !hasValidItems)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private func mealBadge(_ title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "fork.knife")
                .foregroundStyle(.secondary)
            Text(title)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func quickOptionChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    isSelected ? Color.accentColor : Color(.systemBackground),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AIMealDraft, Value>) -> Binding<Value> {
        Binding(
            get: { draft![keyPath: keyPath] },
            set: { draft![keyPath: keyPath] = $0 }
        )
    }

    private func itemBinding(at index: Int) -> Binding<AIMealIngredientDraft> {
        Binding(
            get: { draft!.items[index] },
            set: { draft!.items[index] = $0 }
        )
    }

    private func presentCameraIfPossible() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            step = .error(AIMealRecognitionError.cameraUnavailable.localizedDescription)
            return
        }

        DispatchQueue.main.async {
            isShowingCamera = true
        }
    }

    private func reopenCamera() {
        step = .camera
        presentCameraIfPossible()
    }

    private func handleCapturedImage(_ image: UIImage) {
        capturedImage = image
        step = .analyzing

        Task {
            do {
                guard let data = image.jpegData(compressionQuality: 0.82) else {
                    throw AIMealRecognitionError.invalidImage
                }
                let response = try await recognitionService.recognizeMeal(from: data, language: appLanguage)
                await MainActor.run {
                    draft = AIMealDraft(
                        dishName: response.dishName,
                        notes: response.notes ?? "",
                        items: response.ingredients.map {
                            AIMealIngredientDraft(
                                name: $0.name,
                                gramsText: String(Int($0.grams.rounded())),
                                calories: $0.calories,
                                protein: $0.protein,
                                fat: $0.fat,
                                carbs: $0.carbs,
                                confidence: $0.confidence ?? "medium"
                            )
                        },
                        isBeverage: response.isBeverage ?? false,
                        portionSize: AIPortionSize(guess: response.portionSizeGuess),
                        sugarOption: .none
                    )
                    applyPortionSize(draft?.portionSize ?? .medium)
                    step = .confirmation
                }
            } catch {
                await MainActor.run {
                    step = .error(error.localizedDescription)
                }
            }
        }
    }

    private func saveRecognizedMeal() {
        guard let draft else { return }
        let items = draft.items.filter {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.gramsValue > 0
        }
        guard !items.isEmpty else { return }

        isSaving = true
        let ownerId = sessionStore.firebaseUser?.uid ?? ""
        let aiMealGroupID = UUID().uuidString
        let normalizedDishName = draft.dishName.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            upsertCustomMealTemplate(from: draft, items: items)

            for item in items {
                let productForEntry = Product(
                    name: item.name,
                    protein: item.protein,
                    fat: item.fat,
                    carbs: item.carbs,
                    calories: item.calories,
                    isFavorite: false,
                    isCustom: true
                )

                let entry = FoodEntry(
                    date: selectedDate,
                    mealType: selectedMeal.rawValue,
                    product: productForEntry,
                    portion: item.gramsValue,
                    gender: selectedGender,
                    ownerId: ownerId,
                    isFavorite: false,
                    aiMealGroupID: aiMealGroupID,
                    aiMealName: normalizedDishName.isEmpty ? nil : normalizedDishName
                )
                modelContext.insert(entry)
            }

            try modelContext.save()

            if !ownerId.isEmpty {
                Task {
                    for item in items {
                        await ProductUsageCache.shared.increment(productName: item.name, for: ownerId)
                    }
                }
            }

            onSaved()
            dismiss()
        } catch {
            step = .error(error.localizedDescription)
        }

        isSaving = false
    }

    private func upsertCustomMealTemplate(from draft: AIMealDraft, items: [AIMealIngredientDraft]) {
        let templateName = draft.dishName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !templateName.isEmpty else { return }

        let totalGrams = items.reduce(0) { $0 + $1.gramsValue }
        guard totalGrams > 0 else { return }

        let totalCalories = items.reduce(0) { $0 + Double($1.calories) }
        let totalProtein = items.reduce(0) { $0 + $1.protein }
        let totalFat = items.reduce(0) { $0 + $1.fat }
        let totalCarbs = items.reduce(0) { $0 + $1.carbs }
        let normalization = 100 / totalGrams

        let normalizedCalories = Int((totalCalories * normalization).rounded())
        let normalizedProtein = totalProtein * normalization
        let normalizedFat = totalFat * normalization
        let normalizedCarbs = totalCarbs * normalization

        let descriptor = FetchDescriptor<CustomProduct>()
        let existingProducts = (try? modelContext.fetch(descriptor)) ?? []

        if let existing = existingProducts.first(where: {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare(templateName) == .orderedSame
        }) {
            existing.protein = normalizedProtein
            existing.fat = normalizedFat
            existing.carbs = normalizedCarbs
            existing.calories = normalizedCalories
            existing.isAIGenerated = true
        } else {
            let template = CustomProduct(
                name: templateName,
                protein: normalizedProtein,
                fat: normalizedFat,
                carbs: normalizedCarbs,
                calories: normalizedCalories,
                isAIGenerated: true
            )
            modelContext.insert(template)
        }
    }

    private func applyPortionSize(_ portionSize: AIPortionSize) {
        guard var draft else { return }
        draft.portionSize = portionSize
        draft.items = draft.items.map { item in
            var updated = item
            updated.applyMultiplier(portionSize.multiplier)
            return updated
        }
        self.draft = draft
        if draft.isBeverage {
            applySugarOption(draft.sugarOption)
        }
    }

    private func applySugarOption(_ option: AIBeverageSugarOption) {
        guard var draft else { return }
        draft.sugarOption = option
        let sugarName = AppLocalizer.string("ai.meal.sugar.ingredient")
        draft.items.removeAll {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(sugarName) == .orderedSame
        }

        if option.grams > 0 {
            draft.items.append(
                AIMealIngredientDraft(
                    name: sugarName,
                    gramsText: String(Int(option.grams.rounded())),
                    calories: Int((option.grams * 4).rounded()),
                    protein: 0,
                    fat: 0,
                    carbs: option.grams,
                    confidence: "user"
                )
            )
        }

        self.draft = draft
    }
}

private struct AIMealIngredientCard: View {
    @Binding var item: AIMealIngredientDraft
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                TextField(AppLocalizer.string("ai.meal.ingredient_name"), text: $item.name)
                    .textFieldStyle(.roundedBorder)

                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            HStack(spacing: 12) {
                TextField(AppLocalizer.string("portion.grams"), text: $item.gramsText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: item.gramsText) { _, newValue in
                        item.gramsText = sanitizedNumberString(newValue)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(item.calories) \(AppLocalizer.string("unit.kcal"))")
                        .font(.subheadline.weight(.semibold))
                    Text(
                        AppLocalizer.format(
                            "ai.meal.macros.value",
                            Int(item.protein.rounded()),
                            Int(item.fat.rounded()),
                            Int(item.carbs.rounded())
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Label(AppLocalizer.string("ai.meal.match.ai"), systemImage: "sparkles")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func sanitizedNumberString(_ text: String) -> String {
        let filtered = text.filter { $0.isNumber || $0 == "," || $0 == "." }
        let normalized = filtered.replacingOccurrences(of: ",", with: ".")
        let parts = normalized.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count > 1 else { return filtered }
        return String(parts[0]) + "," + String(parts[1])
    }
}

private struct AICameraCaptureView: UIViewControllerRepresentable {
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
            if let image = info[.originalImage] as? UIImage {
                onImageCaptured(image)
            } else {
                onCancel()
            }
        }
    }
}
