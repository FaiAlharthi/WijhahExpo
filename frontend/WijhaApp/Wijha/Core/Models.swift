import Foundation

// Shapes of the backend responses. Most fields are optional so a missing field never breaks the app.

struct MessageResponse: Decodable {
    let message: String?
}

struct LocationDTO: Codable, Identifiable, Hashable {
    let id: Int
    let x: Double
    let y: Double
}

struct ReviewDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let rating: Int?
    let comment: String?
    let createdAt: String?
    let accessibilityVerdict: String?
    let accessibilityNeeds: [String]?
}

// official accessibility of a pavilion for one need
struct AccessibilityRow: Decodable, Hashable {
    let needType: String
    let status: String
    let note: String?
    let noteAr: String?
}

struct Pavilion: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let country: String?
    let description: String?
    let imageUrl: String?
    let capacity: Int?
    let avgVisitMinutes: Int?
    let location: LocationDTO?
    let reviews: [ReviewDTO]?
    let accessibility: [AccessibilityRow]?

    // ACCESSIBLE, PARTIAL, NOT_ACCESSIBLE or UNKNOWN
    func accessStatus(_ need: String) -> String {
        accessibility?.first { $0.needType == need }?.status ?? "UNKNOWN"
    }

    func accessRow(_ need: String) -> AccessibilityRow? {
        accessibility?.first { $0.needType == need }
    }

    // same rule as the backend: no need is NOT_ACCESSIBLE and every need has data
    func suits(_ needs: [String]) -> Bool {
        needs.allSatisfy { let s = accessStatus($0); return s == "ACCESSIBLE" || s == "PARTIAL" }
    }

    func fullySuits(_ needs: [String]) -> Bool {
        needs.allSatisfy { accessStatus($0) == "ACCESSIBLE" }
    }

    var ratingAverage: Double? {
        let ratings = (reviews ?? []).compactMap(\.rating)
        guard !ratings.isEmpty else { return nil }
        return Double(ratings.reduce(0, +)) / Double(ratings.count)
    }

    var ratingCount: Int { (reviews ?? []).filter { $0.rating != nil }.count }

    static func == (lhs: Pavilion, rhs: Pavilion) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct Zone: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let description: String?
    let location: LocationDTO?
    let pavilions: [Pavilion]?

    static func == (lhs: Zone, rhs: Zone) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct Entrance: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let location: LocationDTO?
}

struct PathDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let distance: Double?
    let stepFree: Bool?
    let shaded: Bool?
    let fromLocation: LocationDTO?
    let toLocation: LocationDTO?
}

struct Interest: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let nameAr: String?
}

struct VisitorInfo: Decodable, Identifiable, Hashable {
    let id: Int
    let fullName: String?
    let username: String?
    let email: String?
    let phone: String?
    let age: Int?
    let gender: String?
    let preferredLanguage: String?
    let nationality: String?
    let interests: [Interest]?
    let passportNumber: String?
    let createdAt: String?

    var firstName: String {
        (fullName ?? username ?? "").split(separator: " ").first.map(String.init) ?? ""
    }
    var initial: String { String((fullName ?? username ?? "?").prefix(1)) }
}

struct UserInfo: Decodable, Identifiable {
    let id: Int
    let fullName: String?
    let username: String?
    let email: String?
    let phone: String?
    let role: String?
    let createdAt: String?
}

struct RoadmapBreak: Decodable, Hashable {
    let type: String?
    let time: String?
    let minutes: Int?
    let note: String?
}

struct AccessibilityWarning: Decodable, Hashable {
    let needType: String
    let status: String
    let note: String?
    let noteAr: String?
}

struct RoadmapStop: Decodable, Identifiable, Hashable {
    let visitId: Int
    let stopOrder: Int?
    let pavilionId: Int?
    let pavilionName: String?
    let country: String?
    let zoneName: String?
    let imageUrl: String?
    let isVisited: Bool?
    let visitedAt: String?
    let accessibilityWarnings: [AccessibilityWarning]?
    let plannedTime: String?
    let expectedWait: Int?

