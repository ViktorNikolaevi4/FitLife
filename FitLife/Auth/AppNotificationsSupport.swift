import SwiftUI
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import UserNotifications

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
    let isEphemeral: Bool

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
        isArchived: Bool = false,
        isEphemeral: Bool = false
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
        self.isEphemeral = isEphemeral
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
        self.isEphemeral = false
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
    private static let pageSize = 50

    @Published private(set) var notifications: [AppNotificationEvent] = []
    @Published private(set) var unreadCount = 0 {
        didSet {
            syncApplicationIconBadge()
        }
    }

    private let firestore: Firestore
    private var notificationsListener: ListenerRegistration?
    private var unreadCountListener: ListenerRegistration?
    private var currentUserId: String?
    private var loadedDocuments: [String: DocumentSnapshot] = [:]
    private var lastPageDocument: DocumentSnapshot?
    private var serverUnreadCount = 0
    private var isBootstrappingUnreadCounter = false
    private var hasReconciledUnreadCounter = false
    private var hasLoadedUnreadSnapshot = false
    private var conversationsBeingMarkedRead: Set<String> = []
    private var conversationsNeedingAnotherPass: Set<String> = []
    @Published private(set) var canLoadMore = false
    @Published private(set) var isLoadingMore = false

    init(firestore: Firestore = .firestore()) {
        self.firestore = firestore
    }

    deinit {
        notificationsListener?.remove()
        unreadCountListener?.remove()
    }

    func setCurrentUser(_ userId: String?) {
        guard currentUserId != userId else { return }
        currentUserId = userId
        notificationsListener?.remove()
        unreadCountListener?.remove()
        notifications = []
        unreadCount = 0
        serverUnreadCount = 0
        loadedDocuments = [:]
        lastPageDocument = nil
        canLoadMore = false
        isLoadingMore = false
        isBootstrappingUnreadCounter = false
        hasReconciledUnreadCounter = false
        hasLoadedUnreadSnapshot = false
        conversationsBeingMarkedRead = []
        conversationsNeedingAnotherPass = []

        guard let userId, userId.isEmpty == false else { return }

        unreadCountListener = firestore
            .collection("users")
            .document(userId)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                let unreadCount = snapshot?.data()?["unreadNotificationCount"] as? NSNumber

                Task { @MainActor in
                    guard self.currentUserId == userId else { return }
                    if let unreadCount {
                        self.serverUnreadCount = max(0, unreadCount.intValue)
                        self.refreshUnreadCount()
                    } else {
                        await self.bootstrapUnreadCounterIfNeeded(for: userId)
                    }
                }
            }

        notificationsListener = firestore
            .collection("notification_events")
            .whereField("recipientId", isEqualTo: userId)
            .whereField("isRead", isEqualTo: false)
            .order(by: "createdAt", descending: true)
            .limit(to: Self.pageSize)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let snapshot else { return }
                Task { @MainActor in
                    guard self.currentUserId == userId else { return }
                    self.canLoadMore = snapshot.documents.count == Self.pageSize
                    if snapshot.metadata.isFromCache == false {
                        self.hasLoadedUnreadSnapshot = true
                    }
                    self.mergeLiveSnapshot(snapshot)
                    if self.lastPageDocument == nil {
                        self.lastPageDocument = snapshot.documents.last
                    }
                    if snapshot.metadata.isFromCache == false,
                       self.hasReconciledUnreadCounter == false {
                        await self.reconcileUnreadCounter(for: userId)
                    }
                }
            }
    }

    func markRead(_ notification: AppNotificationEvent) async {
        guard notification.isRead == false, currentUserId == notification.recipientId else { return }

        do {
            let batch = firestore.batch()
            batch.setData(
                ["isRead": true],
                forDocument: firestore.collection("notification_events").document(notification.id),
                merge: true
            )
            batch.setData(
                unreadCounterUpdate(by: -1),
                forDocument: firestore.collection("users").document(notification.recipientId),
                merge: true
            )
            try await batch.commit()
            serverUnreadCount = max(0, serverUnreadCount - 1)
            loadedDocuments.removeValue(forKey: notification.id)
            rebuildNotifications()
            await reconcileUnreadCounter(for: notification.recipientId)
        } catch {
            #if DEBUG
            print("Failed to mark notification as read:", error.localizedDescription)
            #endif
        }
    }

    /// Marks only incoming chat messages from one counterpart as read.
    /// The query intentionally uses recipientId alone so it does not require
    /// an additional composite Firestore index; sender and type are filtered
    /// locally before the writes are committed.
    func markConversationRead(
        counterpartId: String,
        incomingType: AppNotificationEventType
    ) async {
        guard
            let userId = currentUserId,
            counterpartId.isEmpty == false
        else { return }

        let operationKey = "\(counterpartId)|\(incomingType.rawValue)"
        guard conversationsBeingMarkedRead.insert(operationKey).inserted else {
            conversationsNeedingAnotherPass.insert(operationKey)
            return
        }

        defer {
            conversationsBeingMarkedRead.remove(operationKey)
            conversationsNeedingAnotherPass.remove(operationKey)
        }

        repeat {
            conversationsNeedingAnotherPass.remove(operationKey)
            await markConversationReadPass(
                userId: userId,
                counterpartId: counterpartId,
                incomingType: incomingType
            )
        } while currentUserId == userId
            && conversationsNeedingAnotherPass.contains(operationKey)
    }

    func markAllRead() async {
        do {
            guard let userId = currentUserId else { return }
            let snapshot = try await firestore
                .collection("notification_events")
                .whereField("recipientId", isEqualTo: userId)
                .getDocuments()
            let unreadDocuments = snapshot.documents.filter { document in
                let data = document.data()
                return (data["isRead"] as? Bool) != true && (data["isArchived"] as? Bool) != true
            }

            for startIndex in stride(from: 0, to: unreadDocuments.count, by: 450) {
                let endIndex = min(startIndex + 450, unreadDocuments.count)
                let documents = unreadDocuments[startIndex..<endIndex]
                let batch = firestore.batch()
                for document in documents {
                    batch.setData(["isRead": true], forDocument: document.reference, merge: true)
                }
                batch.setData(
                    unreadCounterUpdate(by: -documents.count),
                    forDocument: firestore.collection("users").document(userId),
                    merge: true
                )
                try await batch.commit()
            }

            // Always repair a stale denormalized counter, even when every
            // event was already marked as read and the loop above was empty.
            try await firestore.collection("users").document(userId).setData([
                "unreadNotificationCount": 0,
                "unreadCounterInitialized": true,
                "unreadCounterUpdatedAt": FieldValue.serverTimestamp()
            ], merge: true)

            guard currentUserId == userId else { return }
            serverUnreadCount = 0
            loadedDocuments = [:]
            rebuildNotifications()
            await reconcileUnreadCounter(for: userId)
        } catch {
            #if DEBUG
            print("Failed to mark all notifications as read:", error.localizedDescription)
            #endif
        }
    }

    private func markConversationReadPass(
        userId: String,
        counterpartId: String,
        incomingType: AppNotificationEventType
    ) async {
        guard currentUserId == userId else { return }

        // Remove already loaded events immediately. The chat and application
        // badges therefore react to the tap without waiting for the network.
        let optimisticDocumentIds: Set<String> = Set(notifications.compactMap { notification -> String? in
            guard
                notification.recipientId == userId,
                notification.senderId == counterpartId,
                notification.type == incomingType,
                notification.isRead == false,
                notification.isArchived == false,
                notification.isEphemeral == false
            else { return nil }
            return notification.id
        })

        if optimisticDocumentIds.isEmpty == false {
            for documentId in optimisticDocumentIds {
                loadedDocuments.removeValue(forKey: documentId)
            }
            serverUnreadCount = max(0, serverUnreadCount - optimisticDocumentIds.count)
            rebuildNotifications()
        }

        do {
            let snapshot = try await firestore
                .collection("notification_events")
                .whereField("recipientId", isEqualTo: userId)
                .getDocuments()

            guard currentUserId == userId else { return }
            let unreadDocuments = snapshot.documents.filter { document in
                let data = document.data()
                return (data["senderId"] as? String) == counterpartId
                    && (data["type"] as? String) == incomingType.rawValue
                    && (data["isRead"] as? Bool) != true
                    && (data["isArchived"] as? Bool) != true
            }

            for startIndex in stride(from: 0, to: unreadDocuments.count, by: 450) {
                let endIndex = min(startIndex + 450, unreadDocuments.count)
                let documents = unreadDocuments[startIndex..<endIndex]
                let batch = firestore.batch()

                for document in documents {
                    batch.setData(["isRead": true], forDocument: document.reference, merge: true)
                }
                batch.setData(
                    unreadCounterUpdate(by: -documents.count),
                    forDocument: firestore.collection("users").document(userId),
                    merge: true
                )
                try await batch.commit()
            }

            guard currentUserId == userId else { return }
            for document in unreadDocuments {
                loadedDocuments.removeValue(forKey: document.documentID)
            }
            let additionallyReadCount = max(0, unreadDocuments.count - optimisticDocumentIds.count)
            serverUnreadCount = max(0, serverUnreadCount - additionallyReadCount)
            rebuildNotifications()
            await reconcileUnreadCounter(for: userId)
        } catch {
            #if DEBUG
            print("Failed to mark conversation notifications as read:", error.localizedDescription)
            #endif
        }
    }

    func delete(_ notification: AppNotificationEvent) async {
        do {
            let batch = firestore.batch()
            batch.setData(
                ["isArchived": true, "isRead": true],
                forDocument: firestore.collection("notification_events").document(notification.id),
                merge: true
            )
            if notification.isRead == false {
                batch.setData(
                    unreadCounterUpdate(by: -1),
                    forDocument: firestore.collection("users").document(notification.recipientId),
                    merge: true
                )
            }
            try await batch.commit()
            if notification.isRead == false {
                serverUnreadCount = max(0, serverUnreadCount - 1)
            }
            loadedDocuments.removeValue(forKey: notification.id)
            rebuildNotifications()
            await reconcileUnreadCounter(for: notification.recipientId)
        } catch {
            #if DEBUG
            print("Failed to archive notification:", error.localizedDescription)
            #endif
        }
    }

    func loadMoreNotifications() async {
        guard
            isLoadingMore == false,
            canLoadMore,
            let userId = currentUserId,
            let lastPageDocument
        else {
            return
        }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let snapshot = try await firestore
                .collection("notification_events")
                .whereField("recipientId", isEqualTo: userId)
                .whereField("isRead", isEqualTo: false)
                .order(by: "createdAt", descending: true)
                .start(afterDocument: lastPageDocument)
                .limit(to: Self.pageSize)
                .getDocuments()

            guard currentUserId == userId else { return }
            canLoadMore = snapshot.documents.count == Self.pageSize
            merge(snapshot.documents)
            if let lastDocument = snapshot.documents.last {
                self.lastPageDocument = lastDocument
            }
            refreshUnreadCount()
        } catch {}
    }

    private func bootstrapUnreadCounterIfNeeded(for userId: String) async {
        guard isBootstrappingUnreadCounter == false, currentUserId == userId else { return }
        isBootstrappingUnreadCounter = true
        defer { isBootstrappingUnreadCounter = false }

        do {
            let snapshot = try await firestore
                .collection("notification_events")
                .whereField("recipientId", isEqualTo: userId)
                .getDocuments()
            let count = snapshot.documents.reduce(into: 0) { result, document in
                let data = document.data()
                if (data["isRead"] as? Bool) != true && (data["isArchived"] as? Bool) != true {
                    result += 1
                }
            }
            guard currentUserId == userId else { return }
            try await firestore.collection("users").document(userId).setData([
                "unreadNotificationCount": count,
                "unreadCounterInitialized": true,
                "unreadCounterUpdatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {}
    }

    private func reconcileUnreadCounter(for userId: String) async {
        guard
            currentUserId == userId,
            let firebaseUser = Auth.auth().currentUser,
            firebaseUser.uid == userId,
            let projectId = FirebaseApp.app()?.options.projectID,
            let url = URL(
                string: "https://europe-west1-\(projectId).cloudfunctions.net/reconcileUnreadNotifications"
            )
        else { return }

        do {
            let idToken = try await firebaseUser.getIDToken()
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data("{}".utf8)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard
                let httpResponse = response as? HTTPURLResponse,
                (200..<300).contains(httpResponse.statusCode),
                let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let countValue = payload["unreadCount"] as? NSNumber
            else {
                throw URLError(.badServerResponse)
            }
            let count = max(0, countValue.intValue)

            guard currentUserId == userId else { return }
            serverUnreadCount = count
            hasReconciledUnreadCounter = true
            refreshUnreadCount()
        } catch {
            #if DEBUG
            print("Failed to reconcile unread notification counter:", error.localizedDescription)
            #endif
        }
    }

    private func unreadCounterUpdate(by delta: Int) -> [String: Any] {
        [
            "unreadNotificationCount": FieldValue.increment(Int64(delta)),
            "unreadCounterInitialized": true,
            "unreadCounterUpdatedAt": FieldValue.serverTimestamp()
        ]
    }

    private func merge(_ documents: [DocumentSnapshot]) {
        for document in documents {
            loadedDocuments[document.documentID] = document
        }
        rebuildNotifications()
    }

    private func mergeLiveSnapshot(_ snapshot: QuerySnapshot) {
        for change in snapshot.documentChanges {
            switch change.type {
            case .added, .modified:
                loadedDocuments[change.document.documentID] = change.document
            case .removed:
                let data = change.document.data()
                if (data["isRead"] as? Bool) == true
                    || (data["isArchived"] as? Bool) == true {
                    loadedDocuments.removeValue(forKey: change.document.documentID)
                }
            }
        }
        rebuildNotifications()
    }

    private func rebuildNotifications() {
        notifications = loadedDocuments.values
            .compactMap { document in
                guard let data = document.data() else { return nil }
                return AppNotificationEvent(id: document.documentID, data: data)
            }
            // The inbox is an action queue, not a history: once a notification
            // has been read, it should no longer occupy the user's attention.
            .filter { $0.isArchived == false && $0.isRead == false }
            .sorted { $0.createdAt > $1.createdAt }
        refreshUnreadCount()
    }

    // The server counter is efficient for a large notification history. The
    // live event list is a safety net: an arriving unread event must be
    // reflected in the UI even while that counter is being updated remotely.
    private func refreshUnreadCount() {
        if hasLoadedUnreadSnapshot, canLoadMore == false {
            // A complete unread-only query is the most accurate source and
            // also repairs a stale denormalized server counter in the UI.
            unreadCount = notifications.count
        } else {
            unreadCount = max(serverUnreadCount, notifications.count)
        }
    }

    private func syncApplicationIconBadge() {
        let badgeCount = unreadCount
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(badgeCount)
        }
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
                        await notificationsStore.delete(notification)
                    }
                } label: {
                    AppNotificationRow(notification: notification)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .onAppear {
                    guard notification.id == notificationsStore.notifications.last?.id else { return }
                    Task {
                        await notificationsStore.loadMoreNotifications()
                    }
                }
            }

            if notificationsStore.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
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

struct AppNotificationDestinationScreen: View {
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
                ClientCoachingEntryScreen(clientId: profile.id, opensChatInitially: true)
            case .profileUpdateRequested, .coachingRequestApproved, .coachingRequestRejected:
                ClientNotificationBridgeScreen(notification: notification, clientId: profile.id)
            case .coachingRequestSubmitted, .workoutReportSent, .nutritionReportSent, .checkInSubmitted, .clientNoteReceived, .workoutAssigned:
                ClientCoachingEntryScreen(clientId: profile.id)
            }
        case .trainer:
            switch notification.type {
            case .clientNoteReceived:
                TrainerClientNotificationDestination(
                    trainerId: profile.id,
                    clientId: notification.senderId,
                    opensChatInitially: true
                )
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
    var opensChatInitially = false

    @State private var client: AppUserProfile?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let client {
                TrainerClientSupportScreen(
                    trainerId: trainerId,
                    client: client,
                    opensChatInitially: opensChatInitially
                )
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
    @State private var assignment: WorkoutAssignment?
    @State private var trainerName: String?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let assignment {
                ClientAssignmentDetailScreen(
                    assignment: assignment,
                    trainerName: trainerName
                )
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
            } else {
                ClientAssignedWorkoutsScreen(clientId: clientId)
            }
        }
        .task { await loadAssignment() }
    }

    private func loadAssignment() async {
        defer { isLoading = false }

        do {
            let assignmentDocument = try await Firestore.firestore()
                .collection("workout_assignments")
                .document(notification.targetId)
                .getDocument()
            guard
                let data = assignmentDocument.data(),
                let assignment = WorkoutAssignment(id: assignmentDocument.documentID, data: data),
                assignment.clientId == clientId
            else {
                return
            }

            self.assignment = assignment
            if let trainerData = try await Firestore.firestore()
                .collection("users")
                .document(assignment.trainerId)
                .getDocument()
                .data() {
                trainerName = AppUserProfile(id: assignment.trainerId, data: trainerData)?.displayName
            }
            await notificationsStore.markRead(notification)
        } catch {
            assignment = nil
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
