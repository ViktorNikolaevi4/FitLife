import Foundation

enum WaterTemperature: String, CaseIterable {
    case cold = "Холодно"
    case warm = "Тепло"
    case hot = "Жарко"

    var displayName: String {
        switch self {
        case .cold:
            return AppLocalizer.string("water.temperature.cold")
        case .warm:
            return AppLocalizer.string("water.temperature.warm")
        case .hot:
            return AppLocalizer.string("water.temperature.hot")
        }
    }
}
