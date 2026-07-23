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
    static let highToLowCableCrossover = "Кроссовер сверху вниз"
    static let lowToHighCableCrossover = "Кроссовер снизу вверх"
    static let pushUps = "Отжимания от пола"
    static let wideGripPushUps = "Отжимания с широкой постановкой рук"
    static let chestFocusedDips = "Отжимания на брусьях с акцентом на грудь"
    static let dumbbellPullover = "Пуловер с гантелью"
    static let shoulderPress = "ЖимНаПлечи"
    static let standingBarbellPress = "Жим штанги стоя"
    static let seatedDumbbellPress = "Жим гантелей сидя"
    static let arnoldPress = "Жим Арнольда"
    static let machineShoulderPress = "Жим плечами в тренажёре"
    static let dumbbellLateralRaise = "Подъём гантелей в стороны"
    static let dumbbellFrontRaise = "Подъём гантелей перед собой"
    static let bentOverDumbbellReverseFly = "Разведение гантелей в наклоне"
    static let barbellUprightRow = "Тяга штанги к подбородку"
    static let yRaises = "Y-подъёмы"
    static let singleArmCableLateralRaise = "Махи одной рукой в кроссовере"
    static let bandShoulderExternalRotation = "Наружное вращение плеча с резинкой"
    static let bandShoulderInternalRotation = "Внутреннее вращение плеча с резинкой"
    static let barbellShrugs = "Шраги со штангой"
    static let dumbbellShrugs = "Шраги с гантелями"
    static let latPulldownToChest = "Тяга верхнего блока к груди"
    static let closeGripLatPulldown = "Тяга верхнего блока узким хватом"
    static let cablePullover = "Пуловер на верхнем блоке"
    static let ropeFacePull = "Тяга каната к лицу"
    static let seatedCableRow = "Тяга горизонтального блока"
    static let barbellBentOverRow = "Тяга штанги в наклоне"
    static let oneArmDumbbellRow = "Тяга гантели одной рукой"
    static let tBarRow = "Тяга Т-грифа"
    static let chestSupportedMachineRow = "Тяга в тренажёре с упором грудью"
    static let pendlayRow = "Тяга Пендли"
    static let legPress = "ЖимНогами"
    static let biceps = "Бицепс"
    static let barbellBicepsCurl = "Сгибание штанги на бицепс"
    static let ezBarBicepsCurl = "Сгибание EZ-штанги на бицепс"
    static let standingDumbbellCurl = "Сгибание гантелей стоя"
    static let hammerCurls = "Молотковые сгибания"
    static let preacherCurl = "Сгибание рук на скамье Скотта"
    static let concentrationCurl = "Концентрированное сгибание"
    static let sidePlank = "БоковаяПланка"
    static let lunges = "Выпады "
    static let pullUps = "Подтягивания"
    static let chinUps = "Подтягивания обратным хватом"
    static let bandAssistedPullUps = "Подтягивания с резинкой"
    static let assistedPullUpMachine = "Подтягивания в гравитроне"
    static let snatch = "Рывок"
    static let squats = "Приседания"
    static let pistolSquat = "Пистолетик"
    static let boxJumps = "Прыжки на тумбу"
    static let deadlift = "СтановаяТяга"
    static let classicDeadlift = "Классическая становая тяга"
    static let sumoDeadlift = "Становая тяга сумо"
    static let backExtension = "Гиперэкстензия"
    static let reverseBackExtension = "Обратная гиперэкстензия"
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
            name: AppLocalizer.string("workout.exercise.high_to_low_cable_crossover"),
            systemImage: WorkoutExerciseIcon.highToLowCableCrossover,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.5,
            defaultSets: [
                WorkoutDraftSet(weight: 15, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.low_to_high_cable_crossover"),
            systemImage: WorkoutExerciseIcon.lowToHighCableCrossover,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.5,
            defaultSets: [
                WorkoutDraftSet(weight: 12, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.push_ups"),
            systemImage: WorkoutExerciseIcon.pushUps,
            accentName: "blue",
            activityType: .strength,
            metValue: 3.8,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 15)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.wide_grip_push_ups"),
            systemImage: WorkoutExerciseIcon.wideGripPushUps,
            accentName: "blue",
            activityType: .strength,
            metValue: 3.8,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.chest_focused_dips"),
            systemImage: WorkoutExerciseIcon.chestFocusedDips,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 10)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.dumbbell_pullover"),
            systemImage: WorkoutExerciseIcon.dumbbellPullover,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.5,
            defaultSets: [
                WorkoutDraftSet(weight: 16, reps: 12)
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
            name: AppLocalizer.string("workout.exercise.barbell_bent_over_row"),
            systemImage: WorkoutExerciseIcon.barbellBentOverRow,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 40, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.one_arm_dumbbell_row"),
            systemImage: WorkoutExerciseIcon.oneArmDumbbellRow,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 20, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.t_bar_row"),
            systemImage: WorkoutExerciseIcon.tBarRow,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 35, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.chest_supported_machine_row"),
            systemImage: WorkoutExerciseIcon.chestSupportedMachineRow,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 35, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.pendlay_row"),
            systemImage: WorkoutExerciseIcon.pendlayRow,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 40, reps: 10)
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
            name: AppLocalizer.string("workout.exercise.standing_barbell_press"),
            systemImage: WorkoutExerciseIcon.standingBarbellPress,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 30, reps: 10)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.seated_dumbbell_press"),
            systemImage: WorkoutExerciseIcon.seatedDumbbellPress,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 14, reps: 10)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.arnold_press"),
            systemImage: WorkoutExerciseIcon.arnoldPress,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 12, reps: 10)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.machine_shoulder_press"),
            systemImage: WorkoutExerciseIcon.machineShoulderPress,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 30, reps: 10)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.dumbbell_lateral_raise"),
            systemImage: WorkoutExerciseIcon.dumbbellLateralRaise,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.0,
            defaultSets: [
                WorkoutDraftSet(weight: 8, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.dumbbell_front_raise"),
            systemImage: WorkoutExerciseIcon.dumbbellFrontRaise,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.0,
            defaultSets: [
                WorkoutDraftSet(weight: 8, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.bent_over_dumbbell_reverse_fly"),
            systemImage: WorkoutExerciseIcon.bentOverDumbbellReverseFly,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.0,
            defaultSets: [
                WorkoutDraftSet(weight: 6, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.barbell_upright_row"),
            systemImage: WorkoutExerciseIcon.barbellUprightRow,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.0,
            defaultSets: [
                WorkoutDraftSet(weight: 25, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.y_raises"),
            systemImage: WorkoutExerciseIcon.yRaises,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.0,
            defaultSets: [
                WorkoutDraftSet(weight: 4, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.single_arm_cable_lateral_raise"),
            systemImage: WorkoutExerciseIcon.singleArmCableLateralRaise,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.0,
            defaultSets: [
                WorkoutDraftSet(weight: 5, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.band_shoulder_external_rotation"),
            systemImage: WorkoutExerciseIcon.bandShoulderExternalRotation,
            accentName: "blue",
            activityType: .strength,
            metValue: 3.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 15)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.band_shoulder_internal_rotation"),
            systemImage: WorkoutExerciseIcon.bandShoulderInternalRotation,
            accentName: "blue",
            activityType: .strength,
            metValue: 3.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 15)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.barbell_shrugs"),
            systemImage: WorkoutExerciseIcon.barbellShrugs,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.0,
            defaultSets: [
                WorkoutDraftSet(weight: 50, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.dumbbell_shrugs"),
            systemImage: WorkoutExerciseIcon.dumbbellShrugs,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.0,
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
            name: AppLocalizer.string("workout.exercise.lat_pulldown_to_chest"),
            systemImage: WorkoutExerciseIcon.latPulldownToChest,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 35, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.close_grip_lat_pulldown"),
            systemImage: WorkoutExerciseIcon.closeGripLatPulldown,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 35, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.cable_pullover"),
            systemImage: WorkoutExerciseIcon.cablePullover,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.5,
            defaultSets: [
                WorkoutDraftSet(weight: 25, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.rope_face_pull"),
            systemImage: WorkoutExerciseIcon.ropeFacePull,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.0,
            defaultSets: [
                WorkoutDraftSet(weight: 20, reps: 15)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.seated_cable_row"),
            systemImage: WorkoutExerciseIcon.seatedCableRow,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 40, reps: 12)
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
            name: AppLocalizer.string("workout.exercise.barbell_biceps_curl"),
            systemImage: WorkoutExerciseIcon.barbellBicepsCurl,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.5,
            defaultSets: [
                WorkoutDraftSet(weight: 25, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.ez_bar_biceps_curl"),
            systemImage: WorkoutExerciseIcon.ezBarBicepsCurl,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.5,
            defaultSets: [
                WorkoutDraftSet(weight: 20, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.standing_dumbbell_curl"),
            systemImage: WorkoutExerciseIcon.standingDumbbellCurl,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.5,
            defaultSets: [
                WorkoutDraftSet(weight: 10, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.hammer_curls"),
            systemImage: WorkoutExerciseIcon.hammerCurls,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.5,
            defaultSets: [
                WorkoutDraftSet(weight: 10, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.preacher_curl"),
            systemImage: WorkoutExerciseIcon.preacherCurl,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.5,
            defaultSets: [
                WorkoutDraftSet(weight: 20, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.concentration_curl"),
            systemImage: WorkoutExerciseIcon.concentrationCurl,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.5,
            defaultSets: [
                WorkoutDraftSet(weight: 8, reps: 12)
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
            name: AppLocalizer.string("workout.exercise.chin_ups"),
            systemImage: WorkoutExerciseIcon.chinUps,
            accentName: "blue",
            activityType: .strength,
            metValue: 6.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 8)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.band_assisted_pullups"),
            systemImage: WorkoutExerciseIcon.bandAssistedPullUps,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.5,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 10)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.assisted_pullup_machine"),
            systemImage: WorkoutExerciseIcon.assistedPullUpMachine,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 30, reps: 10)
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
            name: AppLocalizer.string("workout.exercise.classic_deadlift"),
            systemImage: WorkoutExerciseIcon.classicDeadlift,
            accentName: "blue",
            activityType: .strength,
            metValue: 6.0,
            defaultSets: [
                WorkoutDraftSet(weight: 70, reps: 8)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.sumo_deadlift"),
            systemImage: WorkoutExerciseIcon.sumoDeadlift,
            accentName: "blue",
            activityType: .strength,
            metValue: 6.0,
            defaultSets: [
                WorkoutDraftSet(weight: 70, reps: 8)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.back_extension"),
            systemImage: WorkoutExerciseIcon.backExtension,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 15)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.reverse_back_extension"),
            systemImage: WorkoutExerciseIcon.reverseBackExtension,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 15)
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
