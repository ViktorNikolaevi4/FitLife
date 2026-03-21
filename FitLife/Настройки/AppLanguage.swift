import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case russian = "ru"
    case english = "en"

    static let appStorageKey = "appLanguage"

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .russian:
            return Locale(identifier: "ru_RU")
        case .english:
            return Locale(identifier: "en_US")
        }
    }

    var displayName: String {
        switch self {
        case .russian:
            return localized("settings.language.russian")
        case .english:
            return localized("settings.language.english")
        }
    }

    static func from(rawValue: String) -> AppLanguage {
        AppLanguage(rawValue: rawValue) ?? .russian
    }

    func localized(_ key: String) -> String {
        NSLocalizedString(key, tableName: "Localizable", bundle: bundle, value: key, comment: "")
    }

    private var bundle: Bundle {
        guard let path = Bundle.main.path(forResource: rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}

enum AppLocalizer {
    static var currentLanguage: AppLanguage {
        AppLanguage.from(rawValue: UserDefaults.standard.string(forKey: AppLanguage.appStorageKey) ?? AppLanguage.russian.rawValue)
    }

    static func string(_ key: String) -> String {
        currentLanguage.localized(key)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: currentLanguage.locale, arguments: arguments)
    }
}
