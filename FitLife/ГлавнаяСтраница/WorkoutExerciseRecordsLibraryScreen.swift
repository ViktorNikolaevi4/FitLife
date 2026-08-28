import SwiftData
import SwiftUI

private enum WorkoutExerciseRecordResetStore {
    static let revisionKey = "workout.exercise.records.reset.revision"
    private static let cutoffsKey = "workout.exercise.records.reset.cutoffs"

    static func cutoff(ownerID: String?, exerciseKey: String) -> Date? {
        guard let timestamp = cutoffs()[storageKey(ownerID: ownerID, exerciseKey: exerciseKey)] else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    static func reset(ownerID: String?, exerciseKey: String, at date: Date = .now) {
        var values = cutoffs()
        values[storageKey(ownerID: ownerID, exerciseKey: exerciseKey)] = date.timeIntervalSince1970
        UserDefaults.standard.set(values, forKey: cutoffsKey)
    }

    private static func cutoffs() -> [String: TimeInterval] {
        UserDefaults.standard
            .dictionary(forKey: cutoffsKey)?
            .compactMapValues { ($0 as? NSNumber)?.doubleValue } ?? [:]
    }

    private static func storageKey(ownerID: String?, exerciseKey: String) -> String {
        let resolvedOwnerID = ownerID.flatMap { $0.isEmpty ? nil : $0 } ?? "local"
        return "\(resolvedOwnerID)|\(exerciseKey)"
    }
}

private struct WorkoutExerciseRecordSummary: Identifiable {
    let id: String
    let name: String
    let systemImage: String
    let accentName: String
    let workoutCount: Int
    let completedSetCount: Int
    let history: [WorkoutExerciseHistoryEntry]
    let personalBests: WorkoutExercisePersonalBests

    var lastPerformedAt: Date? { history.first?.date }
    var totalVolume: Double {
        history.compactMap(\.volume).reduce(0, +)
    }
}

private struct WorkoutExerciseRecordAccumulator {
    let name: String
    let systemImage: String
    let accentName: String
    var sessionIDs: Set<UUID>
    var history: [WorkoutExerciseHistoryEntry]
}

struct WorkoutExerciseRecordsLibraryScreen: View {
    @Query(sort: \WorkoutSession.createdAt, order: .reverse) private var workoutHistory: [WorkoutSession]
    @EnvironmentObject private var sessionStore: AppSessionStore
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(WorkoutExerciseRecordResetStore.revisionKey) private var resetRevision = 0
    @State private var searchText = ""

    private var theme: AppTheme { AppTheme(colorScheme) }

