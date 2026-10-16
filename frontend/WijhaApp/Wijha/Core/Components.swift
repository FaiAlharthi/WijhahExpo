import SwiftUI
import UIKit

// ===== tones used by badges, notes, toasts and dialogs =====
enum BadgeTone {
    case neutral, info, primary, success, warning, danger, lime, star

    var foreground: Color {
        switch self {
        case .neutral: return Theme.textSecondary
        case .info: return Theme.info
        case .primary: return Theme.primaryText
        case .success: return Theme.success
        case .warning: return Theme.warning
        case .danger: return Theme.danger
        case .lime: return Theme.textOnLime
        case .star: return Color.dynamic(dark: Palette.amber300, light: Palette.amber700)
        }
    }

    var background: Color {
        switch self {
        case .neutral: return Theme.surfaceSunken
        case .info: return Theme.infoSoft
        case .primary: return Theme.primarySoft
        case .success: return Theme.successSoft
        case .warning: return Theme.warningSoft
        case .danger: return Theme.dangerSoft
        case .lime: return Theme.accentFill
        case .star: return Theme.warningSoft
        }
    }
}

// small pill with icon + words (STATUS component)
struct StatusBadge: View {
    let text: String
    var icon: String? = nil
    var tone: BadgeTone = .primary
    var compact = false

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: compact ? 9 : 10, weight: .bold))
            }
            Text(text)
                .font(compact ? WJFont.micro : WJFont.captionBold)
                .lineLimit(1)
        }
        .foregroundStyle(tone.foreground)
        .padding(.horizontal, compact ? 7 : 9)
        .padding(.vertical, compact ? 3 : 4)
        .background(tone.background, in: Capsule())
    }
}

// the status of a pavilion for the signed in visitor
struct PavilionStatusBadge: View {
    let status: PavilionStatus
    var compact = true
    @Environment(AppSettings.self) private var s

    var body: some View {
        switch status {
        case .none: EmptyView()
        case .next: StatusBadge(text: s.t("status.next"), icon: "location.north.fill", tone: .lime, compact: compact)
        case .inPlan: StatusBadge(text: s.t("status.inPlan"), icon: "point.topleft.down.to.point.bottomright.curvepath", tone: .primary, compact: compact)
        case .visited: StatusBadge(text: s.t("status.visited"), icon: "checkmark.circle", tone: .success, compact: compact)
        case .reviewed: StatusBadge(text: s.t("status.reviewed"), icon: "star.fill", tone: .star, compact: compact)
        }
    }
}

// expected queue badge
struct CrowdBadge: View {
    let minutes: Int?
    var level: String? = nil
    var compact = true
    @Environment(AppSettings.self) private var s

    var body: some View {
        if let minutes {
            let lvl = level ?? CrowdLevel.level(forWait: minutes)
            StatusBadge(
                text: minutes == 0 ? s.t("crowd.noQueue") : s.t("crowd.waitShort", "\(minutes)"),
                icon: CrowdLevel.icon(lvl),
                tone: CrowdLevel.tone(lvl),
                compact: compact
            )
        }
    }
}

// accessibility status pill: "✓ متاح"
struct AccessBadge: View {
    let status: String
    var compact = true
    @Environment(AppSettings.self) private var s
    var body: some View {
        StatusBadge(text: AccessStatus.title(status, s), icon: AccessStatus.icon(status), tone: AccessStatus.tone(status), compact: compact)
    }
}

// ===== screen background: canvas with the blue glow at the top =====
struct ScreenBackground: ViewModifier {
    var glow: GlowStyle = .blue

