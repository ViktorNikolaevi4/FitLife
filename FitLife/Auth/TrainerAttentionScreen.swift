import SwiftUI
import FirebaseFirestore

enum TrainerAttentionStatus: String, CaseIterable, Identifiable {
    case waitingReply
    case noCheckIn
    case noNutrition
    case missedWorkouts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .waitingReply:
            return AppLocalizer.string("trainer.attention.status.waiting_reply")
        case .noCheckIn:
            return AppLocalizer.string("trainer.attention.status.no_checkin")
        case .noNutrition:
            return AppLocalizer.string("trainer.attention.status.no_nutrition")
        case .missedWorkouts:
            return AppLocalizer.string("trainer.attention.status.missed_workouts")
        }
    }

    var iconName: String {
        switch self {
        case .waitingReply:
            return "bubble.left.and.bubble.right.fill"
        case .noCheckIn:
            return "clock.badge.exclamationmark.fill"
        case .noNutrition:
            return "fork.knife"
        case .missedWorkouts:
            return "dumbbell.fill"
        }
    }

    var tint: Color {
        switch self {
        case .waitingReply:
            return .blue
        case .noCheckIn:
            return .orange
        case .noNutrition:
            return .green
        case .missedWorkouts:
            return .orange
        }
    }

    var priority: Int {
        switch self {
        case .waitingReply:
            return 0
        case .missedWorkouts:
            return 1
        case .noCheckIn:
            return 2
        case .noNutrition:
            return 3
        }
    }
}

struct TrainerClientWeeklyActivity: Hashable {
    let checkInsCount: Int
    let nutritionReportsCount: Int
    let workoutReportsCount: Int
    let assignedWorkoutsCount: Int
    let completedWorkoutsCount: Int
    let openWorkoutAssignmentsCount: Int
    let lastActivityAt: Date?
    let lastNote: CoachingNote?

    static let empty = TrainerClientWeeklyActivity(
        checkInsCount: 0,
        nutritionReportsCount: 0,
        workoutReportsCount: 0,
        assignedWorkoutsCount: 0,
        completedWorkoutsCount: 0,
        openWorkoutAssignmentsCount: 0,
        lastActivityAt: nil,
        lastNote: nil
    )
}

struct TrainerAttentionClientItem: Identifiable, Hashable {
    let client: AppUserProfile
    let statuses: [TrainerAttentionStatus]
    let activity: TrainerClientWeeklyActivity

    var id: String { client.id }

    var primaryPriority: Int {
        statuses.map(\.priority).min() ?? 99
    }
}

@MainActor
final class TrainerAttentionStore: ObservableObject {
    @Published private(set) var items: [TrainerAttentionClientItem] = []
    @Published private(set) var allClientCount = 0
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let trainerId: String
    private let firestore: Firestore

    init(trainerId: String, firestore: Firestore = .firestore()) {
        self.trainerId = trainerId
        self.firestore = firestore
    }

    func load() async {
        guard isLoading == false else { return }

        isLoading = true
        errorMessage = nil

        do {
            let clients = try await loadAssignedClients()
            allClientCount = clients.count
            let activitiesByClientId = try await loadWeeklyActivities(clientIds: Set(clients.map(\.id)))

            var loadedItems: [TrainerAttentionClientItem] = []
            for client in clients {
                let activity = activitiesByClientId[client.id] ?? TrainerClientWeeklyActivity.empty
                let statuses = statuses(for: activity)
                guard statuses.isEmpty == false else { continue }

                loadedItems.append(
                    TrainerAttentionClientItem(
                        client: client,
                        statuses: statuses,
                        activity: activity
                    )
                )
            }

            items = loadedItems.sorted {
                if $0.primaryPriority != $1.primaryPriority {
                    return $0.primaryPriority < $1.primaryPriority
                }
                let lhs = $0.activity.lastActivityAt ?? .distantPast
                let rhs = $1.activity.lastActivityAt ?? .distantPast
                if lhs != rhs {
                    return lhs > rhs
                }
                return $0.client.displayName.localizedCaseInsensitiveCompare($1.client.displayName) == .orderedAscending
            }
            isLoading = false
        } catch {
            errorMessage = AppErrorPresenter.message(for: error)
            isLoading = false
        }
    }

