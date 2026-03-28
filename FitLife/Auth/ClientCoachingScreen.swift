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
            if store.isLoading || sessionStore.profile == nil {
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

    private var shouldShowForm: Bool {
        if isEditing { return true }
        guard let request = store.request else { return true }
        return request.status == .draft || request.status == .needsClarification || request.status == .rejected
    }
}

private struct ClientCoachingIntakeScreen: View {
    @ObservedObject var store: ClientCoachingStore
    @EnvironmentObject private var sessionStore: AppSessionStore

    var body: some View {
        Form {
            if let errorMessage = store.errorMessage, errorMessage.isEmpty == false {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            if let intakeBinding = Binding($store.intake) {
                Section(AppLocalizer.string("coaching.intake.section.basics")) {
                    Picker(AppLocalizer.string("coaching.intake.goal"), selection: intakeBinding.goal) {
                        ForEach(ClientCoachingGoal.allCases) { goal in
                            Text(AppLocalizer.string(goal.localizationKey)).tag(goal)
                        }
                    }

                    Stepper(value: intakeBinding.age, in: 14...80) {
                        HStack {
                            Text(AppLocalizer.string("coaching.intake.age"))
                            Spacer()
                            Text("\(intakeBinding.wrappedValue.age)")
                                .foregroundStyle(.secondary)
                        }
                    }

                    metricField(
                        title: AppLocalizer.string("coaching.intake.height"),
                        value: intakeBinding.height,
                        unit: AppLocalizer.string("coaching.unit.cm"),
                        precision: .fractionLength(0)
                    )

                    metricField(
                        title: AppLocalizer.string("coaching.intake.weight"),
                        value: intakeBinding.weight,
                        unit: AppLocalizer.string("coaching.unit.kg"),
                        precision: .fractionLength(1)
                    )

                    Picker(AppLocalizer.string("coaching.intake.sex"), selection: intakeBinding.sex) {
                        ForEach(ClientCoachingSex.allCases) { sex in
                            Text(AppLocalizer.string(sex.localizationKey)).tag(sex)
                        }
                    }
                }

                Section(AppLocalizer.string("coaching.intake.section.training")) {
                    Picker(AppLocalizer.string("coaching.intake.activity"), selection: intakeBinding.activity) {
                        ForEach(ClientCoachingActivity.allCases) { level in
                            Text(AppLocalizer.string(level.localizationKey)).tag(level)
                        }
                    }

                    Picker(AppLocalizer.string("coaching.intake.experience"), selection: intakeBinding.experience) {
                        ForEach(ClientCoachingExperience.allCases) { level in
                            Text(AppLocalizer.string(level.localizationKey)).tag(level)
                        }
                    }

                    TextField(AppLocalizer.string("coaching.intake.limitations"), text: intakeBinding.limitations, axis: .vertical)
                        .lineLimit(3...6)

                    TextField(AppLocalizer.string("coaching.intake.equipment"), text: intakeBinding.equipment, axis: .vertical)
                        .lineLimit(2...5)

                    TextField(AppLocalizer.string("coaching.intake.schedule"), text: intakeBinding.schedule, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section(AppLocalizer.string("coaching.intake.section.measurements")) {
                    metricField(
                        title: AppLocalizer.string("coaching.intake.measurement.waist"),
                        value: intakeBinding.measurements.waist,
                        unit: AppLocalizer.string("coaching.unit.cm"),
                        precision: .fractionLength(1)
                    )
                    metricField(
                        title: AppLocalizer.string("coaching.intake.measurement.chest"),
                        value: intakeBinding.measurements.chest,
                        unit: AppLocalizer.string("coaching.unit.cm"),
                        precision: .fractionLength(1)
                    )
                    metricField(
                        title: AppLocalizer.string("coaching.intake.measurement.hips"),
                        value: intakeBinding.measurements.hips,
                        unit: AppLocalizer.string("coaching.unit.cm"),
                        precision: .fractionLength(1)
                    )
                }

                Section(AppLocalizer.string("coaching.intake.section.notes")) {
                    TextField(AppLocalizer.string("coaching.intake.notes"), text: intakeBinding.notes, axis: .vertical)
                        .lineLimit(4...8)
                }

                Section {
                    Button {
                        Task {
                            guard let profile = sessionStore.profile else { return }
                            await store.saveDraft(profile: profile)
                        }
                    } label: {
                        actionRow(title: AppLocalizer.string("coaching.action.save"))
                    }
                    .disabled(store.isSaving)

                    Button {
                        Task {
                            guard let profile = sessionStore.profile else { return }
                            await store.submit(profile: profile)
                        }
                    } label: {
                        actionRow(title: AppLocalizer.string("coaching.action.submit"), bold: true)
                    }
                    .disabled(store.isSaving)
                }
            }
        }
        .navigationTitle(AppLocalizer.string("workouts.connection"))
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