    func body(content: Content) -> some View {
        content
            .background {
                ZStack(alignment: .top) {
                    Theme.canvas
                    switch glow {
                    case .none:
                        EmptyView()
                    case .blue:
                        LinearGradient(colors: [Theme.glowTop, Theme.glowMid, Theme.canvas.opacity(0)], startPoint: .top, endPoint: .bottom)
                            .frame(height: 300)
                            .overlay(alignment: .topLeading) {
                                RadialGradient(colors: [Theme.glowTop.opacity(0.9), .clear], center: .topLeading, startRadius: 0, endRadius: 280)
                                    .frame(height: 300)
                            }
                    case .lime:
                        RadialGradient(colors: [Palette.lime500.opacity(0.85), Palette.lime600.opacity(0.25), .clear], center: .topLeading, startRadius: 0, endRadius: 360)
                            .frame(height: 360)
                    case .green:
                        RadialGradient(colors: [Palette.green500.opacity(0.80), Palette.green700.opacity(0.28), .clear], center: .top, startRadius: 0, endRadius: 420)
                            .frame(height: 420)
                    }
                }
                .ignoresSafeArea()
            }
    }
}

enum GlowStyle { case none, blue, lime, green }

extension View {
    func screenBackground(_ glow: GlowStyle = .blue) -> some View { modifier(ScreenBackground(glow: glow)) }

    // dark navy card with a subtle border
    func card(padding: CGFloat = 16, radius: CGFloat = Metrics.cardRadius, fill: Color = Theme.surface, stroke: Color = Theme.border) -> some View {
        self
            .padding(padding)
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(stroke, lineWidth: 1))
    }

    func maxContentWidth() -> some View {
        frame(maxWidth: Metrics.maxContentWidth).frame(maxWidth: .infinity)
    }
}

// ===== buttons =====
enum WJButtonKind { case primary, secondary, tertiary, destructive, lime, ghost }

struct WJButtonStyle: ButtonStyle {
    var kind: WJButtonKind = .primary
    var height: CGFloat = Metrics.buttonHeight
    var fullWidth = true
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(height < 44 ? WJFont.label : WJFont.button)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, height < 44 ? 14 : 20)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: height)
            .foregroundStyle(foreground)
            .background(background(configuration.isPressed), in: Capsule())
            .overlay {
                if kind == .secondary || kind == .ghost {
                    Capsule().stroke(enabled ? Theme.borderStrong : Theme.border, lineWidth: 1.2)
                }
            }
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }

    private var foreground: Color {
        guard enabled else { return Theme.textTertiary }
        switch kind {
        case .primary, .destructive: return .white
        case .lime: return Theme.textOnLime
        case .secondary, .ghost: return Theme.textPrimary
        case .tertiary: return Theme.primaryText
        }
    }

    private func background(_ pressed: Bool) -> Color {
        guard enabled else { return kind == .tertiary || kind == .ghost ? .clear : Theme.surfaceRaised }
        switch kind {
        case .primary: return pressed ? Theme.primaryPressed : Theme.primary
        case .destructive: return pressed ? Palette.red700 : Theme.danger
        case .lime: return pressed ? Palette.lime600 : Palette.lime500
        case .secondary: return pressed ? Theme.surfaceRaised : .clear
        case .ghost: return pressed ? Theme.surfaceRaised : Theme.surface.opacity(0.6)
        case .tertiary: return .clear
        }
    }
}

extension ButtonStyle where Self == WJButtonStyle {
    static var wjPrimary: WJButtonStyle { WJButtonStyle(kind: .primary) }
    static var wjSecondary: WJButtonStyle { WJButtonStyle(kind: .secondary) }
    static var wjTertiary: WJButtonStyle { WJButtonStyle(kind: .tertiary, height: 44) }
    static var wjDestructive: WJButtonStyle { WJButtonStyle(kind: .destructive) }
    static func wj(_ kind: WJButtonKind, height: CGFloat = Metrics.buttonHeight, fullWidth: Bool = true) -> WJButtonStyle {
        WJButtonStyle(kind: kind, height: height, fullWidth: fullWidth)
    }
}

// round icon button used in the top bars and on the map ("glass")
struct CircleIconButton: View {
    let icon: String
    var size: CGFloat = 40
    var filled = true
    var flips = false
    var label: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .semibold))
                .flipsForRightToLeftLayoutDirection(flips)
                .foregroundStyle(Theme.textPrimary)
                .frame(width: size, height: size)
                .background {
                    if filled {
                        Circle().fill(.ultraThinMaterial)
                        Circle().fill(Theme.surface.opacity(0.55))
                    }
                }
                .overlay(Circle().stroke(Theme.border.opacity(filled ? 1 : 0), lineWidth: 1))
                .frame(minWidth: Metrics.touch, minHeight: Metrics.touch)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// ===== chips =====
