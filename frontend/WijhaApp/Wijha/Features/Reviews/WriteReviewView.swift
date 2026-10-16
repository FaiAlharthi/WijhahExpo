import SwiftUI

// REV-01 / REV-02: rate 1–5, an optional comment and (for trips with needs) the accessibility verdict
struct WriteReviewView: View {
    let pavilionId: Int
    let reviewId: Int?
    var initialRating: Int = 0

    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(ExpoStore.self) private var expo
    @Environment(VisitorStore.self) private var visitor
    @Environment(\.dismiss) private var dismiss

    @State private var rating = 0
    @State private var comment = ""
    @State private var verdict: String?
    @State private var saving = false
    @State private var error: String?
    @State private var loaded = false
    @FocusState private var commentFocused: Bool

    private let limit = 500

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(s.t(reviewId == nil ? "review.title" : "review.editTitle", s.pavilionName(expo.pavilion(pavilionId)?.name)))
                            .font(WJFont.title1)
                            .foregroundStyle(Theme.textPrimary)
                        if let visitedLine {
                            Text(visitedLine).font(WJFont.footnote).foregroundStyle(Theme.textSecondary)
                        }
                    }

                    VStack(spacing: 8) {
                        StarRatingInput(rating: $rating, size: 34)
                        Text(ratingLabel)
                            .font(WJFont.subhead.weight(.semibold))
                            .foregroundStyle(rating == 0 ? Theme.textTertiary : Theme.textPrimary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(s.t("review.commentLabel")).font(WJFont.label).foregroundStyle(Theme.textSecondary)
                        TextField(s.t("review.commentPlaceholder"), text: $comment, axis: .vertical)
                            .lineLimit(3...5)
                            .font(WJFont.body)
                            .foregroundStyle(Theme.textPrimary)
                            .focused($commentFocused)
                            .padding(14)
                            .frame(minHeight: 110, alignment: .top)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(commentFocused ? Theme.accent : Theme.borderStrong, lineWidth: commentFocused ? 1.6 : 1))
                            .onChange(of: comment) { _, new in
                                if new.count > limit { comment = String(new.prefix(limit)) }
                            }
                        HStack {
                            Text(s.t("review.publicHint")).font(WJFont.caption).foregroundStyle(Theme.textTertiary)
                            Spacer()
                            Text("\(comment.count) / \(limit)").font(WJFont.caption.monospacedDigit()).foregroundStyle(Theme.textTertiary)
                                .environment(\.layoutDirection, .leftToRight)
                        }
                    }

                    if !tripNeeds.isEmpty {
                        verdictCard
                    }

                    if let error {
                        InfoNote(text: error, icon: "exclamationmark.triangle.fill", tone: .danger)
                    }
                }
                .padding(.horizontal, Metrics.margin)
                .padding(.top, 4)
                .padding(.bottom, 24)
                .maxContentWidth()
            }
            .scrollDismissesKeyboard(.interactively)

            Button {
                Task { await submit() }
            } label: {
                HStack { if saving { ProgressView().tint(.white) }; Text(s.t(reviewId == nil ? "review.send" : "review.saveEdit")) }
            }
            .buttonStyle(.wjPrimary)
            .disabled(rating == 0 || saving)
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
                    Image(systemName: "xmark").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                        .frame(width: Metrics.touch, height: Metrics.touch)
                }
            }
        }
        .onAppear { prefill() }
    }

    // trip needs: from the latest plan where this pavilion was visited (the backend falls back the same way)
    private var tripNeeds: [String] {
        if let mine = existing, let needs = mine.accessibilityNeeds, !needs.isEmpty { return AccessNeed.sorted(needs) }
        let plan = visitor.roadmaps
            .filter { $0.stops?.contains { $0.pavilionId == pavilionId } == true }
            .sorted { ($0.visitDate ?? "") > ($1.visitDate ?? "") }
            .first
        return plan?.needs ?? []
    }

    private var existing: ReviewDTO? {
        guard let reviewId else { return nil }
        return visitor.myReviews.first { $0.id == reviewId }
    }

    private var visitedLine: String? {
        guard let visit = (visitor.passport?.visits ?? []).filter({ $0.pavilionId == pavilionId }).max(by: { ($0.visitedAt ?? "") < ($1.visitedAt ?? "") }) else { return nil }
        return s.t("review.visitedAt", DateText.weekdayDay(visit.visitedAt, s), DateText.clock12(DateText.clock(visit.visitedAt), s))
    }

    private var ratingLabel: String {
        switch rating {
        case 1: return s.t("review.r1")
        case 2: return s.t("review.r2")
        case 3: return s.t("review.r3")
        case 4: return s.t("review.r4")
        case 5: return s.t("review.r5")
        default: return s.t("review.tapToRate")
        }
    }

    private var verdictCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(s.t("review.verdictQuestion")).font(WJFont.headline).foregroundStyle(Theme.textPrimary)
            Text(s.t("review.verdictFor", tripNeeds.map { s.label($0) }.joined(separator: "، ")))
                .font(WJFont.caption)
                .foregroundStyle(Theme.textSecondary)
            HStack(spacing: 8) {
                verdictButton("SUITABLE")
                verdictButton("PARTIAL")
                verdictButton("NOT_SUITABLE")
            }
            Text(s.t("review.verdictHint")).font(WJFont.caption).foregroundStyle(Theme.textTertiary)
        }
        .card(padding: 14)
    }

    private func verdictButton(_ value: String) -> some View {
        let on = verdict == value
        let tone = AccessStatus.tone(value)
        return Button {
            verdict = on ? nil : value
        } label: {
            Text(s.label(value))
                .font(WJFont.footnote.weight(.bold))
                .foregroundStyle(on ? .white : Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(on ? (value == "PARTIAL" ? Theme.primary : tone.foreground) : Color.clear, in: Capsule())
                .overlay(Capsule().stroke(on ? .clear : Theme.borderStrong, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func prefill() {
        guard !loaded else { return }
        loaded = true
        if let mine = existing {
            rating = mine.rating ?? initialRating
            comment = mine.comment ?? ""
            verdict = mine.accessibilityVerdict
        } else {
            rating = initialRating
        }
    }

    private func close() {
        if !comment.isEmpty && reviewId == nil {
            app.ask(DialogModel(icon: "xmark", tone: .warning, title: s.t("review.discardTitle"), message: nil,
                                primary: s.t("wizard.discard"), primaryRole: .destructive, secondary: s.t("wizard.keepEditing"),
                                onPrimary: { dismiss() }))
        } else {
            dismiss()
        }
    }

    private func submit() async {
        saving = true
        defer { saving = false }
        error = nil
        let text = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        var body = ReviewBody(rating: rating, comment: text.isEmpty ? nil : text)
        if let verdict, !tripNeeds.isEmpty {
            body.accessibilityVerdict = verdict
            body.accessibilityNeeds = tripNeeds
        }
        do {
            if let reviewId {
                try await API.updateReview(reviewId, body)
            } else {
                try await API.addReview(pavilionId, body)
            }
            await visitor.refreshReviews()
            Haptics.success()
            // REV-03: toast, and the journey offers "حدّث خطتي" when the pavilion is in today's plan
            app.show(s.t(reviewId == nil ? "review.published" : "review.updated"), icon: "star.fill")
            dismiss()
        } catch {
            self.error = AppState.message(error, s)
            Haptics.error()
        }
    }
}
