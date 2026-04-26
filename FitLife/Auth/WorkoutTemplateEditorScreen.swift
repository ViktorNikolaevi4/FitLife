import SwiftUI
import SwiftData

private let workoutTemplateEditorCardBackground = Color(.secondarySystemBackground)
private let workoutTemplateEditorBorder = Color(.separator).opacity(0.22)

struct WorkoutTemplateEditorScreen: View {
    let template: WorkoutTemplate

    @StateObject private var store: WorkoutTemplateContentStore
    @State private var showAddExercise = false
    @State private var showAssignSheet = false
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
                ForEach(store.exercises) { exercise in
                    SwipeRevealDeleteContainer(cornerRadius: 16, onDelete: {
                        Task { await store.deleteExercise(exercise) }
                    }) {
                        VStack(alignment: .leading, spacing: 12) {
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
                                    Text(
                                        AppLocalizer.format(
                                            "trainer.templates.exercise.summary",
                                            exercise.sets.count
                                        )
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }

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
                            .padding(.leading, 4)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 16).fill(workoutTemplateEditorCardBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(workoutTemplateEditorBorder)
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
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
                    await store.addExercise(draft)
                    showAddExercise = false
                }
            }
            .presentationDetents([.large])
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
    }
}
