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
    let isArchived: Bool

    init(
        id: String = UUID().uuidString,
        type: AppNotificationEventType,
        recipientId: String,
        senderId: String,
        senderName: String = "",
        targetType: AppNotificationTargetType,
        targetId: String,
        createdAt: Date = .now,
        isRead: Bool = false,
        isArchived: Bool = false
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
        self.isArchived = isArchived
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
        self.isArchived = (data["isArchived"] as? Bool) ?? false
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
            "isRead": isRead,
            "isArchived": isArchived
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
                    self.notifications = snapshot.documents
                        .compactMap { document in
                            AppNotificationEvent(id: document.documentID, data: document.data())
                        }
                        .filter { $0.isArchived == false }
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

    func delete(_ notification: AppNotificationEvent) async {
        do {
            try await firestore
                .collection("notification_events")
                .document(notification.id)
                .setData(["isArchived": true, "isRead": true], merge: true)
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
            CoachingRequestNotificationDestination(notification: notification, currentUser: profile)
        }
    }

    @ViewBuilder
    private func coachingAreaDestination(for profile: AppUserProfile) -> some View {
        switch profile.role {
        case .client:
            switch notification.type {
            case .coachNoteReceived:
                ClientNoteNotificationDestination(notification: notification, clientId: profile.id)
            case .profileUpdateRequested, .coachingRequestApproved, .coachingRequestRejected:
                ClientNotificationBridgeScreen(notification: notification, clientId: profile.id)
            case .coachingRequestSubmitted, .workoutReportSent, .nutritionReportSent, .checkInSubmitted, .clientNoteReceived, .workoutAssigned:
                ClientCoachingEntryScreen(clientId: profile.id)
            }
        case .trainer:
            switch notification.type {
            case .clientNoteReceived:
                TrainerNoteNotificationDestination(notification: notification, trainerId: profile.id, clientId: notification.senderId)
            case .checkInSubmitted:
                TrainerNotificationBridgeScreen(notification: notification, trainerId: profile.id, clientId: notification.senderId)
            case .coachingRequestSubmitted, .coachingRequestApproved, .coachingRequestRejected, .workoutReportSent, .nutritionReportSent, .coachNoteReceived, .workoutAssigned, .profileUpdateRequested:
                TrainerClientNotificationDestination(trainerId: profile.id, clientId: notification.senderId)
            }
        case .owner:
            TrainerAssignedClientsScreen(trainerId: profile.id)
        }
    }

    @ViewBuilder
    private func workoutAssignmentDestination(for profile: AppUserProfile) -> some View {
        switch profile.role {
        case .client:
            ClientWorkoutAssignmentNotificationDestination(notification: notification, clientId: profile.id)
        case .trainer, .owner:
            TrainerAssignmentsOverviewScreen(trainerId: profile.id)
        }
    }

    @ViewBuilder
    private func reportsDestination(for profile: AppUserProfile) -> some View {
        switch profile.role {
        case .trainer:
            switch notification.targetType {
            case .workoutReport:
                WorkoutReportNotificationDestination(notification: notification)
            case .nutritionReport:
                NutritionReportNotificationDestination(notification: notification)
            case .coachingRequest, .coachingConnection, .checkIn, .workoutAssignment, .profileUpdateRequest:
                TrainerClientNotificationDestination(trainerId: profile.id, clientId: notification.senderId)
            }
        case .client:
            switch notification.targetType {
            case .workoutReport:
                WorkoutReportNotificationDestination(notification: notification)
            case .nutritionReport:
                NutritionReportNotificationDestination(notification: notification)
            case .coachingRequest, .coachingConnection, .checkIn, .workoutAssignment, .profileUpdateRequest:
                ClientCoachingEntryScreen(clientId: profile.id)
            }
        case .owner:
            switch notification.targetType {
            case .workoutReport:
                WorkoutReportNotificationDestination(notification: notification)
            case .nutritionReport:
                NutritionReportNotificationDestination(notification: notification)
            case .coachingRequest, .coachingConnection, .checkIn, .workoutAssignment, .profileUpdateRequest:
                TrainerAssignedClientsScreen(trainerId: profile.id)
            }
        }
    }
}

private struct TrainerClientNotificationDestination: View {
    let trainerId: String
    let clientId: String

    @State private var client: AppUserProfile?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let client {
                TrainerClientSupportScreen(trainerId: trainerId, client: client)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
            } else {
                ContentUnavailableView(
                    AppLocalizer.string("notifications.inbox.empty.title"),
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text(errorMessage ?? AppLocalizer.string("common.error.generic"))
                )
            }
        }
        .task(id: clientId) {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil

        do {
            let snapshot = try await Firestore.firestore()
                .collection("users")
                .document(clientId)
                .getDocument()

            guard let data = snapshot.data(),
                  let client = AppUserProfile(id: snapshot.documentID, data: data) else {
                errorMessage = AppLocalizer.string("common.error.generic")
                isLoading = false
                return
            }

            self.client = client
            isLoading = false
        } catch {
            errorMessage = AppErrorPresenter.message(for: error)
            isLoading = false
        }
    }
}

