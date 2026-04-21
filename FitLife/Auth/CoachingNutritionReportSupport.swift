import SwiftUI
import SwiftData
import FirebaseFirestore

struct CoachingNutritionItemSnapshot: Identifiable, Hashable {
    let id: String
    let name: String
    let grams: Double
    let calories: Int
    let protein: Double
    let fat: Double
    let carbs: Double

    init(id: String = UUID().uuidString, name: String, grams: Double, calories: Int, protein: Double, fat: Double, carbs: Double) {
        self.id = id
        self.name = name
        self.grams = grams
        self.calories = calories
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
    }

    init?(_ data: [String: Any]) {
        guard
            let id = data["id"] as? String,
            let name = data["name"] as? String,
            let grams = data["grams"] as? Double,
            let calories = data["calories"] as? Int,
            let protein = data["protein"] as? Double,
            let fat = data["fat"] as? Double,
            let carbs = data["carbs"] as? Double
        else {
            return nil
        }

        self.id = id
        self.name = name
        self.grams = grams
        self.calories = calories
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
    }

    var firestoreData: [String: Any] {
        [
            "id": id,
            "name": name,
            "grams": grams,
            "calories": calories,
            "protein": protein,
            "fat": fat,
            "carbs": carbs
        ]
    }
}

struct CoachingNutritionMealSnapshot: Identifiable, Hashable {
    let id: String
    let mealTypeRaw: String
    let title: String
    let items: [CoachingNutritionItemSnapshot]

    init(mealTypeRaw: String, title: String, items: [CoachingNutritionItemSnapshot]) {
        self.id = mealTypeRaw
        self.mealTypeRaw = mealTypeRaw
        self.title = title
        self.items = items
    }

    init?(_ data: [String: Any]) {
        guard
            let mealTypeRaw = data["mealTypeRaw"] as? String,
            let title = data["title"] as? String,
            let itemsData = data["items"] as? [[String: Any]]
        else {
            return nil
        }

        self.id = mealTypeRaw
        self.mealTypeRaw = mealTypeRaw
        self.title = title
        self.items = itemsData.compactMap(CoachingNutritionItemSnapshot.init)
    }

    var firestoreData: [String: Any] {
        [
            "mealTypeRaw": mealTypeRaw,
            "title": title,
            "items": items.map(\.firestoreData)
        ]
    }

    var totalCalories: Int { items.reduce(0) { $0 + $1.calories } }
    var totalProtein: Double { items.reduce(0) { $0 + $1.protein } }
    var totalFat: Double { items.reduce(0) { $0 + $1.fat } }
    var totalCarbs: Double { items.reduce(0) { $0 + $1.carbs } }
}

struct CoachingNutritionReport: Identifiable, Hashable {
    let id: String
    let clientId: String
    let trainerId: String
    let dateFrom: Date
    let dateTo: Date
    let createdAt: Date
    let comment: String
    let totalCalories: Int
    let calorieGoal: Int
    let protein: Double
    let fat: Double
    let carbs: Double
    let proteinGoal: Int
    let fatGoal: Int
    let carbGoal: Int
    let meals: [CoachingNutritionMealSnapshot]

    init(
        id: String = UUID().uuidString,
        clientId: String,
        trainerId: String,
        dateFrom: Date,
        dateTo: Date,
        createdAt: Date = .now,
        comment: String = "",
        totalCalories: Int,
        calorieGoal: Int,
        protein: Double,
        fat: Double,
        carbs: Double,
        proteinGoal: Int,
        fatGoal: Int,
        carbGoal: Int,
        meals: [CoachingNutritionMealSnapshot]
    ) {
        self.id = id
        self.clientId = clientId
        self.trainerId = trainerId
        self.dateFrom = dateFrom
        self.dateTo = dateTo
        self.createdAt = createdAt
        self.comment = comment
        self.totalCalories = totalCalories
        self.calorieGoal = calorieGoal
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.proteinGoal = proteinGoal
        self.fatGoal = fatGoal
        self.carbGoal = carbGoal
        self.meals = meals
    }

