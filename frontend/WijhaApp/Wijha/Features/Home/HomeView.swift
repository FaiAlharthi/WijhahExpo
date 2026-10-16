import SwiftUI

// رحلتي tab root: AUTH-SU-05 (no plan today) and AUTH-LI-03 (active plan)
struct HomeView: View {
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(VisitorStore.self) private var visitor
    @Environment(ExpoStore.self) private var expo
    @Environment(Router.self) private var router
    @State private var updating = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if !visitor.loaded && visitor.roadmaps.isEmpty {
                    SkeletonList(count: 3, height: 140)
                } else if let error = visitor.error, visitor.roadmaps.isEmpty {
                    ErrorStateView(message: error) { Task { await visitor.refreshAll() } }
                } else if let today = visitor.today {
                    todayCard(today)
                } else {
                    noPlanCard
                }

                if let alert = visitor.newAlerts.first {
                    crowdAlertCard(alert)
                }

                if let pending = visitor.pending.first {
                    reviewCard(pending)
                }

                if !visitor.upcoming.isEmpty {
                    upcomingCard
                }

                passportCard

                if visitor.today == nil {
                    topRated
                }
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .maxContentWidth()
        }
        .refreshable {
            async let a: Void = visitor.refreshAll()
            async let b: Void = expo.loadCrowd()
            _ = await (a, b)
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .wjTabBar()
    }

    // ===== greeting =====
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(greeting)
                    .font(WJFont.title1)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)   // stays on one line for normal names, wraps only for very long ones
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitleLine)
                    .font(WJFont.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            HStack(spacing: 4) {
                CircleIconButton(icon: "calendar", size: 38, label: s.t("plans.title")) { router.push(.plans) }
                CircleIconButton(icon: "message", size: 38, label: s.t("assistant.title")) { router.push(.assistant) }
            }
        }
        .padding(.top, 12)
    }

    private var greeting: String {
        let name = visitor.info?.firstName ?? ""
        if visitor.today != nil { return s.t("home.helloActive", name) }
        let hour = Calendar.current.component(.hour, from: Date())
        return s.t(hour < 12 ? "home.morning" : "home.evening", name)
    }

    private var subtitleLine: String {
        let day = DateText.longDay(Date(), s)
        if let today = visitor.today, let first = today.orderedStops.first?.plannedTime {
            return "\(day) · \(s.t("home.from", DateText.clock12(first, s)))"
        }
        return day
    }

    // ===== no plan today =====
    private var noPlanCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "sparkle")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.accent)
            Text(s.t("home.noPlanTitle"))
                .font(WJFont.title3)
                .foregroundStyle(Theme.textPrimary)
            Text(s.t("home.noPlanMessage"))
                .font(WJFont.subhead)
                .foregroundStyle(Theme.textSecondary)
            Button {
                startPlan()
            } label: {
                Label(s.t("home.createPlan"), systemImage: "sparkles")
            }
            .buttonStyle(.wjPrimary)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 18)
    }

    // ===== today's plan (AUTH-LI-03) =====
    private func todayCard(_ plan: Roadmap) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(s.t("home.todayPlan")).font(WJFont.title3).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(s.t("home.stopsProgress", "\(plan.visitedCount)", "\(plan.stopsCount)"))
                    .font(WJFont.captionBold)
                    .foregroundStyle(Theme.accent)
            }
            LinearMeter(value: plan.stopsCount == 0 ? 0 : Double(plan.visitedCount) / Double(plan.stopsCount))

            if let next = plan.nextStop {
                Button {
                    if let id = next.pavilionId { router.push(.pavilion(id)) }
                } label: {
                    HStack(spacing: 12) {
                        StopNumber(number: next.stopOrder ?? 1, state: .next, size: 32)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(s.pavilionName(next.pavilionName))
                                .font(WJFont.headline)
                                .foregroundStyle(Theme.textPrimary)
                            HStack(spacing: 6) {
                                Text(s.zoneTitle(next.zoneName))
                                if let time = next.plannedTime {
                                    Text("·")
                                    Text(DateText.clock12(time, s))
                                }
                            }
                            .font(WJFont.caption)
                            .foregroundStyle(Theme.textSecondary)
                            HStack(spacing: 6) {
                                StatusBadge(text: s.t("status.next"), icon: "location.north.fill", tone: .lime, compact: true)
                                CrowdBadge(minutes: next.expectedWait)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                            .flipsForRightToLeftLayoutDirection(true)
                    }
                    .padding(12)
                    .background(Theme.accentSoft.opacity(0.4), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.accent, lineWidth: 1.4))
                }
                .buttonStyle(.plain)
            } else if plan.isFinished {
                InfoNote(text: s.t("home.planDone"), icon: "flag.checkered", tone: .success)
            }

            Button {
                router.push(.journey(plan.roadmapId))
            } label: {
                Label(s.t("home.openMap"), systemImage: "map")
            }
            .buttonStyle(.wjPrimary)

            if PlanMath.canUpdateRest(plan, visitor: visitor) {
                Button {
                    confirmUpdate(plan)
                } label: {
                    HStack(spacing: 6) {
                        if updating { ProgressView() }
                        Label(s.t("plans.updateRest"), systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .buttonStyle(.wj(.secondary, height: 44))
                .disabled(updating)
            }
        }
        .card(padding: 16)
    }

    // ===== crowd alert (WhatsApp alert, also shown here) =====
    private func crowdAlertCard(_ alert: CrowdAlert) -> some View {
        Button {
            router.push(.crowdAlerts)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "person.2.wave.2.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.success)
                    .frame(width: 40, height: 40)
                    .background(Theme.successSoft, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(s.t("alerts.cardTitle", s.pavilionName(alert.pavilionName)))
                        .font(WJFont.headline)
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(s.t("alerts.cardMessage", "\(alert.waitNow ?? 0)", DateText.clock12(alert.calmAt, s), "\(alert.waitCalm ?? 0)"))
                        .font(WJFont.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                    Text(s.t("alerts.review"))
                        .font(WJFont.label)
                        .foregroundStyle(Theme.primaryText)
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
            .card(padding: 14)
        }
        .buttonStyle(.plain)
    }

    // ===== review waiting =====
    private func reviewCard(_ pavilion: Pavilion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "star").foregroundStyle(Theme.star)
                Text(s.t("home.howWasVisit", s.pavilionName(pavilion.name)))
                    .font(WJFont.headline)
                    .foregroundStyle(Theme.textPrimary)
            }
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { i in
                    Button {
                        router.push(.writeReview(pavilionId: pavilion.id, reviewId: nil, rating: i))
                    } label: {
                        Image(systemName: "star")
                            .font(.system(size: 26))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: Metrics.touch, height: Metrics.touch)
                    }
                    .buttonStyle(.plain)
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            Text(s.t("home.reviewHint"))
                .font(WJFont.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 16, stroke: Theme.primary.opacity(0.6))
    }

    // ===== upcoming plans =====
    private var upcomingCard: some View {
        Button {
            router.push(.plans)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)
                    .frame(width: 40, height: 40)
                    .background(Theme.primarySoft, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.t("home.upcoming")).font(WJFont.headline).foregroundStyle(Theme.textPrimary)
                    Text(visitor.upcoming.prefix(2).map { DateText.weekdayDay($0.visitDate, s) }.joined(separator: " · "))
                        .font(WJFont.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .flipsForRightToLeftLayoutDirection(true)
            }
            .card(padding: 14)
        }
        .buttonStyle(.plain)
    }

    // ===== passport =====
    private var passportCard: some View {
        Button {
            router.tab = .passport
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(s.t("home.passport")).font(WJFont.title3).foregroundStyle(Theme.textPrimary)
                    Text(visitor.pending.isEmpty ? s.t("home.passportAllReviewed") : s.t("home.pendingCount", "\(visitor.pending.count)"))
                        .font(WJFont.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Text("\(visitor.earnedCount) / \(max(visitor.stamps.count, expo.pavilions.count))")
                    .font(WJFont.stat)
                    .foregroundStyle(Theme.textPrimary)
                    .environment(\.layoutDirection, .leftToRight)
            }
            .card(padding: 16)
        }
        .buttonStyle(.plain)
    }

    // ===== top rated =====
    private var topRated: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: s.t("home.topRated"), actionTitle: s.t("common.seeAll")) { router.tab = .explore }
            ForEach(expo.topRated.prefix(4)) { pavilion in
                Button {
                    router.push(.pavilion(pavilion.id))
                } label: {
                    PavilionRow(pavilion: pavilion, status: visitor.status(of: pavilion.id))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func startPlan() {
        if (visitor.info?.interests?.count ?? 0) < 3 {
            app.ask(DialogModel(icon: "heart", tone: .primary, title: s.t("plan.needInterestsTitle"),
                                message: s.t("plan.needInterestsMessage"), primary: s.t("plan.chooseInterests"),
                                secondary: s.t("common.cancel"), onPrimary: { router.open(.account, [.interests]) }))
        } else {
            router.showWizard = true
        }
    }

    // OVL-PLANS-05: makeDynamic cannot be undone
    private func confirmUpdate(_ plan: Roadmap) {
        app.ask(DialogModel(icon: "arrow.triangle.2.circlepath", tone: .primary, title: s.t("plans.updateTitle"),
                            message: s.t("plans.updateMessage"), primary: s.t("plans.updateConfirm"),
                            secondary: s.t("plans.keepPlan"), onPrimary: {
            Task { await update(plan) }
        }))
    }

    private func update(_ plan: Roadmap) async {
        updating = true
        defer { updating = false }
        do {
            let updated = try await API.makeDynamic(plan.roadmapId)
            visitor.replace(updated)
            app.show(s.t("plans.updated"))
            router.push(.planDetail(updated.roadmapId))
        } catch {
            app.showError(error, s)
        }
    }
}