    private func loadAssignedClients() async throws -> [AppUserProfile] {
        let linksSnapshot = try await firestore
            .collection("trainer_client_links")
            .whereField("trainerId", isEqualTo: trainerId)
            .whereField("status", isEqualTo: "active")
            .getDocuments()

        let links = linksSnapshot.documents.compactMap { document in
            TrainerClientLink(id: document.documentID, data: document.data())
        }

        // New links include a small client snapshot, so a trainer with hundreds
        // of clients needs just this one links query. Older links stay readable
        // through the per-document fallback below.
        var clientsByID = Dictionary(
            uniqueKeysWithValues: links.compactMap { link in
                link.clientProfileSnapshot.map { (link.clientId, $0) }
            }
        )
        let legacyClientIDs = Set(links.map(\.clientId)).subtracting(Set(clientsByID.keys))

        for clientId in legacyClientIDs {
            let snapshot = try await firestore
                .collection("users")
                .document(clientId)
                .getDocument()

            guard let data = snapshot.data(),
                  let profile = AppUserProfile(id: snapshot.documentID, data: data) else {
                continue
            }
            clientsByID[clientId] = profile
        }

        return clientsByID.values.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private func loadWeeklyActivities(clientIds: Set<String>) async throws -> [String: TrainerClientWeeklyActivity] {
        guard clientIds.isEmpty == false else { return [:] }

        let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        async let checkInsSnapshot = firestore
            .collection("progress_checkins")
            .whereField("trainerId", isEqualTo: trainerId)
            .getDocuments()

        async let notesSnapshot = firestore
            .collection("coaching_notes")
            .whereField("trainerId", isEqualTo: trainerId)
            .getDocuments()

        async let workoutReportsSnapshot = firestore
            .collection("coaching_workout_reports")
            .whereField("trainerId", isEqualTo: trainerId)
            .getDocuments()

        async let nutritionReportsSnapshot = firestore
            .collection("coaching_nutrition_reports")
            .whereField("trainerId", isEqualTo: trainerId)
            .getDocuments()

        async let assignmentsSnapshot = firestore
            .collection("workout_assignments")
            .whereField("trainerId", isEqualTo: trainerId)
            .getDocuments()

        let (checkInDocs, noteDocs, workoutReportDocs, nutritionReportDocs, assignmentDocs) = try await (
            checkInsSnapshot,
            notesSnapshot,
            workoutReportsSnapshot,
            nutritionReportsSnapshot,
            assignmentsSnapshot
        )

        let checkIns = checkInDocs.documents
            .compactMap { ProgressCheckIn(id: $0.documentID, data: $0.data()) }
            .filter { clientIds.contains($0.clientId) && $0.createdAt >= weekStart }

        let notes = noteDocs.documents
            .compactMap { CoachingNote(id: $0.documentID, data: $0.data()) }
            .filter { clientIds.contains($0.clientId) }
            .sorted { $0.createdAt > $1.createdAt }

        let workoutReports = workoutReportDocs.documents
            .compactMap { CoachingWorkoutReport(id: $0.documentID, data: $0.data()) }
            .filter { clientIds.contains($0.clientId) && $0.createdAt >= weekStart }

        let nutritionReports = nutritionReportDocs.documents
            .compactMap { CoachingNutritionReport(id: $0.documentID, data: $0.data()) }
            .filter { clientIds.contains($0.clientId) && ($0.createdAt >= weekStart || $0.dateTo >= weekStart) }

        let assignments = assignmentDocs.documents
            .compactMap { WorkoutAssignment(id: $0.documentID, data: $0.data()) }
            .filter { clientIds.contains($0.clientId) && $0.assignedAt >= weekStart }

        let checkInsByClient = Dictionary(grouping: checkIns, by: \.clientId)
        let notesByClient = Dictionary(grouping: notes, by: \.clientId)
        let workoutReportsByClient = Dictionary(grouping: workoutReports, by: \.clientId)
        let nutritionReportsByClient = Dictionary(grouping: nutritionReports, by: \.clientId)
        let assignmentsByClient = Dictionary(grouping: assignments, by: \.clientId)

        var activities: [String: TrainerClientWeeklyActivity] = [:]
        for clientId in clientIds {
            let clientCheckIns = checkInsByClient[clientId] ?? []
            let clientNotes = notesByClient[clientId] ?? []
            let clientWorkoutReports = workoutReportsByClient[clientId] ?? []
            let clientNutritionReports = nutritionReportsByClient[clientId] ?? []
            let clientAssignments = assignmentsByClient[clientId] ?? []
            let completedAssignments = clientAssignments.filter { $0.status == .completed }
            let openAssignments = clientAssignments.filter { $0.status == .assigned || $0.status == .started }

            let lastActivityAt = [
                clientCheckIns.map(\.createdAt).max(),
                clientNotes.map(\.createdAt).max(),
                clientWorkoutReports.map(\.createdAt).max(),
                clientNutritionReports.map(\.createdAt).max(),
                clientAssignments.map(\.assignedAt).max()
            ]
                .compactMap { $0 }
                .max()

            activities[clientId] = TrainerClientWeeklyActivity(
                checkInsCount: clientCheckIns.count,
                nutritionReportsCount: clientNutritionReports.count,
                workoutReportsCount: clientWorkoutReports.count,
                assignedWorkoutsCount: clientAssignments.count,
                completedWorkoutsCount: completedAssignments.count,
                openWorkoutAssignmentsCount: openAssignments.count,
                lastActivityAt: lastActivityAt,
                lastNote: clientNotes.first
            )
        }

        return activities
    }

    private func statuses(for activity: TrainerClientWeeklyActivity) -> [TrainerAttentionStatus] {
        var statuses: [TrainerAttentionStatus] = []

        if activity.lastNote?.authorRole == .client {
            statuses.append(.waitingReply)
        }
        if activity.checkInsCount == 0 {
            statuses.append(.noCheckIn)
        }
        if activity.nutritionReportsCount == 0 {
            statuses.append(.noNutrition)
        }
        if activity.openWorkoutAssignmentsCount > 0 {
            statuses.append(.missedWorkouts)
        }

        return statuses.sorted { $0.priority < $1.priority }
    }
}

struct TrainerAttentionScreen: View {
    let trainerId: String

