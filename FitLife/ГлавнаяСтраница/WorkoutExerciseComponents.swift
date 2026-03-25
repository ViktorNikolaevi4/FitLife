import SwiftUI

struct WorkoutExerciseCard: View {
    let exercise: WorkoutExercise
    let onToggleExpanded: () -> Void
    let onToggleSet: (WorkoutSet) -> Void
    let onAddSet: () -> Void
    let onDeleteSet: (WorkoutSet) -> Void
    let onDeleteExercise: () -> Void

    private var sortedSets: [WorkoutSet] {
        exercise.sets.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var completedCount: Int {
        sortedSets.filter(\.isCompleted).count
    }

    var body: some View {
        SwipeRevealDeleteContainer(cornerRadius: 16, onDelete: onDeleteExercise) {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: onToggleExpanded) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(workoutAccentColor(exercise.accentName).opacity(0.16))

                            Image(systemName: exercise.systemImage)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(workoutAccentColor(exercise.accentName))
                        }
                        .frame(width: 40, height: 40)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name)
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Text(AppLocalizer.format("workout.exercise.summary", sortedSets.count, completedCount))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(exercise.isExpanded ? 90 : 0))
                            .foregroundStyle(.secondary)
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.black.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .padding(10)

                if exercise.isExpanded {
                    VStack(spacing: 0) {
                        ForEach(sortedSets, id: \.id) { set in
                            WorkoutSetRow(
                                set: set,
                                onToggle: { onToggleSet(set) },
                                onDelete: { onDeleteSet(set) }
                            )
                            if set.id != sortedSets.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }

                        Button(action: onAddSet) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus")
                                Text(AppLocalizer.string("workout.add.set"))
                                    .fontWeight(.semibold)
                            }
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
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
        }
    }
}

struct WorkoutSetRow: View {
    let set: WorkoutSet
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        SwipeRevealDeleteContainer(cornerRadius: 0, onDelete: onDelete) {
            HStack(spacing: 12) {
                Text(AppLocalizer.format("workout.set.number", set.orderIndex + 1))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, alignment: .leading)

                Text(AppLocalizer.format("workout.set.value", formattedWeight(set.weight), set.reps))
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
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private func formattedWeight(_ weight: Double) -> String {
        if weight.rounded() == weight {
            return String(Int(weight))
        }
        return String(format: "%.1f", weight)
    }
}

struct SwipeRevealDeleteContainer<Content: View>: View {
    let cornerRadius: CGFloat
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    @GestureState private var dragTranslation: CGFloat = 0

    private let actionWidth: CGFloat = 88

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack {
                Spacer()

                Button(role: .destructive, action: onDelete) {
                    VStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.headline.weight(.semibold))
                        Text(AppLocalizer.string("common.delete"))
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.red)
                }
                .buttonStyle(.plain)
            }

            content()
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .offset(x: currentOffset)
                .gesture(
                    DragGesture(minimumDistance: 12, coordinateSpace: .local)
                        .updating($dragTranslation) { value, state, _ in
                            if abs(value.translation.width) > abs(value.translation.height) {
                                state = value.translation.width
                            }
                        }
                        .onEnded { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            withAnimation(.easeOut(duration: 0.2)) {
                                if value.translation.width < -36 {
                                    offset = -actionWidth
                                } else if value.translation.width > 36 {
                                    offset = 0
                                }
                            }
                        }
                )
                .onTapGesture {
                    if offset != 0 {
                        withAnimation(.easeOut(duration: 0.2)) {
                            offset = 0
                        }
                    }
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var currentOffset: CGFloat {
        min(0, max(-actionWidth, offset + dragTranslation))
    }
}

func workoutAccentColor(_ name: String) -> Color {
    switch name {
    case "green": return Color(red: 0.38, green: 0.72, blue: 0.52)
    case "orange": return Color(red: 0.92, green: 0.62, blue: 0.34)
    case "purple": return Color(red: 0.57, green: 0.56, blue: 0.85)
    default: return Color(red: 0.39, green: 0.63, blue: 0.94)
    }
}
