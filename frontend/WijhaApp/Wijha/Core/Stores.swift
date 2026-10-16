import SwiftUI
import Observation

// Expo data that is the same for everyone: zones, pavilions, gates, the path network and the queue now.
@MainActor
@Observable
final class ExpoStore {
    var zones: [Zone] = []
    var pavilions: [Pavilion] = []
    var entrances: [Entrance] = []
    var locations: [LocationDTO] = []
    var paths: [PathDTO] = []
    var interests: [Interest] = []
    var crowd: [Int: CrowdStatus] = [:]
    var crowdUpdated: Date?
    var bounds = MapBounds()
    var loaded = false
    var loading = false
    var error: String?

    private var zoneOfPavilion: [Int: Zone] = [:]
    private var pavilionById: [Int: Pavilion] = [:]
    private var locationById: [Int: LocationDTO] = [:]
    private var pavilionByLocation: [Int: Pavilion] = [:]

    func load(force: Bool = false) async {
        if loading || (loaded && !force) { return }
        loading = true
        defer { loading = false }
        do {
            async let z = API.zones()
            async let p = API.pavilions()
            async let e = API.entrances()
            async let l = API.locations()
            async let pa = API.paths()
            async let i = API.interests()
            zones = try await z
            pavilions = try await p
            entrances = (try? await e) ?? []
            locations = (try? await l) ?? []
            paths = (try? await pa) ?? []
            interests = (try? await i) ?? []
            index()
            loaded = true
            error = nil
        } catch {
            self.error = error.text
        }
        await loadCrowd()
    }

    func loadCrowd() async {
        guard let list = try? await API.crowdNow() else { return }
        crowd = Dictionary(list.map { ($0.pavilionId, $0) }, uniquingKeysWith: { a, _ in a })
        crowdUpdated = Date()
    }

