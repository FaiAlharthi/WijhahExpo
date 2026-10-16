import SwiftUI
import UniformTypeIdentifiers

// PLANS-01: every plan by date (today, upcoming, past)
struct PlansListView: View {
    @Environment(AppSettings.self) private var s
    @Environment(VisitorStore.self) private var visitor
    @Environment(Router.self) private var router
    @State private var actionsFor: Roadmap?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Button { router.push(.findGroup) } label: { findGroupBanner }
                    .buttonStyle(.plain)
                if visitor.roadmaps.isEmpty {
                    if visitor.loading {
                        SkeletonList(count: 3)
                    } else {
                        EmptyStateView(icon: "calendar", title: s.t("plans.emptyTitle"), message: s.t("plans.emptyMessage"),
                                       actionTitle: s.t("home.createPlan")) { router.showWizard = true }
                    }
                } else {
                    if let today = visitor.today {
                        group(s.t("plans.today"), [today])
                    }
                    if !visitor.upcoming.isEmpty {
                        group(s.t("plans.upcoming"), visitor.upcoming)
                    }
                    if !visitor.past.isEmpty {
                        group(s.t("plans.past"), visitor.past)
                    }
                    Button {
                        router.showWizard = true
                    } label: {
                        Label(s.t("plans.newDay"), systemImage: "plus")
                    }
                    .buttonStyle(.wjSecondary)
                }
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.top, 4)
            .padding(.bottom, 24)
            .maxContentWidth()
        }
        .refreshable { await visitor.refreshRoadmaps() }
        .screenBackground()
        .wjTopBar(s.t("plans.title"))
        .sheet(item: $actionsFor) { roadmap in
            PlanActionsSheet(roadmap: roadmap).environment(router)
        }
    }

    // entry to "Find a group"
    private var findGroupBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 20))
                .foregroundStyle(Palette.lime500)
                .frame(width: 46, height: 46)
                .background(Palette.mint900, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(s.t("group.title")).font(WJFont.headline).foregroundStyle(Theme.textPrimary)
                Text(s.t("group.bannerSubtitle")).font(WJFont.caption).foregroundStyle(Theme.textSecondary).lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.forward").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.textTertiary)
                .flipsForRightToLeftLayoutDirection(true)
        }
        .padding(14)
        .background(
            LinearGradient(colors: [Palette.blue700.opacity(0.35), Theme.surface], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous).stroke(Palette.blue500.opacity(0.35), lineWidth: 1))
    }

    private func group(_ title: String, _ plans: [Roadmap]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(WJFont.captionBold)
                .foregroundStyle(Theme.accent)
            ForEach(plans) { plan in
                Button {
                    router.push(plan.isToday ? .journey(plan.roadmapId) : .planDetail(plan.roadmapId))
                } label: {
                    planCard(plan)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func planCard(_ plan: Roadmap) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(DateText.weekdayDay(plan.visitDate, s))
                    .font(WJFont.headline)
                    .foregroundStyle(plan.isPast ? Theme.textSecondary : Theme.textPrimary)
                Text(subtitle(plan))
                    .font(WJFont.caption)
                    .foregroundStyle(Theme.textSecondary)
                HStack(spacing: 6) {
                    if plan.isToday, plan.nextStop != nil {
                        StatusBadge(text: s.t("status.next"), icon: "location.north.fill", tone: .lime, compact: true)
                    } else if plan.isToday || plan.isUpcoming {
                        StatusBadge(text: s.t("status.inPlan"), icon: "point.topleft.down.to.point.bottomright.curvepath", tone: .primary, compact: true)
                    }
                    if plan.aiUsed == false {
                        StatusBadge(text: s.t("plans.generalRoute"), icon: "info.circle", tone: .warning, compact: true)
                    }
                    if !plan.needs.isEmpty { NeedIcons(needs: plan.needs) }
                    if plan.whatsappAlerts == true {
                        Image(systemName: "bell.badge").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            Spacer()
            if plan.isPast {
                Image(systemName: "lock").font(.system(size: 13)).foregroundStyle(Theme.textTertiary)
            } else {
                Button {
                    actionsFor = plan
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
        }
        .card(padding: 14)
    }

    private func subtitle(_ plan: Roadmap) -> String {
        var parts = [s.t("plan.pavilionsCount", "\(plan.stopsCount)")]
        if plan.visitedCount > 0 { parts.append(s.t("plans.visitedCount", "\(plan.visitedCount)")) }
        if let gate = plan.entranceName { parts.append(s.t("plans.fromGate", s.entranceName(gate))) }
        return parts.joined(separator: " · ")
    }
}

// PLANS-02: change the stops that are still ahead (visited stops are locked)
struct PlanEditView: View {
    let roadmapId: Int
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(VisitorStore.self) private var visitor
    @Environment(ExpoStore.self) private var expo
    @Environment(\.dismiss) private var dismiss

    @State private var roadmap: Roadmap?
    @State private var items: [EditItem] = []
    @State private var removed: [Int] = []
    @State private var saving = false
    @State private var addMode: AddMode?
    @State private var dragging: EditItem?

    enum AddMode: String, Identifiable { case list, map; var id: String { rawValue } }

    struct EditItem: Identifiable, Equatable {
        let id: String
        let visitId: Int?
        let pavilionId: Int
        let name: String
        let zone: String?
        let visited: Bool
        var isNew: Bool { visitId == nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let roadmap {
                        Text("\(DateText.weekdayDay(roadmap.visitDate, s)) · \(s.t("plan.pavilionsCount", "\(items.count)"))")
                            .font(WJFont.footnote)
                            .foregroundStyle(Theme.textSecondary)
                        InfoNote(text: s.t("edit.lockedNote"), icon: "lock")
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            row(item, index: index)
                                .opacity(dragging == item ? 0.45 : 1)
                                .onDrag {
                                    guard !item.visited else { return NSItemProvider() }
                                    dragging = item
                                    Haptics.tap()
                                    return NSItemProvider(object: item.id as NSString)
                                }
                                .onDrop(of: [.plainText], delegate: StopReorderDelegate(item: item, items: $items, dragging: $dragging))
                        }
                        HStack(spacing: 10) {
                            Button { addMode = .list } label: { Label(s.t("edit.addFromList"), systemImage: "list.bullet") }
                                .buttonStyle(.wj(.secondary, height: 44))
                            Button { addMode = .map } label: { Label(s.t("edit.addFromMap"), systemImage: "map") }
                                .buttonStyle(.wj(.secondary, height: 44))
                        }
                        .padding(.top, 6)
                    } else {
                        SkeletonList(count: 5, height: 72)
                    }
                }
                .padding(.horizontal, Metrics.margin)
                .padding(.top, 4)
                .padding(.bottom, 24)
                .maxContentWidth()
            }
            VStack(spacing: 6) {
                Text(s.t("edit.routeRecalculated")).font(WJFont.caption).foregroundStyle(Theme.textTertiary)
                Button {
                    Task { await save() }
                } label: {
                    HStack { if saving { ProgressView().tint(.white) }; Text(s.t("edit.save")) }
                }
                .buttonStyle(.wjPrimary)
                .disabled(!hasChanges || saving)
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.vertical, 12)
            .background(Theme.canvas.opacity(0.94))
        }
        .screenBackground()
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { close() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark").font(.system(size: 16, weight: .semibold))
                        Text(s.t("edit.title")).font(WJFont.headline)
                    }
                    .foregroundStyle(Theme.textPrimary)
                }
            }
        }
        .sheet(item: $addMode) { mode in
            if let roadmap {
                AddStopSheet(roadmap: roadmap, mode: mode, existing: Set(items.map(\.pavilionId)), positions: positionOptions) { pavilion, position in
                    insert(pavilion, at: position)
                }
            }
        }
        .task { await load() }
    }

    private var hasChanges: Bool {
        guard let roadmap else { return false }
        let original = roadmap.orderedStops.map { "v\($0.visitId)" }
        return !removed.isEmpty || items.map(\.id) != original
    }

    // "في النهاية" / "بعد البحرين (5)"
    private var positionOptions: [(index: Int, title: String)] {
        let firstFree = (items.lastIndex { $0.visited } ?? -1) + 1
        var options: [(Int, String)] = [(items.count, s.t("edit.atEnd"))]
        for i in stride(from: items.count - 1, through: max(firstFree - 1, 0), by: -1) where i >= 0 {
            options.append((i + 1, s.t("edit.after", s.pavilionName(items[i].name), "\(i + 1)")))
        }
        return options.map { (index: $0.0, title: $0.1) }
    }

    private func row(_ item: EditItem, index: Int) -> some View {
        let firstFree = (items.lastIndex { $0.visited } ?? -1) + 1
        let isNext = !item.visited && index == firstFree
        return HStack(spacing: 10) {
            StopNumber(number: index + 1, state: item.visited ? .locked : (isNext ? .next : .upcoming))
            VStack(alignment: .leading, spacing: 4) {
                Text(s.pavilionName(item.name)).font(WJFont.headline).foregroundStyle(item.visited ? Theme.textSecondary : Theme.textPrimary)
                HStack(spacing: 6) {
                    if item.visited {
                        StatusBadge(text: s.t("edit.visitedLocked"), icon: "lock", tone: .neutral, compact: true)
                    } else if item.isNew {
                        StatusBadge(text: s.t("edit.new"), icon: "plus", tone: .lime, compact: true)
                    } else if isNext {
                        StatusBadge(text: s.t("status.next"), icon: "location.north.fill", tone: .lime, compact: true)
                    } else {
                        StatusBadge(text: s.t("status.inPlan"), icon: "point.topleft.down.to.point.bottomright.curvepath", tone: .primary, compact: true)
                    }
                    Text(s.zoneTitle(item.zone))
                        .font(WJFont.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
            Spacer(minLength: 4)
            if item.visited {
                Image(systemName: "lock").foregroundStyle(Theme.textTertiary)
            } else {
                HStack(spacing: 0) {
                    iconButton("arrow.up", enabled: index > firstFree) { move(index, by: -1) }
                    iconButton("arrow.down", enabled: index < items.count - 1) { move(index, by: 1) }
                    iconButton("trash", enabled: true, tint: Theme.danger) { remove(index) }
                }
            }
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(isNext ? Theme.accent : Theme.border, lineWidth: isNext ? 1.4 : 1))
        .opacity(item.visited ? 0.75 : 1)
    }

    private func iconButton(_ icon: String, enabled: Bool, tint: Color = Theme.textSecondary, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
            Haptics.tap()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(enabled ? tint : Theme.textTertiary.opacity(0.5))
                .frame(width: 36, height: 40)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func move(_ index: Int, by delta: Int) {
        let target = index + delta
        guard items.indices.contains(target), !items[target].visited else { return }
        items.swapAt(index, target)
    }

    private func remove(_ index: Int) {
        let item = items.remove(at: index)
        if let id = item.visitId { removed.append(id) }
    }

    private func insert(_ pavilion: Pavilion, at index: Int) {
        let item = EditItem(id: "n\(pavilion.id)", visitId: nil, pavilionId: pavilion.id, name: pavilion.name,
                            zone: expo.zone(of: pavilion.id)?.name, visited: false)
        withAnimation { items.insert(item, at: min(max(index, 0), items.count)) }
    }

    private func load() async {
        do {
            let r = try await API.roadmap(roadmapId)
            roadmap = r
            items = r.orderedStops.compactMap { stop in
                guard let pid = stop.pavilionId else { return nil }
                return EditItem(id: "v\(stop.visitId)", visitId: stop.visitId, pavilionId: pid, name: stop.pavilionName ?? "",
                                zone: stop.zoneName, visited: stop.visited)
            }
            removed = []
        } catch {
            app.showError(error, s)
        }
    }

    private func close() {
        if hasChanges {
            app.ask(DialogModel(icon: "pencil", tone: .warning, title: s.t("edit.discardTitle"), message: s.t("edit.discardMessage"),
                                primary: s.t("wizard.discard"), primaryRole: .destructive, secondary: s.t("wizard.keepEditing"),
                                onPrimary: { dismiss() }))
        } else {
            dismiss()
        }
    }

    // removeStop → addStop (at the end) → reorder, all with the backend endpoints
    private func save() async {
        guard var current = roadmap else { return }
        saving = true
        defer { saving = false }
        do {
            for visitId in removed {
                current = try await API.removeStop(roadmapId, visitId)
            }
            for item in items where item.isNew {
                current = try await API.addStop(roadmapId, item.pavilionId, current.stopsCount + 1)
            }
            let byPavilion = Dictionary(current.orderedStops.filter { !$0.visited }.compactMap { stop in stop.pavilionId.map { ($0, stop.visitId) } },
                                        uniquingKeysWith: { a, _ in a })
            let order = items.filter { !$0.visited }.compactMap { $0.visitId ?? byPavilion[$0.pavilionId] }
            if !order.isEmpty && order != current.orderedStops.filter({ !$0.visited }).map(\.visitId) {
                current = try await API.reorder(roadmapId, order)
            }
            visitor.replace(current)
            app.show(s.t("edit.saved"))
            dismiss()
        } catch {
            app.showError(error, s)
            await load()
        }
    }
}

// drag a stop with the finger to drop it into a new position (visited/locked stops stay put)
struct StopReorderDelegate: DropDelegate {
    let item: PlanEditView.EditItem
    @Binding var items: [PlanEditView.EditItem]
    @Binding var dragging: PlanEditView.EditItem?

    func dropEntered(info: DropInfo) {
        guard let current = dragging, current != item, !item.visited, !current.visited,
              let from = items.firstIndex(of: current),
              let to = items.firstIndex(of: item) else { return }
        if items[to] != current {
            withAnimation(.snappy) {
                items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            }
        }
    }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool {
        withAnimation(.snappy) { dragging = nil }
        Haptics.tap()
        return true
    }
    func dropExited(info: DropInfo) {}
}

// PLANS-03 + list: pick a pavilion and where to add it
struct AddStopSheet: View {
    let roadmap: Roadmap
    let mode: PlanEditView.AddMode
    let existing: Set<Int>
    let positions: [(index: Int, title: String)]
    let onAdd: (Pavilion, Int) -> Void

    @Environment(AppSettings.self) private var s
    @Environment(ExpoStore.self) private var expo
    @Environment(\.dismiss) private var dismiss
    @State private var picked: Pavilion?
    @State private var position: Int?
    @State private var search = ""
    @State private var zoneFilter: Int?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(s.t("edit.pickPavilion")).font(WJFont.title3).foregroundStyle(Theme.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.textSecondary)
                        .frame(width: 36, height: 36).background(Theme.surfaceSunken, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.top, 20)
            .padding(.bottom, 10)

            if mode == .map {
                ExpoMapView(markers: Dictionary(uniqueKeysWithValues: existing.map { ($0, MapMarkerKind.picked) }),
                            selectedId: picked?.id, tripNeeds: roadmap.needs,
                            onTap: { id in
                                picked = expo.pavilion(id)
                                position = nil
                                Haptics.tap()
                            },
                            onTapEmpty: { picked = nil })
                .frame(maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 12)
            } else {
                listContent
            }

            if let picked {
                pickedPanel(picked)
            }
        }
        .background(Theme.sheet)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }

    private var listContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.textTertiary)
                    TextField(s.t("explore.searchPlaceholder"), text: $search)
                        .font(WJFont.body)
                }
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        WJChip(title: s.t("explore.allZones"), selected: zoneFilter == nil, showsToggleIcon: zoneFilter == nil, compact: true) { zoneFilter = nil }
                        ForEach(expo.zones) { zone in
                            WJChip(title: s.zoneTitle(zone.name), selected: zoneFilter == zone.id, compact: true) { zoneFilter = zone.id }
                        }
                    }
                }
                ForEach(filtered) { pavilion in
                    let inPlan = existing.contains(pavilion.id)
                    Button {
                        picked = pavilion
                        position = nil
                    } label: {
                        PavilionRow(pavilion: pavilion, status: inPlan ? .inPlan : .none,
                                    trailing: .selected(picked?.id == pavilion.id), dimmed: !roadmap.needs.isEmpty && !pavilion.suits(roadmap.needs))
                    }
                    .buttonStyle(.plain)
                    .disabled(inPlan)
                }
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.bottom, 20)
        }
    }

    private var filtered: [Pavilion] {
        var list = expo.pavilions
        if let zoneFilter, let zone = expo.zones.first(where: { $0.id == zoneFilter }) {
            let ids = Set((zone.pavilions ?? []).map(\.id))
            list = list.filter { ids.contains($0.id) }
        }
        let q = search.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(q) || s.pavilionName($0.name).contains(q) || ($0.country ?? "").localizedCaseInsensitiveContains(q) || s.countryName($0.country).contains(q) }
        }
        return list.sorted { s.pavilionName($0.name) < s.pavilionName($1.name) }
    }

    private func pickedPanel(_ pavilion: Pavilion) -> some View {
        let unsuitable = !roadmap.needs.isEmpty && !pavilion.suits(roadmap.needs)
        let inPlan = existing.contains(pavilion.id)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                RemoteImage(url: pavilion.imageUrl, cornerRadius: 12).frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(s.pavilionName(pavilion.name)).font(WJFont.headline).foregroundStyle(Theme.textPrimary)
                    Text("\(s.zoneTitle(expo.zone(of: pavilion.id)?.name)) · \(inPlan ? s.t("status.inPlan") : s.t("edit.notInPlan"))")
                        .font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                }
            }
            if unsuitable {
                InfoNote(text: s.t("edit.unsuitable"), icon: "exclamationmark.triangle.fill", tone: .warning)
            }
            if !inPlan {
                Text(s.t("edit.wherePlace")).font(WJFont.label).foregroundStyle(Theme.textSecondary)
                FlowLayout(spacing: 8) {
                    ForEach(positions, id: \.index) { option in
                        WJChip(title: option.title, selected: (position ?? positions.first?.index) == option.index, compact: true) {
                            position = option.index
                        }
                    }
                }
                Button {
                    onAdd(pavilion, position ?? positions.first?.index ?? 0)
                    dismiss()
                } label: {
                    Label(s.t("edit.addToPlan"), systemImage: "plus")
                }
                .buttonStyle(.wjPrimary)
            }
        }
        .padding(Metrics.margin)
        .background(Theme.surfaceRaised, in: UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24))
        .overlay(alignment: .top) { Rectangle().fill(Theme.border).frame(height: 1) }
    }
}
