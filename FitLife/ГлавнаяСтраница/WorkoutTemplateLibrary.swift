import Foundation
import SwiftUI
import UIKit

enum WorkoutExerciseIcon {
    static let cleanAndJerk = "CleanAndJerk"
    static let jumpingJack = "JumpingJack"
    static let run = "Бег"
    static let bench = "Жим штанги лёжа"
    static let dumbbellBench = "Жим гантелей лёжа"
    static let inclineBench = "Жим штанги на наклонной скамье"
    static let inclineDumbbellBench = "Жим гантелей на наклонной скамье"
    static let declineBench = "Жим штанги головой вниз"
    static let declineDumbbellBench = "Жим гантелей головой вниз"
    static let dumbbellFly = "Разводка гантелей лёжа"
    static let pecDeck = "Сведение рук в тренажёре"
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
    weight: Font.Weight = .semibold,
    customAssetScale: CGFloat = 1.9
) -> some View {
    let assetRenderSize = size * customAssetScale

    if hasWorkoutAssetIcon(named: name) {
        Image(name)
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .foregroundStyle(workoutAccentColor(accentName))
            .frame(width: assetRenderSize, height: assetRenderSize)
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
            accentName: "blue",
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
            name: AppLocalizer.string("workout.exercise.dumbbell_bench"),
            systemImage: WorkoutExerciseIcon.dumbbellBench,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 20, reps: 12)
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
            name: AppLocalizer.string("workout.exercise.incline_dumbbell_bench"),
            systemImage: WorkoutExerciseIcon.inclineDumbbellBench,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 18, reps: 10)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.decline_bench"),
            systemImage: WorkoutExerciseIcon.declineBench,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 50, reps: 10)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.decline_dumbbell_bench"),
            systemImage: WorkoutExerciseIcon.declineDumbbellBench,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 18, reps: 10)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.dumbbell_fly"),
            systemImage: WorkoutExerciseIcon.dumbbellFly,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.5,
            defaultSets: [
                WorkoutDraftSet(weight: 10, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.pec_deck"),
            systemImage: WorkoutExerciseIcon.pecDeck,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.5,
            defaultSets: [
                WorkoutDraftSet(weight: 35, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.clean_and_jerk"),
            systemImage: WorkoutExerciseIcon.cleanAndJerk,
            accentName: "blue",
            activityType: .hiit,
            metValue: 7.0,
            defaultSets: [
                WorkoutDraftSet(weight: 50, reps: 6)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.row"),
            systemImage: "dumbbell.fill",
            accentName: "blue",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 40, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.one_arm_row"),
            systemImage: WorkoutExerciseIcon.oneArmRow,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 20, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.press"),
            systemImage: WorkoutExerciseIcon.shoulderPress,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 18, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.lat"),
            systemImage: "figure.mixed.cardio",
            accentName: "blue",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 35, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.legs"),
            systemImage: WorkoutExerciseIcon.legPress,
            accentName: "blue",
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
            accentName: "blue",
            activityType: .strength,
            metValue: 4.5,
            defaultSets: [
                WorkoutDraftSet(weight: 12, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.pullups"),
            systemImage: WorkoutExerciseIcon.pullUps,
            accentName: "blue",
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
            accentName: "blue",
            activityType: .hiit,
            metValue: 8.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, durationSeconds: 60, metricType: .duration)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.squats"),
            systemImage: WorkoutExerciseIcon.squats,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.5,
            defaultSets: [
                WorkoutDraftSet(weight: 40, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.pistol_squat"),
            systemImage: WorkoutExerciseIcon.pistolSquat,
            accentName: "blue",
            activityType: .strength,
            metValue: 6.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 8)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.lunges"),
            systemImage: WorkoutExerciseIcon.lunges,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.5,
            defaultSets: [
                WorkoutDraftSet(weight: 14, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.box_jumps"),
            systemImage: WorkoutExerciseIcon.boxJumps,
            accentName: "blue",
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
            accentName: "blue",
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
            accentName: "blue",
            activityType: .hiit,
            metValue: 10.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, durationSeconds: 30, metricType: .duration)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.jump_rope"),
            systemImage: WorkoutExerciseIcon.jumpRope,
            accentName: "blue",
            activityType: .hiit,
            metValue: 11.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, durationSeconds: 60, metricType: .duration)
            ]
        )
    ]
}
