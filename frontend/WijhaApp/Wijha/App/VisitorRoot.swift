import SwiftUI
import Observation

enum VisitorTab: Hashable, CaseIterable {
    case journey, explore, passport, account
}

enum Route: Hashable {
    case pavilion(Int)
    case journey(Int)                 // today's route on the map
    case directions(Int)              // the walk to one pavilion on the map
    case planDetail(Int)              // upcoming or past plan
    case planEdit(Int)
    case plans
    case findGroup
    case search
    case writeReview(pavilionId: Int, reviewId: Int?, rating: Int)
    case assistant
    case crowdAlerts
    case interests
    case accountDetails
    case deleteAccount
    case settings
}

// tabs, navigation stacks and the flows that open on top of everything
@MainActor
@Observable
final class Router {
    var tab: VisitorTab = .journey
    var journeyPath: [Route] = []
    var explorePath: [Route] = []
    var passportPath: [Route] = []
    var accountPath: [Route] = []
    var guestPath: [Route] = []

    var showWizard = false
    var checkIn: Pavilion?
    var stamped: StampedResult?
    var updateRest: Roadmap?          // the "update the rest of my plan" result

    func push(_ route: Route, guest: Bool = false) {
        if guest { guestPath.append(route); return }
        switch tab {
        case .journey: journeyPath.append(route)
        case .explore: explorePath.append(route)
        case .passport: passportPath.append(route)
        case .account: accountPath.append(route)
        }
    }

    func open(_ tab: VisitorTab, _ routes: [Route] = []) {
        self.tab = tab
        switch tab {
        case .journey: journeyPath = routes
        case .explore: explorePath = routes
        case .passport: passportPath = routes
        case .account: accountPath = routes
        }
    }

    func popToRoot() {
        switch tab {
        case .journey: journeyPath = []
        case .explore: explorePath = []
        case .passport: passportPath = []
        case .account: accountPath = []
        }
    }
}

struct StampedResult: Identifiable {
    let id = UUID()
    let pavilion: Pavilion
    let nextStop: RoadmapStop?
}

struct VisitorRootView: View {
    @Environment(AppState.self) private var app
    @Environment(VisitorStore.self) private var visitor
    @Environment(ExpoStore.self) private var expo
    @Environment(AppSettings.self) private var s
    @State private var router = Router()

    var body: some View {
        @Bindable var router = router
        ZStack {
            if app.guest {
                NavigationStack(path: $router.guestPath) {
                    ExploreView(guest: true)
                        .routeDestinations()
                }
            } else {
                stack(.journey, path: $router.journeyPath) { HomeView() }
                stack(.explore, path: $router.explorePath) { ExploreView(guest: false) }
                stack(.passport, path: $router.passportPath) { PassportView() }
                stack(.account, path: $router.accountPath) { AccountView() }
            }
        }
        .environment(router)
        .fullScreenCover(isPresented: $router.showWizard) {
            PlanWizardView()
                .environment(router)
                .environment(\.layoutDirection, s.layoutDirection)
        }
        .sheet(item: $router.checkIn) { pavilion in
            CheckInSheet(pavilion: pavilion)
                .environment(router)
                .environment(\.layoutDirection, s.layoutDirection)
        }
        .fullScreenCover(item: $router.stamped) { result in
            StampCeremonyView(result: result)
                .environment(router)
                .environment(\.layoutDirection, s.layoutDirection)
        }
        .sheet(isPresented: Binding(get: { app.signInPrompt != nil }, set: { if !$0 { app.signInPrompt = nil } })) {
            SignInPromptSheet(reason: app.signInPrompt ?? "")
                .environment(\.layoutDirection, s.layoutDirection)
        }
        .task(id: app.role) {
            if app.role == .visitor && !visitor.loaded {
                await visitor.refreshAll()
            }
        }
    }

    @ViewBuilder
    private func stack<Content: View>(_ tab: VisitorTab, path: Binding<[Route]>, @ViewBuilder content: () -> Content) -> some View {
        let active = router.tab == tab
        NavigationStack(path: path) {
            content()
                .routeDestinations()
        }
        .opacity(active ? 1 : 0)
        .allowsHitTesting(active)
        .accessibilityHidden(!active)
    }
}

