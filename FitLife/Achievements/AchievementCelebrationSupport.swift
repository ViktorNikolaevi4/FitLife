import SwiftUI
import SwiftData
import UIKit

struct AchievementCelebration: Identifiable {
    let id: UUID
    let achievementIDs: [AchievementID]
    let awardedXP: Int
    let reachedLevel: Int?
    let totalXP: Int

    var isMilestone: Bool {
        if reachedLevel != nil { return true }
        return achievementIDs.contains { id in
            guard let definition = AchievementCatalog.definition(for: id) else { return false }
            return definition.xpReward >= 750 || definition.visibility == .hiddenUntilUnlocked
        }
    }
}

@MainActor
final class AchievementCelebrationStore: ObservableObject {
    @Published private(set) var activeCelebration: AchievementCelebration?
    @Published private(set) var unreadCount = 0

    private var dismissalTask: Task<Void, Never>?

    func present(_ result: AchievementReconciliationResult) {
        guard result.shouldCelebrate else { return }

        let reachedLevel = result.currentLevel > result.previousLevel ? result.currentLevel : nil
        let existing = activeCelebration
        let combinedIDs = (existing?.achievementIDs ?? []).reduce(into: result.unlockedIDs) { ids, id in
            if ids.contains(id) == false { ids.append(id) }
        }
        let celebration = AchievementCelebration(
            id: UUID(),
            achievementIDs: combinedIDs,
            awardedXP: (existing?.awardedXP ?? 0) + result.awardedXP,
            reachedLevel: max(existing?.reachedLevel ?? 0, reachedLevel ?? 0).nonZero,
            totalXP: max(existing?.totalXP ?? 0, result.totalXP)
        )

        dismissalTask?.cancel()
        activeCelebration = celebration
        dismissalTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(celebration.isMilestone ? 7 : 5))
            guard Task.isCancelled == false else { return }
            self?.dismiss(id: celebration.id)
        }
    }

    func dismiss() {
        dismissalTask?.cancel()
        activeCelebration = nil
    }

    func updateUnreadCount(_ count: Int) {
        unreadCount = max(count, 0)
    }

    private func dismiss(id: UUID) {
        guard activeCelebration?.id == id else { return }
        activeCelebration = nil
    }
}

private extension Int {
    var nonZero: Int? { self > 0 ? self : nil }
}

struct AchievementCelebrationBanner: View {
    let celebration: AchievementCelebration
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var firstDefinition: AchievementDefinition? {
        celebration.achievementIDs.first.flatMap(AchievementCatalog.definition(for:))
    }

    private var title: String {
        if let level = celebration.reachedLevel {
            return AppLocalizer.format("profile.achievements.celebration.level", level)
        }
        if celebration.achievementIDs.count > 1 {
            return AppLocalizer.format(
                "profile.achievements.celebration.multiple",
                celebration.achievementIDs.count
            )
        }
        return firstDefinition.map { AppLocalizer.string($0.titleKey) }
            ?? AppLocalizer.string("profile.achievements.celebration.single")
    }

    private var subtitle: String {
        if celebration.reachedLevel != nil, celebration.achievementIDs.isEmpty == false {
            return AppLocalizer.format(
                "profile.achievements.celebration.with_achievements",
                celebration.achievementIDs.count,
                celebration.awardedXP
            )
        }
        return AppLocalizer.format("profile.achievements.celebration.xp", celebration.awardedXP)
    }

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.24 : 0.14))
                Image(systemName: celebration.reachedLevel == nil ? (firstDefinition?.icon ?? "trophy.fill") : "star.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(celebration.reachedLevel == nil
                     ? AppLocalizer.string("profile.achievements.celebration.single")
                     : AppLocalizer.string("profile.achievements.celebration.level_eyebrow"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)

                Text(title)
                    .font(.headline)
                    .lineLimit(2)

                Text(subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 6)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.secondary.opacity(0.12)))
            }
            .accessibilityLabel(AppLocalizer.string("common.close"))
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.accentColor.opacity(0.24), lineWidth: 1)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.30 : 0.14), radius: 18, y: 8)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture(perform: onDismiss)
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        .accessibilityElement(children: .combine)
    }
}

struct AchievementMilestoneCelebrationView: View {
    let celebration: AchievementCelebration
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var backdropOpacity = 0.0
    @State private var badgeScale = 0.55
    @State private var badgeRotation = -10.0
    @State private var ringProgress = 0.0
    @State private var particleProgress = 0.0
    @State private var contentOpacity = 0.0
    @State private var contentOffset = 18.0
    @State private var xpProgress = 0.0

    private var definition: AchievementDefinition? {
        celebration.achievementIDs.first.flatMap(AchievementCatalog.definition(for:))
    }