    init?(id: String, data: [String: Any]) {
        guard
            let clientId = data["clientId"] as? String,
            let trainerId = data["trainerId"] as? String,
            let totalCalories = data["totalCalories"] as? Int,
            let calorieGoal = data["calorieGoal"] as? Int,
            let protein = data["protein"] as? Double,
            let fat = data["fat"] as? Double,
            let carbs = data["carbs"] as? Double,
            let proteinGoal = data["proteinGoal"] as? Int,
            let fatGoal = data["fatGoal"] as? Int,
            let carbGoal = data["carbGoal"] as? Int,
            let mealsData = data["meals"] as? [[String: Any]]
        else {
            return nil
        }

        self.id = id
        self.clientId = clientId
        self.trainerId = trainerId
        self.comment = (data["comment"] as? String) ?? ""
        if let dateFromTimestamp = data["dateFrom"] as? Timestamp {
            self.dateFrom = dateFromTimestamp.dateValue()
        } else {
            self.dateFrom = (data["dateFrom"] as? Date) ?? .now
        }
        if let dateToTimestamp = data["dateTo"] as? Timestamp {
            self.dateTo = dateToTimestamp.dateValue()
        } else {
            self.dateTo = (data["dateTo"] as? Date) ?? self.dateFrom
        }
        if let createdTimestamp = data["createdAt"] as? Timestamp {
            self.createdAt = createdTimestamp.dateValue()
        } else {
            self.createdAt = (data["createdAt"] as? Date) ?? .now
        }
        self.totalCalories = totalCalories
        self.calorieGoal = calorieGoal
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.proteinGoal = proteinGoal
        self.fatGoal = fatGoal
        self.carbGoal = carbGoal
        self.meals = mealsData.compactMap(CoachingNutritionMealSnapshot.init)
    }

    var firestoreData: [String: Any] {
        [
            "clientId": clientId,
            "trainerId": trainerId,
            "dateFrom": dateFrom,
            "dateTo": dateTo,
            "createdAt": createdAt,
            "comment": comment,
            "totalCalories": totalCalories,
            "calorieGoal": calorieGoal,
            "protein": protein,
            "fat": fat,
            "carbs": carbs,
            "proteinGoal": proteinGoal,
            "fatGoal": fatGoal,
            "carbGoal": carbGoal,
            "meals": meals.map(\.firestoreData)
        ]
    }
}

private enum NutritionReportPeriodPreset: String, CaseIterable, Identifiable {
    case today
    case yesterday
    case date

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .today: return "coaching.nutrition.compose.period.today"
        case .yesterday: return "coaching.nutrition.compose.period.yesterday"
        case .date: return "coaching.nutrition.compose.period.date"
        }
    }
}

private enum NutritionReportBuilder {
    static func build(
        clientId: String,
        trainerId: String,
        selectedDate: Date,
        entries: [FoodEntry],
        userData: UserData?,
        comment: String
    ) -> CoachingNutritionReport {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: selectedDate)
        let groupedMeals: [CoachingNutritionMealSnapshot] = MealType.allCases.compactMap { meal in
            let mealEntries = entries.filter { $0.mealType == meal.rawValue }
            let items = itemSnapshots(from: mealEntries)
            guard items.isEmpty == false else { return nil }
            return CoachingNutritionMealSnapshot(mealTypeRaw: meal.rawValue, title: meal.displayName, items: items)
        }

        let totalCalories = groupedMeals.reduce(0) { $0 + $1.totalCalories }
        let totalProtein = groupedMeals.reduce(0) { $0 + $1.totalProtein }
        let totalFat = groupedMeals.reduce(0) { $0 + $1.totalFat }
        let totalCarbs = groupedMeals.reduce(0) { $0 + $1.totalCarbs }

        return CoachingNutritionReport(
            clientId: clientId,
            trainerId: trainerId,
            dateFrom: dayStart,
            dateTo: dayStart,
            comment: comment.trimmingCharacters(in: .whitespacesAndNewlines),
            totalCalories: totalCalories,
            calorieGoal: userData?.calories ?? 0,
            protein: totalProtein,
            fat: totalFat,
            carbs: totalCarbs,
            proteinGoal: userData?.proteins ?? 0,
            fatGoal: userData?.fats ?? 0,
            carbGoal: userData?.carbs ?? 0,
            meals: groupedMeals
        )
    }

    private static func itemSnapshots(from entries: [FoodEntry]) -> [CoachingNutritionItemSnapshot] {
        let groupedAI = Dictionary(grouping: entries.filter { ($0.aiMealGroupID ?? "").isEmpty == false }, by: { $0.aiMealGroupID ?? UUID().uuidString })
        let aiItems = groupedAI.values.map { group -> CoachingNutritionItemSnapshot in
            CoachingNutritionItemSnapshot(
                id: group.first?.aiMealGroupID ?? UUID().uuidString,
                name: group.first?.aiMealName ?? group.first?.product?.name ?? AppLocalizer.string("coaching.nutrition.item.unknown"),
                grams: group.reduce(0) { $0 + $1.portion },
                calories: group.reduce(0) { $0 + ($1.product?.calories ?? 0) },
                protein: group.reduce(0) { $0 + ($1.product?.protein ?? 0) },
                fat: group.reduce(0) { $0 + ($1.product?.fat ?? 0) },
                carbs: group.reduce(0) { $0 + ($1.product?.carbs ?? 0) }
            )
        }

        let regularItems = entries
            .filter { ($0.aiMealGroupID ?? "").isEmpty }
            .map {
                CoachingNutritionItemSnapshot(
                    id: $0.id.uuidString,
                    name: $0.product?.name ?? AppLocalizer.string("coaching.nutrition.item.unknown"),
                    grams: $0.portion,
                    calories: $0.product?.calories ?? 0,
                    protein: $0.product?.protein ?? 0,
                    fat: $0.product?.fat ?? 0,
                    carbs: $0.product?.carbs ?? 0
                )
            }

        return aiItems + regularItems
    }
}

