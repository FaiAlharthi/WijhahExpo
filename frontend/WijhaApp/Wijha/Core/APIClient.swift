import Foundation

struct APIError: LocalizedError {
    let status: Int
    let message: String
    var errorDescription: String? { message }
    var isOffline: Bool { status == -1 }
}

extension Error {
    // readable message for the banners
    var text: String { (self as? APIError)?.message ?? localizedDescription }
}

// Talks to the Spring Boot backend with Basic Auth (username:password with every request)
final class APIClient {
    static let shared = APIClient()

    var baseURL: String = "http://localhost:8080"
    private(set) var username: String?
    private(set) var password: String?

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        // no cookies: every request carries its own Basic Auth header
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.timeoutIntervalForRequest = 120
        return URLSession(configuration: config)
    }()

    func setCredentials(username: String?, password: String?) {
        self.username = username
        self.password = password
    }

    var basicAuthHeader: String? {
        guard let username, let password else { return nil }
        return "Basic " + Data("\(username):\(password)".utf8).base64EncodedString()
    }

    var trimmedBase: String {
        var base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        return base
    }

    // images: absolute links stay, backend links like /stamps/Japan.png get the server address
    func resolveImageURL(_ raw: String?) -> URL? {
        guard var raw, !raw.isEmpty else { return nil }
        if raw.hasPrefix("http") { return URL(string: raw) }
        if raw.hasPrefix("/stamps/") && raw.contains("@1x.png") {
            raw = raw.replacingOccurrences(of: "@1x.png", with: ".png")
                .replacingOccurrences(of: "%20", with: "_")
                .replacingOccurrences(of: " ", with: "_")
        }
        let path = raw.hasPrefix("/") ? raw : "/" + raw
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        return URL(string: trimmedBase + encoded)
    }

    func url(_ path: String) -> URL? {
        URL(string: trimmedBase + "/api/v1" + path)
    }

    // sends the request and decodes the json answer
    func call<T: Decodable>(_ method: String, _ path: String, body: (any Encodable)? = nil, auth: Bool = true) async throws -> T {
        let data = try await raw(method, path, body: body, auth: auth)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError(status: 0, message: "Could not read the server answer (\(path))")
        }
    }

    // endpoints that answer with {"message": "..."}
    @discardableResult
    func send(_ method: String, _ path: String, body: (any Encodable)? = nil, auth: Bool = true) async throws -> String? {
        let data = try await raw(method, path, body: body, auth: auth)
        if data.isEmpty { return nil }
        return (try? JSONDecoder().decode(MessageResponse.self, from: data))?.message
    }

    // binary answers (the roadmap PDF)
    func data(_ method: String, _ path: String) async throws -> Data {
        try await raw(method, path, body: nil, auth: true, accept: "application/pdf")
    }

    private func raw(_ method: String, _ path: String, body: (any Encodable)?, auth: Bool, accept: String = "application/json") async throws -> Data {
        guard let url = url(path) else {
            throw APIError(status: 0, message: "Wrong server address")
        }
        let encodedBody = try body.map { try JSONEncoder().encode($0) }

        // Authenticated requests retry once on a 401: a freshly created account (or a
        // momentary server hiccup) can briefly reject valid credentials. This self-heals it.
        let maxAttempts = (auth && basicAuthHeader != nil) ? 2 : 1
        var lastMessage: String?
        for attempt in 0..<maxAttempts {
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.setValue(accept, forHTTPHeaderField: "Accept")
            if let encodedBody {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = encodedBody
            }
            if auth, let header = basicAuthHeader {
                request.setValue(header, forHTTPHeaderField: "Authorization")
            }

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: request)
            } catch {
                throw APIError(status: -1, message: "OFFLINE")
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (200..<300).contains(status) { return data }
            let message = (try? JSONDecoder().decode(MessageResponse.self, from: data))?.message
            lastMessage = message
            if status == 401, attempt + 1 < maxAttempts {
                try? await Task.sleep(for: .milliseconds(700))
                continue
            }
            switch status {
            case 401: throw APIError(status: 401, message: message ?? "AUTH_FAILED")
            case 403: throw APIError(status: 403, message: message ?? "FORBIDDEN")
            default: throw APIError(status: status, message: message ?? "Something went wrong (\(status))")
            }
        }
        throw APIError(status: 401, message: lastMessage ?? "AUTH_FAILED")
    }
}

private func encodePath(_ text: String) -> String {
    text.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))) ?? text
}

