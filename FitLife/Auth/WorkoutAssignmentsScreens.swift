import SwiftUI
import SwiftData

private let assignmentDetailCardBackground = Color(.secondarySystemBackground)
private let assignmentDetailInsetBackground = Color(.tertiarySystemBackground)
private let assignmentDetailCardBorder = Color(.separator).opacity(0.32)

struct AssignWorkoutTemplateScreen: View {
    let template: WorkoutTemplate
    let exerciseCount: Int

    @StateObject private var store: WorkoutTemplateAssignmentStore
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue

    init(template: WorkoutTemplate, exerciseCount: Int) {
        self.template = template
        self.exerciseCount = exerciseCount
        _store = StateObject(wrappedValue: WorkoutTemplateAssignmentStore(template: template))
    }

    private var appLanguage: AppLanguage {
        AppLanguage.from(rawValue: appLanguageRaw)
    }

    private var visibleClients: [AppUserProfile] {
        guard let clientId = template.clientId else { return store.clients }
        return store.clients.filter { $0.id == clientId }
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

            Section(appLanguage.localized("trainer.assignments.clients.section")) {
                ForEach(visibleClients) { client in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(client.displayName)
                                .font(.headline)
                            Text(client.email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if store.isAssigning(clientId: client.id) {
                            ProgressView()
                                .controlSize(.small)
                                .accessibilityLabel(AppLocalizer.string("trainer.assignments.sending"))
                        } else if store.isAssigned(clientId: client.id) {
                            Label(appLanguage.localized("trainer.assignments.assigned"), systemImage: "checkmark.circle.fill")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.green)
                        } else {
                            Button(AppLocalizer.string("common.add")) {
                                Task {
                                    _ = await store.assignTemplate(to: client, exerciseCount: exerciseCount)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(store.isAssigning(clientId: client.id))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .overlay {
            if store.isLoading {
                ProgressView()
            } else if visibleClients.isEmpty {
                ContentUnavailableView(
                    appLanguage.localized("trainer.assignments.clients.empty.title"),
                    systemImage: "person.2.badge.plus",
                    description: Text(appLanguage.localized("trainer.assignments.clients.empty.subtitle"))
                )
            }
        }
        .navigationTitle(appLanguage.localized("trainer.assignments.title"))
        .task {
            await store.load()
        }
        .refreshable {
            await store.load()
        }
    }
}

private enum ClientAssignmentFilter: String, CaseIterable, Identifiable {
    case all
    case assigned
    case started
    case completed
    case skipped

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .all: return "client.assignments.filter.all"
        case .assigned: return WorkoutAssignmentStatus.assigned.localizationKey
        case .started: return WorkoutAssignmentStatus.started.localizationKey
        case .completed: return WorkoutAssignmentStatus.completed.localizationKey
        case .skipped: return WorkoutAssignmentStatus.skipped.localizationKey
        }
    }

    var status: WorkoutAssignmentStatus? {
        WorkoutAssignmentStatus(rawValue: rawValue)
    }
}

struct ClientAssignedWorkoutsScreen: View {
    @Environment(\.modelContext) private var modelContext

    let clientId: String
    let onWorkoutFlowCompleted: (() -> Void)?

    @StateObject private var store: ClientAssignedWorkoutsStore
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue
    @State private var searchText = ""
    @State private var selectedFilter = ClientAssignmentFilter.all
    @State private var showsHistory = false

    init(clientId: String, onWorkoutFlowCompleted: (() -> Void)? = nil) {
        self.clientId = clientId
        self.onWorkoutFlowCompleted = onWorkoutFlowCompleted
        _store = StateObject(wrappedValue: ClientAssignedWorkoutsStore(clientId: clientId))
    }

    private var appLanguage: AppLanguage {
        AppLanguage.from(rawValue: appLanguageRaw)
    }

    private var visibleActiveAssignments: [WorkoutAssignment] {
        filtered(store.activeAssignments)
    }

    private var visibleHistoryAssignments: [WorkoutAssignment] {
        filtered(store.historyAssignments)
    }

    private var filterAllowsActive: Bool {
        selectedFilter == .all || selectedFilter == .assigned || selectedFilter == .started
    }

    private var filterAllowsHistory: Bool {
        selectedFilter == .all || selectedFilter == .completed || selectedFilter == .skipped
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
                Picker(
                    appLanguage.localized("client.assignments.filter.title"),
                    selection: $selectedFilter
                ) {
                    ForEach(ClientAssignmentFilter.allCases) { filter in
                        Text(AppLocalizer.string(filter.localizationKey)).tag(filter)
                    }
                }
                .pickerStyle(.menu)
            }

            if filterAllowsActive,
               visibleActiveAssignments.isEmpty == false || store.hasMoreActive {
                Section(appLanguage.localized("client.assignments.current")) {
                    ForEach(visibleActiveAssignments) { assignment in
                        assignmentLink(assignment)
                    }

                    if store.hasMoreActive {
                        loadMoreButton(isLoading: store.isLoadingMoreActive) {
                            await store.loadMoreActive()
                        }
                    }
                }
            }

            if filterAllowsHistory,
               visibleHistoryAssignments.isEmpty == false || store.hasMoreHistory {
                Section {
                    DisclosureGroup(isExpanded: $showsHistory) {
                        ForEach(visibleHistoryAssignments) { assignment in
                            assignmentLink(assignment)
                        }

                        if store.hasMoreHistory {
                            loadMoreButton(isLoading: store.isLoadingMoreHistory) {
                                await store.loadMoreHistory()
                            }
                        }
                    } label: {
                        Label(
                            AppLocalizer.format(
                                "client.assignments.history.loaded",
                                visibleHistoryAssignments.count
                            ),
                            systemImage: "clock.arrow.circlepath"
                        )
                    }
                }
            }

            if store.isLoading == false,
               visibleActiveAssignments.isEmpty,
               visibleHistoryAssignments.isEmpty,
               store.hasMoreActive == false,
               store.hasMoreHistory == false,
               searchText.isEmpty == false {
                ContentUnavailableView.search(text: searchText)
                    .listRowBackground(Color.clear)
            }
        }
        .overlay {
            if store.isLoading {
                ProgressView()
            } else if store.activeAssignments.isEmpty && store.historyAssignments.isEmpty
                        && store.hasMoreActive == false && store.hasMoreHistory == false
                        && searchText.isEmpty {
                ContentUnavailableView(
                    appLanguage.localized("client.assignments.empty.title"),
                    systemImage: "list.bullet.clipboard",
                    description: Text(appLanguage.localized("client.assignments.empty.subtitle"))
                )
            }
        }
        .navigationTitle(appLanguage.localized("client.assignments.title"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: appLanguage.localized("client.assignments.search")
        )
        .onChange(of: searchText) { _, newValue in
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                showsHistory = true
            }
        }
        .onChange(of: selectedFilter) { _, newValue in
            if newValue == .completed || newValue == .skipped {
                showsHistory = true
            }
        }
        .task {
            await store.load(modelContext: modelContext)
        }
        .refreshable {
            await store.load(modelContext: modelContext)
        }
    }

    private func filtered(_ assignments: [WorkoutAssignment]) -> [WorkoutAssignment] {
        let statusFiltered: [WorkoutAssignment]
        if let status = selectedFilter.status {
            statusFiltered = assignments.filter { $0.status == status }
        } else {
            statusFiltered = assignments
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return statusFiltered }
        return statusFiltered.filter {
            $0.titleSnapshot.localizedCaseInsensitiveContains(query)
                || $0.notesSnapshot.localizedCaseInsensitiveContains(query)
                || (store.trainerName(for: $0.trainerId)?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private func assignmentLink(_ assignment: WorkoutAssignment) -> some View {
        NavigationLink {
            ClientAssignmentDetailScreen(
                assignment: assignment,
                trainerName: store.trainerName(for: assignment.trainerId),
                onWorkoutFlowCompleted: onWorkoutFlowCompleted
            )
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(assignment.titleSnapshot)
                    .font(.headline)

                if assignment.notesSnapshot.isEmpty == false {
                    Text(assignment.notesSnapshot)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    if let trainerName = store.trainerName(for: assignment.trainerId) {
                        Text(AppLocalizer.format("client.assignments.trainer", trainerName))
                    }

                    Text(
                        AppLocalizer.format(
                            "client.assignments.exercise_count",
                            assignment.exerciseCount
                        )
                    )

                    Spacer(minLength: 4)

                    Text(AppLocalizer.string(assignment.status.localizationKey))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(assignmentStatusColor(assignment.status))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(assignmentStatusColor(assignment.status).opacity(0.14))
                        )
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(assignment.assignedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
    }

    private func loadMoreButton(
        isLoading: Bool,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task { await action() }
        } label: {
            HStack {
                Spacer()
                if isLoading {
                    ProgressView()
                } else {
                    Text(AppLocalizer.string("trainer.assignment_history.load_more"))
                }
                Spacer()
            }
        }
        .disabled(isLoading)
    }

    private func assignmentStatusColor(_ status: WorkoutAssignmentStatus) -> Color {
        switch status {
        case .assigned: return .blue
        case .started: return .orange
        case .completed: return .green
        case .skipped: return .secondary
        }
    }
}

struct ClientAssignmentDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var sessionStore: AppSessionStore

    let assignment: WorkoutAssignment
    let trainerName: String?
    let onWorkoutFlowCompleted: (() -> Void)?

    @Query private var workouts: [WorkoutSession]
    @StateObject private var store: ClientAssignmentDetailStore
    @State private var selectedWorkout: WorkoutSession?
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue
    @AppStorage(Gender.appStorageKey) private var activeGenderRaw: String = Gender.male.rawValue

    init(
        assignment: WorkoutAssignment,
        trainerName: String?,
        onWorkoutFlowCompleted: (() -> Void)? = nil
    ) {
        self.assignment = assignment
        self.trainerName = trainerName
        self.onWorkoutFlowCompleted = onWorkoutFlowCompleted
        _store = StateObject(wrappedValue: ClientAssignmentDetailStore(assignment: assignment))
    }

    private var appLanguage: AppLanguage {
        AppLanguage.from(rawValue: appLanguageRaw)
    }

    private var selectedGender: Gender {
        Gender(rawValue: activeGenderRaw) ?? .male
    }

    private var activeWorkout: WorkoutSession? {
        workouts
            .filter {
                $0.remoteAssignmentId == assignment.id &&
                $0.endedAt == nil &&
                $0.ownerId == sessionStore.firebaseUser?.uid
            }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    private var assignmentBlockGroups: [WorkoutAssignmentBlockGroup] {
        var groups = store.blocks
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { block in
                let exercises = store.exercises
                    .filter { $0.blockId == block.id }
                    .sorted { $0.orderIndex < $1.orderIndex }
                let nestedGroups = block.groups
                    .sorted { $0.orderIndex < $1.orderIndex }
                    .map { nested in
                        WorkoutAssignmentNestedGroup(
                            item: nested,
                            exercises: exercises.filter { $0.groupId == nested.id }
                        )
                    }
                return WorkoutAssignmentBlockGroup(
                    id: block.id,
                    title: block.displayTitle,
                    subtitle: block.subtitle(exerciseCount: exercises.count),
                    exercises: exercises.filter { $0.groupId == nil },
                    nestedGroups: nestedGroups
                )
            }

        let groupedIds = Set(groups.flatMap { $0.exercises.map(\.id) })
        let legacyExercises = store.exercises
            .filter { groupedIds.contains($0.id) == false }
            .sorted { $0.orderIndex < $1.orderIndex }
        if legacyExercises.isEmpty == false {
            groups.insert(
                WorkoutAssignmentBlockGroup(
                    id: "legacy-strength",
                    title: AppLocalizer.string("workout.block.strength.title"),
                    subtitle: AppLocalizer.format("workout.block.exercise_count", legacyExercises.count),
                    exercises: legacyExercises,
                    nestedGroups: []
                ),
                at: 0
            )
        }

        return groups
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
                ForEach(assignmentBlockGroups) { group in
                    WorkoutAssignmentBlockHeader(title: group.title, subtitle: group.subtitle)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 2, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    ForEach(Array(group.exercises.enumerated()), id: \.element.id) { index, exercise in
                        ClientAssignmentExerciseCard(
                            exercise: exercise,
                            displayIndex: index + 1
                        )
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }

                    ForEach(group.nestedGroups) { nestedGroup in
                        WorkoutAssignmentNestedGroupHeader(group: nestedGroup.item)
                            .listRowInsets(EdgeInsets(top: 12, leading: 24, bottom: 2, trailing: 24))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)

                        ForEach(Array(nestedGroup.exercises.enumerated()), id: \.element.id) { index, exercise in
                            ClientAssignmentExerciseCard(
                                exercise: exercise,
                                displayIndex: index + 1
                            )
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                }
            } header: {
                Text(appLanguage.localized("client.assignment.detail.exercises"))
                    .font(.footnote.weight(.semibold))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(assignment.titleSnapshot)
        .navigationDestination(item: $selectedWorkout) { workout in
            ActiveWorkoutScreen(
                workout: workout,
                onWorkoutFlowCompleted: {
                    if let onWorkoutFlowCompleted {
                        onWorkoutFlowCompleted()
                    } else {
                        selectedWorkout = nil
                        DispatchQueue.main.async {
                            dismiss()
                        }
                    }
                }
            )
        }
        .safeAreaInset(edge: .bottom) {
            startAssignmentBar
        }
        .overlay {
            if store.isLoading {
                ProgressView()
            } else if store.exercises.isEmpty {
                ContentUnavailableView(
                    appLanguage.localized("client.assignment.detail.empty.title"),
                    systemImage: "list.bullet.clipboard",
                    description: Text(appLanguage.localized("client.assignment.detail.empty.subtitle"))
                )
            }
        }
        .task {
            await store.load()
        }
        .refreshable {
            await store.load()
        }
    }

    private var startAssignmentBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                Task {
                    let workout = await ClientAssignedWorkoutsStore(clientId: assignment.clientId).startAssignment(
                        assignment,
                        gender: selectedGender,
                        modelContext: modelContext
                    )
                    if let workout {
                        selectedWorkout = workout
                    }
                }
            } label: {
                Text(activeWorkout == nil ? AppLocalizer.string("client.assignments.start") : AppLocalizer.string("client.assignments.resume"))
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isLoading || store.exercises.isEmpty)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
    }
}

private struct WorkoutAssignmentBlockGroup: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let exercises: [WorkoutTemplateExerciseItem]
    let nestedGroups: [WorkoutAssignmentNestedGroup]
}

private struct WorkoutAssignmentNestedGroup: Identifiable {
    let item: WorkoutTemplateBlockGroupItem
    let exercises: [WorkoutTemplateExerciseItem]
    var id: String { item.id }
}

private struct WorkoutAssignmentNestedGroupHeader: View {
    let group: WorkoutTemplateBlockGroupItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: group.kind == .superset ? "link" : "arrow.triangle.branch")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(group.title).font(.subheadline.weight(.semibold))
                Text(description).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.10)))
    }

    private var description: String {
        var parts = [group.kind.title]
        if group.rounds > 1 { parts.append("\(group.rounds) круг(а)") }
        if group.restSeconds > 0 { parts.append("отдых \(group.restSeconds) сек") }
        return parts.joined(separator: " · ")
    }
}

private struct WorkoutAssignmentBlockHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.blue.opacity(0.14))

                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.blue)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

private struct ClientAssignmentExerciseCard: View {
    let exercise: WorkoutTemplateExerciseItem
    let displayIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(workoutAccentColor(exercise.accentName).opacity(0.16))

                    workoutIconImage(
                        named: exercise.systemImage,
                        accentName: exercise.accentName,
                        size: 18
                    )
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(AppLocalizer.format("client.assignment.detail.set_count", exercise.sets.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Text(String(format: "%02d", displayIndex))
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(assignmentDetailInsetBackground, in: Capsule())
            }

            VStack(spacing: 8) {
                ForEach(Array(exercise.sets.enumerated()), id: \.offset) { index, set in
                    ClientAssignmentSetRow(index: index + 1, set: set)
                }
            }

            if exercise.note.isEmpty == false {
                Label(exercise.note, systemImage: "text.bubble")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(assignmentDetailInsetBackground, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 22).fill(assignmentDetailCardBackground))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(assignmentDetailCardBorder))
    }
}

private struct ClientAssignmentSetRow: View {
    let index: Int
    let set: WorkoutDraftSet

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(Color(.systemBackground), in: Circle())

            HStack(spacing: 8) {
                Text("\(formattedWorkoutWeight(set.weight)) kg")
                    .font(.body.weight(.semibold).monospacedDigit())

                Text("x")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(
                    formattedWorkoutMetricValue(
                        reps: set.reps,
                        durationSeconds: set.durationSeconds,
                        metricType: set.metricType
                    )
                )
                .font(.body.weight(.semibold).monospacedDigit())
            }
            .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(assignmentDetailInsetBackground, in: RoundedRectangle(cornerRadius: 16))
    }
}