struct WJChip: View {
    let title: String
    var icon: String? = nil
    var selected: Bool
    var showsToggleIcon = true
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if showsToggleIcon {
                    Image(systemName: selected ? "checkmark" : "plus")
                        .font(.system(size: 11, weight: .bold))
                }
                if let icon {
                    Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                }
                Text(title)
                    .font(compact ? WJFont.footnote.weight(.semibold) : WJFont.label)
                    .lineLimit(1)
            }
            .foregroundStyle(selected ? Color.white : Theme.textPrimary)
            .padding(.horizontal, compact ? 12 : 14)
            .frame(height: compact ? 34 : 40)
            .background(selected ? Theme.primary : Theme.surface, in: Capsule())
            .overlay(Capsule().stroke(selected ? Color.clear : Theme.border, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// two or three segments ("glass" switch): خريطة / قائمة, توضيحية / مصوّرة
struct SegmentedPill<T: Hashable>: View {
    let options: [(T, String, String?)]   // value, title, icon
    @Binding var selection: T
    var height: CGFloat = 36

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.0) { option in
                let on = option.0 == selection
                Button {
                    withAnimation(.snappy(duration: 0.25)) { selection = option.0 }
                } label: {
                    HStack(spacing: 5) {
                        if let icon = option.2 {
                            Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                        }
                        Text(option.1).font(WJFont.footnote.weight(.bold))
                    }
                    .foregroundStyle(on ? Palette.ink900 : Theme.textPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: height - 6)
                    .background {
                        if on { Capsule().fill(Color.white).shadow(color: .black.opacity(0.15), radius: 3, y: 1) }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background {
            Capsule().fill(.ultraThinMaterial)
            Capsule().fill(Theme.surface.opacity(0.6))
        }
        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
    }
}

// yes / no segmented answer used in the wizard
struct ChoicePair: View {
    let yes: String
    let no: String
    @Binding var value: Bool?

    var body: some View {
        HStack(spacing: 10) {
            choice(yes, true)
            choice(no, false)
        }
    }

    private func choice(_ title: String, _ v: Bool) -> some View {
        let on = value == v
        return Button {
            withAnimation(.snappy(duration: 0.2)) { value = v }
        } label: {
            HStack(spacing: 6) {
                if on { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)) }
                Text(title).font(WJFont.label)
            }
            .foregroundStyle(on ? .white : Theme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(on ? Theme.primary : Theme.surfaceSunken, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(on ? .clear : Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

// ===== text field with a label above (FIELD) =====
struct WJTextField: View {
    let label: String
    @Binding var text: String
    var placeholder = ""
    var secure = false
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var error: String? = nil
    var disabled = false
    var forceLTR = false
    var submitLabel: SubmitLabel = .next
    var onSubmit: () -> Void = {}

    @FocusState private var focused: Bool
    @State private var reveal = false
    @Environment(\.layoutDirection) private var direction

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(WJFont.label)
                .foregroundStyle(Theme.textSecondary)
            HStack(spacing: 8) {
                Group {
                    if secure && !reveal {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .font(WJFont.body)
                .foregroundStyle(disabled ? Theme.textTertiary : Theme.textPrimary)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(submitLabel)
                .onSubmit(onSubmit)
                .focused($focused)
                .disabled(disabled)
                .environment(\.layoutDirection, forceLTR ? .leftToRight : direction)

                if secure {
                    Button { reveal.toggle() } label: {
                        Image(systemName: reveal ? "eye.slash" : "eye")
                            .foregroundStyle(Theme.textTertiary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: Metrics.fieldHeight)
            .background(disabled ? Theme.surfaceSunken : Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(error != nil ? Theme.danger : (focused ? Theme.accent : Theme.borderStrong), lineWidth: focused || error != nil ? 1.6 : 1)
            )
            if let error {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(WJFont.caption)
                    .foregroundStyle(Theme.danger)
            }
        }
    }
}

// ===== notes and banners =====
struct InfoNote: View {
    let text: String
    var icon = "info.circle"
    var tone: BadgeTone = .info
    var title: String? = nil
    var actionTitle: String? = nil
    var action: () -> Void = {}

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tone.foreground)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                if let title {
                    Text(title).font(WJFont.label).foregroundStyle(Theme.textPrimary)
                }
                Text(text)
                    .font(WJFont.footnote)
                    .foregroundStyle(title == nil ? Theme.textPrimary.opacity(0.9) : Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let actionTitle {
                    Button(actionTitle, action: action)
                        .font(WJFont.label)
                        .foregroundStyle(Theme.primaryText)
                        .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(tone.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(tone.foreground.opacity(0.18), lineWidth: 1))
    }
}

// ===== progress =====
struct StepProgress: View {
    let total: Int
    let current: Int   // 1 based

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...max(total, 1), id: \.self) { index in
                Capsule()
                    .fill(index <= current ? Theme.primary : Theme.border)
                    .frame(height: 4)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: current)
        .accessibilityElement()
        .accessibilityLabel("\(current) / \(total)")
    }
}

struct LinearMeter: View {
    let value: Double   // 0...1
    var tint: Color = Theme.primary
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.border)
                Capsule().fill(tint).frame(width: max(height, geo.size.width * min(max(value, 0), 1)))
            }
        }
        .frame(height: height)
    }
}

// ===== stars =====
struct StarsView: View {
    let rating: Double
    var size: CGFloat = 12

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: Double(i) <= rating + 0.25 ? "star.fill" : (Double(i) - 0.5 <= rating ? "star.leadinghalf.filled" : "star"))
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(Double(i) - 0.5 <= rating ? Theme.star : Theme.textTertiary)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityLabel(String(format: "%.1f", rating))
    }
}

struct StarRatingInput: View {
    @Binding var rating: Int
    var size: CGFloat = 36

    var body: some View {
        HStack(spacing: 10) {
            ForEach(1...5, id: \.self) { i in
                Button {
                    withAnimation(.spring(duration: 0.25)) { rating = i }
                    Haptics.tap()
                } label: {
                    Image(systemName: i <= rating ? "star.fill" : "star")
                        .font(.system(size: size, weight: .medium))
                        .foregroundStyle(i <= rating ? Theme.star : Theme.textTertiary)
                        .scaleEffect(i == rating ? 1.1 : 1)
                        .frame(minWidth: Metrics.touch, minHeight: Metrics.touch)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(i)")
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }
}

// ===== images =====
struct RemoteImage: View {
    let url: String?
    var cornerRadius: CGFloat = 12
    var iconSize: CGFloat = 18

    var body: some View {
        // a fixed slot that the image fills and is clipped to, so it never spills over neighbours
        Rectangle()
            .fill(Theme.surfaceSunken)
            .overlay {
                AsyncImage(url: APIClient.shared.resolveImageURL(url), transaction: Transaction(animation: .easeOut(duration: 0.25))) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(colors: [Palette.blue700, Palette.blue900], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "photo")
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
        }
    }
}

// ===== loading, empty and error states (STATE) =====
struct LoadingView: View {
    var text: String? = nil
    var body: some View {
        VStack(spacing: 12) {
            ProgressView().tint(Theme.primaryText).controlSize(.large)
            if let text {
                Text(text).font(WJFont.footnote).foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct SkeletonCard: View {
    var height: CGFloat = 88
    @State private var shimmer = false
    var body: some View {
        RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
            .fill(Theme.surface)
            .frame(height: height)
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                    .fill(LinearGradient(colors: [.clear, Theme.textPrimary.opacity(0.06), .clear], startPoint: .leading, endPoint: .trailing))
                    .offset(x: shimmer ? 300 : -300)
            )
            .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
            .onAppear {
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) { shimmer = true }
            }
            .accessibilityHidden(true)
    }
}

struct SkeletonList: View {
    var count = 4
    var height: CGFloat = 88
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<count, id: \.self) { _ in SkeletonCard(height: height) }
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: () -> Void = {}

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.primarySoft).frame(width: 76, height: 76)
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)
            }
            Text(title)
                .font(WJFont.title3)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(WJFont.subhead)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(.wj(.primary, height: 48, fullWidth: false))
                    .padding(.top, 6)
            }
        }
        .padding(.vertical, 36)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }
}

