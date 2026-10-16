import SwiftUI
import Observation
import Security

enum UserRole {
    case visitor, admin
}

// a short message at the bottom of the screen (TOAST)
struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    var tone: BadgeTone = .success
    var icon: String = "checkmark.circle.fill"
}

// a centred dialog (320 wide, scrim 60%)
struct DialogModel: Identifiable {
    let id = UUID()
    var icon: String? = nil
    var tone: BadgeTone = .info
    var title: String
    var message: String? = nil
    var primary: String
    var primaryRole: ButtonRole? = nil
    var secondary: String? = nil
    var onPrimary: () -> Void
    var onSecondary: () -> Void = {}
}

// Who is logged in (kept in the Keychain), plus app wide toasts and dialogs
@MainActor
@Observable
final class AppState {
    var role: UserRole?
    var username: String = ""
    var restoring = true
    var guest = false

    var toast: ToastMessage?
    var dialog: DialogModel?
    // the sign in prompt for guests (OVL-AUTH-01)
    var signInPrompt: String?

    var isLoggedIn: Bool { role != nil }

    // checks the saved login when the app starts
    func restore(visitorStore: VisitorStore) async {
        let start = Date()
        let minSplash: TimeInterval = 3.2        // keep the splash on screen a touch longer
        defer {
            let elapsed = Date().timeIntervalSince(start)
            if elapsed < minSplash {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(minSplash - elapsed))
                    restoring = false
                }
            } else {
                restoring = false
            }
        }
        guard let user = Keychain.read("username"), let pass = Keychain.read("password") else { return }
        do {
            try await login(username: user, password: pass, visitorStore: visitorStore)
        } catch let error as APIError where error.isOffline {
            // keep the account, the server is just not reachable now
            APIClient.shared.setCredentials(username: user, password: pass)
            username = user
            role = .visitor
        } catch {
            APIClient.shared.setCredentials(username: nil, password: nil)
        }
    }

    // Basic Auth has no login endpoint: the visitor info answers for visitors, 403 means the account is an admin
    func login(username: String, password: String, visitorStore: VisitorStore) async throws {
        APIClient.shared.setCredentials(username: username, password: password)
        do {
            let info = try await API.myInfo()
            visitorStore.info = info
            role = .visitor
        } catch let error as APIError where error.status == 403 {
            visitorStore.info = nil
            role = .admin
        } catch {
            APIClient.shared.setCredentials(username: nil, password: nil)
            throw error
        }
        guest = false
        self.username = username
        Keychain.save("username", username)
        Keychain.save("password", password)
    }

    // after the password changes in the account screen
    func updateSavedPassword(username: String, password: String) {
        APIClient.shared.setCredentials(username: username, password: password)
        self.username = username
        Keychain.save("username", username)
        Keychain.save("password", password)
    }

    var savedPassword: String? { Keychain.read("password") }

    func logout(visitorStore: VisitorStore) async {
        await API.logout()
        clearSession(visitorStore: visitorStore)
    }

    func clearSession(visitorStore: VisitorStore) {
        APIClient.shared.setCredentials(username: nil, password: nil)
        Keychain.delete("username")
        Keychain.delete("password")
        visitorStore.reset()
        role = nil
        guest = false
        username = ""
    }

    func show(_ text: String, tone: BadgeTone = .success, icon: String = "checkmark.circle.fill") {
        withAnimation(.spring(duration: 0.35)) {
            toast = ToastMessage(text: text, tone: tone, icon: icon)
        }
    }

    func showError(_ error: Error, _ s: AppSettings) {
        show(Self.message(error, s), tone: .danger, icon: "exclamationmark.triangle.fill")
    }

    func ask(_ dialog: DialogModel) {
        withAnimation(.easeOut(duration: 0.2)) { self.dialog = dialog }
    }

    // translated text of a server error
    static func message(_ error: Error, _ s: AppSettings) -> String {
        guard let api = error as? APIError else { return error.localizedDescription }
        switch api.message {
        case "OFFLINE": return s.t("error.offline", APIClient.shared.trimmedBase)
        case "AUTH_FAILED": return s.t("error.auth")
        case "FORBIDDEN": return s.t("error.forbidden")
        default: return ServerMessages.translate(api.message, s)
        }
    }
}

// The few saved values, kept in the Keychain
enum Keychain {
    static func save(_ key: String, _ value: String) {
        let data = Data(value.utf8)
        delete(key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.wijha.expo2030",
            kSecValueData as String: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.wijha.expo2030",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.wijha.expo2030"
        ]
        SecItemDelete(query as CFDictionary)
    }
}
