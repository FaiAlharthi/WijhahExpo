import SwiftUI
import Observation

// all answers of the plan questions (GenerateRoadmapRequest)
@Observable
final class PlanAnswers {
    var partyType: String? = nil          // SOLO | GROUP
    var partySize = 3
    var hasChildren: Bool? = nil          // UI only, decides if the child rest break is offered
    var wantsBreaks: Bool? = nil
    var breakTypes: Set<String> = []      // PRAYER, MEAL, CHILD_REST
    var hasNeeds: Bool? = nil
    var needs: Set<String> = []

    var date = Date()
    var arrival = PlanAnswers.time(10, 0)
    var departure = PlanAnswers.time(16, 30)

    var experiences: Set<String> = []
    var pace = "RELAXED"
    var allowRevisits: Bool? = nil
    var extraInterests: Set<Int> = []
    var whatsappAlerts = true

    static func time(_ h: Int, _ m: Int) -> Date {
        Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date()) ?? Date()
    }

    // the backend accepts visit days between these dates
    static let firstDay = DateText.parseDay("2026-10-01") ?? Date()
    static let lastDay = DateText.parseDay("2027-03-31") ?? Date()

    // never above lastDay so the date range stays valid after the window ends (the backend then explains)
    var minDate: Date { min(max(Calendar.current.startOfDay(for: Date()), Self.firstDay), Self.lastDay) }

    var minutes: Int {
        let c = Calendar.current
        let a = c.component(.hour, from: arrival) * 60 + c.component(.minute, from: arrival)
        let d = c.component(.hour, from: departure) * 60 + c.component(.minute, from: departure)
        return d - a
    }

    var mobility: Bool { hasNeeds == true && AccessNeed.needsStepFree(Array(needs)) }

    // step 1 is complete
    var step1Missing: String? {
        guard let partyType else { return "wizard.missingParty" }
        if partyType == "GROUP" {
            if partySize < 2 { return "wizard.missingSize" }
            if hasChildren == nil { return "wizard.missingChildren" }
        }
        guard let wantsBreaks else { return "wizard.missingBreaks" }
        if wantsBreaks && breakTypes.isEmpty { return "wizard.missingBreakTypes" }
        guard let hasNeeds else { return "wizard.missingNeedsAnswer" }
        if hasNeeds && needs.isEmpty { return "wizard.missingNeeds" }
        return nil
    }

    var step2Missing: String? {
        if minutes <= 0 { return "wizard.departureAfter" }
        return nil
    }

    var step3Missing: String? {
        if experiences.isEmpty { return "wizard.missingExperience" }
        if allowRevisits == nil { return "wizard.missingRevisits" }
        return nil
    }

    var request: GenerateRoadmapRequest {
        let breaks = wantsBreaks == true
        let kids = partyType == "GROUP" && hasChildren == true
        return GenerateRoadmapRequest(
            visitDate: DateText.dayString(date),
            partyType: partyType ?? "SOLO",
            partySize: partyType == "GROUP" ? partySize : 1,
            arrivalTime: DateText.timeString(arrival),
            departureTime: DateText.timeString(departure),
            experienceTypes: Array(experiences).sorted(),
            visitPace: pace,
            includePrayerBreaks: breaks && breakTypes.contains("PRAYER"),
            includeMealBreaks: breaks && breakTypes.contains("MEAL"),
            includeChildRestBreaks: breaks && kids && breakTypes.contains("CHILD_REST"),
            allowRevisits: allowRevisits ?? false,
            extraInterestIds: extraInterests.isEmpty ? nil : Array(extraInterests),
            whatsappAlerts: whatsappAlerts,
            accessibilityNeeds: hasNeeds == true ? AccessNeed.sorted(Array(needs)) : nil
        )
    }
}

enum WizardStage: Hashable {
    case questions, summary, generating, ready(Int)
}

