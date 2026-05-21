import SwiftUI
import SwiftData

private let profileCardBackground = Color(.secondarySystemBackground)
private let profileCardBorder = Color(.separator).opacity(0.40)

struct ProfileScreen: View {
    @Query private var users: [UserData]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var sessionStore: AppSessionStore
    @EnvironmentObject private var notificationsStore: AppNotificationsStore
    @Environment(\.colorScheme) private var colorScheme

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
        let theme = AppTheme(colorScheme)
        let bg = theme.bg

        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if let user {
                        ProfileHeroCard {
                            ProfileProgressScreen(userData: user, ownerId: currentOwnerId, gender: editingGender)
                        }
                    } else {
                        ProfileHeroCard()
                    }

                    SectionCard(title: AppLocalizer.string("profile.gender")) {
                        ProfileSegmentedPicker(
                            items: Gender.allCases.map { ($0, $0.displayName) },
                            selection: $editingGender
                        )
                    }

                    if let user {
                        @Bindable var u = user

                        SectionCard(title: AppLocalizer.string("profile.parameters")) {
                            ProfileSummaryGrid(age: $u.age, weight: $u.weight, height: $u.height)
                        }
                        .onChange(of: u.age) { _, _ in recalc(u) }
                        .onChange(of: u.weight) { _, _ in recalc(u) }
                        .onChange(of: u.height) { _, _ in recalc(u) }

                        SectionCard(title: AppLocalizer.string("activity.title")) {
                            VStack(alignment: .leading, spacing: 12) {
                                ProfileSegmentedPicker(
                                    items: ActivityLevel.allCases.map { ($0, $0.displayName) },
                                    selection: $u.activityLevel
                                )

                                Text(u.activityLevel.message)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .onChange(of: u.activityLevel) { _, _ in recalc(u) }

                        SectionCard(title: AppLocalizer.string("goal.title")) {
                            VStack(alignment: .leading, spacing: 12) {
                                ProfileSegmentedPicker(
                                    items: WeightGoal.allCases.map { ($0, goalDisplayName($0)) },
                                    selection: $u.goal
                                )

                                Text(goalSubtitle(for: u.goal))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .onChange(of: u.goal) { _, _ in recalc(u) }

                        SectionCard(title: AppLocalizer.string("profile.nutrition_goals")) {
                            VStack(alignment: .leading, spacing: 14) {
                                ProfileSegmentedPicker(
                                    items: NutritionGoalMode.allCases.map { ($0, AppLocalizer.string($0.titleKey)) },
                                    selection: $u.nutritionGoalMode
                                )

                                if u.nutritionGoalMode == .automatic {
                                    VStack(spacing: 12) {
                                        GoalMetricRow(
                                            title: AppLocalizer.string("nutrition.calories"),
                                            value: "\(u.calories)",
                                            unit: AppLocalizer.string("unit.kcal"),
                                            systemImage: "flame.fill",
                                            tint: HomeDarkColors.orange
                                        )
                                        GoalMetricRow(
                                            title: AppLocalizer.string("macro.protein"),
                                            value: "\(u.proteins)",
                                            unit: AppLocalizer.string("unit.grams.short"),
                                            systemImage: "leaf.fill",
                                            tint: HomeDarkColors.green
                                        )
                                        GoalMetricRow(
                                            title: AppLocalizer.string("macro.fat"),
                                            value: "\(u.fats)",
                                            unit: AppLocalizer.string("unit.grams.short"),
                                            systemImage: "drop.fill",
                                            tint: Color(hex: "FFD60A")
                                        )
                                        GoalMetricRow(
                                            title: AppLocalizer.string("macro.carbs"),
                                            value: "\(u.carbs)",
                                            unit: AppLocalizer.string("unit.grams.short"),
                                            systemImage: "water.waves",
                                            tint: theme.accent
                                        )
                                    }

                                    Text(AppLocalizer.string("profile.nutrition_goals.auto_hint"))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                } else {
                                    VStack(spacing: 12) {
                                        GoalMetricRow(
                                            title: AppLocalizer.string("nutrition.calories"),
                                            value: "\(u.calories)",
                                            unit: AppLocalizer.string("unit.kcal"),
                                            systemImage: "flame.fill",
                                            tint: HomeDarkColors.orange
                                        )
                                        GoalMetricRow(
                                            title: AppLocalizer.string("macro.protein"),
                                            value: "\(u.proteins)",
                                            unit: AppLocalizer.string("unit.grams.short"),
                                            systemImage: "leaf.fill",
                                            tint: HomeDarkColors.green
                                        )
                                        GoalMetricRow(
                                            title: AppLocalizer.string("macro.fat"),
                                            value: "\(u.fats)",
                                            unit: AppLocalizer.string("unit.grams.short"),
                                            systemImage: "drop.fill",
                                            tint: Color(hex: "FFD60A")
                                        )
                                        GoalMetricRow(
                                            title: AppLocalizer.string("macro.carbs"),
                                            value: "\(u.carbs)",
                                            unit: AppLocalizer.string("unit.grams.short"),
                                            systemImage: "water.waves",
                                            tint: theme.accent
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
            .toolbarColorScheme(theme.isDark ? .dark : .light, for: .navigationBar)
            .tint(theme.accent)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        AppNotificationsScreen()
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell")
                                .font(.system(size: 18, weight: .semibold))

                            if notificationsStore.unreadCount > 0 {
                                Text("\(min(notificationsStore.unreadCount, 99))")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.red))
                                    .offset(x: 10, y: -8)
                            }
                        }
                    }
                    .accessibilityLabel(AppLocalizer.string("notifications.inbox.title"))
                }
            }
        }
        .onChange(of: editingGender) { _, new in
            if activeGenderRaw != new.rawValue {
                activeGenderRaw = new.rawValue
            }
            ensureUserIfNeeded(for: new)
            if let currentOwnerId,
               let u = users.first(where: { $0.gender == new && $0.ownerId == currentOwnerId }) {
                if u.gender != new {
                    u.gender = new
                    try? modelContext.save()
                }
                recalc(u)
            }
        }
        .onAppear {
            if activeGenderRaw != editingGender.rawValue {
                activeGenderRaw = editingGender.rawValue
            }
            if user == nil {
                ensureUserIfNeeded(for: editingGender)
            }
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

    struct NumberWheelPickerInt: View {
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

private struct ProfileSegmentedPicker<Selection: Hashable>: View {
    let items: [(value: Selection, title: String)]
    @Binding var selection: Selection

    @Environment(\.colorScheme) private var colorScheme

    private var theme: AppTheme { AppTheme(colorScheme) }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Button {
                    selection = item.value
                } label: {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                        .foregroundStyle(selection == item.value ? Color.white : theme.primaryText.opacity(theme.isDark ? 0.86 : 0.70))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if selection == item.value {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(hex: "347DFF"),
                                                Color(hex: "1257E8")
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: theme.accent.opacity(theme.isDark ? 0.28 : 0.18), radius: 10, x: 0, y: 5)
                            }
                        }
                }
                .buttonStyle(.plain)

                if index < items.count - 1 {
                    Rectangle()
                        .fill(theme.border)
                        .frame(width: 1)
                        .padding(.vertical, 8)
                        .opacity(selection == item.value || selection == items[index + 1].value ? 0 : 1)
                }
            }
        }
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(theme.isDark ? Color.white.opacity(0.055) : Color.black.opacity(0.055))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        }
    }
}

