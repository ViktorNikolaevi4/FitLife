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
            return .red
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

        let clientIds = linksSnapshot.documents.compactMap { document in
            TrainerClientLink(id: document.documentID, data: document.data())?.clientId
        }

        var clients: [AppUserProfile] = []
        for chunk in clientIds.chunked(into: 30) {
            let snapshot = try await firestore
                .collection("users")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()

            for document in snapshot.documents {
                guard let profile = AppUserProfile(id: document.documentID, data: document.data()) else {
                    continue
                }
                clients.append(profile)
            }
        }

        return clients.sorted {
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

    init(trainerId: String) {
        self.trainerId = trainerId
        _store = StateObject(wrappedValue: TrainerAttentionStore(trainerId: trainerId))
    }

    private var filteredItems: [TrainerAttentionClientItem] {
        guard let selectedFilter else { return store.items }
        return store.items.filter { $0.statuses.contains(selectedFilter) }
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

            Section {
                TrainerAttentionSummaryCard(
                    attentionCount: store.items.count,
                    clientCount: store.allClientCount
                )
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            if store.items.isEmpty == false {
                Section {
                    TrainerAttentionFilterBar(selection: $selectedFilter)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }

            Section(AppLocalizer.string("trainer.attention.section")) {
                ForEach(filteredItems) { item in
                    NavigationLink {
                        TrainerClientSupportScreen(trainerId: trainerId, client: item.client)
                    } label: {
                        TrainerAttentionClientRow(item: item)
                    }
                }
            }
        }
        .overlay {
            if store.isLoading {
                ProgressView()
            } else if store.items.isEmpty {
                ContentUnavailableView(
                    AppLocalizer.string("trainer.attention.empty.title"),
                    systemImage: "checkmark.seal",
                    description: Text(AppLocalizer.string("trainer.attention.empty.subtitle"))
                )
            } else if filteredItems.isEmpty {
                ContentUnavailableView(
                    AppLocalizer.string("trainer.attention.filter.empty.title"),
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text(AppLocalizer.string("trainer.attention.filter.empty.subtitle"))
                )
            }
        }
        .navigationTitle(AppLocalizer.string("trainer.attention.title"))
        .task {
            await store.load()
        }
        .refreshable {
            await store.load()
        }
    }
}

private struct TrainerAttentionSummaryCard: View {
    let attentionCount: Int
    let clientCount: Int

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.orange.opacity(0.16))
                Image(systemName: "exclamationmark.bubble.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.orange)
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 4) {
                Text(AppLocalizer.format("trainer.attention.summary.title", attentionCount))
                    .font(.headline.weight(.semibold))
                Text(AppLocalizer.format("trainer.attention.summary.subtitle", clientCount))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemGroupedBackground)))
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

                ForEach(TrainerAttentionStatus.allCases) { status in
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(Color.blue.opacity(0.14))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.blue)
                    }

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
                ForEach(item.statuses) { status in
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

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
