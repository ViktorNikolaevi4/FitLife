import SwiftUI
import SwiftData

private let workoutsCardBackground = Color(.secondarySystemBackground)
private let workoutsInsetBackground = Color(.tertiarySystemBackground)
private let workoutsCardBorder = Color(.separator).opacity(0.40)

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
    @State private var showLastWorkoutEmptyAlert = false

    private var theme: AppTheme { AppTheme(colorScheme) }
    private var selectedGender: Gender { Gender(rawValue: activeGenderRaw) ?? .male }
    private var workoutSnapshot: WorkoutDiarySnapshot {
        makeWorkoutSnapshot()
    }

    var body: some View {
        let snapshot = workoutSnapshot

        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(AppLocalizer.string("workouts.diary.title"))
                        .font(.largeTitle.bold())
                        .padding(.horizontal)

                    WorkoutsFeatureCard(
                        title: AppLocalizer.string("workouts.last"),
                        subtitle: lastWorkoutSubtitle(snapshot.lastWorkout),
                        systemImage: "figure.strengthtraining.traditional",
                        tint: HomeDarkColors.orange,
                        isEmptyState: snapshot.lastWorkout == nil,
                        isPrimary: false,
                        theme: theme,
                        action: { openLastWorkout(snapshot.lastWorkout) }
                    )

                    WorkoutsFeatureCard(
                        title: AppLocalizer.string("workouts.new"),
                        subtitle: snapshot.activeWorkout == nil
                            ? AppLocalizer.string("workouts.new.subtitle")
                            : AppLocalizer.string("workouts.new.resume"),
                        systemImage: "dumbbell.fill",
                        tint: HomeDarkColors.blue,
                        isEmptyState: false,
                        isPrimary: true,
                        theme: theme,
                        action: { openActiveWorkout(snapshot.activeWorkout) }
                    )

                    if sessionStore.currentRole == .client,
                       let clientId = sessionStore.firebaseUser?.uid {
                        WorkoutsFeatureCard(
                            title: AppLocalizer.string("workouts.online"),
                            subtitle: AppLocalizer.string("workouts.online.subtitle"),
                            systemImage: "list.bullet.clipboard.fill",
                            tint: HomeDarkColors.red,
                            isEmptyState: false,
                            isPrimary: false,
                            theme: theme,
                            action: {
                                onlineAssignments = OnlineAssignmentsSelection(clientId: clientId)
                            }
                        )

                        WorkoutsFeatureCard(
                            title: AppLocalizer.string("workouts.connection"),
                            subtitle: AppLocalizer.string("workouts.connection.subtitle"),
                            systemImage: "person.2.wave.2.fill",
                            tint: HomeDarkColors.green,
                            isEmptyState: false,
                            isPrimary: false,
                            theme: theme,
                            action: {
                                coachingEntrySelection = ClientCoachingSelection(clientId: clientId)
                            }
                        )
                    }

                    WorkoutsShortcutCard(
                        title: AppLocalizer.string("workouts.history"),
                        subtitle: AppLocalizer.string("workouts.last.subtitle"),
                        systemImage: "clock.arrow.circlepath",
                        theme: theme,
                        action: openHistory
                    )
                    .padding(.horizontal)

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
            .alert(
                AppLocalizer.string("workouts.last.empty.title"),
                isPresented: $showLastWorkoutEmptyAlert
            ) {
                Button(AppLocalizer.string("common.close"), role: .cancel) {}
            } message: {
                Text(AppLocalizer.string("workouts.last.empty.subtitle"))
            }
        }
    }

    private func makeWorkoutSnapshot() -> WorkoutDiarySnapshot {
        let ownerId = sessionStore.firebaseUser?.uid
        var activeWorkout: WorkoutSession?
        var lastWorkout: WorkoutSession?

        for workout in workouts where workout.gender == selectedGender && workout.ownerId == ownerId {
            if workout.endedAt == nil {
                if activeWorkout == nil || workout.createdAt > (activeWorkout?.createdAt ?? .distantPast) {
                    activeWorkout = workout
                }
            } else if let endedAt = workout.endedAt {
                if lastWorkout == nil || endedAt > (lastWorkout?.endedAt ?? .distantPast) {
                    lastWorkout = workout
                }
            }
        }

        return WorkoutDiarySnapshot(activeWorkout: activeWorkout, lastWorkout: lastWorkout)
    }

    private func lastWorkoutSubtitle(_ lastWorkout: WorkoutSession?) -> String {
        guard let lastWorkout else { return AppLocalizer.string("workouts.last.empty.subtitle") }
        let exercisesCount = lastWorkout.exerciseItems.count
        let completedSets = lastWorkout.exerciseItems.flatMap(\.setItems).filter(\.isCompleted).count
        return AppLocalizer.format("workouts.last.summary", exercisesCount, completedSets)
    }

    private func openActiveWorkout(_ activeWorkout: WorkoutSession?) {
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
        refreshWorkoutReminders()
        selectedWorkout = workout
    }

    private func openLastWorkout(_ lastWorkout: WorkoutSession?) {
        guard let lastWorkout else {
            showLastWorkoutEmptyAlert = true
            return
        }
        selectedLastWorkout = LastWorkoutSelection(workout: lastWorkout)
    }

    private func openHistory() {
        historySelection = WorkoutHistorySelection(gender: selectedGender)
    }

    private func refreshWorkoutReminders() {
        guard let ownerId = sessionStore.firebaseUser?.uid else { return }
        LocalReminderScheduler.rescheduleWorkoutRemindersIfEnabled(
            modelContext: modelContext,
            ownerId: ownerId,
            gender: selectedGender
        )
    }

    private struct WorkoutDiarySnapshot {
        let activeWorkout: WorkoutSession?
        let lastWorkout: WorkoutSession?
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

private struct WorkoutDiaryIconTile: View {
    let systemImage: String
    let tint: Color
    let theme: AppTheme
    var isPrimary = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isPrimary
                            ? [Color.white.opacity(0.22), Color.white.opacity(0.12)]
                            : [
                                tint.opacity(theme.isDark ? 0.22 : 0.14),
                                tint.opacity(theme.isDark ? 0.10 : 0.06)
                            ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: systemImage)
                .font(.system(size: 27, weight: .semibold))
                .foregroundStyle(isPrimary ? Color.white : tint)
        }
        .frame(width: 64, height: 64)
    }
}

