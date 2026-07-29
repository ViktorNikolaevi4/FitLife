import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("didOnboard") private var didOnboard = false
    @AppStorage(Gender.appStorageKey) private var activeGenderRaw: String = Gender.male.rawValue
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue

    @EnvironmentObject private var sessionStore: AppSessionStore
    @EnvironmentObject private var notificationsStore: AppNotificationsStore
    @EnvironmentObject private var pushNotificationsManager: AppPushNotificationsManager
    @Environment(\.modelContext) private var modelContext
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
                ProgressView()
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
        }
        .onChange(of: currentOwnerId) { _, _ in
            prepareLocalDataIfNeeded()
            notificationsStore.setCurrentUser(currentOwnerId)
            pushNotificationsManager.setCurrentUser(currentOwnerId)
            refreshMealRemindersIfNeeded()
            refreshWorkoutRemindersIfNeeded()
            presentOpenedPushNotificationIfPossible()
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
                        await notificationsStore.delete(notification)
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
