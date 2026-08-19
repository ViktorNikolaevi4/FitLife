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
        return trimmed.isEmpty ? "тренеру" : trimmed
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
            Text(errorMessage ?? "Попробуйте ещё раз.")
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
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            WorkoutCompletionMetricCard(
                title: "Длительность",
                value: formattedDuration,
                icon: "clock.fill",
                tint: .blue
            )
            WorkoutCompletionMetricCard(
                title: "Калории",
                value: "\(workout.estimatedCalories) ккал",
                icon: "flame.fill",
                tint: .orange
            )
            WorkoutCompletionMetricCard(
                title: "Упражнения",
                value: "\(completedExerciseCount) из \(exerciseCount)",
                icon: "figure.strengthtraining.traditional",
                tint: .indigo
            )
            WorkoutCompletionMetricCard(
                title: "Подходы",
                value: "\(completedSetCount) из \(setGroups.count)",
                icon: "square.stack.3d.up.fill",
                tint: .green
            )
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
                    Image(systemName: didSend ? "checkmark.circle.fill" : "person.crop.circle.badge.checkmark")
                        .font(.title2)
                        .foregroundStyle(didSend ? Color.green : Color.blue)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(didSend ? "Отчёт отправлен" : "Поделиться с тренером")
                            .font(.headline)
                        Text(didSend ? "\(trainerDisplayName) увидит результат тренировки." : "Связь одобрена · \(trainerDisplayName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if didSend == false {
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
            if activeLink != nil && didSend == false {
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
                        Text(isSending ? "Отправляем…" : "Отправить тренеру")
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
            return "Активная тренировка"
        }
        return trimmed
    }

    private var formattedDuration: String {
        let seconds = max(0, workout.elapsedSeconds)
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        if hours > 0 {
            return "\(hours) ч \(minutes) мин"
        }
        return "\(max(1, minutes)) мин"
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
        let notification = AppNotificationEvent(
            id: "workout-report-\(report.id)",
            type: .workoutReportSent,
            recipientId: link.trainerId,
            senderId: link.clientId,
            senderName: sessionStore.profile?.displayName ?? "",
            targetType: .workoutReport,
            targetId: report.id
        )

        do {
            let batch = firestore.batch()
            batch.setData(
                report.firestoreData,
                forDocument: firestore.collection("coaching_workout_reports").document(report.id)
            )
            batch.setData(
                notification.firestoreData,
                forDocument: firestore.collection("notification_events").document(notification.id)
            )
            try await batch.commit()
            didSend = true
            isSending = false
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