private struct WorkoutDiaryCardModifier: ViewModifier {
    let tint: Color
    let theme: AppTheme

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: theme.isDark
                                ? [HomeDarkColors.cardTop, HomeDarkColors.cardBottom]
                                : [HomeColors.card, HomeColors.elevatedBackground],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        theme.isDark ? HomeDarkColors.strokeTop : HomeColors.border,
                        lineWidth: HomeDarkMetrics.strokeWidth
                    )
            }
            .shadow(
                color: theme.isDark ? .black.opacity(0.45) : HomeColors.shadow,
                radius: theme.isDark ? 24 : HomeMetrics.cardShadowRadius,
                x: 0,
                y: theme.isDark ? 14 : HomeMetrics.cardShadowY
            )
    }
}

private struct HighlightedWorkoutCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "1E4FAE").opacity(0.55),
                                Color(hex: "172B50"),
                                Color(hex: "101A32")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "3A86FF").opacity(0.55),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color(hex: "0A84FF").opacity(0.18), radius: 18, x: 0, y: 8)
            .shadow(
                color: .black.opacity(0.45),
                radius: 18,
                x: 0,
                y: 12
            )
    }
}

private enum AnyWorkoutDiaryCardModifier: ViewModifier {
    case regular(Color, AppTheme)
    case highlighted

    @ViewBuilder
    func body(content: Content) -> some View {
        switch self {
        case .regular(let tint, let theme):
            content.workoutDiaryCard(tint: tint, theme: theme)
        case .highlighted:
            content.highlightedWorkoutCard()
        }
    }
}

private extension View {
    func workoutDiaryCard(tint: Color, theme: AppTheme) -> some View {
        modifier(WorkoutDiaryCardModifier(tint: tint, theme: theme))
    }

    func highlightedWorkoutCard() -> some View {
        modifier(HighlightedWorkoutCardModifier())
    }
}

