import SwiftUI

struct ClientCoachingEntryScreen: View {
    let clientId: String

    @EnvironmentObject private var sessionStore: AppSessionStore
    @StateObject private var store: ClientCoachingStore
    @State private var isEditing = false

    init(clientId: String) {
        self.clientId = clientId
        _store = StateObject(wrappedValue: ClientCoachingStore(clientId: clientId))
    }

    var body: some View {
        Group {
            if sessionStore.profile == nil || isInitialLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
            } else if store.activeLink != nil {
                ClientCoachingLinkedScreen(
                    clientId: clientId,
                    trainerId: store.activeLink?.trainerId,
                    trainer: store.trainerProfile
                )
            } else if shouldShowForm {
                ClientCoachingIntakeScreen(store: store)
            } else {
                ClientCoachingStatusScreen(request: store.request) {
                    store.startEditing()
                    isEditing = true
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task(id: sessionStore.profile?.id) {
            guard let profile = sessionStore.profile else { return }
            await store.load(profile: profile)
        }
    }

    private var isInitialLoading: Bool {
        store.isLoading &&
        store.intake == nil &&
        store.request == nil &&
        store.activeLink == nil
    }

    private var shouldShowForm: Bool {
        if isEditing { return true }
        guard let request = store.request else { return true }
        return request.status == .draft || request.status == .needsClarification || request.status == .rejected
    }
}

private struct ClientCoachingIntakeScreen: View {
    @ObservedObject var store: ClientCoachingStore
    @EnvironmentObject private var sessionStore: AppSessionStore
    @State private var selectedStep: IntakeStep = .goal

    private enum IntakeStep: Int, CaseIterable, Identifiable {
        case goal
        case body
        case training
        case measurements
        case notes

        var id: Int { rawValue }

        var titleKey: String {
            switch self {
            case .goal: "coaching.intake.step.goal.title"
            case .body: "coaching.intake.step.body.title"
            case .training: "coaching.intake.step.training.title"
            case .measurements: "coaching.intake.step.measurements.title"
            case .notes: "coaching.intake.step.notes.title"
            }
        }

        var subtitleKey: String {
            switch self {
            case .goal: "coaching.intake.step.goal.subtitle"
            case .body: "coaching.intake.step.body.subtitle"
            case .training: "coaching.intake.step.training.subtitle"
            case .measurements: "coaching.intake.step.measurements.subtitle"
            case .notes: "coaching.intake.step.notes.subtitle"
            }
        }
    }

    var body: some View {
        Group {
            if let intakeBinding = Binding($store.intake) {
                VStack(spacing: 0) {
                    header

                    TabView(selection: $selectedStep) {
                        ForEach(IntakeStep.allCases) { step in
                            intakePage(step, intake: intakeBinding)
                                .tag(step)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
                .safeAreaInset(edge: .bottom) {
                    bottomBar
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(AppLocalizer.string("workouts.connection"))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let errorMessage = store.errorMessage, errorMessage.isEmpty == false {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
            }

            HStack(spacing: 8) {
                ForEach(IntakeStep.allCases) { step in
                    Capsule()
                        .fill(step.rawValue <= selectedStep.rawValue ? Color.accentColor : Color(.tertiarySystemFill))
                        .frame(height: 5)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(AppLocalizer.string(selectedStep.titleKey))
                    .font(.title2.weight(.bold))

                Text(AppLocalizer.string(selectedStep.subtitleKey))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func intakePage(_ step: IntakeStep, intake: Binding<ClientIntakeProfile>) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                switch step {
                case .goal:
                    choiceCard(
                        title: AppLocalizer.string("coaching.intake.goal"),
                        value: intake.goal,
                        options: ClientCoachingGoal.allCases
                    ) { AppLocalizer.string($0.localizationKey) }

                case .body:
                    numberStepperCard(
                        title: AppLocalizer.string("coaching.intake.age"),
                        value: intake.age,
                        range: 14...80,
                        unit: AppLocalizer.string("coaching.unit.years")
                    )
                    metricCard(
                        title: AppLocalizer.string("coaching.intake.height"),
                        value: intake.height,
                        unit: AppLocalizer.string("coaching.unit.cm"),
                        precision: .fractionLength(0)
                    )
                    metricCard(
                        title: AppLocalizer.string("coaching.intake.weight"),
                        value: intake.weight,
                        unit: AppLocalizer.string("coaching.unit.kg"),
                        precision: .fractionLength(1)
                    )
                    choiceCard(
                        title: AppLocalizer.string("coaching.intake.sex"),
                        value: intake.sex,
                        options: ClientCoachingSex.allCases
                    ) { AppLocalizer.string($0.localizationKey) }

                case .training:
                    choiceCard(
                        title: AppLocalizer.string("coaching.intake.activity"),
                        value: intake.activity,
                        options: ClientCoachingActivity.allCases
                    ) { AppLocalizer.string($0.localizationKey) }
                    choiceCard(
                        title: AppLocalizer.string("coaching.intake.experience"),
                        value: intake.experience,
                        options: ClientCoachingExperience.allCases
                    ) { AppLocalizer.string($0.localizationKey) }
                    textAreaCard(
                        title: AppLocalizer.string("coaching.intake.limitations"),
                        placeholder: AppLocalizer.string("coaching.intake.limitations.placeholder"),
                        text: intake.limitations,
                        minHeight: 104
                    )
                    textAreaCard(
                        title: AppLocalizer.string("coaching.intake.equipment"),
                        placeholder: AppLocalizer.string("coaching.intake.equipment.placeholder"),
                        text: intake.equipment,
                        minHeight: 92
                    )
                    textAreaCard(
                        title: AppLocalizer.string("coaching.intake.schedule"),
                        placeholder: AppLocalizer.string("coaching.intake.schedule.placeholder"),
                        text: intake.schedule,
                        minHeight: 92
                    )

                case .measurements:
                    metricCard(
                        title: AppLocalizer.string("coaching.intake.measurement.waist"),
                        value: intake.measurements.waist,
                        unit: AppLocalizer.string("coaching.unit.cm"),
                        precision: .fractionLength(1)
                    )
                    metricCard(
                        title: AppLocalizer.string("coaching.intake.measurement.chest"),
                        value: intake.measurements.chest,
                        unit: AppLocalizer.string("coaching.unit.cm"),
                        precision: .fractionLength(1)
                    )
                    metricCard(
                        title: AppLocalizer.string("coaching.intake.measurement.hips"),
                        value: intake.measurements.hips,
                        unit: AppLocalizer.string("coaching.unit.cm"),
                        precision: .fractionLength(1)
                    )

                case .notes:
                    textAreaCard(
                        title: AppLocalizer.string("coaching.intake.notes"),
                        placeholder: AppLocalizer.string("coaching.intake.notes.placeholder"),
                        text: intake.notes,
                        minHeight: 180
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 12) {
                Button {
                    moveBack()
                } label: {
                    Text(AppLocalizer.string("common.back"))
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .disabled(selectedStep == IntakeStep.allCases.first || store.isSaving)

                Button {
                    if selectedStep == IntakeStep.allCases.last {
                        Task {
                            guard let profile = sessionStore.profile else { return }
                            await store.submit(profile: profile)
                        }
                    } else {
                        moveForward()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(selectedStep == IntakeStep.allCases.last ? AppLocalizer.string("coaching.action.submit") : AppLocalizer.string("common.next"))
                            .font(.headline.weight(.semibold))
                        if store.isSaving {
                            ProgressView()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isSaving)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Button {
                Task {
                    guard let profile = sessionStore.profile else { return }
                    await store.saveDraft(profile: profile)
                }
            } label: {
                Text(AppLocalizer.string("coaching.action.save"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .disabled(store.isSaving)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
    }

    private func moveBack() {
        guard let previous = IntakeStep(rawValue: selectedStep.rawValue - 1) else { return }
        withAnimation(.snappy) {
            selectedStep = previous
        }
    }

    private func moveForward() {
        guard let next = IntakeStep(rawValue: selectedStep.rawValue + 1) else { return }
        withAnimation(.snappy) {
            selectedStep = next
        }
    }

    private func card<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color(.separator).opacity(0.20)))
    }

    private func choiceCard<Value: Hashable>(
        title: String,
        value: Binding<Value>,
        options: [Value],
        label: @escaping (Value) -> String
    ) -> some View {
        card(title: title) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 10)], spacing: 10) {
                ForEach(options, id: \.self) { option in
                    Button {
                        value.wrappedValue = option
                    } label: {
                        HStack {
                            Text(label(option))
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                            if value.wrappedValue == option {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        .foregroundStyle(value.wrappedValue == option ? Color.white : Color.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        .background(
                            value.wrappedValue == option ? Color.accentColor : Color(.tertiarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func numberStepperCard(
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        unit: String
    ) -> some View {
        card(title: title) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(value.wrappedValue)")
                        .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 10) {
                    roundStepperButton(systemImage: "minus") {
                        value.wrappedValue = max(range.lowerBound, value.wrappedValue - 1)
                    }
                    roundStepperButton(systemImage: "plus") {
                        value.wrappedValue = min(range.upperBound, value.wrappedValue + 1)
                    }
                }
            }
        }
    }

    private func roundStepperButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .frame(width: 48, height: 48)
                .background(Color(.tertiarySystemGroupedBackground), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func metricCard(
        title: String,
        value: Binding<Double>,
        unit: String,
        precision: FloatingPointFormatStyle<Double>.Configuration.Precision
    ) -> some View {
        card(title: title) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                TextField("0", value: value, format: .number.precision(precision))
                    .keyboardType(.decimalPad)
                    .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
                    .multilineTextAlignment(.leading)

                Text(unit)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func textAreaCard(
        title: String,
        placeholder: String,
        text: Binding<String>,
        minHeight: CGFloat
    ) -> some View {
        card(title: title) {
            ZStack(alignment: .topLeading) {
                if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                }

                TextEditor(text: text)
                    .frame(minHeight: minHeight)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func metricField(
        title: String,
        value: Binding<Double>,
        unit: String,
        precision: FloatingPointFormatStyle<Double>.Configuration.Precision
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: value, format: .number.precision(precision))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }

    private func actionRow(title: String, bold: Bool = false) -> some View {
        HStack {
            Text(title)
                .fontWeight(bold ? .semibold : .regular)
            Spacer()
            if store.isSaving {
                ProgressView()
            }
        }
    }
}

private struct ClientCoachingStatusScreen: View {
    let request: CoachingRequest?
    let onEdit: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text(AppLocalizer.string("coaching.status.title"))
                    .font(.largeTitle.bold())

                Text(AppLocalizer.string(request?.status.localizationKey ?? CoachingRequestStatus.draft.localizationKey))
                    .font(.title3.weight(.semibold))

                Text(statusDescription)
                    .foregroundStyle(.secondary)

                if let reviewComment = request?.reviewComment, reviewComment.isEmpty == false {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(commentTitle)
                            .font(.headline)
                        Text(reviewComment)
                            .foregroundStyle(.primary)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(commentBackground, in: RoundedRectangle(cornerRadius: 18))
                }

                if request?.status == .needsClarification {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(AppLocalizer.string("coaching.status.next_step.title"))
                            .font(.headline)
                        Text(AppLocalizer.string("coaching.status.next_step.clarification"))
                            .foregroundStyle(.secondary)
                    }
                }

                if canEdit {
                    Button(primaryActionTitle) {
                        onEdit()
                    }
                    .buttonStyle(.borderedProminent)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(AppLocalizer.string("workouts.connection"))
    }

    private var canEdit: Bool {
        guard let request else { return true }
        return request.status == .draft || request.status == .needsClarification || request.status == .rejected
    }

    private var statusDescription: String {
        guard let request else {
            return AppLocalizer.string("coaching.status.description.draft")
        }

        switch request.status {
        case .draft:
            return AppLocalizer.string("coaching.status.description.draft")
        case .submitted:
            return AppLocalizer.string("coaching.status.description.submitted")
        case .needsClarification:
            return AppLocalizer.string("coaching.status.description.needs_clarification")
        case .approved:
            return AppLocalizer.string("coaching.status.description.approved")
        case .rejected:
            return AppLocalizer.string("coaching.status.description.rejected")
        case .assigned:
            return AppLocalizer.string("coaching.status.description.assigned")
        }
    }

    private var primaryActionTitle: String {
        if request?.status == .needsClarification {
            return AppLocalizer.string("coaching.action.fix")
        }

        return AppLocalizer.string("coaching.action.edit")
    }

    private var commentTitle: String {
        if request?.status == .needsClarification {
            return AppLocalizer.string("coaching.status.comment.clarification")
        }

        return AppLocalizer.string("coaching.status.comment")
    }

    private var commentBackground: Color {
        if request?.status == .needsClarification {
            return .orange.opacity(0.14)
        }

        return Color(.secondarySystemGroupedBackground)
    }
}

private struct ClientCoachingLinkedScreen: View {
    let clientId: String
    let trainerId: String?
    let trainer: AppUserProfile?

    var body: some View {
        Group {
            if let trainerId {
                ClientCoachingHomeScreen(
                    clientId: clientId,
                    trainerId: trainerId,
                    trainer: trainer
                )
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(AppLocalizer.string("coaching.linked.title"))
                            .font(.largeTitle.bold())

                        Text(AppLocalizer.string("coaching.linked.subtitle"))
                            .foregroundStyle(.secondary)

                        Text(AppLocalizer.string("coaching.linked.next_step"))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                }
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
                .navigationTitle(AppLocalizer.string("workouts.connection"))
            }
        }
    }
}
