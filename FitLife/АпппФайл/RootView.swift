import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("didOnboard") private var didOnboard = false
    @AppStorage(Gender.appStorageKey) private var activeGenderRaw: String = Gender.male.rawValue
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue

    @EnvironmentObject private var sessionStore: AppSessionStore
    @EnvironmentObject private var notificationsStore: AppNotificationsStore
    @EnvironmentObject private var pushNotificationsManager: AppPushNotificationsManager
    @EnvironmentObject private var achievementCelebrationStore: AchievementCelebrationStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var users: [UserData]
    @State private var preparedOwnerId: String?
    @State private var isPreparingLocalData = false
    @State private var openedPushNotification: AppNotificationEvent?

    private var currentOwnerId: String? {
        sessionStore.firebaseUser?.uid
    }

    private var currentUserData: [UserData] {
        guard let currentOwnerId else { return [] }
        return users.filter { $0.ownerId == currentOwnerId }
    }

    var body: some View {
        Group {
            if sessionStore.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(AppLocalizer.string("app.loading_account"))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            } else if sessionStore.firebaseUser == nil {
                AuthScreen()
            } else if isPreparingLocalData {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
            } else {
                if didOnboard, currentUserData.isEmpty == false {
                    AdaptiveMainView()
                        .background {
                            AchievementReconciliationMonitor()
                        }
                } else {
                    OnboardingView { payload in
                        let calories = MacrosCalculator.calculateCaloriesMifflin(
                            gender: payload.gender,
                            weight: payload.weight,
                            height: payload.height,
                            age: payload.age,
                            activityLevel: payload.activity,
                            goal: payload.goal
                        )
                        let m = MacrosCalculator.calculateMacros(
                            calories: calories,
                            goal: payload.goal
                        )

                        let user = UserData(
                            weight: payload.weight,
                            height: payload.height,
                            age: payload.age,
                            ownerId: currentOwnerId ?? "",
                            activityLevel: payload.activity,
                            goal: payload.goal,
                            gender: payload.gender,
                            calories: calories,
                            proteins: m.proteins,
                            fats: m.fats,
                            carbs: m.carbs
                        )
                        modelContext.insert(user)
                        try? modelContext.save()

                        activeGenderRaw = payload.gender.rawValue
                        didOnboard = true
                    }
                }
            }
        }
        .onAppear {
            prepareLocalDataIfNeeded()
            notificationsStore.setCurrentUser(currentOwnerId)
            pushNotificationsManager.setCurrentUser(currentOwnerId)
            refreshMealRemindersIfNeeded()
            refreshWorkoutRemindersIfNeeded()
            presentOpenedPushNotificationIfPossible()
            retryPendingCoachingReports()
        }
        .onChange(of: currentOwnerId) { _, _ in
            prepareLocalDataIfNeeded()
            notificationsStore.setCurrentUser(currentOwnerId)
            pushNotificationsManager.setCurrentUser(currentOwnerId)
            refreshMealRemindersIfNeeded()
            refreshWorkoutRemindersIfNeeded()
            presentOpenedPushNotificationIfPossible()
            retryPendingCoachingReports()
        }
        .onChange(of: pushNotificationsManager.openedNotification) { _, _ in
            presentOpenedPushNotificationIfPossible()
        }
        .onChange(of: appLanguageRaw) { _, _ in
            Task {
                await pushNotificationsManager.syncCurrentLanguagePreference()
            }
        }
        .onChange(of: activeGenderRaw) { _, _ in
            refreshMealRemindersIfNeeded()
            refreshWorkoutRemindersIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                retryPendingCoachingReports()
            }
        }
        .overlay {
            ZStack(alignment: .top) {
                if let celebration = achievementCelebrationStore.activeCelebration,
                   celebration.isMilestone {
                    AchievementMilestoneCelebrationView(
                        celebration: celebration,
                        onDismiss: achievementCelebrationStore.dismiss
                    )
                    .transition(.opacity)
                }

                VStack(spacing: 8) {
                    if let celebration = achievementCelebrationStore.activeCelebration,
                       celebration.isMilestone == false {
                        AchievementCelebrationBanner(
                            celebration: celebration,
                            onDismiss: achievementCelebrationStore.dismiss
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    if let banner = pushNotificationsManager.inAppNotificationBanner,
                       achievementCelebrationStore.activeCelebration?.isMilestone != true {
                        InAppNotificationMessageBanner(
                            banner: banner,
                            onOpen: pushNotificationsManager.openInAppNotificationBanner,
                            onDismiss: pushNotificationsManager.dismissInAppNotificationBanner
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .zIndex(10)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.84), value: pushNotificationsManager.inAppNotificationBanner?.id)
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: achievementCelebrationStore.activeCelebration?.id)
        .fullScreenCover(item: $openedPushNotification) { notification in
            NavigationStack {
                AppNotificationDestinationScreen(notification: notification)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(AppLocalizer.string("common.close")) {
                                openedPushNotification = nil
                            }
                        }
                    }
                    .task {
                        if notification.isEphemeral == false {
                            await notificationsStore.delete(notification)
                        }
                    }
            }
        }
    }

    private func prepareLocalDataIfNeeded() {
        guard let currentOwnerId, preparedOwnerId != currentOwnerId else { return }
        isPreparingLocalData = true
        migrateLegacyLocalDataIfNeeded(to: currentOwnerId)
        preparedOwnerId = currentOwnerId
        isPreparingLocalData = false
    }

    private func retryPendingCoachingReports() {
        guard let currentOwnerId else { return }
        Task {
            await CoachingReportDeliveryOutbox.shared.retryPending(for: currentOwnerId)
        }
    }

    private func presentOpenedPushNotificationIfPossible() {
        guard
            currentOwnerId != nil,
            openedPushNotification == nil,
            let notification = pushNotificationsManager.openedNotification
        else { return }

        openedPushNotification = notification
        pushNotificationsManager.clearOpenedNotification()
    }

    private func refreshMealRemindersIfNeeded() {
        guard let currentOwnerId else { return }
        LocalReminderScheduler.rescheduleMealRemindersIfEnabled(
            modelContext: modelContext,
            ownerId: currentOwnerId,
            gender: Gender(rawValue: activeGenderRaw) ?? .male
        )
    }

    private func refreshWorkoutRemindersIfNeeded() {
        guard let currentOwnerId else { return }
        LocalReminderScheduler.rescheduleWorkoutRemindersIfEnabled(
            modelContext: modelContext,
            ownerId: currentOwnerId,
            gender: Gender(rawValue: activeGenderRaw) ?? .male
        )
    }

    private func migrateLegacyLocalDataIfNeeded(to ownerId: String) {
        do {
            let localUsers = try modelContext.fetch(FetchDescriptor<UserData>())
            let foodEntries = try modelContext.fetch(FetchDescriptor<FoodEntry>())
            let waterEntries = try modelContext.fetch(FetchDescriptor<WaterIntake>())
            let measurements = try modelContext.fetch(FetchDescriptor<BodyMeasurements>())
            let workouts = try modelContext.fetch(FetchDescriptor<WorkoutSession>())

            var didMutate = false

            for item in localUsers where item.ownerId.isEmpty {
                item.ownerId = ownerId
                didMutate = true
            }
            for item in foodEntries where item.ownerId.isEmpty {
                item.ownerId = ownerId
                didMutate = true
            }
            for item in waterEntries where item.ownerId.isEmpty {
                item.ownerId = ownerId
                didMutate = true
            }
            for item in measurements where item.ownerId.isEmpty {
                item.ownerId = ownerId
                didMutate = true
            }
            for item in workouts where item.ownerId.isEmpty {
                item.ownerId = ownerId
                didMutate = true
            }

            if didMutate {
                try? modelContext.save()
            }
        } catch {}
    }
}

private struct InAppNotificationMessageBanner: View {
    let banner: InAppNotificationBanner
    let onOpen: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    Image(systemName: banner.systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(Color.blue.gradient, in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(banner.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(banner.message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Color.secondary.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AppLocalizer.string("common.close"))
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
    }
}
