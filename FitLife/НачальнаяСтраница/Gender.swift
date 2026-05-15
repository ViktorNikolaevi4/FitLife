import Foundation

enum Gender: String, CaseIterable, Codable {
    case male = "Мужчина"
    case female = "Женщина"

    var imageName: String {
        switch self {
        case .male:
            return "МужскойПрофиль"
        case .female:
            return "ЖенскийПрофиль"
        }
    }

    var displayName: String {
        switch self {
        case .male:
            return AppLocalizer.string("gender.male")
        case .female:
            return AppLocalizer.string("gender.female")
        }
    }
}
