import SwiftUI

enum PassportTab: Hashable { case stamps, history, pending }
enum StampFilter: Hashable { case all, earned, notYet }

// PASS-01…04: notebook style passport with the 58 country stamps, visit history and reviews waiting
struct PassportView: View {
    @Environment(AppSettings.self) private var s
    @Environment(VisitorStore.self) private var visitor
    @Environment(ExpoStore.self) private var expo
    @Environment(Router.self) private var router
    @State private var tab: PassportTab = .stamps
    @State private var filter: StampFilter = .all
    @State private var page = 0
    @State private var detail: Stamp?
    private let perPage = 9

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(s.t("tab.passport")).font(WJFont.title1).foregroundStyle(Theme.textPrimary).padding(.top, 12)
                cover
                Text(s.t("passport.rule"))
                    .font(WJFont.caption)
                    .foregroundStyle(Theme.textSecondary)
                tabs
                notebook
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.bottom, 24)
            .maxContentWidth()
        }
        .refreshable { await visitor.refreshPassport(); await visitor.refreshReviews() }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .wjTabBar()
        .sheet(item: $detail) { stamp in StampDetailSheet(stamp: stamp) }
        .task { if visitor.stamps.isEmpty { await visitor.refreshPassport() } }
    }

    // ===== cover =====
    private var cover: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(s.t("passport.coverTitle")).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                    Text(visitor.info?.fullName ?? "").font(WJFont.title2).foregroundStyle(Theme.textPrimary)
                    Text("\(s.t("passport.number")) \(visitor.passport?.passportNumber ?? visitor.info?.passportNumber ?? "—")")
                        .font(WJFont.caption.monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "seal.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Palette.lime500)
                    .frame(width: 48, height: 48)
                    .background(Palette.mint900, in: Circle())
            }
            HStack(spacing: 28) {
                StatColumn(value: "\(visitor.earnedCount) / \(total)", label: s.t("passport.stamps"))
                StatColumn(value: "\(visitor.passport?.visitsCount ?? 0)", label: s.t("passport.visits"))
                StatColumn(value: "\(visitor.pending.count)", label: s.t("passport.pending"))
            }
            LinearMeter(value: total == 0 ? 0 : Double(visitor.earnedCount) / Double(total), tint: Palette.lime500)
        }
        .padding(18)
        .background(
            LinearGradient(colors: [Palette.blue700.opacity(0.55), Theme.surface], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous).stroke(Palette.blue500.opacity(0.4), lineWidth: 1))
    }

    private var total: Int { max(visitor.stamps.count, expo.pavilions.count) }

    // ===== folder tabs =====
    private var tabs: some View {
        HStack(spacing: 6) {
            tabButton(.stamps, s.t("passport.tabStamps"))
            tabButton(.history, s.t("passport.tabHistory"))
            tabButton(.pending, s.t("passport.tabPending"), badge: visitor.pending.count)
            Spacer()
        }
        .padding(.bottom, -14)
        .zIndex(1)
    }

    private func tabButton(_ value: PassportTab, _ title: String, badge: Int = 0) -> some View {
        let on = tab == value
        return Button {
            withAnimation(.snappy) { tab = value }
        } label: {
            HStack(spacing: 5) {
                Text(title).font(WJFont.footnote.weight(.bold))
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Palette.ink900)
                        .padding(.horizontal, 5)
                        .background(Palette.lime500, in: Capsule())
                }
            }
            .foregroundStyle(on ? Palette.paperInk : Theme.textPrimary)
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(on ? Palette.paper : Theme.surfaceRaised, in: UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // ===== the paper page =====
    private var notebook: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                switch tab {
                case .stamps: stampsPage
                case .history: historyPage
                case .pending: pendingPage
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            // binder holes
            VStack(spacing: 16) {
                ForEach(0..<14, id: \.self) { _ in Circle().fill(Palette.ink900).frame(width: 7, height: 7) }
            }
            .padding(.vertical, 18)
            .padding(.trailing, 8)
        }
        .background(
            ZStack {
                Palette.paper
                VStack(spacing: 32) {
                    ForEach(0..<30, id: \.self) { _ in Rectangle().fill(Palette.paperLine).frame(height: 1) }
                }
                .padding(.top, 40)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .environment(\.colorScheme, .light)
    }

    // PASS-01 / 02
    @ViewBuilder
    private var stampsPage: some View {
        let list = filteredStamps
        let pages = max(1, Int(ceil(Double(list.count) / Double(perPage))))
        let current = min(page, pages - 1)
        HStack {
            Text(s.t("passport.yourStamps")).font(WJFont.title3).foregroundStyle(Palette.paperInk)
            Spacer()
            Text(s.t("passport.page", "\(current + 1)", "\(pages)")).font(WJFont.caption).foregroundStyle(Palette.paperInk.opacity(0.6))
        }
        HStack(spacing: 6) {
            filterChip(.all, s.t("passport.filterAll", "\(visitor.stamps.count)"))
            filterChip(.earned, s.t("passport.filterEarned", "\(visitor.earnedCount)"))
            filterChip(.notYet, s.t("passport.filterNotYet", "\(visitor.stamps.count - visitor.earnedCount)"))
        }
        if visitor.stamps.isEmpty {
            ProgressView().frame(maxWidth: .infinity).padding(30)
        } else if list.isEmpty {
            Text(s.t("passport.emptyFilter")).font(WJFont.footnote).foregroundStyle(Palette.paperInk.opacity(0.6)).padding(.vertical, 20)
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 3), alignment: .center, spacing: 16) {
                ForEach(list.dropFirst(current * perPage).prefix(perPage)) { stamp in
                    Button { detail = stamp } label: { stampCell(stamp) }
                        .buttonStyle(.plain)
                }
            }
            if pages > 1 {
                HStack(spacing: 18) {
                    Button { page = max(current - 1, 0) } label: { Image(systemName: "chevron.left").flipsForRightToLeftLayoutDirection(true) }
                        .disabled(current == 0)
                    Text("\(current + 1) / \(pages)").font(WJFont.caption.monospacedDigit())
                    Button { page = min(current + 1, pages - 1) } label: { Image(systemName: "chevron.right").flipsForRightToLeftLayoutDirection(true) }
                        .disabled(current >= pages - 1)
                }
                .foregroundStyle(Palette.paperInk)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }
        }
    }

    private var filteredStamps: [Stamp] {
        // earned stamps first, then the rest
        let sorted = visitor.stamps.sorted { a, b in
            if a.isEarned != b.isEarned { return a.isEarned }
            if a.isEarned { return (a.earnedAt ?? "") > (b.earnedAt ?? "") }
            return s.countryName(countryOf(a)) < s.countryName(countryOf(b))
        }
        switch filter {
        case .all: return sorted
        case .earned: return sorted.filter(\.isEarned)
        case .notYet: return sorted.filter { !$0.isEarned }
        }
    }

    private func countryOf(_ stamp: Stamp) -> String? { expo.pavilion(stamp.pavilionId)?.country }

    private func filterChip(_ value: StampFilter, _ title: String) -> some View {
        let on = filter == value
        return Button {
            filter = value
            page = 0
        } label: {
            Text(title)
                .font(WJFont.caption.weight(.bold))
                .foregroundStyle(on ? Palette.paper : Palette.paperInk)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(on ? Palette.paperInk : Color.clear, in: Capsule())
                .overlay(Capsule().stroke(Palette.paperInk.opacity(0.4), lineWidth: on ? 0 : 1))
        }
        .buttonStyle(.plain)
    }

    private func stampCell(_ stamp: Stamp) -> some View {
        // visits of this pavilion only (matched by pavilionId): the stamp repeats once per visit and every visit day is listed
        let visits = visitor.visits(of: stamp.pavilionId)
        return VStack(spacing: 5) {
            StampStack(imageUrl: stamp.imageUrl, earned: stamp.isEarned, count: visits.count, size: 68)
                .padding(.bottom, visits.count > 1 ? 8 : 0)
            Text(s.countryName(countryOf(stamp)).isEmpty ? s.pavilionName(stamp.pavilionName) : s.countryName(countryOf(stamp)))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.paperInk)
                .lineLimit(1)
            if stamp.isEarned {
                ForEach(visits) { visit in
                    Label(DateText.shortDay(visit.visitedAt, s), systemImage: "checkmark.circle")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(Palette.blue600)
                }
            } else {
                Label(s.t("passport.notYet"), systemImage: "lock")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Palette.paperInk.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func visitDates(_ pavilionId: Int?) -> [String] {
        visitor.visits(of: pavilionId).map { DateText.shortDay($0.visitedAt, s) }
    }

    // PASS-03: newest first, grouped by day
    @ViewBuilder
    private var historyPage: some View {
        let visits = (visitor.passport?.visits ?? []).sorted { ($0.visitedAt ?? "") > ($1.visitedAt ?? "") }
        let groups = Dictionary(grouping: visits) { String(($0.visitedAt ?? "").prefix(10)) }
        HStack {
            Text(s.t("passport.history")).font(WJFont.title3).foregroundStyle(Palette.paperInk)
            Spacer()
            Text(s.t("passport.visitsCount", "\(visits.count)")).font(WJFont.caption).foregroundStyle(Palette.paperInk.opacity(0.6))
        }
        if visits.isEmpty {
            Text(s.t("passport.noVisits")).font(WJFont.footnote).foregroundStyle(Palette.paperInk.opacity(0.6)).padding(.vertical, 20)
        }
        ForEach(groups.keys.sorted(by: >), id: \.self) { day in
            Text(DateText.longDay(day, s)).font(WJFont.caption.weight(.bold)).foregroundStyle(Palette.paperInk.opacity(0.65))
            ForEach(groups[day] ?? []) { visit in
                Button {
                    if let id = visit.pavilionId { router.push(.pavilion(id)) }
                } label: {
                    HStack(spacing: 10) {
                        StampArt(imageUrl: visitor.stamps.first { $0.pavilionId == visit.pavilionId }?.imageUrl, earned: true, size: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.pavilionName(visit.pavilionName)).font(WJFont.subhead.weight(.bold)).foregroundStyle(Palette.paperInk)
                            Text("\(DateText.clock12(DateText.clock(visit.visitedAt), s)) · \(s.zoneTitle(visit.zoneName))")
                                .font(WJFont.caption).foregroundStyle(Palette.paperInk.opacity(0.6))
                        }
                        Spacer()
                        if visitor.pendingIds.contains(visit.pavilionId ?? -1) {
                            Text(s.t("passport.awaitingReview")).font(WJFont.caption.weight(.bold)).foregroundStyle(Palette.blue600)
                        } else {
                            Label(s.t("status.reviewed"), systemImage: "star.fill").font(WJFont.caption.weight(.bold)).foregroundStyle(Palette.amber700)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // PASS-04: visited pavilions with no review yet
    @ViewBuilder
    private var pendingPage: some View {
        HStack {
            Text(s.t("passport.pendingTitle")).font(WJFont.title3).foregroundStyle(Palette.paperInk)
            Spacer()
            Text(s.t("plan.pavilionsCount", "\(visitor.pending.count)")).font(WJFont.caption).foregroundStyle(Palette.paperInk.opacity(0.6))
        }
        if visitor.pending.isEmpty {
            Text(s.t("passport.noPending")).font(WJFont.footnote).foregroundStyle(Palette.paperInk.opacity(0.6)).padding(.vertical, 20)
        }
        ForEach(visitor.pending) { pavilion in
            HStack(spacing: 10) {
                StampArt(imageUrl: visitor.stamps.first { $0.pavilionId == pavilion.id }?.imageUrl, earned: true, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.pavilionName(pavilion.name)).font(WJFont.subhead.weight(.bold)).foregroundStyle(Palette.paperInk)
                    if let date = visitDates(pavilion.id).first {
                        Text(s.t("passport.visitedOn", date)).font(WJFont.caption).foregroundStyle(Palette.paperInk.opacity(0.6))
                    }
                }
                Spacer()
                Button(s.t("review.rate")) {
                    router.push(.writeReview(pavilionId: pavilion.id, reviewId: nil, rating: 0))
                }
                .buttonStyle(.wj(.primary, height: 36, fullWidth: false))
            }
            .padding(.vertical, 4)
        }
    }
}

// OVL-PASS-01: one stamp
struct StampDetailSheet: View {
    let stamp: Stamp
    @Environment(AppSettings.self) private var s
    @Environment(VisitorStore.self) private var visitor
    @Environment(ExpoStore.self) private var expo
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // visits of this pavilion only, newest first
        let visits = visitor.visits(of: stamp.pavilionId)
        VStack(spacing: 14) {
            SheetHeader(title: s.pavilionName(stamp.pavilionName))
            StampStack(imageUrl: stamp.imageUrl, earned: stamp.isEarned, count: visits.count, size: 150)
                .padding(visits.count > 1 ? 40 : 20)
                .background(Palette.paper, in: RoundedRectangle(cornerRadius: 20))
            if stamp.isEarned {
                Label(s.t("passport.earnedOn", DateText.longDay(String((stamp.earnedAt ?? "").prefix(10)), s)), systemImage: "checkmark.seal.fill")
                    .font(WJFont.subhead.weight(.semibold))
                    .foregroundStyle(Theme.success)
                if visits.count > 1 {
                    Text(s.t("passport.visitsHere", "\(visits.count)")).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(visits) { visit in
                            Label(DateText.longDay(String((visit.visitedAt ?? "").prefix(10)), s), systemImage: "checkmark.circle")
                                .font(WJFont.caption.weight(.semibold))
                                .foregroundStyle(Palette.blue600)
                        }
                    }
                }
            } else {
                Text(s.t("passport.notEarnedHint")).font(WJFont.subhead).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
            if let id = stamp.pavilionId {
                Button(s.t("passport.openPavilion")) {
                    dismiss()
                    router.push(.pavilion(id))
                }
                .buttonStyle(.wjSecondary)
            }
        }
        .padding(.horizontal, Metrics.margin)
        .padding(.bottom, 8)
        .wjSheet([.medium, .large])
    }
}