    var id: Int { visitId }
    var visited: Bool { isVisited ?? false }
}

struct Roadmap: Decodable, Identifiable, Hashable {
    let roadmapId: Int
    let visitDate: String?
    let entranceId: Int?
    let entranceName: String?
    let summary: String?
    let aiUsed: Bool?
    let breaks: [RoadmapBreak]?
    let stops: [RoadmapStop]?
    let accessibilityNeeds: [String]?
    let whatsappAlerts: Bool?

    var id: Int { roadmapId }
    var needs: [String] { AccessNeed.sorted(accessibilityNeeds ?? []) }
    var orderedStops: [RoadmapStop] { (stops ?? []).sorted { ($0.stopOrder ?? 0) < ($1.stopOrder ?? 0) } }
    var visitedCount: Int { (stops ?? []).filter(\.visited).count }
    var stopsCount: Int { stops?.count ?? 0 }
    var started: Bool { visitedCount > 0 }
    var nextStop: RoadmapStop? { orderedStops.first { !$0.visited } }
    var lastVisited: RoadmapStop? { orderedStops.last { $0.visited } }
    var isFinished: Bool { stopsCount > 0 && visitedCount == stopsCount }

    var day: Date? { visitDate.flatMap(DateText.parseDay) }
    var isToday: Bool { day.map { Calendar.current.isDateInToday($0) } ?? false }
    var isPast: Bool {
        guard let day else { return false }
        return day < Calendar.current.startOfDay(for: Date())
    }
    var isUpcoming: Bool { !isToday && !isPast }

    static func == (lhs: Roadmap, rhs: Roadmap) -> Bool {
        lhs.roadmapId == rhs.roadmapId && lhs.stops == rhs.stops && lhs.entranceId == rhs.entranceId
    }
    func hash(into hasher: inout Hasher) { hasher.combine(roadmapId) }
}

struct RouteStop: Decodable, Identifiable, Hashable {
    let visitId: Int
    let stopOrder: Int?
    let pavilionId: Int?
    let pavilionName: String?
    let isVisited: Bool?
    var id: Int { visitId }
}

struct RoadmapRoute: Decodable {
    let visitOrder: [RouteStop]?
    let totalDistance: Double?
    let route: [LocationDTO]?
    let exitEntrance: String?
    let accessibleRoute: Bool?
}

struct ShortestPath: Decodable {
    let totalDistance: Double?
    let locations: [LocationDTO]?
}

struct PassportVisit: Decodable, Identifiable, Hashable {
    let visitId: Int
    let pavilionId: Int?
    let pavilionName: String?
    let country: String?
    let zoneName: String?
    let imageUrl: String?
    let visitedAt: String?
    var id: Int { visitId }
}

struct Passport: Decodable {
    let passportId: Int?
    let passportNumber: String?
    let visitsCount: Int?
    let visits: [PassportVisit]?
}

struct Stamp: Decodable, Identifiable, Hashable {
    let stampId: Int
    let title: String?
    let imageUrl: String?
    let pavilionId: Int?
    let pavilionName: String?
    let earned: Bool?
    let earnedAt: String?
    var id: Int { stampId }
    var isEarned: Bool { earned ?? false }
}

struct PavilionReview: Decodable, Identifiable, Hashable {
    let reviewId: Int
    let visitorName: String?
    let rating: Int?
    let comment: String?
    let createdAt: String?
    var id: Int { reviewId }
}

// pavilion page: the official status and what visitors with this need said
struct PavilionAccessibility: Decodable, Identifiable, Hashable {
    let needType: String
    let status: String
    let note: String?
    let noteAr: String?
    let suitableCount: Int?
    let partialCount: Int?
    let notSuitableCount: Int?
    var id: String { needType }
    var votes: Int { (suitableCount ?? 0) + (partialCount ?? 0) + (notSuitableCount ?? 0) }
}