private struct GoalMetricRow: View {
    let title: String
    let value: String
    let unit: String
    let systemImage: String
    let tint: Color

    @Environment(\.colorScheme) private var colorScheme

    private var theme: AppTheme { AppTheme(colorScheme) }

    var body: some View {
        HStack(spacing: 12) {
            ProfileIconTile(systemImage: systemImage, tint: tint, size: 34, cornerRadius: 10)

            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(theme.primaryText)

            Spacer()

            Text("\(value) \(unit)")
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
        }
    }
}

private struct ProfileIconTile: View {
    let systemImage: String
    let tint: Color
    var size: CGFloat = 46
    var cornerRadius: CGFloat = 14

    @Environment(\.colorScheme) private var colorScheme

    private var theme: AppTheme { AppTheme(colorScheme) }

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(theme.isDark ? 0.26 : 0.16),
                                tint.opacity(theme.isDark ? 0.10 : 0.07)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(tint.opacity(theme.isDark ? 0.18 : 0.12), lineWidth: 1)
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
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(AppLocalizer.string("profile.nutrition_goals.manual_section"))
                                .font(.headline)

                            Text(AppLocalizer.string("profile.nutrition_goals.sheet_subtitle"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text(AppLocalizer.string("nutrition.calories"))
                                .font(.subheadline.weight(.semibold))

                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(calculatedCalories)")
                                    .font(.system(size: 34, weight: .bold))
                                Text(AppLocalizer.string("unit.kcal"))
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }

                            Text(AppLocalizer.string("profile.nutrition_goals.calories_hint"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color(.secondarySystemBackground))
                        )

                        VStack(spacing: 12) {
                            macroField(title: AppLocalizer.string("macro.protein"), text: $proteins, unit: AppLocalizer.string("unit.grams.short"))
                            macroField(title: AppLocalizer.string("macro.fat"), text: $fats, unit: AppLocalizer.string("unit.grams.short"))
                            macroField(title: AppLocalizer.string("macro.carbs"), text: $carbs, unit: AppLocalizer.string("unit.grams.short"))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
                }

                VStack(spacing: 0) {
                    Divider()

                    Button(AppLocalizer.string("common.save")) {
                        save()
                    }
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .disabled(!isValid)
                }
                .background(Color(.systemBackground))
            }
            .navigationTitle(AppLocalizer.string("profile.nutrition_goals.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(AppLocalizer.string("common.cancel")) {
                        dismiss()
                    }
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

    private func macroField(title: String, text: Binding<String>, unit: String) -> some View {
        HStack(spacing: 14) {
            Text(title)
                .font(.body.weight(.medium))

            Spacer()

            TextField("0", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 88)
                .font(.body.weight(.semibold))

            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(profileCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(profileCardBorder)
        )
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
    let progressDestination: AnyView?

    @Environment(\.colorScheme) private var colorScheme

    private var theme: AppTheme { AppTheme(colorScheme) }

    init() {
        progressDestination = nil
    }

    init<Destination: View>(@ViewBuilder progressDestination: () -> Destination) {
        self.progressDestination = AnyView(progressDestination())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                ProfileIconTile(systemImage: "person.fill", tint: theme.accent, size: 58, cornerRadius: 29)

                VStack(alignment: .leading, spacing: 5) {
                    Text(AppLocalizer.string("tab.profile"))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(theme.primaryText)

                    Text(AppLocalizer.string("profile.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let progressDestination {
                Rectangle()
                    .fill(theme.border.opacity(theme.isDark ? 0.70 : 0.55))
                    .frame(height: 1)
                    .padding(.top, 2)

                NavigationLink {
                    progressDestination
                } label: {
                    HStack(spacing: 12) {
                        ProfileIconTile(systemImage: "chart.line.uptrend.xyaxis", tint: theme.accent, size: 40, cornerRadius: 12)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(AppLocalizer.string("profile.progress.title"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(theme.primaryText)

                            Text(AppLocalizer.string("profile.progress.subtitle"))
                                .font(.caption)
                                .foregroundStyle(theme.secondaryText)
                                .lineLimit(2)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(theme.tertiaryText)
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(alignment: .topTrailing) {
            if theme.isDark {
                Circle()
                    .fill(theme.accent.opacity(0.16))
                    .frame(width: 112, height: 112)
                    .offset(x: 42, y: -24)
            }
        }
        .lightweightAdaptiveHomeCard(theme: theme, cornerRadius: HomeDarkMetrics.cardCornerRadius)
        .padding(.horizontal)
    }
}

private struct ProfileSummaryGrid: View {
    @Binding var age: Int
    @Binding var weight: Double
    @Binding var height: Double

    var body: some View {
        HStack(spacing: 10) {
            EditableSummaryMetricCardInt(
                title: AppLocalizer.string("profile.age"),
                value: $age,
                unit: AppLocalizer.string("unit.years"),
                systemImage: "calendar",
                range: 1...100
            )
            EditableSummaryMetricCardDoubleAsInt(
                title: AppLocalizer.string("profile.weight"),
                value: $weight,
                unit: AppLocalizer.string("unit.kg"),
                systemImage: "scalemass",
                range: 30...200
            )
            EditableSummaryMetricCardDoubleAsInt(
                title: AppLocalizer.string("profile.height"),
                value: $height,
                unit: AppLocalizer.string("unit.cm"),
                systemImage: "ruler",
                range: 100...230
            )
        }
    }
}

private struct EditableSummaryMetricCardInt: View {
    let title: String
    @Binding var value: Int
    let unit: String
    let systemImage: String
    let range: ClosedRange<Int>

    @Environment(\.colorScheme) private var colorScheme
    @State private var showSheet = false

    private var theme: AppTheme { AppTheme(colorScheme) }

    var body: some View {
        Button {
            showSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ProfileIconTile(systemImage: systemImage, tint: metricTint, size: 28, cornerRadius: 8)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(value)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(theme.primaryText)
                    Text(unit)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.secondaryText)
                }

                HStack(spacing: 6) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.tertiaryText)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            .padding(12)
            .lightweightAdaptiveHomeCard(theme: theme, cornerRadius: 16)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSheet) {
            ProfileScreen.NumberWheelPickerInt(
                title: title,
                value: $value,
                range: range,
                unit: unit
            )
        }
    }

    private var metricTint: Color {
        switch systemImage {
        case "calendar": return theme.accent
        case "scalemass": return HomeDarkColors.green
        case "ruler": return Color(hex: "7B61FF")
        default: return theme.accent
        }
    }
}

private struct EditableSummaryMetricCardDoubleAsInt: View {
    let title: String
    @Binding var value: Double
    let unit: String
    let systemImage: String
    let range: ClosedRange<Int>

    @Environment(\.colorScheme) private var colorScheme
    @State private var showSheet = false
    @State private var temp = 0

    private var theme: AppTheme { AppTheme(colorScheme) }

    var body: some View {
        Button {
            temp = min(max(Int(value.rounded()), range.lowerBound), range.upperBound)
            showSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ProfileIconTile(systemImage: systemImage, tint: metricTint, size: 28, cornerRadius: 8)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(Int(value.rounded()))")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(theme.primaryText)
                    Text(unit)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.secondaryText)
                }

                HStack(spacing: 6) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.tertiaryText)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            .padding(12)
            .lightweightAdaptiveHomeCard(theme: theme, cornerRadius: 16)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSheet) {
            ProfileScreen.NumberWheelPickerInt(
                title: title,
                value: $temp,
                range: range,
                unit: unit,
                onDone: {
                    value = Double(temp)
                }
            )
        }
    }

    private var metricTint: Color {
        switch systemImage {
        case "calendar": return theme.accent
        case "scalemass": return HomeDarkColors.green
        case "ruler": return Color(hex: "7B61FF")
        default: return theme.accent
        }
    }
}

private struct ProfileProgressScreen: View {
    let userData: UserData
    let ownerId: String?
    let gender: Gender

    @Query private var workouts: [WorkoutSession]
    @Query private var foodEntries: [FoodEntry]
    @Query private var waterEntries: [WaterIntake]
    @Query(sort: \BodyMeasurements.date, order: .reverse) private var measurements: [BodyMeasurements]

    private var calendar: Calendar { .current }
    private var weekStart: Date {
        calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: Date())) ?? calendar.startOfDay(for: Date())
    }
    private var monthStart: Date {
        calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: Date())) ?? calendar.startOfDay(for: Date())
    }

