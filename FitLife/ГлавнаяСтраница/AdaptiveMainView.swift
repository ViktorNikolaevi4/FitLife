import SwiftUI
import SwiftData

struct AdaptiveMainView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var shouldUseIPadShell: Bool {
        UIDevice.current.userInterfaceIdiom == .pad ||
        (horizontalSizeClass == .regular && verticalSizeClass == .regular)
    }

    var body: some View {
        if shouldUseIPadShell {
            IPadMainShell()
        } else {
            MainTabView()
        }
    }
}

private struct IPadMainShell: View {
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue
    @AppStorage(Gender.appStorageKey) private var activeGenderRaw: String = Gender.male.rawValue
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var notificationsStore: AppNotificationsStore

    @State private var selectedTab: MainTab = .home
    @State private var selectedDate = Date()
    @State private var refreshID = UUID()

    private var appLanguage: AppLanguage {
        AppLanguage.from(rawValue: appLanguageRaw)
    }

    private var selectedGender: Gender {
        Gender(rawValue: activeGenderRaw) ?? .male
    }

    private var theme: AppTheme {
        AppTheme(colorScheme)
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 230, ideal: 270, max: 310)
        } detail: {
            NavigationStack {
                selectedContent
            }
        }
        .tint(colorScheme == .dark ? HomeDarkColors.blue : HomeColors.accent)
        .background(theme.bg.ignoresSafeArea())
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("FitLife")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.top, 28)
                .padding(.horizontal, 22)

            VStack(spacing: 8) {
                sidebarButton(.home, title: appLanguage.localized("tab.home"), icon: "house.fill")
                sidebarButton(.nutrition, title: AppLocalizer.string("tab.nutrition"), icon: "fork.knife")
                sidebarButton(.workouts, title: appLanguage.localized("tab.workouts"), icon: "dumbbell.fill")
                sidebarButton(.water, title: appLanguage.localized("tab.water"), icon: "drop.fill")
                sidebarButton(.profile, title: appLanguage.localized("tab.profile"), icon: "person.fill", badge: notificationsStore.unreadCount)
            }
            .padding(.horizontal, 14)

            Spacer()

            sidebarButton(.profile, title: AppLocalizer.string("settings.title"), icon: "gearshape.fill", badge: 0)
                .padding(.horizontal, 14)
                .padding(.bottom, 26)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedTab {
        case .home:
            DashboardScreen(
                selectedDate: $selectedDate,
                showsFloatingAddButton: .constant(false),
                onOpenNutrition: { selectedTab = .nutrition },
                onOpenWorkouts: { selectedTab = .workouts }
            )
            .id(refreshID)
            .toolbar {
                toolbarContent
            }
        case .nutrition:
            NutritionScreen(selectedDate: $selectedDate)
                .toolbar {
                    toolbarContent
                }
        case .workouts:
            WorkoutsScreen()
                .toolbar {
                    toolbarContent
                }
        case .water:
            WaterTrackerViewOne()
                .toolbar {
                    toolbarContent
                }
        case .profile:
            ProfileScreen()
                .toolbar {
                    toolbarContent
                }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            HStack(spacing: 8) {
                Text(selectedTitle)
                    .font(.title.weight(.bold))

                if selectedTab == .home {
                    Text(selectedDate.formatted(.dateTime.day().month(.wide)))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                selectedTab = .profile
            } label: {
                Image(systemName: "bell")
            }
            .overlay(alignment: .topTrailing) {
                if notificationsStore.unreadCount > 0 {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .offset(x: 2, y: -2)
                }
            }

            Button {
                selectedTab = .profile
            } label: {
                Image(systemName: "person.fill")
            }
        }
    }

    private var selectedTitle: String {
        switch selectedTab {
        case .home:
            return appLanguage.localized("tab.home")
        case .nutrition:
            return AppLocalizer.string("tab.nutrition")
        case .workouts:
            return appLanguage.localized("tab.workouts")
        case .water:
            return appLanguage.localized("tab.water")
        case .profile:
            return appLanguage.localized("tab.profile")
        }
    }

    private func sidebarButton(
        _ tab: MainTab,
        title: String,
        icon: String,
        badge: Int = 0
    ) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 24)

                Text(title)
                    .font(.headline.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)

                Spacer()

                if badge > 0 {
                    Text("\(badge)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.red))
                }
            }
            .foregroundStyle(isSelected ? HomeColors.accent : .secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? HomeColors.accent.opacity(0.12) : Color.clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? HomeColors.accent.opacity(0.18) : Color.clear)
            }
        }
        .buttonStyle(.plain)
    }
}