struct PavilionDetails: Decodable, Hashable {
    let pavilionId: Int
    let name: String
    let country: String?
    let description: String?
    let imageUrl: String?
    let zoneId: Int?
    let zoneName: String?
    let x: Double?
    let y: Double?
    let reviews: [PavilionReview]?
    let accessibility: [PavilionAccessibility]?
}

// ===== crowd =====

// expected queue of one pavilion now: CALM (10 min or less), MODERATE, CROWDED (20 min or more)
struct CrowdStatus: Decodable, Identifiable, Hashable {
    let pavilionId: Int
    let pavilionName: String?
    let waitMinutes: Int?
    let level: String?
    let expectedPeople: Int?
    let capacity: Int?
    let manual: Bool?
    var id: Int { pavilionId }
}

struct CrowdSlot: Decodable, Identifiable, Hashable {
    let time: String
    let waitMinutes: Int?
    let level: String?
    var id: String { time }
}

struct CrowdPavilion: Decodable, Hashable {
    let pavilionId: Int
    let pavilionName: String?
    let waitNow: Int?
    let level: String?
    let capacity: Int?
    let avgVisitMinutes: Int?
    let calmAt: String?
    let slots: [CrowdSlot]?
}

struct CrowdAlert: Decodable, Identifiable, Hashable {
    let alertId: Int
    let roadmapId: Int?
    let pavilionId: Int?
    let pavilionName: String?
    let sentAt: String?
    let calmAt: String?
    let waitNow: Int?
    let waitCalm: Int?
    let delivered: Bool?
    let accepted: Bool?
    var id: Int { alertId }
}

// ===== assistant =====

struct ChatSuggestions: Decodable {
    let questions: [String]?
}

struct ChatAnswer: Decodable {
    let answer: String?
}

// ===== admin =====

struct CountItem: Decodable, Identifiable, Hashable {
    let name: String
    let count: Int
    var id: String { name }
}

struct PavilionStat: Decodable, Identifiable, Hashable {
    let pavilionId: Int
    let name: String
    let country: String?
    let zoneName: String?
    let visits: Int?
    let averageRating: Double?
    let reviewsCount: Int?
    var id: Int { pavilionId }
}

struct AccessibilityConflict: Decodable, Identifiable, Hashable {
    let pavilionId: Int
    let pavilionName: String?
    let needType: String
    let officialStatus: String?
    let notSuitableCount: Int?
    let totalCount: Int?
    var id: String { "\(pavilionId)-\(needType)" }
}

struct Dashboard: Decodable {
    let totalVisitors: Int?
    let totalCheckIns: Int?
    let totalRoadmaps: Int?
    let mostVisitedPavilions: [PavilionStat]?
    let topRatedPavilions: [PavilionStat]?
    let lowestRatedPavilions: [PavilionStat]?
    let topInterests: [CountItem]?
    let visitsPerDay: [CountItem]?
    let visitsPerZone: [CountItem]?
    let entrances: [CountItem]?
    let roadmapsWithNeeds: Int?
    let accessibilityNeeds: [CountItem]?
    let accessibilityConflicts: [AccessibilityConflict]?
    let crowdedNow: [CrowdStatus]?
    let alertsSentToday: Int?
    let alertsAcceptedToday: Int?
}

// records the admin can see
struct VisitRecord: Decodable, Identifiable, Hashable {
    let id: Int
    let visitedAt: String?
    let isVisited: Bool?
    let stopOrder: Int?
    let pavilionName: String?
    let pavilionId: Int?
}

struct PassportRecord: Decodable, Identifiable, Hashable {
    let id: Int
    let passportNumber: String?
    let visits: [VisitRecord]?
}

