import SwiftUI

enum ExploreMode: Hashable { case list, map }

enum ExploreFilter: Hashable {
    case all, topRated, zone(Int), accessible
}

// DISC-01…04, DISC-08: browse pavilions as a list or on the map, guest or signed in
struct ExploreView: View {
    let guest: Bool
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(ExpoStore.self) private var expo
    @Environment(VisitorStore.self) private var visitor
    @Environment(Router.self) private var router

    @State private var mode: ExploreMode = .list
    @State private var filter: ExploreFilter = .all
    @State private var needs: Set<String> = []
    @State private var showNeeds = false
    @State private var crowdLayer = false
    @State private var results: [Pavilion]?
    @State private var loading = false
    @State private var error: String?
    @State private var selected: Int?
    @State private var adding: Int?
    @State private var addTarget: Pavilion?
    @State private var zoomToken = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            if mode == .list {
                list
            } else {
                mapMode
            }
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .modifier(TabBarIf(enabled: !guest))
        .sheet(isPresented: $showNeeds) {
            NeedsFilterSheet(needs: $needs) {
                filter = needs.isEmpty ? .all : .accessible
            }
        }
        .sheet(item: $addTarget) { pav in
            AddToPlanSheet(pavilion: pav).environment(router)
        }
        .task(id: filter) { await loadFilter() }
        .task(id: needs) { if filter == .accessible { await loadFilter() } }
        .task { await expo.load() }
        .onAppear {
            if !guest, filter == .all, needs.isEmpty, let tripNeeds = visitor.today?.needs, !tripNeeds.isEmpty {
                needs = Set(tripNeeds)   // needs pre-fill from today's plan
            }
        }
    }

    // ===== header: title, list / map, guest banner, search, chips =====
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if guest {
                    CircleIconButton(icon: "arrow.left", size: 38, flips: true, label: "Back") { app.guest = false }
                }
                Text(s.t("explore.title")).font(WJFont.title1).foregroundStyle(Theme.textPrimary)
                Spacer()
                SegmentedPill(options: [(ExploreMode.list, s.t("explore.list"), "list.bullet"), (ExploreMode.map, s.t("explore.map"), "map")], selection: $mode)
            }
            if guest {
                InfoNote(text: s.t("guest.banner"), icon: "info.circle", title: s.t("guest.bannerTitle"), actionTitle: s.t("auth.login")) {
                    AuthFlowView.startAt = .login
                    app.guest = false
                }
            }
            if mode == .list {
                Button { router.push(.search, guest: guest) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Theme.textTertiary)
                        Text(s.t("explore.searchPlaceholder")).font(WJFont.body).foregroundStyle(Theme.textTertiary)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.borderStrong, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(s.t("explore.searchPlaceholder"))
            }
            chips
        }
        .padding(.horizontal, Metrics.margin)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                WJChip(title: s.t("explore.topRated"), selected: filter == .topRated, compact: true) {
                    filter = filter == .topRated ? .all : .topRated
                }
                WJChip(title: needs.isEmpty ? s.t("explore.accessibility") : s.t("explore.accessibilityCount", "\(needs.count)"),
                       icon: "figure.roll", selected: filter == .accessible, showsToggleIcon: false, compact: true) {
                    showNeeds = true
                }
                WJChip(title: s.t("explore.crowd"), icon: "person.2.fill", selected: crowdLayer, showsToggleIcon: false, compact: true) {
                    crowdLayer.toggle()
                    if crowdLayer { Task { await expo.loadCrowd() } }
                }
                ForEach(expo.zones) { zone in
                    WJChip(title: s.zoneTitle(zone.name), selected: filter == .zone(zone.id), compact: true) {
                        filter = filter == .zone(zone.id) ? .all : .zone(zone.id)
                    }
                }
            }
            .padding(.horizontal, Metrics.margin)
        }
        .padding(.horizontal, -Metrics.margin)
    }

    // ===== list =====
    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if loading && results == nil {
                    SkeletonList(count: 5)
                } else if let error {
                    ErrorStateView(message: error) { Task { await loadFilter() } }
                } else if filter == .accessible {
                    accessibleSections
                } else if shown.isEmpty {
                    EmptyStateView(icon: "magnifyingglass", title: s.t("explore.noResults"))
                } else {
                    if crowdLayer {
                        Text(s.t("explore.crowdSorted")).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                    }
                    ForEach(shown) { pavilion in row(pavilion) }
                }
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.bottom, 24)
            .maxContentWidth()
        }
        .refreshable {
            await expo.load(force: true)
            await loadFilter()
        }
    }

    // fully accessible first, then partly accessible (backend order)
    @ViewBuilder
    private var accessibleSections: some View {
        let list = results ?? []
        let full = list.filter { $0.fullySuits(Array(needs)) }
        let partial = list.filter { !$0.fullySuits(Array(needs)) }
        HStack {
            NeedIcons(needs: AccessNeed.sorted(Array(needs)))
            Text(AccessNeed.sorted(Array(needs)).map { s.label($0) }.joined(separator: "، "))
                .font(WJFont.caption).foregroundStyle(Theme.textSecondary)
            Spacer()
            Button(s.t("common.change")) { showNeeds = true }.font(WJFont.label).foregroundStyle(Theme.primaryText)
        }
        if list.isEmpty {
            EmptyStateView(icon: "figure.roll", title: s.t("explore.noAccessible"), message: s.t("explore.noAccessibleMessage"))
        }
        if !full.isEmpty {
            Text(s.t("explore.fullyAccessible", "\(full.count)")).font(WJFont.captionBold).foregroundStyle(Theme.success)
            ForEach(full) { pavilion in row(pavilion, accessNeeds: Array(needs)) }
        }
        if !partial.isEmpty {
            Text(s.t("explore.partlyAccessible", "\(partial.count)")).font(WJFont.captionBold).foregroundStyle(Theme.warning).padding(.top, 6)
            ForEach(partial) { pavilion in row(pavilion, accessNeeds: Array(needs)) }
        }
    }

    private func row(_ pavilion: Pavilion, accessNeeds: [String] = []) -> some View {
        let status = guest ? PavilionStatus.none : visitor.status(of: pavilion.id)
        let canAdd = !guest
        return Button {
            router.push(.pavilion(pavilion.id), guest: guest)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                PavilionRow(pavilion: pavilion, status: status, showsCrowd: true, trailing: canAdd ? .add : .chevron) {
                    addTarget = pavilion
                }
                if !accessNeeds.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(AccessNeed.sorted(accessNeeds), id: \.self) { need in
                            let st = pavilion.accessStatus(need)
                            StatusBadge(text: "\(s.label(need)): \(AccessStatus.title(st, s))", icon: AccessStatus.icon(st), tone: AccessStatus.tone(st), compact: true)
                        }
                    }
                    .padding(.top, 6)
                    .padding(.horizontal, 4)
                }
            }
            .overlay {
                if adding == pavilion.id { ProgressView().frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 30) }
            }
        }
        .buttonStyle(.plain)
    }

    private var shown: [Pavilion] {
        let base = results ?? expo.pavilions.sorted { s.pavilionName($0.name) < s.pavilionName($1.name) }
        if crowdLayer {
            return base.sorted { (expo.crowd[$0.id]?.waitMinutes ?? 999) < (expo.crowd[$1.id]?.waitMinutes ?? 999) }
        }
        return base
    }

    // ===== map =====
    // the whole site, with today's plan and visits marked; the pop-up opens over the tapped pavilion
    private var mapMode: some View {
        ZStack(alignment: .top) {
            ExpoMapView(
                markers: exploreMarkers,
                selectedId: selected,
                tripNeeds: filter == .accessible ? Array(needs) : [],
                crowdLayer: crowdLayer,
                insets: EdgeInsets(top: 104, leading: 0, bottom: 0, trailing: 0),
                zoomToken: zoomToken,
                onTap: { id in
                    withAnimation(.spring(duration: 0.3)) { selected = id }
                    Haptics.tap()
                },
                onTapEmpty: { withAnimation { selected = nil } }
            ) { pavilion in
                PavilionPopCard(pavilion: pavilion, roadmap: guest ? nil : visitor.today, adding: adding == pavilion.id,
                                onAdd: { addTarget = pavilion },
                                onDetails: { router.push(.pavilion(pavilion.id), guest: guest) },
                                onClose: { withAnimation { self.selected = nil } })
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 8) {
                        MapStyleSwitch()
                        MapLegend(kind: crowdLayer ? .crowd : (exploreMarkers.isEmpty ? .explore : .plan))
                    }
                    Spacer(minLength: 4)
                    MapZoomControl(zoomIn: { zoomToken += 1 }, zoomOut: { zoomToken -= 1 })
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous))
    }

    // today's plan in lime, today's visits in blue (signed in visitors only)
    private var exploreMarkers: [Int: MapMarkerKind] {
        guard !guest else { return [:] }
        var result: [Int: MapMarkerKind] = [:]
        for id in visitor.todayPlanIds { result[id] = .picked }
        for id in visitor.todayVisitedIds { result[id] = .visitedPlain }
        return result
    }

    // ===== data =====
    private func loadFilter() async {
        error = nil
        switch filter {
        case .all:
            results = nil
        case .topRated:
            loading = true
            defer { loading = false }
            do { results = try await API.topRated() } catch { self.error = AppState.message(error, s) }
        case .zone(let id):
            loading = true
            defer { loading = false }
            do { results = try await API.pavilions(zone: id) } catch { self.error = AppState.message(error, s) }
        case .accessible:
            guard !needs.isEmpty else { results = nil; return }
            loading = true
            defer { loading = false }
            do { results = try await API.accessiblePavilions(AccessNeed.sorted(Array(needs))) } catch { self.error = AppState.message(error, s) }
        }
    }

}

