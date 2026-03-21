import SwiftUI

struct OnboardingPayload {
    var gender: Gender = .male
    var age: Int = 25
    var weight: Double = 70
    var height: Double = 175
    var activity: ActivityLevel = .none
    var goal: WeightGoal = .currentWeight
}

private struct BasicsStep: View {
    @Binding var gender: Gender
    @Binding var age: Int
    @Binding var weight: Double
    @Binding var height: Double

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(AppLocalizer.string("onboarding.basics"))
                    .font(.largeTitle).bold()
                    .padding(.top, 40)

                // Пол
                VStack(alignment: .leading, spacing: 12) {
                    Text(AppLocalizer.string("profile.gender")).font(.headline)
                    Picker("", selection: $gender) {
                        Text(Gender.male.displayName).tag(Gender.male)
                        Text(Gender.female.displayName).tag(Gender.female)
                    }
                    .pickerStyle(.segmented)
                }

                // Возраст
                VStack(alignment: .leading, spacing: 12) {
                    Text(AppLocalizer.string("profile.age")).font(.headline)
                    HStack {
                        Stepper(value: $age, in: 14...90, step: 1) { EmptyView() }
                            .labelsHidden()
                        Spacer()
                        Text(AppLocalizer.format("onboarding.age.value", age)).font(.title3).monospacedDigit()
                    }
                }

                // Вес
                VStack(alignment: .leading, spacing: 12) {
                    Text(AppLocalizer.string("profile.weight")).font(.headline)
                    HStack {
                        Stepper(value: $weight, in: 35...250, step: 1) { EmptyView() }
                            .labelsHidden()
                        Spacer()
                        Text(AppLocalizer.format("onboarding.weight.value", weight))
                            .font(.title3).monospacedDigit()
                    }
                }
                // Рост
                VStack(alignment: .leading, spacing: 12) {
                    Text(AppLocalizer.string("profile.height")).font(.headline)
                    Slider(value: $height, in: 120...230, step: 1)
                    Text(AppLocalizer.format("onboarding.height.value", Int(height)))
                        .font(.title3).monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
}


struct OnboardingView: View {
    var onFinish: (OnboardingPayload) -> Void

    @State private var page = 0
    @State private var data = OnboardingPayload()

    private let pages = 3   // basics + activity + goal

    var body: some View {
        VStack {
            TabView(selection: $page) {
                BasicsStep(
                    gender: $data.gender,
                    age: $data.age,
                    weight: $data.weight,
                    height: $data.height
                )
                .tag(0)

                ActivityStep(activity: $data.activity).tag(1)
                GoalStep(goal: $data.goal).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(.easeInOut, value: page)

            HStack(spacing: 12) {
                Button(AppLocalizer.string("common.back")) { page = max(0, page - 1) }
                    .buttonStyle(OnbSecondary())
                    .disabled(page == 0)

                if page < pages - 1 {
                    Button(AppLocalizer.string("common.next")) { page = min(pages - 1, page + 1) }
                        .buttonStyle(OnbPrimary())
                } else {
                    Button(AppLocalizer.string("common.done")) { onFinish(data) }
                        .buttonStyle(OnbPrimary())
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

private struct ActivityStep: View {
    @Binding var activity: ActivityLevel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(AppLocalizer.string("activity.title"))
                .font(.largeTitle).bold()
                .padding(.top, 40)

            ActivityRow(title: AppLocalizer.string("activity.none"), caption: AppLocalizer.string("activity.caption.none"),
                        isOn: activity == .none)
                .onTapGesture { activity = .none }

            ActivityRow(title: AppLocalizer.string("activity.light"), caption: AppLocalizer.string("activity.caption.light"),
                        isOn: activity == .light)
                .onTapGesture { activity = .light }

            ActivityRow(title: AppLocalizer.string("activity.moderate"), caption: AppLocalizer.string("activity.caption.moderate"),
                        isOn: activity == .moderate)
                .onTapGesture { activity = .moderate }

            ActivityRow(title: AppLocalizer.string("activity.pro"), caption: AppLocalizer.string("activity.caption.pro"),
                        isOn: activity == .pro)
                .onTapGesture { activity = .pro }

            Spacer()
        }
        .padding(.horizontal)
    }
}


private struct GoalStep: View {
    @Binding var goal: WeightGoal
    var body: some View {
        VStack(spacing: 24) {
            Text(AppLocalizer.string("goal.title")).font(.largeTitle).bold().padding(.top, 40)
            VStack(spacing: 12) {
                GoalRow(title: WeightGoal.loseWeight.displayName, isOn: goal == .loseWeight)
                    .onTapGesture { goal = .loseWeight }
                GoalRow(title: WeightGoal.currentWeight.displayName, isOn: goal == .currentWeight)
                    .onTapGesture { goal = .currentWeight }
                GoalRow(title: WeightGoal.gainWeight.displayName, isOn: goal == .gainWeight)
                    .onTapGesture { goal = .gainWeight }
            }
            .padding(.horizontal)
            Spacer()
        }
    }
}

// MARK: — мини-вьюшки

private struct ActivityRow: View {
    var title: String
    var caption: String
    var isOn: Bool
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(caption).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isOn ? .blue : .secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(.background))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.quaternary))
    }
}

private struct GoalRow: View {
    var title: String
    var isOn: Bool
    var body: some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isOn ? .blue : .secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(.background))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.quaternary))
    }
}

// MARK: — кнопки

private struct OnbPrimary: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.blue, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.white)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

private struct OnbSecondary: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.primary)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
