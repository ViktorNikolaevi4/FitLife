import SwiftUI
import SwiftData

struct WorkoutsScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var sessionStore: AppSessionStore
    @Query private var workouts: [WorkoutSession]
    @AppStorage(Gender.appStorageKey) private var activeGenderRaw: String = Gender.male.rawValue

    @State private var selectedWorkout: WorkoutSession?
    @State private var selectedLastWorkout: LastWorkoutSelection?
    @State private var onlineAssignments: OnlineAssignmentsSelection?
    @State private var coachingEntrySelection: ClientCoachingSelection?
    @State private var historySelection: WorkoutHistorySelection?

    private var theme: AppTheme { AppTheme(colorScheme) }
    private var selectedGender: Gender { Gender(rawValue: activeGenderRaw) ?? .male }
    private var relevantWorkouts: [WorkoutSession] {
        workouts.filter { $0.gender == selectedGender && $0.ownerId == sessionStore.firebaseUser?.uid }
    }
    private var activeWorkout: WorkoutSession? {
        relevantWorkouts
            .filter { $0.endedAt == nil }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }
    private var lastWorkout: WorkoutSession? {
        relevantWorkouts
            .filter { $0.endedAt != nil }
            .sorted { ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast) }
            .first
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(AppLocalizer.string("workouts.diary.title"))
                        .font(.largeTitle.bold())
                        .padding(.horizontal)

                    HStack(spacing: 12) {
                        WorkoutsShortcutCard(
                            title: AppLocalizer.string("workouts.history"),
                            systemImage: "clock.arrow.circlepath",
                            theme: theme,
                            action: openHistory
                        )

                        WorkoutsShortcutCard(
                            title: AppLocalizer.string("workouts.templates"),
                            systemImage: "square.grid.2x2.fill",
                            theme: theme,
                            action: {}
                        )
                    }
                    .padding(.horizontal)

                    WorkoutsFeatureCard(
                        title: AppLocalizer.string("workouts.last"),
                        subtitle: lastWorkoutSubtitle,
                        systemImage: "figure.strengthtraining.traditional",
                        tint: .orange,
                        theme: theme,
                        action: openLastWorkout
                    )

                    WorkoutsFeatureCard(
                        title: AppLocalizer.string("workouts.new"),
                        subtitle: activeWorkout == nil
                            ? AppLocalizer.string("workouts.new.subtitle")
                            : AppLocalizer.string("workouts.new.resume"),
                        systemImage: "dumbbell.fill",
                        tint: .blue,
                        theme: theme,
                        action: openActiveWorkout
                    )

                    if sessionStore.currentRole == .client,
                       let clientId = sessionStore.firebaseUser?.uid {
                        WorkoutsFeatureCard(
                            title: AppLocalizer.string("workouts.online"),
                            subtitle: AppLocalizer.string("workouts.online.subtitle"),
                            systemImage: "list.bullet.clipboard.fill",
                            tint: .pink,
                            theme: theme,
                            action: {
                                onlineAssignments = OnlineAssignmentsSelection(clientId: clientId)
                            }
                        )

                        WorkoutsFeatureCard(
                            title: AppLocalizer.string("workouts.connection"),
                            subtitle: AppLocalizer.string("workouts.connection.subtitle"),
                            systemImage: "person.2.wave.2.fill",
                            tint: .green,
                            theme: theme,
                            action: {
                                coachingEntrySelection = ClientCoachingSelection(clientId: clientId)
                            }
                        )
                    }

                    Button(action: {}) {
                        HStack {
                            Text(AppLocalizer.string("workouts.weekly.activity"))
                                .font(.headline.weight(.semibold))
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 18)
                        .background(RoundedRectangle(cornerRadius: 18).fill(.black))
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .padding(.top, 6)
                }
                .padding(.vertical, 16)
            }
            .background(theme.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedWorkout) { workout in
                ActiveWorkoutScreen(workout: workout)
            }
            .navigationDestination(item: $selectedLastWorkout) { selection in
                WorkoutDetailScreen(workout: selection.workout)
            }
            .navigationDestination(item: $onlineAssignments) { selection in
                ClientAssignedWorkoutsScreen(clientId: selection.clientId)
            }
            .navigationDestination(item: $coachingEntrySelection) { selection in
                ClientCoachingEntryScreen(clientId: selection.clientId)
            }
            .navigationDestination(item: $historySelection) { selection in
                WorkoutHistoryScreen(gender: selection.gender)
            }
        }
    }

    private var lastWorkoutSubtitle: String {
        guard let lastWorkout else { return AppLocalizer.string("workouts.last.subtitle") }
        let exercisesCount = lastWorkout.exercises.count
        let completedSets = lastWorkout.exercises.flatMap(\.sets).filter(\.isCompleted).count
        return AppLocalizer.format("workouts.last.summary", exercisesCount, completedSets)
    }

    private func openActiveWorkout() {
        if let activeWorkout {
            selectedWorkout = activeWorkout
            return
        }

        let workout = WorkoutSession(
            ownerId: sessionStore.firebaseUser?.uid ?? "",
            title: AppLocalizer.string("workout.active.title"),
            gender: selectedGender
        )

        modelContext.insert(workout)
        try? modelContext.save()
        selectedWorkout = workout
    }

    private func openLastWorkout() {
        guard let lastWorkout else { return }
        selectedLastWorkout = LastWorkoutSelection(workout: lastWorkout)
    }

    private func openHistory() {
        historySelection = WorkoutHistorySelection(gender: selectedGender)
    }
}

