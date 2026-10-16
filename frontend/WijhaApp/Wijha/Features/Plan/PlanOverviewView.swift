import SwiftUI

// PLAN-07 (plan ready) and the plan detail: AI summary, entrance, breaks, ordered stops and exit gate
struct PlanOverviewView: View {
    let roadmapId: Int
    var mode: Mode = .detail
    var onStart: () -> Void = {}

    enum Mode { case ready, detail }

    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(VisitorStore.self) private var visitor
    @Environment(ExpoStore.self) private var expo
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var roadmap: Roadmap?
    @State private var route: RoadmapRoute?
    @State private var loading = true
    @State private var error: String?
    @State private var showActions = false
    @State private var showShare = false
    @State private var showEntrance = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let roadmap {
                        content(roadmap)
                    } else if loading {
                        SkeletonList(count: 4, height: 110)
                    } else if let error {
                        ErrorStateView(message: error) { Task { await load() } }
                    }
                }
                .padding(.horizontal, Metrics.margin)
                .padding(.top, 4)
                .padding(.bottom, 24)
                .maxContentWidth()
            }
            .refreshable { await load() }

            if roadmap != nil {
                Button(action: start) {
                    Label(s.t("plan.startOnMap"), systemImage: "map")
                }
                .buttonStyle(.wjPrimary)
                .padding(.horizontal, Metrics.margin)
                .padding(.vertical, 12)
                .background(Theme.canvas.opacity(0.94))
            }
        }
        .screenBackground()
        .navigationBarBackButtonHidden(mode == .ready)
        .wjTopBar(mode == .ready ? "" : s.t("plan.detailTitle"), showsBack: mode == .detail) {
            if let roadmap {
                HStack(spacing: 2) {
                    CircleIconButton(icon: "square.and.arrow.up", size: 36, filled: false, label: s.t("share.title")) { showShare = true }
                    if !roadmap.isPast {
                        CircleIconButton(icon: "ellipsis", size: 36, filled: false, label: s.t("plans.actions")) { showActions = true }
                    }
                }
            }
        }
        .toolbar {
            if mode == .ready {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark").font(.system(size: 16, weight: .semibold))
                            Text(s.t("plan.yourPlan")).font(WJFont.headline)
                        }
                        .foregroundStyle(Theme.textPrimary)
                    }
                }
            }
        }
        .sheet(isPresented: $showActions) {
            if let roadmap {
                PlanActionsSheet(roadmap: roadmap, onChanged: { updated in
                    self.roadmap = updated
                    Task { await loadRoute() }
                }, onDeleted: {
                    if mode == .ready { dismiss() } else { dismiss() }
                })
                .environment(router)
            }
        }
        .sheet(isPresented: $showShare) {
            if let roadmap { SharePlanSheet(roadmap: roadmap) }
        }
        .sheet(isPresented: $showEntrance) {
            if let roadmap {
                ChangeEntranceSheet(roadmap: roadmap) { updated in
                    self.roadmap = updated
                    Task { await loadRoute() }
                }
            }
        }
        .task { await load() }
    }

    @ViewBuilder
    private func content(_ roadmap: Roadmap) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(mode == .ready ? s.t("plan.readyTitle") : DateText.weekdayDay(roadmap.visitDate, s))
                .font(WJFont.title1)
                .foregroundStyle(Theme.textPrimary)
            Text(metaLine(roadmap))
                .font(WJFont.footnote)
                .foregroundStyle(Theme.textSecondary)
        }

        if roadmap.aiUsed == false {
            InfoNote(text: s.t("plan.generalRoute"), icon: "info.circle", tone: .warning, title: s.t("plan.generalRouteTitle"))
        } else if let summary = roadmap.summary, !summary.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                EyebrowLabel(text: s.t("plan.whyThisPlan"), icon: "sparkle")
                Text(summary)
                    .font(WJFont.subhead)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(padding: 14)
        }

        if !roadmap.needs.isEmpty {
            accessibilityCard(roadmap)
        }

        entranceCard(roadmap)

        if let breaks = roadmap.breaks, !breaks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(s.t("plan.breaks")).font(WJFont.headline).foregroundStyle(Theme.textPrimary)
                ForEach(Array(breaks.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 10) {
                        Image(systemName: breakIcon(item.type))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 22)
                        Text(s.label(item.type)).font(WJFont.subhead.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("\(DateText.clock12(item.time, s)) · \(s.t("common.minutesShort", "\(item.minutes ?? 0)"))")
                            .font(WJFont.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .card(padding: 14)
        }

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(s.t("plan.stopsInOrder")).font(WJFont.title3).foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 4)
                Text(s.t("home.stopsProgress", "\(roadmap.visitedCount)", "\(roadmap.stopsCount)"))
                    .font(WJFont.captionBold)
                    .foregroundStyle(Theme.accent)
            }
            if !roadmap.isPast {
                Button { push(.planEdit(roadmap.roadmapId)) } label: {
                    Label(s.t("plan.editStops"), systemImage: "pencil")
                        .font(WJFont.label)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.wj(.secondary, height: 44))
            }
            let next = roadmap.nextStop?.visitId
            ForEach(Array(roadmap.orderedStops.enumerated()), id: \.element.id) { index, stop in
                Button {
                    if let id = stop.pavilionId { push(.pavilion(id)) }
                } label: {
                    StopRow(stop: stop, number: stop.stopOrder ?? index + 1, isNext: roadmap.isToday && stop.visitId == next)
                }
                .buttonStyle(.plain)
            }
            if let exit = route?.exitEntrance {
                HStack(spacing: 8) {
                    Image(systemName: "door.right.hand.open").foregroundStyle(Theme.warning)
                    Text(s.t("plan.exitFrom", s.entranceName(exit)))
                        .font(WJFont.footnote)
                        .foregroundStyle(Theme.textSecondary)
                    if let distance = route?.totalDistance, distance > 0 {
                        Spacer()
                        Text(s.t("plan.walkTotal", "\(Walk.meters(units: distance))"))
                            .font(WJFont.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func metaLine(_ r: Roadmap) -> String {
        var parts = [DateText.longDay(r.visitDate, s), s.t("plan.pavilionsCount", "\(r.stopsCount)")]
        if let first = r.orderedStops.first?.plannedTime { parts.append(s.t("home.from", DateText.clock12(first, s))) }
        return parts.joined(separator: " · ")
    }

    private func accessibilityCard(_ r: Roadmap) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                NeedIcons(needs: r.needs)
                Text(r.needs.map { s.label($0) }.joined(separator: "، "))
                    .font(WJFont.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            if AccessNeed.needsStepFree(r.needs) {
                if route?.accessibleRoute == true {
                    StatusBadge(text: s.t("plan.stepFreeRoute"), icon: "checkmark", tone: .success)
                } else if route?.accessibleRoute == false {
                    StatusBadge(text: s.t("plan.routeHasStairs"), icon: "exclamationmark.triangle.fill", tone: .warning)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14, fill: Theme.successSoft.opacity(0.5), stroke: Theme.success.opacity(0.3))
    }

    private func entranceCard(_ r: Roadmap) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "door.left.hand.open")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.success)
                .frame(width: 36, height: 36)
                .background(Theme.successSoft, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(s.t("plan.startFrom")).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                Text(s.entranceName(r.entranceName)).font(WJFont.headline).foregroundStyle(Theme.textPrimary)
                Text(r.started ? s.t("plan.entranceLocked") : s.t("plan.entranceNote"))
                    .font(WJFont.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if !r.started && !r.isPast {
                Button(s.t("plan.change")) { showEntrance = true }
                    .font(WJFont.label)
                    .foregroundStyle(Theme.primaryText)
            }
        }
        .card(padding: 14)
    }

    private func breakIcon(_ type: String?) -> String {
        switch type {
        case "PRAYER": return "moon.stars"
        case "MEAL": return "fork.knife"
        case "CHILD_REST": return "heart"
        default: return "clock"
        }
    }

    private func start() {
        guard let roadmap else { return }
        if mode == .ready { onStart() } else { push(.journey(roadmap.roadmapId)) }
    }

    private func push(_ route: Route) {
        if mode == .ready {
            dismiss()
            router.open(.journey, [route])
        } else {
            router.push(route)
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let r = try await API.roadmap(roadmapId)
            roadmap = r
            visitor.replace(r)
            error = nil
        } catch {
            if roadmap == nil { self.error = AppState.message(error, s) }
        }
        await loadRoute()
    }

    private func loadRoute() async {
        route = try? await API.routeFromEntrance(roadmapId)
    }
}

struct PlanDetailView: View {
    let roadmapId: Int
    var body: some View { PlanOverviewView(roadmapId: roadmapId, mode: .detail) }
}

// OVL-PLANS-01: one place for every plan action
struct PlanActionsSheet: View {
    let roadmap: Roadmap
    var onChanged: (Roadmap) -> Void = { _ in }
    var onDeleted: () -> Void = {}

    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(VisitorStore.self) private var visitor
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var showShare = false
    @State private var showGroupShare = false
    @State private var showEntrance = false
    @State private var working = false
    @Environment(GroupShareStore.self) private var group

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SheetHeader(title: s.t("plans.actionsTitle", DateText.weekdayDay(roadmap.visitDate, s)))
                .padding(.bottom, 8)
            row("person.3.fill", group.isShared(roadmap.roadmapId) ? s.t("group.manageShare") : s.t("group.shareTitle"),
                badge: group.isShared(roadmap.roadmapId) ? s.t("group.sharedBadge") : nil) { showGroupShare = true }
            if !roadmap.isPast {
                row("checkmark.seal", s.t("group.confirmPlan"), disabled: confirmed,
                    hint: confirmed ? s.t("group.confirmedHint") : s.t("group.confirmHint")) { confirmPlan() }
            }
            Divider().overlay(Theme.divider).padding(.vertical, 6)
            row("square.and.arrow.up", s.t("share.title")) { showShare = true }
            row("pencil", s.t("plans.edit"), disabled: confirmed, hint: confirmed ? s.t("group.lockedForEdit") : nil) {
                dismiss()
                router.push(.planEdit(roadmap.roadmapId))
            }
            row("arrow.triangle.2.circlepath", s.t("plans.updateRest"), disabled: !PlanMath.canUpdateRest(roadmap, visitor: visitor),
                hint: PlanMath.canUpdateRest(roadmap, visitor: visitor) ? nil : s.t("plans.updateRestHint")) {
                confirmUpdate()
            }
            row("door.left.hand.open", s.t("plans.changeEntrance"), disabled: roadmap.started,
                hint: roadmap.started ? s.t("plan.entranceLocked") : nil) { showEntrance = true }
            Divider().overlay(Theme.divider).padding(.vertical, 6)
            row("trash", s.t("plans.delete"), destructive: true) { confirmDelete() }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Metrics.margin)
        .wjSheet([.height(560), .large])
        .sheet(isPresented: $showShare) { SharePlanSheet(roadmap: roadmap) }
        .sheet(isPresented: $showGroupShare) { GroupShareSheet(roadmap: roadmap) }
        .sheet(isPresented: $showEntrance) {
            ChangeEntranceSheet(roadmap: roadmap) { updated in
                onChanged(updated)
                dismiss()
            }
        }
        .overlay { if working { LoadingView().background(Theme.scrim) } }
    }

    private var confirmed: Bool { group.isConfirmed(roadmap.roadmapId) }

    private func confirmPlan() {
        app.ask(DialogModel(icon: "checkmark.seal.fill", tone: .success, title: s.t("group.confirmTitle"),
                            message: s.t("group.confirmMessage"), primary: s.t("group.confirmNow"),
                            secondary: s.t("common.cancel"), onPrimary: {
            Task {
                working = true
                defer { working = false }
                do {
                    try await API.confirmRoadmap(roadmap.roadmapId)
                    group.setConfirmed(roadmap.roadmapId)
                    app.show(s.t("group.confirmedToast"))
                    dismiss()
                } catch {
                    app.showError(error, s)
                }
            }
        }))
    }

    private func row(_ icon: String, _ title: String, disabled: Bool = false, destructive: Bool = false, hint: String? = nil, badge: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(WJFont.callout.weight(.semibold))
                    if let hint {
                        Text(hint).font(WJFont.caption).foregroundStyle(Theme.textTertiary)
                    }
                }
                Spacer()
                if let badge {
                    StatusBadge(text: badge, tone: .success, compact: true)
                }
            }
            .foregroundStyle(disabled ? Theme.textTertiary : (destructive ? Theme.danger : Theme.textPrimary))
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private func confirmUpdate() {
        app.ask(DialogModel(icon: "arrow.triangle.2.circlepath", tone: .primary, title: s.t("plans.updateTitle"),
                            message: s.t("plans.updateMessage"), primary: s.t("plans.updateConfirm"),
                            secondary: s.t("plans.keepPlan"), onPrimary: {
            Task {
                working = true
                defer { working = false }
                do {
                    let updated = try await API.makeDynamic(roadmap.roadmapId)
                    visitor.replace(updated)
                    onChanged(updated)
                    app.show(s.t("plans.updated"))
                    dismiss()
                } catch {
                    app.showError(error, s)
                }
            }
        }))
    }

    private func confirmDelete() {
        app.ask(DialogModel(icon: "trash", tone: .danger, title: s.t("plans.deleteTitle"), message: s.t("plans.deleteMessage"),
                            primary: s.t("plans.delete"), primaryRole: .destructive, secondary: s.t("common.cancel"), onPrimary: {
            Task {
                do {
                    try await API.deleteRoadmap(roadmap.roadmapId)
                    visitor.roadmaps.removeAll { $0.roadmapId == roadmap.roadmapId }
                    app.show(s.t("plans.deleted"))
                    dismiss()
                    onDeleted()
                } catch {
                    app.showError(error, s)
                }
            }
        }))
    }
}

