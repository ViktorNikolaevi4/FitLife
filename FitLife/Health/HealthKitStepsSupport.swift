import SwiftUI
import HealthKit
import OSLog
import UIKit

enum HealthKitStepsPreference {
    static let enabledKey = "healthkit.steps.enabled"
    static let goalKey = "healthkit.steps.goal"
    static let defaultGoal = 10_000
}

struct HealthKitDailySteps: Identifiable, Equatable {
    let date: Date
    let steps: Int

    var id: Date { date }
}

@MainActor
final class HealthKitStepsStore: ObservableObject {
    @Published private(set) var steps = 0
    @Published private(set) var weeklySteps: [HealthKitDailySteps] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isAvailable = HKHealthStore.isHealthDataAvailable()
    @Published private(set) var hasLoadedSteps = false
    @Published private(set) var authorizationNeedsRequest = false
    @Published private(set) var shouldOpenSettingsForPermission = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var warningMessage: String?

    private let healthStore = HKHealthStore()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "FitLife",
        category: "HealthKitSteps"
    )
    private var loadedDay: Date?

    func requestAccess() async -> Bool {
        guard isAvailable, let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            errorMessage = AppLocalizer.string("health.steps.unavailable")
            return false
        }

        isLoading = true
        errorMessage = nil
        warningMessage = nil
        shouldOpenSettingsForPermission = false
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [stepType])
            authorizationNeedsRequest = false
            isLoading = false
            return true
        } catch {
            logger.error("HealthKit authorization request failed: \(error.localizedDescription, privacy: .public)")
            shouldOpenSettingsForPermission = isPermissionError(error)
            errorMessage = healthKitErrorMessage(for: error)
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
        warningMessage = nil
        shouldOpenSettingsForPermission = false

        do {
            authorizationNeedsRequest = try await needsAuthorizationRequest(for: stepType)
        } catch {
            logger.warning("Could not determine HealthKit authorization request status: \(error.localizedDescription, privacy: .public)")
            authorizationNeedsRequest = false
        }

        guard authorizationNeedsRequest == false else {
            if loadedDay.map({ calendar.isDate($0, inSameDayAs: date) }) != true {
                steps = 0
                hasLoadedSteps = false
            }
            errorMessage = AppLocalizer.string("health.steps.error.authorization_required")
            isLoading = false
            return
        }

        do {
            let value = try await cumulativeSteps(type: stepType, start: start, end: end)
            steps = max(0, Int(value.rounded()))
            loadedDay = start
            hasLoadedSteps = true
        } catch {
            logger.error("Daily HealthKit steps query failed: \(error.localizedDescription, privacy: .public)")
            if loadedDay.map({ calendar.isDate($0, inSameDayAs: date) }) != true {
                steps = 0
                hasLoadedSteps = false
            }
            shouldOpenSettingsForPermission = isPermissionError(error)
            errorMessage = healthKitErrorMessage(for: error)
            isLoading = false
            return
        }

        do {
            weeklySteps = try await cumulativeStepsByDay(type: stepType, containing: date)
        } catch {
            logger.warning("Weekly HealthKit steps query failed: \(error.localizedDescription, privacy: .public)")
            weeklySteps = []
            warningMessage = AppLocalizer.string("health.steps.warning.week_unavailable")
        }
        isLoading = false
    }

    func hasLoadedSteps(for date: Date) -> Bool {
        guard let loadedDay else { return false }
        return hasLoadedSteps && Calendar.current.isDate(loadedDay, inSameDayAs: date)
    }

    private func needsAuthorizationRequest(for stepType: HKQuantityType) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            healthStore.getRequestStatusForAuthorization(toShare: [], read: [stepType]) { status, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status == .shouldRequest)
                }
            }
        }
    }

    private func healthKitErrorMessage(for error: Error) -> String {
        let nsError = error as NSError
        guard nsError.domain == HKErrorDomain,
              let code = HKError.Code(rawValue: nsError.code) else {
            return AppLocalizer.string("health.steps.error.generic")
        }

        switch code {
        case .errorAuthorizationDenied, .errorAuthorizationNotDetermined, .errorRequiredAuthorizationDenied:
            return AppLocalizer.string("health.steps.error.permission")
        case .errorDatabaseInaccessible:
            return AppLocalizer.string("health.steps.error.device_locked")
        case .errorHealthDataRestricted:
            return AppLocalizer.string("health.steps.error.restricted")
        case .errorHealthDataUnavailable:
            return AppLocalizer.string("health.steps.unavailable")
        case .errorUserCanceled:
            return AppLocalizer.string("health.steps.error.authorization_required")
        default:
            return AppLocalizer.string("health.steps.error.generic")
        }
    }

    private func isPermissionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == HKErrorDomain,
              let code = HKError.Code(rawValue: nsError.code) else { return false }
        return code == .errorAuthorizationDenied || code == .errorRequiredAuthorizationDenied
    }

    nonisolated private static func isNoDataError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == HKErrorDomain && nsError.code == HKError.Code.errorNoData.rawValue
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
                    if Self.isNoDataError(error) {
                        continuation.resume(returning: 0)
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }
                let value = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    private func cumulativeStepsByDay(
        type: HKQuantityType,
        containing date: Date
    ) async throws -> [HealthKitDailySteps] {
        let calendar = Calendar.current
        let selectedDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: selectedDay)
        let distanceFromMonday = (weekday + 5) % 7
        guard
            let weekStart = calendar.date(byAdding: .day, value: -distanceFromMonday, to: selectedDay),
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)
        else { return [] }

        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: weekStart,
                end: weekEnd,
                options: [.strictStartDate, .strictEndDate]
            )
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: weekStart,
                intervalComponents: DateComponents(day: 1)
            )

            query.initialResultsHandler = { _, collection, error in
                if let error {
                    if Self.isNoDataError(error) {
                        continuation.resume(returning: [])
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }

                var valuesByDay: [Date: Int] = [:]
                collection?.enumerateStatistics(
                    from: weekStart,
                    to: weekEnd.addingTimeInterval(-1)
                ) { statistics, _ in
                    let day = calendar.startOfDay(for: statistics.startDate)
                    let value = statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    valuesByDay[day] = max(0, Int(value.rounded()))
                }

                let values = (0..<7).compactMap { offset -> HealthKitDailySteps? in
                    guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else {
                        return nil
                    }
                    return HealthKitDailySteps(date: day, steps: valuesByDay[day] ?? 0)
                }
                continuation.resume(returning: values)
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
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Button(action: onOpenSettings) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "shoeprints.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(theme.accent)

                    Text(AppLocalizer.string("health.steps.title"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)

                    Spacer(minLength: 0)

                    if store.isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.tertiaryText)
                    }
                }

                if canShowSteps {
                    Text(AppLocalizer.format("health.steps.count", store.steps))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.primaryText)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    if store.weeklySteps.isEmpty == false {
                        WeeklyStepsMiniChart(
                            values: store.weeklySteps,
                            selectedDate: date,
                            theme: theme
                        )
                    } else if store.warningMessage != nil {
                        Text(AppLocalizer.string("health.steps.warning.week_unavailable"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                } else {
                    Text(statusText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(3)

                    Spacer(minLength: 0)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 172, alignment: .leading)
            .adaptiveHomeCard(theme: theme, cornerRadius: HomeDarkMetrics.cardCornerRadius)
        }
        .buttonStyle(.plain)
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
        if let errorMessage = store.errorMessage,
           errorMessage.isEmpty == false,
           store.hasLoadedSteps(for: date) == false {
            return AppLocalizer.string("health.steps.retry_hint")
        }
        return AppLocalizer.format("health.steps.count", store.steps)
    }

    private var canShowSteps: Bool {
        isEnabled && store.isAvailable && store.hasLoadedSteps(for: date)
    }
}

