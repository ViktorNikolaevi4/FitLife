import SwiftUI

struct TrainerAssignmentsOverviewScreen: View {
    let trainerId: String

    @StateObject private var store: TrainerAssignmentsOverviewStore
    @State private var searchText = ""
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue

    init(trainerId: String) {
        self.trainerId = trainerId
        _store = StateObject(wrappedValue: TrainerAssignmentsOverviewStore(trainerId: trainerId))
    }

    private var appLanguage: AppLanguage {
        AppLanguage.from(rawValue: appLanguageRaw)
    }

    private var clientsNeedingAssignment: [TrainerAssignmentClientSummary] {
        filteredClientSummaries.filter(\.needsAssignment)
    }

    private var clientsWithActiveAssignment: [TrainerAssignmentClientSummary] {
        filteredClientSummaries.filter { $0.isActiveClient && $0.needsAssignment == false }
    }

    private var archivedClients: [TrainerAssignmentClientSummary] {
        filteredClientSummaries.filter { $0.isActiveClient == false }
    }

    private var filteredClientSummaries: [TrainerAssignmentClientSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return store.clientSummaries }
        return store.clientSummaries.filter {
            $0.displayName.localizedCaseInsensitiveContains(query)
                || $0.email.localizedCaseInsensitiveContains(query)
        }
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
                            TrainerClientAssignmentsScreen(summary: summary, trainerId: trainerId)
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
                            TrainerClientAssignmentsScreen(summary: summary, trainerId: trainerId)
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
                            TrainerClientAssignmentsScreen(summary: summary, trainerId: trainerId)
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
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: appLanguage.localized("trainer.overview.search")
        )
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
                        "trainer.overview.client.active_summary",
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
    let trainerId: String

    @StateObject private var draftsStore: TrainerClientWorkoutDraftsStore
    @StateObject private var historyStore: TrainerClientAssignmentHistoryStore
    @State private var showCreateDraft = false
    @State private var pendingDeleteDraft: WorkoutTemplate?
    @State private var showsHistory = false
    @State private var searchText = ""
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue

    init(summary: TrainerAssignmentClientSummary, trainerId: String) {
        self.summary = summary
        self.trainerId = trainerId
        _draftsStore = StateObject(
            wrappedValue: TrainerClientWorkoutDraftsStore(
                trainerId: trainerId,
                clientId: summary.id
            )
        )
        _historyStore = StateObject(
            wrappedValue: TrainerClientAssignmentHistoryStore(
                trainerId: trainerId,
                clientId: summary.id,
                initialAssignments: summary.assignments
            )
        )
    }

    private var appLanguage: AppLanguage {
        AppLanguage.from(rawValue: appLanguageRaw)
    }

    private var filteredAssignments: [WorkoutAssignment] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return historyStore.assignments }
        return historyStore.assignments.filter {
            $0.titleSnapshot.localizedCaseInsensitiveContains(query)
                || $0.notesSnapshot.localizedCaseInsensitiveContains(query)
        }
    }

    private var historyAssignments: [WorkoutAssignment] {
        filteredAssignments.filter { $0.status == .completed || $0.status == .skipped }
    }

    var body: some View {
        List {
            if let errorMessage = draftsStore.errorMessage, errorMessage.isEmpty == false {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            if let errorMessage = historyStore.errorMessage, errorMessage.isEmpty == false {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            if draftsStore.drafts.isEmpty == false {
                Section(appLanguage.localized("trainer.client_drafts.section")) {
                    ForEach(draftsStore.drafts) { draft in
                        NavigationLink {
                            WorkoutTemplateEditorScreen(template: draft)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(draft.title)
                                    .font(.headline)
                                if draft.notes.isEmpty == false {
                                    Text(draft.notes)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Text(draft.updatedAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDeleteDraft = draft
                            } label: {
                                Label(AppLocalizer.string("common.delete"), systemImage: "trash")
                            }
                        }
                    }
                }
            }

            if historyStore.assignments.isEmpty
                && draftsStore.drafts.isEmpty
                && draftsStore.isLoading == false
                && historyStore.isLoading == false {
                ContentUnavailableView(
                    appLanguage.localized("trainer.overview.client.empty.title"),
                    systemImage: "list.bullet.clipboard",
                    description: Text(appLanguage.localized("trainer.overview.client.empty.subtitle"))
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(
                    [WorkoutAssignmentStatus.assigned, .started],
                    id: \.rawValue
                ) { status in
                    let assignments = filteredAssignments.filter { $0.status == status }
                    if assignments.isEmpty == false {
                        Section(AppLocalizer.string(status.localizationKey)) {
                            ForEach(assignments) { assignment in
                                assignmentLink(assignment)
                            }
                        }
                    }
                }

                if historyAssignments.isEmpty == false || historyStore.hasMore {
                    Section {
                        DisclosureGroup(isExpanded: $showsHistory) {
                            ForEach(historyAssignments) { assignment in
                                assignmentLink(assignment)
                            }

                            if historyStore.hasMore {
                                Button {
                                    Task { await historyStore.loadMore() }
                                } label: {
                                    HStack {
                                        Spacer()
                                        if historyStore.isLoadingMore {
                                            ProgressView()
                                        } else {
                                            Text(AppLocalizer.string("trainer.assignment_history.load_more"))
                                        }
                                        Spacer()
                                    }
                                }
                                .disabled(historyStore.isLoadingMore)
                            }
                        } label: {
                            Label(
                                AppLocalizer.format(
                                    "trainer.assignment_history.loaded",
                                    historyAssignments.count
                                ),
                                systemImage: "clock.arrow.circlepath"
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle(summary.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: appLanguage.localized("trainer.assignment_history.search")
        )
        .onChange(of: searchText) { _, newValue in
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                showsHistory = true
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateDraft = true
                } label: {
                    Label(appLanguage.localized("trainer.client_drafts.create"), systemImage: "plus")
                }
            }
        }
        .overlay {
            if (draftsStore.isLoading && draftsStore.drafts.isEmpty)
                || (historyStore.isLoading && historyStore.assignments.isEmpty) {
                ProgressView()
            }
        }
        .task {
            await draftsStore.load()
            await historyStore.load()
        }
        .refreshable {
            await draftsStore.load()
            await historyStore.load()
        }
        .sheet(isPresented: $showCreateDraft) {
            CreateWorkoutTemplateScreen { title, notes in
                if await draftsStore.createDraft(title: title, notes: notes) {
                    showCreateDraft = false
                }
            }
        }
        .confirmationDialog(
            AppLocalizer.string("trainer.client_drafts.delete.title"),
            isPresented: Binding(
                get: { pendingDeleteDraft != nil },
                set: { if $0 == false { pendingDeleteDraft = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(AppLocalizer.string("common.delete"), role: .destructive) {
                guard let pendingDeleteDraft else { return }
                Task { await draftsStore.deleteDraft(pendingDeleteDraft) }
                self.pendingDeleteDraft = nil
            }
            Button(AppLocalizer.string("common.cancel"), role: .cancel) {
                pendingDeleteDraft = nil
            }
        } message: {
            Text(AppLocalizer.string("trainer.client_drafts.delete.message"))
        }
    }

    private func assignmentLink(_ assignment: WorkoutAssignment) -> some View {
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