// Every backend endpoint used by the app
enum API {
    private static var c: APIClient { APIClient.shared }

    // ===== visitor account =====
    static func register(_ body: RegisterRequest) async throws { try await c.send("POST", "/visitor/register", body: body, auth: false) }
    static func myInfo() async throws -> VisitorInfo { try await c.call("GET", "/visitor/getMyInfo") }
    static func updateVisitor(_ body: UpdateVisitorBody) async throws { try await c.send("PUT", "/visitor/updateVisitor", body: body) }
    static func addInterest(_ id: Int) async throws { try await c.send("PUT", "/visitor/addInterest/\(id)") }
    static func removeInterest(_ id: Int) async throws { try await c.send("DELETE", "/visitor/removeInterest/\(id)") }
    static func deleteMyVisitor() async throws { try await c.send("DELETE", "/visitor/deleteVisitor") }

    // ===== user account =====
    static func user(_ id: Int) async throws -> UserInfo { try await c.call("GET", "/user/get/\(id)") }
    static func updateUser(_ body: UpdateUserBody) async throws { try await c.send("PUT", "/user/updateUser", body: body) }
    static func deleteMyUser() async throws { try await c.send("DELETE", "/user/deleteUser") }
    static func logout() async { _ = try? await c.send("POST", "/user/auth/logout") }

    // ===== expo data (open to everyone) =====
    static func zones() async throws -> [Zone] { try await c.call("GET", "/zone/get", auth: false) }
    static func entrances() async throws -> [Entrance] { try await c.call("GET", "/entrance/getAll", auth: false) }
    static func locations() async throws -> [LocationDTO] { try await c.call("GET", "/location/get", auth: false) }
    static func interests() async throws -> [Interest] { try await c.call("GET", "/interest/get", auth: false) }
    static func pavilions() async throws -> [Pavilion] { try await c.call("GET", "/pavilion/get", auth: false) }
    static func pavilionDetails(_ id: Int) async throws -> PavilionDetails { try await c.call("GET", "/pavilion/details/\(id)", auth: false) }
    static func pavilions(zone id: Int) async throws -> [Pavilion] { try await c.call("GET", "/pavilion/zone/\(id)", auth: false) }
    static func searchPavilions(_ name: String) async throws -> [Pavilion] { try await c.call("GET", "/pavilion/search/\(encodePath(name))", auth: false) }
    static func topRated() async throws -> [Pavilion] { try await c.call("GET", "/pavilion/top-rated", auth: false) }
    static func accessiblePavilions(_ needs: [String]) async throws -> [Pavilion] { try await c.call("GET", "/pavilion/accessible/\(needs.joined(separator: ","))", auth: false) }
    static func unvisited() async throws -> [Pavilion] { try await c.call("GET", "/pavilion/unvisited") }
    static func paths() async throws -> [PathDTO] { try await c.call("GET", "/path/get", auth: false) }
    static func shortest(from: Int, to: Int) async throws -> ShortestPath { try await c.call("GET", "/path/shortest/\(from)/\(to)", auth: false) }
    static func shortestAccessible(from: Int, to: Int) async throws -> ShortestPath { try await c.call("GET", "/path/shortest-accessible/\(from)/\(to)", auth: false) }
    static func averageRating(_ pavilionId: Int) async throws -> Double { try await c.call("GET", "/review/pavilion/\(pavilionId)/average", auth: false) }
    static func latestReviews(_ pavilionId: Int) async throws -> [ReviewDTO] { try await c.call("GET", "/review/pavilion/\(pavilionId)/latest", auth: false) }

    // ===== crowd =====
    static func crowdNow() async throws -> [CrowdStatus] { try await c.call("GET", "/crowd/now", auth: false) }
    static func pavilionCrowd(_ id: Int) async throws -> CrowdPavilion { try await c.call("GET", "/crowd/pavilion/\(id)", auth: false) }
    static func myCrowdAlerts() async throws -> [CrowdAlert] { try await c.call("GET", "/crowd/alerts/my") }
    static func acceptCrowdAlert(_ alertId: Int) async throws -> Roadmap { try await c.call("POST", "/crowd/alerts/\(alertId)/accept") }