private struct CoachingRequestNotificationDestination: View {
    let notification: AppNotificationEvent
    let currentUser: AppUserProfile

    @EnvironmentObject private var notificationsStore: AppNotificationsStore
    @StateObject private var store: CoachingRequestsReviewStore

    init(notification: AppNotificationEvent, currentUser: AppUserProfile) {
        self.notification = notification
        self.currentUser = currentUser
        _store = StateObject(wrappedValue: CoachingRequestsReviewStore(currentUser: currentUser))
    }

    var body: some View {
        Group {
            if let request = store.requests.first(where: { $0.id == notification.targetId }) {
                CoachingRequestDetailScreen(
                    request: request,
                    currentUser: currentUser,
                    trainers: store.trainers,
                    onApprove: { trainerId in
                        let succeeded = await store.approve(request, trainerId: trainerId)
                        if succeeded {
                            await notificationsStore.delete(notification)
                        }
                        return succeeded
                    },
                    onClarify: { comment in
                        let succeeded = await store.requestClarification(for: request, comment: comment)
                        if succeeded {
                            await notificationsStore.delete(notification)
                        }
                        return succeeded
                    },
                    onReject: { comment in
                        let succeeded = await store.reject(request, comment: comment)
                        if succeeded {
                            await notificationsStore.delete(notification)
                        }
                        return succeeded
                    }
                )
            } else if store.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
            } else {
                ContentUnavailableView(
                    AppLocalizer.string("notifications.inbox.empty.title"),
                    systemImage: "doc.text.magnifyingglass",
                    description: Text(store.errorMessage ?? AppLocalizer.string("common.error.generic"))
                )
            }
        }
        .task {
            await store.load()
        }
    }
}

private struct TrainerNotificationBridgeScreen: View {
    let notification: AppNotificationEvent
    let trainerId: String
    let clientId: String

    @EnvironmentObject private var notificationsStore: AppNotificationsStore
    @State private var openClientCard = false

    var body: some View {
        Color.clear
            .navigationTitle(notification.localizedTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(AppLocalizer.string("notifications.inbox.move_to_client")) {
                        Task {
                            await notificationsStore.delete(notification)
                            openClientCard = true
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $openClientCard) {
                TrainerClientNotificationDestination(trainerId: trainerId, clientId: clientId)
            }
    }
}

private struct ClientNotificationBridgeScreen: View {
    let notification: AppNotificationEvent
    let clientId: String

    @EnvironmentObject private var notificationsStore: AppNotificationsStore
    @State private var openCoaching = false

    var body: some View {
        Color.clear
            .navigationTitle(notification.localizedTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(AppLocalizer.string("notifications.inbox.open_related")) {
                        Task {
                            await notificationsStore.delete(notification)
                            openCoaching = true
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $openCoaching) {
                ClientCoachingEntryScreen(clientId: clientId)
            }
    }
}

private struct ClientWorkoutAssignmentNotificationDestination: View {
    let notification: AppNotificationEvent
    let clientId: String

    @EnvironmentObject private var notificationsStore: AppNotificationsStore
    @State private var openAssignments = false

    var body: some View {
        Color.clear
            .navigationTitle(notification.localizedTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(AppLocalizer.string("notifications.inbox.open_related")) {
                        Task {
                            await notificationsStore.delete(notification)
                            openAssignments = true
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $openAssignments) {
                ClientAssignedWorkoutsScreen(clientId: clientId)
            }
    }
}

private struct ClientNoteNotificationDestination: View {
    let notification: AppNotificationEvent
    let clientId: String

    @EnvironmentObject private var notificationsStore: AppNotificationsStore
    @State private var note: CoachingNote?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var openCoaching = false

    var body: some View {
        Group {
            if let note {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(notification.senderName.isEmpty ? notification.localizedTitle : notification.senderName)
                                .font(.title2.weight(.semibold))
                            Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text(AppLocalizer.string("coaching.notes.title"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(note.message)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color(.secondarySystemGroupedBackground))
                                )
                        }
                    }
                    .padding()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(AppLocalizer.string("notifications.inbox.open_related")) {
                            Task {
                                await notificationsStore.delete(notification)
                                openCoaching = true
                            }
                        }
                    }
                }
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
            } else {
                ContentUnavailableView(
                    AppLocalizer.string("notifications.inbox.empty.title"),
                    systemImage: "message.badge",
                    description: Text(errorMessage ?? AppLocalizer.string("common.error.generic"))
                )
            }
        }
        .navigationTitle(notification.localizedTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $openCoaching) {
            ClientCoachingEntryScreen(clientId: clientId)
        }
        .task(id: notification.targetId) {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil

        do {
            let snapshot = try await Firestore.firestore()
                .collection("coaching_notes")
                .document(notification.targetId)
                .getDocument()

            guard let data = snapshot.data(),
                  let note = CoachingNote(id: snapshot.documentID, data: data) else {
                errorMessage = AppLocalizer.string("common.error.generic")
                isLoading = false
                return
            }

            self.note = note
            isLoading = false
        } catch {
            errorMessage = AppErrorPresenter.message(for: error)
            isLoading = false
        }
    }
}

private struct TrainerNoteNotificationDestination: View {
    let notification: AppNotificationEvent
    let trainerId: String
    let clientId: String

    @EnvironmentObject private var notificationsStore: AppNotificationsStore
    @State private var note: CoachingNote?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var openClientCard = false

    var body: some View {
        Group {
            if let note {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(notification.senderName.isEmpty ? notification.localizedTitle : notification.senderName)
                                .font(.title2.weight(.semibold))
                            Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text(AppLocalizer.string("coaching.notes.title"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(note.message)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color(.secondarySystemGroupedBackground))
                                )
                        }
                    }
                    .padding()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(AppLocalizer.string("notifications.inbox.move_to_client")) {
                            Task {
                                await notificationsStore.delete(notification)
                                openClientCard = true
                            }
                        }
                    }
                }
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
            } else {
                ContentUnavailableView(
                    AppLocalizer.string("notifications.inbox.empty.title"),
                    systemImage: "message.badge",
                    description: Text(errorMessage ?? AppLocalizer.string("common.error.generic"))
                )
            }
        }
        .navigationTitle(notification.localizedTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $openClientCard) {
            TrainerClientNotificationDestination(trainerId: trainerId, clientId: clientId)
        }
        .task(id: notification.targetId) {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil

        do {
            let snapshot = try await Firestore.firestore()
                .collection("coaching_notes")
                .document(notification.targetId)
                .getDocument()

            guard let data = snapshot.data(),
                  let note = CoachingNote(id: snapshot.documentID, data: data) else {
                errorMessage = AppLocalizer.string("common.error.generic")
                isLoading = false
                return
            }

            self.note = note
            isLoading = false
        } catch {
            errorMessage = AppErrorPresenter.message(for: error)
            isLoading = false
        }
    }
}

