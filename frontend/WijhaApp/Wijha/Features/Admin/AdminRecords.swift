import SwiftUI

enum RecordKind: Hashable { case visitors, roadmaps, visits, passports, reviews }

// everything visitors created, plus the visitor accounts
struct AdminRecordsView: View {
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @State private var kind: RecordKind = .visitors
    @State private var visitors: [VisitorInfo] = []
    @State private var roadmaps: [RoadmapRecord] = []
    @State private var visits: [VisitRecord] = []
    @State private var passports: [PassportRecord] = []
    @State private var reviews: [ReviewDTO] = []
    @State private var loading = false
    @State private var error: String?
    @State private var query = ""

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                Text(s.t("admin.records")).font(WJFont.title1).foregroundStyle(Theme.textPrimary).padding(.top, 12)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip(.visitors, "admin.visitors")
                        chip(.roadmaps, "admin.roadmaps")
                        chip(.visits, "admin.visits")
                        chip(.passports, "admin.passports")
                        chip(.reviews, "admin.reviews")
                    }
                    .padding(.horizontal, Metrics.margin)
                }
                .padding(.horizontal, -Metrics.margin)

                if kind == .visitors {
                    TextField(s.t("common.search"), text: $query)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                }

                if loading {
                    SkeletonList(count: 5, height: 70)
                } else if let error {
                    ErrorStateView(message: error) { Task { await load() } }
                } else {
                    switch kind {
                    case .visitors: visitorRows
                    case .roadmaps: roadmapRows
                    case .visits: visitRows
                    case .passports: passportRows
                    case .reviews: reviewRows
                    }
                }
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.bottom, 24)
            .maxContentWidth()
        }
        .refreshable { await load() }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .task(id: kind) { await load() }
    }

    private func chip(_ value: RecordKind, _ key: String) -> some View {
        WJChip(title: s.t(key), selected: kind == value, showsToggleIcon: false, compact: true) { kind = value }
    }

    // ===== visitors =====
    @ViewBuilder
    private var visitorRows: some View {
        let list = visitors.filter { v in
            query.isEmpty || (v.fullName ?? "").localizedCaseInsensitiveContains(query) || (v.username ?? "").localizedCaseInsensitiveContains(query) || (v.email ?? "").localizedCaseInsensitiveContains(query)
        }
        Text(s.t("admin.count", "\(list.count)")).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
        ForEach(list) { v in
            NavigationLink {
                AdminVisitorDetail(visitor: v) { Task { await load() } }
            } label: {
                HStack(spacing: 12) {
                    Text(v.initial)
                        .font(WJFont.headline)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Theme.primary, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(v.fullName ?? "").font(WJFont.subhead.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                        Text("@\(v.username ?? "") · \(v.nationality ?? "")").font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Text(v.passportNumber ?? "").font(WJFont.caption.monospacedDigit()).foregroundStyle(Theme.textTertiary)
                }
                .card(padding: 12)
            }
            .buttonStyle(.plain)
        }
    }

    // ===== roadmaps =====
    @ViewBuilder
    private var roadmapRows: some View {
        Text(s.t("admin.count", "\(roadmaps.count)")).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
        ForEach(roadmaps.sorted { ($0.visitDate ?? "") > ($1.visitDate ?? "") }) { r in
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    if let summary = r.aiSummary, !summary.isEmpty {
                        Text(summary).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                    }
                    ForEach((r.visits ?? []).sorted { ($0.stopOrder ?? 0) < ($1.stopOrder ?? 0) }) { v in visitLine(v) }
                }
                .padding(.top, 8)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("#\(r.id) · \(DateText.weekdayDay(r.visitDate, s))").font(WJFont.subhead.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                    Text([s.label(r.partyType), r.partySize.map { "×\($0)" } ?? "", s.label(r.visitPace), "\(String((r.arrivalTime ?? "").prefix(5)))–\(String((r.departureTime ?? "").prefix(5)))"]
                        .filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                    HStack(spacing: 6) {
                        if let gate = r.entrance?.name { StatusBadge(text: s.entranceName(gate), icon: "door.left.hand.open", tone: .success, compact: true) }
                        if r.whatsappAlerts == true { StatusBadge(text: s.t("admin.alertsOn"), icon: "bell.badge", tone: .warning, compact: true) }
                        if let needs = r.accessibilityNeeds, !needs.isEmpty { NeedIcons(needs: AccessNeed.sorted(needs)) }
                    }
                }
            }
            .tint(Theme.textSecondary)
            .card(padding: 12)
        }
    }

    // ===== visits =====
    @ViewBuilder
    private var visitRows: some View {
        let checked = visits.filter { $0.isVisited ?? false }
        Text(s.t("admin.checkedCount", "\(checked.count)", "\(visits.count)")).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
        ForEach(visits) { v in visitLine(v).card(padding: 12) }
    }

    // ===== passports =====
    @ViewBuilder
    private var passportRows: some View {
        Text(s.t("admin.count", "\(passports.count)")).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
        ForEach(passports) { p in
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    if (p.visits ?? []).isEmpty { Text("—").foregroundStyle(Theme.textSecondary) }
                    ForEach(p.visits ?? []) { v in visitLine(v) }
                }
                .padding(.top, 8)
            } label: {
                HStack {
                    Image(systemName: "person.text.rectangle").foregroundStyle(Theme.accent)
                    Text(p.passportNumber ?? "#\(p.id)").font(WJFont.subhead.monospacedDigit()).foregroundStyle(Theme.textPrimary)
                    Spacer()
                    StatusBadge(text: "\((p.visits ?? []).filter { $0.isVisited ?? false }.count)", icon: "seal.fill", tone: .lime, compact: true)
                }
            }
            .tint(Theme.textSecondary)
            .card(padding: 12)
        }
    }

    // ===== reviews =====
    @ViewBuilder
    private var reviewRows: some View {
        Text(s.t("admin.reviewsHint")).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
        ForEach(reviews.sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }) { review in
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("#\(review.id)").font(WJFont.caption.monospacedDigit()).foregroundStyle(Theme.textTertiary)
                    StarsView(rating: Double(review.rating ?? 0), size: 11)
                    if let verdict = review.accessibilityVerdict {
                        AccessBadge(status: verdict)
                    }
                    Spacer()
                    Button {
                        app.ask(DialogModel(icon: "trash", tone: .danger, title: s.t("review.deleteTitle"), message: s.t("admin.deleteReviewMessage"),
                                            primary: s.t("review.delete"), primaryRole: .destructive, secondary: s.t("common.cancel"), onPrimary: {
                            Task {
                                do { try await API.deleteReview(review.id); await load(); app.show(s.t("review.deleted")) } catch { app.showError(error, s) }
                            }
                        }))
                    } label: { Image(systemName: "trash").foregroundStyle(Theme.danger).frame(width: 34, height: 34) }
                    .buttonStyle(.plain)
                }
                if let comment = review.comment, !comment.isEmpty {
                    Text(comment).font(WJFont.subhead).foregroundStyle(Theme.textPrimary)
                }
                Text(DateText.short(review.createdAt)).font(WJFont.caption).foregroundStyle(Theme.textTertiary)
            }
            .card(padding: 12)
        }
    }

    private func visitLine(_ v: VisitRecord) -> some View {
        HStack {
            Image(systemName: (v.isVisited ?? false) ? "checkmark.seal.fill" : "circle.dashed")
                .foregroundStyle((v.isVisited ?? false) ? Theme.success : Theme.textTertiary)
            Text(s.pavilionName(v.pavilionName)).font(WJFont.subhead).foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(DateText.short(v.visitedAt)).font(WJFont.caption.monospacedDigit()).foregroundStyle(Theme.textSecondary)
        }
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            switch kind {
            case .visitors: visitors = try await API.allVisitors()
            case .roadmaps: roadmaps = try await API.allRoadmaps()
            case .visits: visits = try await API.allVisits()
            case .passports: passports = try await API.allPassports()
            case .reviews: reviews = try await API.allReviews()
            }
        } catch {
            self.error = AppState.message(error, s)
        }
    }
}