extension View {
    func routeDestinations() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .pavilion(let id): PavilionDetailView(pavilionId: id)
            case .journey(let id): JourneyMapView(roadmapId: id)
            case .directions(let id): JourneyMapView(roadmapId: nil, directionsTo: id)
            case .planDetail(let id): PlanDetailView(roadmapId: id)
            case .planEdit(let id): PlanEditView(roadmapId: id)
            case .plans: PlansListView()
            case .findGroup: FindGroupView()
            case .search: SearchView()
            case .writeReview(let pavilionId, let reviewId, let rating): WriteReviewView(pavilionId: pavilionId, reviewId: reviewId, initialRating: rating)
            case .assistant: AssistantView()
            case .crowdAlerts: CrowdAlertsView()
            case .interests: InterestsEditView()
            case .accountDetails: AccountDetailsView()
            case .deleteAccount: DeleteAccountView()
            case .settings: SettingsView()
            }
        }
    }

    // the bottom navigation on root screens (and the journey map)
    func wjTabBar() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) { WJTabBar() }
    }
}

// Bottom navigation: رحلتي · استكشف · جوازي · حسابي (active item on a pill)
struct WJTabBar: View {
    @Environment(Router.self) private var router
    @Environment(AppSettings.self) private var s
    @Environment(VisitorStore.self) private var visitor

    var body: some View {
        HStack(spacing: 0) {
            item(.journey, "tab.journey", "point.topleft.down.to.point.bottomright.curvepath")
            item(.explore, "tab.explore", "safari")
            item(.passport, "tab.passport", "person.text.rectangle")
            item(.account, "tab.account", "person")
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity)
        .background {
            Theme.tabBar
                .overlay(alignment: .top) { Rectangle().fill(Theme.border).frame(height: 0.5) }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func item(_ tab: VisitorTab, _ key: String, _ icon: String) -> some View {
        let on = router.tab == tab
        return Button {
            if router.tab == tab { withAnimation { router.popToRoot() } }
            router.tab = tab
            Haptics.tap()
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if on {
                        Capsule().fill(Theme.tabActivePill).frame(width: 58, height: 30)
                    }
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: on ? .bold : .regular))
                        .foregroundStyle(on ? Theme.textPrimary : Theme.textSecondary)
                    if tab == .passport && !visitor.pending.isEmpty {
                        Circle().fill(Theme.accentFill).frame(width: 7, height: 7).offset(x: 12, y: -9)
                    }
                }
                .frame(height: 30)
                Text(s.t(key))
                    .font(.system(size: 11, weight: on ? .bold : .medium))
                    .foregroundStyle(on ? Theme.textPrimary : Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

// OVL-AUTH-01: a guest tapped something that needs an account
struct SignInPromptSheet: View {
    let reason: String
    @Environment(AppState.self) private var app
    @Environment(AppSettings.self) private var s
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(title: s.t("guest.promptTitle"))
            Text(reason.isEmpty ? s.t("guest.promptMessage") : reason)
                .font(WJFont.subhead)
                .foregroundStyle(Theme.textSecondary)
            VStack(alignment: .leading, spacing: 12) {
                benefit("point.topleft.down.to.point.bottomright.curvepath", s.t("guest.benefitPlan"))
                benefit("person.text.rectangle", s.t("guest.benefitPassport"))
                benefit("star", s.t("guest.benefitReview"))
            }
            .padding(.vertical, 4)
            Spacer(minLength: 0)
            Button(s.t("auth.createAccount")) {
                dismiss()
                app.guest = false
                AuthFlowView.startAt = .signUp
            }
            .buttonStyle(.wjPrimary)
            Button(s.t("auth.login")) {
                dismiss()
                app.guest = false
                AuthFlowView.startAt = .login
            }
            .buttonStyle(.wjSecondary)
        }
        .padding(.horizontal, Metrics.margin)
        .padding(.bottom, 12)
        .wjSheet([.height(440)])
    }

    private func benefit(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            Text(text).font(WJFont.subhead).foregroundStyle(Theme.textPrimary)
        }
    }
}
