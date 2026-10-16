import SwiftUI
import Observation

// ============================================================================
// Find a Group (ابحث عن مجموعة)
//
// A visitor publishes a day plan; others browse the same day's plans, ranked by
// shared interests, and copy one into their own journey. Coordination happens on
// WhatsApp — there are no join requests on the backend, so there are none here.
//
// The backend never tells the owner whether their own plan is shared, confirmed,
// or how many copies it got, so that state is tracked on the device in
// GroupShareStore (see the note there).
// ============================================================================

// MARK: - Local share state (device only)

/// The backend exposes no "is my plan shared / confirmed" read, so we remember what
/// the owner did on THIS device. It survives relaunch (UserDefaults) but not a new
/// device — a deliberate trade-off to avoid changing the backend.
@MainActor
@Observable
final class GroupShareStore {
    struct Share: Codable, Equatable {
        var shared = false
        var note: String? = nil
        var showContact = false
        var audience = "ALL"      // ALL | SAME_GENDER
        var confirmed = false
    }

    private var map: [Int: Share] = [:]
    private let key = "wijha.groupShare.v1"

    init() { load() }

    func share(_ roadmapId: Int) -> Share { map[roadmapId] ?? Share() }
    func isShared(_ roadmapId: Int) -> Bool { map[roadmapId]?.shared == true }
    func isConfirmed(_ roadmapId: Int) -> Bool { map[roadmapId]?.confirmed == true }

    func setShared(_ roadmapId: Int, note: String?, showContact: Bool, audience: String) {
        var s = map[roadmapId] ?? Share()
        s.shared = true
        s.note = note
        s.showContact = showContact
        s.audience = audience
        map[roadmapId] = s
        save()
    }

    func setUnshared(_ roadmapId: Int) {
        guard var s = map[roadmapId] else { return }
        s.shared = false
        s.showContact = false
        map[roadmapId] = s
        save()
    }

    func setConfirmed(_ roadmapId: Int) {
        var s = map[roadmapId] ?? Share()
        s.confirmed = true
        map[roadmapId] = s
        save()
    }

    func forget(_ roadmapId: Int) {
        map[roadmapId] = nil
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Int: Share].self, from: data) else { return }
        map = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Browse

// GRP-01: the day's shared plans, ranked by shared interests
struct FindGroupView: View {
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(VisitorStore.self) private var visitor
    @Environment(Router.self) private var router

    @State private var day = Calendar.current.startOfDay(for: Date())
    @State private var plans: [SharedRoadmap] = []
    @State private var loading = false
    @State private var loadingMore = false
    @State private var reachedEnd = false
    @State private var page = 0
    @State private var error: String?
    @State private var detail: SharedRoadmap?
    private let pageSize = 15

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                Text(s.t("group.browseIntro"))
                    .font(WJFont.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 2)

                daySelector

