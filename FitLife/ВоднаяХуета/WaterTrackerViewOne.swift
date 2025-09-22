

import Foundation
import SwiftUI
import SwiftData

struct WaterTrackerViewOne: View {
    // SwiftData
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [UserData]

    // активный пол, как и на главном экране
    @AppStorage(Gender.appStorageKey) private var activeGenderRaw: String = Gender.male.rawValue
    private var selectedGender: Gender { Gender(rawValue: activeGenderRaw) ?? .male }

    // UI state
    @State private var showNotificationSettings = false
    @State private var stepML: Double = 250
    private var stepLiters: Double { stepML / 1000.0 }
    private let portionOptions: [Double] = [200, 250, 300, 400, 500]

    @State private var selectedTemperature: WaterTemperature = .warm
    @State private var waterIntake: Double = 0.0

    // текущий пользователь по активному полу
    private var userData: UserData? {
        users.first(where: { $0.gender == selectedGender })
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Трекер воды")
                .font(.headline)
                .padding(.top, 20)

            // Температура
            Picker("Температура воды", selection: $selectedTemperature) {
                ForEach(WaterTemperature.allCases, id: \.self) { temp in
                    Text(temp.rawValue).tag(temp)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .onChange(of: selectedTemperature) { _ in
                // цель пересчитается реактивно через dailyGoal
            }

            // Прогресс
            VStack(spacing: 8) {
                Text("\(Int(waterPercentage))%")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundColor(.blue)

                Text("\(waterIntake, specifier: "%.2f") л из \(dailyGoal, specifier: "%.2f") л")
                    .font(.title3)
                    .foregroundColor(.gray)
            }

            // Кнопки
            HStack {
                // Левая колонка
                VStack(spacing: 8) {
                    Button(action: { addWater(amount: stepLiters) }) {
                        VStack(spacing: 2) {
                            Image(systemName: "plus")
                            Text("Добавить воду")
                        }
                        .font(.title3)
                    }
                    .foregroundStyle(.black)

                    Menu {
                        ForEach(portionOptions, id: \.self) { ml in
                            Button {
                                stepML = ml
                            } label: {
                                HStack {
                                    Text("\(Int(ml)) мл")
                                    if stepML == ml { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("\(Int(stepML)) мл")
                            Image(systemName: "chevron.down")
                        }
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color(.systemGray6)))
                    }
                }

                Spacer()

                // Правая колонка
                Button(action: { showNotificationSettings = true }) {
                    VStack {
                        Image(systemName: "bell")
                        Text("Напомнить")
                    }
                    .font(.title3)
                }
                .foregroundStyle(.black)
                .sheet(isPresented: $showNotificationSettings) {
                    NotificationSettingsView()
                }
            }
            .padding(.horizontal)

            Spacer(minLength: 8)
        }
        .padding(.bottom, 16)
        .onAppear {
            ensureUserIfNeeded()
            loadWaterIntake()
        }
        // если поменяли активный пол — подгрузим запись для другого пользователя
        .onChange(of: activeGenderRaw) { _ in
            ensureUserIfNeeded()
            loadWaterIntake()
        }
        // если изменился вес пользователя — прогресс сам обновится, но перезагрузим цель/данные
        .onChange(of: users) { _ in
            loadWaterIntake()
        }
    }

    // MARK: - Расчёты
    private var dailyGoal: Double {
        guard let user = userData else { return 0 }
        let multiplier: Double
        switch selectedTemperature {
        case .cold: multiplier = 30.0
        case .warm: multiplier = 35.0
        case .hot:  multiplier = 40.0
        }
        return (user.weight * multiplier) / 1000.0
    }

    private var waterPercentage: Double {
        guard dailyGoal > 0 else { return 0 }
        return min((waterIntake / dailyGoal) * 100, 100)
    }

    // MARK: - Действия
    private func addWater(amount: Double) {
        waterIntake += amount
        saveWaterIntake()
    }

    // MARK: - SwiftData
    private func ensureUserIfNeeded() {
        if userData == nil {
            let newUser = UserData(
                weight: 0, height: 0, age: 0,
                activityLevel: .none,
                goal: .currentWeight,
                gender: selectedGender
            )
            modelContext.insert(newUser)
            try? modelContext.save()
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
                entry.user = user
                modelContext.insert(entry)
            }
            try modelContext.save()
        } catch {
            #if DEBUG
            print("saveWaterIntake error:", error)
            #endif
        }
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
            } else {
                waterIntake = 0
            }
        } catch {
            waterIntake = 0
            #if DEBUG
            print("loadWaterIntake error:", error)
            #endif
        }
    }
}
