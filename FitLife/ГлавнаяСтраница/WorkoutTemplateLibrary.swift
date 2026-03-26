import Foundation

func workoutTemplates() -> [WorkoutExerciseTemplate] {
    [
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.bench"),
            systemImage: "figure.strengthtraining.traditional",
            accentName: "blue",
            defaultSets: [(60, 12), (65, 10), (70, 8)]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.row"),
            systemImage: "dumbbell.fill",
            accentName: "orange",
            defaultSets: [(40, 12), (45, 10), (50, 8)]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.press"),
            systemImage: "figure.arms.open",
            accentName: "purple",
            defaultSets: [(18, 12), (18, 10), (20, 8)]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.lat"),
            systemImage: "figure.mixed.cardio",
            accentName: "green",
            defaultSets: [(35, 12), (40, 10), (45, 8)]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.legs"),
            systemImage: "figure.run.square.stack",
            accentName: "orange",
            defaultSets: [(80, 12), (90, 10), (100, 8)]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.core"),
            systemImage: "figure.core.training",
            accentName: "blue",
            defaultSets: [(0, 20), (0, 18), (0, 15)]
        )
    ]
}
