import SwiftUI

// JRNY-01…04, JRNY-A1/A2: today's route on the site map, the next stop and pavilion pop-ups.
// With directionsTo it shows the walk to one pavilion (اتجاهات).
//
// Layout: the map fills the whole screen. The controls float on top and the next-stop card
// floats at the bottom; both report their height so the map keeps its camera (and the
// pop-ups) inside the part of the screen they leave free. Nothing overlaps, on any iPhone.
struct JourneyMapView: View {
    let roadmapId: Int?
    var directionsTo: Int? = nil

    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(VisitorStore.self) private var visitor
    @Environment(ExpoStore.self) private var expo
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var roadmap: Roadmap?
    @State private var route: RoadmapRoute?
    @State private var directions: [Int] = []
    @State private var directionsDistance: Double?
    @State private var directionsFrom: String?
    @State private var selected: Int?
    @State private var expanded = true
    @State private var loading = true
    @State private var error: String?
    @State private var showActions = false
    @State private var showShare = false
    @State private var adding = false
    @State private var topHeight: CGFloat = 0
    @State private var bottomHeight: CGFloat = 0
    @State private var playToken = 0
    @State private var recenterToken = 0
    @State private var zoomToken = 0
    private static var playedPlans = Set<Int>()     // the trip plays itself once per plan