// OVL-PLANS-03: download / share the PDF, or send it to my WhatsApp
struct SharePlanSheet: View {
    let roadmap: Roadmap
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var pdfURL: URL?
    @State private var loadingPDF = false
    @State private var sending = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SheetHeader(title: s.t("share.title"), subtitle: s.t("share.subtitle"))
            Button {
                Task { await preparePDF() }
            } label: {
                HStack(spacing: 8) {
                    if loadingPDF { ProgressView().tint(.white) } else { Image(systemName: "doc.richtext") }
                    Text(s.t("share.pdf"))
                }
            }
            .buttonStyle(.wjPrimary)
            .disabled(loadingPDF)

            Button {
                Task { await sendWhatsApp() }
            } label: {
                HStack(spacing: 8) {
                    if sending { ProgressView() } else { Image(systemName: "message.fill") }
                    Text(s.t("share.whatsapp"))
                }
            }
            .buttonStyle(.wjSecondary)
            .disabled(sending)

            Text(s.t("share.whatsappHint")).font(WJFont.caption).foregroundStyle(Theme.textTertiary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Metrics.margin)
        .wjSheet([.height(330)])
        .sheet(isPresented: Binding(get: { pdfURL != nil }, set: { if !$0 { pdfURL = nil } })) {
            if let pdfURL { ShareSheet(items: [pdfURL]).presentationDetents([.medium, .large]) }
        }
    }

    private func preparePDF() async {
        loadingPDF = true
        defer { loadingPDF = false }
        do {
            let data = try await API.roadmapPDF(roadmap.roadmapId)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("wijha-\(roadmap.visitDate ?? "plan").pdf")
            try data.write(to: url, options: .atomic)
            pdfURL = url
        } catch {
            app.showError(error, s)
        }
    }

    private func sendWhatsApp() async {
        sending = true
        defer { sending = false }
        do {
            _ = try await API.sendPDFToWhatsApp(roadmap.roadmapId)
            app.show(s.t("share.sent"), icon: "paperplane.fill")
            dismiss()
        } catch {
            app.showError(error, s)
        }
    }
}