private struct WorkoutReportNotificationDestination: View {
    let notification: AppNotificationEvent

    @EnvironmentObject private var sessionStore: AppSessionStore
    @EnvironmentObject private var notificationsStore: AppNotificationsStore
    @State private var report: CoachingWorkoutReport?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showClientCard = false

    var body: some View {
        Group {
            if let report {
                CoachingWorkoutReportDetailScreen(report: report)
                    .toolbar {
                        if canMoveToClientCard {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(AppLocalizer.string("notifications.inbox.move_to_client")) {
                                    Task {
                                        await notificationsStore.delete(notification)
                                        showClientCard = true
                                    }
                                }
                            }
                        }
                    }
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
        .task(id: notification.targetId) {
            await load()
        }
        .navigationDestination(isPresented: $showClientCard) {
            if let report {
                TrainerClientNotificationDestination(
                    trainerId: sessionStore.profile?.id ?? notification.recipientId,
                    clientId: report.clientId
                )
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil

        do {
            let snapshot = try await Firestore.firestore()
                .collection("coaching_workout_reports")
                .document(notification.targetId)
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

    private var canMoveToClientCard: Bool {
        sessionStore.currentRole == .trainer && report != nil
    }
}

private struct NutritionReportNotificationDestination: View {
    let notification: AppNotificationEvent

    @EnvironmentObject private var sessionStore: AppSessionStore
    @EnvironmentObject private var notificationsStore: AppNotificationsStore
    @State private var report: CoachingNutritionReport?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showClientCard = false

    var body: some View {
        Group {
            if let report {
                CoachingNutritionReportDetailScreen(report: report)
                    .toolbar {
                        if canMoveToClientCard {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(AppLocalizer.string("notifications.inbox.move_to_client")) {
                                    Task {
                                        await notificationsStore.delete(notification)
                                        showClientCard = true
                                    }
                                }
                            }
                        }
                    }
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
        .task(id: notification.targetId) {
            await load()
        }
        .navigationDestination(isPresented: $showClientCard) {
            if let report {
                TrainerClientNotificationDestination(
                    trainerId: sessionStore.profile?.id ?? notification.recipientId,
                    clientId: report.clientId
                )
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil

        do {
            let snapshot = try await Firestore.firestore()
                .collection("coaching_nutrition_reports")
                .document(notification.targetId)
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

    private var canMoveToClientCard: Bool {
        sessionStore.currentRole == .trainer && report != nil
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