                if loading && plans.isEmpty {
                    SkeletonList(count: 3)
                } else if let error, plans.isEmpty {
                    ErrorStateView(message: error) { Task { await reload() } }
                } else if plans.isEmpty {
                    emptyState
                } else {
                    ForEach(plans) { plan in
                        Button { detail = plan } label: { SharedPlanCard(plan: plan) }
                            .buttonStyle(.plain)
                    }
                    if loadingMore {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 10)
                    } else if !reachedEnd {
                        Color.clear.frame(height: 1).onAppear { Task { await loadMore() } }
                    }
                }
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.bottom, 28)
            .maxContentWidth()
        }
        .refreshable { await reload() }
        .screenBackground()
        .wjTopBar(s.t("group.title"))
        .sheet(item: $detail) { plan in
            SharedPlanDetailView(plan: plan) { await reload() }
                .environment(router)
        }
        .task(id: day) { await reload() }
    }

    // today plus the next six days, and any day the visitor already has an upcoming plan for
    private var days: [Date] {
        let cal = Calendar.current
        var set = Set<Date>()
        var list: [Date] = []
        for offset in 0..<7 {
            if let d = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: Date())) {
                if set.insert(d).inserted { list.append(d) }
            }
        }
        for plan in visitor.upcoming {
            if let d = plan.day, set.insert(cal.startOfDay(for: d)).inserted { list.append(cal.startOfDay(for: d)) }
        }
        return list.sorted()
    }

    private var daySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(days, id: \.self) { date in
                    let on = Calendar.current.isDate(date, inSameDayAs: day)
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { day = date }
                    } label: {
                        VStack(spacing: 2) {
                            Text(DateText.weekdayShort(date, s)).font(WJFont.micro)
                            Text(DateText.dayNumber(date, s)).font(WJFont.label)
                        }
                        .foregroundStyle(on ? Palette.ink900 : Theme.textPrimary)
                        .frame(width: 52, height: 56)
                        .background(on ? Theme.accentFill : Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(on ? Color.clear : Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3.sequence")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Theme.textTertiary)
            Text(s.t("group.emptyTitle")).font(WJFont.headline).foregroundStyle(Theme.textPrimary)
            Text(s.t("group.emptyMessage")).font(WJFont.footnote).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
            Button(s.t("group.shareMine")) { router.push(.plans) }
                .buttonStyle(.wj(.secondary, height: 44, fullWidth: false))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func reload() async {
        loading = true
        page = 0
        reachedEnd = false
        defer { loading = false }
        do {
            let result = try await API.sharedRoadmaps(date: DateText.dayString(day), page: 0, size: pageSize)
            plans = result
            reachedEnd = result.count < pageSize
            error = nil
        } catch {
            self.error = AppState.message(error, s)
            plans = []
        }
    }

    private func loadMore() async {
        guard !loadingMore, !reachedEnd, !loading else { return }
        loadingMore = true
        defer { loadingMore = false }
        let next = page + 1
        if let result = try? await API.sharedRoadmaps(date: DateText.dayString(day), page: next, size: pageSize) {
            page = next
            plans.append(contentsOf: result)
            reachedEnd = result.count < pageSize
        } else {
            reachedEnd = true
        }
    }
}

// MARK: - Card

// one shared plan in the browse list
struct SharedPlanCard: View {
    let plan: SharedRoadmap
    @Environment(AppSettings.self) private var s

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                GroupAvatar(name: plan.firstName)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(plan.firstName ?? "—").font(WJFont.headline).foregroundStyle(Theme.textPrimary)
                        if plan.locked == true {
                            StatusBadge(text: s.t("group.confirmed"), icon: "checkmark.seal.fill", tone: .success, compact: true)
                        }
                    }
                    if let nationality = plan.nationality, !nationality.isEmpty {
                        Text(s.countryName(nationality)).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                if (plan.commonInterests ?? 0) > 0 {
                    commonPill
                }
            }

            if let note = plan.shareNote, !note.isEmpty {
                Text("“\(note)”")
                    .font(WJFont.subhead)
                    .foregroundStyle(Theme.textPrimary.opacity(0.9))
                    .lineLimit(2)
            }

            if let interests = plan.interests, !interests.isEmpty {
                InterestWrap(interests: interests)
            }

            // stop avatars + meta
            HStack(spacing: 10) {
                StopThumbnails(stops: plan.orderedStops)
                Spacer()
                Text(s.t("plan.pavilionsCount", "\(plan.orderedStops.count)"))
                    .font(WJFont.caption).foregroundStyle(Theme.textSecondary)
            }

            Divider().overlay(Theme.divider)

            HStack(spacing: 10) {
                metaItem("clock", timeRange)
                if let gate = plan.entranceName {
                    metaItem("door.left.hand.open", s.entranceName(gate))
                }
                Spacer()
                if (plan.copyCount ?? 0) > 0 {
                    Label(s.t("group.copies", "\(plan.copyCount ?? 0)"), systemImage: "person.2.fill")
                        .font(WJFont.micro.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .stroke((plan.commonInterests ?? 0) > 0 ? Theme.accent.opacity(0.4) : Theme.border, lineWidth: 1)
        )
    }

    private var commonPill: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles").font(.system(size: 10, weight: .bold))
            Text(s.t("group.commonCount", "\(plan.commonInterests ?? 0)")).font(WJFont.micro.weight(.bold))
        }
        .foregroundStyle(Palette.ink900)
        .padding(.horizontal, 9)
        .frame(height: 24)
        .background(Theme.accentFill, in: Capsule())
    }

    private func metaItem(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.textTertiary)
            Text(text).font(WJFont.caption).foregroundStyle(Theme.textSecondary).lineLimit(1)
        }
    }

    private var timeRange: String {
        let a = DateText.clock12(plan.arrivalTime, s)
        let b = DateText.clock12(plan.departureTime, s)
        if a.isEmpty && b.isEmpty { return DateText.weekdayDay(plan.visitDate, s) }
        return "\(a) – \(b)"
    }
}

