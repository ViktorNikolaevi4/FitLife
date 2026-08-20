import Foundation
import UIKit
import UserNotifications
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging

struct InAppNotificationBanner: Identifiable, Equatable {
    let id: String
    let title: String
    let message: String
    let systemImage: String
    let notification: AppNotificationEvent
}

@MainActor
final class AppPushNotificationsManager: NSObject, ObservableObject {
    static let shared = AppPushNotificationsManager()

    @Published private(set) var fcmToken: String?
    @Published private(set) var openedNotification: AppNotificationEvent?
    @Published private(set) var inAppNotificationBanner: InAppNotificationBanner?

    private var currentUserId: String?
    private var hasAPNSToken = false
    private var isConfigured = false
    private var foregroundNotificationsListener: ListenerRegistration?
    private var hasReceivedInitialForegroundNotificationsSnapshot = false
    private var coachingNotesListener: ListenerRegistration?
    private var coachingNotesRetryTask: Task<Void, Never>?
    private var coachingNotesLastProcessedAt: Date?
    private var coachingNotesRetryAttempt = 0
    private var workoutReportsListener: ListenerRegistration?
    private var nutritionReportsListener: ListenerRegistration?
    private var reportListenersRetryTask: Task<Void, Never>?
    private var reportsLastProcessedAt: Date?
    private var reportListenersRetryAttempt = 0
    private var hasReceivedWorkoutReportSnapshot = false
    private var hasReceivedNutritionReportSnapshot = false
    private var bannerDismissTask: Task<Void, Never>?
    private var activeChatCounterpartId: String?
    private var displayedNotificationKeys: [String] = []
    private var displayedNotificationKeySet: Set<String> = []
    private let didRequestPermissionKey = "push.didRequestAuthorization"
    private let lastSyncedUserIdKey = "push.lastSyncedUserId"
    private let lastSyncedTokenKey = "push.lastSyncedToken"
    private let deviceIdKey = "push.deviceId"
    private let displayedNotificationLimit = 200
    private let maxListenerRetryAttempts = 5

    private var firestore: Firestore {
        Firestore.firestore()
    }