// PLAN-01…07: four questions, summary, generating and plan ready
struct PlanWizardView: View {
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(VisitorStore.self) private var visitor
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var answers = PlanAnswers()
    @State private var step = 1
    @State private var stage: WizardStage = .questions
    @State private var showMissing = false
    @State private var generateError: String?
    @State private var generateTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .questions: questions
                case .summary: summary
                case .generating: GeneratingView { cancelGenerate() }
                case .ready(let id): PlanOverviewView(roadmapId: id, mode: .ready) {
                    dismiss()
                    router.open(.journey, [.journey(id)])
                }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: stage)
        }
        // the wizard is a full-screen cover, so host toasts/dialogs here or they render behind it
        .overlay { ToastHost() }
        .overlay { DialogHost() }
        .onAppear {
            answers.date = answers.minDate
        }
    }

    // ===== the four steps =====
    private var questions: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    StepProgress(total: 4, current: step)
                    switch step {
                    case 1: PartyStep(answers: answers)
                    case 2: DateStep(answers: answers)
                    case 3: StyleStep(answers: answers)
                    default: InterestsStep(answers: answers)
                    }
                }
                .padding(.horizontal, Metrics.margin)
                .padding(.top, 4)
                .padding(.bottom, 24)
                .id(step)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 8) {
                if let missing = missingKey {
                    Text(s.t(missing))
                        .font(WJFont.caption)
                        .foregroundStyle(showMissing ? Theme.danger : Theme.textSecondary)
                }
                Button(step == 4 ? s.t("wizard.reviewSummary") : s.t("common.next")) {
                    if missingKey == nil {
                        showMissing = false
                        if step == 4 { stage = .summary } else { withAnimation { step += 1 } }
                    } else {
                        showMissing = true
                        Haptics.error()
                    }
                }
                .buttonStyle(.wjPrimary)
                .disabled(missingKey != nil && step == 1 && answers.partyType == nil)
                if step == 4 {
                    Button(s.t("wizard.skipStep")) { answers.extraInterests = []; stage = .summary }
                        .buttonStyle(.wjTertiary)
                }
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.vertical, 12)
            .background(Theme.canvas.opacity(0.94))
        }
        .maxContentWidth()
        .screenBackground()
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            // back goes one step back with the answers kept, ✕ on step 1 closes the wizard
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if step > 1 { withAnimation { step -= 1 } } else { closeWizard() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: step > 1 ? "arrow.left" : "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .flipsForRightToLeftLayoutDirection(true)
                            .frame(width: 32, height: Metrics.touch)
                        Text(s.t("wizard.title")).font(WJFont.headline)
                    }
                    .foregroundStyle(Theme.textPrimary)
                }
            }
        }
    }

    private var missingKey: String? {
        switch step {
        case 1: return answers.step1Missing
        case 2: return answers.step2Missing
        case 3: return answers.step3Missing
        default: return nil
        }
    }

    private func closeWizard() {
        if answers.partyType == nil {
            dismiss()
        } else {
            app.ask(DialogModel(icon: "xmark", tone: .warning, title: s.t("wizard.discardTitle"), message: s.t("wizard.discardMessage"),
                                primary: s.t("wizard.discard"), primaryRole: .destructive, secondary: s.t("wizard.keepEditing"),
                                onPrimary: { dismiss() }))
        }
    }

    // ===== PLAN-05 summary =====
    private var summary: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(s.t("wizard.summaryTitle")).font(WJFont.title1).foregroundStyle(Theme.textPrimary)

                    VStack(spacing: 0) {
                        summaryRow("wizard.rowParty", partyText, step: 1)
                        if answers.hasNeeds == true {
                            summaryRow("wizard.rowNeeds", AccessNeed.sorted(Array(answers.needs)).map { s.label($0) }.joined(separator: "، ") + (answers.mobility ? " · " + s.t("wizard.stepFreeRoute") : ""), step: 1)
                        }
                        summaryRow("wizard.rowBreaks", breaksText, step: 1)
                        summaryRow("wizard.rowDate", "\(DateText.longDay(answers.date, s)) · \(DateText.clock12(DateText.timeString(answers.arrival), s)) – \(DateText.clock12(DateText.timeString(answers.departure), s))", step: 2)
                        summaryRow("wizard.rowExperience", answers.experiences.sorted().map { s.label($0) }.joined(separator: " · "), step: 3)
                        summaryRow("wizard.rowPace", s.label(answers.pace), step: 3)
                        summaryRow("wizard.rowRevisits", answers.allowRevisits == true ? s.t("wizard.revisitsYes") : s.t("wizard.revisitsNo"), step: 3)
                        summaryRow("wizard.rowInterests", extraInterestsText, step: 4, last: true)
                    }
                    .card(padding: 0)

                    // WhatsApp crowd alerts (backend: whatsappAlerts)
                    Toggle(isOn: $answers.whatsappAlerts) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label(s.t("wizard.whatsappTitle"), systemImage: "bell.badge")
                                .font(WJFont.headline)
                                .foregroundStyle(Theme.textPrimary)
                            Text(s.t("wizard.whatsappMessage"))
                                .font(WJFont.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .tint(Theme.primary)
                    .card(padding: 14)

                    InfoNote(text: s.t("wizard.entranceNote"), icon: "door.left.hand.open")

                    if let generateError {
                        InfoNote(text: generateError, icon: "exclamationmark.triangle.fill", tone: .danger)
                    }
                }
                .padding(.horizontal, Metrics.margin)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }

            Button(s.t("wizard.create")) { confirmCreate() }
                .buttonStyle(.wjPrimary)
                .padding(.horizontal, Metrics.margin)
                .padding(.vertical, 12)
                .background(Theme.canvas.opacity(0.94))
        }
        .maxContentWidth()
        .screenBackground()
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { stage = .questions } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left").flipsForRightToLeftLayoutDirection(true)
                        Text(s.t("wizard.title")).font(WJFont.headline)
                    }
                    .foregroundStyle(Theme.textPrimary)
                }
            }
        }
    }

    private func summaryRow(_ key: String, _ value: String, step target: Int, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(s.t(key)).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                    Text(value.isEmpty ? s.t("common.none") : value)
                        .font(WJFont.subhead.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button(s.t("common.edit")) {
                    step = target
                    stage = .questions
                }
                .font(WJFont.label)
                .foregroundStyle(Theme.primaryText)
            }
            .padding(14)
            if !last { Divider().overlay(Theme.divider).padding(.horizontal, 14) }
        }
    }

    private var partyText: String {
        if answers.partyType == "GROUP" {
            var text = "\(s.t("wizard.group")) · \(s.t("wizard.visitors", "\(answers.partySize)"))"
            if answers.hasChildren == true { text += " · " + s.t("wizard.withKids") }
            return text
        }
        return "\(s.t("wizard.solo")) · \(s.t("wizard.oneVisitor"))"
    }

    private var breaksText: String {
        guard answers.wantsBreaks == true else { return s.t("wizard.noBreaks") }
        return ["PRAYER", "MEAL", "CHILD_REST"].filter { answers.breakTypes.contains($0) && ($0 != "CHILD_REST" || answers.hasChildren == true) }
            .map { s.label($0) }.joined(separator: " · ")
    }

    @Environment(ExpoStore.self) private var expo

    private var extraInterestsText: String {
        expo.interests.filter { answers.extraInterests.contains($0.id) }.map { s.interestName($0) }.joined(separator: " · ")
    }

    // OVL-PLAN-01: a plan for the same day is replaced (visited stops stay)
    private func confirmCreate() {
        let day = DateText.dayString(answers.date)
        if visitor.roadmaps.contains(where: { $0.visitDate?.hasPrefix(day) == true }) {
            app.ask(DialogModel(icon: "calendar.badge.exclamationmark", tone: .warning,
                                title: s.t("wizard.replaceTitle", DateText.shortDay(day, s)),
                                message: s.t("wizard.replaceMessage"),
                                primary: s.t("wizard.replaceConfirm"), secondary: s.t("wizard.keepCurrent"),
                                onPrimary: { startGenerate() }))
        } else {
            startGenerate()
        }
    }

    private func startGenerate() {
        generateError = nil
        stage = .generating
        let request = answers.request
        generateTask = Task {
            do {
                let roadmap = try await API.generate(request)
                if Task.isCancelled { await visitor.refreshRoadmaps(); return }
                visitor.replace(roadmap)
                Haptics.success()
                stage = .ready(roadmap.roadmapId)
                Task { await visitor.refreshAlerts() }
            } catch {
                if Task.isCancelled { return }
                generateError = AppState.message(error, s)
                stage = .summary
                Haptics.error()
            }
        }
    }

    // cancel only stops waiting; the request may still finish on the server
    private func cancelGenerate() {
        generateTask?.cancel()
        stage = .summary
        Task {
            try? await Task.sleep(for: .seconds(4))
            await visitor.refreshRoadmaps()
        }
    }
}