    private var title: String {
        if let level = celebration.reachedLevel {
            return AppLocalizer.format("profile.achievements.celebration.level", level)
        }
        if celebration.achievementIDs.count > 1 {
            return AppLocalizer.format("profile.achievements.celebration.multiple", celebration.achievementIDs.count)
        }
        return definition.map { AppLocalizer.string($0.titleKey) }
            ?? AppLocalizer.string("profile.achievements.celebration.single")
    }

    private var levelProgress: AchievementLevelProgress {
        AchievementLevelCalculator.progress(totalXP: celebration.totalXP)
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(0.62 * backdropOpacity)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    if reduceMotion == false {
                        Circle()
                            .stroke(Color.accentColor.opacity(0.34), lineWidth: 2)
                            .frame(width: 146, height: 146)
                            .scaleEffect(0.72 + ringProgress * 0.72)
                            .opacity(1 - ringProgress)

                        Circle()
                            .stroke(Color.cyan.opacity(0.24), lineWidth: 1.5)
                            .frame(width: 146, height: 146)
                            .scaleEffect(0.88 + ringProgress * 0.95)
                            .opacity((1 - ringProgress) * 0.8)

                        ForEach(0..<12, id: \.self) { index in
                            celebrationParticle(index: index)
                        }
                    }

                    CelebrationHexagon()
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.34), Color.accentColor.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    CelebrationHexagon()
                        .stroke(Color.accentColor, lineWidth: 5)
                    CelebrationHexagon()
                        .stroke(Color.white.opacity(0.55), lineWidth: 1)
                        .padding(8)

                    if let level = celebration.reachedLevel {
                        Text("\(level)")
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText())
                    } else {
                        Image(systemName: definition?.icon ?? "trophy.fill")
                            .font(.system(size: 52, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .frame(width: 174, height: 190)
                .scaleEffect(badgeScale)
                .rotationEffect(.degrees(badgeRotation))
                .shadow(color: Color.accentColor.opacity(0.48), radius: 28)

                VStack(spacing: 9) {
                    Text(celebration.reachedLevel == nil
                         ? AppLocalizer.string("profile.achievements.celebration.rare_eyebrow")
                         : AppLocalizer.string("profile.achievements.celebration.level_eyebrow"))
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.accentColor)

                    Text(title)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)

                    Text(AppLocalizer.format("profile.achievements.celebration.xp", celebration.awardedXP))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.accentColor.opacity(0.13)))
                }
                .opacity(contentOpacity)
                .offset(y: contentOffset)

                VStack(spacing: 7) {
                    HStack {
                        Text(AppLocalizer.format("profile.achievements.level", levelProgress.level))
                        Spacer()
                        Text("\(levelProgress.xpInsideLevel) / \(levelProgress.requiredXP) XP")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.16))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.accentColor, Color.cyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: proxy.size.width * xpProgress)
                        }
                    }
                    .frame(height: 8)
                }
                .opacity(contentOpacity)

                Button(action: onDismiss) {
                    Text(AppLocalizer.string("profile.achievements.celebration.continue"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(Capsule().fill(Color.accentColor))
                }
                .buttonStyle(.plain)
                .opacity(contentOpacity)
            }
            .padding(28)
            .frame(maxWidth: 430)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.28), lineWidth: 1)
            }
            .padding(.horizontal, 20)
        }
        .task(id: celebration.id) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if reduceMotion {
                backdropOpacity = 1
                badgeScale = 1
                badgeRotation = 0
                contentOpacity = 1
                contentOffset = 0
                xpProgress = levelProgress.fraction
                return
            }

            withAnimation(.easeOut(duration: 0.20)) {
                backdropOpacity = 1
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) {
                badgeScale = 1
                badgeRotation = 0
            }
            withAnimation(.easeOut(duration: 0.85)) {
                ringProgress = 1
                particleProgress = 1
            }
            try? await Task.sleep(for: .milliseconds(180))
            guard Task.isCancelled == false else { return }
            withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) {
                contentOpacity = 1
                contentOffset = 0
            }
            withAnimation(.easeInOut(duration: 0.85).delay(0.10)) {
                xpProgress = levelProgress.fraction
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func celebrationParticle(index: Int) -> some View {
        let angle = (Double(index) / 12.0) * Double.pi * 2 - Double.pi / 2
        let distance = 88.0 + Double(index % 3) * 13.0
        let size = CGFloat(4 + index % 3 * 2)
        return Circle()
            .fill(index.isMultiple(of: 3) ? Color.cyan : Color.accentColor)
            .frame(width: size, height: size)
            .offset(
                x: CGFloat(cos(angle) * distance * particleProgress),
                y: CGFloat(sin(angle) * distance * particleProgress)
            )
            .scaleEffect(0.5 + particleProgress * 0.7)
            .opacity(1 - particleProgress)
    }
}