struct ErrorStateView: View {
    let message: String
    var retry: (() -> Void)? = nil
    @Environment(AppSettings.self) private var s

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.warning)
            Text(s.t("error.title"))
                .font(WJFont.headline)
                .foregroundStyle(Theme.textPrimary)
            Text(message)
                .font(WJFont.footnote)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            if let retry {
                Button(s.t("common.retry"), action: retry)
                    .buttonStyle(.wj(.secondary, height: 44, fullWidth: false))
            }
        }
        .frame(maxWidth: .infinity)
        .card(padding: 20)
    }
}

// ===== section title =====
struct SectionTitle: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: () -> Void = {}

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(WJFont.title3)
                    .foregroundStyle(Theme.textPrimary)
                if let subtitle {
                    Text(subtitle).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
            if let actionTitle {
                Button(actionTitle, action: action)
                    .font(WJFont.label)
                    .foregroundStyle(Theme.primaryText)
            }
        }
    }
}

// small lime label above titles: "الخطوة 1 من 4 · المرافقون"
struct EyebrowLabel: View {
    let text: String
    var icon: String? = nil
    var body: some View {
        HStack(spacing: 5) {
            if let icon { Image(systemName: icon).font(.system(size: 11, weight: .bold)) }
            Text(text).font(WJFont.captionBold)
        }
        .foregroundStyle(Theme.accent)
    }
}

