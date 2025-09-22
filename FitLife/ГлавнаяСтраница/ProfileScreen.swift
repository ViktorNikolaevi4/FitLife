import SwiftUI
import SwiftData

struct ProfileScreen: View {
    @Query private var users: [UserData]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var scheme

    @AppStorage(Gender.appStorageKey) private var activeGenderRaw: String = Gender.male.rawValue
    @State private var editingGender: Gender

    init() {
        let raw = UserDefaults.standard.string(forKey: Gender.appStorageKey) ?? Gender.male.rawValue
        _editingGender = State(initialValue: Gender(rawValue: raw) ?? .male)
    }

    private var user: UserData? { users.first(where: { $0.gender == editingGender }) }

    var body: some View {
        let bg = Color(.systemGray6)

        NavigationStack {                // ⬅️ добавили стек
            ScrollView {
                VStack(spacing: 16) {
                    // Пол
                    SectionCard(title: "Пол") {
                        Picker("", selection: $editingGender) {
                            ForEach(Gender.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    if let user {
                        @Bindable var u = user

                        // Параметры
                        SectionCard(title: "Параметры") {
                            LabeledStepperI(title: "Возраст", value: $u.age,    range: 1...100,   step: 1,   suffix: "лет")
                            LabeledStepperD(title: "Вес",     value: $u.weight, range: 30...200,  step: 1.0, suffix: "кг")
                            LabeledStepperD(title: "Рост",    value: $u.height, range: 100...230, step: 1.0, suffix: "см")
                        }
                        .onChange(of: u.age)    { _,_ in recalc(u) }
                        .onChange(of: u.weight) { _,_ in recalc(u) }
                        .onChange(of: u.height) { _,_ in recalc(u) }

                        // Активность
                        SectionCard(title: "Физическая активность") {
                            Picker("", selection: $u.activityLevel) {
                                ForEach(ActivityLevel.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.segmented)
                        }
                        .onChange(of: u.activityLevel) { _,_ in recalc(u) }

                        // Цель
                        SectionCard(title: "Цель") {
                            Picker("", selection: $u.goal) {
                                ForEach(WeightGoal.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.segmented)
                        }
                        .onChange(of: u.goal) { _,_ in recalc(u) }

                        // ИМТ
                        BMISection(userData: u)
                    } else {
                        ContentUnavailableView(
                            "Профиль не найден",
                            systemImage: "person.crop.circle.badge.questionmark",
                            description: Text("Создам профиль автоматически.")
                        )
                        .task { ensureUserIfNeeded(for: editingGender) }
                    }
                }
                .padding(.vertical, 16)
              //  .background(Color(.systemGray6))
            }
            .background(bg)
            .navigationTitle("Профиль")                   // теперь видно
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(bg, for: .navigationBar)
           // .toolbarBorderHidden(true, for: .navigationBar)
// или .large если нужен большой заголовок
            //.toolbarBackground(.visible, for: .navigationBar) // можно раскомментировать, если фон скрывается
        }
        .onChange(of: editingGender) { _, new in
            activeGenderRaw = new.rawValue
            ensureUserIfNeeded(for: new)
            if let u = users.first(where: { $0.gender == new }) {
                u.gender = new
                try? modelContext.save()
                recalc(u)
            }
        }
        .onAppear {
            activeGenderRaw = editingGender.rawValue
            ensureUserIfNeeded(for: editingGender)
        }
    }

    private func ensureUserIfNeeded(for gender: Gender) {
        if users.first(where: { $0.gender == gender }) == nil {
            let u = UserData(weight: 70, height: 170, age: 25,
                             activityLevel: .none, goal: .currentWeight, gender: gender)
            modelContext.insert(u)
            try? modelContext.save()
            recalc(u)
        }
    }

    private func recalc(_ u: UserData) {
        let cals = MacrosCalculator.calculateCaloriesMifflin(
            gender: u.gender, weight: u.weight, height: u.height, age: u.age,
            activityLevel: u.activityLevel, goal: u.goal
        )
        let macros = MacrosCalculator.calculateMacros(calories: cals, goal: u.goal)
        u.calories = cals
        u.macros   = macros
        try? modelContext.save()
    }
}


// — Вспомогательные мини-контролы без дженериков —

private struct LabeledStepperI: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    var suffix: String = ""

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Stepper(value: $value, in: range, step: step) {
                Text("\(value) \(suffix)")
                    .foregroundStyle(.secondary)
            }
          //  .labelsHidden()
        }
    }
}

private struct LabeledStepperD: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var suffix: String = ""

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Stepper(value: $value, in: range, step: step) {
                Text("\(Int(value)) \(suffix)")
                    .foregroundStyle(.secondary)
            }
         //   .labelsHidden()
        }
    }
}

private struct SectionCard<Content: View>: View {
    let title: String?
    @ViewBuilder var content: Content
    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title; self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title { Text(title).font(.headline) }
            content
        }
        .padding(14)
        // если хочешь ВСЕГДА белый (даже в тёмной теме) — поставь .white
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))   // динамичный белый/чёрный
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black.opacity(0.06))
        )
        .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 2)
        .padding(.horizontal)
    }
}


