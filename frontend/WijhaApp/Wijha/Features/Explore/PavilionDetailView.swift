import SwiftUI
import Charts

// DISC-06 / DISC-07 / CHK-01 / REV-04: the pavilion page with accessibility, queue and reviews
struct PavilionDetailView: View {
    let pavilionId: Int
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(ExpoStore.self) private var expo
    @Environment(VisitorStore.self) private var visitor
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var details: PavilionDetails?
    @State private var average: Double?
    @State private var latest: [ReviewDTO] = []
    @State private var crowd: CrowdPavilion?
    @State private var error: String?
    @State private var showAllNeeds = false
    @State private var adding = false

    private var guest: Bool { app.guest }
    private var pavilion: Pavilion? { expo.pavilion(pavilionId) }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero
                    VStack(alignment: .leading, spacing: 18) {
                        if let details {
                            info(details)
                            if let crowd { CrowdCard(crowd: crowd) }
                            accessibilitySection(details)
                            myReviewSection(details)
                            reviewsSection(details)
                        } else if let error {
                            ErrorStateView(message: error) { Task { await load() } }
                        } else {
                            SkeletonList(count: 3, height: 100)
                        }
                    }
                    .padding(.horizontal, Metrics.margin)
                    .padding(.top, 16)
                    .padding(.bottom, 170)
                    .maxContentWidth()
                }
            }
            .ignoresSafeArea(edges: .top)
            .refreshable { await load() }

            bottomBar
        }
        .background(Theme.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            CircleIconButton(icon: "arrow.left", size: 40, flips: true, label: "Back") { dismiss() }
                .padding(.horizontal, 12)
                .padding(.top, 4)
        }
        .sheet(isPresented: $showAllNeeds) {
            if let details { AllNeedsSheet(details: details, tripNeeds: visitor.today?.needs ?? []) }
        }
        .task { await load() }
    }

    // ===== hero image =====
    private var hero: some View {
        ZStack(alignment: .bottom) {
            RemoteImage(url: details?.imageUrl ?? pavilion?.imageUrl, cornerRadius: 0, iconSize: 34)
                .frame(height: 300)
                .frame(maxWidth: .infinity)
                .clipped()
            LinearGradient(colors: [.clear, Theme.canvas.opacity(0.7), Theme.canvas], startPoint: .center, endPoint: .bottom)
                .frame(height: 300)
        }
        .frame(height: 300)
    }

    // ===== name, zone, rating, description =====
    @ViewBuilder
    private func info(_ d: PavilionDetails) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if !guest { PavilionStatusBadge(status: visitor.status(of: pavilionId), compact: false) }
                if let c = expo.crowd[pavilionId] { CrowdBadge(minutes: c.waitMinutes, level: c.level, compact: false) }
            }
            Text(s.pavilionName(d.name))
                .font(WJFont.title1)
                .foregroundStyle(Theme.textPrimary)
            Text(locationLine(d))
                .font(WJFont.footnote)
                .foregroundStyle(Theme.textSecondary)
            HStack(spacing: 8) {
                StarsView(rating: average ?? 0, size: 14)
                Text("\((average ?? 0).oneDecimal) · \(s.t("pavilion.reviewsCount", "\(d.reviews?.count ?? 0)"))")
                    .font(WJFont.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            if let description = d.description, !description.isEmpty {
                Text(description)
                    .font(WJFont.body)
                    .foregroundStyle(Theme.textPrimary.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
    }

    private func locationLine(_ d: PavilionDetails) -> String {
        var parts = [s.zoneTitle(d.zoneName)]
        if !guest, let today = visitor.today, let stop = today.orderedStops.first(where: { $0.pavilionId == pavilionId }) {
            parts.append(s.t("map.stopOf", "\(stop.stopOrder ?? 1)", "\(today.stopsCount)"))
        } else if let country = d.country {
            parts.insert(s.countryName(country), at: 0)
        }
        return parts.joined(separator: " · ")
    }

    // ===== accessibility (trip needs first) =====
    @ViewBuilder
    private func accessibilitySection(_ d: PavilionDetails) -> some View {
        let rows = d.accessibility ?? []
        if !rows.isEmpty {
            let tripNeeds = guest ? [] : (visitor.today?.needs ?? [])
            let first = tripNeeds.isEmpty ? Array(rows.prefix(2)) : rows.filter { tripNeeds.contains($0.needType) }
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(s.t("access.title")).font(WJFont.title3).foregroundStyle(Theme.textPrimary)
                    Spacer()
                    if !tripNeeds.isEmpty {
                        Text(s.t("access.byTripNeeds")).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
                ForEach(first) { row in
                    AccessRowView(row: row)
                    if row.id != first.last?.id { Divider().overlay(Theme.divider) }
                }
                Button {
                    showAllNeeds = true
                } label: {
                    HStack(spacing: 4) {
                        Text(s.t("access.allNeeds", "\(rows.count)"))
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).flipsForRightToLeftLayoutDirection(true)
                    }
                    .font(WJFont.label)
                    .foregroundStyle(Theme.primaryText)
                }
            }
            .card(padding: 16)
        }
    }

    // ===== my review (REV-04) =====
    @ViewBuilder
    private func myReviewSection(_ d: PavilionDetails) -> some View {
        if !guest {
            let myIds = Set(visitor.myReviews.map(\.id))
            if let mine = d.reviews?.first(where: { myIds.contains($0.reviewId) }) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(s.t("review.yours")).font(WJFont.headline).foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Button {
                            router.push(.writeReview(pavilionId: pavilionId, reviewId: mine.reviewId, rating: mine.rating ?? 0))
                        } label: {
                            Image(systemName: "pencil").frame(width: 36, height: 36)
                        }
                        .foregroundStyle(Theme.textSecondary)
                        Button {
                            confirmDelete(mine.reviewId)
                        } label: {
                            Image(systemName: "trash").frame(width: 36, height: 36)
                        }
                        .foregroundStyle(Theme.danger)
                    }
                    StarsView(rating: Double(mine.rating ?? 0), size: 14)
                    if let comment = mine.comment, !comment.isEmpty {
                        Text(comment).font(WJFont.subhead).foregroundStyle(Theme.textPrimary)
                    }
                    Text(DateText.relative(mine.createdAt, s)).font(WJFont.caption).foregroundStyle(Theme.textTertiary)
                }
                .card(padding: 14, stroke: Theme.primary.opacity(0.5))
            }
        }
    }

    // ===== latest reviews =====
    @ViewBuilder
    private func reviewsSection(_ d: PavilionDetails) -> some View {
        let names = Dictionary((d.reviews ?? []).map { ($0.reviewId, $0.visitorName ?? "") }, uniquingKeysWith: { a, _ in a })
        let items = latest.isEmpty ? (d.reviews ?? []).prefix(5).map { ReviewItem(id: $0.reviewId, name: $0.visitorName, rating: $0.rating, comment: $0.comment, date: $0.createdAt) }
            : latest.map { ReviewItem(id: $0.id, name: names[$0.id], rating: $0.rating, comment: $0.comment, date: $0.createdAt) }
        VStack(alignment: .leading, spacing: 12) {
            Text(s.t("pavilion.latestReviews")).font(WJFont.title3).foregroundStyle(Theme.textPrimary)
            if items.isEmpty {
                Text(s.t("pavilion.noReviews")).font(WJFont.subhead).foregroundStyle(Theme.textSecondary)
            }
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.name?.isEmpty == false ? item.name! : s.t("review.visitor"))
                            .font(WJFont.label)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        StarsView(rating: Double(item.rating ?? 0), size: 11)
                    }
                    if let comment = item.comment, !comment.isEmpty {
                        Text(comment).font(WJFont.footnote).foregroundStyle(Theme.textPrimary.opacity(0.9))
                    }
                    Text(DateText.relative(item.date, s)).font(WJFont.caption).foregroundStyle(Theme.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(padding: 14)
            }
        }
    }

    private struct ReviewItem: Identifiable {
        let id: Int
        let name: String?
        let rating: Int?
        let comment: String?
        let date: String?
    }

    // ===== bottom actions (variants by visit state) =====
    private var bottomBar: some View {
        VStack(spacing: 10) {
            if guest {
                Text(s.t("pavilion.guestHint")).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                Button(s.t("pavilion.signInToPlan")) { app.signInPrompt = s.t("guest.promptPavilion", s.pavilionName(pavilion?.name)) }
                    .buttonStyle(.wjPrimary)
                Button { router.push(.directions(pavilionId), guest: true) } label: { Label(s.t("pavilion.showOnMap"), systemImage: "mappin.and.ellipse") }
                    .buttonStyle(.wjSecondary)
            } else {
                // the backend allows one check-in per pavilion per day: a pavilion visited on an earlier day
                // (reviewed or not) can be checked in again today and gets another stamp
                let visitedToday = visitor.todayVisitedIds.contains(pavilionId)
                let status = visitor.status(of: pavilionId)
                if visitedToday && status == .visited {
                    Button {
                        router.push(.writeReview(pavilionId: pavilionId, reviewId: nil, rating: 0))
                    } label: { Label(s.t("pavilion.rateVisit"), systemImage: "star") }
                        .buttonStyle(.wjPrimary)
                } else if visitedToday {
                    Button {
                        router.open(.passport)
                    } label: { Label(s.t("pavilion.showStamp"), systemImage: "seal") }
                        .buttonStyle(.wjPrimary)
                } else {
                    Text(s.t(status == .reviewed || status == .visited ? "checkin.hintAgain" : "checkin.hint"))
                        .font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                    Button {
                        if let pavilion { router.checkIn = pavilion }
                    } label: { Label(s.t("checkin.button"), systemImage: "seal") }
                        .buttonStyle(.wjPrimary)
                    if status == .reviewed {
                        Button {
                            router.open(.passport)
                        } label: { Label(s.t("pavilion.showStamp"), systemImage: "seal") }
                            .buttonStyle(.wjSecondary)
                    }
                }
                HStack(spacing: 10) {
                    Button { router.push(.directions(pavilionId)) } label: { Label(s.t("map.directions"), systemImage: "location.north.line") }
                        .buttonStyle(.wj(.secondary, height: 46))
                    if let today = visitor.today, !visitor.todayPlanIds.contains(pavilionId), !visitedToday {
                        Button {
                            Task { await add(today) }
                        } label: {
                            HStack { if adding { ProgressView() } else { Image(systemName: "plus") }; Text(s.t("pavilion.addToPlan")) }
                        }
                        .buttonStyle(.wj(.secondary, height: 46))
                        .disabled(adding)
                    }
                }
            }
        }
        .padding(.horizontal, Metrics.margin)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(
            LinearGradient(colors: [Theme.canvas.opacity(0), Theme.canvas.opacity(0.95), Theme.canvas], startPoint: .top, endPoint: .center)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // ===== data =====
    private func load() async {
        await expo.load()
        async let d = API.pavilionDetails(pavilionId)
        async let a = try? API.averageRating(pavilionId)
        async let l = try? API.latestReviews(pavilionId)
        async let c = try? API.pavilionCrowd(pavilionId)
        do {
            details = try await d
            error = nil
        } catch {
            if details == nil { self.error = AppState.message(error, s) }
        }
        average = await a
        latest = await l ?? []
        crowd = await c
    }

    private func add(_ today: Roadmap) async {
        if let pavilion, !today.needs.isEmpty && !pavilion.suits(today.needs) {
            app.ask(DialogModel(icon: "exclamationmark.triangle.fill", tone: .warning, title: s.t("edit.unsuitableTitle"),
                                message: s.t("edit.unsuitable"), primary: s.t("common.ok"), onPrimary: {}))
            return
        }
        adding = true
        defer { adding = false }
        do {
            let updated = try await API.addStop(today.roadmapId, pavilionId, today.stopsCount + 1)
            visitor.replace(updated)
            app.show(s.t("map.added", s.pavilionName(pavilion?.name)))
        } catch {
            app.showError(error, s)
        }
    }

    // OVL-REV-01: delete my review
    private func confirmDelete(_ reviewId: Int) {
        app.ask(DialogModel(icon: "trash", tone: .danger, title: s.t("review.deleteTitle"), message: s.t("review.deleteMessage"),
                            primary: s.t("review.delete"), primaryRole: .destructive, secondary: s.t("common.cancel"), onPrimary: {
            Task {
                do {
                    try await API.deleteReview(reviewId)
                    await visitor.refreshReviews()
                    await load()
                    app.show(s.t("review.deleted"))
                } catch {
                    app.showError(error, s)
                }
            }
        }))
    }
}

// one need: name, official status, note and what visitors said
struct AccessRowView: View {
    let row: PavilionAccessibility
    @Environment(AppSettings.self) private var s

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: AccessNeed.icon(row.needType)).foregroundStyle(Theme.textSecondary).frame(width: 20)
                Text(s.label(row.needType)).font(WJFont.headline).foregroundStyle(Theme.textPrimary)
                Spacer()
                AccessBadge(status: row.status)
            }
            let note = s.isArabic ? (row.noteAr ?? row.note) : (row.note ?? row.noteAr)
            if let note, !note.isEmpty {
                Text(note).font(WJFont.footnote).foregroundStyle(Theme.textSecondary)
            }
            if row.votes > 0 {
                Label(s.t("access.votes", "\(row.suitableCount ?? 0)", "\(row.votes)", s.label(row.needType)), systemImage: "person.2")
                    .font(WJFont.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }
}

