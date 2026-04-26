import Foundation
import SwiftUI
import UIKit

enum WorkoutExerciseIcon {
    static let cleanAndJerk = "CleanAndJerk"
    static let jumpingJack = "JumpingJack"
    static let run = "Бег"
    static let bench = "ЖимЛежа"
    static let shoulderPress = "ЖимНаПлечи"
    static let legPress = "ЖимНогами"
    static let biceps = "Бицепс"
    static let sidePlank = "БоковаяПланка"
    static let lunges = "Выпады "
    static let pullUps = "Подтягивания"
    static let snatch = "Рывок"
    static let squats = "Приседания"
    static let boxJumps = "Прыжки на тумбу"
    static let deadlift = "СтановаяТяга"
    static let battleRopes = "канат"
    static let jumpRope = "скакалка"
}

func hasWorkoutAssetIcon(named name: String) -> Bool {
    UIImage(named: name) != nil
}

@ViewBuilder
func workoutIconImage(
    named name: String,
    accentName: String,
    size: CGFloat,
    weight: Font.Weight = .semibold
) -> some View {
    if hasWorkoutAssetIcon(named: name) {
        Image(name)
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .foregroundStyle(workoutAccentColor(accentName))
            .frame(width: size, height: size)
    } else {
        Image(systemName: name)
            .font(.system(size: size, weight: weight))
            .foregroundStyle(workoutAccentColor(accentName))
    }
}

func workoutTemplates() -> [WorkoutExerciseTemplate] {
    [
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.run"),
            systemImage: WorkoutExerciseIcon.run,
            accentName: "green",
            defaultSets: [
                WorkoutDraftSet(weight: 0, durationSeconds: 900, metricType: .duration)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.bench"),
            systemImage: WorkoutExerciseIcon.bench,
            accentName: "blue",
            defaultSets: [
                WorkoutDraftSet(weight: 60, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.clean_and_jerk"),
            systemImage: WorkoutExerciseIcon.cleanAndJerk,
            accentName: "orange",
            defaultSets: [
                WorkoutDraftSet(weight: 50, reps: 6)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.row"),
            systemImage: "dumbbell.fill",
            accentName: "orange",
            defaultSets: [
                WorkoutDraftSet(weight: 40, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.press"),
            systemImage: WorkoutExerciseIcon.shoulderPress,
            accentName: "purple",
            defaultSets: [
                WorkoutDraftSet(weight: 18, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.lat"),
            systemImage: "figure.mixed.cardio",
            accentName: "green",
            defaultSets: [
                WorkoutDraftSet(weight: 35, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.legs"),
            systemImage: WorkoutExerciseIcon.legPress,
            accentName: "orange",
            defaultSets: [
                WorkoutDraftSet(weight: 80, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.core"),
            systemImage: "figure.core.training",
            accentName: "blue",
            defaultSets: [
                WorkoutDraftSet(weight: 0, durationSeconds: 60, metricType: .duration)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.biceps"),
            systemImage: WorkoutExerciseIcon.biceps,
            accentName: "orange",
            defaultSets: [
                WorkoutDraftSet(weight: 12, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.pullups"),
            systemImage: WorkoutExerciseIcon.pullUps,
            accentName: "green",
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 10)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.jumping_jack"),
            systemImage: WorkoutExerciseIcon.jumpingJack,
            accentName: "green",
            defaultSets: [
                WorkoutDraftSet(weight: 0, durationSeconds: 60, metricType: .duration)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.squats"),
            systemImage: WorkoutExerciseIcon.squats,
            accentName: "orange",
            defaultSets: [
                WorkoutDraftSet(weight: 40, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.lunges"),
            systemImage: WorkoutExerciseIcon.lunges,
            accentName: "purple",
            defaultSets: [
                WorkoutDraftSet(weight: 14, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.box_jumps"),
            systemImage: WorkoutExerciseIcon.boxJumps,
            accentName: "green",
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.side_plank"),
            systemImage: WorkoutExerciseIcon.sidePlank,
            accentName: "blue",
            defaultSets: [
                WorkoutDraftSet(weight: 0, durationSeconds: 45, metricType: .duration)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.deadlift"),
            systemImage: WorkoutExerciseIcon.deadlift,
            accentName: "purple",
            defaultSets: [
                WorkoutDraftSet(weight: 70, reps: 8)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.snatch"),
            systemImage: WorkoutExerciseIcon.snatch,
            accentName: "blue",
            defaultSets: [
                WorkoutDraftSet(weight: 35, reps: 6)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.battle_ropes"),
            systemImage: WorkoutExerciseIcon.battleRopes,
            accentName: "orange",
            defaultSets: [
                WorkoutDraftSet(weight: 0, durationSeconds: 30, metricType: .duration)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.jump_rope"),
            systemImage: WorkoutExerciseIcon.jumpRope,
            accentName: "green",
            defaultSets: [
                WorkoutDraftSet(weight: 0, durationSeconds: 60, metricType: .duration)
            ]
        )
    ]
}