private struct LastWorkoutSelection: Identifiable, Hashable {
    let workout: WorkoutSession
    var id: UUID { workout.id }

    static func == (lhs: LastWorkoutSelection, rhs: LastWorkoutSelection) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private struct OnlineAssignmentsSelection: Identifiable, Hashable {
    let clientId: String
    var id: String { clientId }
}

private struct WorkoutHistorySelection: Identifiable, Hashable {
    let gender: Gender
    var id: String { gender.rawValue }
}

private struct ClientCoachingSelection: Identifiable, Hashable {
    let clientId: String
    var id: String { clientId }
}

private struct WorkoutsShortcutCard: View {
    let title: String
    let systemImage: String
    let theme: AppTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(theme.subtleFill))

                Text(title)
                    .font(.headline.weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 122, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 18).fill(theme.card))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(theme.border))
        }
        .buttonStyle(.plain)
    }
}

private struct WorkoutsFeatureCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let theme: AppTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(tint.opacity(0.14))

                    Image(systemName: systemImage)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .frame(width: 84, height: 84)

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 20).fill(theme.card))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(theme.border))
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }
}

private struct WorkoutHistoryScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionStore: AppSessionStore
    @Query private var workouts: [WorkoutSession]

    let gender: Gender
    @State private var selectedRange: WorkoutHistoryRange = .allTime
    @State private var customStartDate = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var customEndDate = Date()

    private var completedWorkouts: [WorkoutSession] {
        workouts
            .filter { $0.gender == gender && $0.endedAt != nil && $0.ownerId == sessionStore.firebaseUser?.uid }
            .filter(isWorkoutInSelectedRange)
            .sorted { ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                historyHeader
                historyFilters

                if completedWorkouts.isEmpty {
                    ContentUnavailableView(
                        AppLocalizer.string("workouts.history.empty.title"),
                        systemImage: "clock.arrow.circlepath",
                        description: Text(AppLocalizer.string("workouts.history.empty.subtitle"))
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(completedWorkouts, id: \.id) { workout in
                            NavigationLink {
                                WorkoutDetailScreen(workout: workout)
                            } label: {
                                WorkoutHistoryRow(workout: workout)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
    }

    private var historyFilters: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(WorkoutHistoryRange.primaryCases) { range in
                    Button {
                        selectedRange = range
                    } label: {
                        Text(AppLocalizer.string(range.localizationKey))
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(selectedRange == range ? Color.blue : Color.white)
                            )
                            .foregroundStyle(selectedRange == range ? Color.white : Color.primary)
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.black.opacity(selectedRange == range ? 0 : 0.08))
                            )
                    }
                    .buttonStyle(.plain)
                }

                Menu {
                    ForEach(WorkoutHistoryRange.secondaryCases) { range in
                        Button {
                            selectedRange = range
                        } label: {
                            if selectedRange == range {
                                Label(AppLocalizer.string(range.localizationKey), systemImage: "checkmark")
                            } else {
                                Text(AppLocalizer.string(range.localizationKey))
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(AppLocalizer.string("workouts.history.range.more"))
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(WorkoutHistoryRange.secondaryCases.contains(selectedRange) ? Color.blue : Color.white)
                    )
                    .foregroundStyle(WorkoutHistoryRange.secondaryCases.contains(selectedRange) ? Color.white : Color.primary)
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.black.opacity(WorkoutHistoryRange.secondaryCases.contains(selectedRange) ? 0 : 0.08))
                    )
                }
            }

            if selectedRange == .custom {
                VStack(spacing: 12) {
                    DatePicker(
                        AppLocalizer.string("workouts.history.custom.start"),
                        selection: $customStartDate,
                        in: ...customEndDate,
                        displayedComponents: .date
                    )

                    DatePicker(
                        AppLocalizer.string("workouts.history.custom.end"),
                        selection: $customEndDate,
                        in: customStartDate...Date(),
                        displayedComponents: .date
                    )
                }
                .font(.subheadline)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.black.opacity(0.05)))
            }
        }
    }

    private var historyHeader: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(AppLocalizer.string("workouts.history"))
                .font(.headline.weight(.semibold))

            Spacer()

            Color.clear
                .frame(width: 40, height: 40)
        }
    }

    private func isWorkoutInSelectedRange(_ workout: WorkoutSession) -> Bool {
        let referenceDate = workout.endedAt ?? workout.createdAt
        let calendar = Calendar.current

        switch selectedRange {
        case .week:
            return referenceDate >= (calendar.date(byAdding: .day, value: -7, to: .now) ?? .distantPast)
        case .month:
            return referenceDate >= (calendar.date(byAdding: .month, value: -1, to: .now) ?? .distantPast)
        case .threeMonths:
            return referenceDate >= (calendar.date(byAdding: .month, value: -3, to: .now) ?? .distantPast)
        case .halfYear:
            return referenceDate >= (calendar.date(byAdding: .month, value: -6, to: .now) ?? .distantPast)
        case .year:
            return referenceDate >= (calendar.date(byAdding: .year, value: -1, to: .now) ?? .distantPast)
        case .allTime:
            return true
        case .custom:
            let start = calendar.startOfDay(for: customStartDate)
            let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: customEndDate) ?? customEndDate
            return referenceDate >= start && referenceDate <= end
        }
    }
}

