import Foundation

enum ActivityLevel: String, CaseIterable, Codable {
    case none = "Нет"
    case light = "1-3 раза"
    case moderate = "4-5 раза"
    case pro = "PRO"

    var message: String {
        switch self {
        case .none:
            return AppLocalizer.string("activity.message.none")
        case .light:
            return AppLocalizer.string("activity.message.light")
        case .moderate:
            return AppLocalizer.string("activity.message.moderate")
        case .pro:
            return AppLocalizer.string("activity.message.pro")
        }
    }

    var displayName: String {
        switch self {
        case .none:
            return AppLocalizer.string("activity.none")
        case .light:
            return AppLocalizer.string("activity.light")
        case .moderate:
            return AppLocalizer.string("activity.moderate")
        case .pro:
            return AppLocalizer.string("activity.pro")
        }
    }
}