    @StateObject private var store: TrainerAttentionStore
    @State private var selectedFilter: TrainerAttentionStatus?
    @State private var showsAllMessages = false

    init(trainerId: String) {
        self.trainerId = trainerId
        _store = StateObject(wrappedValue: TrainerAttentionStore(trainerId: trainerId))
    }

    private var messageItems: [TrainerAttentionClientItem] {
        store.items
            .filter { $0.statuses.contains(.waitingReply) && $0.activity.lastNote != nil }
            .sorted {
                ($0.activity.lastNote?.createdAt ?? .distantPast) >
                    ($1.activity.lastNote?.createdAt ?? .distantPast)
            }
    }

    private var visibleMessageItems: [TrainerAttentionClientItem] {
        showsAllMessages ? messageItems : Array(messageItems.prefix(3))
    }

    private var queueItems: [TrainerAttentionClientItem] {
        store.items.filter { item in
            item.statuses.contains { $0 != .waitingReply }
        }
    }

    private var filteredQueueItems: [TrainerAttentionClientItem] {
        guard let selectedFilter else { return queueItems }
        return queueItems.filter { $0.statuses.contains(selectedFilter) }
    }

    var body: some View {
        List {
            if let errorMessage = store.errorMessage, errorMessage.isEmpty == false {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            if messageItems.isEmpty == false {
                Section {
                    ForEach(visibleMessageItems) { item in
                        NavigationLink {
                            TrainerClientSupportScreen(
                                trainerId: trainerId,
                                client: item.client,
                                opensChatInitially: true
                            )
                        } label: {
                            TrainerAttentionMessageRow(item: item)
                        }
                    }

                    if messageItems.count > 3 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showsAllMessages.toggle()
                            }
                        } label: {
                            Label(
                                showsAllMessages
                                    ? AppLocalizer.string("trainer.attention.messages.collapse")
                                    : AppLocalizer.format("trainer.attention.messages.show_all", messageItems.count),
                                systemImage: showsAllMessages ? "chevron.up" : "chevron.down"
                            )
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    }
                } header: {
                    HStack {
                        Text(AppLocalizer.string("trainer.attention.messages.title"))
                        Spacer()
                        Text(messageItems.count.formatted())
                            .foregroundStyle(.blue)
                    }
                }
            }

            if queueItems.isEmpty == false {
                Section {
                    TrainerAttentionFilterBar(selection: $selectedFilter)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                Section(AppLocalizer.string("trainer.attention.queue.title")) {
                    if filteredQueueItems.isEmpty {
                        Label(
                            AppLocalizer.string("trainer.attention.queue.empty"),
                            systemImage: "checkmark.circle"
                        )
                        .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredQueueItems) { item in
                            NavigationLink {
                                TrainerClientSupportScreen(trainerId: trainerId, client: item.client)
                            } label: {
                                TrainerAttentionClientRow(
                                    item: item,
                                    statuses: item.statuses.filter { $0 != .waitingReply }
                                )
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if store.isLoading && store.items.isEmpty {
                ProgressView()
            } else if store.items.isEmpty && store.errorMessage == nil {
                ContentUnavailableView(
                    AppLocalizer.string("trainer.attention.empty.title"),
                    systemImage: "checkmark.seal",
                    description: Text(AppLocalizer.string("trainer.attention.empty.subtitle"))
                )
            }
        }
        .navigationTitle(AppLocalizer.string("trainer.attention.title"))
        .onAppear {
            Task {
                await store.load()
            }
        }
        .refreshable {
            await store.load()
        }
    }
}

private struct TrainerAttentionMessageRow: View {
    let item: TrainerAttentionClientItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            TrainerAttentionAvatar(profile: item.client, size: 48)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(item.client.displayName)
                        .font(.headline)
                        .lineLimit(1)

                    Circle()
                        .fill(.blue)
                        .frame(width: 8, height: 8)

                    Spacer(minLength: 8)

                    if let createdAt = item.activity.lastNote?.createdAt {
                        Text(messageDate(createdAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let message = item.activity.lastNote?.message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Label(AppLocalizer.string("trainer.attention.messages.reply"), systemImage: "arrowshape.turn.up.left.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 5)
    }

    private func messageDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct TrainerAttentionFilterBar: View {
    @Binding var selection: TrainerAttentionStatus?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                TrainerAttentionFilterChip(
                    title: AppLocalizer.string("trainer.attention.filter.all"),
                    tint: .blue,
                    isSelected: selection == nil,
                    action: { selection = nil }
                )

                ForEach(TrainerAttentionStatus.allCases.filter { $0 != .waitingReply }) { status in
                    TrainerAttentionFilterChip(
                        title: status.title,
                        tint: status.tint,
                        isSelected: selection == status,
                        action: { selection = status }
                    )
                }
            }
        }
    }
}

private struct TrainerAttentionFilterChip: View {
    let title: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color(.systemBackground) : tint)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(isSelected ? tint : tint.opacity(0.14)))
        }
        .buttonStyle(.plain)
    }
}

private struct TrainerAttentionClientRow: View {
    let item: TrainerAttentionClientItem
    let statuses: [TrainerAttentionStatus]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                TrainerAttentionAvatar(profile: item.client, size: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.client.displayName)
                        .font(.headline)
                    Text(weeklySummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            FlowLayout(spacing: 6) {
                ForEach(statuses) { status in
                    Label(status.title, systemImage: status.iconName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(status.tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(status.tint.opacity(0.14)))
                }
            }

            if let lastActivityAt = item.activity.lastActivityAt {
                Text(AppLocalizer.format("trainer.attention.last_activity", lastActivityAt.formatted(date: .abbreviated, time: .shortened)))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
    }

    private var weeklySummary: String {
        AppLocalizer.format(
            "trainer.attention.weekly.summary",
            item.activity.checkInsCount,
            item.activity.nutritionReportsCount,
            item.activity.completedWorkoutsCount,
            item.activity.assignedWorkoutsCount
        )
    }
}

private struct TrainerAttentionAvatar: View {
    let profile: AppUserProfile
    let size: CGFloat

    var body: some View {
        Group {
            if let photoURL = profile.photoURL,
               let url = URL(string: photoURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var fallback: some View {
        Circle()
            .fill(Color.blue.opacity(0.14))
            .overlay {
                Text(String(profile.displayName.prefix(1)).uppercased())
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(.blue)
            }
    }
}

private struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    init(spacing: CGFloat, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: spacing) {
                content
            }
            VStack(alignment: .leading, spacing: spacing) {
                content
            }
        }
    }
}
