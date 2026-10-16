import SwiftUI

// Pavilion card: image on the side, name, zone, rating, status badge and an action
struct PavilionRow: View {
    let pavilion: Pavilion
    var status: PavilionStatus = .none
    var showsCrowd = true
    var trailing: Trailing = .chevron
    var dimmed = false
    var onAdd: (() -> Void)? = nil

    enum Trailing { case chevron, add, none, selected(Bool) }

    @Environment(AppSettings.self) private var s
    @Environment(ExpoStore.self) private var expo

    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(url: pavilion.imageUrl, cornerRadius: 14)
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 5) {
                Text(s.pavilionName(pavilion.name))
                    .font(WJFont.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    Text(s.zoneTitle(expo.zone(of: pavilion.id)?.name))
                        .lineLimit(1)
                    if let avg = pavilion.ratingAverage {
                        Text("·")
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(Theme.star)
                            Text("\(avg.oneDecimal) (\(pavilion.ratingCount))")
                        }
                        .environment(\.layoutDirection, .leftToRight)
                    }
                }
                .font(WJFont.caption)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                // badges wrap to a new line instead of spilling past the card edge
                FlowLayout(spacing: 6) {
                    PavilionStatusBadge(status: status)
                    if showsCrowd, let c = expo.crowd[pavilion.id] {
                        CrowdBadge(minutes: c.waitMinutes, level: c.level)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 8)
            trailingView
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous).stroke(Theme.border, lineWidth: 1))
        .opacity(dimmed ? 0.5 : 1)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var trailingView: some View {
        switch trailing {
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
                .flipsForRightToLeftLayoutDirection(true)
        case .add:
            Button {
                onAdd?()
            } label: {
                Label(s.t("common.add"), systemImage: "plus")
                    .font(WJFont.footnote.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .overlay(Capsule().stroke(Theme.borderStrong, lineWidth: 1))
            }
            .buttonStyle(.plain)
        case .selected(let on):
            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(on ? Theme.primary : Theme.textTertiary)
        case .none:
            EmptyView()
        }
    }
}

// numbered marker used in stop lists and on the map
struct StopNumber: View {
    let number: Int
    var state: StopState = .upcoming
    var size: CGFloat = 28

    enum StopState { case upcoming, next, visited, locked }

    var body: some View {
        ZStack {
            switch state {
            case .visited, .locked:
                Circle().fill(Theme.surfaceSunken)
                Circle().stroke(Theme.textTertiary, lineWidth: 1.2)
                Image(systemName: "checkmark").font(.system(size: size * 0.4, weight: .bold)).foregroundStyle(Theme.textSecondary)
            case .next:
                Circle().fill(Palette.lime500)
                Text("\(number)").font(.system(size: size * 0.45, weight: .heavy)).foregroundStyle(Palette.ink900)
            case .upcoming:
                Circle().fill(Theme.primary)
                Text("\(number)").font(.system(size: size * 0.45, weight: .bold)).foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
    }
}

// one stop of a plan: number, name, zone, planned time and queue, warnings
struct StopRow: View {
    let stop: RoadmapStop
    let number: Int
    var isNext = false
    var showsChevron = true
    @Environment(AppSettings.self) private var s

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                StopNumber(number: number, state: stop.visited ? .visited : (isNext ? .next : .upcoming))
                VStack(alignment: .leading, spacing: 4) {
                    Text(s.pavilionName(stop.pavilionName))
                        .font(WJFont.headline)
                        .foregroundStyle(stop.visited ? Theme.textSecondary : Theme.textPrimary)
                    HStack(spacing: 6) {
                        if stop.visited {
                            StatusBadge(text: s.t("status.visitedAt", DateText.clock12(DateText.clock(stop.visitedAt), s)), icon: "checkmark.circle", tone: .success, compact: true)
                        } else if isNext {
                            StatusBadge(text: s.t("status.next"), icon: "location.north.fill", tone: .lime, compact: true)
                        } else {
                            StatusBadge(text: s.t("status.inPlan"), icon: "point.topleft.down.to.point.bottomright.curvepath", tone: .primary, compact: true)
                        }
                        Text(s.zoneTitle(stop.zoneName))
                            .font(WJFont.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                    if !stop.visited, stop.plannedTime != nil || stop.expectedWait != nil {
                        HStack(spacing: 8) {
                            if let time = stop.plannedTime {
                                Label(DateText.clock12(time, s), systemImage: "clock")
                                    .font(WJFont.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            CrowdBadge(minutes: stop.expectedWait)
                        }
                    }
                }
                Spacer(minLength: 0)
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .flipsForRightToLeftLayoutDirection(true)
                }
            }
            if !stop.visited, let warnings = stop.accessibilityWarnings, !warnings.isEmpty {
                AccessWarningStrip(warnings: warnings)
            }
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(isNext ? Theme.accent : Theme.border, lineWidth: isNext ? 1.4 : 1))
        .contentShape(Rectangle())
    }
}

// amber strip: "عربة أطفال: متاح جزئيًا · لازم تترك عربة الأطفال عند المدخل"
struct AccessWarningStrip: View {
    let warnings: [AccessibilityWarning]
    @Environment(AppSettings.self) private var s

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(warnings, id: \.self) { w in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: AccessStatus.icon(w.status))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AccessStatus.tone(w.status).foreground)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(s.label(w.needType)): \(AccessStatus.title(w.status, s))")
                            .font(WJFont.captionBold)
                            .foregroundStyle(Theme.textPrimary)
                        let note = s.isArabic ? (w.noteAr ?? w.note) : (w.note ?? w.noteAr)
                        if let note, !note.isEmpty {
                            Text(note).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.warningSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// helpers shared by the plan screens
enum PlanMath {
    // "update the rest of my plan" needs unvisited stops and a reviewed visit in this plan (same rule as makeDynamic)
    @MainActor
    static func canUpdateRest(_ roadmap: Roadmap, visitor: VisitorStore) -> Bool {
        guard roadmap.isToday, roadmap.nextStop != nil else { return false }
        let pending = visitor.pendingIds
        return roadmap.orderedStops.contains { $0.visited && !pending.contains($0.pavilionId ?? -1) }
    }
}