// OVL-PLANS-04: change the entrance before the first check-in
struct ChangeEntranceSheet: View {
    let roadmap: Roadmap
    var onChanged: (Roadmap) -> Void
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(ExpoStore.self) private var expo
    @Environment(VisitorStore.self) private var visitor
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Int?
    @State private var saving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SheetHeader(title: s.t("entrance.title"), subtitle: s.t("entrance.subtitle"))
            ForEach(expo.entrances) { gate in
                let on = (selected ?? roadmap.entranceId) == gate.id
                Button {
                    selected = gate.id
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "door.left.hand.open")
                            .foregroundStyle(on ? Theme.success : Theme.textSecondary)
                        Text(s.entranceName(gate.name)).font(WJFont.callout.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                        Spacer()
                        if gate.id == roadmap.entranceId {
                            StatusBadge(text: s.t("entrance.current"), tone: .neutral, compact: true)
                        }
                        Image(systemName: on ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(on ? Theme.primary : Theme.textTertiary)
                    }
                    .padding(14)
                    .background(on ? Theme.primarySoft : Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(on ? Theme.primary : Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            Button {
                Task { await save() }
            } label: {
                HStack { if saving { ProgressView().tint(.white) }; Text(s.t("entrance.save")) }
            }
            .buttonStyle(.wjPrimary)
            .disabled(saving || selected == nil || selected == roadmap.entranceId)
        }
        .padding(.horizontal, Metrics.margin)
        .padding(.bottom, 8)
        .wjSheet([.medium])
    }

    private func save() async {
        guard let selected else { return }
        saving = true
        defer { saving = false }
        do {
            let updated = try await API.changeEntrance(roadmap.roadmapId, selected)
            visitor.replace(updated)
            onChanged(updated)
            app.show(s.t("entrance.changed"))
            dismiss()
        } catch {
            app.showError(error, s)
        }
    }
}