// ===== top bar used by pushed screens: back arrow, title, trailing actions =====
struct WJTopBar<Trailing: View>: ViewModifier {
    let title: String
    var showsBack = true
    var close = false
    @ViewBuilder var trailing: () -> Trailing
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        if showsBack {
                            Button { dismiss() } label: {
                                Image(systemName: close ? "xmark" : "arrow.left")
                                    .font(.system(size: 17, weight: .semibold))
                                    .flipsForRightToLeftLayoutDirection(true)
                                    .foregroundStyle(Theme.textPrimary)
                                    .frame(width: Metrics.touch, height: Metrics.touch)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("Back")
                        }
                        Text(title)
                            .font(WJFont.headline)
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    trailing()
                }
            }
    }
}

extension View {
    func wjTopBar(_ title: String, showsBack: Bool = true, close: Bool = false) -> some View {
        modifier(WJTopBar(title: title, showsBack: showsBack, close: close) { EmptyView() })
    }

    func wjTopBar<T: View>(_ title: String, showsBack: Bool = true, close: Bool = false, @ViewBuilder trailing: @escaping () -> T) -> some View {
        modifier(WJTopBar(title: title, showsBack: showsBack, close: close, trailing: trailing))
    }

    // bottom sheet look: drag handle, raised surface, 28 radius.
    // Re-asserts the language's layout direction, since presented sheets don't
    // reliably inherit a forced layoutDirection from the app root.
    func wjSheet(_ detents: Set<PresentationDetent> = [.medium, .large]) -> some View {
        modifier(WJSheetChrome(detents: detents))
    }
}

struct WJSheetChrome: ViewModifier {
    let detents: Set<PresentationDetent>
    @Environment(AppSettings.self) private var s
    func body(content: Content) -> some View {
        content
            .environment(\.layoutDirection, s.layoutDirection)
            .presentationDetents(detents)
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(Theme.sheet)
    }
}

// title row inside sheets: ✕ on one side, title on the other
struct SheetHeader: View {
    let title: String
    var subtitle: String? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(WJFont.title3).foregroundStyle(Theme.textPrimary)
                if let subtitle {
                    Text(subtitle).font(WJFont.footnote).foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Theme.surfaceSunken, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 22)
    }
}

