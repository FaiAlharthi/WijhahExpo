import SwiftUI
import Charts

enum AdminTab: Hashable, CaseIterable { case dashboard, data, crowd, records, account }

// Admin screens in the same style as the visitor app
struct AdminRootView: View {
    @Environment(AppSettings.self) private var s
    @State private var tab: AdminTab = .dashboard

    var body: some View {
        ZStack {
            page(.dashboard) { AdminDashboardView() }
            page(.data) { AdminDataHome() }
            page(.crowd) { AdminCrowdView() }
            page(.records) { AdminRecordsView() }
            page(.account) { AdminAccountView() }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
    }

    @ViewBuilder
    private func page<C: View>(_ value: AdminTab, @ViewBuilder content: () -> C) -> some View {
        let on = tab == value
        NavigationStack { content() }
            .opacity(on ? 1 : 0)
            .allowsHitTesting(on)
            .accessibilityHidden(!on)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            item(.dashboard, "admin.dashboard", "chart.bar.xaxis")
            item(.data, "admin.data", "square.stack.3d.up")
            item(.crowd, "admin.crowd", "person.3")
            item(.records, "admin.records", "list.bullet.rectangle")
            item(.account, "tab.account", "person")
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
        .background {
            Theme.tabBar
                .overlay(alignment: .top) { Rectangle().fill(Theme.border).frame(height: 0.5) }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func item(_ value: AdminTab, _ key: String, _ icon: String) -> some View {
        let on = tab == value
        return Button {
            tab = value
            Haptics.tap()
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if on { Capsule().fill(Theme.tabActivePill).frame(width: 54, height: 30) }
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: on ? .bold : .regular))
                        .foregroundStyle(on ? Theme.textPrimary : Theme.textSecondary)
                }
                .frame(height: 30)
                Text(s.t(key))
                    .font(.system(size: 10.5, weight: on ? .bold : .medium))
                    .foregroundStyle(on ? Theme.textPrimary : Theme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// ===== dashboard =====
struct AdminDashboardView: View {
    @Environment(AppSettings.self) private var s
    @State private var dashboard: Dashboard?
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    WijhaMark(size: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.t("admin.welcome")).font(WJFont.title2).foregroundStyle(Theme.textPrimary)
                        Text(s.t("admin.subtitle")).font(WJFont.footnote).foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.top, 12)

                if loading && dashboard == nil {
                    SkeletonList(count: 4, height: 120)
                } else if let error, dashboard == nil {
                    ErrorStateView(message: error) { Task { await load() } }
                } else if let d = dashboard {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        tile(s.t("admin.totalVisitors"), "\(d.totalVisitors ?? 0)", "person.3.fill", .primary)
                        tile(s.t("admin.totalCheckIns"), "\(d.totalCheckIns ?? 0)", "seal.fill", .success)
                        tile(s.t("admin.totalRoadmaps"), "\(d.totalRoadmaps ?? 0)", "point.topleft.down.to.point.bottomright.curvepath", .lime)
                        tile(s.t("admin.alertsToday"), "\(d.alertsAcceptedToday ?? 0) / \(d.alertsSentToday ?? 0)", "bell.badge.fill", .warning)
                    }

                    crowdCard(d)
                    accessibilityCard(d)

                    chartCard(s.t("admin.visitsPerDay"), d.visitsPerDay ?? []) { items in
                        Chart(items) { item in
                            AreaMark(x: .value("day", String(item.name.suffix(5))), y: .value("visits", item.count))
                                .foregroundStyle(LinearGradient(colors: [Palette.blue500.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom))
                            LineMark(x: .value("day", String(item.name.suffix(5))), y: .value("visits", item.count))
                                .foregroundStyle(Palette.blue400)
                                .interpolationMethod(.catmullRom)
                            PointMark(x: .value("day", String(item.name.suffix(5))), y: .value("visits", item.count))
                                .foregroundStyle(Palette.lime500)
                        }
                    }
                    chartCard(s.t("admin.visitsPerZone"), d.visitsPerZone ?? []) { items in
                        Chart(items) { item in
                            BarMark(x: .value("zone", s.zoneName(item.name)), y: .value("visits", item.count))
                                .foregroundStyle(Palette.blue500.gradient)
                                .cornerRadius(6)
                        }
                    }
                    chartCard(s.t("admin.entrances"), d.entrances ?? []) { items in
                        Chart(items) { item in
                            SectorMark(angle: .value("count", item.count), innerRadius: .ratio(0.58), angularInset: 2)
                                .foregroundStyle(by: .value("gate", s.entranceName(item.name)))
                                .cornerRadius(4)
                        }
                        .chartForegroundStyleScale(range: [Palette.blue500, Palette.lime500, Palette.mint500, Palette.amber500, Palette.blue300])
                    }
                    chartCard(s.t("admin.topInterests"), d.topInterests ?? [], height: CGFloat(max(150, (d.topInterests?.count ?? 0) * 30))) { items in
                        Chart(items) { item in
                            BarMark(x: .value("count", item.count), y: .value("interest", item.name))
                                .foregroundStyle(Palette.lime500.gradient)
                                .cornerRadius(4)
                        }
                    }
                    statList(s.t("admin.mostVisited"), d.mostVisitedPavilions ?? [], icon: "flame.fill") { s.t("admin.visitsUnit", "\($0.visits ?? 0)") }
                    statList(s.t("admin.topRated"), d.topRatedPavilions ?? [], icon: "star.fill") { "★ \(($0.averageRating ?? 0).oneDecimal) (\($0.reviewsCount ?? 0))" }
                    statList(s.t("admin.lowestRated"), d.lowestRatedPavilions ?? [], icon: "exclamationmark.bubble.fill") { "★ \(($0.averageRating ?? 0).oneDecimal) (\($0.reviewsCount ?? 0))" }
                }
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.bottom, 24)
            .maxContentWidth()
        }
        .refreshable { await load() }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
    }

