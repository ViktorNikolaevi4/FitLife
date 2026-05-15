import Foundation

enum WeightGoal: String, CaseIterable, Codable {
    case loseWeight = "Снизить вес"
    case currentWeight = "Текущий вес"
    case gainWeight = "Набрать вес"

    var displayName: String {
        switch self {
        case .loseWeight:
            return AppLocalizer.string("goal.lose")
        case .currentWeight:
            return AppLocalizer.string("goal.maintain")
        case .gainWeight:
            return AppLocalizer.string("goal.gain")
        }
    }
}