struct RoadmapRecord: Decodable, Identifiable, Hashable {
    let id: Int
    let visitDate: String?
    let partyType: String?
    let partySize: Int?
    let arrivalTime: String?
    let departureTime: String?
    let visitPace: String?
    let createdAt: String?
    let aiSummary: String?
    let entrance: Entrance?
    let visits: [VisitRecord]?
    let accessibilityNeeds: [String]?
    let experienceTypes: [String]?
    let whatsappAlerts: Bool?
}

// ===== request bodies =====

struct RegisterRequest: Encodable {
    var fullName = ""
    var username = ""
    var password = ""
    var email = ""
    var phone = "+966"
    var age = 25
    var gender = ""
    var preferredLanguage = "AR"
    var nationality = ""
}

struct GenerateRoadmapRequest: Encodable {
    var visitDate: String
    var partyType: String
    var partySize: Int
    var arrivalTime: String
    var departureTime: String
    var experienceTypes: [String]
    var visitPace: String
    var includePrayerBreaks: Bool
    var includeMealBreaks: Bool
    var includeChildRestBreaks: Bool
    var allowRevisits: Bool
    var extraInterestIds: [Int]?
    var whatsappAlerts: Bool
    var accessibilityNeeds: [String]?
}

struct ShareBody: Encodable {
    var shareNote: String?
    var showContact: Bool
    var audience: String   // ALL | SAME_GENDER
}

// a shared plan shown in "Find a group"
struct SharedRoadmap: Decodable, Identifiable, Hashable {
    let roadmapId: Int
    let visitDate: String?
    let arrivalTime: String?
    let departureTime: String?
    let visitPace: String?
    let firstName: String?
    let nationality: String?
    let interests: [Interest]?
    let commonInterests: Int?
    let shareNote: String?
    let entranceName: String?
    let stops: [SharedStop]?
    let copyCount: Int?
    let locked: Bool?
    let phone: String?
    var id: Int { roadmapId }
    var orderedStops: [SharedStop] { (stops ?? []).sorted { ($0.stopOrder ?? 0) < ($1.stopOrder ?? 0) } }
}

struct SharedStop: Decodable, Identifiable, Hashable {
    let stopOrder: Int?
    let pavilionId: Int?
    let pavilionName: String?
    let zoneName: String?
    let imageUrl: String?
    var id: Int { pavilionId ?? (stopOrder ?? 0) }
}

struct ReorderRequest: Encodable {
    let visitIds: [Int]
}

struct ChatMessageBody: Encodable {
    let role: String
    let text: String
}

struct ChatRequest: Encodable {
    let question: String
    let history: [ChatMessageBody]
}

struct ReviewBody: Encodable {
    let rating: Int
    let comment: String?
    var accessibilityVerdict: String? = nil
    var accessibilityNeeds: [String]? = nil
}

struct AccessibilityUpdateBody: Encodable {
    var status: String
    var note: String?
    var noteAr: String?
}

struct PathAccessibilityBody: Encodable {
    var stepFree: Bool
    var shaded: Bool
}

struct UpdateUserBody: Encodable {
    var fullName: String
    var username: String
    var password: String
    var email: String
    var phone: String
}

struct UpdateVisitorBody: Encodable {
    var age: Int
    var gender: String
    var preferredLanguage: String
    var nationality: String
}

struct ZoneBody: Encodable {
    var name: String
    var description: String
}

struct EntranceBody: Encodable {
    var name: String
}

struct LocationBody: Encodable {
    var x: Double
    var y: Double
}

struct PavilionBody: Encodable {
    var name: String
    var country: String
    var description: String
    var imageUrl: String
    var capacity: Int?
    var avgVisitMinutes: Int?
}

struct InterestBody: Encodable {
    var name: String
    var nameAr: String
}

// ===== date and time text from the backend =====
enum DateText {
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func parseDay(_ text: String) -> Date? {
        dayFormatter.date(from: String(text.prefix(10)))
    }