// ===== step 1: who is coming, breaks, accessibility =====
struct PartyStep: View {
    @Bindable var answers: PlanAnswers
    @Environment(AppSettings.self) private var s

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                EyebrowLabel(text: s.t("wizard.step1"))
                Text(s.t("wizard.whoTitle")).font(WJFont.title1).foregroundStyle(Theme.textPrimary)
                Text(s.t("wizard.whoSubtitle")).font(WJFont.subhead).foregroundStyle(Theme.textSecondary)
            }

            optionCard("SOLO", icon: "person", title: s.t("wizard.solo"), message: s.t("wizard.soloMessage"))
            optionCard("GROUP", icon: "person.2", title: s.t("wizard.group"), message: s.t("wizard.groupMessage"))

            if answers.partyType == "SOLO" {
                InfoNote(text: s.t("wizard.soloNote"), icon: "person")
            }

            if answers.partyType == "GROUP" {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.t("wizard.groupSize")).font(WJFont.headline).foregroundStyle(Theme.textPrimary)
                        Text(s.t("wizard.groupSizeHint")).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    SizeStepper(value: $answers.partySize, range: 2...20)
                }
                question(s.t("wizard.kidsQuestion"), hint: s.t("wizard.kidsHint")) {
                    ChoicePair(yes: s.t("common.yes"), no: s.t("common.no"), value: $answers.hasChildren)
                }
            }

            if answers.partyType != nil {
                question(s.t("wizard.breaksQuestion"), hint: s.t("wizard.breaksHint")) {
                    ChoicePair(yes: s.t("common.yes"), no: s.t("common.no"), value: $answers.wantsBreaks)
                }
                if answers.wantsBreaks == true {
                    question(s.t("wizard.breakTypes"), hint: nil) {
                        FlowLayout(spacing: 8) {
                            breakChip("PRAYER")
                            breakChip("MEAL")
                            if answers.partyType == "GROUP" && answers.hasChildren == true {
                                breakChip("CHILD_REST")
                            }
                        }
                    }
                } else if answers.wantsBreaks == false {
                    InfoNote(text: s.t("wizard.noBreaksNote"), icon: "clock")
                }

                question(s.t(answers.partyType == "GROUP" ? "wizard.needsQuestionGroup" : "wizard.needsQuestionSolo"), hint: s.t("wizard.needsHint")) {
                    ChoicePair(yes: s.t("common.yes"), no: s.t("common.no"), value: $answers.hasNeeds)
                }
                if answers.hasNeeds == true {
                    question(s.t("wizard.needsPick"), hint: nil) {
                        NeedPicker(selected: $answers.needs)
                    }
                    if answers.mobility {
                        InfoNote(text: s.t("wizard.mobilityNote"), icon: "figure.roll")
                    } else if !answers.needs.isEmpty {
                        InfoNote(text: s.t("wizard.needsNote"), icon: "info.circle")
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: answers.partyType)
        .animation(.easeInOut(duration: 0.2), value: answers.wantsBreaks)
        .animation(.easeInOut(duration: 0.2), value: answers.hasNeeds)
        .onChange(of: answers.partyType) { _, new in
            if new == "SOLO" { answers.hasChildren = nil; answers.breakTypes.remove("CHILD_REST") }
        }
        .onChange(of: answers.hasChildren) { _, new in
            if new != true { answers.breakTypes.remove("CHILD_REST") }
        }
    }

    private func optionCard(_ value: String, icon: String, title: String, message: String) -> some View {
        let on = answers.partyType == value
        return Button {
            withAnimation(.snappy) { answers.partyType = value }
            Haptics.tap()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 46, height: 46)
                    .background(Theme.surfaceRaised, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(WJFont.headline).foregroundStyle(Theme.textPrimary)
                    Text(message).font(WJFont.footnote).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(on ? Theme.primary : Theme.textTertiary)
            }
            .padding(16)
            .background(on ? Theme.primarySoft : Theme.surface, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous).stroke(on ? Theme.primary : Theme.border, lineWidth: on ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func breakChip(_ type: String) -> some View {
        WJChip(title: s.label(type), selected: answers.breakTypes.contains(type), compact: true) {
            if answers.breakTypes.contains(type) { answers.breakTypes.remove(type) } else { answers.breakTypes.insert(type) }
        }
    }

    private func question<C: View>(_ title: String, hint: String?, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(WJFont.headline).foregroundStyle(Theme.textPrimary)
                if let hint { Text(hint).font(WJFont.caption).foregroundStyle(Theme.textSecondary) }
            }
            content()
        }
    }
}

