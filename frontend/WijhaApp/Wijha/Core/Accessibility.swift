import SwiftUI

// the six types of need, same names as the backend
enum AccessNeed {
    static let all = ["WHEELCHAIR", "LIMITED_MOBILITY", "VISUAL", "HEARING", "SENSORY", "STROLLER_ELDERLY"]

    // these needs walk on step free paths, prefer the shade and get 40 min per pavilion
    static let mobility: Set<String> = ["WHEELCHAIR", "LIMITED_MOBILITY", "STROLLER_ELDERLY"]

    static func needsStepFree(_ needs: [String]) -> Bool {
        needs.contains { mobility.contains($0) }
    }

    static func sorted(_ needs: [String]) -> [String] {
        all.filter { needs.contains($0) }
    }

    static func icon(_ need: String) -> String {
        switch need {
        case "WHEELCHAIR": return "figure.roll"
        case "LIMITED_MOBILITY": return "figure.walk.motion"
        case "VISUAL": return "eye"
        case "HEARING": return "ear"
        case "SENSORY": return "waveform"
        case "STROLLER_ELDERLY": return "figure.and.child.holdinghands"
        default: return "accessibility"
        }
    }
}

// the Accessibility / Status component: icon + words, never colour alone
enum AccessStatus {
    static func tone(_ status: String) -> BadgeTone {
        switch status {
        case "ACCESSIBLE", "SUITABLE": return .success
        case "PARTIAL": return .warning
        case "NOT_ACCESSIBLE", "NOT_SUITABLE": return .danger
        default: return .neutral
        }
    }

    static func icon(_ status: String) -> String {
        switch status {
        case "ACCESSIBLE", "SUITABLE": return "checkmark"
        case "PARTIAL": return "exclamationmark.triangle.fill"
        case "NOT_ACCESSIBLE", "NOT_SUITABLE": return "xmark"
        default: return "questionmark"
        }
    }

    // "متاح" / "متاح جزئيًا" / "غير متاح" / "غير معروف"
    static func title(_ status: String, _ s: AppSettings) -> String {
        s.t("access.status.\(status)")
    }
}

// crowd level of a pavilion queue
enum CrowdLevel {
    static func tone(_ level: String?) -> BadgeTone {
        switch level {
        case "CALM": return .success
        case "CROWDED": return .danger
        case "MODERATE": return .warning
        default: return .neutral
        }
    }

    static func icon(_ level: String?) -> String {
        switch level {
        case "CALM": return "person"
        case "CROWDED": return "person.3.fill"
        default: return "person.2.fill"
        }
    }

    static func level(forWait minutes: Int?) -> String {
        guard let minutes else { return "UNKNOWN" }
        if minutes <= 10 { return "CALM" }
        if minutes >= 20 { return "CROWDED" }
        return "MODERATE"
    }
}

// same walking speed as the backend timeline: 1 map unit = 2 m, 75 m per minute
enum Walk {
    static func minutes(units: Double, mobility: Bool = false) -> Int {
        let base = units * 2 / 75
        return max(1, Int((mobility ? base * 1.25 : base).rounded()))
    }

    static func meters(units: Double) -> Int { Int((units * 2).rounded()) }
}
