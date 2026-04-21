import SwiftUI
import FirebaseFirestore

enum AppNotificationEventType: String, Codable, CaseIterable {
    case coachingRequestSubmitted = "coaching_request_submitted"
    case coachingRequestApproved = "coaching_request_approved"
    case coachingRequestRejected = "coaching_request_rejected"
    case workoutReportSent = "workout_report_sent"
    case nutritionReportSent = "nutrition_report_sent"
    case checkInSubmitted = "checkin_submitted"
    case coachNoteReceived = "coach_note_received"
    case clientNoteReceived = "client_note_received"
    case workoutAssigned = "workout_assigned"
    case profileUpdateRequested = "profile_update_requested"
}

enum AppNotificationTargetType: String, Codable {
    case coachingRequest = "coaching_request"
    case coachingConnection = "coaching_connection"
    case workoutReport = "workout_report"
    case nutritionReport = "nutrition_report"
    case checkIn = "checkin"
    case workoutAssignment = "workout_assignment"
    case profileUpdateRequest = "profile_update_request"
}

struct AppNotificationEvent: Identifiable, Hashable {
    let id: String
    let type: AppNotificationEventType
    let recipientId: String
    let senderId: String
    let senderName: String
    let targetType: AppNotificationTargetType
    let targetId: String
    let createdAt: Date
    let isRead: Bool

    init(
        id: String = UUID().uuidString,
        type: AppNotificationEventType,
        recipientId: String,
        senderId: String,
        senderName: String = "",
        targetType: AppNotificationTargetType,
        targetId: String,
        createdAt: Date = .now,
        isRead: Bool = false
    ) {
        self.id = id
        self.type = type
        self.recipientId = recipientId
        self.senderId = senderId
        self.senderName = senderName
        self.targetType = targetType
        self.targetId = targetId
        self.createdAt = createdAt
        self.isRead = isRead
    }

    init?(id: String, data: [String: Any]) {
        guard
            let typeRaw = data["type"] as? String,
            let type = AppNotificationEventType(rawValue: typeRaw),
            let recipientId = data["recipientId"] as? String,
            let senderId = data["senderId"] as? String,
            let targetTypeRaw = data["targetType"] as? String,
            let targetType = AppNotificationTargetType(rawValue: targetTypeRaw),
            let targetId = data["targetId"] as? String
        else {
            return nil
        }

        self.id = id
        self.type = type
        self.recipientId = recipientId
        self.senderId = senderId
        self.senderName = (data["senderName"] as? String) ?? ""
        self.targetType = targetType
        self.targetId = targetId
        if let createdTimestamp = data["createdAt"] as? Timestamp {
            self.createdAt = createdTimestamp.dateValue()
        } else {
            self.createdAt = (data["createdAt"] as? Date) ?? .now
        }
        self.isRead = (data["isRead"] as? Bool) ?? false
    }

    var firestoreData: [String: Any] {
        [
            "type": type.rawValue,
            "recipientId": recipientId,
            "senderId": senderId,
            "senderName": senderName,
            "targetType": targetType.rawValue,
            "targetId": targetId,
            "createdAt": createdAt,
            "isRead": isRead
        ]
    }

    var localizedTitle: String {
        AppLocalizer.string("notifications.event.\(type.rawValue).title")
    }

    var localizedBody: String {
        let keyPrefix = "notifications.event.\(type.rawValue).body"
        let trimmedSenderName = senderName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSenderName.isEmpty == false {
            return AppLocalizer.format("\(keyPrefix).sender", trimmedSenderName)
        }
        return AppLocalizer.string(keyPrefix)
    }
}

enum AppNotificationEventWriter {
    static func create(
        type: AppNotificationEventType,
        recipientId: String,
        senderId: String,
        senderName: String = "",
        targetType: AppNotificationTargetType,
        targetId: String,
        firestore: Firestore = .firestore()
    ) async throws {
        guard recipientId.isEmpty == false, targetId.isEmpty == false else { return }

        let event = AppNotificationEvent(
            type: type,
            recipientId: recipientId,
            senderId: senderId,
            senderName: senderName,
            targetType: targetType,
            targetId: targetId
        )

        try await firestore
            .collection("notification_events")
            .document(event.id)
            .setData(event.firestoreData)
    }