    // ===== roadmaps =====
    static func myRoadmaps() async throws -> [Roadmap] { try await c.call("GET", "/roadmap/getMyRoadmaps") }
    static func generate(_ body: GenerateRoadmapRequest) async throws -> Roadmap { try await c.call("POST", "/roadmap/generate", body: body) }
    static func roadmap(_ id: Int) async throws -> Roadmap { try await c.call("GET", "/roadmap/getStops/\(id)") }
    static func changeEntrance(_ roadmapId: Int, _ entranceId: Int) async throws -> Roadmap { try await c.call("PUT", "/roadmap/changeEntrance/\(roadmapId)/\(entranceId)") }
    static func addStop(_ roadmapId: Int, _ pavilionId: Int, _ position: Int) async throws -> Roadmap { try await c.call("POST", "/roadmap/addStop/\(roadmapId)/\(pavilionId)/\(position)") }
    static func removeStop(_ roadmapId: Int, _ visitId: Int) async throws -> Roadmap { try await c.call("DELETE", "/roadmap/removeStop/\(roadmapId)/\(visitId)") }
    static func reorder(_ roadmapId: Int, _ visitIds: [Int]) async throws -> Roadmap { try await c.call("PUT", "/roadmap/reorder/\(roadmapId)", body: ReorderRequest(visitIds: visitIds)) }
    static func makeDynamic(_ roadmapId: Int) async throws -> Roadmap { try await c.call("PUT", "/roadmap/makeDynamic/\(roadmapId)") }
    static func deleteRoadmap(_ id: Int) async throws { try await c.send("DELETE", "/roadmap/deleteRoadmap/\(id)") }
    static func roadmapPDF(_ id: Int) async throws -> Data { try await c.data("GET", "/roadmap/pdf/\(id)") }
    static func sendPDFToWhatsApp(_ id: Int) async throws -> String? { try await c.send("POST", "/roadmap/sendPdf/\(id)") }
    static func routeFromEntrance(_ roadmapId: Int) async throws -> RoadmapRoute { try await c.call("GET", "/path/roadmap/\(roadmapId)") }

    // ===== find a group =====
    static func shareRoadmap(_ id: Int, _ body: ShareBody) async throws { try await c.send("PUT", "/roadmap/share/\(id)", body: body) }
    static func unshareRoadmap(_ id: Int) async throws { try await c.send("PUT", "/roadmap/unshare/\(id)") }
    static func confirmRoadmap(_ id: Int) async throws { try await c.send("PUT", "/roadmap/confirm/\(id)") }
    static func sharedRoadmaps(date: String, page: Int = 0, size: Int = 15) async throws -> [SharedRoadmap] { try await c.call("GET", "/roadmap/shared?date=\(date)&page=\(page)&size=\(size)") }
    static func copyRoadmap(_ id: Int) async throws -> Roadmap { try await c.call("POST", "/roadmap/copy/\(id)") }
    static func routeFrom(_ roadmapId: Int, location: Int) async throws -> RoadmapRoute { try await c.call("GET", "/path/roadmap/\(roadmapId)/\(location)") }

    // ===== visits and passport =====
    static func checkIn(_ pavilionId: Int) async throws { try await c.send("POST", "/visit/checkIn/\(pavilionId)") }
    static func myPassport() async throws -> Passport { try await c.call("GET", "/passport/getMyPassport") }
    static func myStamps() async throws -> [Stamp] { try await c.call("GET", "/passport/getMyStamps") }

    // ===== reviews =====
    static func addReview(_ pavilionId: Int, _ body: ReviewBody) async throws { try await c.send("POST", "/review/add/\(pavilionId)", body: body) }
    static func updateReview(_ reviewId: Int, _ body: ReviewBody) async throws { try await c.send("PUT", "/review/update/\(reviewId)", body: body) }
    static func deleteReview(_ reviewId: Int) async throws { try await c.send("DELETE", "/review/delete/\(reviewId)") }
    static func pendingReviews() async throws -> [Pavilion] { try await c.call("GET", "/review/getPending") }
    static func myReviews() async throws -> [ReviewDTO] { try await c.call("GET", "/review/getMyReviews") }

    // ===== assistant =====
    static func chatSuggestions() async throws -> ChatSuggestions { try await c.call("GET", "/chatbot/suggestions") }
    static func ask(_ body: ChatRequest) async throws -> ChatAnswer { try await c.call("POST", "/chatbot/ask", body: body) }

