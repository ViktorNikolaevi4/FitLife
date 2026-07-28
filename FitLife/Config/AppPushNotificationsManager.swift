import Foundation
import UIKit
import UserNotifications
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging

@MainActor
final class AppPushNotificationsManager: NSObject, ObservableObject {
    static let shared = AppPushNotificationsManager()

    @Published private(set) var fcmToken: String?
    @Published private(set) var openedNotification: AppNotificationEvent?

    private var currentUserId: String?
    private var hasAPNSToken = false
    private let didRequestPermissionKey = "push.didRequestAuthorization"

    private var firestore: Firestore {
        Firestore.firestore()
    }

    func configure() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        Task {
            await ensurePushRegistrationFlow()
        }
    }

    func setCurrentUser(_ userId: String?) {
        currentUserId = userId
        Task {
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
            try await firestore
                .collection("users")
                .document(currentUserId)
                .setData([
                    "fcmTokens": FieldValue.arrayUnion([fcmToken]),
                    "lastFCMToken": fcmToken,
                    "pushTokenUpdatedAt": FieldValue.serverTimestamp()
                ], merge: true)
        } catch {
            #if DEBUG
            print("Failed to sync FCM token:", error.localizedDescription)
            #endif
        }
    }

    private func refreshFCMTokenIfPossible() async {
        let token = await withCheckedContinuation { continuation in
            Messaging.messaging().token { token, _ in
                continuation.resume(returning: token)
            }
        }

        guard let token, token.isEmpty == false else { return }
        fcmToken = token
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
        completionHandler([.banner, .badge, .sound, .list])
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