// MARK: - Detail

// GRP-02: the full shared plan, with the stops and a way to copy it
struct SharedPlanDetailView: View {
    let plan: SharedRoadmap
    var onCopied: () async -> Void = {}

    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(VisitorStore.self) private var visitor
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var copying = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SheetHeader(title: s.t("group.planOf", plan.firstName ?? "—"))

                // owner
                HStack(spacing: 12) {
                    GroupAvatar(name: plan.firstName, size: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(plan.firstName ?? "—").font(WJFont.title3).foregroundStyle(Theme.textPrimary)
                            if plan.locked == true {
                                StatusBadge(text: s.t("group.confirmed"), icon: "checkmark.seal.fill", tone: .success, compact: true)
                            }
                        }
                        if let nationality = plan.nationality, !nationality.isEmpty {
                            Text(s.countryName(nationality)).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    Spacer()
                    if (plan.copyCount ?? 0) > 0 {
                        VStack(spacing: 1) {
                            Text("\(plan.copyCount ?? 0)").font(WJFont.stat).foregroundStyle(Theme.accent)
                            Text(s.t("group.copiesLabel")).font(WJFont.micro).foregroundStyle(Theme.textTertiary)
                        }
                    }
                }

                if (plan.commonInterests ?? 0) > 0 {
                    InfoNote(text: s.t("group.commonNote", "\(plan.commonInterests ?? 0)"), icon: "sparkles", tone: .lime)
                }

                if let note = plan.shareNote, !note.isEmpty {
                    Text("“\(note)”")
                        .font(WJFont.body)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.surfaceSunken, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                if let interests = plan.interests, !interests.isEmpty {
                    section(s.t("group.interests")) { InterestWrap(interests: interests) }
                }

                // the day
                HStack(spacing: 10) {
                    infoChip("calendar", DateText.weekdayDay(plan.visitDate, s))
                    infoChip("clock", timeRange)
                    if let gate = plan.entranceName { infoChip("door.left.hand.open", s.entranceName(gate)) }
                }

                // stops
                section(s.t("group.stops", "\(plan.orderedStops.count)")) {
                    VStack(spacing: 8) {
                        ForEach(plan.orderedStops) { stop in
                            HStack(spacing: 12) {
                                StopNumber(number: stop.stopOrder ?? 0, state: .upcoming, size: 26)
                                RemoteImage(url: stop.imageUrl, cornerRadius: 10).frame(width: 42, height: 42)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.pavilionName(stop.pavilionName)).font(WJFont.subhead.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                                    Text(s.zoneTitle(stop.zoneName)).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }

                // contact (only if the owner shared their number)
                if let phone = plan.phone, !phone.isEmpty {
                    contactBlock(phone)
                }

                Color.clear.frame(height: 72)
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.top, 4)
        }
        .safeAreaInset(edge: .bottom) { copyBar }
        .wjSheet([.large])
    }

    private var copyBar: some View {
        VStack(spacing: 6) {
            Button {
                Task { await copy() }
            } label: {
                HStack(spacing: 8) {
                    if copying { ProgressView().tint(.white) } else { Image(systemName: "arrow.down.doc") }
                    Text(s.t("group.copyToMine"))
                }
            }
            .buttonStyle(.wjPrimary)
            .disabled(copying)
            Text(s.t("group.copyHint")).font(WJFont.micro).foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, Metrics.margin)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .background(Theme.sheet.opacity(0.9))
        .overlay(alignment: .top) { Rectangle().fill(Theme.border).frame(height: 0.5) }
    }

    private func contactBlock(_ phone: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(s.t("group.contact")).font(WJFont.captionBold).foregroundStyle(Theme.accent)
            Button {
                openWhatsApp(phone)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "message.fill").font(.system(size: 18)).foregroundStyle(Palette.mint500)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.t("group.whatsapp")).font(WJFont.subhead.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                        Text(phone).font(WJFont.caption.monospacedDigit()).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.forward.app").font(.system(size: 15)).foregroundStyle(Theme.textTertiary)
                }
                .padding(14)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(WJFont.captionBold).foregroundStyle(Theme.accent)
            content()
        }
    }