private struct WorkoutsShortcutCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let theme: AppTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                WorkoutDiaryIconTile(
                    systemImage: systemImage,
                    tint: theme.primaryText.opacity(0.88),
                    theme: theme
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                        .multilineTextAlignment(.leading)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.tertiaryText)
            }
            .workoutDiaryCard(tint: theme.primaryText.opacity(0.88), theme: theme)
        }
        .buttonStyle(.plain)
    }
}

private struct WorkoutsFeatureCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let isEmptyState: Bool
    let isPrimary: Bool
    let theme: AppTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            cardContent
        }
        .buttonStyle(.plain)
    }

    private var cardContent: some View {
        HStack(spacing: 16) {
            WorkoutDiaryIconTile(systemImage: systemImage, tint: tint, theme: theme, isPrimary: isPrimary)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(titleColor)
                if isEmptyState {
                    Text(AppLocalizer.string("workouts.last.empty.title"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(subtitleColor)
                } else {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(subtitleColor)
                        .multilineTextAlignment(.leading)
                }
            }

            Spacer()

            Image(systemName: isEmptyState ? "info.circle" : "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(chevronColor)
        }
        .modifier(isPrimary ? AnyWorkoutDiaryCardModifier.highlighted : AnyWorkoutDiaryCardModifier.regular(tint, theme))
        .padding(.horizontal)
    }

    private var titleColor: Color {
        isPrimary ? .white : theme.primaryText
    }

    private var subtitleColor: Color {
        isPrimary ? .white.opacity(0.86) : theme.secondaryText
    }

    private var chevronColor: Color {
        isPrimary ? .white.opacity(0.9) : theme.tertiaryText
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
                                    .fill(selectedRange == range ? Color.blue : workoutsCardBackground)
                            )
                            .foregroundStyle(selectedRange == range ? Color.white : Color.primary)
                            .overlay(
                                Capsule()
                                    .strokeBorder(selectedRange == range ? .clear : workoutsCardBorder)
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
                            .fill(WorkoutHistoryRange.secondaryCases.contains(selectedRange) ? Color.blue : workoutsCardBackground)
                    )
                    .foregroundStyle(WorkoutHistoryRange.secondaryCases.contains(selectedRange) ? Color.white : Color.primary)
                    .overlay(
                        Capsule()
                            .strokeBorder(WorkoutHistoryRange.secondaryCases.contains(selectedRange) ? .clear : workoutsCardBorder)
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
                .background(RoundedRectangle(cornerRadius: 18).fill(workoutsCardBackground))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(workoutsCardBorder))
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
                    .background(Circle().fill(workoutsCardBackground))
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
        workout.exerciseItems.count
    }

    private var completedSets: Int {
        workout.exerciseItems.flatMap(\.setItems).filter(\.isCompleted).count
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: workout.endedAt ?? workout.createdAt)
    }

    private var caloriesText: String {
        formattedWorkoutCalories(workout.estimatedCalories)
    }

    private var trimmedNote: String {
        workout.note.trimmingCharacters(in: .whitespacesAndNewlines)
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

                if trimmedNote.isEmpty == false {
                    Text(trimmedNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(caloriesText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20).fill(workoutsCardBackground))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(workoutsCardBorder))
    }
}