    // ===== admin =====
    static func dashboard() async throws -> Dashboard { try await c.call("GET", "/admin/dashboard") }
    static func allVisitors() async throws -> [VisitorInfo] { try await c.call("GET", "/visitor/getAll") }
    static func visitor(_ id: Int) async throws -> VisitorInfo { try await c.call("GET", "/visitor/get/\(id)") }
    static func deleteVisitor(_ id: Int) async throws { try await c.send("DELETE", "/visitor/deleteVisitor/\(id)") }
    static func deleteUser(_ id: Int) async throws { try await c.send("DELETE", "/user/deleteUser/\(id)") }
    static func allRoadmaps() async throws -> [RoadmapRecord] { try await c.call("GET", "/roadmap/getAll") }
    static func allVisits() async throws -> [VisitRecord] { try await c.call("GET", "/visit/getAll") }
    static func allPassports() async throws -> [PassportRecord] { try await c.call("GET", "/passport/getAll") }
    static func allReviews() async throws -> [ReviewDTO] { try await c.call("GET", "/review/get") }

    static func addZone(locationId: Int, _ body: ZoneBody) async throws { try await c.send("POST", "/zone/add/\(locationId)", body: body) }
    static func updateZone(_ id: Int, _ body: ZoneBody) async throws { try await c.send("PUT", "/zone/update/\(id)", body: body) }
    static func deleteZone(_ id: Int) async throws { try await c.send("DELETE", "/zone/delete/\(id)") }

    static func addEntrance(locationId: Int, _ body: EntranceBody) async throws { try await c.send("POST", "/entrance/createEntrance/\(locationId)", body: body) }
    static func updateEntrance(_ id: Int, _ body: EntranceBody) async throws { try await c.send("PUT", "/entrance/updateEntrance/\(id)", body: body) }
    static func deleteEntrance(_ id: Int) async throws { try await c.send("DELETE", "/entrance/deleteEntrance/\(id)") }

    static func addLocation(_ body: LocationBody) async throws { try await c.send("POST", "/location/add", body: body) }
    static func updateLocation(_ id: Int, _ body: LocationBody) async throws { try await c.send("PUT", "/location/update/\(id)", body: body) }
    static func deleteLocation(_ id: Int) async throws { try await c.send("DELETE", "/location/delete/\(id)") }

    static func addPavilion(zoneId: Int, locationId: Int, _ body: PavilionBody) async throws { try await c.send("POST", "/pavilion/add/\(zoneId)/\(locationId)", body: body) }
    static func updatePavilion(_ id: Int, _ body: PavilionBody) async throws { try await c.send("PUT", "/pavilion/update/\(id)", body: body) }
    static func deletePavilion(_ id: Int) async throws { try await c.send("DELETE", "/pavilion/delete/\(id)") }
    static func updatePavilionAccessibility(_ pavilionId: Int, _ need: String, _ body: AccessibilityUpdateBody) async throws { try await c.send("PUT", "/pavilion/accessibility/\(pavilionId)/\(need)", body: body) }

    static func addPath(from: Int, to: Int) async throws { try await c.send("POST", "/path/add/\(from)/\(to)") }
    static func deletePath(_ id: Int) async throws { try await c.send("DELETE", "/path/delete/\(id)") }
    static func updatePathAccessibility(_ id: Int, _ body: PathAccessibilityBody) async throws { try await c.send("PUT", "/path/accessibility/\(id)", body: body) }
    static func generatePaths() async throws -> String? { try await c.send("POST", "/path/generate") }

    static func addInterestItem(_ body: InterestBody) async throws { try await c.send("POST", "/interest/add", body: body) }
    static func updateInterestItem(_ id: Int, _ body: InterestBody) async throws { try await c.send("PUT", "/interest/update/\(id)", body: body) }
    static func deleteInterestItem(_ id: Int) async throws { try await c.send("DELETE", "/interest/delete/\(id)") }

    static func setCrowdFactor(_ value: Int) async throws { try await c.send("PUT", "/crowd/factor/\(value)") }
    static func setManualWait(_ pavilionId: Int, minutes: Int) async throws { try await c.send("PUT", "/crowd/override/\(pavilionId)/\(minutes)") }
    static func setManualWait(_ pavilionId: Int, minutes: Int, duration: Int) async throws { try await c.send("PUT", "/crowd/override/\(pavilionId)/\(minutes)/\(duration)") }
    static func clearManualWait(_ pavilionId: Int) async throws { try await c.send("DELETE", "/crowd/override/\(pavilionId)") }
    static func runCrowdCheck() async throws -> String? { try await c.send("POST", "/crowd/check") }
}