    private func infoChip(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.textTertiary)
            Text(text).font(WJFont.caption.weight(.semibold)).foregroundStyle(Theme.textSecondary).lineLimit(1)
        }
        .padding(.horizontal, 10).frame(height: 30)
        .background(Theme.surfaceSunken, in: Capsule())
    }

    private var timeRange: String {
        let a = DateText.clock12(plan.arrivalTime, s)
        let b = DateText.clock12(plan.departureTime, s)
        return a.isEmpty && b.isEmpty ? "—" : "\(a) – \(b)"
    }

    private func openWhatsApp(_ phone: String) {
        let digits = phone.filter { $0.isNumber }
        guard let url = URL(string: "https://wa.me/\(digits)") else { return }
        UIApplication.shared.open(url)
    }

    private func copy() async {
        copying = true
        defer { copying = false }
        do {
            let created = try await API.copyRoadmap(plan.roadmapId)
            visitor.replace(created)
            await visitor.refreshRoadmaps()
            await onCopied()
            Haptics.success()
            dismiss()
            app.show(s.t("group.copied"))
            router.open(.journey, created.isToday ? [.journey(created.roadmapId)] : [.planDetail(created.roadmapId)])
        } catch {
            // the most common cause is "you already have a plan for this day"
            Haptics.error()
            app.showError(error, s)
        }
    }
}

// MARK: - Share sheet (owner)

// GRP-06: publish my plan, or change / stop sharing it
struct GroupShareSheet: View {
    let roadmap: Roadmap
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(VisitorStore.self) private var visitor
    @Environment(GroupShareStore.self) private var group
    @Environment(\.dismiss) private var dismiss

    @State private var note: String = ""
    @State private var showContact = false
    @State private var sameGenderOnly = false
    @State private var working = false
    private let maxNote = 140