private struct CelebrationHexagon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        for index in 0..<6 {
            let angle = CGFloat(index) * .pi / 3 - .pi / 2
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

struct AchievementReconciliationMonitor: View {
    @Query private var users: [UserData]
    @Query private var workouts: [WorkoutSession]
    @Query private var foodEntries: [FoodEntry]
    @Query private var waterEntries: [WaterIntake]
    @Query private var measurements: [BodyMeasurements]
    @Query private var progressRecords: [UserAchievementProgress]
    @Query private var unlockedAchievements: [UnlockedAchievement]

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var sessionStore: AppSessionStore
    @EnvironmentObject private var celebrationStore: AchievementCelebrationStore
    @AppStorage(Gender.appStorageKey) private var activeGenderRaw = Gender.male.rawValue
    @AppStorage(HealthKitStepsPreference.enabledKey) private var stepsEnabled = false
    @AppStorage(HealthKitStepsPreference.goalKey) private var stepGoal = HealthKitStepsPreference.defaultGoal
    @StateObject private var externalDataStore = AchievementExternalDataStore()

    private var ownerID: String? { sessionStore.firebaseUser?.uid }
    private var gender: Gender { Gender(rawValue: activeGenderRaw) ?? .male }
    private var userData: UserData? {
        guard let ownerID else { return nil }
        return users.first { $0.ownerId == ownerID && $0.gender == gender }
    }
    private var scopeID: String? {
        guard let ownerID else { return nil }
        return AchievementEngine.scopeID(ownerId: ownerID, gender: gender)
    }
    private var resetAt: Date? {
        progressRecords.first { $0.scopeID == scopeID }?.achievementResetAt
    }

    private var reconciliationSignature: String {
        guard let ownerID else { return "signed-out" }
        let workoutRevision = workouts.filter { $0.ownerId == ownerID && $0.gender == gender }.map {
            "\($0.id):\($0.endedAt?.timeIntervalSinceReferenceDate ?? 0):\($0.exerciseItems.count)"
        }.joined(separator: "|").hashValue
        let foodRevision = foodEntries.filter { $0.ownerId == ownerID && $0.gender == gender }.map {
            "\($0.date.timeIntervalSinceReferenceDate):\($0.product?.calories ?? 0)"
        }.joined(separator: "|").hashValue
        let waterRevision = waterEntries.filter {
            $0.gender == gender && ($0.ownerId == ownerID || $0.user?.id == userData?.id)
        }.map { "\($0.date.timeIntervalSinceReferenceDate):\($0.intake.safeFinite)" }
            .joined(separator: "|").hashValue
        let measurementRevision = measurements.filter { $0.ownerId == ownerID }.map {
            String($0.date.timeIntervalSinceReferenceDate)
        }.joined(separator: "|").hashValue
        let external = externalDataStore.snapshot
        return "\(ownerID):\(gender.rawValue):\(workoutRevision):\(foodRevision):\(waterRevision):\(measurementRevision):\(userData?.weight ?? 0):\(userData?.calories ?? 0):\(external.healthConnected):\(external.stepGoalDays ?? -1):\(external.totalSteps ?? -1):\(external.checkInCount ?? -1):\(external.coachDays ?? -1):\(resetAt?.timeIntervalSinceReferenceDate ?? 0)"
    }

    private var externalLoadSignature: String {
        "\(ownerID ?? ""):\(stepsEnabled):\(stepGoal):\(resetAt?.timeIntervalSinceReferenceDate ?? 0)"
    }

    private var unseenSignature: String {
        unlockedAchievements
            .filter { $0.scopeID == scopeID && $0.isUnseen }
            .map(\.compositeID)
            .sorted()
            .joined(separator: "|")
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .task(id: reconciliationSignature) {
                guard let ownerID, let userData else { return }
                do {
                    let result = try AchievementEngine.reconcile(
                        ownerId: ownerID,
                        gender: gender,
                        userData: userData,
                        workouts: workouts,
                        foodEntries: foodEntries,
                        waterEntries: waterEntries,
                        measurements: measurements,
                        externalSnapshot: externalDataStore.snapshot,
                        modelContext: modelContext
                    )
                    celebrationStore.present(result)
                    refreshUnreadCount()
                } catch {
                    assertionFailure("Achievement reconciliation failed: \(error)")
                }
            }
            .task(id: externalLoadSignature) {
                guard let ownerID else { return }
                await externalDataStore.load(
                    clientId: ownerID,
                    stepsEnabled: stepsEnabled,
                    stepGoal: stepGoal,
                    progressStartedAt: resetAt
                )
            }
            .onAppear(perform: refreshUnreadCount)
            .onChange(of: unseenSignature) { _, _ in refreshUnreadCount() }
    }

    private func refreshUnreadCount() {
        celebrationStore.updateUnreadCount(
            unlockedAchievements.filter { $0.scopeID == scopeID && $0.isUnseen }.count
        )
    }
}