private struct WorkoutDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let workout: WorkoutSession
    @State private var expandedExerciseIDs: Set<UUID> = []
    @State private var showDeleteConfirmation = false
    @State private var editingSet: WorkoutSet?
    @State private var editingExerciseNote: WorkoutExercise?
    @State private var isEditingWorkoutNote = false

    private var sortedExercises: [WorkoutExercise] {
        workout.exerciseItems.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var completedSets: Int {
        sortedExercises.flatMap(\.setItems).filter(\.isCompleted).count
    }

    private var totalSets: Int {
        sortedExercises.flatMap(\.setItems).count
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: workout.endedAt ?? workout.createdAt)
    }

    private var caloriesText: String {
        formattedWorkoutCalories(workout.estimatedCalories)
    }

    private var trimmedWorkoutNote: String {
        workout.note.trimmingCharacters(in: .whitespacesAndNewlines)
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
                                onToggleExpanded: { toggleExpanded(exercise.id) },
                                onEditNote: { editingExerciseNote = exercise },
                                onEditSet: { set in editingSet = set },
                                onToggleSet: { set in toggleSet(set) }
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
            Button(AppLocalizer.string("workouts.history.delete.button"), role: .destructive) {
                deleteWorkout()
            }
        } message: {
            Text(AppLocalizer.string("workouts.history.delete.message"))
        }
        .sheet(item: $editingSet) { set in
            EditCompletedWorkoutSetScreen(
                set: set,
                onSave: { weight, reps, durationSeconds, metricType in
                    updateSet(
                        set,
                        weight: weight,
                        reps: reps,
                        durationSeconds: durationSeconds,
                        metricType: metricType
                    )
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingExerciseNote) { exercise in
            EditCompletedWorkoutExerciseNoteScreen(
                exercise: exercise,
                onSave: { note in
                    updateExerciseNote(exercise, note: note)
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isEditingWorkoutNote) {
            EditCompletedWorkoutSessionNoteScreen(
                workout: workout,
                onSave: { note in
                    updateWorkoutNote(note)
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(workoutsCardBackground))
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
                    title: AppLocalizer.string("workout.last.calories"),
                    value: caloriesText
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

            Button(action: { isEditingWorkoutNote = true }) {
                HStack(spacing: 10) {
                    Image(systemName: "note.text")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(
                        trimmedWorkoutNote.isEmpty
                        ? AppLocalizer.string("workout.note.add")
                        : trimmedWorkoutNote
                    )
                    .font(.subheadline)
                    .foregroundStyle(trimmedWorkoutNote.isEmpty ? .secondary : .primary)
                    .lineLimit(2)
                    .truncationMode(.tail)

                    Spacer()
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 18).fill(workoutsInsetBackground))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(workoutsCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(workoutsCardBorder)
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

    private func toggleSet(_ set: WorkoutSet) {
        set.isCompleted.toggle()
        try? modelContext.save()
    }

    private func updateSet(
        _ set: WorkoutSet,
        weight: Double,
        reps: Int,
        durationSeconds: Int,
        metricType: WorkoutSetMetricType
    ) {
        set.weight = weight
        set.metricType = metricType
        set.reps = reps
        set.durationSeconds = durationSeconds
        try? modelContext.save()
    }

    private func updateExerciseNote(_ exercise: WorkoutExercise, note: String) {
        exercise.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        try? modelContext.save()
    }

    private func updateWorkoutNote(_ note: String) {
        workout.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        try? modelContext.save()
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
        .background(RoundedRectangle(cornerRadius: 18).fill(workoutsInsetBackground))
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
        .background(RoundedRectangle(cornerRadius: 24).fill(workoutsCardBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(workoutsCardBorder)
        )
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
    let onEditNote: () -> Void
    let onEditSet: (WorkoutSet) -> Void
    let onToggleSet: (WorkoutSet) -> Void

    private var sortedSets: [WorkoutSet] {
        exercise.setItems.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var completedCount: Int {
        sortedSets.filter(\.isCompleted).count
    }

    private var trimmedNote: String {
        exercise.note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggleExpanded) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(workoutAccentColor(exercise.accentName).opacity(0.14))

                        workoutIconImage(
                            named: exercise.systemImage,
                            accentName: exercise.accentName,
                            size: 19
                        )
                    }
                    .frame(width: 48, height: 48)

                    VStack(alignment: .leading, spacing: 3) {
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
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 10) {
                    Button(action: onEditNote) {
                        HStack(spacing: 8) {
                            Image(systemName: "note.text")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Text(
                                trimmedNote.isEmpty
                                ? AppLocalizer.string("workout.exercise.note.add")
                                : trimmedNote
                            )
                                .font(.subheadline)
                                .foregroundStyle(trimmedNote.isEmpty ? .secondary : .primary)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(workoutsInsetBackground)
                        )
                    }
                    .buttonStyle(.plain)

                    ForEach(sortedSets, id: \.id) { set in
                        Button(action: { onEditSet(set) }) {
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

                                Button(action: { onToggleSet(set) }) {
                                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(set.isCompleted ? Color.green : .secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(workoutsInsetBackground)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(RoundedRectangle(cornerRadius: 22).fill(workoutsCardBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(workoutsCardBorder)
        )
    }

}

private struct EditCompletedWorkoutExerciseNoteScreen: View {
    @Environment(\.dismiss) private var dismiss

    let exercise: WorkoutExercise
    let onSave: (String) -> Void

    @State private var note: String
    @FocusState private var isNoteFocused: Bool

    init(exercise: WorkoutExercise, onSave: @escaping (String) -> Void) {
        self.exercise = exercise
        self.onSave = onSave
        _note = State(initialValue: exercise.note)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(AppLocalizer.string("workout.exercise.note.title"))
                    .font(.title3.weight(.semibold))

                TextField(
                    AppLocalizer.string("workout.exercise.note.placeholder"),
                    text: $note,
                    axis: .vertical
                )
                .lineLimit(4...8)
                .focused($isNoteFocused)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 18).fill(workoutsInsetBackground))

                Button(action: save) {
                    Text(AppLocalizer.string("workout.exercise.note.save"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color(.systemBackground))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 18).fill(HomeColors.primaryActionGradient))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(AppLocalizer.string("common.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(AppLocalizer.string("common.done")) {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil,
                            from: nil,
                            for: nil
                        )
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isNoteFocused = true
                }
            }
        }
    }

    private func save() {
        onSave(note)
        dismiss()
    }
}

private struct EditCompletedWorkoutSessionNoteScreen: View {
    @Environment(\.dismiss) private var dismiss

    let workout: WorkoutSession
    let onSave: (String) -> Void

    @State private var note: String
    @FocusState private var isNoteFocused: Bool

    init(workout: WorkoutSession, onSave: @escaping (String) -> Void) {
        self.workout = workout
        self.onSave = onSave
        _note = State(initialValue: workout.note)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(AppLocalizer.string("workout.note.title"))
                    .font(.title3.weight(.semibold))

                TextField(
                    AppLocalizer.string("workout.note.placeholder"),
                    text: $note,
                    axis: .vertical
                )
                .lineLimit(4...8)
                .focused($isNoteFocused)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 18).fill(workoutsInsetBackground))

                Button(action: save) {
                    Text(AppLocalizer.string("workout.note.save"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color(.systemBackground))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 18).fill(HomeColors.primaryActionGradient))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(AppLocalizer.string("common.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(AppLocalizer.string("common.done")) {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil,
                            from: nil,
                            for: nil
                        )
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isNoteFocused = true
                }
            }
        }
    }

    private func save() {
        onSave(note)
        dismiss()
    }
}

private struct EditCompletedWorkoutSetScreen: View {
    @Environment(\.dismiss) private var dismiss

    let set: WorkoutSet
    let onSave: (Double, Int, Int, WorkoutSetMetricType) -> Void

    @State private var draftSet: WorkoutDraftSet

    init(set: WorkoutSet, onSave: @escaping (Double, Int, Int, WorkoutSetMetricType) -> Void) {
        self.set = set
        self.onSave = onSave
        _draftSet = State(
            initialValue: WorkoutDraftSet(
                weight: set.weight,
                reps: set.reps,
                durationSeconds: set.durationSeconds,
                metricType: set.metricType
            )
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(AppLocalizer.string("workout.set.edit.title"))
                            .font(.title3.weight(.semibold))
                        Text(AppLocalizer.string("workout.set.edit.subtitle"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    WorkoutDraftSetEditorRow(
                        title: AppLocalizer.format("workout.setup.set.title", set.orderIndex + 1),
                        set: draftSet,
                        onChange: { draftSet = $0 },
                        onDelete: {},
                        canDelete: false
                    )

                    Button(action: save) {
                        Text(AppLocalizer.string("workout.set.edit.save"))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color(.systemBackground))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 18).fill(HomeColors.primaryActionGradient))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(AppLocalizer.string("common.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(AppLocalizer.string("common.done")) {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil,
                            from: nil,
                            for: nil
                        )
                    }
                }
            }
        }
    }

    private func save() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        DispatchQueue.main.async {
            onSave(draftSet.weight, draftSet.reps, draftSet.durationSeconds, draftSet.metricType)
            dismiss()
        }
    }
}
