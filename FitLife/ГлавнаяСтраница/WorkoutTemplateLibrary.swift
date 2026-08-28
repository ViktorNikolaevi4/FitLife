import Foundation
import SwiftUI
import UIKit

enum WorkoutExerciseIcon {
    static let cleanAndJerk = "CleanAndJerk"
    static let barbellClean = "Взятие на грудь 1"
    static let horizontalPullUps = "Горизонтальные подтягивания"
    static let hangingLegRaise = "Подъём ног в висе"
    static let lyingLegRaise = "Подъём ног лежа"
    static let snatchPull = "Рывковая тяга"
    static let barbellSnatch = "Рывок штанги"
    static let turkishGetUp = "Турецкий подъём"
    static let medBallThrow = "Броски медбола"
    static let medBallSlam = "Броски медбола в пол"
    static let jumpingJack = "JumpingJack"
    static let run = "Бег"
    static let walking = "Ходьба"
    static let assaultBike = "Assault Bike"
    static let skiErg = "SkiErg"
    static let stairMaster = "StairMaster"
    static let runInPlank = "Бег в упоре лежа"
    static let burpee = "Бёрпи"
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
    static let barbellPushPress = "Швунг со штангой"
    static let dumbbellPushPress = "Швунг с гантелями"
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
    static let legPress = "Жим ногами"
    static let legExtension = "Разгибание ног в тренажёре"
    static let machineHipAbduction = "Отведение ног в тренажёре "
    static let bandedSeatedHipAbduction = "Отведение ног с резинкой сидя"
    static let stepUpKneeDrive = "Подъём на платформу с подъёмом колена"
    static let boxStepUp = "Зашагивания на тумбу"
    static let biceps = "Бицепс"
    static let barbellBicepsCurl = "Сгибание штанги на бицепс"
    static let ezBarBicepsCurl = "Сгибание EZ-штанги на бицепс"
    static let standingDumbbellCurl = "Сгибание гантелей стоя"
    static let hammerCurls = "Молотковые сгибания"
    static let preacherCurl = "Сгибание рук на скамье Скотта"
    static let concentrationCurl = "Концентрированное сгибание"
    static let inclineDumbbellCurl = "Сгибание гантелей на наклонной скамье"
    static let lowCableBicepsCurl = "Сгибание рук на нижнем блоке"
    static let lyingFrenchPress = "Французский жим лёжа"
    static let seatedFrenchPress = "Французский жим сидя"
    static let cableTricepsPushdown = "Разгибание рук на верхнем блоке"
    static let ropeTricepsPushdown = "Разгибание рук с канатом"
    static let singleArmTricepsExtension = "Разгибание одной руки"
    static let closeGripBenchPress = "Жим лёжа узким хватом"
    static let tricepsFocusedDips = "Отжимания на брусьях с акцентом на трицепс"
    static let benchDips = "Обратные отжимания от лавки"
    static let overheadDumbbellTricepsExtension = "Разгибание гантели из-за головы"
    static let dumbbellKickback = "Кикбэк с гантелью"
    static let sidePlank = "БоковаяПланка"
    static let elbowPlank = "Планка на локтях"
    static let deadBug = "Dead Bug"
    static let birdDog = "Bird Dog"
    static let crunches = "Скручивания на пресс"
    static let abWheelRollout = "Ролик для пресса "
    static let lunges = "Выпады "
    static let reverseLunges = "Выпады назад"
    static let bulgarianSplitSquat = "Болгарские выпады"
    static let pullUps = "Подтягивания"
    static let chinUps = "Подтягивания обратным хватом"
    static let bandAssistedPullUps = "Подтягивания с резинкой"
    static let assistedPullUpMachine = "Подтягивания в гравитроне"
    static let snatch = "Рывок"
    static let squats = "Приседания"
    static let barbellSquat = "Приседания со штангой"
    static let frontSquat = "Фронтальные приседания"
    static let gobletSquat = "Гоблет-приседания"
    static let kettlebellSquat = "Приседания с гирей"
    static let zercherSquat = "Приседания Зерхера"
    static let hackSquat = "Гак-приседания"
    static let pistolSquat = "Пистолетик"
    static let sumoSquat = "Приседания сумо"
    static let splitSquat = "Сплит-приседания"
    static let wallSit = "Статический присед у стены"
    static let jumpSquats = "Прыжковые приседания"
    static let jumpingLunges = "Прыжковые выпады"
    static let boxJumps = "Прыжки на тумбу"
    static let deadlift = "СтановаяТяга"
    static let classicDeadlift = "Классическая становая тяга"
    static let sumoDeadlift = "Становая тяга сумо"
    static let romanianDeadlift = "Румынская тяга"
    static let stiffLegDeadlift = "Тяга на прямых ногах"
    static let goodMorning = "Наклоны Good Morning"
    static let singleLegGluteBridge = "Ягодичный мост 1 ногой"
    static let barbellHipThrust = "ягодичный мост"
    static let backExtension = "Гиперэкстензия"
    static let reverseBackExtension = "Обратная гиперэкстензия"
    static let battleRopes = "канат"
    static let sledPush = "Толкание саней"
    static let jumpRope = "скакалка"
    static let lowerAbs = "Пресс нижний"
    static let oneArmRow = "тяга одной рукой"
    static let rowing = "Гребля"
    static let rowingMachine = "Гребной тренажёр"
    static let wallChestStretch = "Растяжка грудных мышц у стены"
    static let overheadTricepsStretch = "Растяжка трицепса над головой"
    static let crossBodyShoulderStretch = "Поперечная растяжка плеча"
    static let catCow = "Кошка-корова"
    static let childPose = "Поза ребёнка"
    static let cobraPose = "Кобра"
    static let lyingThoracicRotation = "Повороты грудного отдела лёжа"
    static let supineSpinalTwist = "Скручивания позвоночника лёжа"
    static let thoracicExtensionFoamRoller = "Разгибание грудного отдела на ролле"
    static let hipFlexorStretch = "Растяжка сгибателей бедра"
    static let standingQuadricepsStretch = "Растяжка квадрицепса стоя"
    static let hamstringStretch = "Растяжка задней поверхности бедра"
    static let figureFourGluteStretch = "Растяжка ягодичных “четвёрка”"
    static let pigeonPose = "Поза голубя"
    static let butterflyStretch = "Бабочка"
    static let sideLungeAdductorStretch = "Растяжка приводящих в боковом выпаде"
    static let dynamicLegSwings = "Динамические махи ногами"
    static let powerClean = "Взятие на грудь в стойку "
    static let hangClean = "Взятие на грудь с виса "
    static let blockClean = "Взятие на грудь с плинтов "
    static let powerSnatch = "Рывок в стойку "
    static let cleanPull = "Тяга толчковая "
    static let hangSnatch = "Рывок с виса "
    static let blockSnatch = "Рывок с плинтов "
    static let overheadSquat = "Приседания со штангой над головой "
    static let splitJerk = "Толчок в ножницы "
    static let kettlebellSwing = "Махи гирей "
    static let singleArmDumbbellSnatch = "Рывок гантели одной рукой "
    static let dumbbellClean = "Взятие гантелей на грудь "
    static let doubleUnders = "Двойные прыжки на скакалке "
    static let toesToBar = "Носки к перекладине "
    static let handstandPushUp = "Отжимания в стойке на руках "
    static let ropeClimb = "Лазание по канату "
    static let devilPress = "Devil Press "
    static let barMuscleUp = "Выход силой на перекладине "
    static let ringMuscleUp = "Выход силой на кольцах "
    static let handstandWalk = "Ходьба на руках "
    static let sandbagCarry = "Переноска мешка "
    static let bearCrawl = "Медвежья ходьба "
    static let boxJumpOver = "☐ Запрыгивания через тумбу "
}