    static func createForActiveTrainers(
        type: AppNotificationEventType,
        senderId: String,
        senderName: String = "",
        targetType: AppNotificationTargetType,
        targetId: String,
        firestore: Firestore = .firestore()
    ) async throws {
        let trainersSnapshot = try await firestore
            .collection("users")
            .whereField("role", isEqualTo: AppUserRole.trainer.rawValue)
            .whereField("isActive", isEqualTo: true)
            .getDocuments()

        let batch = firestore.batch()
        for trainerDocument in trainersSnapshot.documents {
            let recipientId = trainerDocument.documentID
            let event = AppNotificationEvent(
                type: type,
                recipientId: recipientId,
                senderId: senderId,
                senderName: senderName,
                targetType: targetType,
                targetId: targetId
            )
            batch.setData(
                event.firestoreData,
                forDocument: firestore.collection("notification_events").document(event.id)
            )
        }

        try await batch.commit()
    }
}

@MainActor
final class AppNotificationsStore: ObservableObject {
    @Published private(set) var notifications: [AppNotificationEvent] = []
    @Published private(set) var unreadCount = 0

    private let firestore: Firestore
    private var listener: ListenerRegistration?
    private var currentUserId: String?

    init(firestore: Firestore = .firestore()) {
        self.firestore = firestore
    }

    deinit {
        listener?.remove()
    }

    func setCurrentUser(_ userId: String?) {
        guard currentUserId != userId else { return }
        currentUserId = userId
        listener?.remove()
        notifications = []
        unreadCount = 0

        guard let userId, userId.isEmpty == false else { return }

        listener = firestore
            .collection("notification_events")
            .whereField("recipientId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let snapshot else { return }
                Task { @MainActor in
                    self.notifications = snapshot.documents.compactMap { document in
                        AppNotificationEvent(id: document.documentID, data: document.data())
                    }
                    self.unreadCount = self.notifications.filter { $0.isRead == false }.count
                }
            }
    }

    func markRead(_ notification: AppNotificationEvent) async {
        guard notification.isRead == false else { return }

        do {
            try await firestore
                .collection("notification_events")
                .document(notification.id)
                .setData(["isRead": true], merge: true)
        } catch {}
    }

    func markAllRead() async {
        let unreadNotifications = notifications.filter { $0.isRead == false }
        guard unreadNotifications.isEmpty == false else { return }

        let batch = firestore.batch()
        for notification in unreadNotifications {
            let ref = firestore.collection("notification_events").document(notification.id)
            batch.setData(["isRead": true], forDocument: ref, merge: true)
        }

        do {
            try await batch.commit()
        } catch {}
    }
}

struct AppNotificationsScreen: View {
    @EnvironmentObject private var notificationsStore: AppNotificationsStore
    @State private var selectedNotification: AppNotificationEvent?

    var body: some View {
        List {
            ForEach(notificationsStore.notifications) { notification in
                Button {
                    selectedNotification = notification
                    Task {
                        await notificationsStore.markRead(notification)
                    }
                } label: {
                    AppNotificationRow(notification: notification)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
            }
        }
        .overlay {
            if notificationsStore.notifications.isEmpty {
                ContentUnavailableView(
                    AppLocalizer.string("notifications.inbox.empty.title"),
                    systemImage: "bell.slash",
                    description: Text(AppLocalizer.string("notifications.inbox.empty.subtitle"))
                )
            }
        }
        .navigationTitle(AppLocalizer.string("notifications.inbox.title"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if notificationsStore.unreadCount > 0 {
                    Button(AppLocalizer.string("notifications.inbox.mark_all_read")) {
                        Task {
                            await notificationsStore.markAllRead()
                        }
                    }
                }
            }
        }
        .navigationDestination(item: $selectedNotification) { notification in
            AppNotificationDestinationScreen(notification: notification)
        }
    }
}

private struct AppNotificationDestinationScreen: View {
    let notification: AppNotificationEvent

    @EnvironmentObject private var sessionStore: AppSessionStore

