import SwiftUI
import SwiftData
import Combine
import UIKit

struct WorkoutBlockRunnerScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let block: WorkoutBlock
    let onFinish: () -> Void

    @State private var now = Date()
    @State private var showSkipConfirmation = false
    @State private var showRestartConfirmation = false
    @State private var lastCuedPhaseEnd: Date?
    @State private var lastCuedSecond: Int?

    private let ticker = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    private var exercises: [WorkoutExercise] {
        block.exerciseItems.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var preset: WorkoutBlockPreset {
        block.preset
    }

    private var isIntervalBlock: Bool {
        preset == .tabata || preset == .hiit
    }

    private var isTimedBlock: Bool {
        isIntervalBlock || block.mode == .amrap || block.mode == .emom || preset == .forTime
    }

    private var currentExercise: WorkoutExercise? {
        guard exercises.isEmpty == false else { return nil }
        return exercises[min(max(block.currentExerciseIndex, 0), exercises.count - 1)]
    }

    private var totalRounds: Int {
        max(block.rounds, 1)
    }

    private var currentRoundNumber: Int {
        min(block.currentRoundIndex + 1, totalRounds)
    }

    private var remainingSeconds: Int {
        if block.runnerPhase == .paused {
            return max(block.pausedRemainingSeconds, 0)
        }
        guard let end = block.phaseEndsAt else { return 0 }
        return max(Int(ceil(end.timeIntervalSince(now))), 0)
    }

    private var phaseDuration: Int {
        switch block.runnerPhase {
        case .rest:
            return max(block.restSeconds > 0 ? block.restSeconds : block.restBetweenRoundsSeconds, 1)
        case .work, .paused:
            if isIntervalBlock { return max(block.workSeconds, 1) }
            if block.mode == .emom { return emomIntervalSeconds }
            return max(block.durationMinutes * 60, 1)
        case .ready, .completed:
            return 1
        }
    }

    private var timerProgress: Double {
        guard phaseDuration > 0 else { return 0 }
        return min(max(1 - Double(remainingSeconds) / Double(phaseDuration), 0), 1)
    }

    private var emomIntervalSeconds: Int {
        switch preset {
        case .e2mom: return 120
        case .e3mom: return 180
        default: return 60
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                progressSummary

                if isTimedBlock {
                    timerCard
                }

                if isIntervalBlock {
                    intervalHistoryCard
                }

                exerciseSequenceCard

                if block.restBetweenRoundsSeconds > 0 && isIntervalBlock == false {
                    infoCard(
                        icon: "timer",
                        title: "Отдых после раунда",
                        value: formatClock(block.restBetweenRoundsSeconds)
                    )
                }

                trainerHintCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 150)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(block.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            controls
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(.bar)
        }
        .onAppear {
            now = Date()
            normalizeRestoredState()
        }
        .onReceive(ticker) { date in
            now = date
            playTimerCueIfNeeded()
            handleTimerTick()
        }
        .confirmationDialog(
            "Пропустить блок?",
            isPresented: $showSkipConfirmation,
            titleVisibility: .visible
        ) {
            Button("Пропустить блок", role: .destructive) {
                finishBlock(markExercisesFinished: false)
            }
            Button("Продолжить тренировку", role: .cancel) {}
        } message: {
            Text("Незавершённые подходы и интервалы останутся без отметки.")
        }
        .confirmationDialog(
            "Пройти блок заново?",
            isPresented: $showRestartConfirmation,
            titleVisibility: .visible
        ) {
            Button("Сбросить результаты и начать заново", role: .destructive) {
                restartBlock()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Отметки подходов и интервалов этого блока будут сброшены.")
        }
    }

    private var progressSummary: some View {
        HStack(spacing: 12) {
            runnerMetric(icon: "arrow.triangle.2.circlepath", title: progressMetricTitle, value: progressMetricValue)
            runnerMetric(icon: "figure.strengthtraining.traditional", title: "Упражнений", value: "\(exercises.count)")
            runnerMetric(icon: "checkmark.circle", title: completionMetricTitle, value: completionMetricValue)
        }
    }

    private var completionMetricTitle: String {
        isIntervalBlock ? "Интервалов" : "Выполнено"
    }

    private var completionMetricValue: String {
        isIntervalBlock
            ? "\(block.completedIntervalIndexes.count) из \(totalRounds)"
            : "\(completedExerciseCount)"
    }

    private var progressMetricTitle: String {
        if block.mode == .amrap { return "Раундов" }
        if block.mode == .emom { return "Интервал" }
        if preset == .forTime { return "Режим" }
        return isIntervalBlock ? "Интервал" : "Раунд"
    }

    private var progressMetricValue: String {
        if block.mode == .amrap { return "\(block.currentRoundIndex)" }
        if block.mode == .emom {
            let intervalCount = max(block.durationMinutes * 60 / emomIntervalSeconds, 1)
            return "\(min(block.currentRoundIndex + 1, intervalCount)) из \(intervalCount)"
        }
        if preset == .forTime { return "На время" }
        return "\(currentRoundNumber) из \(totalRounds)"
    }

    private var completedExerciseCount: Int {
        exercises.filter(\.isFinished).count
    }

    private func runnerMetric(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(.blue)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color(.separator).opacity(0.35)))
    }

    private var timerCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: timerProgress)
                    .stroke(
                        block.runnerPhase == .rest ? Color.green : Color.blue,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 7) {
                    Text(phaseTitle.uppercased())
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(block.runnerPhase == .rest ? Color.green : Color.blue)
                    Text(formatClock(remainingSeconds))
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                    Text(currentExercise?.name ?? block.title)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(30)
            }
            .frame(maxWidth: 310)
            .frame(height: 310)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(phaseTitle), осталось \(remainingSeconds) секунд, \(currentExercise?.name ?? block.title)")

            Text(timerDetail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color(.secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color(.separator).opacity(0.35)))
    }

    private var phaseTitle: String {
        switch block.runnerPhase {
        case .ready: return "Готово к старту"
        case .work: return "Работа"
        case .rest: return "Отдых"
        case .paused: return "Пауза"
        case .completed: return "Завершено"
        }
    }

    private var timerDetail: String {
        if isIntervalBlock {
            return "Интервал \(currentRoundNumber) из \(totalRounds) • \(block.workSeconds) сек работа • \(block.restSeconds) сек отдых"
        }
        if block.mode == .emom {
            return "Интервал \(block.currentRoundIndex + 1) • каждые \(emomIntervalSeconds / 60) мин"
        }
        if block.mode == .amrap {
            return "Выполнено раундов: \(block.currentRoundIndex)"
        }
        return "Лимит времени: \(block.durationMinutes) мин"
    }

    private var exerciseSequenceCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: preset.iconName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.blue.opacity(0.12)))

                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.title)
                        .font(.title3.weight(.bold))
                    Text(sequenceSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(16)

            ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                Divider().padding(.leading, 76)
                NavigationLink {
                    WorkoutExerciseDetailScreen(
                        exercise: exercise,
                        followingExercises: [],
                        onOpenExercise: { _ in }
                    )
                } label: {
                    exerciseRow(exercise, index: index)
                }
                .buttonStyle(.plain)
            }
        }
        .background(RoundedRectangle(cornerRadius: 24).fill(Color(.secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color(.separator).opacity(0.35)))
    }

    private var intervalHistoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Интервалы")
                    .font(.headline)
                Spacer()
                Text("\(block.completedIntervalIndexes.count) из \(totalRounds) выполнено")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(0..<totalRounds, id: \.self) { index in
                        intervalStatus(index)
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color(.separator).opacity(0.35)))
    }

    private func intervalStatus(_ index: Int) -> some View {
        let isCompleted = block.completedIntervalIndexes.contains(index)
        let isCurrent = block.isFinished == false && index == block.currentRoundIndex

        return VStack(spacing: 5) {
            Image(systemName: isCompleted ? "checkmark" : (isCurrent ? "circle.fill" : "minus"))
                .font(.caption.weight(.bold))
            Text("\(index + 1)")
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(isCompleted ? Color.white : (isCurrent ? Color.blue : Color.secondary))
        .frame(width: 44, height: 44)
        .background(
            Circle().fill(
                isCompleted
                    ? Color.green
                    : (isCurrent ? Color.blue.opacity(0.14) : Color(.systemGray5))
            )
        )
        .overlay {
            if isCurrent && isCompleted == false {
                Circle().strokeBorder(Color.blue, lineWidth: 1.5)
            }
        }
        .accessibilityLabel(
            isCompleted
                ? "Интервал \(index + 1), выполнен"
                : (isCurrent ? "Интервал \(index + 1), текущий" : "Интервал \(index + 1), пропущен")
        )
    }

    private var sequenceSubtitle: String {
        if block.type == .superset { return "\(exercises.count) упражнения • \(totalRounds) раунда" }
        if isIntervalBlock { return "\(totalRounds) интервалов" }
        return "\(exercises.count) упражнения • \(totalRounds) раунда"
    }

    private func exerciseRow(_ exercise: WorkoutExercise, index: Int) -> some View {
        let isCurrent = block.runnerPhase != .rest && index == block.currentExerciseIndex && block.isFinished == false
        let completedSet = setForCurrentRound(in: exercise)?.isCompleted == true

        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(workoutAccentColor(exercise.accentName).opacity(0.15))
                workoutIconImage(named: exercise.systemImage, accentName: exercise.accentName, size: 18, customAssetScale: 2.35)
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    if block.type == .superset {
                        Text("A\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(isCurrent ? .white : .secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(isCurrent ? Color.blue : Color(.systemGray5)))
                    }
                    Text(exercise.name)
                        .font(.headline)
                        .lineLimit(2)
                }
                Text(exerciseMetric(exercise))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if completedSet {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                    .accessibilityLabel("Выполнено")
            } else if isCurrent {
                Text("Текущая")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.blue))
            }
        }
        .padding(14)
        .background(isCurrent ? Color.blue.opacity(0.08) : Color.clear)
        .overlay {
            if isCurrent {
                RoundedRectangle(cornerRadius: 17).strokeBorder(Color.blue, lineWidth: 1.5)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func exerciseMetric(_ exercise: WorkoutExercise) -> String {
        guard let set = setForCurrentRound(in: exercise) ?? exercise.setItems.sorted(by: { $0.orderIndex < $1.orderIndex }).first else {
            return "Параметры не заданы"
        }
        return formattedWorkoutSetValue(
            weight: set.weight,
            reps: set.reps,
            durationSeconds: set.durationSeconds,
            metricType: set.metricType
        )
    }

    private var trainerHintCard: some View {
        let notes = exercises.map(\.note).filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
        return Group {
            if let note = notes.first {
                infoCard(icon: "star", title: "Подсказка тренера", value: note)
            }
        }
    }

    private func infoCard(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.blue.opacity(0.12)))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(value).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color(.separator).opacity(0.35)))
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Button(action: primaryAction) {
                Label(primaryActionTitle, systemImage: primaryActionIcon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(RoundedRectangle(cornerRadius: 18).fill(HomeColors.primaryActionGradient))
            }
            .buttonStyle(.plain)
            .disabled(exercises.isEmpty)
            .opacity(exercises.isEmpty ? 0.5 : 1)

            if block.runnerPhase == .completed {
                Button("Пройти блок заново") {
                    showRestartConfirmation = true
                }
                .font(.headline.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.blue, lineWidth: 1.5))
                .buttonStyle(.plain)
            } else {
                Button(secondaryActionTitle, action: secondaryAction)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.blue, lineWidth: 1.5))
                    .buttonStyle(.plain)
            }
        }
    }

    private var primaryActionTitle: String {
        switch block.runnerPhase {
        case .ready: return "Начать блок"
        case .paused: return "Продолжить"
        case .completed: return "Вернуться к тренировке"
        case .rest: return "Пауза"
        case .work:
            if isTimedBlock { return "Пауза" }
            return "Завершить \(currentExerciseLabel)"
        }
    }

    private var primaryActionIcon: String {
        switch block.runnerPhase {
        case .ready, .paused: return "play.fill"
        case .completed: return "checkmark.circle.fill"
        case .rest: return "pause.fill"
        case .work: return isTimedBlock ? "pause.fill" : "checkmark.circle.fill"
        }
    }

    private var currentExerciseLabel: String {
        guard let currentExercise else { return "упражнение" }
        if block.type == .superset { return "A\(block.currentExerciseIndex + 1)" }
        return currentExercise.name
    }

    private var secondaryActionTitle: String {
        if block.runnerPhase == .rest { return "Пропустить отдых" }
        if isIntervalBlock && block.runnerPhase == .work { return "Пропустить интервал" }
        if block.mode == .amrap && block.runnerPhase == .work { return "Раунд выполнен" }
        if preset == .forTime && block.runnerPhase == .work { return "Завершить блок" }
        return "Пропустить блок"
    }

    private func primaryAction() {
        switch block.runnerPhase {
        case .ready:
            startBlock()
        case .paused:
            resumeTimer()
        case .completed:
            onFinish()
            dismiss()
        case .rest:
            pauseTimer()
        case .work:
            if isTimedBlock { pauseTimer() } else { completeCurrentExercise() }
        }
    }

    private func secondaryAction() {
        if block.runnerPhase == .rest {
            finishRest()
        } else if isIntervalBlock && block.runnerPhase == .work {
            finishWorkInterval(markCompleted: false)
        } else if block.mode == .amrap && block.runnerPhase == .work {
            block.currentRoundIndex += 1
            save()
        } else if preset == .forTime && block.runnerPhase == .work {
            finishBlock(markExercisesFinished: true)
        } else {
            showSkipConfirmation = true
        }
    }

    private func startBlock() {
        block.runnerStartedAt = block.runnerStartedAt ?? Date()
        block.currentRoundIndex = max(block.currentRoundIndex, 0)
        block.currentExerciseIndex = min(max(block.currentExerciseIndex, 0), max(exercises.count - 1, 0))
        block.runnerPhase = .work

        if isIntervalBlock {
            startPhase(seconds: max(block.workSeconds, 1))
        } else if block.mode == .emom {
            startPhase(seconds: emomIntervalSeconds)
        } else if block.mode == .amrap || preset == .forTime {
            startPhase(seconds: max(block.durationMinutes * 60, 1))
        } else {
            block.phaseEndsAt = nil
            save()
        }
    }

    private func startPhase(seconds: Int) {
        block.phaseEndsAt = Date().addingTimeInterval(TimeInterval(max(seconds, 1)))
        block.pausedRemainingSeconds = 0
        save()
    }

    private func pauseTimer() {
        guard block.runnerPhase == .work || block.runnerPhase == .rest else { return }
        block.phaseBeforePause = block.runnerPhase
        block.pausedRemainingSeconds = remainingSeconds
        block.runnerPhase = .paused
        block.phaseEndsAt = nil
        save()
    }

    private func resumeTimer() {
        let phase = block.phaseBeforePause == .rest ? WorkoutBlockRunnerPhase.rest : .work
        block.runnerPhase = phase
        startPhase(seconds: max(block.pausedRemainingSeconds, 1))
    }

    private func completeCurrentExercise() {
        guard let exercise = currentExercise else { return }
        setForCurrentRound(in: exercise)?.isCompleted = true

        if block.currentExerciseIndex + 1 < exercises.count {
            block.currentExerciseIndex += 1
            save()
            return
        }

        if block.currentRoundIndex + 1 >= totalRounds {
            finishBlock(markExercisesFinished: true)
        } else if block.restBetweenRoundsSeconds > 0 {
            block.runnerPhase = .rest
            startPhase(seconds: block.restBetweenRoundsSeconds)
        } else {
            advanceToNextRound()
        }
    }

    private func advanceToNextRound() {
        block.currentRoundIndex += 1
        block.currentExerciseIndex = 0
        block.runnerPhase = .work
        block.phaseEndsAt = nil
        save()
    }

    private func finishWorkInterval(markCompleted: Bool) {
        if markCompleted {
            block.completedIntervalIndexes.insert(block.currentRoundIndex)
            if let exercise = currentExercise {
                setForCurrentRound(in: exercise)?.isCompleted = true
            }
        }

        if block.currentRoundIndex + 1 >= totalRounds {
            finishBlock(markExercisesFinished: markCompleted)
        } else if block.restSeconds > 0 {
            block.runnerPhase = .rest
            startPhase(seconds: block.restSeconds)
        } else {
            advanceInterval()
        }
    }

    private func finishRest() {
        if isIntervalBlock {
            advanceInterval()
        } else {
            advanceToNextRound()
        }
    }

    private func advanceInterval() {
        block.currentRoundIndex += 1
        if exercises.isEmpty == false {
            block.currentExerciseIndex = block.currentRoundIndex % exercises.count
        }
        block.runnerPhase = .work
        startPhase(seconds: max(block.workSeconds, 1))
    }

    private func finishBlock(markExercisesFinished: Bool) {
        block.isFinished = true
        block.runnerPhase = .completed
        block.runnerCompletedAt = Date()
        block.phaseEndsAt = nil
        if markExercisesFinished {
            exercises.forEach { $0.isFinished = true }
        }
        save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onFinish()
    }

    private func restartBlock() {
        block.isFinished = false
        block.currentRoundIndex = 0
        block.currentExerciseIndex = 0
        block.runnerPhase = .ready
        block.phaseBeforePause = .work
        block.phaseEndsAt = nil
        block.pausedRemainingSeconds = 0
        block.runnerStartedAt = nil
        block.runnerCompletedAt = nil
        block.completedIntervalIndexes = []

        for exercise in exercises {
            exercise.isFinished = false
            exercise.setItems.forEach { $0.isCompleted = false }
        }
        save()
    }

    private func handleTimerTick() {
        guard block.runnerPhase == .work || block.runnerPhase == .rest else { return }
        guard block.phaseEndsAt != nil else { return }
        guard remainingSeconds == 0 else { return }

        if block.runnerPhase == .rest {
            finishRest()
        } else if isIntervalBlock {
            finishWorkInterval(markCompleted: true)
        } else if block.mode == .emom {
            block.completedIntervalIndexes.insert(block.currentRoundIndex)
            let totalSeconds = max(block.durationMinutes * 60, emomIntervalSeconds)
            let elapsed = Int(Date().timeIntervalSince(block.runnerStartedAt ?? Date()))
            if elapsed >= totalSeconds {
                finishBlock(markExercisesFinished: true)
            } else {
                block.currentRoundIndex += 1
                if exercises.isEmpty == false {
                    block.currentExerciseIndex = block.currentRoundIndex % exercises.count
                }
                startPhase(seconds: emomIntervalSeconds)
            }
        } else {
            finishBlock(markExercisesFinished: true)
        }
    }

    private func playTimerCueIfNeeded() {
        guard block.runnerPhase == .work || block.runnerPhase == .rest,
              let phaseEnd = block.phaseEndsAt else {
            lastCuedPhaseEnd = nil
            lastCuedSecond = nil
            return
        }

        if lastCuedPhaseEnd != phaseEnd {
            lastCuedPhaseEnd = phaseEnd
            lastCuedSecond = nil
        }

        let seconds = remainingSeconds
        guard lastCuedSecond != seconds else { return }
        lastCuedSecond = seconds

        if (1...3).contains(seconds) {
            WorkoutTimerCuePlayer.shared.countdownTick()
        } else if seconds == 0 {
            WorkoutTimerCuePlayer.shared.phaseCompleted()
        }
    }

    private func normalizeRestoredState() {
        if block.isFinished {
            block.runnerPhase = .completed
        }
        if block.runnerPhase == .work || block.runnerPhase == .rest {
            handleTimerTick()
        }
    }

    private func setForCurrentRound(in exercise: WorkoutExercise) -> WorkoutSet? {
        let sets = exercise.setItems.sorted { $0.orderIndex < $1.orderIndex }
        guard sets.isEmpty == false else { return nil }
        return sets[min(block.currentRoundIndex, sets.count - 1)]
    }

    private func save() {
        try? modelContext.save()
    }

    private func formatClock(_ seconds: Int) -> String {
        String(format: "%02d:%02d", max(seconds, 0) / 60, max(seconds, 0) % 60)
    }
}