private enum WorkoutHistoryRange: String, CaseIterable, Identifiable {
    case week
    case month
    case threeMonths
    case halfYear
    case year
    case allTime
    case custom

    var id: String { rawValue }

    static let primaryCases: [WorkoutHistoryRange] = [.week, .month, .threeMonths]
    static let secondaryCases: [WorkoutHistoryRange] = [.halfYear, .year, .allTime, .custom]

    var localizationKey: String {
        switch self {
        case .week: return "workouts.history.range.week"
        case .month: return "workouts.history.range.month"
        case .threeMonths: return "workouts.history.range.three_months"
        case .halfYear: return "workouts.history.range.half_year"
        case .year: return "workouts.history.range.year"
        case .allTime: return "workouts.history.range.all_time"
        case .custom: return "workouts.history.range.custom"
        }
    }
}

private struct WorkoutHistoryRow: View {
    let workout: WorkoutSession

    private var exerciseCount: Int {
        workout.exercises.count
    }

    private var completedSets: Int {
        workout.exercises.flatMap(\.sets).filter(\.isCompleted).count
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: workout.endedAt ?? workout.createdAt)
    }

    private var durationText: String {
        let totalMinutes = workout.elapsedSeconds / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)ч \(minutes)м"
        }
        return "\(max(1, minutes)) мин"
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.16),
                                Color.cyan.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.blue)
            }
            .frame(width: 64, height: 78)

            VStack(alignment: .leading, spacing: 6) {
                Text(workout.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(AppLocalizer.format("workouts.last.summary", exerciseCount, completedSets))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(durationText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.black.opacity(0.05)))
    }
}