struct SizeStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 0) {
            button("minus", enabled: value > range.lowerBound) { value -= 1 }
            Text("\(value)")
                .font(WJFont.headline.monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
                .frame(minWidth: 36)
            button("plus", enabled: value < range.upperBound) { value += 1 }
        }
        .padding(4)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
        .environment(\.layoutDirection, .leftToRight)
    }

    private func button(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.tap()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(enabled ? Theme.textPrimary : Theme.textTertiary)
                .frame(width: 40, height: 40)
                .background(Theme.surfaceRaised, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// ===== step 2: date and time =====
struct DateStep: View {
    @Bindable var answers: PlanAnswers
    @Environment(AppSettings.self) private var s

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                EyebrowLabel(text: s.t("wizard.step2"))
                Text(s.t("wizard.whenTitle")).font(WJFont.title1).foregroundStyle(Theme.textPrimary)
            }

            pickerField(s.t("wizard.date")) {
                DatePicker("", selection: $answers.date, in: answers.minDate...PlanAnswers.lastDay, displayedComponents: .date)
            }
            pickerField(s.t("wizard.arrival")) {
                DatePicker("", selection: $answers.arrival, displayedComponents: .hourAndMinute)
            }
            pickerField(s.t("wizard.departure"), error: answers.minutes <= 0 ? s.t("wizard.departureAfter") : nil) {
                DatePicker("", selection: $answers.departure, displayedComponents: .hourAndMinute)
            }

            if answers.minutes > 0 {
                InfoNote(text: s.t("wizard.durationHint", "\(answers.minutes / 60)", "\(answers.minutes % 60)", answers.mobility ? "40" : "30"), icon: "clock")
            }
        }
    }

    private func pickerField<C: View>(_ label: String, error: String? = nil, @ViewBuilder picker: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(WJFont.label).foregroundStyle(Theme.textSecondary)
            HStack {
                picker()
                    .labelsHidden()
                    .environment(\.locale, s.locale)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: Metrics.fieldHeight)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(error == nil ? Theme.borderStrong : Theme.danger, lineWidth: 1))
            if let error {
                Text(error).font(WJFont.caption).foregroundStyle(Theme.danger)
            }
        }
    }
}