struct AdminVisitorDetail: View {
    let visitor: VisitorInfo
    var onDeleted: () -> Void
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var info: VisitorInfo?
    @State private var user: UserInfo?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                let v = info ?? visitor
                VStack(alignment: .leading, spacing: 4) {
                    Text(v.fullName ?? "").font(WJFont.title2).foregroundStyle(Theme.textPrimary)
                    Text("@\(v.username ?? "")").font(WJFont.footnote).foregroundStyle(Theme.textSecondary)
                }
                VStack(spacing: 0) {
                    field(s.t("register.email"), v.email)
                    field(s.t("register.phone"), v.phone)
                    field(s.t("register.age"), v.age.map { "\($0)" })
                    field(s.t("register.gender"), s.label(v.gender))
                    field(s.t("register.nationality"), v.nationality)
                    field(s.t("account.preferredLanguage"), v.preferredLanguage)
                    field(s.t("passport.number"), v.passportNumber)
                    field(s.t("admin.role"), s.label(user?.role ?? "VISITOR"))
                    field(s.t("admin.joined"), DateText.short(v.createdAt))
                }
                .card(padding: 0)
                if let interests = v.interests, !interests.isEmpty {
                    Text(s.t("interests.title")).font(WJFont.headline).foregroundStyle(Theme.textPrimary)
                    FlowLayout(spacing: 6) {
                        ForEach(interests) { i in StatusBadge(text: s.interestName(i), tone: .primary) }
                    }
                }
                Button(s.t("admin.deleteVisitor")) { confirm(user: false) }
                    .buttonStyle(.wjSecondary)
                Button(s.t("admin.deleteUser")) { confirm(user: true) }
                    .buttonStyle(.wjDestructive)
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.bottom, 24)
            .maxContentWidth()
        }
        .screenBackground()
        .wjTopBar(s.t("admin.visitor"))
        .task {
            info = try? await API.visitor(visitor.id)
            user = try? await API.user(visitor.id)    // visitor id = user id
        }
    }

    private func field(_ label: String, _ value: String?) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label).font(WJFont.footnote).foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(value ?? "—").font(WJFont.subhead.weight(.semibold)).foregroundStyle(Theme.textPrimary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            Divider().overlay(Theme.divider)
        }
    }

    private func confirm(user: Bool) {
        app.ask(DialogModel(icon: "trash", tone: .danger, title: s.t(user ? "admin.deleteUser" : "admin.deleteVisitor"),
                            message: s.t(user ? "admin.deleteUserMessage" : "admin.deleteVisitorMessage"),
                            primary: s.t("common.delete"), primaryRole: .destructive, secondary: s.t("common.cancel"), onPrimary: {
            Task {
                do {
                    if user { try await API.deleteUser(visitor.id) } else { try await API.deleteVisitor(visitor.id) }
                    app.show(s.t("admin.deleted"))
                    onDeleted()
                    dismiss()
                } catch { app.showError(error, s) }
            }
        }))
    }
}