    private var waterGoalLiters: Double {
        max((userData.weight.safeFinite * 35.0 / 1000.0).safeFinite, 0)
    }

    var body: some View {
        let snapshot = makeSnapshot()

        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                ProgressSummaryGrid(
                    workouts: snapshot.weekWorkoutsCount,
                    averageCalories: snapshot.averageCaloriesThisWeek,
                    waterGoalDays: snapshot.waterGoalDays,
                    weight: Int(userData.weight.rounded())
                )

                progressSection(title: AppLocalizer.string("profile.progress.body")) {
                    ProgressMetricRow(
                        icon: "scalemass",
                        title: AppLocalizer.string("profile.weight"),
                        value: "\(Int(userData.weight.rounded())) \(AppLocalizer.string("unit.kg"))",
                        subtitle: AppLocalizer.string("profile.progress.current_value")
                    )

                    if let latestMeasurement = snapshot.latestMeasurement {
                        ProgressMetricRow(
                            icon: "ruler",
                            title: AppLocalizer.string("measurements.latest"),
                            value: AppLocalizer.format("profile.progress.measurements.value", Int(latestMeasurement.waist.rounded()), Int(latestMeasurement.hips.rounded())),
                            subtitle: formattedDate(latestMeasurement.date)
                        )
                    } else {
                        ProgressMetricRow(
                            icon: "ruler",
                            title: AppLocalizer.string("measurements.title"),
                            value: AppLocalizer.string("measurements.empty"),
                            subtitle: AppLocalizer.string("measurements.empty.subtitle")
                        )
                    }
                }

                progressSection(title: AppLocalizer.string("tab.workouts")) {
                    ProgressMetricRow(
                        icon: "dumbbell.fill",
                        title: AppLocalizer.string("profile.progress.workouts.week"),
                        value: "\(snapshot.weekWorkoutsCount)",
                        subtitle: AppLocalizer.format("profile.progress.workouts.month", snapshot.monthWorkoutsCount)
                    )
                    ProgressMetricRow(
                        icon: "checkmark.circle",
                        title: AppLocalizer.string("profile.progress.sets.week"),
                        value: "\(snapshot.completedSetsThisWeek)",
                        subtitle: AppLocalizer.format("profile.progress.volume.week", snapshot.trainingVolumeThisWeek)
                    )
                    ProgressMetricRow(
                        icon: "timer",
                        title: AppLocalizer.string("profile.progress.duration.month"),
                        value: formattedMinutes(snapshot.totalWorkoutMinutesThisMonth),
                        subtitle: AppLocalizer.string("profile.progress.completed_only")
                    )
                }

                progressSection(title: AppLocalizer.string("tab.nutrition")) {
                    ProgressMetricRow(
                        icon: "flame",
                        title: AppLocalizer.string("profile.progress.calories.average"),
                        value: "\(snapshot.averageCaloriesThisWeek) \(AppLocalizer.string("unit.kcal"))",
                        subtitle: AppLocalizer.format("profile.progress.target", userData.calories)
                    )
                    ProgressMetricRow(
                        icon: "target",
                        title: AppLocalizer.string("profile.progress.nutrition.target_days"),
                        value: AppLocalizer.format("profile.progress.days.of_week", snapshot.nutritionDaysInTarget),
                        subtitle: AppLocalizer.string("profile.progress.nutrition.target_hint")
                    )
                    ProgressMetricRow(
                        icon: "fork.knife",
                        title: AppLocalizer.string("profile.progress.protein.average"),
                        value: "\(snapshot.proteinAverageThisWeek) \(AppLocalizer.string("unit.grams.short"))",
                        subtitle: AppLocalizer.format("profile.progress.target.grams", userData.proteins)
                    )
                }

                progressSection(title: AppLocalizer.string("tab.water")) {
                    ProgressMetricRow(
                        icon: "drop.fill",
                        title: AppLocalizer.string("profile.progress.water.average"),
                        value: formattedLiters(snapshot.averageWaterThisWeek),
                        subtitle: AppLocalizer.format("profile.progress.water.goal", waterGoalLiters)
                    )
                    ProgressMetricRow(
                        icon: "checkmark.circle",
                        title: AppLocalizer.string("profile.progress.water.target_days"),
                        value: AppLocalizer.format("profile.progress.days.of_week", snapshot.waterGoalDays),
                        subtitle: AppLocalizer.string("profile.progress.water.goal_hint")
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(AppLocalizer.string("profile.progress.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func makeSnapshot() -> ProfileProgressSnapshot {
        var weekWorkoutsCount = 0
        var monthWorkoutsCount = 0
        var completedSetsThisWeek = 0
        var trainingVolumeThisWeek = 0.0
        var totalWorkoutSecondsThisMonth = 0

        for workout in workouts where workout.ownerId == ownerId && workout.gender == gender && workout.endedAt != nil {
            if workout.createdAt >= weekStart {
                weekWorkoutsCount += 1

                for exercise in workout.exerciseItems {
                    for set in exercise.setItems where set.isCompleted {
                        completedSetsThisWeek += 1
                        if set.metricType == .reps {
                            trainingVolumeThisWeek += set.weight.safeFinite * Double(set.reps)
                        }
                    }
                }
            }

            if workout.createdAt >= monthStart {
                monthWorkoutsCount += 1
                totalWorkoutSecondsThisMonth += max(0, workout.elapsedSeconds)
            }
        }

        var caloriesByDay: [Date: Int] = [:]
        var proteinByDay: [Date: Double] = [:]

        for entry in foodEntries where entry.ownerId == ownerId && entry.gender == gender && entry.date >= weekStart {
            let day = calendar.startOfDay(for: entry.date)
            caloriesByDay[day, default: 0] += entry.product?.calories ?? 0
            proteinByDay[day, default: 0] += (entry.product?.protein ?? 0).safeFinite
        }

        let averageCaloriesThisWeek = average(values: Array(caloriesByDay.values))
        let proteinAverageThisWeek = average(values: proteinByDay.values.map { Int(max($0.safeFinite, 0)) })
        let nutritionDaysInTarget = nutritionTargetDays(from: caloriesByDay.values)

        var waterByDay: [Date: Double] = [:]

        for entry in waterEntries where entry.gender == gender && entry.date >= weekStart {
            let ownerMatches = entry.ownerId == ownerId || entry.user?.id == userData.id
            guard ownerMatches else { continue }
            let day = calendar.startOfDay(for: entry.date)
            waterByDay[day, default: 0] += entry.intake.safeFinite
        }

        let waterTotals = Array(waterByDay.values)
        let averageWaterThisWeek = average(values: waterTotals)
        let waterGoalDays = waterGoalLiters > 0
            ? waterTotals.filter { $0 >= waterGoalLiters }.count
            : 0

        let latestMeasurement = measurements.first { measurement in
            guard let ownerId else { return false }
            return measurement.ownerId == ownerId
        }

        return ProfileProgressSnapshot(
            weekWorkoutsCount: weekWorkoutsCount,
            monthWorkoutsCount: monthWorkoutsCount,
            completedSetsThisWeek: completedSetsThisWeek,
            trainingVolumeThisWeek: Int(trainingVolumeThisWeek.safeFinite),
            totalWorkoutMinutesThisMonth: totalWorkoutSecondsThisMonth / 60,
            averageCaloriesThisWeek: averageCaloriesThisWeek,
            proteinAverageThisWeek: proteinAverageThisWeek,
            nutritionDaysInTarget: nutritionDaysInTarget,
            averageWaterThisWeek: averageWaterThisWeek,
            waterGoalDays: waterGoalDays,
            latestMeasurement: latestMeasurement
        )
    }

    private func average(values: [Int]) -> Int {
        guard values.isEmpty == false else { return 0 }
        return values.reduce(0, +) / values.count
    }

    private func average(values: [Double]) -> Double {
        guard values.isEmpty == false else { return 0 }
        return (values.reduce(0, +) / Double(values.count)).safeFinite
    }

    private func nutritionTargetDays(from caloriesByDay: Dictionary<Date, Int>.Values) -> Int {
        guard userData.calories > 0 else { return 0 }
        let lower = Int(Double(userData.calories) * 0.90)
        let upper = Int(Double(userData.calories) * 1.10)
        return caloriesByDay.filter { $0 >= lower && $0 <= upper }.count
    }

    private func progressSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.weight(.semibold))

            VStack(spacing: 10) {
                content()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(profileCardBackground))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(profileCardBorder))
    }

    private func formattedMinutes(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours) \(AppLocalizer.string("unit.hours.short")) \(remainingMinutes) \(AppLocalizer.string("unit.minutes.short"))"
        }
        return "\(minutes) \(AppLocalizer.string("unit.minutes.short"))"
    }

    private func formattedLiters(_ value: Double) -> String {
        String(format: "%.1f %@", value, AppLocalizer.string("unit.liters.short"))
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month().year())
    }

    private struct ProfileProgressSnapshot {
        let weekWorkoutsCount: Int
        let monthWorkoutsCount: Int
        let completedSetsThisWeek: Int
        let trainingVolumeThisWeek: Int
        let totalWorkoutMinutesThisMonth: Int
        let averageCaloriesThisWeek: Int
        let proteinAverageThisWeek: Int
        let nutritionDaysInTarget: Int
        let averageWaterThisWeek: Double
        let waterGoalDays: Int
        let latestMeasurement: BodyMeasurements?
    }
}

private struct ProgressSummaryGrid: View {
    let workouts: Int
    let averageCalories: Int
    let waterGoalDays: Int
    let weight: Int

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
            summaryCard(
                title: AppLocalizer.string("tab.workouts"),
                value: "\(workouts)",
                subtitle: AppLocalizer.string("profile.progress.this_week"),
                icon: "dumbbell.fill"
            )
            summaryCard(
                title: AppLocalizer.string("tab.nutrition"),
                value: "\(averageCalories)",
                subtitle: AppLocalizer.string("profile.progress.kcal_average"),
                icon: "flame.fill"
            )
            summaryCard(
                title: AppLocalizer.string("tab.water"),
                value: "\(waterGoalDays)/7",
                subtitle: AppLocalizer.string("profile.progress.goal_days"),
                icon: "drop.fill"
            )
            summaryCard(
                title: AppLocalizer.string("profile.weight"),
                value: "\(weight)",
                subtitle: AppLocalizer.string("unit.kg"),
                icon: "scalemass"
            )
        }
    }

    private func summaryCard(title: String, value: String, subtitle: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(profileCardBackground))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(profileCardBorder))
    }
}

private struct ProgressMetricRow: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color(.tertiarySystemBackground)))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
    }
}