// ===== step 3: experience, pace, revisits =====
struct StyleStep: View {
    @Bindable var answers: PlanAnswers
    @Environment(AppSettings.self) private var s
    private let types = ["CULTURAL", "EDUCATIONAL", "ENTERTAINMENT", "RELAXATION", "CULINARY"]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                EyebrowLabel(text: s.t("wizard.step3"))
                Text(s.t("wizard.styleTitle")).font(WJFont.title1).foregroundStyle(Theme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(s.t("wizard.experienceType")).font(WJFont.headline).foregroundStyle(Theme.textPrimary)
                FlowLayout(spacing: 8) {
                    ForEach(types, id: \.self) { type in
                        WJChip(title: s.label(type), selected: answers.experiences.contains(type), compact: true) {
                            if answers.experiences.contains(type) { answers.experiences.remove(type) } else { answers.experiences.insert(type) }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(s.t("wizard.pace")).font(WJFont.headline).foregroundStyle(Theme.textPrimary)
                    Text(s.t("wizard.paceHint")).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                }
                HStack(spacing: 8) {
                    WJChip(title: s.label("RELAXED"), selected: answers.pace == "RELAXED", showsToggleIcon: answers.pace == "RELAXED", compact: true) { answers.pace = "RELAXED" }
                    WJChip(title: s.label("INTENSIVE"), selected: answers.pace == "INTENSIVE", showsToggleIcon: answers.pace == "INTENSIVE", compact: true) { answers.pace = "INTENSIVE" }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(s.t("wizard.revisitsQuestion")).font(WJFont.headline).foregroundStyle(Theme.textPrimary)
                    Text(s.t("wizard.revisitsHint")).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                }
                ChoicePair(yes: s.t("common.yes"), no: s.t("common.no"), value: $answers.allowRevisits)
            }
        }
    }
}