    var body: some View {
        let lines = RouteLines.build(route: route, stops: roadmap?.orderedStops ?? [], expo: expo)
        GeometryReader { geo in
        ZStack(alignment: .top) {
            // the map runs under the status bar; the controls below stay in the safe area,
            // so the camera window starts below the status bar and the floating controls
            ExpoMapView(
                markers: markers,
                route: lines,
                directions: directionPoints,
                selectedId: selected ?? directionsTo,
                showsPopup: selected != nil,
                tripNeeds: roadmap?.needs ?? [],
                insets: EdgeInsets(top: geo.safeAreaInsets.top + topHeight + 8, leading: 0, bottom: bottomHeight + 8, trailing: 0),
                focus: focusPoints(lines),
                playToken: playToken,
                recenterToken: recenterToken,
                zoomToken: zoomToken,
                onTap: { id in
                    guard id != directionsTo else { return }
                    withAnimation(.spring(duration: 0.3)) { selected = id }
                    Haptics.tap()
                },
                onTapEmpty: { withAnimation { selected = nil } }
            ) { pavilion in
                PavilionPopCard(pavilion: pavilion, roadmap: roadmap, adding: adding,
                                onAdd: { Task { await add(pavilion) } },
                                onDetails: { router.push(.pavilion(pavilion.id)) },
                                onClose: { withAnimation { self.selected = nil } })
            }
            .ignoresSafeArea(edges: .top)

            // ===== floating controls =====
            VStack(spacing: 10) {
                topBar
                banner
            }
            .padding(.bottom, 6)
            .reportHeight(MapTopInsetKey.self)

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                VStack(spacing: 10) {
                    if loading && roadmap == nil && directionsTo == nil {
                        ProgressView().tint(Theme.primaryText).padding(10)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    if let error {
                        ErrorStateView(message: error) { Task { await load() } }
                            .padding(.horizontal, Metrics.margin)
                    }
                    toolsRow
                    bottomCard
                }
                .padding(.top, 6)
                .padding(.bottom, 8)
                .reportHeight(MapBottomInsetKey.self)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onPreferenceChange(MapTopInsetKey.self) { topHeight = $0 }
        .onPreferenceChange(MapBottomInsetKey.self) { bottomHeight = $0 }
        .background(Theme.mapBase)
        .toolbar(.hidden, for: .navigationBar)
        .modifier(TabBarIf(enabled: !app.guest))
        .sheet(isPresented: $showActions) {
            if let roadmap {
                PlanActionsSheet(roadmap: roadmap, onChanged: { updated in
                    self.roadmap = updated
                    Task { await loadRoute() }
                }, onDeleted: { dismiss() })
                .environment(router)
            }
        }
        .sheet(isPresented: $showShare) {
            if let roadmap { SharePlanSheet(roadmap: roadmap) }
        }
        .task { await load() }
        .onChange(of: visitor.today) { _, new in
            // after a check-in the visited stop turns blue and the walked part extends
            if let new, new.roadmapId == roadmapId, new != roadmap {
                roadmap = new
                Task { await loadRoute() }
            }
        }
    }

    // ===== top bar: back · plan actions · map style =====
    // row 1: back and the plan actions · row 2: the map style switch at full width, never squeezed
    private var topBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                CircleIconButton(icon: "arrow.left", size: 40, flips: true, label: s.t("common.back")) { dismiss() }
                Spacer(minLength: 4)
                if let roadmap {
                    CircleIconButton(icon: "list.bullet.rectangle", size: 40, label: s.t("map.list")) { router.push(.planDetail(roadmap.roadmapId)) }
                    if !roadmap.isPast {
                        CircleIconButton(icon: "pencil", size: 40, label: s.t("plans.edit")) { router.push(.planEdit(roadmap.roadmapId)) }
                    }
                    CircleIconButton(icon: "ellipsis", size: 40, label: s.t("plans.actions")) { showActions = true }
                }
            }
            // map-style switch on one side, the trip play button on the other
            HStack(spacing: 8) {
                MapStyleSwitch()
                Spacer(minLength: 4)
                if directionsTo == nil, (route?.route?.count ?? 0) > 1 {
                    MapPlayButton { playToken += 1 }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    // legend at the bottom edge · zoom + / − on the trailing side (play lives in the top bar)
    @ViewBuilder
    private var toolsRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if directionsTo == nil {
                MapLegend(kind: .route)
            }
            Spacer(minLength: 0)
            MapZoomControl(zoomIn: { zoomToken += 1 }, zoomOut: { zoomToken -= 1 })
        }
        .padding(.horizontal, Metrics.margin)
    }

    // JRNY-A1 / A2: accessible route banners (only for trips with a mobility need)
    @ViewBuilder
    private var banner: some View {
        if let roadmap, AccessNeed.needsStepFree(roadmap.needs), let accessible = route?.accessibleRoute {
            HStack(spacing: 8) {
                Image(systemName: accessible ? "checkmark" : "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .bold))
                Text(accessible ? s.t("map.stepFreeBanner") : s.t("map.stairsBanner"))
                    .font(WJFont.footnote.weight(.semibold))
                    .multilineTextAlignment(.leading)
            }
            .foregroundStyle(accessible ? Theme.success : Theme.warning)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(accessible ? Theme.successSoft : Theme.warningSoft, in: Capsule())
            .overlay(Capsule().stroke((accessible ? Theme.success : Theme.warning).opacity(0.35), lineWidth: 1))
            .padding(.horizontal, Metrics.margin)
        }
    }

    // ===== bottom card =====
    @ViewBuilder
    private var bottomCard: some View {
        if let directionsTo, let pavilion = expo.pavilion(directionsTo) {
            directionsCard(pavilion)
        } else if let roadmap {
            if let next = roadmap.nextStop {
                if expanded && selected == nil {
                    nextStopCard(next, roadmap)
                } else {
                    Button { withAnimation(.spring(duration: 0.3)) { expanded = true; selected = nil } } label: {
                        HStack(spacing: 8) {
                            Text(s.t("status.next")).font(WJFont.captionBold).foregroundStyle(Theme.accent)
                            Text(s.pavilionName(next.pavilionName)).font(WJFont.label).foregroundStyle(Theme.textPrimary)
                            if let time = next.plannedTime {
                                Text("· \(DateText.clock12(time, s))").font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                            }
                            Image(systemName: "chevron.up").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                        .background(.ultraThinMaterial, in: Capsule())
                        .background(Theme.surface.opacity(0.6), in: Capsule())
                        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, Metrics.margin)
                }
            } else if roadmap.isFinished {
                VStack(alignment: .leading, spacing: 8) {
                    Label(s.t("map.finishedTitle"), systemImage: "flag.checkered")
                        .font(WJFont.headline).foregroundStyle(Theme.textPrimary)
                    Text(s.t("plan.exitFrom", s.entranceName(route?.exitEntrance ?? roadmap.entranceName)))
                        .font(WJFont.footnote).foregroundStyle(Theme.textSecondary)
                    Button(s.t("map.openPassport")) { router.tab = .passport }
                        .buttonStyle(.wj(.primary, height: 46))
                }
                .card(padding: 16, fill: Theme.surface)
                .padding(.horizontal, Metrics.margin)
            }
        }
    }

    private func nextStopCard(_ next: RoadmapStop, _ roadmap: Roadmap) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Capsule().fill(Theme.borderStrong).frame(width: 36, height: 5).frame(maxWidth: .infinity)
                .onTapGesture { withAnimation(.spring(duration: 0.3)) { expanded = false } }
            HStack {
                StatusBadge(text: s.t("status.next"), icon: "location.north.fill", tone: .lime, compact: true)
                Spacer()
                if let time = next.plannedTime {
                    Label(s.t("map.expectedAt", DateText.clock12(time, s)), systemImage: "clock")
                        .font(WJFont.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Button {
                if let id = next.pavilionId { router.push(.pavilion(id)) }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(s.pavilionName(next.pavilionName)).font(WJFont.title3).foregroundStyle(Theme.textPrimary)
                        Text("\(s.zoneTitle(next.zoneName)) · \(s.t("map.stopOf", "\(next.stopOrder ?? 1)", "\(roadmap.stopsCount)"))")
                            .font(WJFont.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    RemoteImage(url: next.imageUrl ?? expo.pavilion(next.pavilionId)?.imageUrl, cornerRadius: 12)
                        .frame(width: 48, height: 48)
                }
            }
            .buttonStyle(.plain)
            if let wait = next.expectedWait {
                HStack(spacing: 6) {
                    CrowdBadge(minutes: wait)
                    Text(s.t("map.expectedQueue")).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                }
            }
            if let warnings = next.accessibilityWarnings, !warnings.isEmpty {
                AccessWarningStrip(warnings: warnings)
            }
            HStack(spacing: 10) {
                Button {
                    if let p = expo.pavilion(next.pavilionId) { router.checkIn = p }
                } label: {
                    Label(s.t("checkin.button"), systemImage: "seal")
                }
                .buttonStyle(.wj(.primary, height: 46))
                Button {
                    Task { await showDirections(to: next.pavilionId, roadmap: roadmap) }
                } label: {
                    Label(s.t("map.directions"), systemImage: "location.north.line")
                }
                .buttonStyle(.wj(.secondary, height: 46))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background(Theme.surface.opacity(0.85), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.border, lineWidth: 1))
        .padding(.horizontal, 12)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func directionsCard(_ pavilion: Pavilion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                RemoteImage(url: pavilion.imageUrl, cornerRadius: 12).frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(s.pavilionName(pavilion.name)).font(WJFont.headline).foregroundStyle(Theme.textPrimary)
                    if let from = directionsFrom {
                        Label(s.t("map.fromCurrent", from), systemImage: "location.fill")
                            .font(WJFont.caption)
                            .foregroundStyle(Color(hex: 0x12C4DE))
                            .lineLimit(2)
                    }
                }
                Spacer()
                if let d = directionsDistance {
                    Text(s.t("map.meters", "\(Walk.meters(units: d))"))
                        .font(WJFont.label)
                        .foregroundStyle(Theme.accent)
                }
            }
            if directions.isEmpty && !loading {
                Text(s.t("map.noDirections")).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
            }
            Button(s.t("common.details")) { router.push(.pavilion(pavilion.id)) }
                .buttonStyle(.wj(.secondary, height: 44))
        }
        .padding(16)
        .background(Theme.surface.opacity(0.95), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.border, lineWidth: 1))
        .padding(.horizontal, 12)
    }

    // ===== markers, focus and directions for the map =====
    private var markers: [Int: MapMarkerKind] {
        guard let roadmap else { return [:] }
        var result: [Int: MapMarkerKind] = [:]
        let next = roadmap.nextStop?.visitId
        for (index, stop) in roadmap.orderedStops.enumerated() {
            guard let pid = stop.pavilionId else { continue }
            let n = stop.stopOrder ?? index + 1
            if stop.visited { result[pid] = .visited(n) }
            else if stop.visitId == next && roadmap.isToday { result[pid] = .next(n) }
            else { result[pid] = .upcoming(n) }
        }
        return result
    }

    // the leg the camera opens on: your last visited stop (or the gate) and the next two stops;
    // with directions, the whole walk to the pavilion
    private func focusPoints(_ lines: RouteLines) -> [CGPoint] {
        if directionsTo != nil {
            let pts = directionPoints
            if !pts.isEmpty { return pts }
            if let loc = expo.pavilion(directionsTo)?.location { return [CGPoint(x: loc.x, y: loc.y)] }
            return []
        }
        guard let roadmap else { return [] }
        let stops = roadmap.orderedStops
        var pts: [CGPoint] = []
        if let last = stops.last(where: { $0.visited }), let l = expo.pavilion(last.pavilionId)?.location {
            pts.append(CGPoint(x: l.x, y: l.y))
        } else if let gate = lines.entrance {
            pts.append(gate)
        }
        let upcoming = stops.filter { !$0.visited }.prefix(2)
        for stop in upcoming {
            if let l = expo.pavilion(stop.pavilionId)?.location { pts.append(CGPoint(x: l.x, y: l.y)) }
        }
        if upcoming.isEmpty, let exit = lines.exitGate { pts.append(exit) }
        return pts
    }

    private var directionPoints: [CGPoint] {
        directions.compactMap { expo.location($0) }.map { CGPoint(x: $0.x, y: $0.y) }
    }

    // ===== data =====
    private func load() async {
        loading = true
        defer { loading = false }
        await expo.load()
        if let roadmapId {
            if let cached = visitor.roadmaps.first(where: { $0.roadmapId == roadmapId }) { roadmap = cached }
            do {
                let fresh = try await API.roadmap(roadmapId)
                roadmap = fresh
                visitor.replace(fresh)
                error = nil
            } catch {
                if roadmap == nil { self.error = AppState.message(error, s) }
            }
            await loadRoute()
        }
        if let directionsTo {
            await showDirections(to: directionsTo, roadmap: visitor.today)
        } else if let roadmap, roadmap.isToday, !roadmap.orderedStops.isEmpty, !Self.playedPlans.contains(roadmap.roadmapId) {
            // the first time a plan's map opens, the trip plays itself gate to gate
            Self.playedPlans.insert(roadmap.roadmapId)
            try? await Task.sleep(for: .milliseconds(500))
            playToken += 1
        }
    }

    private func loadRoute() async {
        guard let roadmapId else { return }
        route = try? await API.routeFromEntrance(roadmapId)
    }

    // the walk from the last visited stop (or the entrance) to a pavilion, from the backend shortest path
    private func showDirections(to pavilionId: Int?, roadmap: Roadmap?) async {
        guard let pavilionId, let target = expo.pavilion(pavilionId)?.location?.id else { return }
        var fromId: Int?
        var fromName: String?
        if let roadmap, let last = roadmap.lastVisited, let loc = expo.pavilion(last.pavilionId)?.location?.id {
            fromId = loc
            fromName = s.pavilionName(last.pavilionName)
        } else if let roadmap, let gate = expo.entrances.first(where: { $0.id == roadmap.entranceId }) ?? expo.entrance(named: roadmap.entranceName) {
            fromId = gate.location?.id
            fromName = s.entranceName(gate.name)
        } else if let gate = expo.entrances.first {
            fromId = gate.location?.id
            fromName = s.entranceName(gate.name)
        }
        guard let fromId else { return }
        let stepFree = AccessNeed.needsStepFree(roadmap?.needs ?? [])
        do {
            let path: ShortestPath
            if stepFree {
                path = try await API.shortestAccessible(from: fromId, to: target)
            } else {
                path = try await API.shortest(from: fromId, to: target)
            }
            withAnimation {
                directions = (path.locations ?? []).map(\.id)
                directionsDistance = path.totalDistance
                directionsFrom = fromName
            }
        } catch {
            app.showError(error, s)
        }
    }

    private func add(_ pavilion: Pavilion) async {
        guard let roadmap else { return }
        adding = true
        defer { adding = false }
        do {
            let updated = try await API.addStop(roadmap.roadmapId, pavilion.id, roadmap.stopsCount + 1)
            self.roadmap = updated
            visitor.replace(updated)
            await loadRoute()
            app.show(s.t("map.added", s.pavilionName(pavilion.name)))
            selected = nil
        } catch {
            app.showError(error, s)
        }
    }
}

// OVL-MAP-01: brief card for a tapped pavilion
struct PavilionPopCard: View {
    let pavilion: Pavilion
    let roadmap: Roadmap?
    var adding = false
    let onAdd: () -> Void
    let onDetails: () -> Void
    let onClose: () -> Void

    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(ExpoStore.self) private var expo
    @Environment(VisitorStore.self) private var visitor

    var body: some View {
        let inPlan = roadmap?.stops?.contains { $0.pavilionId == pavilion.id } ?? false
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                RemoteImage(url: pavilion.imageUrl, cornerRadius: 14, iconSize: 22)
                    .frame(height: 110)
                    .frame(maxWidth: .infinity)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(8)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(s.pavilionName(pavilion.name)).font(WJFont.headline).foregroundStyle(Theme.textPrimary)
                HStack(spacing: 6) {
                    Text("\(s.countryName(pavilion.country)) · \(s.zoneTitle(expo.zone(of: pavilion.id)?.name))")
                        .font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                    if app.role == .visitor {
                        if inPlan {
                            StatusBadge(text: s.t("status.inPlan"), tone: .primary, compact: true)
                        } else {
                            StatusBadge(text: s.t("status.notInPlan"), tone: .neutral, compact: true)
                        }
                    }
                    if let c = expo.crowd[pavilion.id] { CrowdBadge(minutes: c.waitMinutes, level: c.level) }
                }
            }
            if let description = pavilion.description {
                Text(description)
                    .font(WJFont.footnote)
                    .foregroundStyle(Theme.textPrimary.opacity(0.85))
                    .lineLimit(3)
            }
            HStack(spacing: 10) {
                if app.role == .visitor, let roadmap, !inPlan, !roadmap.isPast {
                    Button(action: onAdd) {
                        HStack { if adding { ProgressView().tint(.white) } else { Image(systemName: "plus") }; Text(s.t("common.add")) }
                    }
                    .buttonStyle(.wj(.primary, height: 42))
                    .disabled(adding)
                }
                Button(s.t("common.details"), action: onDetails)
                    .buttonStyle(.wj(.secondary, height: 42))
            }
        }
        .padding(12)
        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
    }
}