    func configure() {
        guard isConfigured == false else { return }
        isConfigured = true
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.ensurePushRegistrationFlow()
                if self.hasAPNSToken {
                    await self.refreshFCMTokenIfPossible()
                    await self.syncFCMTokenIfPossible()
                }
            }
        }
        Task {
            await ensurePushRegistrationFlow()
        }
    }

    func setCurrentUser(_ userId: String?) {
        guard currentUserId != userId else {
            Task {
                await syncPreferredLanguageIfPossible()
                await syncFCMTokenIfPossible()
            }
            return
        }

        let previousUserId = currentUserId
            ?? UserDefaults.standard.string(forKey: lastSyncedUserIdKey)
        let previousToken = fcmToken
            ?? UserDefaults.standard.string(forKey: lastSyncedTokenKey)

        foregroundNotificationsListener?.remove()
        foregroundNotificationsListener = nil
        hasReceivedInitialForegroundNotificationsSnapshot = false
        coachingNotesListener?.remove()
        coachingNotesListener = nil
        coachingNotesRetryTask?.cancel()
        coachingNotesRetryTask = nil
        coachingNotesLastProcessedAt = nil
        coachingNotesRetryAttempt = 0
        workoutReportsListener?.remove()
        workoutReportsListener = nil
        nutritionReportsListener?.remove()
        nutritionReportsListener = nil
        reportListenersRetryTask?.cancel()
        reportListenersRetryTask = nil
        reportsLastProcessedAt = nil
        reportListenersRetryAttempt = 0
        hasReceivedWorkoutReportSnapshot = false
        hasReceivedNutritionReportSnapshot = false
        bannerDismissTask?.cancel()
        inAppNotificationBanner = nil
        activeChatCounterpartId = nil
        currentUserId = userId

        Task {
            if let previousUserId,
               previousUserId != userId,
               let previousToken,
               previousToken.isEmpty == false {
                await removeFCMToken(previousToken, from: previousUserId)
            }

            configureForegroundNotificationsListener(for: userId)
            await ensurePushRegistrationFlow()
            await syncPreferredLanguageIfPossible()
            if hasAPNSToken {
                await refreshFCMTokenIfPossible()
                await syncFCMTokenIfPossible()
            }
        }
    }

    func syncCurrentLanguagePreference() async {
        await syncPreferredLanguageIfPossible()
    }

    func didRegisterForRemoteNotifications(deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        hasAPNSToken = true
        Task {
            await refreshFCMTokenIfPossible()
            await syncFCMTokenIfPossible()
        }
    }

    func didFailToRegisterForRemoteNotifications(_ error: Error) {
        #if DEBUG
        print("Push registration failed:", error.localizedDescription)
        #endif
    }

    func clearOpenedNotification() {
        openedNotification = nil
    }

    func dismissInAppNotificationBanner() {
        bannerDismissTask?.cancel()
        bannerDismissTask = nil
        inAppNotificationBanner = nil
    }

    func openInAppNotificationBanner() {
        guard let banner = inAppNotificationBanner else { return }
        openedNotification = banner.notification
        dismissInAppNotificationBanner()
    }

    func setChatVisible(counterpartId: String, isVisible: Bool) {
        if isVisible {
            activeChatCounterpartId = counterpartId
            if inAppNotificationBanner?.notification.targetType == .coachingConnection {
                dismissInAppNotificationBanner()
            }
        } else if activeChatCounterpartId == counterpartId {
            activeChatCounterpartId = nil
        }
    }

    func handleNotificationResponse(userInfo: [AnyHashable: Any]) {
        guard
            let eventId = userInfo["eventId"] as? String,
            let typeRaw = userInfo["type"] as? String,
            let type = AppNotificationEventType(rawValue: typeRaw),
            let recipientId = userInfo["recipientId"] as? String,
            let senderId = userInfo["senderId"] as? String,
            let targetTypeRaw = userInfo["targetType"] as? String,
            let targetType = AppNotificationTargetType(rawValue: targetTypeRaw),
            let targetId = userInfo["targetId"] as? String
        else {
            #if DEBUG
            print("Failed to parse notification payload:", userInfo)
            #endif
            return
        }

        openedNotification = AppNotificationEvent(
            id: eventId,
            type: type,
            recipientId: recipientId,
            senderId: senderId,
            senderName: (userInfo["senderName"] as? String) ?? "",
            targetType: targetType,
            targetId: targetId
        )
    }

    private func ensurePushRegistrationFlow() async {
        let settings = await notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            await registerForRemoteNotifications()
        case .notDetermined:
            guard UserDefaults.standard.bool(forKey: didRequestPermissionKey) == false else { return }
            UserDefaults.standard.set(true, forKey: didRequestPermissionKey)
            let granted = await requestAuthorization()
            if granted {
                await registerForRemoteNotifications()
            }
        case .denied:
            break
        @unknown default:
            break
        }
    }

    private func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func registerForRemoteNotifications() async {
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    private func syncFCMTokenIfPossible() async {
        guard
            let currentUserId,
            let fcmToken,
            fcmToken.isEmpty == false
        else { return }

        do {
            let userRef = firestore.collection("users").document(currentUserId)
            let deviceRef = userRef.collection("push_devices").document(pushDeviceId)
            let batch = firestore.batch()
            batch.setData([
                "fcmTokens": FieldValue.arrayUnion([fcmToken]),
                "lastFCMToken": fcmToken,
                "pushTokenUpdatedAt": FieldValue.serverTimestamp()
            ], forDocument: userRef, merge: true)
            // A stable device record makes this token authoritative for this
            // installation, unlike the migration-only legacy token array.
            batch.setData([
                "fcmToken": fcmToken,
                "platform": "ios",
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: deviceRef, merge: true)
            try await batch.commit()
            UserDefaults.standard.set(currentUserId, forKey: lastSyncedUserIdKey)
            UserDefaults.standard.set(fcmToken, forKey: lastSyncedTokenKey)
        } catch {
            #if DEBUG
            print("Failed to sync FCM token:", error.localizedDescription)
            #endif
        }
    }

    private var pushDeviceId: String {
        if let deviceId = UserDefaults.standard.string(forKey: deviceIdKey),
           deviceId.isEmpty == false {
            return deviceId
        }
        let deviceId = UUID().uuidString
        UserDefaults.standard.set(deviceId, forKey: deviceIdKey)
        return deviceId
    }

    private func refreshFCMTokenIfPossible() async {
        let token = await withCheckedContinuation { continuation in
            Messaging.messaging().token { token, _ in
                continuation.resume(returning: token)
            }
        }

        guard let token, token.isEmpty == false else { return }
        let oldToken = fcmToken
            ?? UserDefaults.standard.string(forKey: lastSyncedTokenKey)
        if let oldToken,
           oldToken != token,
           let currentUserId,
           UserDefaults.standard.string(forKey: lastSyncedUserIdKey) == currentUserId {
            await removeFCMToken(oldToken, from: currentUserId)
        }
        fcmToken = token
    }

    private func removeFCMToken(_ token: String, from userId: String) async {
        do {
            let userRef = firestore.collection("users").document(userId)
            let userSnapshot = try await userRef.getDocument()
            guard userSnapshot.exists else {
                if UserDefaults.standard.string(forKey: lastSyncedUserIdKey) == userId {
                    UserDefaults.standard.removeObject(forKey: lastSyncedUserIdKey)
                    UserDefaults.standard.removeObject(forKey: lastSyncedTokenKey)
                }
                return
            }
            let lastFCMToken = userSnapshot.data()?["lastFCMToken"] as? String
            var fields: [String: Any] = [
                "fcmTokens": FieldValue.arrayRemove([token]),
                "pushTokenUpdatedAt": FieldValue.serverTimestamp()
            ]
            if lastFCMToken == token {
                fields["lastFCMToken"] = FieldValue.delete()
            }

            try await firestore
                .collection("users")
                .document(userId)
                .setData(fields, merge: true)

            if UserDefaults.standard.string(forKey: lastSyncedUserIdKey) == userId {
                UserDefaults.standard.removeObject(forKey: lastSyncedUserIdKey)
                UserDefaults.standard.removeObject(forKey: lastSyncedTokenKey)
            }
        } catch {
            #if DEBUG
            print("Failed to remove FCM token from previous account:", error.localizedDescription)
            #endif
        }
    }

    // Notification events are the single source of truth for the inbox and
    // badge. Listening to them also gives the foreground banner the same view
    // of new activity, without relying on a role-specific chat/report query
    // or a narrow client-clock time window.
    private func configureForegroundNotificationsListener(for userId: String?) {
        foregroundNotificationsListener?.remove()
        foregroundNotificationsListener = nil
        hasReceivedInitialForegroundNotificationsSnapshot = false

        guard let userId, userId.isEmpty == false else { return }

        foregroundNotificationsListener = firestore
            .collection("notification_events")
            .whereField("recipientId", isEqualTo: userId)
            .whereField("isRead", isEqualTo: false)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error {
                    #if DEBUG
                    print("Foreground notifications listener failed:", error.localizedDescription)
                    #endif
                    return
                }

                let events = snapshot?.documentChanges.compactMap { change -> AppNotificationEvent? in
                    guard change.type == .added else { return nil }
                    return AppNotificationEvent(
                        id: change.document.documentID,
                        data: change.document.data()
                    )
                } ?? []
                let isFromCache = snapshot?.metadata.isFromCache ?? true

                Task { @MainActor [weak self] in
                    guard let self, self.currentUserId == userId else { return }

                    // The initial snapshot fills the already-visible inbox;
                    // only additions after it are new foreground activity.
                    guard self.hasReceivedInitialForegroundNotificationsSnapshot else {
                        // A cache snapshot may be incomplete. Wait for the
                        // server snapshot before deciding which events were
                        // already present when the app became active.
                        guard isFromCache == false else { return }
                        self.hasReceivedInitialForegroundNotificationsSnapshot = true
                        return
                    }

                    for event in events {
                        self.receiveForegroundNotificationEvent(event)
                    }
                }
            }
    }

    private func receiveForegroundNotificationEvent(_ event: AppNotificationEvent) {
        guard
            UIApplication.shared.applicationState == .active,
            event.isArchived == false,
            event.isRead == false
        else { return }

        if event.targetType == .coachingConnection,
           activeChatCounterpartId == event.senderId {
            rememberDisplayedNotification(type: event.type, targetId: event.targetId)
            return
        }

        guard wasNotificationDisplayed(type: event.type, targetId: event.targetId) == false else {
            return
        }
        rememberDisplayedNotification(type: event.type, targetId: event.targetId)
        #if DEBUG
        print("Showing foreground notification banner:", event.type.rawValue, event.id)
        #endif
        showInAppNotificationBanner(
            id: event.id,
            title: event.localizedTitle,
            message: event.localizedBody,
            systemImage: foregroundNotificationSystemImage(for: event.type),
            notification: event
        )
    }

    private func foregroundNotificationSystemImage(
        for type: AppNotificationEventType
    ) -> String {
        switch type {
        case .coachNoteReceived, .clientNoteReceived:
            return "bubble.left.and.bubble.right.fill"
        case .workoutAssigned:
            return "dumbbell.fill"
        case .workoutReportSent:
            return "figure.strengthtraining.traditional"
        case .nutritionReportSent:
            return "fork.knife"
        case .checkInSubmitted:
            return "chart.line.uptrend.xyaxis"
        case .coachingRequestSubmitted, .coachingRequestApproved, .coachingRequestRejected:
            return "person.2.fill"
        case .profileUpdateRequested:
            return "person.text.rectangle"
        }
    }

    private func configureForegroundChatListener(for userId: String?) async {
        guard let userId, userId.isEmpty == false else { return }

        coachingNotesListener?.remove()
        coachingNotesListener = nil

        do {
            let userSnapshot = try await firestore
                .collection("users")
                .document(userId)
                .getDocument()
            guard
                currentUserId == userId,
                let roleRaw = userSnapshot.data()?["role"] as? String,
                let role = AppUserRole(rawValue: roleRaw),
                role == .client || role == .trainer
            else { return }

            let listenerStartedAt = coachingNotesLastProcessedAt
                ?? Date().addingTimeInterval(-1)
            let participantField = role == .client ? "clientId" : "trainerId"
            coachingNotesListener = firestore
                .collection("coaching_notes")
                .whereField(participantField, isEqualTo: userId)
                .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: listenerStartedAt))
                .order(by: "createdAt", descending: false)
                .addSnapshotListener { [weak self] snapshot, error in
                    if let error {
                        #if DEBUG
                        print("Foreground chat listener failed:", error.localizedDescription)
                        #endif
                        Task { @MainActor [weak self] in
                            self?.scheduleForegroundChatListenerRetry(for: userId)
                        }
                        return
                    }

                    let notes = snapshot?.documentChanges.compactMap { change -> CoachingNote? in
                        guard change.type == .added else { return nil }
                        return CoachingNote(id: change.document.documentID, data: change.document.data())
                    } ?? []

                    Task { @MainActor [weak self] in
                        guard let self, self.currentUserId == userId else { return }
                        self.coachingNotesRetryAttempt = 0
                        for note in notes {
                            self.recordCoachingNoteProcessed(at: note.createdAt)
                            self.receiveForegroundChatNote(note, recipientRole: role)
                        }
                    }
                }
        } catch {
            #if DEBUG
            print("Failed to configure foreground chat listener:", error.localizedDescription)
            #endif
            scheduleForegroundChatListenerRetry(for: userId)
        }
    }

    private func scheduleForegroundChatListenerRetry(for userId: String) {
        guard currentUserId == userId else { return }
        coachingNotesListener?.remove()
        coachingNotesListener = nil
        coachingNotesRetryTask?.cancel()
        guard coachingNotesRetryAttempt < maxListenerRetryAttempts else {
            #if DEBUG
            print("Foreground chat listener retry limit reached for user:", userId)
            #endif
            return
        }
        coachingNotesRetryAttempt += 1
        let delay = listenerRetryDelay(for: coachingNotesRetryAttempt)
        coachingNotesRetryTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard Task.isCancelled == false else { return }
            await self?.configureForegroundChatListener(for: userId)
        }
    }

    private func configureForegroundReportListeners(for userId: String?) async {
        workoutReportsListener?.remove()
        workoutReportsListener = nil
        nutritionReportsListener?.remove()
        nutritionReportsListener = nil
        hasReceivedWorkoutReportSnapshot = false
        hasReceivedNutritionReportSnapshot = false

        guard let userId, userId.isEmpty == false else { return }

        do {
            let userSnapshot = try await firestore
                .collection("users")
                .document(userId)
                .getDocument()
            guard
                currentUserId == userId,
                let roleRaw = userSnapshot.data()?["role"] as? String,
                AppUserRole(rawValue: roleRaw) == .trainer
            else { return }

            let listenerStartedAt = reportsLastProcessedAt
                ?? Date().addingTimeInterval(-1)
            workoutReportsListener = firestore
                .collection("coaching_workout_reports")
                .whereField("trainerId", isEqualTo: userId)
                .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: listenerStartedAt))
                .order(by: "createdAt", descending: false)
                .addSnapshotListener { [weak self] snapshot, error in
                    if let error {
                        #if DEBUG
                        print("Foreground workout report listener failed:", error.localizedDescription)
                        #endif
                        Task { @MainActor [weak self] in
                            self?.scheduleForegroundReportListenersRetry(for: userId)
                        }
                        return
                    }

                    let reports = snapshot?.documentChanges.compactMap { change -> CoachingWorkoutReport? in
                        guard change.type == .added else { return nil }
                        return CoachingWorkoutReport(
                            id: change.document.documentID,
                            data: change.document.data()
                        )
                    } ?? []

                    Task { @MainActor [weak self] in
                        guard let self, self.currentUserId == userId else { return }
                        self.hasReceivedWorkoutReportSnapshot = true
                        self.resetReportRetryCountIfReady()
                        for report in reports {
                            self.recordReportProcessed(at: report.createdAt)
                            self.receiveForegroundWorkoutReport(report)
                        }
                    }
                }

            nutritionReportsListener = firestore
                .collection("coaching_nutrition_reports")
                .whereField("trainerId", isEqualTo: userId)
                .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: listenerStartedAt))
                .order(by: "createdAt", descending: false)
                .addSnapshotListener { [weak self] snapshot, error in
                    if let error {
                        #if DEBUG
                        print("Foreground nutrition report listener failed:", error.localizedDescription)
                        #endif
                        Task { @MainActor [weak self] in
                            self?.scheduleForegroundReportListenersRetry(for: userId)
                        }
                        return
                    }

                    let reports = snapshot?.documentChanges.compactMap { change -> CoachingNutritionReport? in
                        guard change.type == .added else { return nil }
                        return CoachingNutritionReport(
                            id: change.document.documentID,
                            data: change.document.data()
                        )
                    } ?? []

                    Task { @MainActor [weak self] in
                        guard let self, self.currentUserId == userId else { return }
                        self.hasReceivedNutritionReportSnapshot = true
                        self.resetReportRetryCountIfReady()
                        for report in reports {
                            self.recordReportProcessed(at: report.createdAt)
                            self.receiveForegroundNutritionReport(report)
                        }
                    }
                }
        } catch {
            #if DEBUG
            print("Failed to configure foreground report listeners:", error.localizedDescription)
            #endif
            scheduleForegroundReportListenersRetry(for: userId)
        }
    }

    private func scheduleForegroundReportListenersRetry(for userId: String) {
        guard currentUserId == userId else { return }
        workoutReportsListener?.remove()
        workoutReportsListener = nil
        nutritionReportsListener?.remove()
        nutritionReportsListener = nil
        reportListenersRetryTask?.cancel()
        guard reportListenersRetryAttempt < maxListenerRetryAttempts else {
            #if DEBUG
            print("Foreground report listeners retry limit reached for user:", userId)
            #endif
            return
        }
        reportListenersRetryAttempt += 1
        let delay = listenerRetryDelay(for: reportListenersRetryAttempt)
        reportListenersRetryTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard Task.isCancelled == false else { return }
            await self?.configureForegroundReportListeners(for: userId)
        }
    }

    private func recordCoachingNoteProcessed(at date: Date?) {
        let processedAt = date ?? .now
        guard let lastProcessedAt = coachingNotesLastProcessedAt,
              lastProcessedAt >= processedAt else {
            coachingNotesLastProcessedAt = processedAt
            return
        }
    }

    private func recordReportProcessed(at date: Date?) {
        let processedAt = date ?? .now
        guard let lastProcessedAt = reportsLastProcessedAt,
              lastProcessedAt >= processedAt else {
            reportsLastProcessedAt = processedAt
            return
        }
    }

    private func resetReportRetryCountIfReady() {
        guard hasReceivedWorkoutReportSnapshot, hasReceivedNutritionReportSnapshot else { return }
        reportListenersRetryAttempt = 0
    }

    // Retry transient listener failures at 15s, 30s, 60s, 120s, then 5m;
    // automatic retries stop after five consecutive failures.
    private func listenerRetryDelay(for attempt: Int) -> Duration {
        let multiplier = 1 << max(0, attempt - 1)
        let seconds = min(15 * multiplier, 300)
        return .seconds(seconds)
    }

    private func receiveForegroundChatNote(
        _ note: CoachingNote,
        recipientRole: AppUserRole
    ) {
        guard UIApplication.shared.applicationState == .active else { return }

        let type: AppNotificationEventType
        let recipientId: String
        let senderId: String
        let title: String

        switch recipientRole {
        case .client:
            guard
                note.clientId == currentUserId,
                note.authorRole == .trainer,
                note.authorId == note.trainerId
            else { return }
            type = .coachNoteReceived
            recipientId = note.clientId
            senderId = note.trainerId
            title = AppLocalizer.string("coaching.notes.author.trainer")
        case .trainer:
            guard
                note.trainerId == currentUserId,
                note.authorRole == .client,
                note.authorId == note.clientId
            else { return }
            type = .clientNoteReceived
            recipientId = note.trainerId
            senderId = note.clientId
            title = AppLocalizer.string("coaching.notes.author.client")
        case .owner:
            return
        }

        if activeChatCounterpartId == senderId {
            rememberDisplayedNotification(type: type, targetId: note.id)
            return
        }
        guard wasNotificationDisplayed(type: type, targetId: note.id) == false else { return }
        rememberDisplayedNotification(type: type, targetId: note.id)

        let notification = AppNotificationEvent(
            id: "coaching-note-\(note.id)",
            type: type,
            recipientId: recipientId,
            senderId: senderId,
            targetType: .coachingConnection,
            targetId: note.id,
            createdAt: note.createdAt,
            isEphemeral: true
        )
        showInAppNotificationBanner(
            id: note.id,
            title: title,
            message: note.message,
            systemImage: "bubble.left.and.bubble.right.fill",
            notification: notification
        )
    }

    private func receiveForegroundWorkoutReport(_ report: CoachingWorkoutReport) {
        guard
            UIApplication.shared.applicationState == .active,
            report.trainerId == currentUserId
        else { return }

        showForegroundReport(
            type: .workoutReportSent,
            targetType: .workoutReport,
            reportId: report.id,
            trainerId: report.trainerId,
            clientId: report.clientId,
            createdAt: report.createdAt,
            systemImage: "dumbbell.fill"
        )
    }

    private func receiveForegroundNutritionReport(_ report: CoachingNutritionReport) {
        guard
            UIApplication.shared.applicationState == .active,
            report.trainerId == currentUserId
        else { return }

        showForegroundReport(
            type: .nutritionReportSent,
            targetType: .nutritionReport,
            reportId: report.id,
            trainerId: report.trainerId,
            clientId: report.clientId,
            createdAt: report.createdAt,
            systemImage: "fork.knife"
        )
    }

    private func showForegroundReport(
        type: AppNotificationEventType,
        targetType: AppNotificationTargetType,
        reportId: String,
        trainerId: String,
        clientId: String,
        createdAt: Date,
        systemImage: String
    ) {
        guard wasNotificationDisplayed(type: type, targetId: reportId) == false else { return }
        rememberDisplayedNotification(type: type, targetId: reportId)

        let notification = AppNotificationEvent(
            id: "\(type.rawValue)-\(reportId)",
            type: type,
            recipientId: trainerId,
            senderId: clientId,
            targetType: targetType,
            targetId: reportId,
            createdAt: createdAt,
            isEphemeral: true
        )
        showInAppNotificationBanner(
            id: reportId,
            title: notification.localizedTitle,
            message: notification.localizedBody,
            systemImage: systemImage,
            notification: notification
        )
    }

    private func showInAppNotificationBanner(
        id: String,
        title: String,
        message: String,
        systemImage: String,
        notification: AppNotificationEvent
    ) {
        let banner = InAppNotificationBanner(
            id: id,
            title: title,
            message: message,
            systemImage: systemImage,
            notification: notification
        )

        bannerDismissTask?.cancel()
        inAppNotificationBanner = banner
        bannerDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard Task.isCancelled == false else { return }
            await MainActor.run {
                guard self?.inAppNotificationBanner?.id == banner.id else { return }
                self?.inAppNotificationBanner = nil
            }
        }
    }

    private func notificationKey(type: AppNotificationEventType, targetId: String) -> String {
        "\(type.rawValue)|\(targetId)"
    }

    private func wasNotificationDisplayed(type: AppNotificationEventType, targetId: String) -> Bool {
        displayedNotificationKeySet.contains(notificationKey(type: type, targetId: targetId))
    }

    private func rememberDisplayedNotification(type: AppNotificationEventType, targetId: String) {
        let key = notificationKey(type: type, targetId: targetId)
        guard displayedNotificationKeySet.insert(key).inserted else { return }
        displayedNotificationKeys.append(key)
        if displayedNotificationKeys.count > displayedNotificationLimit {
            let removed = displayedNotificationKeys.removeFirst()
            displayedNotificationKeySet.remove(removed)
        }
    }

    private func foregroundPresentationOptions(
        for userInfo: [AnyHashable: Any]
    ) -> UNNotificationPresentationOptions {
        guard
            let typeRaw = userInfo["type"] as? String,
            let type = AppNotificationEventType(rawValue: typeRaw),
            type == .coachNoteReceived
                || type == .clientNoteReceived
                || type == .workoutReportSent
                || type == .nutritionReportSent,
            let targetId = userInfo["targetId"] as? String,
            targetId.isEmpty == false
        else {
            return [.banner, .badge, .sound, .list]
        }

        let senderId = userInfo["senderId"] as? String
        let isChat = type == .coachNoteReceived || type == .clientNoteReceived
        if (isChat && activeChatCounterpartId == senderId)
            || wasNotificationDisplayed(type: type, targetId: targetId) {
            rememberDisplayedNotification(type: type, targetId: targetId)
            return [.badge, .list]
        }

        rememberDisplayedNotification(type: type, targetId: targetId)
        return [.banner, .badge, .sound, .list]
    }

    private func syncPreferredLanguageIfPossible() async {
        guard let currentUserId else { return }

        let language = UserDefaults.standard.string(forKey: AppLanguage.appStorageKey) ?? AppLanguage.russian.rawValue

        do {
            try await firestore
                .collection("users")
                .document(currentUserId)
                .setData([
                    "preferredLanguage": language
                ], merge: true)
        } catch {
            #if DEBUG
            print("Failed to sync preferred language:", error.localizedDescription)
            #endif
        }
    }
}