// the bottom navigation only for signed in visitors
struct TabBarIf: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled { content.wjTabBar() } else { content }
    }
}

// DISC-08: filter by accessibility needs (multi select)
struct NeedsFilterSheet: View {
    @Binding var needs: Set<String>
    var onApply: () -> Void
    @Environment(AppSettings.self) private var s
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(title: s.t("explore.needsTitle"), subtitle: s.t("explore.needsSubtitle"))
            VStack(spacing: 8) {
                ForEach(AccessNeed.all, id: \.self) { need in
                    let on = draft.contains(need)
                    Button {
                        if on { draft.remove(need) } else { draft.insert(need) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: AccessNeed.icon(need))
                                .frame(width: 24)
                                .foregroundStyle(on ? Theme.primaryText : Theme.textSecondary)
                            Text(s.label(need)).font(WJFont.callout.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Image(systemName: on ? "checkmark.square.fill" : "square")
                                .foregroundStyle(on ? Theme.primary : Theme.textTertiary)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 50)
                        .background(on ? Theme.primarySoft : Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(on ? Theme.primary.opacity(0.6) : Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                Button(s.t("common.clear")) { draft = [] }
                    .buttonStyle(.wjSecondary)
                Button(s.t("common.apply")) {
                    needs = draft
                    onApply()
                    dismiss()
                }
                .buttonStyle(.wjPrimary)
            }
        }
        .padding(.horizontal, Metrics.margin)
        .padding(.bottom, 8)
        .wjSheet([.large])
        .onAppear { draft = needs }
    }
}

// DISC-05: search by pavilion or country name (Arabic and English)
struct SearchView: View {
    @Environment(AppSettings.self) private var s
    @Environment(VisitorStore.self) private var visitor
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [Pavilion] = []
    @State private var searching = false
    @State private var searched = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.textTertiary)
                    TextField(s.t("explore.searchPlaceholder"), text: $query)
                        .font(WJFont.body)
                        .focused($focused)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                        .onSubmit { s.addRecentSearch(query) }
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textTertiary) }
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(Theme.surface, in: Capsule())
                .overlay(Capsule().stroke(focused ? Theme.accent : Theme.borderStrong, lineWidth: 1.2))
                Button(s.t("common.cancel")) { dismiss() }
                    .font(WJFont.label)
                    .foregroundStyle(Theme.primaryText)
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.vertical, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if query.trimmingCharacters(in: .whitespaces).count < 2 {
                        if !s.recentSearches.isEmpty {
                            Text(s.t("search.recent")).font(WJFont.captionBold).foregroundStyle(Theme.textSecondary)
                            ForEach(s.recentSearches, id: \.self) { item in
                                Button { query = item } label: {
                                    HStack {
                                        Image(systemName: "clock.arrow.circlepath").foregroundStyle(Theme.textTertiary)
                                        Text(item).font(WJFont.callout).foregroundStyle(Theme.textPrimary)
                                        Spacer()
                                    }
                                    .frame(height: 40)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else if searching && results.isEmpty {
                        SkeletonList(count: 3)
                    } else if searched && results.isEmpty {
                        EmptyStateView(icon: "magnifyingglass", title: s.t("explore.noResults"), message: s.t("search.noResultsMessage"))
                    } else {
                        Text(s.t("search.resultsFor", query)).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                        ForEach(results) { pavilion in
                            Button {
                                s.addRecentSearch(query)
                                router.push(.pavilion(pavilion.id), guest: app.guest)
                            } label: {
                                PavilionRow(pavilion: pavilion, status: app.guest ? .none : visitor.status(of: pavilion.id))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, Metrics.margin)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .screenBackground(.none)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { focused = true }
        .task(id: query) {
            let q = query.trimmingCharacters(in: .whitespaces)
            guard q.count >= 2 else { results = []; searched = false; return }
            try? await Task.sleep(for: .milliseconds(300))      // 300 ms debounce
            if Task.isCancelled { return }
            searching = true
            defer { searching = false }
            do {
                // Arabic text is matched to the English country name the backend knows
                if let english = PavilionNames.arabicCountries.first(where: { $0.value.contains(q) || q.contains($0.value) })?.key, q.range(of: "\\p{Arabic}", options: .regularExpression) != nil {
                    results = try await API.searchPavilions(english)
                } else {
                    results = try await API.searchPavilions(q)
                }
            } catch let e as APIError where e.status == 400 {
                results = []      // "No pavilions found" = empty result, not an error
            } catch {
                results = []
            }
            searched = true
        }
    }
}

// DISC-03: pick which plan to add a pavilion to (a visitor may keep several plans), or open the pavilion
struct AddToPlanSheet: View {
    let pavilion: Pavilion
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(VisitorStore.self) private var visitor
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var working: Int?

    private var plans: [Roadmap] {
        visitor.roadmaps.filter { !$0.isPast }.sorted { ($0.day ?? .distantFuture) < ($1.day ?? .distantFuture) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SheetHeader(title: s.t("addplan.title"), subtitle: s.pavilionName(pavilion.name))

            Button {
                dismiss()
                router.push(.pavilion(pavilion.id))
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "building.columns")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.primaryText)
                        .frame(width: 34, height: 34)
                        .background(Theme.primarySoft, in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.t("addplan.visit")).font(WJFont.callout.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                        Text(s.t("addplan.visitHint")).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .flipsForRightToLeftLayoutDirection(true)
                }
                .padding(12)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Text(s.t("addplan.choosePlan")).font(WJFont.label).foregroundStyle(Theme.textSecondary)

            if plans.isEmpty {
                VStack(spacing: 10) {
                    Text(s.t("addplan.noPlans"))
                        .font(WJFont.subhead)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    Button(s.t("addplan.createPlan")) { dismiss(); router.showWizard = true }
                        .buttonStyle(.wj(.primary, height: 46))
                }
                .padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(plans) { plan in planRow(plan) }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Metrics.margin)
        .padding(.bottom, 8)
        .wjSheet([.medium, .large])
    }

    private func planRow(_ plan: Roadmap) -> some View {
        let already = plan.stops?.contains { $0.pavilionId == pavilion.id } ?? false
        let busy = working == plan.roadmapId
        return Button {
            Task { await add(to: plan) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: plan.isToday ? "calendar.circle.fill" : "calendar")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(plan.isToday ? Theme.accent : Theme.textSecondary)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(DateText.weekdayDay(plan.visitDate, s)).font(WJFont.callout.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                    Text(s.t("plan.pavilionsCount", "\(plan.stopsCount)")).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if busy {
                    ProgressView().tint(Theme.primaryText)
                } else if already {
                    StatusBadge(text: s.t("status.inPlan"), icon: "checkmark", tone: .success, compact: true)
                } else {
                    Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundStyle(Theme.primary)
                }
            }
            .padding(12)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(already ? Theme.success.opacity(0.4) : Theme.border, lineWidth: 1))
            .opacity(already ? 0.7 : 1)
        }
        .buttonStyle(.plain)
        .disabled(already || working != nil)
    }

    private func add(to plan: Roadmap) async {
        // if the pavilion does not fit the trip's needs, let the visitor add it anyway
        if !plan.needs.isEmpty && !pavilion.suits(plan.needs) {
            app.ask(DialogModel(icon: "exclamationmark.triangle.fill", tone: .warning,
                                title: s.t("edit.unsuitableTitle"),
                                message: s.t("addplan.unsuitableAnyway"),
                                primary: s.t("addplan.addAnyway"),
                                secondary: s.t("common.cancel"),
                                onPrimary: { Task { await commitAdd(to: plan) } }))
            return
        }
        await commitAdd(to: plan)
    }

    private func commitAdd(to plan: Roadmap) async {
        working = plan.roadmapId
        defer { working = nil }
        do {
            let updated = try await API.addStop(plan.roadmapId, pavilion.id, plan.stopsCount + 1)
            visitor.replace(updated)
            app.show(s.t("map.added", s.pavilionName(pavilion.name)))
            dismiss()
        } catch {
            app.showError(error, s)
        }
    }
}