    private var records: [WorkoutExerciseRecordSummary] {
        _ = resetRevision
        let ownerID = sessionStore.firebaseUser?.uid
        let sessions = workoutHistory.filter { session in
            guard let ownerID, ownerID.isEmpty == false else { return true }
            return session.ownerId == ownerID
        }
        let catalogTemplates = Dictionary(
            workoutTemplates().map { (normalizedWorkoutExerciseName($0.name), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var accumulators: [String: WorkoutExerciseRecordAccumulator] = [:]
        for session in sessions {
            for exercise in session.exerciseItems {
                let key = normalizedWorkoutExerciseName(exercise.name)
                guard
                    key.isEmpty == false,
                    let entry = workoutExerciseHistoryEntry(for: exercise, in: session),
                    entry.completedSetCount > 0,
                    WorkoutExerciseRecordResetStore.cutoff(ownerID: ownerID, exerciseKey: key)
                        .map({ entry.date > $0 }) ?? true
                else { continue }

                if var accumulator = accumulators[key] {
                    accumulator.sessionIDs.insert(session.id)
                    accumulator.history.append(entry)
                    accumulators[key] = accumulator
                } else {
                    let catalogTemplate = catalogTemplates[key]
                    accumulators[key] = WorkoutExerciseRecordAccumulator(
                        name: catalogTemplate?.name ?? exercise.name,
                        systemImage: catalogTemplate?.systemImage ?? exercise.systemImage,
                        accentName: catalogTemplate?.accentName ?? exercise.accentName,
                        sessionIDs: [session.id],
                        history: [entry]
                    )
                }
            }
        }

        return accumulators.map { key, accumulator in
            let history = accumulator.history.sorted { $0.date > $1.date }

            return WorkoutExerciseRecordSummary(
                id: key,
                name: accumulator.name,
                systemImage: accumulator.systemImage,
                accentName: accumulator.accentName,
                workoutCount: accumulator.sessionIDs.count,
                completedSetCount: history.reduce(0) { $0 + $1.completedSetCount },
                history: history,
                personalBests: WorkoutExercisePersonalBests(history: history)
            )
        }
        .sorted {
            if $0.workoutCount != $1.workoutCount { return $0.workoutCount > $1.workoutCount }
            if $0.completedSetCount != $1.completedSetCount { return $0.completedSetCount > $1.completedSetCount }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var filteredRecords: [WorkoutExerciseRecordSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return records }
        return records.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        Group {
            if records.isEmpty {
                ContentUnavailableView {
                    Label(AppLocalizer.string("profile.exercise_records.empty.title"), systemImage: "trophy")
                } description: {
                    Text(AppLocalizer.string("profile.exercise_records.empty.subtitle"))
                }
            } else {
                VStack(spacing: 0) {
                    recordsSearchField
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 4)

                    if filteredRecords.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                HStack {
                                    Text(AppLocalizer.string("profile.exercise_records.frequency_order"))
                                        .font(.subheadline)
                                        .foregroundStyle(theme.secondaryText)
                                    Spacer()
                                    Text("\(filteredRecords.count)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(theme.secondaryText)
                                }
                                .padding(.horizontal, 4)

                                ForEach(filteredRecords) { record in
                                    NavigationLink {
                                        WorkoutExerciseRecordDetailScreen(
                                            record: record,
                                            onReset: {
                                                WorkoutExerciseRecordResetStore.reset(
                                                    ownerID: sessionStore.firebaseUser?.uid,
                                                    exerciseKey: record.id
                                                )
                                                resetRevision &+= 1
                                            }
                                        )
                                    } label: {
                                        WorkoutExerciseRecordRow(record: record)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                        }
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(AppLocalizer.string("profile.exercise_records.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var recordsSearchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(AppLocalizer.string("profile.exercise_records.search"), text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if searchText.isEmpty == false {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AppLocalizer.string("profile.exercise_records.search.clear"))
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
        }
    }
}

private struct WorkoutExerciseRecordRow: View {
    let record: WorkoutExerciseRecordSummary

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(workoutAccentColor(record.accentName).opacity(0.14))

                workoutIconImage(
                    named: record.systemImage,
                    accentName: record.accentName,
                    size: 22,
                    customAssetScale: 2.25
                )
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 5) {
                Text(record.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(AppLocalizer.format(
                    "profile.exercise_records.usage",
                    record.workoutCount,
                    record.completedSetCount
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if let oneRepMax = record.personalBests.estimatedOneRepMax {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(AppLocalizer.string("profile.exercise_records.one_rep_max.short"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(formattedWorkoutWeight(oneRepMax)) \(AppLocalizer.string("unit.kg"))")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct WorkoutExerciseRecordDetailScreen: View {
    @Environment(\.dismiss) private var dismiss

    let record: WorkoutExerciseRecordSummary
    let onReset: () -> Void

    @State private var isShowingResetConfirmation = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                header
                statistics
                personalBests
                history
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(record.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(
                        AppLocalizer.string("profile.exercise_records.reset"),
                        systemImage: "arrow.counterclockwise",
                        role: .destructive
                    ) {
                        isShowingResetConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel(AppLocalizer.string("profile.exercise_records.actions"))
            }
        }
        .confirmationDialog(
            AppLocalizer.string("profile.exercise_records.reset.title"),
            isPresented: $isShowingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(AppLocalizer.string("profile.exercise_records.reset.confirm"), role: .destructive) {
                onReset()
                dismiss()
            }
            Button(AppLocalizer.string("common.cancel"), role: .cancel) {}
        } message: {
            Text(AppLocalizer.string("profile.exercise_records.reset.message"))
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(workoutAccentColor(record.accentName).opacity(0.14))
                workoutIconImage(
                    named: record.systemImage,
                    accentName: record.accentName,
                    size: 30,
                    customAssetScale: 2.2
                )
            }
            .frame(width: 76, height: 76)

            VStack(alignment: .leading, spacing: 5) {
                Text(record.name)
                    .font(.title3.weight(.bold))
                Text(AppLocalizer.format(
                    "profile.exercise_records.usage",
                    record.workoutCount,
                    record.completedSetCount
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if let date = record.lastPerformedAt {
                    Text(AppLocalizer.format(
                        "profile.exercise_records.last_performed",
                        date.formatted(date: .abbreviated, time: .omitted)
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var statistics: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppLocalizer.string("profile.exercise_records.statistics"))
                .font(.title3.weight(.bold))

            HStack(spacing: 12) {
                statisticCard(
                    title: AppLocalizer.string("profile.exercise_records.workouts"),
                    value: "\(record.workoutCount)",
                    icon: "calendar"
                )
                statisticCard(
                    title: AppLocalizer.string("profile.exercise_records.completed_sets"),
                    value: "\(record.completedSetCount)",
                    icon: "checkmark.circle.fill"
                )
                statisticCard(
                    title: AppLocalizer.string("profile.exercise_records.total_volume"),
                    value: record.totalVolume > 0
                        ? "\(formattedWorkoutWeight(record.totalVolume)) \(AppLocalizer.string("unit.kg"))"
                        : "—",
                    icon: "sum"
                )
            }
        }
    }

    private func statisticCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
            Text(value)
                .font(.headline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var personalBests: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(AppLocalizer.string("profile.exercise_records.personal_bests"))
                    .font(.title3.weight(.bold))
                Spacer()
                Text(AppLocalizer.string("profile.exercise_records.completed_only"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                WorkoutPersonalBestCard(
                    title: AppLocalizer.string("profile.exercise_records.one_rep_max"),
                    value: record.personalBests.estimatedOneRepMax.map { "\(formattedWorkoutWeight($0)) \(AppLocalizer.string("unit.kg"))" } ?? "—",
                    icon: "chart.line.uptrend.xyaxis"
                )
                WorkoutPersonalBestCard(
                    title: AppLocalizer.string("profile.exercise_records.achieved_one_rep_max"),
                    value: record.personalBests.achievedOneRepMax.map { "\(formattedWorkoutWeight($0)) \(AppLocalizer.string("unit.kg"))" } ?? "—",
                    icon: "medal.fill"
                )
                WorkoutPersonalBestCard(
                    title: AppLocalizer.string("profile.exercise_records.ten_rep_max"),
                    value: record.personalBests.tenRepMax.map { "\(formattedWorkoutWeight($0)) \(AppLocalizer.string("unit.kg"))" } ?? "—",
                    icon: "10.circle.fill"
                )
                WorkoutPersonalBestCard(
                    title: AppLocalizer.string("profile.exercise_records.max_weight"),
                    value: record.personalBests.maxWeight.map { "\(formattedWorkoutWeight($0)) \(AppLocalizer.string("unit.kg"))" } ?? "—",
                    icon: "dumbbell.fill"
                )
                WorkoutPersonalBestCard(
                    title: AppLocalizer.string("profile.exercise_records.max_reps"),
                    value: record.personalBests.maxReps.map(String.init) ?? "—",
                    icon: "target"
                )
                WorkoutPersonalBestCard(
                    title: AppLocalizer.string("profile.exercise_records.max_volume"),
                    value: record.personalBests.maxVolume.map { "\(formattedWorkoutWeight($0)) \(AppLocalizer.string("unit.kg"))" } ?? "—",
                    icon: "square.stack.3d.up.fill"
                )
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppLocalizer.string("profile.exercise_records.history"))
                .font(.title3.weight(.bold))

            ForEach(record.history) { entry in
                WorkoutExerciseHistoryRow(entry: entry)
            }
        }
    }
}