// ===== flow layout for chips =====
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat? = nil

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + (lineSpacing ?? spacing)
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + (lineSpacing ?? spacing)
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// ===== accessibility needs picker and icons =====
struct NeedPicker: View {
    @Binding var selected: Set<String>
    @Environment(AppSettings.self) private var s

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(AccessNeed.all, id: \.self) { need in
                WJChip(title: s.label(need), selected: selected.contains(need), compact: true) {
                    if selected.contains(need) { selected.remove(need) } else { selected.insert(need) }
                }
            }
        }
    }
}

struct NeedIcons: View {
    let needs: [String]
    var color: Color = Theme.primaryText
    var body: some View {
        HStack(spacing: 4) {
            ForEach(needs, id: \.self) { need in
                Image(systemName: AccessNeed.icon(need))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 22, height: 22)
                    .background(color.opacity(0.14), in: Circle())
            }
        }
    }
}

// ===== stat column used on the passport cover and the stamp screen =====
struct StatColumn: View {
    let value: String
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(WJFont.stat)
                .foregroundStyle(Theme.textPrimary)
                .environment(\.layoutDirection, .leftToRight)
            Text(label)
                .font(WJFont.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }
}

// ===== toast and dialog hosts (above everything, including the tab bar) =====
struct ToastHost: View {
    @Environment(AppState.self) private var app

    var body: some View {
        VStack {
            Spacer()
            if let toast = app.toast {
                HStack(spacing: 10) {
                    Image(systemName: toast.icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(toast.tone == .danger ? Theme.danger : Palette.mint500)
                    Text(toast.text)
                        .font(WJFont.label)
                        .foregroundStyle(Palette.ink50)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 13)
                .background(Palette.ink800, in: Capsule())
                .overlay(Capsule().stroke(Palette.ink600, lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 16, y: 6)
                .padding(.horizontal, Metrics.margin)
                .padding(.bottom, 110)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .id(toast.id)
                .task(id: toast.id) {
                    try? await Task.sleep(for: .seconds(2.6))
                    withAnimation(.easeOut(duration: 0.25)) {
                        if app.toast?.id == toast.id { app.toast = nil }
                    }
                }
                .onTapGesture { withAnimation { app.toast = nil } }
            }
        }
        .allowsHitTesting(app.toast != nil)
        .accessibilityElement(children: .contain)
    }
}

struct DialogHost: View {
    @Environment(AppState.self) private var app
    @Environment(AppSettings.self) private var s

    var body: some View {
        ZStack {
            if let dialog = app.dialog {
                Theme.scrim
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { close() }

                VStack(spacing: 14) {
                    if let icon = dialog.icon {
                        Image(systemName: icon)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(dialog.tone == .lime ? Theme.accent : dialog.tone.foreground)
                            .frame(width: 48, height: 48)
                            .background(dialog.tone.background.opacity(dialog.tone == .lime ? 0.2 : 1), in: Circle())
                    }
                    Text(dialog.title)
                        .font(WJFont.title3)
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                    if let message = dialog.message {
                        Text(message)
                            .font(WJFont.subhead)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(spacing: 10) {
                        Button(dialog.primary) {
                            let action = dialog.onPrimary
                            close()
                            action()
                        }
                        .buttonStyle(.wj(dialog.primaryRole == .destructive ? .destructive : .primary, height: 48))
                        if let secondary = dialog.secondary {
                            Button(secondary) {
                                let action = dialog.onSecondary
                                close()
                                action()
                            }
                            .buttonStyle(.wj(.secondary, height: 48))
                        }
                    }
                    .padding(.top, 6)
                }
                .padding(22)
                .frame(width: Metrics.dialogWidth)
                .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.border, lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 30, y: 12)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
                .accessibilityAddTraits(.isModal)
            }
        }
        .animation(.spring(duration: 0.3), value: app.dialog?.id)
    }

    private func close() {
        withAnimation(.easeOut(duration: 0.2)) { app.dialog = nil }
    }
}

// ===== haptics =====
enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func stamp() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

// keeps the swipe back gesture when the system back button is hidden
extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}

// share a file (the roadmap PDF)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

extension Double {
    var oneDecimal: String { String(format: "%.1f", self) }
}