    static func dayString(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    static func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    // "2026-10-15T10:05:00.123" -> Date
    static func parseDateTime(_ text: String?) -> Date? {
        guard let text, text.count >= 16 else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return f.date(from: String(text.prefix(16)))
    }

    // "الثلاثاء 15 أكتوبر 2030" (Western digits)
    static func longDay(_ text: String?, _ s: AppSettings) -> String {
        guard let text, let date = parseDay(text) else { return text ?? "" }
        return longDay(date, s)
    }

    static func longDay(_ date: Date, _ s: AppSettings) -> String {
        let f = DateFormatter()
        f.locale = s.locale
        f.calendar = Calendar(identifier: .gregorian)
        f.setLocalizedDateFormatFromTemplate("EEEEdMMMMy")
        return f.string(from: date)
    }

    // "15 أكتوبر"
    static func shortDay(_ text: String?, _ s: AppSettings) -> String {
        guard let text, let date = parseDay(text) else { return text ?? "" }
        let f = DateFormatter()
        f.locale = s.locale
        f.calendar = Calendar(identifier: .gregorian)
        f.setLocalizedDateFormatFromTemplate("dMMMM")
        return f.string(from: date)
    }

    // "الثلاثاء 15 أكتوبر" without the year
    static func weekdayDay(_ text: String?, _ s: AppSettings) -> String {
        guard let text, let date = parseDay(text) else { return text ?? "" }
        let f = DateFormatter()
        f.locale = s.locale
        f.calendar = Calendar(identifier: .gregorian)
        f.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        return f.string(from: date)
    }

    // short weekday for the day strip, e.g. "الأحد" / "Sun"
    static func weekdayShort(_ date: Date, _ s: AppSettings) -> String {
        let f = DateFormatter()
        f.locale = s.locale
        f.calendar = Calendar(identifier: .gregorian)
        f.setLocalizedDateFormatFromTemplate("EEE")
        return f.string(from: date)
    }

    // day number for the day strip, e.g. "15"
    static func dayNumber(_ date: Date, _ s: AppSettings) -> String {
        let f = DateFormatter()
        f.locale = s.locale
        f.calendar = Calendar(identifier: .gregorian)
        f.setLocalizedDateFormatFromTemplate("d")
        return f.string(from: date)
    }

    // "10:05" -> "10:05 ص" / "10:05 AM"
    static func clock12(_ hhmm: String?, _ s: AppSettings) -> String {
        guard let hhmm, hhmm.count >= 4 else { return hhmm ?? "" }
        let parts = hhmm.prefix(5).split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return String(hhmm.prefix(5)) }
        let pm = h >= 12
        let h12 = h % 12 == 0 ? 12 : h % 12
        let suffix = s.isArabic ? (pm ? "م" : "ص") : (pm ? "PM" : "AM")
        return String(format: "%d:%02d %@", h12, m, suffix)
    }

    // "2026-10-15T10:05:00" -> "10:05"
    static func clock(_ text: String?) -> String {
        guard let text else { return "" }
        if let tIndex = text.firstIndex(of: "T") {
            return String(text[text.index(after: tIndex)...].prefix(5))
        }
        return String(text.prefix(5))
    }

    // "2026-10-15T10:05:00" -> "2026-10-15 10:05"
    static func short(_ text: String?) -> String {
        guard let text else { return "" }
        let day = String(text.prefix(10))
        let time = clock(text)
        return time.isEmpty ? day : "\(day) \(time)"
    }

    // "قبل ساعتين" / "2 hours ago"
    static func relative(_ text: String?, _ s: AppSettings) -> String {
        guard let date = parseDateTime(text) else { return short(text) }
        let f = RelativeDateTimeFormatter()
        f.locale = s.locale
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
    }

    static func minutes(from hhmm: String?) -> Int? {
        guard let hhmm else { return nil }
        let parts = hhmm.prefix(5).split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return h * 60 + m
    }
}
