import SwiftUI

struct ClientCheckInHubScreen: View {
    @ObservedObject var store: ClientCoachingHomeStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(AppLocalizer.string("coaching.checkin.hub.title"))
                        .font(.largeTitle.bold())
                    Text(AppLocalizer.string("coaching.checkin.hub.subtitle"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                NavigationLink {
                    ClientWeeklyCheckInScreen(store: store)
                } label: {
                    checkInCard(
                        icon: "waveform.path.ecg",
                        title: AppLocalizer.string("coaching.checkin.weekly.title"),
                        subtitle: AppLocalizer.string("coaching.checkin.weekly.subtitle"),
                        status: latestStatus(for: .weekly),
                        accent: .blue
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    ClientMonthlyCheckInScreen(store: store)
                } label: {
                    checkInCard(
                        icon: "ruler",
                        title: AppLocalizer.string("coaching.checkin.monthly.title"),
                        subtitle: AppLocalizer.string("coaching.checkin.monthly.subtitle"),
                        status: latestStatus(for: .monthly),
                        accent: .purple
                    )
                }
                .buttonStyle(.plain)

                Text(AppLocalizer.string("coaching.checkin.hub.privacy"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            .padding(20)
        }
        .background(background.ignoresSafeArea())
        .navigationTitle(AppLocalizer.string("coaching.checkin.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(AppLocalizer.string("common.close")) { dismiss() }
            }
        }
    }

    private var background: Color {
        colorScheme == .dark ? Color(.systemGroupedBackground) : HomeColors.background
    }

    private func latestStatus(for kind: ProgressCheckInKind) -> String {
        guard let checkIn = store.checkIns.first(where: { $0.kind == kind }) else {
            return AppLocalizer.string("coaching.checkin.not_completed")
        }
        return AppLocalizer.format(
            "coaching.checkin.last_completed",
            checkIn.createdAt.formatted(date: .abbreviated, time: .omitted)
        )
    }

    private func checkInCard(
        icon: String,
        title: String,
        subtitle: String,
        status: String,
        accent: Color
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 54, height: 54)
                .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 17, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(status)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(accent)
                    .padding(.top, 2)
            }

            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.05), lineWidth: 1)
        }
    }
}

private enum WeeklyCheckInStep: Int, CaseIterable {
    case energy
    case sleep
    case stress
    case motivation
    case recovery
    case adherence
    case rpe
    case pain
    case steps
    case comment

    var icon: String {
        switch self {
        case .energy: return "bolt.fill"
        case .sleep: return "moon.fill"
        case .stress: return "brain.head.profile"
        case .motivation: return "flame.fill"
        case .recovery: return "heart.text.square.fill"
        case .adherence: return "checkmark.circle.fill"
        case .rpe: return "chart.line.uptrend.xyaxis"
        case .pain: return "cross.case.fill"
        case .steps: return "shoeprints.fill"
        case .comment: return "text.bubble.fill"
        }
    }

    var titleKey: String { "coaching.checkin.weekly.\(String(describing: self)).question" }
    var hintKey: String { "coaching.checkin.weekly.\(String(describing: self)).hint" }
}

private struct WeeklyCheckInDraft: Equatable {
    var energy = 7
    var sleep = 7
    var stress = 5
    var motivation = 7
    var recovery = 7
    var adherence = 7
    var rpe = 7
    var hasPain = false
    var painNotes = ""
    var notes = ""

    subscript(step: WeeklyCheckInStep) -> Int {
        get {
            switch step {
            case .energy: return energy
            case .sleep: return sleep
            case .stress: return stress
            case .motivation: return motivation
            case .recovery: return recovery
            case .adherence: return adherence
            case .rpe: return rpe
            case .pain, .steps, .comment: return 0
            }
        }
        set {
            switch step {
            case .energy: energy = newValue
            case .sleep: sleep = newValue
            case .stress: stress = newValue
            case .motivation: motivation = newValue
            case .recovery: recovery = newValue
            case .adherence: adherence = newValue
            case .rpe: rpe = newValue
            case .pain, .steps, .comment: break
            }
        }
    }
}