final class FitLifeAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Configure Firebase before any Messaging/Auth/Firestore object can be
        // created. In a SwiftUI app the App delegate runs earlier than the
        // @main App initializer, so doing this only in FitLifeApp.init() leaves
        // a short race during launch.
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        AppPushNotificationsManager.shared.configure()
        if let userInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            AppPushNotificationsManager.shared.handleNotificationResponse(userInfo: userInfo)
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        AppPushNotificationsManager.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        AppPushNotificationsManager.shared.didFailToRegisterForRemoteNotifications(error)
    }
}

extension AppPushNotificationsManager: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task { @MainActor in
            let oldToken = self.fcmToken
                ?? UserDefaults.standard.string(forKey: self.lastSyncedTokenKey)
            if let oldToken,
               oldToken != fcmToken,
               let currentUserId = self.currentUserId,
               UserDefaults.standard.string(forKey: self.lastSyncedUserIdKey) == currentUserId {
                await self.removeFCMToken(oldToken, from: currentUserId)
            }
            self.fcmToken = fcmToken
            await self.syncFCMTokenIfPossible()
        }
    }
}

extension AppPushNotificationsManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Task { @MainActor in
            completionHandler(
                self.foregroundPresentationOptions(
                    for: notification.request.content.userInfo
                )
            )
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            self.handleNotificationResponse(userInfo: response.notification.request.content.userInfo)
        }
        completionHandler()
    }
}
