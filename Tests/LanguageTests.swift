import Foundation

@main
struct LanguageTests {
    static func main() throws {
        var checks = 0
        func expect(_ name: String, _ condition: @autoclosure () -> Bool) throws {
            guard condition() else { throw TestFailure(message: name) }
            checks += 1
        }

        try expect("manual Chinese overrides English system", AppLanguage.simplifiedChinese.usesChinese(systemLanguages: ["en-US"]))
        try expect("manual English overrides Chinese system", !AppLanguage.english.usesChinese(systemLanguages: ["zh-Hans-CN"]))
        try expect("system simplified Chinese", AppLanguage.system.usesChinese(systemLanguages: ["zh-Hans-CN"]))
        try expect("system Chinese uses available Chinese translation", AppLanguage.system.usesChinese(systemLanguages: ["zh-Hant-TW"]))
        try expect("locale underscore form", AppLanguage.system.usesChinese(systemLanguages: ["zh_CN"]))
        try expect("locale case insensitive", AppLanguage.system.usesChinese(systemLanguages: ["ZH-hans"]))
        try expect("first system language controls selection", !AppLanguage.system.usesChinese(systemLanguages: ["fr-FR", "zh-Hans"]))
        try expect("unsupported system language falls back to English", !AppLanguage.system.usesChinese(systemLanguages: ["ja-JP"]))
        try expect("missing system language falls back to English", !AppLanguage.system.usesChinese(systemLanguages: []))
        try expect("empty language falls back to English", !AppLanguage.system.usesChinese(systemLanguages: [""]))
        try expect("unrelated prefix is not Chinese", !AppLanguage.system.usesChinese(systemLanguages: ["zhinvalid"]))

        let suite = "HoverCapture.LanguageTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            throw TestFailure(message: "Could not create isolated preferences")
        }
        defer { defaults.removePersistentDomain(forName: suite) }
        try expect("fresh preference follows system", AppLanguage.read(from: defaults) == .system)
        AppLanguage.simplifiedChinese.store(in: defaults)
        try expect("manual Chinese stored", AppLanguage.read(from: defaults) == .simplifiedChinese)
        AppLanguage.english.store(in: defaults)
        try expect("manual English stored", AppLanguage.read(from: defaults) == .english)
        guard let reloaded = UserDefaults(suiteName: suite) else {
            throw TestFailure(message: "Could not reload isolated preferences")
        }
        try expect("choice survives preference reload", AppLanguage.read(from: reloaded) == .english)
        AppLanguage.system.store(in: defaults)
        try expect("system setting stored", AppLanguage.read(from: defaults) == .system)
        defaults.set("unsupported", forKey: "appLanguage")
        try expect("invalid stored setting follows system", AppLanguage.read(from: defaults) == .system)
        defaults.set(123, forKey: "appLanguage")
        try expect("wrong stored type follows system", AppLanguage.read(from: defaults) == .system)
        print("Language tests: \(checks) passed, 0 failed")
    }
}

private struct TestFailure: Error {
    let message: String
}
