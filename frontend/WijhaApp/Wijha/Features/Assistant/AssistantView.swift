import SwiftUI

struct ChatLine: Identifiable, Equatable {
    let id = UUID()
    let fromUser: Bool
    let text: String
    var failed = false
}

// AST-01 / AST-02: chat about pavilions, zones, gates and today's plan. History lives only in the open session.
struct AssistantView: View {
    @Environment(AppSettings.self) private var s
    @Environment(ExpoStore.self) private var expo
    @Environment(Router.self) private var router
    @State private var lines: [ChatLine] = []
    @State private var suggestions: [String] = []
    @State private var input = ""
    @State private var thinking = false
    @FocusState private var focused: Bool
    private let limit = 500

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(s.t("assistant.sessionNote"), systemImage: "lock")
                            .font(WJFont.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(Theme.surface.opacity(0.7), in: Capsule())

                        if lines.isEmpty {
                            intro
                        }
                        ForEach(lines) { line in
                            bubble(line).id(line.id)
                        }
                        if thinking {
                            TypingDots().id("typing")
                        }
                        if !lines.isEmpty && !thinking && !suggestions.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(s.t("assistant.suggestions")).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                                ForEach(suggestions.prefix(3), id: \.self) { q in suggestionChip(q) }
                            }
                            .padding(.top, 6)
                        }
                    }
                    .padding(.horizontal, Metrics.margin)
                    .padding(.vertical, 12)
                    .maxContentWidth()
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: lines.count) {
                    withAnimation { proxy.scrollTo(lines.last?.id, anchor: .bottom) }
                }
                .onChange(of: thinking) {
                    if thinking { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
                }
            }
            composer
        }
        .screenBackground()
        .wjTopBar(s.t("assistant.title"), close: true)
        .task { await loadSuggestions() }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 12) {
                WijhaMark(size: 64)
                Text(s.t("assistant.hello")).font(WJFont.title2).foregroundStyle(Theme.textPrimary)
                Text(s.t("assistant.helloMessage"))
                    .font(WJFont.subhead)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
            if !suggestions.isEmpty {
                Text(s.t("assistant.suggested")).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                ForEach(suggestions, id: \.self) { q in suggestionChip(q) }
            }
        }
    }

    private func suggestionChip(_ q: String) -> some View {
        Button {
            Task { await send(q) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkle").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.accent)
                Text(q).font(WJFont.footnote.weight(.semibold)).foregroundStyle(Theme.textPrimary).multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func bubble(_ line: ChatLine) -> some View {
        if line.fromUser {
            HStack {
                Spacer(minLength: 50)
                Text(line.text)
                    .font(WJFont.subhead)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.primary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(line.text)
                    .font(WJFont.subhead)
                    .foregroundStyle(line.failed ? Theme.danger : Theme.textPrimary)
                    .textSelection(.enabled)
                let linked = mentionedPavilions(line.text)
                if !linked.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(linked) { pavilion in
                            Button { router.push(.pavilion(pavilion.id)) } label: {
                                HStack(spacing: 4) {
                                    Text(s.pavilionName(pavilion.name))
                                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)).flipsForRightToLeftLayoutDirection(true)
                                }
                                .font(WJFont.caption.weight(.bold))
                                .foregroundStyle(Theme.primaryText)
                                .padding(.horizontal, 10)
                                .frame(height: 28)
                                .background(Theme.primarySoft, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.border, lineWidth: 1))
            .padding(.trailing, 40)
        }
    }

    private func mentionedPavilions(_ text: String) -> [Pavilion] {
        expo.pavilions.filter { p in
            let ar = s.pavilionName(p.name)
            let country = PavilionNames.arabicCountries[p.country ?? ""] ?? ""
            return text.localizedCaseInsensitiveContains(p.name) || (!ar.isEmpty && text.contains(ar)) || (!country.isEmpty && text.contains("جناح \(country)"))
        }
        .prefix(3)
        .map { $0 }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                TextField(s.t("assistant.placeholder"), text: $input, axis: .vertical)
                    .lineLimit(1...4)
                    .font(WJFont.body)
                    .focused($focused)
                    .onChange(of: input) { _, new in if new.count > limit { input = String(new.prefix(limit)) } }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(focused ? Theme.accent : Theme.borderStrong, lineWidth: 1))
                Button {
                    let q = input
                    input = ""
                    Task { await send(q) }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(canSend ? .white : Theme.textTertiary)
                        .flipsForRightToLeftLayoutDirection(true)
                        .frame(width: 44, height: 44)
                        .background(canSend ? Theme.primary : Theme.surfaceRaised, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
            if !input.isEmpty {
                Text("\(input.count) / \(limit)").font(WJFont.caption.monospacedDigit()).foregroundStyle(Theme.textTertiary).padding(.leading, 8)
            }
        }
        .padding(.horizontal, Metrics.margin)
        .padding(.vertical, 10)
        .background(Theme.canvas.opacity(0.95))
    }

    private var canSend: Bool { !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !thinking }

    private func loadSuggestions() async {
        let result = try? await API.chatSuggestions()
        suggestions = result?.questions ?? []
    }

    private func send(_ question: String) async {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !thinking else { return }
        let history = lines.filter { !$0.failed }.suffix(10).map { ChatMessageBody(role: $0.fromUser ? "USER" : "BOT", text: $0.text) }
        withAnimation { lines.append(ChatLine(fromUser: true, text: q)) }
        thinking = true
        defer { thinking = false }
        do {
            let answer = try await API.ask(ChatRequest(question: q, history: Array(history)))
            withAnimation { lines.append(ChatLine(fromUser: false, text: answer.answer ?? s.t("assistant.noAnswer"))) }
        } catch {
            withAnimation { lines.append(ChatLine(fromUser: false, text: AppState.message(error, s), failed: true)) }
        }
    }
}

struct TypingDots: View {
    @State private var phase = 0
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Theme.textSecondary)
                    .frame(width: 7, height: 7)
                    .opacity(phase == i ? 1 : 0.35)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Theme.surface, in: Capsule())
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(350))
                phase = (phase + 1) % 3
            }
        }
    }
}
