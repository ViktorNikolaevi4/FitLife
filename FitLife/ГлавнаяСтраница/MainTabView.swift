import SwiftUI
import SwiftData

// MARK: - Хелперы

extension Gender {
    static let appStorageKey = "activeGender"
}

// MARK: - Табы (для контекста)

struct MainTabView: View {
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue
    @AppStorage(Gender.appStorageKey) private var activeGenderRaw: String = Gender.male.rawValue
    @State private var selectedDate: Date = Date()
    @State private var sheet: RationSheet? = nil
    @State private var refreshID = UUID()
    @State private var selectedTab: MainTab = .home
    @State private var showsHomeFloatingAddButton = true

    private var appLanguage: AppLanguage {
        AppLanguage.from(rawValue: appLanguageRaw)
    }

    private var selectedGender: Gender {
        Gender(rawValue: activeGenderRaw) ?? .male
    }

    private var showsFloatingAddButton: Bool {
        (selectedTab == .home && showsHomeFloatingAddButton) || selectedTab == .nutrition
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                DashboardScreen(
                    selectedDate: $selectedDate,
                    showsFloatingAddButton: $showsHomeFloatingAddButton,
                    onOpenWorkouts: { selectedTab = .workouts }
                )
                    .id(refreshID)
                    .tag(MainTab.home)
                    .tabItem { Label(appLanguage.localized("tab.home"), systemImage: "house.fill") }

                NavigationStack {
                    NutritionScreen(selectedDate: $selectedDate)
                }
                    .tag(MainTab.nutrition)
                    .tabItem { Label(AppLocalizer.string("tab.nutrition"), systemImage: "fork.knife") }

                WorkoutsScreen()
                    .tag(MainTab.workouts)
                    .tabItem { Label(appLanguage.localized("tab.workouts"), systemImage: "dumbbell.fill") }

                WaterTrackerViewOne()
                    .tag(MainTab.water)
                    .tabItem { Label(appLanguage.localized("tab.water"), systemImage: "drop.fill") }

                ProfileScreen()
                    .tag(MainTab.profile)
                    .tabItem { Label(appLanguage.localized("tab.profile"), systemImage: "person.fill") }
            }

            if showsFloatingAddButton {
                Button(action: { sheet = .ration }) {
                    ZStack {
                        Circle()
                            .fill(.black)
                            .frame(width: 58, height: 58)
                            .shadow(color: .black.opacity(0.18), radius: 10, y: 5)

                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20)
                .padding(.bottom, 74)
            }
        }
        .sheet(item: $sheet) { key in
            let preset: MealType? = { if case let .quick(m) = key { m } else { nil } }()
            RationPopupView(
                gender: selectedGender,
                selectedDate: $selectedDate,
                onMealAdded: { refreshID = UUID() },
                preselectedMeal: preset
            )
        }
    }
}

private enum MainTab: Hashable {
    case home
    case nutrition
    case workouts
    case profile
    case water
}
