import SwiftUI

struct TrainerAssignmentsOverviewScreen: View {
    let trainerId: String

    @StateObject private var store: TrainerAssignmentsOverviewStore
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue

    init(trainerId: String) {
        self.trainerId = trainerId
        _store = StateObject(wrappedValue: TrainerAssignmentsOverviewStore(trainerId: trainerId))
    }

    private var appLanguage: AppLanguage {
        AppLanguage.from(rawValue: appLanguageRaw)
    }

    private var clientsNeedingAssignment: [TrainerAssignmentClientSummary] {
        store.clientSummaries.filter(\.needsAssignment)
    }

    private var clientsWithActiveAssignment: [TrainerAssignmentClientSummary] {
        store.clientSummaries.filter { $0.isActiveClient && $0.needsAssignment == false }
    }

    private var archivedClients: [TrainerAssignmentClientSummary] {
        store.clientSummaries.filter { $0.isActiveClient == false }
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

            if clientsNeedingAssignment.isEmpty == false {
                Section(appLanguage.localized("trainer.overview.clients.needs_assignment.section")) {
                    ForEach(clientsNeedingAssignment) { summary in
                        NavigationLink {
                            TrainerClientAssignmentsScreen(summary: summary)
                        } label: {
                            TrainerAssignmentClientRow(summary: summary)
                        }
                    }
                }
            }

            if clientsWithActiveAssignment.isEmpty == false {
                Section(appLanguage.localized("trainer.overview.clients.active.section")) {
                    ForEach(clientsWithActiveAssignment) { summary in
                        NavigationLink {
                            TrainerClientAssignmentsScreen(summary: summary)
                        } label: {
                            TrainerAssignmentClientRow(summary: summary)
                        }
                    }
                }
            }

            if archivedClients.isEmpty == false {
                Section(appLanguage.localized("trainer.overview.clients.archive.section")) {
                    ForEach(archivedClients) { summary in
                        NavigationLink {
                            TrainerClientAssignmentsScreen(summary: summary)
                        } label: {
                            TrainerAssignmentClientRow(summary: summary)
                        }
                    }
                }
            }
        }
        .overlay {
            if store.isLoading {
                ProgressView()
            } else if store.clientSummaries.isEmpty {
                ContentUnavailableView(
                    appLanguage.localized("trainer.overview.clients.empty.title"),
                    systemImage: "person.2",
                    description: Text(appLanguage.localized("trainer.overview.clients.empty.subtitle"))
                )
            }
        }
        .navigationTitle(appLanguage.localized("trainer.overview.title"))
        .task {
            await store.load()
        }
        .refreshable {
            await store.load()
        }
    }
}

private struct TrainerAssignmentClientRow: View {
    let summary: TrainerAssignmentClientSummary