private struct ClientWeeklyCheckInScreen: View {
    @ObservedObject var store: ClientCoachingHomeStore
    @EnvironmentObject private var sessionStore: AppSessionStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var stepIndex = 0
    @State private var draft = WeeklyCheckInDraft()
    @State private var isComplete = false
    @StateObject private var stepsStore = HealthKitStepsStore()
    @AppStorage(HealthKitStepsPreference.enabledKey) private var stepsEnabled = false
    @AppStorage(HealthKitStepsPreference.goalKey) private var stepGoal = HealthKitStepsPreference.defaultGoal
    @State private var recentSteps: [HealthKitDailySteps] = []
    @State private var attachSteps = true

    private var step: WeeklyCheckInStep { WeeklyCheckInStep.allCases[stepIndex] }

    var body: some View {
        Group {
            if isComplete {
                completionView
            } else {
                wizardView
            }
        }
        .background(background.ignoresSafeArea())
        .navigationBarBackButtonHidden(isComplete)
        .navigationTitle(AppLocalizer.string("coaching.checkin.weekly.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isComplete == false {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if stepIndex == 0 { dismiss() } else { stepIndex -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.22), value: stepIndex)
    }

    private var wizardView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("\(stepIndex + 1) \(AppLocalizer.string("common.of")) \(WeeklyCheckInStep.allCases.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(stepIndex + 1), total: Double(WeeklyCheckInStep.allCases.count))
                    .tint(.blue)
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Image(systemName: step.icon)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 76, height: 76)
                        .background(Color.blue.opacity(0.12), in: Circle())

                    Text(AppLocalizer.string(step.titleKey))
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    stepContent
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 140)
            }
        }
        .safeAreaInset(edge: .bottom) {
            primaryButton(
                title: stepIndex == WeeklyCheckInStep.allCases.count - 1
                    ? AppLocalizer.string("coaching.checkin.action.submit")
                    : AppLocalizer.string("common.continue")
            ) {
                advance()
            }
            .disabled(store.isSubmitting || (step == .pain && draft.hasPain && draft.painNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            .opacity(store.isSubmitting ? 0.7 : 1)
            .padding(20)
            .background(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .energy, .sleep, .stress, .motivation, .recovery, .adherence, .rpe:
            scaleContent
        case .pain:
            painContent
        case .steps:
            stepsContent
        case .comment:
            commentContent
        }
    }

    private var scaleContent: some View {
        VStack(spacing: 22) {
            Text("\(draft[step])")
                .font(.system(size: 80, weight: .medium, design: .rounded))
                .contentTransition(.numericText())

            Slider(
                value: Binding(
                    get: { Double(draft[step]) },
                    set: { draft[step] = Int($0.rounded()) }
                ),
                in: 1...10,
                step: 1
            )
            .tint(.blue)

            HStack {
                Text("1")
                Spacer()
                Text("10")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)

            Text(AppLocalizer.string(step.hintKey))
                .font(.body)
                .foregroundStyle(.blue)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var painContent: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                selectionButton(AppLocalizer.string("common.no"), selected: draft.hasPain == false) {
                    draft.hasPain = false
                    draft.painNotes = ""
                }
                selectionButton(AppLocalizer.string("common.yes"), selected: draft.hasPain) {
                    draft.hasPain = true
                }
            }

            if draft.hasPain {
                TextField(AppLocalizer.string("coaching.checkin.weekly.pain.placeholder"), text: $draft.painNotes, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(16)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .padding(20)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var commentContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppLocalizer.string("coaching.checkin.optional"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(AppLocalizer.string("coaching.checkin.notes"), text: $draft.notes, axis: .vertical)
                .lineLimit(5...9)
                .padding(16)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(20)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var stepsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if stepsEnabled == false {
                Label(AppLocalizer.string("coaching.checkin.steps.disabled"), systemImage: "heart.slash")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button(AppLocalizer.string("coaching.checkin.steps.connect")) {
                    stepsEnabled = true
                    Task { await loadStepSnapshot(requestAccess: true) }
                }
                .font(.headline)
                .foregroundStyle(.blue)
            } else if stepsStore.isLoading {
                HStack(spacing: 12) {
                    ProgressView()
                    Text(AppLocalizer.string("coaching.checkin.steps.loading"))
                        .foregroundStyle(.secondary)
                }
            } else if recentSteps.count == 7 {
                Toggle(AppLocalizer.string("coaching.checkin.steps.attach"), isOn: $attachSteps)
                    .font(.headline)

                Divider()

                HStack {
                    stepsSummary(
                        AppLocalizer.string("coaching.checkin.steps.average"),
                        value: formattedSteps(recentSteps.reduce(0) { $0 + $1.steps } / 7)
                    )
                    Spacer()
                    stepsSummary(
                        AppLocalizer.string("coaching.checkin.steps.goal_days"),
                        value: "\(recentSteps.filter { $0.steps >= stepGoal }.count)/7"
                    )
                }

                VStack(spacing: 0) {
                    ForEach(recentSteps) { day in
                        HStack {
                            Text(day.date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(formattedSteps(day.steps))
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, 9)
                        if day.id != recentSteps.last?.id { Divider() }
                    }
                }
            } else {
                Text(stepsStore.errorMessage ?? AppLocalizer.string("coaching.checkin.steps.unavailable"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button(AppLocalizer.string("coaching.checkin.steps.retry")) {
                    Task { await loadStepSnapshot(requestAccess: true) }
                }
                .font(.headline)
                .foregroundStyle(.blue)
            }
        }
        .padding(20)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .task {
            await loadStepSnapshot(requestAccess: false)
        }
    }

    private var completionView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                Image(systemName: "checkmark")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 112, height: 112)
                    .background(Color.blue.opacity(0.16), in: Circle())
                    .overlay(Circle().stroke(Color.blue.opacity(0.7), lineWidth: 1))

                VStack(spacing: 8) {
                    Text(AppLocalizer.string("coaching.checkin.weekly.completed"))
                        .font(.largeTitle.bold())
                    Text(AppLocalizer.string("coaching.checkin.weekly.completed.subtitle"))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text(AppLocalizer.string("coaching.checkin.summary"))
                        .font(.title3.bold())
                        .padding(.bottom, 8)
                    summaryRow("bolt.fill", "coaching.checkin.energy", draft.energy)
                    summaryRow("moon.fill", "coaching.checkin.sleep", draft.sleep)
                    summaryRow("brain.head.profile", "coaching.checkin.stress", draft.stress)
                    summaryRow("flame.fill", "coaching.checkin.motivation", draft.motivation)
                    summaryRow("heart.text.square.fill", "coaching.checkin.recovery", draft.recovery)
                    summaryRow("checkmark.circle.fill", "coaching.checkin.adherence", draft.adherence)
                    summaryRow("chart.line.uptrend.xyaxis", "coaching.checkin.rpe", draft.rpe, showsDivider: false)
                }
                .padding(20)
                .background(cardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))

                primaryButton(title: AppLocalizer.string("coaching.checkin.return")) { dismiss() }
            }
            .padding(24)
        }
    }

    private func advance() {
        if stepIndex < WeeklyCheckInStep.allCases.count - 1 {
            stepIndex += 1
            return
        }

        Task {
            await store.submitWeeklyCheckIn(
                energy: draft.energy,
                sleep: draft.sleep,
                stress: draft.stress,
                motivation: draft.motivation,
                recovery: draft.recovery,
                adherence: draft.adherence,
                rpe: draft.rpe,
                hasPain: draft.hasPain,
                painNotes: draft.painNotes,
                notes: draft.notes,
                stepGoal: attachSteps && recentSteps.count == 7 ? stepGoal : 0,
                dailySteps: attachSteps
                    ? recentSteps.map { CheckInDailySteps(date: $0.date, steps: $0.steps) }
                    : [],
                senderName: sessionStore.profile?.displayName ?? ""
            )
            if store.errorMessage == nil { isComplete = true }
        }
    }

    private func summaryRow(_ icon: String, _ titleKey: String, _ value: Int, showsDivider: Bool = true) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 28)
            Text(AppLocalizer.string(titleKey))
            Spacer()
            Text("\(value)")
                .fontWeight(.semibold)
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
            if showsDivider { Divider() }
        }
    }

    @MainActor
    private func loadStepSnapshot(requestAccess: Bool) async {
        guard stepsEnabled else {
            recentSteps = []
            attachSteps = false
            return
        }

        if requestAccess && stepsStore.authorizationNeedsRequest {
            guard await stepsStore.requestAccess() else {
                recentSteps = []
                attachSteps = false
                return
            }
        }

        var values = await stepsStore.recentSevenDays()
        if values == nil && requestAccess && stepsStore.authorizationNeedsRequest {
            guard await stepsStore.requestAccess() else {
                recentSteps = []
                attachSteps = false
                return
            }
            values = await stepsStore.recentSevenDays()
        }

        recentSteps = values ?? []
        attachSteps = recentSteps.count == 7
    }

    private func stepsSummary(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.title3.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func formattedSteps(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    private func selectionButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(selected ? Color.blue : Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var background: Color { colorScheme == .dark ? Color(.systemGroupedBackground) : HomeColors.background }
    private var cardBackground: Color { Color(.secondarySystemGroupedBackground) }
}

private struct ClientMonthlyCheckInScreen: View {
    @ObservedObject var store: ClientCoachingHomeStore
    @EnvironmentObject private var sessionStore: AppSessionStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var weight = ""
    @State private var waist = ""
    @State private var chest = ""
    @State private var hips = ""
    @State private var notes = ""
    @State private var didPrefill = false
    @State private var isComplete = false

    var body: some View {
        Group {
            if isComplete {
                completionView
            } else {
                formView
            }
        }
        .background(background.ignoresSafeArea())
        .navigationTitle(AppLocalizer.string("coaching.checkin.monthly.title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isComplete)
        .onAppear(perform: prefill)
    }

    private var formView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(AppLocalizer.string("coaching.checkin.monthly.heading"))
                        .font(.title.bold())
                    Text(AppLocalizer.string("coaching.checkin.monthly.description"))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 0) {
                    measurementField("coaching.intake.weight", value: $weight, unit: "coaching.unit.kg")
                    Divider().padding(.leading, 18)
                    measurementField("coaching.intake.measurement.waist", value: $waist, unit: "coaching.unit.cm")
                    Divider().padding(.leading, 18)
                    measurementField("coaching.intake.measurement.chest", value: $chest, unit: "coaching.unit.cm")
                    Divider().padding(.leading, 18)
                    measurementField("coaching.intake.measurement.hips", value: $hips, unit: "coaching.unit.cm")
                }
                .background(cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    Text(AppLocalizer.string("coaching.checkin.notes"))
                        .font(.headline)
                    TextField(AppLocalizer.string("coaching.checkin.optional"), text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .padding(16)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(18)
                .background(cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                if let error = store.errorMessage, error.isEmpty == false {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                primaryButton(title: AppLocalizer.string("coaching.checkin.action.submit")) { submit() }
                    .disabled(isValid == false || store.isSubmitting)
                    .opacity(isValid && store.isSubmitting == false ? 1 : 0.5)
            }
            .padding(20)
        }
    }

    private var completionView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(.purple)
                .frame(width: 112, height: 112)
                .background(Color.purple.opacity(0.15), in: Circle())
            Text(AppLocalizer.string("coaching.checkin.monthly.completed"))
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(AppLocalizer.string("coaching.checkin.monthly.completed.subtitle"))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            primaryButton(title: AppLocalizer.string("coaching.checkin.return")) { dismiss() }
        }
        .padding(24)
    }

    private func measurementField(_ titleKey: String, value: Binding<String>, unit: String) -> some View {
        HStack(spacing: 12) {
            Text(AppLocalizer.string(titleKey))
            Spacer()
            TextField("0", text: value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
            Text(AppLocalizer.string(unit))
                .foregroundStyle(.secondary)
        }
        .font(.body)
        .padding(18)
    }

    private var isValid: Bool {
        parsed(weight) > 0 && parsed(waist) > 0 && parsed(chest) > 0 && parsed(hips) > 0
    }

    private func prefill() {
        guard didPrefill == false else { return }
        didPrefill = true
        guard let latest = store.checkIns.first(where: { $0.includesMeasurements && $0.weight > 0 }) else { return }
        weight = format(latest.weight)
        waist = format(latest.waist)
        chest = format(latest.chest)
        hips = format(latest.hips)
    }

    private func submit() {
        guard isValid else { return }
        Task {
            await store.submitMonthlyCheckIn(
                weight: parsed(weight),
                waist: parsed(waist),
                chest: parsed(chest),
                hips: parsed(hips),
                notes: notes,
                senderName: sessionStore.profile?.displayName ?? ""
            )
            if store.errorMessage == nil { isComplete = true }
        }
    }

    private func parsed(_ value: String) -> Double {
        Double(value.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func format(_ value: Double) -> String {
        String(format: "%.1f", value).replacingOccurrences(of: ".", with: Locale.current.decimalSeparator ?? ".")
    }

    private var background: Color { colorScheme == .dark ? Color(.systemGroupedBackground) : HomeColors.background }
    private var cardBackground: Color { Color(.secondarySystemGroupedBackground) }
}

private func primaryButton(title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(HomeColors.primaryActionGradient, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
    }
    .buttonStyle(.plain)
}

struct TrainerWeeklyCheckInOverviewCard: View {
    let checkIns: [ProgressCheckIn]
    let openHistory: () -> Void

    private var weekly: [ProgressCheckIn] {
        checkIns.filter { $0.kind == .weekly }.sorted { $0.createdAt > $1.createdAt }
    }

    private var latest: ProgressCheckIn? { weekly.first }
    private var previous: ProgressCheckIn? { weekly.dropFirst().first }

    var body: some View {
        if let latest {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(AppLocalizer.string("coaching.checkin.trainer.weekly"))
                            .font(.headline)
                        Text(latest.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if attentionReasons(for: latest).isEmpty == false {
                        Label(AppLocalizer.string("coaching.checkin.trainer.attention"), systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                    metric("coaching.checkin.energy", value: latest.energy, previous: previous?.energy, higherIsBetter: true)
                    metric("coaching.checkin.sleep", value: latest.sleep, previous: previous?.sleep, higherIsBetter: true)
                    metric("coaching.checkin.stress", value: latest.stress, previous: previous?.stress, higherIsBetter: false)
                    metric("coaching.checkin.recovery", value: latest.recovery, previous: previous?.recovery, higherIsBetter: true)
                    metric("coaching.checkin.motivation", value: latest.motivation, previous: previous?.motivation, higherIsBetter: true)
                    metric("coaching.checkin.rpe", value: latest.rpe, previous: previous?.rpe, higherIsBetter: nil)
                }

                if let insight = insight(for: latest) {
                    Label(insight, systemImage: "sparkles")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }

                Button(action: openHistory) {
                    HStack {
                        Text(AppLocalizer.string("coaching.checkin.trainer.open_history"))
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HomeColors.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.16))
            }
        }
    }

    private func metric(_ key: String, value: Int, previous: Int?, higherIsBetter: Bool?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(AppLocalizer.string(key))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(value)")
                    .font(.title3.bold())
                    .foregroundStyle(scoreColor(for: value))
                Text("/10")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(scoreColor(for: value).opacity(0.82))
                Spacer()
                if let previous, previous != value {
                    let delta = value - previous
                    Image(systemName: delta > 0 ? "arrow.up" : "arrow.down")
                        .font(.caption.bold())
                        .foregroundStyle(deltaColor(delta: delta, higherIsBetter: higherIsBetter))
                    Text("\(abs(delta))")
                        .font(.caption.bold())
                        .foregroundStyle(deltaColor(delta: delta, higherIsBetter: higherIsBetter))
                }
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func scoreColor(for value: Int) -> Color {
        switch value {
        case ...2:
            return Color(red: 1.00, green: 0.22, blue: 0.24)
        case 3...4:
            return Color(red: 1.00, green: 0.38, blue: 0.08)
        case 5...6:
            return Color(red: 1.00, green: 0.78, blue: 0.05)
        case 7...8:
            return Color(red: 0.24, green: 0.82, blue: 0.35)
        default:
            return Color(red: 0.00, green: 0.72, blue: 0.30)
        }
    }

    private func deltaColor(delta: Int, higherIsBetter: Bool?) -> Color {
        guard let higherIsBetter else { return .secondary }
        return (delta > 0) == higherIsBetter ? .green : .red
    }

    private func attentionReasons(for value: ProgressCheckIn) -> [String] {
        var reasons: [String] = []
        if value.hasPain { reasons.append(AppLocalizer.string("coaching.checkin.trainer.reason.pain")) }
        if value.sleep <= 5 { reasons.append(AppLocalizer.string("coaching.checkin.trainer.reason.sleep")) }
        if value.recovery <= 4 { reasons.append(AppLocalizer.string("coaching.checkin.trainer.reason.recovery")) }
        if value.stress >= 8 { reasons.append(AppLocalizer.string("coaching.checkin.trainer.reason.stress")) }
        if value.rpe >= 9 { reasons.append(AppLocalizer.string("coaching.checkin.trainer.reason.rpe")) }
        return reasons
    }

    private func insight(for value: ProgressCheckIn) -> String? {
        let reasons = attentionReasons(for: value)
        if reasons.isEmpty {
            return AppLocalizer.string("coaching.checkin.trainer.stable")
        }
        return AppLocalizer.format("coaching.checkin.trainer.insight", reasons.joined(separator: ", "))
    }
}