private enum WorkoutAssetIconCache {
    private static var cache: [String: Bool] = [:]

    static func hasIcon(named name: String) -> Bool {
        if let cached = cache[name] {
            return cached
        }

        let hasIcon = UIImage(named: name) != nil
        cache[name] = hasIcon
        return hasIcon
    }
}

func hasWorkoutAssetIcon(named name: String) -> Bool {
    WorkoutAssetIconCache.hasIcon(named: name)
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

private enum WorkoutTemplateLibraryCache {
    private static var cachedTemplatesByLanguage: [String: [WorkoutExerciseTemplate]] = [:]

    static func templates(for language: AppLanguage = AppLocalizer.currentLanguage) -> [WorkoutExerciseTemplate] {
        if let cached = cachedTemplatesByLanguage[language.rawValue] {
            return cached
        }

        let templates = makeWorkoutTemplates()
        cachedTemplatesByLanguage[language.rawValue] = templates
        return templates
    }
}

func workoutTemplates() -> [WorkoutExerciseTemplate] {
    WorkoutTemplateLibraryCache.templates()
}

private func mobilityTemplate(
    nameKey: String,
    systemImage: String,
    durationSeconds: Int
) -> WorkoutExerciseTemplate {
    WorkoutExerciseTemplate(
        name: AppLocalizer.string(nameKey),
        systemImage: systemImage,
        accentName: "teal",
        activityType: .mobility,
        metValue: 2.5,
        defaultSets: [
            WorkoutDraftSet(
                weight: 0,
                reps: 0,
                durationSeconds: durationSeconds,
                metricType: .duration
            )
        ]
    )
}

private func makeWorkoutTemplates() -> [WorkoutExerciseTemplate] {
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
            name: AppLocalizer.string("workout.exercise.walking"),
            systemImage: WorkoutExerciseIcon.walking,
            accentName: "blue",
            activityType: .cardio,
            metValue: 3.5,
            defaultSets: [
                WorkoutDraftSet(weight: 0, durationSeconds: 1800, metricType: .duration)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.assault_bike"),
            systemImage: WorkoutExerciseIcon.assaultBike,
            accentName: "blue",
            activityType: .cardio,
            metValue: 10.5,
            defaultSets: [
                WorkoutDraftSet(weight: 0, durationSeconds: 600, metricType: .duration)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.ski_erg"),
            systemImage: WorkoutExerciseIcon.skiErg,
            accentName: "blue",
            activityType: .cardio,
            metValue: 8.5,
            defaultSets: [
                WorkoutDraftSet(weight: 0, durationSeconds: 600, metricType: .duration)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.stair_master"),
            systemImage: WorkoutExerciseIcon.stairMaster,
            accentName: "blue",
            activityType: .cardio,
            metValue: 9.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, durationSeconds: 600, metricType: .duration)
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
            name: AppLocalizer.string("workout.exercise.barbell_push_press"),
            systemImage: WorkoutExerciseIcon.barbellPushPress,
            accentName: "blue",
            activityType: .strength,
            metValue: 6.0,
            defaultSets: [
                WorkoutDraftSet(weight: 30, reps: 8)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.dumbbell_push_press"),
            systemImage: WorkoutExerciseIcon.dumbbellPushPress,
            accentName: "blue",
            activityType: .strength,
            metValue: 6.0,
            defaultSets: [
                WorkoutDraftSet(weight: 12, reps: 8)
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
            name: AppLocalizer.string("workout.exercise.leg_extension"),
            systemImage: WorkoutExerciseIcon.legExtension,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.5,
            defaultSets: [
                WorkoutDraftSet(weight: 35, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.machine_hip_abduction"),
            systemImage: WorkoutExerciseIcon.machineHipAbduction,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.0,
            defaultSets: [
                WorkoutDraftSet(weight: 35, reps: 15)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.banded_seated_hip_abduction"),
            systemImage: WorkoutExerciseIcon.bandedSeatedHipAbduction,
            accentName: "blue",
            activityType: .strength,
            metValue: 3.5,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 20)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.step_up_knee_drive"),
            systemImage: WorkoutExerciseIcon.stepUpKneeDrive,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.5,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.box_step_up"),
            systemImage: WorkoutExerciseIcon.boxStepUp,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 10)
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
            name: AppLocalizer.string("workout.exercise.incline_dumbbell_curl"),
            systemImage: WorkoutExerciseIcon.inclineDumbbellCurl,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.5,
            defaultSets: [
                WorkoutDraftSet(weight: 8, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.low_cable_biceps_curl"),
            systemImage: WorkoutExerciseIcon.lowCableBicepsCurl,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.5,
            defaultSets: [
                WorkoutDraftSet(weight: 20, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.lying_french_press"),
            systemImage: WorkoutExerciseIcon.lyingFrenchPress,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.0,
            defaultSets: [
                WorkoutDraftSet(weight: 20, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.seated_french_press"),
            systemImage: WorkoutExerciseIcon.seatedFrenchPress,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.0,
            defaultSets: [
                WorkoutDraftSet(weight: 18, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.cable_triceps_pushdown"),
            systemImage: WorkoutExerciseIcon.cableTricepsPushdown,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.0,
            defaultSets: [
                WorkoutDraftSet(weight: 25, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.rope_triceps_pushdown"),
            systemImage: WorkoutExerciseIcon.ropeTricepsPushdown,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.0,
            defaultSets: [
                WorkoutDraftSet(weight: 20, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.single_arm_triceps_extension"),
            systemImage: WorkoutExerciseIcon.singleArmTricepsExtension,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.0,
            defaultSets: [
                WorkoutDraftSet(weight: 8, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.close_grip_bench_press"),
            systemImage: WorkoutExerciseIcon.closeGripBenchPress,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 40, reps: 10)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.triceps_focused_dips"),
            systemImage: WorkoutExerciseIcon.tricepsFocusedDips,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 10)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.bench_dips"),
            systemImage: WorkoutExerciseIcon.benchDips,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.overhead_dumbbell_triceps_extension"),
            systemImage: WorkoutExerciseIcon.overheadDumbbellTricepsExtension,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.0,
            defaultSets: [
                WorkoutDraftSet(weight: 16, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.dumbbell_kickback"),
            systemImage: WorkoutExerciseIcon.dumbbellKickback,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.0,
            defaultSets: [
                WorkoutDraftSet(weight: 6, reps: 12)
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
            name: AppLocalizer.string("workout.exercise.rowing_machine"),
            systemImage: WorkoutExerciseIcon.rowingMachine,
            accentName: "blue",
            activityType: .cardio,
            metValue: 7.0,
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
            name: AppLocalizer.string("workout.exercise.run_in_plank"),
            systemImage: WorkoutExerciseIcon.runInPlank,
            accentName: "blue",
            activityType: .hiit,
            metValue: 8.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, durationSeconds: 45, metricType: .duration)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.burpee"),
            systemImage: WorkoutExerciseIcon.burpee,
            accentName: "blue",
            activityType: .hiit,
            metValue: 9.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 10)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.barbell_squat"),
            systemImage: WorkoutExerciseIcon.barbellSquat,
            accentName: "blue",
            activityType: .strength,
            metValue: 6.0,
            defaultSets: [
                WorkoutDraftSet(weight: 50, reps: 10)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.front_squat"),
            systemImage: WorkoutExerciseIcon.frontSquat,
            accentName: "blue",
            activityType: .strength,
            metValue: 6.0,
            defaultSets: [
                WorkoutDraftSet(weight: 40, reps: 8)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.goblet_squat"),
            systemImage: WorkoutExerciseIcon.gobletSquat,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.5,
            defaultSets: [
                WorkoutDraftSet(weight: 20, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.kettlebell_squat"),
            systemImage: WorkoutExerciseIcon.kettlebellSquat,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.5,
            defaultSets: [
                WorkoutDraftSet(weight: 16, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.sumo_squat"),
            systemImage: WorkoutExerciseIcon.sumoSquat,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.5,
            defaultSets: [
                WorkoutDraftSet(weight: 20, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.zercher_squat"),
            systemImage: WorkoutExerciseIcon.zercherSquat,
            accentName: "blue",
            activityType: .strength,
            metValue: 6.0,
            defaultSets: [
                WorkoutDraftSet(weight: 40, reps: 8)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.hack_squat"),
            systemImage: WorkoutExerciseIcon.hackSquat,
            accentName: "blue",
            activityType: .strength,
            metValue: 6.0,
            defaultSets: [
                WorkoutDraftSet(weight: 60, reps: 10)
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
            name: AppLocalizer.string("workout.exercise.reverse_lunges"),
            systemImage: WorkoutExerciseIcon.reverseLunges,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.5,
            defaultSets: [
                WorkoutDraftSet(weight: 12, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.bulgarian_split_squat"),
            systemImage: WorkoutExerciseIcon.bulgarianSplitSquat,
            accentName: "blue",
            activityType: .strength,
            metValue: 6.0,
            defaultSets: [
                WorkoutDraftSet(weight: 12, reps: 10)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.split_squat"),
            systemImage: WorkoutExerciseIcon.splitSquat,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.5,
            defaultSets: [
                WorkoutDraftSet(weight: 12, reps: 10)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.wall_sit"),
            systemImage: WorkoutExerciseIcon.wallSit,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, durationSeconds: 45, metricType: .duration)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.jump_squats"),
            systemImage: WorkoutExerciseIcon.jumpSquats,
            accentName: "blue",
            activityType: .hiit,
            metValue: 8.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 15)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.jumping_lunges"),
            systemImage: WorkoutExerciseIcon.jumpingLunges,
            accentName: "blue",
            activityType: .hiit,
            metValue: 8.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 12)
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
            name: AppLocalizer.string("workout.exercise.elbow_plank"),
            systemImage: WorkoutExerciseIcon.elbowPlank,
            accentName: "blue",
            activityType: .core,
            metValue: 3.5,
            defaultSets: [
                WorkoutDraftSet(weight: 0, durationSeconds: 45, metricType: .duration)
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
            name: AppLocalizer.string("workout.exercise.dead_bug"),
            systemImage: WorkoutExerciseIcon.deadBug,
            accentName: "blue",
            activityType: .core,
            metValue: 3.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 10)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.bird_dog"),
            systemImage: WorkoutExerciseIcon.birdDog,
            accentName: "blue",
            activityType: .core,
            metValue: 3.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 10)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.crunches"),
            systemImage: WorkoutExerciseIcon.crunches,
            accentName: "blue",
            activityType: .core,
            metValue: 3.8,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 15)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.ab_wheel_rollout"),
            systemImage: WorkoutExerciseIcon.abWheelRollout,
            accentName: "blue",
            activityType: .core,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 10)
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
            name: AppLocalizer.string("workout.exercise.romanian_deadlift"),
            systemImage: WorkoutExerciseIcon.romanianDeadlift,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.5,
            defaultSets: [
                WorkoutDraftSet(weight: 50, reps: 10)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.stiff_leg_deadlift"),
            systemImage: WorkoutExerciseIcon.stiffLegDeadlift,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.5,
            defaultSets: [
                WorkoutDraftSet(weight: 40, reps: 10)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.good_morning"),
            systemImage: WorkoutExerciseIcon.goodMorning,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.0,
            defaultSets: [
                WorkoutDraftSet(weight: 20, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.barbell_hip_thrust"),
            systemImage: WorkoutExerciseIcon.barbellHipThrust,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.5,
            defaultSets: [
                WorkoutDraftSet(weight: 50, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.single_leg_glute_bridge"),
            systemImage: WorkoutExerciseIcon.singleLegGluteBridge,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 12)
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
            name: AppLocalizer.string("workout.exercise.sled_push"),
            systemImage: WorkoutExerciseIcon.sledPush,
            accentName: "blue",
            activityType: .hiit,
            metValue: 8.0,
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
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.barbell_clean"),
            systemImage: WorkoutExerciseIcon.barbellClean,
            accentName: "blue",
            activityType: .strength,
            metValue: 7.0,
            defaultSets: [
                WorkoutDraftSet(weight: 40, reps: 6)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.horizontal_pullups"),
            systemImage: WorkoutExerciseIcon.horizontalPullUps,
            accentName: "blue",
            activityType: .strength,
            metValue: 4.5,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.hanging_leg_raise"),
            systemImage: WorkoutExerciseIcon.hangingLegRaise,
            accentName: "blue",
            activityType: .core,
            metValue: 4.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.lying_leg_raise"),
            systemImage: WorkoutExerciseIcon.lyingLegRaise,
            accentName: "blue",
            activityType: .core,
            metValue: 3.5,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 15)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.snatch_pull"),
            systemImage: WorkoutExerciseIcon.snatchPull,
            accentName: "blue",
            activityType: .strength,
            metValue: 6.5,
            defaultSets: [
                WorkoutDraftSet(weight: 40, reps: 6)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.barbell_snatch"),
            systemImage: WorkoutExerciseIcon.barbellSnatch,
            accentName: "blue",
            activityType: .hiit,
            metValue: 7.0,
            defaultSets: [
                WorkoutDraftSet(weight: 35, reps: 6)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.power_clean"),
            systemImage: WorkoutExerciseIcon.powerClean,
            accentName: "blue",
            activityType: .strength,
            metValue: 7.0,
            defaultSets: [WorkoutDraftSet(weight: 40, reps: 5)]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.hang_clean"),
            systemImage: WorkoutExerciseIcon.hangClean,
            accentName: "blue",
            activityType: .strength,
            metValue: 7.0,
            defaultSets: [WorkoutDraftSet(weight: 40, reps: 5)]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.block_clean"),
            systemImage: WorkoutExerciseIcon.blockClean,
            accentName: "blue",
            activityType: .strength,
            metValue: 7.0,
            defaultSets: [WorkoutDraftSet(weight: 40, reps: 5)]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.power_snatch"),
            systemImage: WorkoutExerciseIcon.powerSnatch,
            accentName: "blue",
            activityType: .strength,
            metValue: 7.0,
            defaultSets: [WorkoutDraftSet(weight: 30, reps: 5)]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.clean_pull"),
            systemImage: WorkoutExerciseIcon.cleanPull,
            accentName: "blue",
            activityType: .strength,
            metValue: 6.5,
            defaultSets: [WorkoutDraftSet(weight: 50, reps: 5)]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.hang_snatch"),
            systemImage: WorkoutExerciseIcon.hangSnatch,
            accentName: "blue",
            activityType: .strength,
            metValue: 7.0,
            defaultSets: [WorkoutDraftSet(weight: 30, reps: 5)]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.block_snatch"),
            systemImage: WorkoutExerciseIcon.blockSnatch,
            accentName: "blue",
            activityType: .strength,
            metValue: 7.0,
            defaultSets: [WorkoutDraftSet(weight: 30, reps: 5)]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.overhead_squat"),
            systemImage: WorkoutExerciseIcon.overheadSquat,
            accentName: "blue",
            activityType: .strength,
            metValue: 6.0,
            defaultSets: [WorkoutDraftSet(weight: 30, reps: 8)]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.split_jerk"),
            systemImage: WorkoutExerciseIcon.splitJerk,
            accentName: "blue",
            activityType: .strength,
            metValue: 7.0,
            defaultSets: [WorkoutDraftSet(weight: 40, reps: 5)]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.kettlebell_swing"),
            systemImage: WorkoutExerciseIcon.kettlebellSwing,
            accentName: "blue",
            activityType: .hiit,
            metValue: 9.0,
            defaultSets: [WorkoutDraftSet(weight: 16, reps: 15)]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.single_arm_dumbbell_snatch"),
            systemImage: WorkoutExerciseIcon.singleArmDumbbellSnatch,
            accentName: "blue",
            activityType: .hiit,
            metValue: 8.0,
            defaultSets: [WorkoutDraftSet(weight: 16, reps: 8)]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.dumbbell_clean"),
            systemImage: WorkoutExerciseIcon.dumbbellClean,
            accentName: "blue",
            activityType: .hiit,
            metValue: 8.0,
            defaultSets: [WorkoutDraftSet(weight: 12, reps: 8)]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.double_unders"),
            systemImage: WorkoutExerciseIcon.doubleUnders,
            accentName: "blue",
            activityType: .hiit,
            metValue: 12.0,
            defaultSets: [WorkoutDraftSet(weight: 0, reps: 50)]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.toes_to_bar"),
            systemImage: WorkoutExerciseIcon.toesToBar,
            accentName: "blue",
            activityType: .core,
            metValue: 5.0,
            defaultSets: [WorkoutDraftSet(weight: 0, reps: 10)]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.handstand_push_up"),
            systemImage: WorkoutExerciseIcon.handstandPushUp,
            accentName: "blue",
            activityType: .strength,
            metValue: 6.0,
            defaultSets: [WorkoutDraftSet(weight: 0, reps: 8)]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.rope_climb"),
            systemImage: WorkoutExerciseIcon.ropeClimb,
            accentName: "blue",
            activityType: .strength,
            metValue: 8.0,
            defaultSets: [WorkoutDraftSet(weight: 0, reps: 3)]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.devil_press"),
            systemImage: WorkoutExerciseIcon.devilPress,
            accentName: "blue",
            activityType: .hiit,
            metValue: 10.0,
            defaultSets: [WorkoutDraftSet(weight: 10, reps: 10)]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.bar_muscle_up"),
            systemImage: WorkoutExerciseIcon.barMuscleUp,
            accentName: "blue",
            activityType: .strength,
            metValue: 7.0,
            defaultSets: [WorkoutDraftSet(weight: 0, reps: 5)]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.ring_muscle_up"),
            systemImage: WorkoutExerciseIcon.ringMuscleUp,
            accentName: "blue",
            activityType: .strength,
            metValue: 7.0,
            defaultSets: [WorkoutDraftSet(weight: 0, reps: 5)]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.handstand_walk"),
            systemImage: WorkoutExerciseIcon.handstandWalk,
            accentName: "blue",
            activityType: .core,
            metValue: 6.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, durationSeconds: 30, metricType: .duration)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.sandbag_carry"),
            systemImage: WorkoutExerciseIcon.sandbagCarry,
            accentName: "blue",
            activityType: .strength,
            metValue: 7.0,
            defaultSets: [
                WorkoutDraftSet(weight: 20, durationSeconds: 60, metricType: .duration)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.bear_crawl"),
            systemImage: WorkoutExerciseIcon.bearCrawl,
            accentName: "blue",
            activityType: .hiit,
            metValue: 8.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, durationSeconds: 45, metricType: .duration)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.box_jump_over"),
            systemImage: WorkoutExerciseIcon.boxJumpOver,
            accentName: "blue",
            activityType: .hiit,
            metValue: 9.0,
            defaultSets: [WorkoutDraftSet(weight: 0, reps: 12)]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.turkish_getup"),
            systemImage: WorkoutExerciseIcon.turkishGetUp,
            accentName: "blue",
            activityType: .strength,
            metValue: 5.0,
            defaultSets: [
                WorkoutDraftSet(weight: 12, reps: 6)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.med_ball_throw"),
            systemImage: WorkoutExerciseIcon.medBallThrow,
            accentName: "blue",
            activityType: .hiit,
            metValue: 7.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 12)
            ]
        ),
        WorkoutExerciseTemplate(
            name: AppLocalizer.string("workout.exercise.med_ball_slam"),
            systemImage: WorkoutExerciseIcon.medBallSlam,
            accentName: "blue",
            activityType: .hiit,
            metValue: 8.0,
            defaultSets: [
                WorkoutDraftSet(weight: 0, reps: 12)
            ]
        ),
        mobilityTemplate(
            nameKey: "workout.exercise.wall_chest_stretch",
            systemImage: WorkoutExerciseIcon.wallChestStretch,
            durationSeconds: 30
        ),
        mobilityTemplate(
            nameKey: "workout.exercise.overhead_triceps_stretch",
            systemImage: WorkoutExerciseIcon.overheadTricepsStretch,
            durationSeconds: 30
        ),
        mobilityTemplate(
            nameKey: "workout.exercise.cross_body_shoulder_stretch",
            systemImage: WorkoutExerciseIcon.crossBodyShoulderStretch,
            durationSeconds: 30
        ),
        mobilityTemplate(
            nameKey: "workout.exercise.cat_cow",
            systemImage: WorkoutExerciseIcon.catCow,
            durationSeconds: 60
        ),
        mobilityTemplate(
            nameKey: "workout.exercise.child_pose",
            systemImage: WorkoutExerciseIcon.childPose,
            durationSeconds: 60
        ),
        mobilityTemplate(
            nameKey: "workout.exercise.cobra_pose",
            systemImage: WorkoutExerciseIcon.cobraPose,
            durationSeconds: 30
        ),
        mobilityTemplate(
            nameKey: "workout.exercise.lying_thoracic_rotation",
            systemImage: WorkoutExerciseIcon.lyingThoracicRotation,
            durationSeconds: 45
        ),
        mobilityTemplate(
            nameKey: "workout.exercise.supine_spinal_twist",
            systemImage: WorkoutExerciseIcon.supineSpinalTwist,
            durationSeconds: 45
        ),
        mobilityTemplate(
            nameKey: "workout.exercise.thoracic_extension_foam_roller",
            systemImage: WorkoutExerciseIcon.thoracicExtensionFoamRoller,
            durationSeconds: 60
        ),
        mobilityTemplate(
            nameKey: "workout.exercise.hip_flexor_stretch",
            systemImage: WorkoutExerciseIcon.hipFlexorStretch,
            durationSeconds: 45
        ),
        mobilityTemplate(
            nameKey: "workout.exercise.standing_quadriceps_stretch",
            systemImage: WorkoutExerciseIcon.standingQuadricepsStretch,
            durationSeconds: 30
        ),
        mobilityTemplate(
            nameKey: "workout.exercise.hamstring_stretch",
            systemImage: WorkoutExerciseIcon.hamstringStretch,
            durationSeconds: 45
        ),
        mobilityTemplate(
            nameKey: "workout.exercise.figure_four_glute_stretch",
            systemImage: WorkoutExerciseIcon.figureFourGluteStretch,
            durationSeconds: 45
        ),
        mobilityTemplate(
            nameKey: "workout.exercise.pigeon_pose",
            systemImage: WorkoutExerciseIcon.pigeonPose,
            durationSeconds: 60
        ),
        mobilityTemplate(
            nameKey: "workout.exercise.butterfly_stretch",
            systemImage: WorkoutExerciseIcon.butterflyStretch,
            durationSeconds: 60
        ),
        mobilityTemplate(
            nameKey: "workout.exercise.side_lunge_adductor_stretch",
            systemImage: WorkoutExerciseIcon.sideLungeAdductorStretch,
            durationSeconds: 45
        ),
        mobilityTemplate(
            nameKey: "workout.exercise.dynamic_leg_swings",
            systemImage: WorkoutExerciseIcon.dynamicLegSwings,
            durationSeconds: 60
        )
    ]
}