private struct WorkoutDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let workout: WorkoutSession
    @State private var expandedExerciseIDs: Set<UUID> = []
    @State private var showDeleteConfirmation = false

    private var sortedExercises: [WorkoutExercise] {
        workout.exercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var completedSets: Int {
        sortedExercises.flatMap(\.sets).filter(\.isCompleted).count
    }

    private var totalSets: Int {
        sortedExercises.flatMap(\.sets).count
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: workout.endedAt ?? workout.createdAt)
    }

    private var durationText: String {
        let totalMinutes = workout.elapsedSeconds / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)ч \(minutes)м"
        }
        return "\(max(1, minutes)) мин"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header
                summaryCard

                if sortedExercises.isEmpty {
                    emptyCard
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(sortedExercises, id: \.id) { exercise in
                            LastWorkoutExerciseCard(
                                exercise: exercise,
                                isExpanded: expandedExerciseIDs.contains(exercise.id),
                                onToggleExpanded: { toggleExpanded(exercise.id) }
                            )
                        }
                    }
                }

                if workout.endedAt != nil {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Label(AppLocalizer.string("workouts.history.delete.button"), systemImage: "trash")
                                .font(.headline.weight(.semibold))
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.red.opacity(0.10))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .alert(AppLocalizer.string("workouts.history.delete.title"), isPresented: $showDeleteConfirmation) {
            Button(AppLocalizer.string("common.cancel"), role: .cancel) {}
            Button(AppLocalizer.string("common.delete"), role: .destructive) {
                deleteWorkout()
            }
        } message: {
            Text(AppLocalizer.string("workouts.history.delete.message"))
        }
    }

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(AppLocalizer.string("workout.detail.title"))
                .font(.headline.weight(.semibold))

            Spacer()

            Color.clear
                .frame(width: 40, height: 40)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.orange.opacity(0.26),
                                    Color.yellow.opacity(0.14),
                                    Color.red.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Image(systemName: "flame.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color.orange)
                }
                .frame(width: 76, height: 88)

                VStack(alignment: .leading, spacing: 6) {
                    Text(AppLocalizer.string("workouts.last").uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .tracking(1.1)

                    Text(formattedDate)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(AppLocalizer.format("workouts.last.summary", sortedExercises.count, completedSets))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                workoutStatCard(
                    title: AppLocalizer.string("workout.last.duration"),
                    value: durationText
                )
                workoutStatCard(
                    title: AppLocalizer.string("workout.last.exercises"),
                    value: "\(sortedExercises.count)"
                )
                workoutStatCard(
                    title: AppLocalizer.string("workout.last.completed"),
                    value: "\(completedSets)/\(totalSets)"
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(Color.black.opacity(0.05))
        )
    }

    private func toggleExpanded(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedExerciseIDs.contains(id) {
                expandedExerciseIDs.remove(id)
            } else {
                expandedExerciseIDs.insert(id)
            }
        }
    }

    private func workoutStatCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.systemGray6)))
    }

    private var emptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(AppLocalizer.string("workout.last.empty.title"))
                .font(.headline.weight(.semibold))

            Text(AppLocalizer.string("workout.last.empty.subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color.white))
    }

    private func deleteWorkout() {
        modelContext.delete(workout)
        try? modelContext.save()
        dismiss()
    }
}

private struct LastWorkoutExerciseCard: View {
    let exercise: WorkoutExercise
    let isExpanded: Bool
    let onToggleExpanded: () -> Void

    private var sortedSets: [WorkoutSet] {
        exercise.sets.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var completedCount: Int {
        sortedSets.filter(\.isCompleted).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggleExpanded) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(workoutAccentColor(exercise.accentName).opacity(0.14))

                        Image(systemName: exercise.systemImage)
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(workoutAccentColor(exercise.accentName))
                    }
                    .frame(width: 48, height: 48)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(exercise.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(AppLocalizer.format("workout.exercise.summary", sortedSets.count, completedCount))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 10) {
                    ForEach(sortedSets, id: \.id) { set in
                        HStack(spacing: 12) {
                            Text(AppLocalizer.format("workout.set.number", set.orderIndex + 1))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 26, alignment: .leading)

                            Text(AppLocalizer.format("workout.set.value", formattedWeight(set.weight), set.reps))
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)

                            Spacer()

                            Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(set.isCompleted ? Color.green : .secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(.systemGray6))
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.white))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.black.opacity(0.05))
        )
    }

    private func formattedWeight(_ weight: Double) -> String {
        if weight.rounded() == weight {
            return String(Int(weight))
        }
        return String(format: "%.1f", weight)
    }
}
