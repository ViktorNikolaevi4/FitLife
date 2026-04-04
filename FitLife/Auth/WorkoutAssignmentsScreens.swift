import SwiftUI
import SwiftData

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
                if assignment.notesSnapshot.isEmpty == false {
                    Text(assignment.notesSnapshot)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let trainerName {
                    Text(AppLocalizer.format("client.assignments.trainer", trainerName))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(assignment.assignedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Section(appLanguage.localized("client.assignment.detail.exercises")) {
                ForEach(store.exercises) { exercise in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(exercise.name)
                            .font(.headline)

                        ForEach(Array(exercise.sets.enumerated()), id: \.offset) { index, set in
                            HStack {
                                Text("\(index + 1).")
                                    .foregroundStyle(.secondary)
                                Text(AppLocalizer.format("workout.set.value", formattedWeight(set.weight), set.reps))
                                Spacer()
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                Button(activeWorkout == nil ? AppLocalizer.string("client.assignments.start") : AppLocalizer.string("client.assignments.resume")) {
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
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle(assignment.titleSnapshot)
        .navigationDestination(item: $selectedWorkout) { workout in
            ActiveWorkoutScreen(workout: workout)
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

    private func formattedWeight(_ weight: Double) -> String {
        if weight.rounded() == weight {
            return String(Int(weight))
        }
        return String(format: "%.1f", weight)
    }
}
