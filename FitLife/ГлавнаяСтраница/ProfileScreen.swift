import SwiftUI
import SwiftData
import PhotosUI
import UIKit

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
                        ProfileHeroCard(
                            progressUserData: user,
                            ownerId: currentOwnerId,
                            gender: editingGender
                        )
                    } else {
                        ProfileHeroCard()
                    }

                    SectionCard(title: AppLocalizer.string("profile.gender")) {
                        PremiumSegmentedPicker(
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
                                PremiumSegmentedPicker(
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
                                PremiumSegmentedPicker(
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
                                PremiumSegmentedPicker(
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

struct PremiumSegmentedPicker<Selection: Hashable>: View {
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
                                                theme.accent.opacity(theme.isDark ? 0.92 : 0.86),
                                                theme.accent
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
                        .frame(height: 22)
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

    @State private var proteins: Int
    @State private var fats: Int
    @State private var carbs: Int

    init(userData: UserData) {
        self.userData = userData
        _proteins = State(initialValue: userData.proteins)
        _fats = State(initialValue: userData.fats)
        _carbs = State(initialValue: userData.carbs)
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
                            macroField(
                                title: AppLocalizer.string("macro.protein"),
                                value: $proteins,
                                unit: AppLocalizer.string("unit.grams.short"),
                                systemImage: "leaf.fill",
                                tint: HomeDarkColors.green,
                                range: 0...500
                            )
                            macroField(
                                title: AppLocalizer.string("macro.fat"),
                                value: $fats,
                                unit: AppLocalizer.string("unit.grams.short"),
                                systemImage: "drop.fill",
                                tint: Color(hex: "FFD60A"),
                                range: 0...300
                            )
                            macroField(
                                title: AppLocalizer.string("macro.carbs"),
                                value: $carbs,
                                unit: AppLocalizer.string("unit.grams.short"),
                                systemImage: "circle.grid.2x2.fill",
                                tint: Color(hex: "7B61FF"),
                                range: 0...700
                            )
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

    private var calculatedCalories: Int {
        (proteins * 4) + (fats * 9) + (carbs * 4)
    }

    private func macroField(
        title: String,
        value: Binding<Int>,
        unit: String,
        systemImage: String,
        tint: Color,
        range: ClosedRange<Int>
    ) -> some View {
        ManualMacroGoalRow(
            title: title,
            value: value,
            unit: unit,
            systemImage: systemImage,
            tint: tint,
            range: range
        )
    }

    private func save() {
        userData.nutritionGoalMode = .manual
        userData.calories = calculatedCalories
        userData.proteins = proteins
        userData.fats = fats
        userData.carbs = carbs
        try? modelContext.save()
        dismiss()
    }
}

private struct ManualMacroGoalRow: View {
    let title: String
    @Binding var value: Int
    let unit: String
    let systemImage: String
    let tint: Color
    let range: ClosedRange<Int>

    @Environment(\.colorScheme) private var colorScheme
    @State private var showPicker = false

    private var theme: AppTheme { AppTheme(colorScheme) }

    var body: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: 14) {
                ProfileIconTile(systemImage: systemImage, tint: tint, size: 34, cornerRadius: 10)

                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.primaryText)

                Spacer(minLength: 8)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(value)")
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(theme.primaryText)

                    Text(unit)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    Capsule(style: .continuous)
                        .fill(theme.accent.opacity(theme.isDark ? 0.16 : 0.10))
                }

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.tertiaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(profileCardBackground)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(profileCardBorder)
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPicker) {
            ProfileScreen.NumberWheelPickerInt(
                title: title,
                value: $value,
                range: range,
                unit: unit
            )
        }
    }
}

private struct ProfileHeroCard: View {
    let progressUserData: UserData?
    let ownerId: String?
    let gender: Gender

    @Query private var achievementProgressRecords: [UserAchievementProgress]
    @Query private var unlockedAchievements: [UnlockedAchievement]
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var sessionStore: AppSessionStore
    @EnvironmentObject private var achievementCelebrationStore: AchievementCelebrationStore
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var isShowingPhotoActions = false
    @State private var isShowingPhotoPicker = false
    @State private var isUploadingPhoto = false
    @State private var photoErrorMessage = ""
    @State private var isShowingPhotoError = false
    @State private var isAchievementPreviewPresented = false

    private var theme: AppTheme { AppTheme(colorScheme) }

    private var achievementProgress: AchievementLevelProgress {
        guard let ownerId else { return AchievementLevelCalculator.progress(totalXP: 0) }
        let scope = AchievementEngine.scopeID(ownerId: ownerId, gender: gender)
        let totalXP = achievementProgressRecords.first { $0.scopeID == scope }?.totalXP ?? 0
        return AchievementLevelCalculator.progress(totalXP: totalXP)
    }

    private var displayName: String? {
        let candidates = [
            sessionStore.profile?.displayName,
            sessionStore.firebaseUser?.displayName,
            sessionStore.firebaseUser?.email?.split(separator: "@").first.map(String.init)
        ]
        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { $0.isEmpty == false }
    }

    private var scopedUnlocks: [UnlockedAchievement] {
        guard let ownerId else { return [] }
        let scope = AchievementEngine.scopeID(ownerId: ownerId, gender: gender)
        return unlockedAchievements.filter { $0.scopeID == scope }
    }

    private var unseenUnlocks: [UnlockedAchievement] {
        scopedUnlocks.filter(\.isUnseen).sorted { $0.unlockedAt > $1.unlockedAt }
    }

    private var newestUnseenUnlock: UnlockedAchievement? { unseenUnlocks.first }

    private var newestUnseenDefinition: AchievementDefinition? {
        newestUnseenUnlock
            .flatMap { AchievementID(rawValue: $0.achievementID) }
            .flatMap(AchievementCatalog.definition(for:))
    }

    private var achievementPreviewID: String {
        newestUnseenUnlock?.compositeID ?? "seen"
    }

    init() {
        progressUserData = nil
        ownerId = nil
        gender = .male
    }

    init(progressUserData: UserData, ownerId: String?, gender: Gender) {
        self.progressUserData = progressUserData
        self.ownerId = ownerId
        self.gender = gender
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                Button {
                    isShowingPhotoActions = true
                } label: {
                    profileAvatar
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AppLocalizer.string("profile.photo.change"))

                VStack(alignment: .leading, spacing: 5) {
                    if progressUserData != nil {
                        Text(displayName ?? AppLocalizer.format("profile.achievements.level", achievementProgress.level))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(theme.primaryText)
                            .lineLimit(1)

                        if displayName != nil {
                            Text(AppLocalizer.format("profile.achievements.level", achievementProgress.level))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(theme.accent)
                        }

                        ProgressView(value: achievementProgress.fraction)
                            .tint(theme.accent)
                            .frame(maxWidth: 220)

                        Text(achievementProgress.isMaximumLevel
                             ? AppLocalizer.string("profile.achievements.maximum_reached")
                             : AppLocalizer.format(
                                "profile.achievements.xp_remaining",
                                achievementProgress.level + 1,
                                achievementProgress.remainingXP
                             ))
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                            .lineLimit(2)
                    } else {
                        Text(AppLocalizer.string("tab.profile"))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(theme.primaryText)

                        Text(AppLocalizer.string("profile.subtitle"))
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if let progressUserData {
                Rectangle()
                    .fill(theme.border.opacity(theme.isDark ? 0.70 : 0.55))
                    .frame(height: 1)
                    .padding(.top, 2)

                NavigationLink {
                    ProfileProgressScreen(
                        userData: progressUserData,
                        ownerId: ownerId,
                        gender: gender
                    )
                } label: {
                    HStack(spacing: 12) {
                        if let definition = newestUnseenDefinition {
                            ZStack {
                                Image(systemName: "hexagon.fill")
                                    .font(.system(size: 48, weight: .regular))
                                    .foregroundStyle(theme.accent.opacity(theme.isDark ? 0.24 : 0.14))
                                Image(systemName: "hexagon")
                                    .font(.system(size: 48, weight: .semibold))
                                    .foregroundStyle(theme.accent)
                                Image(systemName: definition.icon)
                                    .font(.system(size: 19, weight: .bold))
                                    .foregroundStyle(theme.accent)
                            }
                            .frame(width: 52, height: 54)
                            .scaleEffect(isAchievementPreviewPresented ? 1 : 0.82)
                        } else {
                            ProfileIconTile(
                                systemImage: "chart.line.uptrend.xyaxis",
                                tint: theme.accent,
                                size: 40,
                                cornerRadius: 12
                            )
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(unseenUnlocks.isEmpty
                                 ? AppLocalizer.string("profile.achievements.title")
                                 : unseenUnlocks.count == 1
                                    ? AppLocalizer.string("profile.achievements.preview.new")
                                    : AppLocalizer.format("profile.achievements.preview.new_count", unseenUnlocks.count))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(unseenUnlocks.isEmpty ? theme.primaryText : theme.accent)

                            Text(newestUnseenDefinition.map {
                                AppLocalizer.format(
                                    "profile.achievements.preview.reward",
                                    AppLocalizer.string($0.titleKey),
                                    newestUnseenUnlock?.rewardedXP ?? $0.xpReward
                                )
                            } ?? AppLocalizer.format(
                                "profile.achievements.preview.summary",
                                achievementProgress.level,
                                achievementProgress.totalXP,
                                scopedUnlocks.count
                            ))
                                .font(.caption)
                                .foregroundStyle(theme.secondaryText)
                                .lineLimit(2)
                        }

                        Spacer(minLength: 8)

                        if unseenUnlocks.isEmpty == false {
                            Text(AppLocalizer.string("profile.achievements.preview.open"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.accent)
                                .lineLimit(1)
                        }

                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(theme.tertiaryText)
                    }
                    .padding(12)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(unseenUnlocks.isEmpty ? Color.clear : theme.accent.opacity(theme.isDark ? 0.10 : 0.08))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                unseenUnlocks.isEmpty ? Color.clear : theme.accent.opacity(0.38),
                                lineWidth: 1
                            )
                    }
                    .scaleEffect(reduceMotion || unseenUnlocks.isEmpty || isAchievementPreviewPresented ? 1 : 0.97)
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .task(id: achievementPreviewID) {
                    isAchievementPreviewPresented = reduceMotion || unseenUnlocks.isEmpty
                    guard reduceMotion == false, unseenUnlocks.isEmpty == false else { return }
                    await Task.yield()
                    withAnimation(.spring(response: 0.52, dampingFraction: 0.68)) {
                        isAchievementPreviewPresented = true
                    }
                }

                Rectangle()
                    .fill(theme.border.opacity(theme.isDark ? 0.70 : 0.55))
                    .frame(height: 1)
                    .padding(.top, 2)

                NavigationLink {
                    WorkoutExerciseRecordsLibraryScreen()
                } label: {
                    HStack(spacing: 12) {
                        ProfileIconTile(systemImage: "trophy.fill", tint: theme.accent, size: 40, cornerRadius: 12)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(AppLocalizer.string("profile.exercise_records.title"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(theme.primaryText)

                            Text(AppLocalizer.string("profile.exercise_records.subtitle"))
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
        .lightweightAdaptiveHomeCard(
            theme: theme,
            cornerRadius: HomeDarkMetrics.cardCornerRadius,
            showsShadow: false
        )
        .padding(.horizontal)
        .confirmationDialog(
            AppLocalizer.string("profile.photo.title"),
            isPresented: $isShowingPhotoActions,
            titleVisibility: .visible
        ) {
            Button(AppLocalizer.string("profile.photo.choose")) {
                Task {
                    try? await Task.sleep(for: .milliseconds(200))
                    isShowingPhotoPicker = true
                }
            }

            if sessionStore.profile?.photoURL != nil || previewImage != nil {
                Button(AppLocalizer.string("profile.photo.remove"), role: .destructive) {
                    Task { await removeProfilePhoto() }
                }
            }

            Button(AppLocalizer.string("common.cancel"), role: .cancel) {}
        }
        .photosPicker(
            isPresented: $isShowingPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images,
            preferredItemEncoding: .current
        )
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task { await uploadProfilePhoto(from: item) }
        }
        .alert(AppLocalizer.string("common.error"), isPresented: $isShowingPhotoError) {
            Button(AppLocalizer.string("common.ok"), role: .cancel) {}
        } message: {
            Text(photoErrorMessage)
        }
    }

    private var profileAvatar: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                Circle()
                    .fill(theme.accent.opacity(theme.isDark ? 0.18 : 0.11))

                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFill()
                } else if
                    let urlString = sessionStore.profile?.photoURL,
                    let url = URL(string: urlString) {
                    CachedProfileAvatarImage(
                        url: url,
                        cacheKey: profilePhotoCacheKey
                    ) {
                        fallbackProfileIcon
                    }
                } else {
                    fallbackProfileIcon
                }
            }
            .frame(width: 68, height: 68)
            .clipShape(Circle())
            .overlay(Circle().stroke(theme.accent.opacity(0.22), lineWidth: 1))

            ZStack {
                Circle()
                    .fill(theme.accent)
                if isUploadingPhoto {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.65)
                } else {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 23, height: 23)
            .overlay(Circle().stroke(theme.card, lineWidth: 2))
        }
        .opacity(isUploadingPhoto ? 0.82 : 1)
    }

    private var fallbackProfileIcon: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(theme.accent)
    }

    @MainActor
    private func uploadProfilePhoto(from item: PhotosPickerItem) async {
        isUploadingPhoto = true
        defer {
            isUploadingPhoto = false
            selectedPhotoItem = nil
        }

        do {
            guard
                let sourceData = try await item.loadTransferable(type: Data.self),
                let image = UIImage(data: sourceData),
                let preparedImage = Self.preparedProfileImage(from: image),
                let uploadData = preparedImage.jpegData(compressionQuality: 0.82)
            else {
                throw NSError(
                    domain: "FitLife.ProfilePhoto",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: AppLocalizer.string("profile.photo.invalid")]
                )
            }

            previewImage = preparedImage
            try await sessionStore.updateProfilePhoto(with: uploadData)
            try? ProfileAvatarImageCache.save(data: uploadData, cacheKey: profilePhotoCacheKey)
        } catch {
            previewImage = nil
            photoErrorMessage = AppErrorPresenter.message(for: error)
            isShowingPhotoError = true
        }
    }

    @MainActor
    private func removeProfilePhoto() async {
        isUploadingPhoto = true
        defer { isUploadingPhoto = false }

        do {
            try await sessionStore.removeProfilePhoto()
            previewImage = nil
            ProfileAvatarImageCache.remove(cacheKey: profilePhotoCacheKey)
        } catch {
            photoErrorMessage = AppErrorPresenter.message(for: error)
            isShowingPhotoError = true
        }
    }

    private static func preparedProfileImage(from image: UIImage) -> UIImage? {
        let maximumDimension: CGFloat = 1_024
        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }

        let scale = min(1, maximumDimension / max(sourceSize.width, sourceSize.height))
        let targetSize = CGSize(
            width: max(1, (sourceSize.width * scale).rounded()),
            height: max(1, (sourceSize.height * scale).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    private var profilePhotoCacheKey: String {
        ownerId ?? sessionStore.firebaseUser?.uid ?? "current-user"
    }
}

private struct CachedProfileAvatarImage<Placeholder: View>: View {
    let url: URL
    private let cacheKey: String
    private let placeholder: Placeholder
    @State private var image: UIImage?

    init(
        url: URL,
        cacheKey: String,
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.url = url
        self.cacheKey = cacheKey
        self.placeholder = placeholder()
        _image = State(initialValue: ProfileAvatarImageCache.read(cacheKey: cacheKey))
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .task(id: url.absoluteString) {
            await refreshImage()
        }
    }

    @MainActor
    private func refreshImage() async {
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad

        guard
            let (data, response) = try? await URLSession.shared.data(for: request),
            let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode),
            let downloadedImage = UIImage(data: data)
        else { return }

        image = downloadedImage
        try? ProfileAvatarImageCache.save(data: data, cacheKey: cacheKey)
    }
}

private enum ProfileAvatarImageCache {
    static func read(cacheKey: String) -> UIImage? {
        guard let url = cacheURL(cacheKey: cacheKey) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    static func save(data: Data, cacheKey: String) throws {
        guard let url = cacheURL(cacheKey: cacheKey) else { return }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }

    static func remove(cacheKey: String) {
        guard let url = cacheURL(cacheKey: cacheKey) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static func cacheURL(cacheKey: String) -> URL? {
        guard let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let safeKey = cacheKey.replacingOccurrences(
            of: "[^A-Za-z0-9_-]",
            with: "_",
            options: .regularExpression
        )
        return root
            .appendingPathComponent("FitLifeProfileAvatars", isDirectory: true)
            .appendingPathComponent("\(safeKey).image")
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
            .lightweightAdaptiveHomeCard(theme: theme, cornerRadius: 16, showsShadow: false)
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
            .lightweightAdaptiveHomeCard(theme: theme, cornerRadius: 16, showsShadow: false)
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
    @Query private var achievementProgressRecords: [UserAchievementProgress]
    @Query private var xpTransactions: [XPTransaction]
    @Query private var unlockedAchievements: [UnlockedAchievement]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var achievementCelebrationStore: AchievementCelebrationStore

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

    private var achievementScopeID: String? {
        guard let ownerId, ownerId.isEmpty == false else { return nil }
        return AchievementEngine.scopeID(ownerId: ownerId, gender: gender)
    }

    var body: some View {
        let snapshot = makeSnapshot()
        let theme = AppTheme(colorScheme)
        let scope = achievementScopeID
        let storedProgress = achievementProgressRecords.first { $0.scopeID == scope }
        let scopedTransactions = xpTransactions.filter { $0.scopeID == scope }
        let scopedUnlocks = unlockedAchievements.filter { $0.scopeID == scope }
        let weeklyXP = scopedTransactions
            .filter { $0.occurredAt >= weekStart }
            .reduce(0) { $0 + max($1.amount, 0) }

        ScrollView(showsIndicators: false) {
            ProgressAchievementsDashboard(
                snapshot: snapshot,
                theme: theme,
                achievementProgress: storedProgress,
                weeklyXP: weeklyXP,
                unlockedAchievements: scopedUnlocks,
                onResetXP: {
                    guard let scope else { return }
                    try? AchievementEngine.resetProgress(scopeID: scope, modelContext: modelContext)
                    achievementCelebrationStore.dismiss()
                    achievementCelebrationStore.updateUnreadCount(0)
                }
            )
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 120)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(AppLocalizer.string("profile.achievements.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            var didChange = false
            for unlock in scopedUnlocks where unlock.isUnseen {
                unlock.isUnseen = false
                didChange = true
            }
            if didChange {
                try? modelContext.save()
            }
            achievementCelebrationStore.updateUnreadCount(0)
        }
    }

    private func makeSnapshot() -> ProfileProgressSnapshot {
        var weekWorkoutsCount = 0
        var monthWorkoutsCount = 0
        var completedSetsThisWeek = 0
        var trainingVolumeThisWeek = 0.0
        var totalWorkoutSecondsThisMonth = 0
        var workoutDays = Set<Date>()

        for workout in workouts where workout.ownerId == ownerId && workout.gender == gender && workout.endedAt != nil {
            if let endedAt = workout.endedAt, endedAt >= weekStart {
                workoutDays.insert(calendar.startOfDay(for: endedAt))
            }

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
        var nutritionDays = Set<Date>()

        for entry in foodEntries where entry.ownerId == ownerId && entry.gender == gender && entry.date >= weekStart {
            let day = calendar.startOfDay(for: entry.date)
            nutritionDays.insert(day)
            caloriesByDay[day, default: 0] += entry.product?.calories ?? 0
            proteinByDay[day, default: 0] += (entry.product?.protein ?? 0).safeFinite
        }

        let averageCaloriesThisWeek = average(values: Array(caloriesByDay.values))
        let proteinAverageThisWeek = average(values: proteinByDay.values.map { Int(max($0.safeFinite, 0)) })
        let nutritionDaysInTarget = nutritionTargetDays(from: caloriesByDay.values)

        var waterByDay: [Date: Double] = [:]
        var waterGoalDaySet = Set<Date>()

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
        if waterGoalLiters > 0 {
            for (day, intake) in waterByDay where intake >= waterGoalLiters {
                waterGoalDaySet.insert(day)
            }
        }

        let latestMeasurement = measurements.first { measurement in
            guard let ownerId else { return false }
            return measurement.ownerId == ownerId
        }
        let weekRhythm = makeWeekRhythm(
            nutritionDays: nutritionDays,
            waterGoalDays: waterGoalDaySet,
            workoutDays: workoutDays
        )

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
            weekRhythm: weekRhythm,
            latestMeasurement: latestMeasurement
        )
    }

    private func makeWeekRhythm(
        nutritionDays: Set<Date>,
        waterGoalDays: Set<Date>,
        workoutDays: Set<Date>
    ) -> WeekRhythmSnapshot {
        let days = (0..<7).compactMap { offset -> WeekRhythmDay? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            return WeekRhythmDay(
                date: day,
                hasNutrition: nutritionDays.contains(day),
                hasWaterGoal: waterGoalDays.contains(day),
                hasWorkout: workoutDays.contains(day)
            )
        }

        return WeekRhythmSnapshot(days: days)
    }

    private struct ProgressAchievementsDashboard: View {
        let snapshot: ProfileProgressSnapshot
        let theme: AppTheme
        let achievementProgress: UserAchievementProgress?
        let weeklyXP: Int
        let unlockedAchievements: [UnlockedAchievement]
        let onResetXP: () -> Void

        private var levelProgress: AchievementLevelProgress {
            AchievementLevelCalculator.progress(totalXP: achievementProgress?.totalXP ?? 0)
        }
        private var unlockedIDs: Set<AchievementID> {
            Set(unlockedAchievements.compactMap { AchievementID(rawValue: $0.achievementID) })
        }
        private var presentedDefinitions: [AchievementDefinition] {
            AchievementCatalog.definitions.filter {
                $0.visibility == .standard || unlockedIDs.contains($0.id)
            }
        }
        private var planScore: Int {
            min(max(Int((Double(snapshot.weekRhythm.totalSignals) / 21.0 * 100).rounded()), 0), 100)
        }
        private var unlockedBadges: [AchievementBadge] {
            unlockedAchievements
                .sorted { $0.unlockedAt > $1.unlockedAt }
                .compactMap { unlock in
                    guard let id = AchievementID(rawValue: unlock.achievementID),
                          let definition = AchievementCatalog.definition(for: id) else { return nil }
                    return AchievementBadge(definition: definition, unlock: unlock)
                }
        }
        private var nextAchievements: [AchievementGoal] {
            presentedDefinitions
                .filter { unlockedIDs.contains($0.id) == false }
                .map { AchievementGoal(definition: $0, current: currentValue(for: $0.id)) }
                .sorted {
                    let lhs = Double(min($0.current, $0.definition.target)) / Double(max($0.definition.target, 1))
                    let rhs = Double(min($1.current, $1.definition.target)) / Double(max($1.definition.target, 1))
                    return lhs == rhs ? $0.definition.target < $1.definition.target : lhs > rhs
                }
                .prefix(3)
                .map { $0 }
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                NavigationLink {
                    AchievementLevelsScreen(
                        totalXP: levelProgress.totalXP,
                        theme: theme,
                        onResetXP: onResetXP
                    )
                } label: {
                    levelCard
                }
                .buttonStyle(.plain)
                weeklySummary

                HStack {
                    sectionTitle(AppLocalizer.string("profile.achievements.recent"))
                    NavigationLink {
                        AchievementListScreen(
                            title: AppLocalizer.string("profile.achievements.all"),
                            definitions: presentedDefinitions,
                            theme: theme,
                            progress: achievementProgress,
                            unlocks: unlockedAchievements
                        )
                    } label: {
                        Text(AppLocalizer.string("profile.achievements.view_all"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.accent)
                    }
                }

                if unlockedBadges.isEmpty {
                    Text(AppLocalizer.string("profile.achievements.none_unlocked"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(profileCardBackground))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(profileCardBorder))
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(unlockedBadges) { badge in
                                NavigationLink {
                                    achievementDetail(for: badge.definition)
                                } label: {
                                    badgeCard(badge)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                }

                sectionTitle(AppLocalizer.string("profile.achievements.next"))
                VStack(spacing: 0) {
                    if nextAchievements.isEmpty {
                        Text(AppLocalizer.string("profile.achievements.all_unlocked"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 14)
                    } else {
                        ForEach(Array(nextAchievements.enumerated()), id: \.element.id) { index, goal in
                            NavigationLink {
                                achievementDetail(for: goal.definition)
                            } label: {
                                goalRow(
                                    icon: goal.definition.icon,
                                    title: AppLocalizer.string(goal.definition.titleKey),
                                    current: goal.current,
                                    target: goal.definition.target
                                )
                            }
                            .buttonStyle(.plain)
                            if index < nextAchievements.count - 1 {
                                Divider().padding(.leading, 38)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(profileCardBackground))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(profileCardBorder))

                sectionTitle(AppLocalizer.string("profile.achievements.categories"))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                    ForEach(AchievementCategory.allCases, id: \.self) { category in
                        categoryLink(icon: categoryIcon(category), title: categoryTitle(category), category: category)
                    }
                }
            }
        }

        private var levelCard: some View {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(AppLocalizer.format("profile.achievements.level", levelProgress.level))
                        .font(.title3.weight(.bold))
                    Text(levelProgress.isMaximumLevel
                         ? "\(levelProgress.totalXP) XP"
                         : "\(levelProgress.xpInsideLevel) / \(levelProgress.requiredXP) XP")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(theme.accent)
                    ProgressView(value: levelProgress.fraction)
                        .tint(theme.accent)
                    Text(levelProgress.isMaximumLevel
                         ? AppLocalizer.string("profile.achievements.maximum_reached")
                         : AppLocalizer.format("profile.achievements.xp_remaining", levelProgress.level + 1, levelProgress.remainingXP))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(AppLocalizer.string("profile.achievements.motto"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                ZStack {
                    Hexagon()
                        .stroke(theme.accent, lineWidth: 4)
                        .frame(width: 78, height: 86)
                        .shadow(color: theme.accent.opacity(0.55), radius: 12)
                    Text("\(levelProgress.level)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(profileCardBackground))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(profileCardBorder))
        }

        private var weeklySummary: some View {
            HStack(spacing: 0) {
                summaryItem(icon: "flame.fill", value: "\(achievementProgress?.currentStreak ?? 0)", label: AppLocalizer.string("profile.achievements.summary.active_days"))
                summaryDivider
                summaryItem(icon: "hexagon.fill", value: "+\(weeklyXP) XP", label: AppLocalizer.string("profile.achievements.summary.week"))
                summaryDivider
                summaryItem(icon: "target", value: "\(planScore)%", label: AppLocalizer.string("profile.achievements.summary.plan_score"))
            }
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(profileCardBackground))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(profileCardBorder))
        }

        private func summaryItem(icon: String, value: String, label: String) -> some View {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(value).font(.caption.weight(.bold)).lineLimit(1)
                    Text(label).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
        }

        private var summaryDivider: some View {
            Rectangle().fill(profileCardBorder).frame(width: 1, height: 30)
        }

        private func sectionTitle(_ title: String) -> some View {
            Text(title)
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        }

        private func badgeCard(_ badge: AchievementBadge) -> some View {
            VStack(spacing: 6) {
                ZStack {
                    Hexagon().fill(theme.accent.opacity(0.14))
                    Hexagon().stroke(theme.accent, lineWidth: 2)
                    Image(systemName: badge.definition.icon)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(theme.accent)
                }
                .frame(width: 44, height: 48)
                Text(AppLocalizer.string(badge.definition.titleKey))
                    .font(.system(size: 11, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(width: 86, height: 94)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(profileCardBackground))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(profileCardBorder))
            .foregroundStyle(.primary)
        }

        private func goalRow(icon: String, title: String, current: Int, target: Int) -> some View {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 9) {
                    Image(systemName: icon).foregroundStyle(theme.accent).frame(width: 22)
                    Text(title).font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(min(current, target)) / \(target)").font(.subheadline.weight(.bold))
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: Double(min(current, target)), total: Double(target)).tint(theme.accent)
            }
            .padding(.vertical, 10)
            .foregroundStyle(.primary)
        }

        private func currentValue(for id: AchievementID) -> Int {
            Self.metricValue(for: id, progress: achievementProgress)
        }

        private static func metricValue(for id: AchievementID, progress: UserAchievementProgress?) -> Int {
            progress?.metricValue(for: id) ?? 0
        }

        private func categoryTitle(_ category: AchievementCategory) -> String {
            switch category {
            case .firstSteps:
                return AppLocalizer.string("profile.achievements.category.firstSteps")
            case .workouts:
                return AppLocalizer.string("tab.workouts")
            case .water:
                return AppLocalizer.string("tab.water")
            case .nutrition:
                return AppLocalizer.string("tab.nutrition")
            case .steps:
                return AppLocalizer.string("profile.achievements.category.steps")
            case .coach:
                return AppLocalizer.string("profile.achievements.category.coach")
            case .measurements:
                return AppLocalizer.string("profile.achievements.category.measurements")
            }
        }

        private func categoryIcon(_ category: AchievementCategory) -> String {
            switch category {
            case .firstSteps: return "flag.fill"
            case .workouts: return "dumbbell.fill"
            case .water: return "drop.fill"
            case .nutrition: return "fork.knife"
            case .steps: return "figure.walk"
            case .coach: return "person.2.fill"
            case .measurements: return "ruler.fill"
            }
        }

        private func achievementDetail(for definition: AchievementDefinition) -> some View {
            AchievementDetailScreen(
                definition: definition,
                current: currentValue(for: definition.id),
                unlock: unlockedAchievements.first { $0.achievementID == definition.id.rawValue },
                theme: theme
            )
        }

        private func categoryLink(icon: String, title: String, category: AchievementCategory) -> some View {
            NavigationLink {
                AchievementListScreen(
                    title: title,
                    definitions: presentedDefinitions.filter { $0.category == category },
                    theme: theme,
                    progress: achievementProgress,
                    unlocks: unlockedAchievements
                )
            } label: {
                categoryCard(icon: icon, title: title, category: category)
            }
            .buttonStyle(.plain)
        }

        private func categoryCard(icon: String, title: String, category: AchievementCategory) -> some View {
            let definitions = presentedDefinitions.filter { $0.category == category }
            let current = definitions.filter { unlockedIDs.contains($0.id) }.count
            let target = definitions.count
            return HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(theme.accent)
                    .font(.headline)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(theme.accent.opacity(0.14)))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.caption.weight(.semibold)).lineLimit(1)
                    HStack(spacing: 6) {
                        Text("\(current) / \(target)").font(.caption.weight(.bold)).foregroundStyle(theme.accent)
                        ProgressView(value: Double(min(current, target)), total: Double(target)).tint(theme.accent)
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(profileCardBackground))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(profileCardBorder))
            .foregroundStyle(.primary)
        }

        private struct AchievementLevelsScreen: View {
            let totalXP: Int
            let theme: AppTheme
            let onResetXP: () -> Void
            @State private var isResetConfirmationPresented = false

            private var progress: AchievementLevelProgress {
                AchievementLevelCalculator.progress(totalXP: totalXP)
            }

            private var displayedLevels: ClosedRange<Int> {
                1...AchievementLevelCalculator.maximumLevel
            }

            var body: some View {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(AppLocalizer.format("profile.achievements.level", progress.level))
                                .font(.title2.weight(.bold))
                            Text(AppLocalizer.format("profile.achievements.levels.total_xp_value", totalXP))
                                .font(.headline)
                                .foregroundStyle(theme.accent)
                            ProgressView(value: progress.fraction)
                                .tint(theme.accent)
                            Text(progress.isMaximumLevel
                                 ? AppLocalizer.string("profile.achievements.maximum_reached")
                                 : AppLocalizer.format("profile.achievements.xp_remaining", progress.level + 1, progress.remainingXP))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }

                    Section(AppLocalizer.string("profile.achievements.levels.requirements")) {
                        ForEach(displayedLevels, id: \.self) { level in
                            levelRow(level)
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            isResetConfirmationPresented = true
                        } label: {
                            Label(
                                AppLocalizer.string("profile.achievements.reset_xp.action"),
                                systemImage: "arrow.counterclockwise"
                            )
                        }
                    } header: {
                        Text(AppLocalizer.string("profile.achievements.reset_xp.section"))
                    } footer: {
                        Text(AppLocalizer.string("profile.achievements.reset_xp.footer"))
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle(AppLocalizer.string("profile.achievements.levels.title"))
                .navigationBarTitleDisplayMode(.inline)
                .alert(
                    AppLocalizer.string("profile.achievements.reset_xp.confirm_title"),
                    isPresented: $isResetConfirmationPresented
                ) {
                    Button(AppLocalizer.string("common.cancel"), role: .cancel) {}
                    Button(AppLocalizer.string("profile.achievements.reset_xp.confirm_action"), role: .destructive) {
                        onResetXP()
                    }
                } message: {
                    Text(AppLocalizer.string("profile.achievements.reset_xp.confirm_message"))
                }
            }

            private func levelRow(_ level: Int) -> some View {
                let requiredTotal = AchievementLevelCalculator.totalXPRequired(toReach: level)
                let isCurrent = level == progress.level
                let isReached = level < progress.level

                return HStack(spacing: 12) {
                    ZStack {
                        Hexagon()
                            .fill((isReached || isCurrent) ? theme.accent.opacity(0.16) : Color.secondary.opacity(0.10))
                        Hexagon()
                            .stroke((isReached || isCurrent) ? theme.accent : Color.secondary.opacity(0.35), lineWidth: 2)
                        Text("\(level)")
                            .font(.headline.weight(.bold))
                    }
                    .frame(width: 42, height: 46)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(AppLocalizer.format("profile.achievements.levels.level_number", level))
                            .font(.body.weight(isCurrent ? .bold : .semibold))
                        Text(AppLocalizer.format("profile.achievements.levels.required_xp", requiredTotal))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if isCurrent {
                        Text(AppLocalizer.string("profile.achievements.levels.current"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.accent)
                    } else if isReached {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(theme.accent)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 3)
            }
        }

        private struct AchievementListScreen: View {
            let title: String
            let definitions: [AchievementDefinition]
            let theme: AppTheme
            let progress: UserAchievementProgress?
            let unlocks: [UnlockedAchievement]

            var body: some View {
                List(definitions) { definition in
                    let current = ProgressAchievementsDashboard.metricValue(for: definition.id, progress: progress)
                    let unlock = unlocks.first { $0.achievementID == definition.id.rawValue }

                    NavigationLink {
                        AchievementDetailScreen(
                            definition: definition,
                            current: current,
                            unlock: unlock,
                            theme: theme
                        )
                    } label: {
                        achievementRow(definition, current: current, isUnlocked: unlock != nil)
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
            }

            private func achievementRow(_ definition: AchievementDefinition, current: Int, isUnlocked: Bool) -> some View {
                HStack(spacing: 12) {
                    ZStack {
                        Hexagon().fill(theme.accent.opacity(isUnlocked ? 0.16 : 0.08))
                        Hexagon().stroke(isUnlocked ? theme.accent : Color.secondary.opacity(0.35), lineWidth: 2)
                        Image(systemName: definition.icon)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(isUnlocked ? theme.accent : .secondary)
                    }
                    .frame(width: 46, height: 50)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(AppLocalizer.string(definition.titleKey))
                            .font(.body.weight(.semibold))
                        Text(AppLocalizer.string(definition.descriptionKey))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        HStack {
                            ProgressView(value: Double(min(current, definition.target)), total: Double(definition.target))
                                .tint(theme.accent)
                            Text("\(min(current, definition.target)) / \(definition.target)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("+\(definition.xpReward) XP")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.accent)
                }
                .padding(.vertical, 4)
            }
        }

        private struct AchievementDetailScreen: View {
            let definition: AchievementDefinition
            let current: Int
            let unlock: UnlockedAchievement?
            let theme: AppTheme

            private var isUnlocked: Bool { unlock != nil }

            var body: some View {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        ZStack {
                            Hexagon().fill(theme.accent.opacity(isUnlocked ? 0.18 : 0.08))
                            Hexagon().stroke(isUnlocked ? theme.accent : Color.secondary.opacity(0.4), lineWidth: 4)
                            Image(systemName: definition.icon)
                                .font(.system(size: 38, weight: .bold))
                                .foregroundStyle(isUnlocked ? theme.accent : .secondary)
                        }
                        .frame(width: 112, height: 122)

                        VStack(spacing: 7) {
                            Text(AppLocalizer.string(definition.titleKey))
                                .font(.title2.weight(.bold))
                                .multilineTextAlignment(.center)
                            Label(
                                AppLocalizer.string(isUnlocked ? "profile.achievements.detail.unlocked" : "profile.achievements.detail.locked"),
                                systemImage: isUnlocked ? "checkmark.seal.fill" : "lock.fill"
                            )
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isUnlocked ? theme.accent : .secondary)
                        }

                        detailCard(
                            title: AppLocalizer.string("profile.achievements.detail.condition"),
                            icon: "scope"
                        ) {
                            Text(AppLocalizer.string(definition.descriptionKey))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        detailCard(
                            title: AppLocalizer.string("profile.achievements.detail.progress"),
                            icon: "chart.bar.fill"
                        ) {
                            VStack(spacing: 8) {
                                HStack {
                                    Text("\(min(current, definition.target)) / \(definition.target)")
                                        .font(.headline.weight(.bold))
                                    Spacer()
                                    Text("+\(definition.xpReward) XP")
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(theme.accent)
                                }
                                ProgressView(value: Double(min(current, definition.target)), total: Double(definition.target))
                                    .tint(theme.accent)
                            }
                        }

                        if let unlock {
                            detailCard(
                                title: AppLocalizer.string("profile.achievements.detail.unlocked_at"),
                                icon: "calendar"
                            ) {
                                Text(unlock.unlockedAt.formatted(date: .long, time: .omitted))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(20)
                }
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
                .navigationTitle(AppLocalizer.string("profile.achievements.detail.title"))
                .navigationBarTitleDisplayMode(.inline)
            }

            private func detailCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
                VStack(alignment: .leading, spacing: 12) {
                    Label(title, systemImage: icon)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(theme.accent)
                    content()
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(profileCardBackground))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(profileCardBorder))
            }
        }

        private struct AchievementBadge: Identifiable {
            let definition: AchievementDefinition
            let unlock: UnlockedAchievement
            var id: AchievementID { definition.id }
        }

        private struct AchievementGoal: Identifiable {
            let definition: AchievementDefinition
            let current: Int
            var id: AchievementID { definition.id }
        }

        private struct Hexagon: Shape {
            func path(in rect: CGRect) -> Path {
                let radius = min(rect.width, rect.height) / 2
                let center = CGPoint(x: rect.midX, y: rect.midY)
                var path = Path()
                for index in 0..<6 {
                    let angle = CGFloat(index) * .pi / 3 - .pi / 2
                    let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                    index == 0 ? path.move(to: point) : path.addLine(to: point)
                }
                path.closeSubpath()
                return path
            }
        }
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
        let weekRhythm: WeekRhythmSnapshot
        let latestMeasurement: BodyMeasurements?
    }
}

private struct ProgressSummaryGrid: View {
    let workouts: Int
    let averageCalories: Int
    let waterGoalDays: Int
    let weight: Int

    @Environment(\.colorScheme) private var colorScheme

    private var theme: AppTheme { AppTheme(colorScheme) }

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
            ProfileIconTile(systemImage: icon, tint: theme.accent, size: 34, cornerRadius: 10)

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

    @Environment(\.colorScheme) private var colorScheme

    private var theme: AppTheme { AppTheme(colorScheme) }

    var body: some View {
        HStack(spacing: 12) {
            ProfileIconTile(systemImage: icon, tint: theme.accent, size: 34, cornerRadius: 10)

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