    var body: some View {
        Group {
            if let profile = sessionStore.profile {
                switch notification.targetType {
                case .coachingRequest:
                    coachingRequestDestination(for: profile)
                case .coachingConnection, .checkIn, .profileUpdateRequest:
                    coachingAreaDestination(for: profile)
                case .workoutAssignment:
                    workoutAssignmentDestination(for: profile)
                case .workoutReport, .nutritionReport:
                    reportsDestination(for: profile)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func coachingRequestDestination(for profile: AppUserProfile) -> some View {
        switch profile.role {
        case .client:
            ClientCoachingEntryScreen(clientId: profile.id)
        case .trainer, .owner:
            CoachingRequestsReviewScreen(currentUser: profile)
        }
    }

    @ViewBuilder
    private func coachingAreaDestination(for profile: AppUserProfile) -> some View {
        switch profile.role {
        case .client:
            ClientCoachingEntryScreen(clientId: profile.id)
        case .trainer, .owner:
            TrainerAssignedClientsScreen(trainerId: profile.id)
        }
    }

    @ViewBuilder
    private func workoutAssignmentDestination(for profile: AppUserProfile) -> some View {
        switch profile.role {
        case .client:
            ClientAssignedWorkoutsScreen(clientId: profile.id)
        case .trainer, .owner:
            TrainerAssignmentsOverviewScreen(trainerId: profile.id)
        }
    }

    @ViewBuilder
    private func reportsDestination(for profile: AppUserProfile) -> some View {
        switch notification.targetType {
        case .workoutReport:
            WorkoutReportNotificationDestination(reportId: notification.targetId)
        case .nutritionReport:
            NutritionReportNotificationDestination(reportId: notification.targetId)
        case .coachingRequest, .coachingConnection, .checkIn, .workoutAssignment, .profileUpdateRequest:
            switch profile.role {
            case .client:
                ClientCoachingEntryScreen(clientId: profile.id)
            case .trainer, .owner:
                TrainerAssignedClientsScreen(trainerId: profile.id)
            }
        }
    }
}

private struct WorkoutReportNotificationDestination: View {
    let reportId: String

    @State private var report: CoachingWorkoutReport?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let report {
                CoachingWorkoutReportDetailScreen(report: report)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
            } else {
                ContentUnavailableView(
                    AppLocalizer.string("notifications.inbox.empty.title"),
                    systemImage: "doc.text.magnifyingglass",
                    description: Text(errorMessage ?? AppLocalizer.string("common.error.generic"))
                )
            }
        }
        .task(id: reportId) {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil

        do {
            let snapshot = try await Firestore.firestore()
                .collection("coaching_workout_reports")
                .document(reportId)
                .getDocument()

            guard let data = snapshot.data(),
                  let report = CoachingWorkoutReport(id: snapshot.documentID, data: data) else {
                errorMessage = AppLocalizer.string("common.error.generic")
                isLoading = false
                return
            }

            self.report = report
            isLoading = false
        } catch {
            errorMessage = AppErrorPresenter.message(for: error)
            isLoading = false
        }
    }
}

private struct NutritionReportNotificationDestination: View {
    let reportId: String

    @State private var report: CoachingNutritionReport?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let report {
                CoachingNutritionReportDetailScreen(report: report)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
            } else {
                ContentUnavailableView(
                    AppLocalizer.string("notifications.inbox.empty.title"),
                    systemImage: "doc.text.magnifyingglass",
                    description: Text(errorMessage ?? AppLocalizer.string("common.error.generic"))
                )
            }
        }
        .task(id: reportId) {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil

        do {
            let snapshot = try await Firestore.firestore()
                .collection("coaching_nutrition_reports")
                .document(reportId)
                .getDocument()

            guard let data = snapshot.data(),
                  let report = CoachingNutritionReport(id: snapshot.documentID, data: data) else {
                errorMessage = AppLocalizer.string("common.error.generic")
                isLoading = false
                return
            }

            self.report = report
            isLoading = false
        } catch {
            errorMessage = AppErrorPresenter.message(for: error)
            isLoading = false
        }
    }
}

private struct AppNotificationRow: View {
    let notification: AppNotificationEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(notification.isRead ? Color.clear : Color.accentColor)
                .frame(width: 10, height: 10)
                .padding(.top, 7)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(notification.localizedTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer(minLength: 12)

                    Text(notification.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }

                Text(notification.localizedBody)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
