import SwiftUI
import SwiftData

struct ProfileScreen: View {
    @Query private var users: [UserData]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var sessionStore: AppSessionStore

    @AppStorage(Gender.appStorageKey) private var activeGenderRaw: String = Gender.male.rawValue
    @State private var editingGender: Gender
    @State private var isShowingNutritionGoalsEditor = false

    init() {
        let raw = UserDefaults.standard.string(forKey: Gender.appStorageKey) ?? Gender.male.rawValue
        _editingGender = State(initialValue: Gender(rawValue: raw) ?? .male)
    }

    private var currentOwnerId: String? { sessionStore.firebaseUser?.uid }
    private var user: UserData? {
        guard let currentOwnerId else { return nil }
        return users.first(where: { $0.gender == editingGender && $0.ownerId == currentOwnerId })
    }

    var body: some View {
        let bg = Color(.systemGray6)

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ProfileHeroCard()

                    SectionCard(title: AppLocalizer.string("profile.gender")) {
                        Picker("", selection: $editingGender) {
                            ForEach(Gender.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    if let user {
                        @Bindable var u = user

                        SectionCard(title: AppLocalizer.string("profile.parameters")) {
                            VStack(spacing: 16) {
                                ProfileSummaryGrid(age: u.age, weight: u.weight, height: u.height)

                                Divider()

                                VStack(spacing: 14) {
                                    ValueRowInt(title: AppLocalizer.string("profile.age"), value: $u.age, range: 1...100, unit: AppLocalizer.string("unit.years"))
                                    ValueRowDoubleAsInt(title: AppLocalizer.string("profile.weight"), value: $u.weight, range: 30...200, unit: AppLocalizer.string("unit.kg"))
                                    ValueRowDoubleAsInt(title: AppLocalizer.string("profile.height"), value: $u.height, range: 100...230, unit: AppLocalizer.string("unit.cm"))
                                }
                            }
                        }
                        .onChange(of: u.age) { _, _ in recalc(u) }
                        .onChange(of: u.weight) { _, _ in recalc(u) }
                        .onChange(of: u.height) { _, _ in recalc(u) }

                        SectionCard(title: AppLocalizer.string("activity.title")) {
                            VStack(alignment: .leading, spacing: 12) {
                                Picker("", selection: $u.activityLevel) {
                                    ForEach(ActivityLevel.allCases, id: \.self) { Text($0.displayName).tag($0) }
                                }
                                .pickerStyle(.segmented)

                                Text(u.activityLevel.message)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .onChange(of: u.activityLevel) { _, _ in recalc(u) }

                        SectionCard(title: AppLocalizer.string("goal.title")) {
                            VStack(alignment: .leading, spacing: 12) {
                                Picker("", selection: $u.goal) {
                                    ForEach(WeightGoal.allCases, id: \.self) { Text(goalDisplayName($0)).tag($0) }
                                }
                                .pickerStyle(.segmented)

                                Text(goalSubtitle(for: u.goal))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .onChange(of: u.goal) { _, _ in recalc(u) }

                        SectionCard(title: AppLocalizer.string("profile.nutrition_goals")) {
                            VStack(alignment: .leading, spacing: 14) {
                                Picker("", selection: $u.nutritionGoalMode) {
                                    ForEach(NutritionGoalMode.allCases, id: \.self) {
                                        Text(AppLocalizer.string($0.titleKey)).tag($0)
                                    }
                                }
                                .pickerStyle(.segmented)

                                if u.nutritionGoalMode == .automatic {
                                    Text(AppLocalizer.string("profile.nutrition_goals.auto_hint"))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                } else {
                                    VStack(spacing: 12) {
                                        GoalMetricRow(
                                            title: AppLocalizer.string("nutrition.calories"),
                                            value: "\(u.calories)",
                                            unit: AppLocalizer.string("unit.kcal")
                                        )
                                        GoalMetricRow(
                                            title: AppLocalizer.string("macro.protein"),
                                            value: "\(u.proteins)",
                                            unit: AppLocalizer.string("unit.grams.short")
                                        )
                                        GoalMetricRow(
                                            title: AppLocalizer.string("macro.fat"),
                                            value: "\(u.fats)",
                                            unit: AppLocalizer.string("unit.grams.short")
                                        )
                                        GoalMetricRow(
                                            title: AppLocalizer.string("macro.carbs"),
                                            value: "\(u.carbs)",
                                            unit: AppLocalizer.string("unit.grams.short")
                                        )
                                    }

                                    Button(AppLocalizer.string("profile.nutrition_goals.edit")) {
                                        isShowingNutritionGoalsEditor = true
                                    }
                                    .font(.body.weight(.semibold))
                                }
                            }
                        }
                        .onChange(of: u.nutritionGoalMode) { _, newValue in
                            if newValue == .automatic {
                                recalc(u, force: true)
                            } else {
                                try? modelContext.save()
                            }
                        }
                        .sheet(isPresented: $isShowingNutritionGoalsEditor) {
                            ManualNutritionGoalsEditor(userData: u)
                        }

                        BMISection(userData: u)
                    } else {
                        ContentUnavailableView(
                            AppLocalizer.string("profile.not_found"),
                            systemImage: "person.crop.circle.badge.questionmark",
                            description: Text(AppLocalizer.string("profile.auto_create"))
                        )
                        .task { ensureUserIfNeeded(for: editingGender) }
                    }

                    MeasurementsCard()
                }
                .padding(.vertical, 16)
            }
            .background(bg)
            .navigationTitle(AppLocalizer.string("tab.profile"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(bg, for: .navigationBar)
        }
        .onChange(of: editingGender) { _, new in
            activeGenderRaw = new.rawValue
            ensureUserIfNeeded(for: new)
            if let currentOwnerId,
               let u = users.first(where: { $0.gender == new && $0.ownerId == currentOwnerId }) {
                u.gender = new
                try? modelContext.save()
                recalc(u)
            }
        }
        .onAppear {
            activeGenderRaw = editingGender.rawValue
            ensureUserIfNeeded(for: editingGender)
        }
    }

    private func ensureUserIfNeeded(for gender: Gender) {
        guard let currentOwnerId else { return }
        if users.first(where: { $0.gender == gender && $0.ownerId == currentOwnerId }) == nil {
            let u = UserData(weight: 70, height: 170, age: 25,
                             ownerId: currentOwnerId,
                             activityLevel: .none, goal: .currentWeight, gender: gender)
            modelContext.insert(u)
            try? modelContext.save()
            recalc(u)
        }
    }

    private func recalc(_ u: UserData, force: Bool = false) {
        guard force || u.nutritionGoalMode == .automatic else {
            try? modelContext.save()
            return
        }

        let cals = MacrosCalculator.calculateCaloriesMifflin(
            gender: u.gender, weight: u.weight, height: u.height, age: u.age,
            activityLevel: u.activityLevel, goal: u.goal
        )
        let macros = MacrosCalculator.calculateMacros(calories: cals, goal: u.goal)
        u.calories = cals
        u.macros = macros
        try? modelContext.save()
    }

    private func goalDisplayName(_ goal: WeightGoal) -> String {
        switch goal {
        case .currentWeight:
            return AppLocalizer.string("goal.maintain_short")
        default:
            return goal.displayName
        }
    }

    private func goalSubtitle(for goal: WeightGoal) -> String {
        switch goal {
        case .loseWeight:
            return AppLocalizer.string("goal.subtitle.lose")
        case .currentWeight:
            return AppLocalizer.string("goal.subtitle.maintain")
        case .gainWeight:
            return AppLocalizer.string("goal.subtitle.gain")
        }
    }

    private struct ValueRowInt: View {
        let title: String
        @Binding var value: Int
        let range: ClosedRange<Int>
        let unit: String
        var step: Int = 1

        @State private var showSheet = false

        var body: some View {
            Button {
                showSheet = true
            } label: {
                HStack {
                    Text(title)
                        .font(.body.weight(.medium))
                    Spacer()
                    Text("\(value) \(unit)")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showSheet) {
                NumberWheelPickerInt(
                    title: title,
                    value: $value,
                    range: range,
                    unit: unit,
                    step: step
                )
            }
        }
    }

    private struct ValueRowDoubleAsInt: View {
        let title: String
        @Binding var value: Double
        let range: ClosedRange<Int>
        let unit: String
        var step: Int = 1

        @State private var showSheet = false
        @State private var temp: Int = 0

        var body: some View {
            Button {
                temp = min(max(Int(value.rounded()), range.lowerBound), range.upperBound)
                showSheet = true
            } label: {
                HStack {
                    Text(title)
                        .font(.body.weight(.medium))
                    Spacer()
                    Text("\(Int(value.rounded())) \(unit)")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showSheet) {
                NumberWheelPickerInt(
                    title: title,
                    value: $temp,
                    range: range,
                    unit: unit,
                    step: step,
                    onDone: {
                        value = Double(temp)
                    }
                )
            }
        }
    }

    private struct NumberWheelPickerInt: View {
        let title: String
        @Binding var value: Int
        let range: ClosedRange<Int>
        let unit: String
        var step: Int = 1
        var onDone: (() -> Void)? = nil

        @Environment(\.dismiss) private var dismiss

        private var values: [Int] {
            Array(stride(from: range.lowerBound, through: range.upperBound, by: step))
        }

        var body: some View {
            NavigationStack {
                VStack(spacing: 0) {
                    Picker("", selection: $value) {
                        ForEach(values, id: \.self) { v in
                            Text("\(v) \(unit)").tag(v)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    Text("\(value) \(unit)")
                        .font(.title3.weight(.semibold))
                        .padding(.vertical, 12)
                        .foregroundStyle(.secondary)
                }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(AppLocalizer.string("common.done")) {
                            onDone?()
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            dismiss()
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }
}

private struct GoalMetricRow: View {
    let title: String
    let value: String
    let unit: String

    var body: some View {
        HStack {
            Text(title)
                .font(.body.weight(.medium))
            Spacer()
            Text("\(value) \(unit)")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct ManualNutritionGoalsEditor: View {
    @Bindable var userData: UserData

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var proteins: String
    @State private var fats: String
    @State private var carbs: String

    init(userData: UserData) {
        self.userData = userData
        _proteins = State(initialValue: "\(userData.proteins)")
        _fats = State(initialValue: "\(userData.fats)")
        _carbs = State(initialValue: "\(userData.carbs)")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(AppLocalizer.string("profile.nutrition_goals.manual_section")) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(AppLocalizer.string("nutrition.calories"))
                            Spacer()
                            Text("\(calculatedCalories)")
                            Text(AppLocalizer.string("unit.kcal"))
                                .foregroundStyle(.secondary)
                        }

                        Text(AppLocalizer.string("profile.nutrition_goals.calories_hint"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    numericField(AppLocalizer.string("macro.protein"), text: $proteins, unit: AppLocalizer.string("unit.grams.short"))
                    numericField(AppLocalizer.string("macro.fat"), text: $fats, unit: AppLocalizer.string("unit.grams.short"))
                    numericField(AppLocalizer.string("macro.carbs"), text: $carbs, unit: AppLocalizer.string("unit.grams.short"))
                }
            }
            .navigationTitle(AppLocalizer.string("profile.nutrition_goals.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(AppLocalizer.string("common.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(AppLocalizer.string("common.save")) {
                        save()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var isValid: Bool {
        parsedValue(proteins) != nil &&
        parsedValue(fats) != nil &&
        parsedValue(carbs) != nil
    }

    private var calculatedCalories: Int {
        let proteinsValue = parsedValue(proteins) ?? 0
        let fatsValue = parsedValue(fats) ?? 0
        let carbsValue = parsedValue(carbs) ?? 0
        return (proteinsValue * 4) + (fatsValue * 9) + (carbsValue * 4)
    }

    private func numericField(_ title: String, text: Binding<String>, unit: String) -> some View {
        HStack {
            TextField(title, text: text)
                .keyboardType(.numberPad)
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }

    private func parsedValue(_ text: String) -> Int? {
        guard let value = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)), value >= 0 else {
            return nil
        }
        return value
    }

    private func save() {
        guard
            let proteinsValue = parsedValue(proteins),
            let fatsValue = parsedValue(fats),
            let carbsValue = parsedValue(carbs)
        else { return }

        userData.nutritionGoalMode = .manual
        userData.calories = (proteinsValue * 4) + (fatsValue * 9) + (carbsValue * 4)
        userData.proteins = proteinsValue
        userData.fats = fatsValue
        userData.carbs = carbsValue
        try? modelContext.save()
        dismiss()
    }
}

private struct ProfileHeroCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppLocalizer.string("tab.profile"))
                .font(.system(size: 28, weight: .bold))

            Text(AppLocalizer.string("profile.subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Label(AppLocalizer.string("profile.hero.parameters"), systemImage: "slider.horizontal.3")
                Label(AppLocalizer.string("profile.hero.progress"), systemImage: "chart.line.uptrend.xyaxis")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.black.opacity(0.06))
        )
        .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 4)
        .padding(.horizontal)
    }
}

private struct ProfileSummaryGrid: View {
    let age: Int
    let weight: Double
    let height: Double

    var body: some View {
        HStack(spacing: 10) {
            SummaryMetricCard(
                title: AppLocalizer.string("profile.age"),
                value: "\(age)",
                unit: AppLocalizer.string("unit.years"),
                systemImage: "calendar"
            )
            SummaryMetricCard(
                title: AppLocalizer.string("profile.weight"),
                value: "\(Int(weight.rounded()))",
                unit: AppLocalizer.string("unit.kg"),
                systemImage: "scalemass"
            )
            SummaryMetricCard(
                title: AppLocalizer.string("profile.height"),
                value: "\(Int(height.rounded()))",
                unit: AppLocalizer.string("unit.cm"),
                systemImage: "ruler"
            )
        }
    }
}

private struct SummaryMetricCard: View {
    let title: String
    let value: String
    let unit: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                Text(unit)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