struct ClientNutritionReportComposerScreen: View {
    let clientId: String
    let trainerId: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var sessionStore: AppSessionStore
    @ObservedObject var store: ClientCoachingHomeStore
    @Query private var users: [UserData]
    @AppStorage(Gender.appStorageKey) private var activeGenderRaw: String = Gender.male.rawValue

    @State private var selectedPreset: NutritionReportPeriodPreset = .today
    @State private var customDate = Date()
    @State private var comment = ""
    @State private var previewReport: CoachingNutritionReport?
    @State private var isLoadingPreview = false
    @State private var previewError: String?

    private var selectedGender: Gender { Gender(rawValue: activeGenderRaw) ?? .male }
    private var reportDate: Date {
        switch selectedPreset {
        case .today: return Date()
        case .yesterday: return Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        case .date: return customDate
        }
    }

    private var userData: UserData? {
        users.first { $0.ownerId == clientId && $0.gender == selectedGender }
    }

    var body: some View {
        List {
            Section {
                Text(AppLocalizer.string("coaching.nutrition.compose.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section(AppLocalizer.string("coaching.nutrition.compose.period")) {
                Picker(AppLocalizer.string("coaching.nutrition.compose.period"), selection: $selectedPreset) {
                    ForEach(NutritionReportPeriodPreset.allCases) { preset in
                        Text(AppLocalizer.string(preset.localizationKey)).tag(preset)
                    }
                }
                .pickerStyle(.segmented)

                if selectedPreset == .date {
                    DatePicker(
                        AppLocalizer.string("coaching.nutrition.compose.date"),
                        selection: $customDate,
                        displayedComponents: .date
                    )
                }
            }

            if isLoadingPreview {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else if let previewReport {
                Section(AppLocalizer.string("coaching.nutrition.detail.title")) {
                    CoachingNutritionReportSummaryContent(report: previewReport)
                }

                Section(AppLocalizer.string("coaching.nutrition.compose.comment")) {
                    TextField(AppLocalizer.string("coaching.nutrition.compose.comment.placeholder"), text: $comment, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                    Button {
                        Task {
                            await store.sendNutritionReport(
                                previewReport.with(comment: comment),
                                senderName: sessionStore.profile?.displayName ?? ""
                            )
                            if store.errorMessage == nil {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            Text(AppLocalizer.string("coaching.nutrition.action.submit"))
                            Spacer()
                            if store.isSubmitting {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(store.isSubmitting)
                }
            } else {
                Section {
                    Text(previewError ?? AppLocalizer.string("coaching.nutrition.empty.available"))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(AppLocalizer.string("coaching.nutrition.compose.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(AppLocalizer.string("common.cancel")) {
                    dismiss()
                }
            }
        }
        .task { loadPreview() }
        .onChange(of: selectedPreset) { _, _ in loadPreview() }
        .onChange(of: customDate) { _, _ in
            if selectedPreset == .date { loadPreview() }
        }
    }

    private func loadPreview() {
        isLoadingPreview = true
        previewError = nil

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: reportDate)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            previewReport = nil
            previewError = AppLocalizer.string("coaching.nutrition.empty.available")
            isLoadingPreview = false
            return
        }

        do {
            let predicate = #Predicate<FoodEntry> {
                $0.date >= dayStart && $0.date < dayEnd && $0.ownerId == clientId
            }
            let entries = try modelContext.fetch(FetchDescriptor<FoodEntry>(predicate: predicate))
                .filter { $0.gender == selectedGender }

            guard entries.isEmpty == false else {
                previewReport = nil
                previewError = AppLocalizer.string("coaching.nutrition.empty.available")
                isLoadingPreview = false
                return
            }

            previewReport = NutritionReportBuilder.build(
                clientId: clientId,
                trainerId: trainerId,
                selectedDate: reportDate,
                entries: entries,
                userData: userData,
                comment: comment
            )
            isLoadingPreview = false
        } catch {
            previewReport = nil
            previewError = error.localizedDescription
            isLoadingPreview = false
        }
    }
}

private extension CoachingNutritionReport {
    func with(comment: String) -> CoachingNutritionReport {
        CoachingNutritionReport(
            id: id,
            clientId: clientId,
            trainerId: trainerId,
            dateFrom: dateFrom,
            dateTo: dateTo,
            createdAt: createdAt,
            comment: comment.trimmingCharacters(in: .whitespacesAndNewlines),
            totalCalories: totalCalories,
            calorieGoal: calorieGoal,
            protein: protein,
            fat: fat,
            carbs: carbs,
            proteinGoal: proteinGoal,
            fatGoal: fatGoal,
            carbGoal: carbGoal,
            meals: meals
        )
    }
}

struct CoachingNutritionReportRow: View {
    let report: CoachingNutritionReport

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(AppLocalizer.string("coaching.nutrition.report.header"))
                    .font(.headline)
                Spacer()
                Text(report.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(report.dateFrom.formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 10) {
                Text(AppLocalizer.format("coaching.nutrition.calories.value", report.totalCalories, report.calorieGoal))
                Text(AppLocalizer.format("coaching.nutrition.macros.value", Int(report.protein.rounded()), Int(report.fat.rounded()), Int(report.carbs.rounded())))
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let firstMeal = report.meals.first {
                Text(AppLocalizer.format("coaching.nutrition.meal_count", report.meals.count, firstMeal.title))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct CoachingNutritionReportSummaryContent: View {
    let report: CoachingNutritionReport

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(report.dateFrom.formatted(date: .abbreviated, time: .omitted))
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text(AppLocalizer.format("coaching.nutrition.calories.value", report.totalCalories, report.calorieGoal))
                Text(AppLocalizer.format("coaching.nutrition.macros.value", Int(report.protein.rounded()), Int(report.fat.rounded()), Int(report.carbs.rounded())))
                Text(AppLocalizer.format("coaching.nutrition.macros.goal", report.proteinGoal, report.fatGoal, report.carbGoal))
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

            ForEach(report.meals) { meal in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(meal.title)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(AppLocalizer.format("unit.kcal.value", meal.totalCalories))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(meal.items) { item in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .font(.caption.weight(.semibold))
                                Text(AppLocalizer.format("coaching.nutrition.item.detail", Int(item.grams.rounded()), item.calories))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(AppLocalizer.format("coaching.nutrition.item.macros", Int(item.protein.rounded()), Int(item.fat.rounded()), Int(item.carbs.rounded())))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CoachingNutritionReportDetailScreen: View {
    let report: CoachingNutritionReport

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                CoachingNutritionReportSummaryContent(report: report)
            }

            if report.comment.isEmpty == false {
                Section(AppLocalizer.string("coaching.nutrition.detail.comment")) {
                    Text(report.comment)
                }
            }
        }
        .navigationTitle(AppLocalizer.string("coaching.nutrition.detail.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(AppLocalizer.string("common.close")) {
                    dismiss()
                }
            }
        }
    }
}

struct CoachingNutritionReportHistoryScreen: View {
    let reports: [CoachingNutritionReport]
    let canDelete: Bool
    let onDelete: ((CoachingNutritionReport) async -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedReport: CoachingNutritionReport?
    @State private var pendingDelete: CoachingNutritionReport?

    var body: some View {
        List {
            if reports.isEmpty {
                Text(AppLocalizer.string("coaching.nutrition.empty.received"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(reports) { report in
                    Button {
                        selectedReport = report
                    } label: {
                        CoachingNutritionReportRow(report: report)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if canDelete {
                            Button(role: .destructive) {
                                pendingDelete = report
                            } label: {
                                Label(AppLocalizer.string("common.delete"), systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(AppLocalizer.string("coaching.nutrition.section"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(AppLocalizer.string("common.close")) {
                    dismiss()
                }
            }
        }
        .sheet(item: $selectedReport) { report in
            NavigationStack {
                CoachingNutritionReportDetailScreen(report: report)
            }
        }
        .alert(AppLocalizer.string("coaching.history.delete.title"), isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button(AppLocalizer.string("common.cancel"), role: .cancel) {
                pendingDelete = nil
            }
            Button(AppLocalizer.string("common.delete"), role: .destructive) {
                guard let pendingDelete, let onDelete else { return }
                Task { await onDelete(pendingDelete) }
                self.pendingDelete = nil
            }
        } message: {
            Text(AppLocalizer.string("coaching.history.delete.message"))
        }
    }
}
