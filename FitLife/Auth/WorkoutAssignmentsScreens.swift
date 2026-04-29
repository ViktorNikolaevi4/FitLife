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
                ForEach(store.clients) { client in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(client.displayName)
                                .font(.headline)
                            Text(client.email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if store.isAssigned(clientId: client.id) {
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
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .overlay {
            if store.isLoading {
                ProgressView()
            } else if store.clients.isEmpty {
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

struct ClientAssignedWorkoutsScreen: View {
    let clientId: String

    @StateObject private var store: ClientAssignedWorkoutsStore
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue

    init(clientId: String) {
        self.clientId = clientId
        _store = StateObject(wrappedValue: ClientAssignedWorkoutsStore(clientId: clientId))
    }

    private var appLanguage: AppLanguage {
        AppLanguage.from(rawValue: appLanguageRaw)
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

            Section(appLanguage.localized("client.assignments.section")) {
                ForEach(store.assignments) { assignment in
                    NavigationLink {
                        ClientAssignmentDetailScreen(
                            assignment: assignment,
                            trainerName: store.trainerName(for: assignment.trainerId)
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(assignment.titleSnapshot)
                                .font(.headline)

                            if assignment.notesSnapshot.isEmpty == false {
                                Text(
                                    assignment.notesSnapshot
                                )
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            }

                            HStack(spacing: 12) {
                                if let trainerName = store.trainerName(for: assignment.trainerId) {
                                    Text(
                                        AppLocalizer.format(
                                            "client.assignments.trainer",
                                            trainerName
                                        )
                                    )
                                }

                                Text(
                                    AppLocalizer.format(
                                        "client.assignments.exercise_count",
                                        assignment.exerciseCount
                                    )
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
            }
        }
        .overlay {
            if store.isLoading {
                ProgressView()
            } else if store.assignments.isEmpty {
                ContentUnavailableView(
                    appLanguage.localized("client.assignments.empty.title"),
                    systemImage: "list.bullet.clipboard",
                    description: Text(appLanguage.localized("client.assignments.empty.subtitle"))
                )
            }
        }
        .navigationTitle(appLanguage.localized("client.assignments.title"))
        .task {
            await store.load()
        }
        .refreshable {
            await store.load()
        }
    }
}

struct ClientAssignmentDetailScreen: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var sessionStore: AppSessionStore

    let assignment: WorkoutAssignment
    let trainerName: String?

    @Query private var workouts: [WorkoutSession]
    @StateObject private var store: ClientAssignmentDetailStore
    @State private var selectedWorkout: WorkoutSession?
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue
    @AppStorage(Gender.appStorageKey) private var activeGenderRaw: String = Gender.male.rawValue

    init(
        assignment: WorkoutAssignment,
        trainerName: String?
    ) {
        self.assignment = assignment
        self.trainerName = trainerName
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
                ForEach(Array(store.exercises.enumerated()), id: \.element.id) { index, exercise in
                    ClientAssignmentExerciseCard(
                        exercise: exercise,
                        displayIndex: index + 1
                    )
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
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
            ActiveWorkoutScreen(workout: workout)
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
