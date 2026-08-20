import SwiftUI
import HealthKit

enum HealthKitStepsPreference {
    static let enabledKey = "healthkit.steps.enabled"
    static let goalKey = "healthkit.steps.goal"
    static let defaultGoal = 10_000
}

@MainActor
final class HealthKitStepsStore: ObservableObject {
    @Published private(set) var steps = 0
    @Published private(set) var isLoading = false
    @Published private(set) var isAvailable = HKHealthStore.isHealthDataAvailable()
    @Published private(set) var errorMessage: String?

    private let healthStore = HKHealthStore()

    func requestAccess() async -> Bool {
        guard isAvailable, let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            errorMessage = AppLocalizer.string("health.steps.unavailable")
            return false
        }

        isLoading = true
        errorMessage = nil
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [stepType])
            isLoading = false
            return true
        } catch {
            errorMessage = AppErrorPresenter.message(for: error)
            isLoading = false
            return false
        }
    }

    func loadSteps(for date: Date) async {
        guard isAvailable, let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            steps = 0
            errorMessage = AppLocalizer.string("health.steps.unavailable")
            return
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }

        isLoading = true
        errorMessage = nil
        do {
            let value = try await cumulativeSteps(type: stepType, start: start, end: end)
            steps = max(0, Int(value.rounded()))
        } catch {
            steps = 0
            errorMessage = AppErrorPresenter.message(for: error)
        }
        isLoading = false
    }

    private func cumulativeSteps(type: HKQuantityType, start: Date, end: Date) async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: start,
                end: end,
                options: [.strictStartDate, .strictEndDate]
            )
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let value = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }
}

struct HealthKitStepsCard: View {
    let date: Date
    let theme: AppTheme
    let onOpenSettings: () -> Void

    @StateObject private var store = HealthKitStepsStore()
    @AppStorage(HealthKitStepsPreference.enabledKey) private var isEnabled = false
    @AppStorage(HealthKitStepsPreference.goalKey) private var goal = HealthKitStepsPreference.defaultGoal
    @Environment(\.scenePhase) private var scenePhase

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(max(Double(store.steps) / Double(goal), 0), 1)
    }

    var body: some View {
        Button(action: onOpenSettings) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "shoeprints.fill")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(theme.accent)
                        .frame(width: 44, height: 44)
                        .background(theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(AppLocalizer.string("health.steps.title"))
                            .font(.headline)
                            .foregroundStyle(theme.primaryText)
                        Text(statusText)
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                    }

                    Spacer()

                    if store.isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.tertiaryText)
                    }
                }

                if isEnabled && store.isAvailable {
                    ProgressView(value: progress)
                        .tint(theme.accent)
                        .accessibilityLabel(AppLocalizer.string("health.steps.progress"))
                        .accessibilityValue("\(store.steps) / \(goal)")
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(theme.border, lineWidth: 1)
            }
            .shadow(color: theme.cardShadow, radius: theme.cardShadowRadius, y: theme.cardShadowY)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .task(id: refreshKey) {
            guard isEnabled else { return }
            await store.loadSteps(for: date)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, isEnabled else { return }
            Task { await store.loadSteps(for: date) }
        }
    }

    private var refreshKey: String {
        "\(Calendar.current.startOfDay(for: date).timeIntervalSince1970)-\(isEnabled)"
    }

    private var statusText: String {
        if store.isAvailable == false {
            return AppLocalizer.string("health.steps.unavailable")
        }
        if isEnabled == false {
            return AppLocalizer.string("health.steps.connect_hint")
        }
        if let errorMessage = store.errorMessage, errorMessage.isEmpty == false {
            return AppLocalizer.string("health.steps.retry_hint")
        }
        return AppLocalizer.format("health.steps.value", store.steps, goal)
    }
}

struct HealthKitStepsSettingsScreen: View {
    @StateObject private var store = HealthKitStepsStore()
    @AppStorage(HealthKitStepsPreference.enabledKey) private var isEnabled = false
    @AppStorage(HealthKitStepsPreference.goalKey) private var goal = HealthKitStepsPreference.defaultGoal

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "heart.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(Color.red.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Apple Health")
                            .font(.headline)
                        Text(connectionStatus)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if isEnabled == false {
                    Button {
                        Task {
                            if await store.requestAccess() {
                                isEnabled = true
                                await store.loadSteps(for: .now)
                            }
                        }
                    } label: {
                        HStack {
                            Text(AppLocalizer.string("health.steps.connect"))
                            Spacer()
                            if store.isLoading { ProgressView() }
                        }
                    }
                    .disabled(store.isLoading || store.isAvailable == false)
                }
            } footer: {
                Text(AppLocalizer.string("health.steps.privacy"))
            }

            Section(AppLocalizer.string("health.steps.goal")) {
                Stepper(value: $goal, in: 1_000...50_000, step: 500) {
                    HStack {
                        Text(AppLocalizer.string("health.steps.daily_goal"))
                        Spacer()
                        Text(goal.formatted())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .disabled(isEnabled == false)

            if isEnabled {
                Section {
                    HStack {
                        Text(AppLocalizer.string("health.steps.today"))
                        Spacer()
                        if store.isLoading {
                            ProgressView()
                        } else {
                            Text(store.steps.formatted())
                                .font(.headline)
                        }
                    }

                    Button(AppLocalizer.string("health.steps.refresh")) {
                        Task { await store.loadSteps(for: .now) }
                    }

                    Button(AppLocalizer.string("health.steps.disable"), role: .destructive) {
                        isEnabled = false
                    }
                }
            }

            if let errorMessage = store.errorMessage, errorMessage.isEmpty == false {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle(AppLocalizer.string("health.steps.settings_title"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if isEnabled { await store.loadSteps(for: .now) }
        }
    }

    private var connectionStatus: String {
        if store.isAvailable == false { return AppLocalizer.string("health.steps.unavailable") }
        return AppLocalizer.string(isEnabled ? "health.steps.enabled" : "health.steps.disabled")
    }
}