    private var alreadyShared: Bool { group.isShared(roadmap.roadmapId) }
    private var hasPhone: Bool { (visitor.info?.phone?.isEmpty == false) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SheetHeader(title: s.t("group.shareTitle"), subtitle: s.t("group.shareSubtitle"))

                if alreadyShared {
                    InfoNote(text: s.t("group.alreadyShared"), icon: "checkmark.circle.fill", tone: .success)
                }

                // note
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(s.t("group.noteLabel")).font(WJFont.captionBold).foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("\(note.count)/\(maxNote)").font(WJFont.micro.monospacedDigit()).foregroundStyle(note.count > maxNote ? Theme.danger : Theme.textTertiary)
                    }
                    TextField(s.t("group.notePlaceholder"), text: $note, axis: .vertical)
                        .lineLimit(2...4)
                        .font(WJFont.body)
                        .padding(12)
                        .background(Theme.surfaceSunken, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.border, lineWidth: 1))
                        .onChange(of: note) { _, v in if v.count > maxNote { note = String(v.prefix(maxNote)) } }
                }

                // audience
                VStack(alignment: .leading, spacing: 8) {
                    Text(s.t("group.audience")).font(WJFont.captionBold).foregroundStyle(Theme.textPrimary)
                    Toggle(isOn: $sameGenderOnly) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.t("group.sameGender")).font(WJFont.subhead.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                            Text(s.t("group.sameGenderHint")).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .tint(Theme.primary)
                }

                // contact
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $showContact) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.t("group.showContact")).font(WJFont.subhead.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                            Text(s.t("group.showContactHint")).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .tint(Theme.primary)
                    .disabled(!hasPhone)
                    if !hasPhone {
                        InfoNote(text: s.t("group.noPhone"), icon: "exclamationmark.triangle.fill", tone: .warning)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.top, 4)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button {
                    Task { await publish() }
                } label: {
                    HStack(spacing: 8) {
                        if working { ProgressView().tint(.white) } else { Image(systemName: "person.3.fill") }
                        Text(alreadyShared ? s.t("group.update") : s.t("group.publish"))
                    }
                }
                .buttonStyle(.wjPrimary)
                .disabled(working)

                if alreadyShared {
                    Button(s.t("group.stopSharing")) { Task { await stop() } }
                        .buttonStyle(.wj(.destructive, height: 46))
                        .disabled(working)
                }
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
            .background(Theme.sheet.opacity(0.9))
            .overlay(alignment: .top) { Rectangle().fill(Theme.border).frame(height: 0.5) }
        }
        .wjSheet([.large])
        .onAppear {
            let current = group.share(roadmap.roadmapId)
            note = current.note ?? ""
            showContact = current.showContact && hasPhone
            sameGenderOnly = current.audience == "SAME_GENDER"
        }
    }

    private func publish() async {
        working = true
        defer { working = false }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let audience = sameGenderOnly ? "SAME_GENDER" : "ALL"
        do {
            try await API.shareRoadmap(roadmap.roadmapId, ShareBody(shareNote: trimmed.isEmpty ? nil : trimmed, showContact: showContact, audience: audience))
            group.setShared(roadmap.roadmapId, note: trimmed.isEmpty ? nil : trimmed, showContact: showContact, audience: audience)
            Haptics.success()
            dismiss()
            app.show(alreadyShared ? s.t("group.updatedToast") : s.t("group.publishedToast"))
        } catch {
            Haptics.error()
            app.showError(error, s)
        }
    }

    private func stop() async {
        working = true
        defer { working = false }
        do {
            try await API.unshareRoadmap(roadmap.roadmapId)
            group.setUnshared(roadmap.roadmapId)
            Haptics.tap()
            dismiss()
            app.show(s.t("group.stoppedToast"), tone: .neutral, icon: "eye.slash")
        } catch {
            Haptics.error()
            app.showError(error, s)
        }
    }
}

// MARK: - Small shared pieces

// a round monogram for a first name (no photos on the backend)
struct GroupAvatar: View {
    let name: String?
    var size: CGFloat = 40

    private var initial: String {
        let t = (name ?? "").trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? "?" : String(t.prefix(1))
    }

    var body: some View {
        Text(initial)
            .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
            .foregroundStyle(Palette.lime500)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [Palette.blue700.opacity(0.7), Palette.mint900], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: Circle()
            )
            .overlay(Circle().stroke(Palette.blue500.opacity(0.4), lineWidth: 1))
    }
}

// a wrapping row of interest chips (uses the existing FlowLayout)
struct InterestWrap: View {
    let interests: [Interest]
    @Environment(AppSettings.self) private var s

    var body: some View {
        FlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(interests) { interest in
                Text(s.interestName(interest))
                    .font(WJFont.micro.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 9)
                    .frame(height: 26)
                    .background(Theme.surfaceSunken, in: Capsule())
                    .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
            }
        }
    }
}

// up to four overlapping stop thumbnails
struct StopThumbnails: View {
    let stops: [SharedStop]
    private let shown = 4

    var body: some View {
        HStack(spacing: -10) {
            ForEach(Array(stops.prefix(shown).enumerated()), id: \.offset) { index, stop in
                RemoteImage(url: stop.imageUrl, cornerRadius: 9)
                    .frame(width: 34, height: 34)
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Theme.surface, lineWidth: 2))
                    .zIndex(Double(shown - index))
            }
            if stops.count > shown {
                Text("+\(stops.count - shown)")
                    .font(WJFont.micro.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(Theme.surfaceSunken, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Theme.surface, lineWidth: 2))
            }
        }
    }
}