    private var initial: String {
        String(summary.displayName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased()
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.accentColor.opacity(0.14))
                .frame(width: 46, height: 46)
                .overlay {
                    Text(initial.isEmpty ? "?" : initial)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(summary.displayName)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    if summary.needsAssignment {
                        Text(AppLocalizer.string("trainer.overview.client.needs_assignment"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.orange.opacity(0.14), in: Capsule())
                    }
                }

                Text(
                    AppLocalizer.format(
                        "trainer.overview.client.summary",
                        summary.assignments.count,
                        summary.activeAssignmentCount
                    )
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if let latestAssignment = summary.assignments.first {
                    Text(
                        AppLocalizer.format(
                            "trainer.overview.client.latest",
                            latestAssignment.titleSnapshot
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct TrainerClientAssignmentsScreen: View {
    let summary: TrainerAssignmentClientSummary

    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage.from(rawValue: appLanguageRaw)
    }

    var body: some View {
        List {
            if summary.assignments.isEmpty {
                ContentUnavailableView(
                    appLanguage.localized("trainer.overview.client.empty.title"),
                    systemImage: "list.bullet.clipboard",
                    description: Text(appLanguage.localized("trainer.overview.client.empty.subtitle"))
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(WorkoutAssignmentStatus.allCases, id: \.rawValue) { status in
                    let assignments = summary.assignments.filter { $0.status == status }
                    if assignments.isEmpty == false {
                        Section(AppLocalizer.string(status.localizationKey)) {
                            ForEach(assignments) { assignment in
                                NavigationLink {
                                    TrainerAssignmentDetailScreen(assignment: assignment)
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(assignment.titleSnapshot)
                                            .font(.headline)

                                        Text(
                                            AppLocalizer.format(
                                                "trainer.overview.exercise_count",
                                                assignment.exerciseCount
                                            )
                                        )
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                        Text(assignment.assignedAt.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(summary.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TrainerAssignmentDetailScreen: View {
    let assignment: WorkoutAssignment

    @StateObject private var store: ClientAssignmentDetailStore
    @State private var editableTemplate: WorkoutTemplate?

    init(assignment: WorkoutAssignment) {
        self.assignment = assignment
        _store = StateObject(wrappedValue: ClientAssignmentDetailStore(assignment: assignment))
    }

    private var sortedBlocks: [WorkoutTemplateBlockItem] {
        store.blocks.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var ungroupedExercises: [WorkoutTemplateExerciseItem] {
        store.exercises
            .filter { $0.blockId == nil }
            .sorted { $0.orderIndex < $1.orderIndex }
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

            Section(AppLocalizer.string("trainer.assignment.detail.info")) {
                LabeledContent(
                    AppLocalizer.string("trainer.assignment.detail.status"),
                    value: AppLocalizer.string(assignment.status.localizationKey)
                )
                LabeledContent(
                    AppLocalizer.string("trainer.assignment.detail.assigned_at"),
                    value: assignment.assignedAt.formatted(date: .abbreviated, time: .omitted)
                )
                if assignment.notesSnapshot.isEmpty == false {
                    Text(assignment.notesSnapshot)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(sortedBlocks) { block in
                Section {
                    ForEach(exercises(in: block)) { exercise in
                        TrainerAssignmentExerciseRow(exercise: exercise, block: block)
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(block.displayTitle)
                        Text(block.subtitle(exerciseCount: exercises(in: block).count))
                            .font(.caption)
                            .textCase(nil)
                    }
                }
            }

            if ungroupedExercises.isEmpty == false {
                Section(AppLocalizer.string("client.assignment.detail.exercises")) {
                    ForEach(ungroupedExercises) { exercise in
                        TrainerAssignmentExerciseRow(exercise: exercise, block: nil)
                    }
                }
            }
        }
        .navigationTitle(assignment.titleSnapshot)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $editableTemplate) { template in
            WorkoutTemplateEditorScreen(template: template)
        }
        .safeAreaInset(edge: .bottom) {
            createCopyBar
        }
        .overlay {
            if store.isLoading {
                ProgressView()
            } else if store.exercises.isEmpty {
                ContentUnavailableView(
                    AppLocalizer.string("client.assignment.detail.empty.title"),
                    systemImage: "list.bullet.clipboard",
                    description: Text(AppLocalizer.string("client.assignment.detail.empty.subtitle"))
                )
            }
        }
        .task { await store.load() }
        .refreshable { await store.load() }
    }

    private var createCopyBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                Task {
                    editableTemplate = await store.createEditableTemplateCopy()
                }
            } label: {
                HStack(spacing: 10) {
                    if store.isCreatingEditableCopy {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "doc.on.doc.fill")
                    }
                    Text(AppLocalizer.string("trainer.assignment.reuse.action"))
                }
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isLoading || store.exercises.isEmpty || store.isCreatingEditableCopy)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
    }

    private func exercises(in block: WorkoutTemplateBlockItem) -> [WorkoutTemplateExerciseItem] {
        store.exercises
            .filter { $0.blockId == block.id }
            .sorted { $0.orderIndex < $1.orderIndex }
    }
}

private struct TrainerAssignmentExerciseRow: View {
    let exercise: WorkoutTemplateExerciseItem
    let block: WorkoutTemplateBlockItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(exercise.name)
                .font(.headline)

            HStack(spacing: 8) {
                Text(setSummary)
                if let groupTitle {
                    Text("•")
                    Text(groupTitle)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if exercise.note.isEmpty == false {
                Text(exercise.note)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var groupTitle: String? {
        guard let groupID = exercise.groupId else { return nil }
        return block?.groups.first { $0.id == groupID }?.title
    }

    private var setSummary: String {
        guard let firstSet = exercise.sets.first else { return "—" }
        if firstSet.metricType == .duration {
            return AppLocalizer.format(
                "trainer.assignment.detail.duration",
                exercise.sets.count,
                firstSet.durationSeconds
            )
        }
        return AppLocalizer.format(
            "trainer.assignment.detail.reps",
            exercise.sets.count,
            firstSet.reps
        )
    }
}