// OVL-DISC-01: all six needs
struct AllNeedsSheet: View {
    let details: PavilionDetails
    let tripNeeds: [String]
    @Environment(AppSettings.self) private var s

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SheetHeader(title: s.t("access.sheetTitle", s.pavilionName(details.name)), subtitle: s.t("access.sheetSubtitle"))
                let rows = (details.accessibility ?? []).sorted { a, b in
                    let ia = tripNeeds.contains(a.needType) ? 0 : 1, ib = tripNeeds.contains(b.needType) ? 0 : 1
                    if ia != ib { return ia < ib }
                    return (AccessNeed.all.firstIndex(of: a.needType) ?? 0) < (AccessNeed.all.firstIndex(of: b.needType) ?? 0)
                }
                ForEach(rows) { row in
                    AccessRowView(row: row)
                        .card(padding: 14, stroke: tripNeeds.contains(row.needType) ? Theme.primary.opacity(0.5) : Theme.border)
                }
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.bottom, 20)
        }
        .wjSheet([.large])
    }
}

// the queue now and for the rest of the day (crowd)
struct CrowdCard: View {
    let crowd: CrowdPavilion
    @Environment(AppSettings.self) private var s

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(s.t("crowd.title")).font(WJFont.title3).foregroundStyle(Theme.textPrimary)
                Spacer()
                CrowdBadge(minutes: crowd.waitNow, level: crowd.level, compact: false)
            }
            Text(summary)
                .font(WJFont.footnote)
                .foregroundStyle(Theme.textSecondary)
            let slots = (crowd.slots ?? []).filter { slot in
                guard let m = DateText.minutes(from: slot.time) else { return false }
                let now = Calendar.current.component(.hour, from: Date()) * 60 + Calendar.current.component(.minute, from: Date())
                return m >= now - 15
            }.prefix(16)
            let hasWait = slots.contains { ($0.waitMinutes ?? 0) > 0 }
            if !slots.isEmpty && hasWait {
                Chart(Array(slots)) { slot in
                    BarMark(x: .value("time", slot.time), y: .value("wait", slot.waitMinutes ?? 0))
                        .foregroundStyle(color(slot.level))
                        .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: 1)) { value in
                        if value.index % 4 == 0, let label = value.as(String.self) {
                            AxisValueLabel(label)
                        }
                    }
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 96)
                .environment(\.layoutDirection, .leftToRight)
            }
            HStack(spacing: 14) {
                if let cap = crowd.capacity {
                    Label(s.t("crowd.capacity", "\(cap)"), systemImage: "person.3")
                }
                if let avg = crowd.avgVisitMinutes {
                    Label(s.t("crowd.avgVisit", "\(avg)"), systemImage: "clock")
                }
            }
            .font(WJFont.caption)
            .foregroundStyle(Theme.textTertiary)
        }
        .card(padding: 16)
    }

    private var summary: String {
        if crowd.level == "CALM" { return s.t("crowd.calmNow") }
        if let calm = crowd.calmAt { return s.t("crowd.calmAt", DateText.clock12(calm, s)) }
        return s.t("crowd.staysBusy")
    }

    private func color(_ level: String?) -> Color {
        switch level {
        case "CALM": return Palette.mint500
        case "CROWDED": return Palette.red500
        default: return Palette.amber500
        }
    }
}