private struct WeeklyStepsMiniChart: View {
    let values: [HealthKitDailySteps]
    let selectedDate: Date
    let theme: AppTheme

    private var maximum: Double {
        Double(max(values.map(\.steps).max() ?? 0, 1))
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(values) { value in
                VStack(spacing: 4) {
                    GeometryReader { proxy in
                        let fraction = Double(value.steps) / maximum
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(barColor(for: value.date))
                            .frame(height: max(value.steps > 0 ? 4 : 2, proxy.size.height * fraction))
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                    .frame(height: 27)

                    Text(weekdayText(for: value.date))
                        .font(.system(size: 9, weight: isSelected(value.date) ? .semibold : .regular))
                        .foregroundStyle(isSelected(value.date) ? theme.primaryText : theme.tertiaryText)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 42)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppLocalizer.string("health.steps.week_chart"))
    }

    private func isSelected(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: selectedDate)
    }

    private func barColor(for date: Date) -> Color {
        isSelected(date) ? theme.accent : theme.accent.opacity(0.48)
    }

    private func weekdayText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocalizer.currentLanguage.locale
        formatter.setLocalizedDateFormatFromTemplate("EE")
        return formatter.string(from: date).lowercased()
    }
}

struct HealthKitStepsSettingsScreen: View {
    @StateObject private var store = HealthKitStepsStore()
    @AppStorage(HealthKitStepsPreference.enabledKey) private var isEnabled = false
    @AppStorage(HealthKitStepsPreference.goalKey) private var goal = HealthKitStepsPreference.defaultGoal
    @Environment(\.openURL) private var openURL

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
                        } else if store.hasLoadedSteps(for: .now) == false {
                            Text("—")
                                .font(.headline)
                        } else {
                            Text(store.steps.formatted())
                                .font(.headline)
                        }
                    }

                    Button(AppLocalizer.string("health.steps.refresh")) {
                        Task { await store.loadSteps(for: .now) }
                    }

                    if store.authorizationNeedsRequest {
                        Button(AppLocalizer.string("health.steps.grant_access")) {
                            Task {
                                if await store.requestAccess() {
                                    await store.loadSteps(for: .now)
                                }
                            }
                        }
                    } else if store.shouldOpenSettingsForPermission {
                        Button(AppLocalizer.string("health.steps.open_settings")) {
                            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                            openURL(url)
                        }
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

            if let warningMessage = store.warningMessage, warningMessage.isEmpty == false {
                Section {
                    Label(warningMessage, systemImage: "chart.bar.xaxis")
                        .foregroundStyle(.secondary)
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
        if store.authorizationNeedsRequest { return AppLocalizer.string("health.steps.access_required") }
        return AppLocalizer.string(isEnabled ? "health.steps.enabled" : "health.steps.disabled")
    }
}
