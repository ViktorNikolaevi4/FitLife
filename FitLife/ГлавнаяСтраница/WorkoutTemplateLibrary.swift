import Foundation
import SwiftUI
import UIKit

enum WorkoutExerciseIcon {
    static let cleanAndJerk = "CleanAndJerk"
    static let jumpingJack = "JumpingJack"
    static let run = "Бег"
    static let bench = "bench_press_bold"
    static let inclineBench = "Жим на наклонной скамье"
    static let shoulderPress = "ЖимНаПлечи"
    static let legPress = "ЖимНогами"
    static let biceps = "Бицепс"
    static let sidePlank = "БоковаяПланка"
    static let lunges = "Выпады "
    static let pullUps = "Подтягивания"
    static let snatch = "Рывок"
    static let squats = "Приседания"
    static let pistolSquat = "Пистолетик"
    static let boxJumps = "Прыжки на тумбу"
    static let deadlift = "СтановаяТяга"
    static let battleRopes = "канат"
    static let jumpRope = "скакалка"
    static let lowerAbs = "Пресс нижний"
    static let oneArmRow = "тяга одной рукой"
    static let rowing = "Гребля"
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
            activityType: .cardio,
            metValue: 9.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, durationSeconds: 900, metricType: .duration)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.bench"),
            systemImage: WorkoutExerciseIcon.bench,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 60, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.incline_bench"),
            systemImage: WorkoutExerciseIcon.inclineBench,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 45, reps: 10)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.clean_and_jerk"),
            systemImage: WorkoutExerciseIcon.cleanAndJerk,
            accentName: "orange",
            activityType: .hiit,
            metValue: 7.0,
            defaultSets: [
                WorkoutDraftSet(weight: 50, reps: 6)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.row"),
            systemImage: "dumbbell.fill",
            accentName: "orange",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 40, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.one_arm_row"),
            systemImage: WorkoutExerciseIcon.oneArmRow,
            accentName: "orange",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 20, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.press"),
            systemImage: WorkoutExerciseIcon.shoulderPress,
            accentName: "purple",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 18, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.lat"),
            systemImage: "figure.mixed.cardio",
            accentName: "green",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 35, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.legs"),
            systemImage: WorkoutExerciseIcon.legPress,
            accentName: "orange",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 80, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.core"),
            systemImage: "figure.core.training",
            accentName: "blue",
            activityType: .core,
            metValue: 4.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, durationSeconds: 60, metricType: .duration)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.lower_abs"),
            systemImage: WorkoutExerciseIcon.lowerAbs,
            accentName: "blue",
            activityType: .core,
            metValue: 4.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 15)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.biceps"),
            systemImage: WorkoutExerciseIcon.biceps,
            accentName: "orange",
            activityType: .strength,
            metValue: 4.5,
            defaultSets: [
                WorkoutDraftSet(weight: 12, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.pullups"),
            systemImage: WorkoutExerciseIcon.pullUps,
            accentName: "green",
            activityType: .strength,
            metValue: 6.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 10)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.rowing"),
            systemImage: WorkoutExerciseIcon.rowing,
            accentName: "blue",
            activityType: .cardio,
            metValue: 8.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, durationSeconds: 600, metricType: .duration)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.jumping_jack"),
            systemImage: WorkoutExerciseIcon.jumpingJack,
            accentName: "green",
            activityType: .hiit,
            metValue: 8.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, durationSeconds: 60, metricType: .duration)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.squats"),
            systemImage: WorkoutExerciseIcon.squats,
            accentName: "orange",
            activityType: .strength,
            metValue: 5.5,
            defaultSets: [
                WorkoutDraftSet(weight: 40, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.pistol_squat"),
            systemImage: WorkoutExerciseIcon.pistolSquat,
            accentName: "purple",
            activityType: .strength,
            metValue: 6.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 8)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.lunges"),
            systemImage: WorkoutExerciseIcon.lunges,
            accentName: "purple",
            activityType: .strength,
            metValue: 5.5,
            defaultSets: [
                WorkoutDraftSet(weight: 14, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.box_jumps"),
            systemImage: WorkoutExerciseIcon.boxJumps,
            accentName: "green",
            activityType: .hiit,
            metValue: 8.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.side_plank"),
            systemImage: WorkoutExerciseIcon.sidePlank,
            accentName: "blue",
            activityType: .core,
            metValue: 3.5,
            defaultSets: [
                WorkoutDraftSet(weight: 0, durationSeconds: 45, metricType: .duration)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.deadlift"),
            systemImage: WorkoutExerciseIcon.deadlift,
            accentName: "purple",
            activityType: .strength,
            metValue: 6.0,
            defaultSets: [
                WorkoutDraftSet(weight: 70, reps: 8)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.snatch"),
            systemImage: WorkoutExerciseIcon.snatch,
            accentName: "blue",
            activityType: .hiit,
            metValue: 7.0,
            defaultSets: [
                WorkoutDraftSet(weight: 35, reps: 6)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.battle_ropes"),
            systemImage: WorkoutExerciseIcon.battleRopes,
            accentName: "orange",
            activityType: .hiit,
            metValue: 10.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, durationSeconds: 30, metricType: .duration)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.jump_rope"),
            systemImage: WorkoutExerciseIcon.jumpRope,
            accentName: "green",
            activityType: .hiit,
            metValue: 11.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, durationSeconds: 60, metricType: .duration)
            ]
        )
    ]
}
