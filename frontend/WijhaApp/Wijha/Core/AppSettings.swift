import SwiftUI
import Observation

enum AppLanguage: String, CaseIterable, Identifiable {
    case ar, en
    var id: String { rawValue }
    var displayName: String { self == .ar ? "العربية" : "English" }
    // the value the backend expects for preferredLanguage
    var apiValue: String { self == .ar ? "AR" : "EN" }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case dark, light, system
    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    var icon: String {
        switch self {
        case .dark: return "moon.fill"
        case .light: return "sun.max.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }
}

enum MapStyle: String {
    case illustrated, image
}

// language, appearance, map style and the backend address, saved on the device
@Observable
final class AppSettings {
    var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "language") }
    }
    var appearance: AppAppearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "appearance") }
    }
    // the map style is remembered per device, default = illustrated (توضيحية)
    var mapStyle: MapStyle {
        didSet { UserDefaults.standard.set(mapStyle.rawValue, forKey: "mapStyle") }
    }
    var serverURL: String {
        didSet {
            UserDefaults.standard.set(serverURL, forKey: "serverURL")
            APIClient.shared.baseURL = serverURL
        }
    }
    // recent searches stay on the device only
    var recentSearches: [String] {
        didSet { UserDefaults.standard.set(recentSearches, forKey: "recentSearches") }
    }

    init() {
        let defaults = UserDefaults.standard
        language = AppLanguage(rawValue: defaults.string(forKey: "language") ?? "") ?? .ar
        appearance = AppAppearance(rawValue: defaults.string(forKey: "appearance") ?? "") ?? .dark
        mapStyle = MapStyle(rawValue: defaults.string(forKey: "mapStyle") ?? "") ?? .illustrated
        serverURL = defaults.string(forKey: "serverURL") ?? "http://localhost:8080"
        recentSearches = defaults.stringArray(forKey: "recentSearches") ?? []
        APIClient.shared.baseURL = serverURL
    }

    var isArabic: Bool { language == .ar }
    var layoutDirection: LayoutDirection { isArabic ? .rightToLeft : .leftToRight }
    // Western digits in both languages (design rule)
    var locale: Locale { Locale(identifier: isArabic ? "ar@numbers=latn" : "en_US") }

    func t(_ key: String) -> String {
        guard let pair = Strings.table[key] else { return key }
        return isArabic ? pair.0 : pair.1
    }

    // text with %@ placeholders filled in order
    func t(_ key: String, _ args: CVarArg...) -> String {
        String(format: t(key), locale: Locale(identifier: "en_US_POSIX"), arguments: args)
    }

    // fixed backend values shown in the app language
    func label(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "" }
        if let pair = Strings.values[value] { return isArabic ? pair.0 : pair.1 }
        return value
    }

    func zoneName(_ name: String?) -> String { label(name) }

    // "منطقة التعاون" / "Collaboration Zone"
    func zoneTitle(_ name: String?) -> String {
        guard let name, !name.isEmpty else { return "" }
        return isArabic ? "منطقة \(label(name))" : "\(label(name)) Zone"
    }

    func entranceName(_ name: String?) -> String { label(name) }

    func pavilionName(_ name: String?) -> String {
        guard let name else { return "" }
        if isArabic, let ar = PavilionNames.arabic[name] { return ar }
        return name
    }

    func countryName(_ country: String?) -> String {
        guard let country else { return "" }
        if isArabic, let ar = PavilionNames.arabicCountries[country] { return ar }
        return country
    }

    func interestName(_ interest: Interest) -> String {
        if isArabic, let ar = interest.nameAr, !ar.isEmpty { return ar }
        return interest.name
    }

    func addRecentSearch(_ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 2 else { return }
        var list = recentSearches.filter { $0.caseInsensitiveCompare(clean) != .orderedSame }
        list.insert(clean, at: 0)
        recentSearches = Array(list.prefix(6))
    }
}
