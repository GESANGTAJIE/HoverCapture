import Foundation

enum AppLanguage: String, CaseIterable {
    case system
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    static var storedPreference: AppLanguage {
        get { read(from: .standard) }
        set { newValue.store(in: .standard) }
    }

    static func read(from defaults: UserDefaults) -> AppLanguage {
        guard let value = defaults.string(forKey: "appLanguage"),
              let language = AppLanguage(rawValue: value) else { return .system }
        return language
    }

    func store(in defaults: UserDefaults) {
        defaults.set(rawValue, forKey: "appLanguage")
    }

    func usesChinese(systemLanguages: [String] = Locale.preferredLanguages) -> Bool {
        switch self {
        case .simplifiedChinese: return true
        case .english: return false
        case .system:
            let languageCode = systemLanguages.first?.split(whereSeparator: { $0 == "-" || $0 == "_" }).first
            return languageCode?.lowercased() == "zh"
        }
    }
}

enum AppText {
    static var chinese: Bool { AppLanguage.storedPreference.usesChinese() }
    static func pick(_ zh: String, _ en: String) -> String { chinese ? zh : en }
}
