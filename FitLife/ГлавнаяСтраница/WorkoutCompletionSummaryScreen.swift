import SwiftUI
import FirebaseFirestore

struct WorkoutCompletionSummaryScreen: View {
    @EnvironmentObject private var sessionStore: AppSessionStore

    let workout: WorkoutSession
    let onDone: () -> Void

    @State private var activeLink: TrainerClientLink?
    @State private var trainerName = ""
    @State private var isCheckingConnection = true
    @State private var isSending = false
    @State private var didSend = false
    @State private var isQueuedForDelivery = false
    @State private var connectionError = false
    @State private var errorMessage: String?

    private let firestore = Firestore.firestore()

    private var exerciseCount: Int {
        workout.exerciseItems.count
    }

    private var completedExerciseCount: Int {
        workout.exerciseItems.filter(\.isFinished).count
    }

    private var setGroups: [WorkoutSetGroupDescriptor] {
        workout.exerciseItems.flatMap(workoutSetGroups(for:))
    }

    private var completedSetCount: Int {
        setGroups.filter(\.isCompleted).count
    }

    private var trainerDisplayName: String {
        let trimmed = trainerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? AppLocalizer.string("workout.completion.trainer_fallback") : trimmed
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                completionHero
                metricsGrid
                trainerSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 30)
            .padding(.bottom, 150)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            bottomActions
        }
        .interactiveDismissDisabled()
        .task {
            await loadActiveTrainerConnection()
        }
        .alert(
            "Не удалось отправить тренировку",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if $0 == false { errorMessage = nil } }
            )
        ) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text(errorMessage ?? AppLocalizer.string("common.try_again"))
        }
    }

    private var completionHero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.14))
                    .frame(width: 92, height: 92)

                Image(systemName: "checkmark")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.green)
            }

            VStack(spacing: 6) {
                Text("Тренировка завершена")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text(displayWorkoutTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text(workout.createdAt.formatted(date: .long, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private var metricsGrid: some View {
        VStack(spacing: 12) {
            WorkoutCompletionMetricCard(
                title: AppLocalizer.string("workout.completion.calories"),
                value: AppLocalizer.format("workout.energy.kcal", workout.estimatedCalories),
                icon: "flame.fill",
                tint: .orange
            )

            HStack(spacing: 12) {
                WorkoutCompletionMetricCard(
                    title: AppLocalizer.string("workout.completion.exercises"),
                    value: AppLocalizer.format("workout.progress.out_of", completedExerciseCount, exerciseCount),
                    icon: "figure.strengthtraining.traditional",
                    tint: .indigo
                )
                WorkoutCompletionMetricCard(
                    title: AppLocalizer.string("workout.completion.sets"),
                    value: AppLocalizer.format("workout.progress.out_of", completedSetCount, setGroups.count),
                    icon: "square.stack.3d.up.fill",
                    tint: .green
                )
            }
        }
    }

    @ViewBuilder
    private var trainerSection: some View {
        if isCheckingConnection {
            HStack(spacing: 12) {
                ProgressView()
                Text("Проверяем связь с тренером…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(summaryCardBackground)
        } else if let activeLink {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: didSend ? "checkmark.circle.fill" : (isQueuedForDelivery ? "clock.badge.checkmark.fill" : "person.crop.circle.badge.checkmark"))
                        .font(.title2)
                        .foregroundStyle(didSend ? Color.green : Color.blue)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(didSend ? AppLocalizer.string("workout.completion.report_sent") : (isQueuedForDelivery ? AppLocalizer.string("workout.completion.report_queued") : AppLocalizer.string("workout.completion.share_with_trainer")))
                            .font(.headline)
                        Text(didSend ? AppLocalizer.format("workout.completion.trainer_will_see", trainerDisplayName) : (isQueuedForDelivery ? AppLocalizer.string("workout.completion.send_when_online") : AppLocalizer.format("workout.completion.connection_approved", trainerDisplayName)))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if didSend == false && isQueuedForDelivery == false {
                    Divider()
                    Text("Тренеру будут доступны упражнения, выполненные подходы, фактические веса, повторения и ваши заметки.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(summaryCardBackground)
            .accessibilityElement(children: .combine)
            .accessibilityValue(activeLink.trainerId)
        } else if connectionError {
            VStack(alignment: .leading, spacing: 12) {
                Label("Не удалось проверить связь с тренером", systemImage: "wifi.exclamationmark")
                    .font(.headline)
                Text("Результат сохранён на устройстве. Проверьте интернет и повторите проверку — тренировку можно отправить позже из раздела связи с тренером.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Проверить снова") {
                    Task { await loadActiveTrainerConnection() }
                }
                .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(summaryCardBackground)
        } else if sessionStore.profile?.role == .client {
            VStack(alignment: .leading, spacing: 8) {
                Label("Тренер не подключён", systemImage: "person.crop.circle.badge.questionmark")
                    .font(.headline)
                Text("Тренировка сохранена. После одобрения связи вы сможете отправлять тренеру отчёты.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(summaryCardBackground)
        }
    }

    private var bottomActions: some View {
        VStack(spacing: 10) {
            if activeLink != nil && didSend == false && isQueuedForDelivery == false {
                Button {
                    Task { await sendToTrainer() }
                } label: {
                    HStack(spacing: 10) {
                        if isSending {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                        Text(isSending ? AppLocalizer.string("workout.completion.sending") : AppLocalizer.string("workout.completion.send_to_trainer"))
                    }
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(RoundedRectangle(cornerRadius: 20).fill(HomeColors.primaryActionGradient))
                }
                .buttonStyle(.plain)
                .disabled(isSending)

                Button("Готово без отправки", action: onDone)
                    .font(.headline)
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .disabled(isSending)
            } else {
                Button(action: onDone) {
                    Label("Готово", systemImage: didSend ? "checkmark.circle.fill" : "checkmark")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(RoundedRectangle(cornerRadius: 20).fill(HomeColors.primaryActionGradient))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.bar)
    }

    private var summaryCardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.35))
            }
    }

    private var displayWorkoutTitle: String {
        let trimmed = workout.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "Активная тренировка" || trimmed == "Active Workout" {
            return AppLocalizer.string("workout.active.title")
        }
        return trimmed
    }

    @MainActor
    private func loadActiveTrainerConnection() async {
        isCheckingConnection = true
        connectionError = false
        errorMessage = nil
        activeLink = nil
        trainerName = ""

        guard let profile = sessionStore.profile, profile.role == .client else {
            isCheckingConnection = false
            return
        }

        do {
            let snapshot = try await firestore
                .collection("trainer_client_links")
                .whereField("clientId", isEqualTo: profile.id)
                .whereField("status", isEqualTo: "active")
                .limit(to: 1)
                .getDocuments()

            guard let document = snapshot.documents.first,
                  let link = TrainerClientLink(id: document.documentID, data: document.data()) else {
                isCheckingConnection = false
                return
            }

            activeLink = link
            if let profileDocument = try? await firestore.collection("users").document(link.trainerId).getDocument(),
               let data = profileDocument.data() {
                trainerName = (data["displayName"] as? String) ?? ""
            }
            isCheckingConnection = false
        } catch {
            connectionError = true
            isCheckingConnection = false
        }
    }

    @MainActor
    private func sendToTrainer() async {
        guard let link = activeLink, isSending == false else { return }
        isSending = true
        errorMessage = nil

        let report = CoachingWorkoutReport(
            clientId: link.clientId,
            trainerId: link.trainerId,
            workouts: [CoachingWorkoutSnapshot(workout: workout)]
        )
        do {
            let result = try await CoachingReportDeliveryOutbox.shared.submitWorkoutReport(
                report,
                senderName: sessionStore.profile?.displayName ?? "",
                firestore: firestore
            )
            didSend = result == .delivered
            isQueuedForDelivery = result == .queued
            isSending = false
            onDone()
        } catch {
            errorMessage = AppErrorPresenter.message(for: error)
            isSending = false
        }
    }
}

private struct WorkoutCompletionMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.headline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color(.separator).opacity(0.35))
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}
