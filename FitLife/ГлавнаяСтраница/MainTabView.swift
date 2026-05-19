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
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var productCatalogStore: ProductCatalogStore
    @EnvironmentObject private var notificationsStore: AppNotificationsStore
    @State private var selectedDate: Date = Date()
    @State private var sheet: RationSheet? = nil
    @State private var refreshID = UUID()
    @State private var selectedTab: MainTab = .home
    @State private var showsHomeFloatingAddButton = true
    @State private var isShowingAIQuickAdd = false

    private var appLanguage: AppLanguage {
        AppLanguage.from(rawValue: appLanguageRaw)
    }

    private var selectedGender: Gender {
        Gender(rawValue: activeGenderRaw) ?? .male
    }

    private var showsFloatingAddButton: Bool {
        selectedTab == .home && showsHomeFloatingAddButton
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
                    .badge(notificationsStore.unreadCount)
            }
            .tint(colorScheme == .dark ? HomeDarkColors.blue : HomeColors.accent)
            .toolbarBackground(colorScheme == .dark ? Color.black.opacity(0.62) : Color.white.opacity(0.88), for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .tabBar)

            if showsFloatingAddButton {
                Button(action: { isShowingAIQuickAdd = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background {
                            Circle()
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
                        }
                        .shadow(color: HomeDarkColors.blue.opacity(0.35), radius: 20, x: 0, y: 10)
                        .shadow(color: .black.opacity(0.38), radius: 14, x: 0, y: 8)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20)
                .padding(.bottom, 74)
            }
        }
        .onAppear {
            Self.configurePremiumTabBar(for: colorScheme)
            productCatalogStore.preloadIfNeeded()
        }
        .onChange(of: colorScheme) { _, newScheme in
            Self.configurePremiumTabBar(for: newScheme)
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
        .sheet(isPresented: $isShowingAIQuickAdd) {
            AIQuickMealEntryChooserView(
                selectedDate: selectedDate,
                selectedGender: selectedGender,
                onSaved: { refreshID = UUID() }
            )
        }
    }

    private static func configurePremiumTabBar(for colorScheme: ColorScheme) {
        let isDark = colorScheme == .dark
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: isDark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight)
        appearance.backgroundColor = isDark
            ? UIColor.black.withAlphaComponent(0.62)
            : UIColor.white.withAlphaComponent(0.88)
        appearance.shadowColor = isDark
            ? UIColor.white.withAlphaComponent(0.08)
            : UIColor.black.withAlphaComponent(0.08)

        let selectedColor = UIColor(isDark ? HomeDarkColors.blue : HomeColors.accent)
        let normalColor = UIColor(isDark ? HomeDarkColors.tertiaryText : HomeColors.tertiaryText)

        [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance].forEach {
            $0.selected.iconColor = selectedColor
            $0.selected.titleTextAttributes = [.foregroundColor: selectedColor]
            $0.normal.iconColor = normalColor
            $0.normal.titleTextAttributes = [.foregroundColor: normalColor]
        }

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = selectedColor
        UITabBar.appearance().unselectedItemTintColor = normalColor
        UITabBar.appearance().isTranslucent = true
    }
}

private enum MainTab: Hashable {
    case home
    case nutrition
    case workouts
    case profile
    case water
}