    private func index() {
        zoneOfPavilion = [:]
        for zone in zones {
            for p in zone.pavilions ?? [] { zoneOfPavilion[p.id] = zone }
        }
        pavilionById = Dictionary(pavilions.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        locationById = Dictionary(locations.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        pavilionByLocation = [:]
        for p in pavilions { if let loc = p.location { pavilionByLocation[loc.id] = p } }
        bounds = MapBounds.compute(locations: locations, zones: zones, pavilions: pavilions, entrances: entrances)
    }

    func pavilion(_ id: Int?) -> Pavilion? { id.flatMap { pavilionById[$0] } }
    func zone(of pavilionId: Int?) -> Zone? { pavilionId.flatMap { zoneOfPavilion[$0] } }
    func location(_ id: Int?) -> LocationDTO? { id.flatMap { locationById[$0] } }
    func pavilion(atLocation id: Int) -> Pavilion? { pavilionByLocation[id] }
    func entrance(named name: String?) -> Entrance? { entrances.first { $0.name == name } }

    func pavilions(inZone zone: Zone) -> [Pavilion] {
        let ids = Set((zone.pavilions ?? []).map(\.id))
        return pavilions.filter { ids.contains($0.id) }
    }

    var topRated: [Pavilion] {
        pavilions.filter { $0.ratingCount > 0 }
            .sorted { ($0.ratingAverage ?? 0, $0.ratingCount) > ($1.ratingAverage ?? 0, $1.ratingCount) }
    }

    func isShaded(_ a: Int, _ b: Int) -> Bool {
        paths.first { ($0.fromLocation?.id == a && $0.toLocation?.id == b) || ($0.fromLocation?.id == b && $0.toLocation?.id == a) }?.shaded == true
    }

}

// The logged in visitor: info, plans, passport, reviews and crowd alerts
@MainActor
@Observable
final class VisitorStore {
    var info: VisitorInfo?
    var roadmaps: [Roadmap] = []
    var passport: Passport?
    var stamps: [Stamp] = []
    var pending: [Pavilion] = []
    var myReviews: [ReviewDTO] = []
    var alerts: [CrowdAlert] = []
    var loaded = false
    var loading = false
    var error: String?

    func reset() {
        info = nil
        roadmaps = []
        passport = nil
        stamps = []
        pending = []
        myReviews = []
        alerts = []
        loaded = false
        error = nil
    }

    func refreshAll() async {
        loading = true
        defer { loading = false }
        async let i: Void = refreshInfo()
        async let r: Void = refreshRoadmaps()
        async let p: Void = refreshPassport()
        async let v: Void = refreshReviews()
        async let a: Void = refreshAlerts()
        _ = await (i, r, p, v, a)
        loaded = true
    }

    func refreshInfo() async {
        let value = try? await API.myInfo()
        if let value { info = value }
    }

    func refreshRoadmaps() async {
        do {
            roadmaps = try await API.myRoadmaps()
            error = nil
        } catch {
            self.error = error.text
        }
    }

    func refreshPassport() async {
        async let p = try? API.myPassport()
        async let s = try? API.myStamps()
        let passportValue = await p
        let stampsValue = await s
        if let passportValue { passport = passportValue }
        if let stampsValue { stamps = stampsValue }
    }

    func refreshReviews() async {
        async let p = try? API.pendingReviews()
        async let m = try? API.myReviews()
        pending = await p ?? []
        myReviews = await m ?? []
    }

    func refreshAlerts() async {
        alerts = (try? await API.myCrowdAlerts()) ?? []
    }

    // after a check-in: plans, passport and reviews waiting all change
    func afterCheckIn() async {
        async let r: Void = refreshRoadmaps()
        async let p: Void = refreshPassport()
        async let v: Void = refreshReviews()
        _ = await (r, p, v)
    }

    func replace(_ roadmap: Roadmap) {
        if let index = roadmaps.firstIndex(where: { $0.roadmapId == roadmap.roadmapId }) {
            roadmaps[index] = roadmap
        } else {
            roadmaps.append(roadmap)
        }
    }

    var today: Roadmap? { roadmaps.first { $0.isToday } }
    var upcoming: [Roadmap] { roadmaps.filter(\.isUpcoming).sorted { ($0.visitDate ?? "") < ($1.visitDate ?? "") } }
    var past: [Roadmap] { roadmaps.filter(\.isPast).sorted { ($0.visitDate ?? "") > ($1.visitDate ?? "") } }

    var earnedStampIds: Set<Int> { Set(stamps.filter(\.isEarned).compactMap(\.pavilionId)) }
    var pendingIds: Set<Int> { Set(pending.map(\.id)) }
    var earnedCount: Int { stamps.filter(\.isEarned).count }

    var todayVisitedIds: Set<Int> {
        let calendar = Calendar.current
        return Set((passport?.visits ?? []).filter { v in
            DateText.parseDateTime(v.visitedAt).map { calendar.isDateInToday($0) } ?? false
        }.compactMap(\.pavilionId))
    }

    var todayPlanIds: Set<Int> { Set((today?.stops ?? []).compactMap(\.pavilionId)) }

    // every recorded visit of ONE pavilion (matched by its id only, so a repeated stamp never leaks to another country), newest first
    // the backend allows one check-in per pavilion per day, so each visit here is a different day
    func visits(of pavilionId: Int?) -> [PassportVisit] {
        guard let pavilionId else { return [] }
        return (passport?.visits ?? [])
            .filter { $0.pavilionId == pavilionId }
            .sorted { ($0.visitedAt ?? "") > ($1.visitedAt ?? "") }
    }

    // status shown on every pavilion card (text + icon, not colour alone)
    func status(of pavilionId: Int) -> PavilionStatus {
        if let next = today?.nextStop, next.pavilionId == pavilionId { return .next }
        if earnedStampIds.contains(pavilionId) {
            return pendingIds.contains(pavilionId) ? .visited : .reviewed
        }
        if todayPlanIds.contains(pavilionId) { return .inPlan }
        return .none
    }

    var newAlerts: [CrowdAlert] {
        alerts.filter { $0.accepted != true }
    }
}

enum PavilionStatus {
    case none, inPlan, next, visited, reviewed
}

// the map area, same rule as route3d.html / mapart.js so expo-map.png sits in the same place
struct MapBounds {
    var minX: Double = 0
    var maxX: Double = 1000
    var minY: Double = 0
    var maxY: Double = 770

    var width: Double { max(maxX - minX, 1) }
    var height: Double { max(maxY - minY, 1) }
    var aspect: Double { width / height }

    static func compute(locations: [LocationDTO], zones: [Zone], pavilions: [Pavilion], entrances: [Entrance]) -> MapBounds {
        guard !locations.isEmpty else { return MapBounds() }
        let zoneIds = Set(zones.compactMap { $0.location?.id })
        let pavilionIds = Set(pavilions.compactMap { $0.location?.id })
        let entranceIds = Set(entrances.compactMap { $0.location?.id })
        let junctions = locations.filter { !zoneIds.contains($0.id) && !pavilionIds.contains($0.id) && !entranceIds.contains($0.id) }

        // the central plaza is the junction closest to the middle of the zones
        var cx = 500.0, cy = 400.0
        let zonePoints = zones.compactMap(\.location)
        if !zonePoints.isEmpty {
            cx = zonePoints.map(\.x).reduce(0, +) / Double(zonePoints.count)
            cy = zonePoints.map(\.y).reduce(0, +) / Double(zonePoints.count)
        }
        let plaza = junctions.min { hypot($0.x - cx, $0.y - cy) < hypot($1.x - cx, $1.y - cy) }
        if let plaza, hypot(plaza.x - cx, plaza.y - cy) <= 60 {
            return MapBounds()
        }
        let xs = locations.map(\.x), ys = locations.map(\.y)
        return MapBounds(minX: (xs.min() ?? 0) - 90, maxX: (xs.max() ?? 1000) + 90,
                         minY: (ys.min() ?? 0) - 60, maxY: (ys.max() ?? 770) + 60)
    }

    func point(_ x: Double, _ y: Double, in size: CGSize) -> CGPoint {
        CGPoint(x: (x - minX) / width * size.width, y: (y - minY) / height * size.height)
    }
}