// ===== step 4: extra interests for this day =====
struct InterestsStep: View {
    @Bindable var answers: PlanAnswers
    @Environment(AppSettings.self) private var s
    @Environment(ExpoStore.self) private var expo
    @Environment(VisitorStore.self) private var visitor

    var body: some View {
        let mine = Set((visitor.info?.interests ?? []).map(\.id))
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                EyebrowLabel(text: s.t("wizard.step4"))
                Text(s.t("wizard.interestsTitle")).font(WJFont.title1).foregroundStyle(Theme.textPrimary)
                Text(s.t("wizard.interestsSubtitle")).font(WJFont.subhead).foregroundStyle(Theme.textSecondary)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text(s.t("wizard.fromProfile")).font(WJFont.label).foregroundStyle(Theme.textSecondary)
                FlowLayout(spacing: 8) {
                    ForEach(visitor.info?.interests ?? []) { interest in
                        WJChip(title: s.interestName(interest), selected: true, compact: true) {}
                            .allowsHitTesting(false)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text(s.t("wizard.addForToday")).font(WJFont.label).foregroundStyle(Theme.textSecondary)
                FlowLayout(spacing: 8) {
                    ForEach(expo.interests.filter { !mine.contains($0.id) }) { interest in
                        WJChip(title: s.interestName(interest), selected: answers.extraInterests.contains(interest.id), compact: true) {
                            if answers.extraInterests.contains(interest.id) { answers.extraInterests.remove(interest.id) } else { answers.extraInterests.insert(interest.id) }
                        }
                    }
                }
            }
        }
    }
}

// PLAN-06: full screen wait while the AI builds the plan (steps are cosmetic)
struct GeneratingView: View {
    let onCancel: () -> Void
    @Environment(AppSettings.self) private var s
    @State private var phase = 0
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "sparkle")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Theme.accent)
                .scaleEffect(pulse ? 1.15 : 0.9)
                .rotationEffect(.degrees(pulse ? 20 : -10))
            Text(s.t("generating.title")).font(WJFont.title2).foregroundStyle(Theme.textPrimary)
            Text(s.t("generating.subtitle"))
                .font(WJFont.subhead)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            VStack(alignment: .leading, spacing: 12) {
                stepLine(0, "generating.step1")
                stepLine(1, "generating.step2")
                stepLine(2, "generating.step3")
            }
            .padding(.top, 10)
            Spacer()
            Button(s.t("common.cancel"), action: onCancel)
                .buttonStyle(.wjTertiary)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .screenBackground(.lime)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            withAnimation(.easeInOut(duration: 1.1).repeatForever()) { pulse = true }
            for i in 1...3 {
                try? await Task.sleep(for: .seconds(1.6))
                withAnimation { phase = i }
            }
        }
    }

    private func stepLine(_ index: Int, _ key: String) -> some View {
        HStack(spacing: 10) {
            Group {
                if phase > index {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.success)
                } else if phase == index {
                    ProgressView().controlSize(.small).tint(Theme.accent)
                } else {
                    Image(systemName: "circle").foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(width: 20)
            Text(s.t(key))
                .font(WJFont.subhead)
                .foregroundStyle(phase >= index ? Theme.textPrimary : Theme.textTertiary)
        }
    }
}
