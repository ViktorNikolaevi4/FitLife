import SwiftUI

private let workoutCardBackground = Color(.secondarySystemBackground)
private let workoutCardInsetBackground = Color(.tertiarySystemBackground)
private let workoutCardBorder = Color(.separator).opacity(0.40)

struct WorkoutExerciseCard: View {
    let exercise: WorkoutExercise
    let onToggleExpanded: () -> Void
    let onEditNote: () -> Void
    let onToggleSet: (WorkoutSet) -> Void
    let onEditSet: (WorkoutSet) -> Void
    let onAddSet: () -> Void
    let onDeleteSet: (WorkoutSet) -> Void
    let onDeleteExercise: () -> Void

    private var sortedSets: [WorkoutSet] {
        exercise.setItems.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var completedCount: Int {
        sortedSets.filter(\.isCompleted).count
    }

    @State private var showDeleteConfirmation = false

    private var trimmedNote: String {
        exercise.note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggleExpanded) {
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
                    .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(AppLocalizer.format("workout.exercise.summary", sortedSets.count, completedCount))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if trimmedNote.isEmpty == false {
                            Text(trimmedNote)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(exercise.isExpanded ? 90 : 0))
                        .foregroundStyle(.secondary)
                        .font(.system(size: 15, weight: .semibold))
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(workoutCardInsetBackground))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(workoutCardBorder))
            }
            .buttonStyle(.plain)
            .padding(10)

            if exercise.isExpanded {
                VStack(spacing: 0) {
                    Button(action: onEditNote) {
                        HStack(spacing: 8) {
                            Image(systemName: "note.text")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Text(
                                trimmedNote.isEmpty
                                ? AppLocalizer.string("workout.exercise.note.add")
                                : trimmedNote
                            )
                            .font(.subheadline)
                            .foregroundStyle(
                                trimmedNote.isEmpty
                                ? .secondary
                                : .primary
                            )
                            .multilineTextAlignment(.leading)
                            .lineLimit(1)
                            .truncationMode(.tail)

                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 2)
                        .padding(.bottom, 14)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .padding(.leading, 16)

                    ForEach(sortedSets, id: \.id) { set in
                        WorkoutSetRow(
                            set: set,
                            onEdit: { onEditSet(set) },
                            onToggle: { onToggleSet(set) }
                        )
                        if set.id != sortedSets.last?.id {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }

                    Button(action: onAddSet) {
                        Text(AppLocalizer.string("workout.add.set"))
                            .fontWeight(.semibold)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .padding(.top, 14)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(workoutCardBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(workoutCardBorder)
        )
        .contextMenu {
            Button(action: onEditNote) {
                Label(
                    AppLocalizer.string("workout.exercise.note.title"),
                    systemImage: "note.text"
                )
            }

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label(
                    AppLocalizer.string("workout.exercise.delete"),
                    systemImage: "trash"
                )
            }
        }
        .confirmationDialog(
            AppLocalizer.string("workout.exercise.delete.title"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(AppLocalizer.string("workout.exercise.delete"), role: .destructive) {
                onDeleteExercise()
            }
            Button(AppLocalizer.string("common.cancel"), role: .cancel) {}
        } message: {
            Text(AppLocalizer.string("workout.exercise.delete.message"))
        }
    }
}

struct WorkoutSetRow: View {
    let set: WorkoutSet
    let onEdit: () -> Void
    let onToggle: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                Text(AppLocalizer.format("workout.set.number", set.orderIndex + 1))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, alignment: .leading)

                Text(
                    formattedWorkoutSetValue(
                        weight: set.weight,
                        reps: set.reps,
                        durationSeconds: set.durationSeconds,
                        metricType: set.metricType
                    )
                )
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer()

                Button(action: onToggle) {
                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(set.isCompleted ? Color.green : .secondary)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

}

func workoutAccentColor(_ name: String) -> Color {
    switch name {
    case "blue": return Color(red: 0.39, green: 0.63, blue: 0.94)
    case "sky": return Color(red: 0.31, green: 0.72, blue: 0.96)
    case "cyan": return Color(red: 0.18, green: 0.76, blue: 0.86)
    case "teal": return Color(red: 0.20, green: 0.67, blue: 0.66)
    case "green": return Color(red: 0.38, green: 0.72, blue: 0.52)
    case "mint": return Color(red: 0.36, green: 0.78, blue: 0.65)
    case "lime": return Color(red: 0.60, green: 0.78, blue: 0.30)
    case "yellow": return Color(red: 0.93, green: 0.77, blue: 0.24)
    case "gold": return Color(red: 0.88, green: 0.64, blue: 0.20)
    case "orange": return Color(red: 0.92, green: 0.62, blue: 0.34)
    case "coral": return Color(red: 0.92, green: 0.45, blue: 0.32)
    case "red": return Color(red: 0.86, green: 0.30, blue: 0.30)
    case "crimson": return Color(red: 0.74, green: 0.20, blue: 0.31)
    case "pink": return Color(red: 0.91, green: 0.45, blue: 0.64)
    case "rose": return Color(red: 0.86, green: 0.35, blue: 0.49)
    case "magenta": return Color(red: 0.78, green: 0.35, blue: 0.78)
    case "violet": return Color(red: 0.60, green: 0.43, blue: 0.90)
    case "purple": return Color(red: 0.57, green: 0.56, blue: 0.85)
    case "indigo": return Color(red: 0.38, green: 0.43, blue: 0.82)
    case "navy": return Color(red: 0.22, green: 0.36, blue: 0.68)
    case "aqua": return Color(red: 0.28, green: 0.70, blue: 0.78)
    case "emerald": return Color(red: 0.24, green: 0.62, blue: 0.43)
    case "olive": return Color(red: 0.48, green: 0.58, blue: 0.31)
    case "amber": return Color(red: 0.93, green: 0.54, blue: 0.22)
    case "peach": return Color(red: 0.93, green: 0.58, blue: 0.43)
    case "salmon": return Color(red: 0.90, green: 0.42, blue: 0.42)
    case "plum": return Color(red: 0.54, green: 0.35, blue: 0.62)
    case "brown": return Color(red: 0.56, green: 0.40, blue: 0.30)
    case "slate": return Color(red: 0.43, green: 0.50, blue: 0.58)
    case "graphite": return Color(red: 0.34, green: 0.36, blue: 0.40)
    default: return workoutAccentColor("blue")
    }
}
