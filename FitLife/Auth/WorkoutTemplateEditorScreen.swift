import SwiftUI
import SwiftData

private let workoutTemplateEditorCardBackground = Color(.secondarySystemBackground)
private let workoutTemplateEditorBorder = Color(.separator).opacity(0.22)

struct WorkoutTemplateEditorScreen: View {
    let template: WorkoutTemplate

    @StateObject private var store: WorkoutTemplateContentStore
    @State private var showAddExercise = false
    @State private var showAddBlock = false
    @State private var targetBlockId: String?
    @State private var showAssignSheet = false
    @State private var expandedExerciseIds: Set<String> = []
    @State private var pendingDeleteExercise: WorkoutTemplateExerciseItem?
    @Query(sort: \CustomWorkoutExerciseTemplate.createdAt) private var customTemplates: [CustomWorkoutExerciseTemplate]
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue

    init(template: WorkoutTemplate) {
        self.template = template
        _store = StateObject(wrappedValue: WorkoutTemplateContentStore(template: template))
    }

    private var appLanguage: AppLanguage {
        AppLanguage.from(rawValue: appLanguageRaw)
    }

    private var templates: [WorkoutExerciseTemplate] {
        workoutTemplates()
    }

    private var templateBlockGroups: [WorkoutTemplateBlockGroup] {
        var groups = store.blocks
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { block in
                let exercises = store.exercises
                    .filter { $0.blockId == block.id }
                    .sorted { $0.orderIndex < $1.orderIndex }
                return WorkoutTemplateBlockGroup(
                    id: block.id,
                    block: block,
                    title: block.displayTitle,
                    subtitle: block.subtitle(exerciseCount: exercises.count),
                    exercises: exercises
                )
            }

        let groupedIds = Set(groups.flatMap { $0.exercises.map(\.id) })
        let legacyExercises = store.exercises
            .filter { groupedIds.contains($0.id) == false }
            .sorted { $0.orderIndex < $1.orderIndex }
        if legacyExercises.isEmpty == false {
            groups.insert(
                WorkoutTemplateBlockGroup(
                    id: "legacy-strength",
                    block: nil,
                    title: AppLocalizer.string("workout.block.strength.title"),
                    subtitle: AppLocalizer.format("workout.block.exercise_count", legacyExercises.count),
                    exercises: legacyExercises
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

            if template.notes.isEmpty == false {
                Section(appLanguage.localized("trainer.templates.notes")) {
                    Text(template.notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section(appLanguage.localized("trainer.templates.exercises.section")) {
                ForEach(templateBlockGroups) { group in
                    WorkoutTemplateBlockHeader(
                        title: group.title,
                        subtitle: group.subtitle,
                        onAddExercise: group.block.map { block in
                            {
                                targetBlockId = block.id
                                showAddExercise = true
                            }
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 2, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    ForEach(group.exercises) { exercise in
                        WorkoutTemplateExerciseCard(
                            exercise: exercise,
                            isExpanded: expandedExerciseIds.contains(exercise.id),
                            onToggleExpanded: {
                                toggleExpanded(exercise.id)
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDeleteExercise = exercise
                            } label: {
                                Label(AppLocalizer.string("common.delete"), systemImage: "trash")
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(template.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAssignSheet = true
                } label: {
                    Image(systemName: "paperplane")
                }
                .disabled(store.exercises.isEmpty)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddBlock = true
                } label: {
                    Image(systemName: "square.stack.3d.up.fill")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    targetBlockId = nil
                    showAddExercise = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .overlay {
            if store.isLoading {
                ProgressView()
            } else if store.exercises.isEmpty {
                ContentUnavailableView(
                    appLanguage.localized("trainer.templates.exercises.empty.title"),
                    systemImage: "dumbbell",
                    description: Text(appLanguage.localized("trainer.templates.exercises.empty.subtitle"))
                )
            }
        }
        .task {
            await store.load()
        }
        .sheet(isPresented: $showAddExercise) {
            AddWorkoutExerciseScreen(templates: templates) { draft in
                Task {
                    await store.addExercise(draft, blockId: targetBlockId)
                    targetBlockId = nil
                    showAddExercise = false
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddBlock) {
            AddWorkoutTemplateBlockScreen { draft in
                Task {
                    await store.addBlock(
                        title: draft.resolvedTitle,
                        type: draft.type,
                        rounds: draft.rounds,
                        restBetweenRoundsSeconds: draft.restBetweenRoundsSeconds
                    )
                    showAddBlock = false
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAssignSheet) {
            NavigationStack {
                AssignWorkoutTemplateScreen(
                    template: template,
                    exerciseCount: store.exercises.count
                )
            }
        }
        .confirmationDialog(
            AppLocalizer.string("workout.exercise.delete.title"),
            isPresented: Binding(
                get: { pendingDeleteExercise != nil },
                set: { if $0 == false { pendingDeleteExercise = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(AppLocalizer.string("workout.exercise.delete"), role: .destructive) {
                guard let pendingDeleteExercise else { return }
                expandedExerciseIds.remove(pendingDeleteExercise.id)
                Task { await store.deleteExercise(pendingDeleteExercise) }
                self.pendingDeleteExercise = nil
            }
            Button(AppLocalizer.string("common.cancel"), role: .cancel) {
                pendingDeleteExercise = nil
            }
        } message: {
            Text(AppLocalizer.string("workout.exercise.delete.message"))
        }
    }

    private func toggleExpanded(_ id: String) {
        withAnimation(.snappy(duration: 0.22)) {
            if expandedExerciseIds.contains(id) {
                expandedExerciseIds.remove(id)
            } else {
                expandedExerciseIds.insert(id)
            }
        }
    }
}

private struct WorkoutTemplateBlockGroup: Identifiable {
    let id: String
    let block: WorkoutTemplateBlockItem?
    let title: String
    let subtitle: String
    let exercises: [WorkoutTemplateExerciseItem]
}

private struct WorkoutTemplateBlockHeader: View {
    let title: String
    let subtitle: String
    var onAddExercise: (() -> Void)?

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

            if let onAddExercise {
                Button(action: onAddExercise) {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.blue)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.blue.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AppLocalizer.string("workout.add.exercise"))
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }
}

private struct WorkoutTemplateBlockDraft {
    var title: String
    var type: WorkoutBlockType
    var rounds: Int
    var restBetweenRoundsSeconds: Int

    var resolvedTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            return type.title
        }
        return trimmedTitle
    }
}

private struct AddWorkoutTemplateBlockScreen: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (WorkoutTemplateBlockDraft) -> Void

    @State private var type: WorkoutBlockType = .circuit
    @State private var title = ""
    @State private var rounds = 3
    @State private var restBetweenRoundsSeconds = 60

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(AppLocalizer.string("workout.block.type"), selection: $type) {
                        ForEach(WorkoutBlockType.templateCases, id: \.self) { blockType in
                            Text(blockType.title).tag(blockType)
                        }
                    }
                    .pickerStyle(.menu)

                    TextField(AppLocalizer.string("workout.block.title.placeholder"), text: $title)
                }

                if type == .circuit {
                    Section(AppLocalizer.string("workout.block.circuit.settings")) {
                        Stepper(
                            AppLocalizer.format("workout.block.rounds.value", rounds),
                            value: $rounds,
                            in: 1...20
                        )
                        Stepper(
                            AppLocalizer.format("workout.block.round_rest.value", restBetweenRoundsSeconds),
                            value: $restBetweenRoundsSeconds,
                            in: 0...600,
                            step: 5
                        )
                    }
                }
            }
            .navigationTitle(AppLocalizer.string("workout.block.add.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(AppLocalizer.string("common.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(AppLocalizer.string("common.save")) {
                        save()
                    }
                }
            }
        }
    }

    private func save() {
        onSave(
            WorkoutTemplateBlockDraft(
                title: title,
                type: type,
                rounds: type == .circuit ? rounds : 1,
                restBetweenRoundsSeconds: type == .circuit ? restBetweenRoundsSeconds : 0
            )
        )
        dismiss()
    }
}

private struct WorkoutTemplateExerciseCard: View {
    let exercise: WorkoutTemplateExerciseItem
    let isExpanded: Bool
    let onToggleExpanded: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggleExpanded) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(workoutAccentColor(exercise.accentName).opacity(0.16))
                        .frame(width: 40, height: 40)
                        .overlay {
                            workoutIconImage(
                                named: exercise.systemImage,
                                accentName: exercise.accentName,
                                size: 18
                            )
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(AppLocalizer.format("trainer.templates.exercise.summary", exercise.sets.count))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
                .padding(14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(Array(exercise.sets.enumerated()), id: \.offset) { index, set in
                        HStack {
                            Text("\(index + 1)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 24, alignment: .leading)

                            Text(
                                formattedWorkoutSetValue(
                                    weight: set.weight,
                                    reps: set.reps,
                                    durationSeconds: set.durationSeconds,
                                    metricType: set.metricType
                                )
                            )
                            .font(.subheadline.weight(.medium))

                            Spacer()
                        }
                        .padding(.vertical, 10)

                        if index < exercise.sets.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(workoutTemplateEditorCardBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(workoutTemplateEditorBorder)
        )
    }
}
