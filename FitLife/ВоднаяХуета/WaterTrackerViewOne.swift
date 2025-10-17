import Foundation
import SwiftUI
import SwiftData

struct WaterTrackerViewOne: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [UserData]

    @AppStorage(Gender.appStorageKey) private var activeGenderRaw: String = Gender.male.rawValue
    private var selectedGender: Gender { Gender(rawValue: activeGenderRaw) ?? .male }

    @State private var showNotificationSettings = false
    @State private var stepML: Int = 250
    private var stepLiters: Double { Double(stepML) / 1000.0 }
    private let portionOptions: [Int] = [200, 250, 300, 400, 500]

    @State private var selectedTemperature: WaterTemperature = .warm
    @State private var waterIntake: Double = 0.0

    @Environment(\.colorScheme) private var colorScheme
    private var theme: AppTheme { AppTheme(colorScheme) }

    private var userData: UserData? { users.first(where: { $0.gender == selectedGender }) }

    // прогресс для кольца 0...1
    private var ringProgress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(waterIntake / dailyGoal, 1)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {

                Picker("Температура воды", selection: $selectedTemperature) {
                    ForEach(WaterTemperature.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Spacer()

                // КРУГОВАЯ ДИАГРАММА В ЦЕНТРЕ
                HStack {
                    Spacer()
                    ZStack {
                        Donut(
                            progress: ringProgress,
                            lineWidth: 14,
                            track: theme.ringTrack,
                            gradient: theme.ringGradient
                        )
                        .frame(width: 220, height: 220)
                        .animation(.easeInOut(duration: 0.25), value: ringProgress)

                        VStack(spacing: 6) {
                            Text("\(Int(waterPercentage))%")
                                .font(.system(size: 44, weight: .semibold))
                                .foregroundStyle(.blue)
                            Text("\(waterIntake, specifier: "%.2f") л из \(dailyGoal, specifier: "%.2f") л")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(theme.bg.ignoresSafeArea())
            .onAppear { ensureUserIfNeeded(); loadWaterIntake() }
            .onChange(of: activeGenderRaw) { _ in ensureUserIfNeeded(); loadWaterIntake() }
            .onChange(of: users) { _ in loadWaterIntake() }
            .navigationTitle("Трекер воды")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNotificationSettings = true } label: {
                        HStack(spacing: 6) { Image(systemName: "bell"); Text("Напомнить") }
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(theme.bg, for: .navigationBar)
            .sheet(isPresented: $showNotificationSettings) { NotificationSettingsView() }

            // Карточка снизу
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    WaterAddRow(
                        portionML: $stepML,
                        options: portionOptions,
                        onAdd: { addWater(amount: stepLiters) }
                    )
                    .padding(.horizontal)
                }
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background(theme.bg)
                .overlay(alignment: .top) { Divider().opacity(0.25) } // тонкий разделитель
            }
            .tint(.blue)
        }
    }

    // MARK: - Расчёты
    private var dailyGoal: Double {
        guard let user = userData else { return 0 }
        let m: Double = switch selectedTemperature { case .cold: 30; case .warm: 35; case .hot: 40 }
        return (user.weight * m) / 1000.0
    }
    private var waterPercentage: Double {
        guard dailyGoal > 0 else { return 0 }
        return min((waterIntake / dailyGoal) * 100, 100)
    }

    // MARK: - Данные
    private func addWater(amount: Double) { waterIntake += amount; saveWaterIntake() }

    private func ensureUserIfNeeded() {
        if userData == nil {
            let u = UserData(weight: 0, height: 0, age: 0, activityLevel: .none, goal: .currentWeight, gender: selectedGender)
            modelContext.insert(u); try? modelContext.save()
        }
    }

    private func saveWaterIntake() {
        guard let user = userData else { return }
        let today = Calendar.current.startOfDay(for: Date())
        do {
            let all = try modelContext.fetch(FetchDescriptor<WaterIntake>())
            if let existing = all.first(where: {
                Calendar.current.isDate($0.date, inSameDayAs: today) && $0.user?.id == user.id
            }) {
                existing.intake = waterIntake
            } else {
                let entry = WaterIntake(date: today, intake: waterIntake, gender: user.gender)
                entry.user = user; modelContext.insert(entry)
            }
            try? modelContext.save()
        } catch { print("saveWaterIntake error:", error) }
    }

    private func loadWaterIntake() {
        guard let user = userData else { waterIntake = 0; return }
        let today = Calendar.current.startOfDay(for: Date())
        do {
            let all = try modelContext.fetch(FetchDescriptor<WaterIntake>())
            if let existing = all.first(where: {
                Calendar.current.isDate($0.date, inSameDayAs: today) && $0.user?.id == user.id
            }) {
                waterIntake = existing.intake
            } else { waterIntake = 0 }
        } catch { waterIntake = 0 }
    }
}

// MARK: - Карточка добавления воды
private struct WaterAddRow: View {
    @Binding var portionML: Int
    let options: [Int]
    var onAdd: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.blue)
                Image(systemName: "drop.fill").foregroundStyle(.white)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 0) {
                Text("Добавить воду").font(.headline)
                Text("Порция \(portionML) мл")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            Spacer()

            Menu {
                ForEach(options, id: \.self) { ml in
                    Button {
                        portionML = ml
                    } label: {
                        HStack {
                            Text("\(ml) мл")
                            if portionML == ml { Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text("\(portionML) мл").font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.down").font(.footnote)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                // динамический фон для тёмной/светлой
                .background(Capsule().fill(Color(.tertiarySystemFill)))
                // аккуратная обводка через separator
                .overlay(
                    Capsule().stroke(
                        Color(.separator).opacity(colorScheme == .dark ? 0.45 : 0.20)
                    )
                )
                .foregroundStyle(.primary)
                .contentShape(Capsule())
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground)) // чуть светлее фона
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.separator).opacity(colorScheme == .dark ? 0.55 : 0.20))
        )
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0.00 : 0.06),
            radius: 8, x: 0, y: 3
        )
        .contentShape(Rectangle())
        .onTapGesture { onAdd() }
    }
}
