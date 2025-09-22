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
                            ValueRowInt(title: "Возраст", value: $u.age,    range: 1...100,  unit: "лет")
                            ValueRowDoubleAsInt(title: "Вес",   value: $u.weight, range: 30...200, unit: "кг")
                            ValueRowDoubleAsInt(title: "Рост",  value: $u.height, range: 100...230, unit: "см")
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

    // Строка с числом (Int) — по тапу открывает шит с колесом
    private struct ValueRowInt: View {
        let title: String
        @Binding var value: Int
        let range: ClosedRange<Int>
        let unit: String
        var step: Int = 1

        @State private var showSheet = false

        var body: some View {
            Button {
                showSheet = true
            } label: {
                HStack {
                    Text(title)
                    Spacer()
                    Text("\(value) \(unit)")
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showSheet) {
                NumberWheelPickerInt(
                    title: title,
                    value: $value,
                    range: range,
                    unit: unit,
                    step: step
                )
            }
        }
    }

    // Строка для Double, но колесо даёт целые (типичный кейс для кг/см)
    // Внутри делает безопасное преобразование Int <-> Double
    private struct ValueRowDoubleAsInt: View {
        let title: String
        @Binding var value: Double
        let range: ClosedRange<Int>
        let unit: String
        var step: Int = 1

        @State private var showSheet = false
        @State private var temp: Int = 0

        var body: some View {
            Button {
                temp = min(max(Int(value.rounded()), range.lowerBound), range.upperBound)
                showSheet = true
            } label: {
                HStack {
                    Text(title)
                    Spacer()
                    Text("\(Int(value.rounded())) \(unit)")
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showSheet) {
                NumberWheelPickerInt(
                    title: title,
                    value: $temp,
                    range: range,
                    unit: unit,
                    step: step,
                    onDone: {
                        value = Double(temp)
                    }
                )
            }
        }
    }

    // Сам шит с колесом выбора (Int)
    private struct NumberWheelPickerInt: View {
        let title: String
        @Binding var value: Int
        let range: ClosedRange<Int>
        let unit: String
        var step: Int = 1
        var onDone: (() -> Void)? = nil

        @Environment(\.dismiss) private var dismiss

        private var values: [Int] {
            Array(stride(from: range.lowerBound, through: range.upperBound, by: step))
        }

        var body: some View {
            NavigationStack {
                VStack(spacing: 0) {
                    Picker("", selection: $value) {
                        ForEach(values, id: \.self) { v in
                            Text("\(v) \(unit)").tag(v)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    // Подпись текущего значения
                    Text("\(value) \(unit)")
                        .font(.title3.weight(.semibold))
                        .padding(.vertical, 12)
                        .foregroundStyle(.secondary)
                }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Готово") {
                            onDone?()
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            dismiss()
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
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