    private func tile(_ title: String, _ value: String, _ icon: String, _ tone: BadgeTone) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tone == .lime ? Theme.accent : tone.foreground)
                .frame(width: 32, height: 32)
                .background((tone == .lime ? Theme.accentSoft : tone.background), in: Circle())
            Text(value).font(WJFont.stat).foregroundStyle(Theme.textPrimary).environment(\.layoutDirection, .leftToRight)
            Text(title).font(WJFont.caption).foregroundStyle(Theme.textSecondary).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }

    private func crowdCard(_ d: Dashboard) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(s.t("admin.crowdedNow"), systemImage: "person.3.fill").font(WJFont.headline).foregroundStyle(Theme.textPrimary)
            let list = d.crowdedNow ?? []
            if list.isEmpty {
                Text(s.t("admin.noCrowd")).font(WJFont.footnote).foregroundStyle(Theme.textSecondary)
            }
            ForEach(list) { item in
                HStack {
                    Text(s.pavilionName(item.pavilionName)).font(WJFont.subhead.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                    if item.manual == true { StatusBadge(text: s.t("admin.manual"), tone: .neutral, compact: true) }
                    Spacer()
                    Text("\(item.expectedPeople ?? 0)/\(item.capacity ?? 0)").font(WJFont.caption.monospacedDigit()).foregroundStyle(Theme.textTertiary)
                    CrowdBadge(minutes: item.waitMinutes, level: item.level)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }

    // trips with needs, which needs, and pavilions whose official data the visitors disagree with
    private func accessibilityCard(_ d: Dashboard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(s.t("admin.accessTitle"), systemImage: "figure.roll").font(WJFont.headline).foregroundStyle(Theme.textPrimary)
                Spacer()
                StatusBadge(text: s.t("admin.tripsWithNeeds", "\(d.roadmapsWithNeeds ?? 0)"), tone: .lime, compact: true)
            }
            let needs = d.accessibilityNeeds ?? []
            if needs.isEmpty {
                Text(s.t("admin.noData")).font(WJFont.footnote).foregroundStyle(Theme.textSecondary)
            } else {
                Chart(needs) { item in
                    BarMark(x: .value("count", item.count), y: .value("need", s.label(item.name)))
                        .foregroundStyle(Palette.mint500.gradient)
                        .cornerRadius(4)
                }
                .frame(height: CGFloat(max(120, needs.count * 30)))
                .environment(\.layoutDirection, .leftToRight)
            }
            Divider().overlay(Theme.divider)
            Text(s.t("admin.conflicts")).font(WJFont.subhead.weight(.bold)).foregroundStyle(Theme.textPrimary)
            let conflicts = d.accessibilityConflicts ?? []
            if conflicts.isEmpty {
                Text(s.t("admin.noConflicts")).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
            }
            ForEach(conflicts) { conflict in
                HStack(spacing: 10) {
                    Image(systemName: AccessNeed.icon(conflict.needType)).foregroundStyle(Theme.danger).frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.pavilionName(conflict.pavilionName)).font(WJFont.subhead.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                        Text("\(s.label(conflict.needType)) · \(s.t("admin.officially")) \(AccessStatus.title(conflict.officialStatus ?? "UNKNOWN", s))")
                            .font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    StatusBadge(text: "\(conflict.notSuitableCount ?? 0)/\(conflict.totalCount ?? 0)", icon: "hand.thumbsdown.fill", tone: .danger, compact: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }

    @ViewBuilder
    private func chartCard<C: View>(_ title: String, _ items: [CountItem], height: CGFloat = 190, @ViewBuilder chart: ([CountItem]) -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(WJFont.headline).foregroundStyle(Theme.textPrimary)
            if items.isEmpty {
                Text(s.t("admin.noData")).font(WJFont.footnote).foregroundStyle(Theme.textSecondary).frame(maxWidth: .infinity, minHeight: 60)
            } else {
                chart(items).frame(height: height).environment(\.layoutDirection, .leftToRight)
            }
        }
        .card(padding: 14)
    }

    private func statList(_ title: String, _ stats: [PavilionStat], icon: String, value: @escaping (PavilionStat) -> String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(WJFont.headline).foregroundStyle(Theme.textPrimary)
            if stats.isEmpty { Text(s.t("admin.noData")).font(WJFont.footnote).foregroundStyle(Theme.textSecondary) }
            ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                HStack(spacing: 10) {
                    Text("\(index + 1)")
                        .font(WJFont.captionBold)
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 24, height: 24)
                        .background(Theme.surfaceRaised, in: Circle())
                    VStack(alignment: .leading, spacing: 1) {
                        Text(s.pavilionName(stat.name)).font(WJFont.subhead.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                        Text(s.zoneTitle(stat.zoneName)).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Text(value(stat)).font(WJFont.caption.monospacedDigit()).foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }

    private func load() async {
        do {
            dashboard = try await API.dashboard()
            error = nil
        } catch {
            self.error = error.text
        }
        loading = false
    }
}

// ===== crowd controls: app factor, manual queue per pavilion, run the alert check =====
struct AdminCrowdView: View {
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(ExpoStore.self) private var expo
    @State private var crowd: [CrowdStatus] = []
    @State private var factor = 4
    @State private var loading = true
    @State private var editing: CrowdStatus?
    @State private var running = false
    @State private var search = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(s.t("admin.crowd")).font(WJFont.title1).foregroundStyle(Theme.textPrimary).padding(.top, 12)

                VStack(alignment: .leading, spacing: 10) {
                    Text(s.t("admin.factorTitle")).font(WJFont.headline).foregroundStyle(Theme.textPrimary)
                    Text(s.t("admin.factorHint")).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                    HStack {
                        SizeStepper(value: $factor, range: 1...20)
                        Spacer()
                        Button(s.t("common.save")) { Task { await saveFactor() } }
                            .buttonStyle(.wj(.primary, height: 40, fullWidth: false))
                    }
                }
                .card(padding: 14)

                VStack(alignment: .leading, spacing: 10) {
                    Text(s.t("admin.checkTitle")).font(WJFont.headline).foregroundStyle(Theme.textPrimary)
                    Text(s.t("admin.checkHint")).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                    Button {
                        Task { await runCheck() }
                    } label: {
                        HStack { if running { ProgressView().tint(.white) } else { Image(systemName: "bell.and.waves.left.and.right") }; Text(s.t("admin.runCheck")) }
                    }
                    .buttonStyle(.wj(.primary, height: 44))
                    .disabled(running)
                }
                .card(padding: 14)

                HStack {
                    Text(s.t("admin.queueNow")).font(WJFont.title3).foregroundStyle(Theme.textPrimary)
                    Spacer()
                    if let updated = expo.crowdUpdated {
                        Text(DateText.timeString(updated)).font(WJFont.caption).foregroundStyle(Theme.textTertiary)
                    }
                }
                TextField(s.t("explore.searchPlaceholder"), text: $search)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                if loading && crowd.isEmpty { SkeletonList(count: 5, height: 60) }
                ForEach(filtered) { item in
                    Button { editing = item } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(s.pavilionName(item.pavilionName)).font(WJFont.subhead.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                                Text(s.t("admin.peopleCapacity", "\(item.expectedPeople ?? 0)", "\(item.capacity ?? 0)"))
                                    .font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            if item.manual == true { StatusBadge(text: s.t("admin.manual"), icon: "hand.raised.fill", tone: .neutral, compact: true) }
                            CrowdBadge(minutes: item.waitMinutes, level: item.level)
                        }
                        .card(padding: 12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.bottom, 24)
            .maxContentWidth()
        }
        .refreshable { await load() }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $editing) { item in
            ManualQueueSheet(item: item) { Task { await load() } }
        }
        .task { await load() }
    }

    private var filtered: [CrowdStatus] {
        let q = search.trimmingCharacters(in: .whitespaces)
        let sorted = crowd.sorted { ($0.waitMinutes ?? 0) > ($1.waitMinutes ?? 0) }
        guard !q.isEmpty else { return sorted }
        return sorted.filter { ($0.pavilionName ?? "").localizedCaseInsensitiveContains(q) || s.pavilionName($0.pavilionName).contains(q) }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        crowd = (try? await API.crowdNow()) ?? crowd
        await expo.loadCrowd()
    }

    private func saveFactor() async {
        do {
            try await API.setCrowdFactor(factor)
            app.show(s.t("admin.factorSaved"))
            await load()
        } catch {
            app.showError(error, s)
        }
    }

    private func runCheck() async {
        running = true
        defer { running = false }
        do {
            let message = try await API.runCrowdCheck()
            app.show(message ?? s.t("common.done"), icon: "bell.fill")
        } catch {
            app.showError(error, s)
        }
    }
}

struct ManualQueueSheet: View {
    let item: CrowdStatus
    var onChange: () -> Void
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var minutes = 15
    @State private var duration = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(title: s.pavilionName(item.pavilionName), subtitle: s.t("admin.manualSubtitle"))
            HStack {
                Text(s.t("admin.queueMinutes")).font(WJFont.subhead.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                Spacer()
                SizeStepper(value: $minutes, range: 0...180)
            }
            HStack {
                Text(s.t("admin.forMinutes")).font(WJFont.subhead.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                Spacer()
                SizeStepper(value: $duration, range: 5...480)
            }
            Spacer(minLength: 0)
            Button(s.t("admin.setManual")) {
                Task {
                    do {
                        if duration == 30 {
                            try await API.setManualWait(item.pavilionId, minutes: minutes)
                        } else {
                            try await API.setManualWait(item.pavilionId, minutes: minutes, duration: duration)
                        }
                        app.show(s.t("admin.manualSet"))
                        onChange()
                        dismiss()
                    } catch { app.showError(error, s) }
                }
            }
            .buttonStyle(.wjPrimary)
            if item.manual == true {
                Button(s.t("admin.clearManual")) {
                    Task {
                        do {
                            try await API.clearManualWait(item.pavilionId)
                            app.show(s.t("admin.manualCleared"))
                            onChange()
                            dismiss()
                        } catch { app.showError(error, s) }
                    }
                }
                .buttonStyle(.wjSecondary)
            }
        }
        .padding(.horizontal, Metrics.margin)
        .padding(.bottom, 8)
        .wjSheet([.height(380)])
        .onAppear { minutes = item.waitMinutes ?? 15 }
    }
}

// ===== admin account =====
struct AdminAccountView: View {
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(VisitorStore.self) private var visitor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    WijhaMark(size: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("@\(app.username)").font(WJFont.title2).foregroundStyle(Theme.textPrimary)
                        StatusBadge(text: s.label("ADMIN"), icon: "shield.lefthalf.filled", tone: .lime, compact: true)
                    }
                }
                .padding(.top, 12)
                NavigationLink {
                    SettingsView()
                } label: {
                    HStack {
                        Label(s.t("settings.title"), systemImage: "gearshape").font(WJFont.callout.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.right").flipsForRightToLeftLayoutDirection(true).foregroundStyle(Theme.textTertiary)
                    }
                    .foregroundStyle(Theme.textPrimary)
                    .card(padding: 14)
                }
                .buttonStyle(.plain)
                Button {
                    app.ask(DialogModel(icon: "rectangle.portrait.and.arrow.right", tone: .primary, title: s.t("account.logoutTitle"),
                                        primary: s.t("account.logout"), primaryRole: .destructive, secondary: s.t("common.cancel"),
                                        onPrimary: { Task { await app.logout(visitorStore: visitor) } }))
                } label: {
                    Label(s.t("account.logout"), systemImage: "rectangle.portrait.and.arrow.right")
                }
                .buttonStyle(.wjSecondary)
            }
            .padding(.horizontal, Metrics.margin)
            .maxContentWidth()
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
    }
}
