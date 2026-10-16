import SwiftUI

// OVL-CHK-01: check-in has no geofence, the visitor confirms on a sheet
struct CheckInSheet: View {
    let pavilion: Pavilion
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(VisitorStore.self) private var visitor
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var sending = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(title: s.t("checkin.title", s.pavilionName(pavilion.name)))
            HStack(spacing: 12) {
                RemoteImage(url: pavilion.imageUrl, cornerRadius: 14).frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(s.t("checkin.message")).font(WJFont.subhead).foregroundStyle(Theme.textSecondary)
                }
            }
            if let error {
                InfoNote(text: error, icon: "exclamationmark.triangle.fill", tone: .warning)
            }
            Spacer(minLength: 0)
            Button {
                Task { await confirm() }
            } label: {
                HStack { if sending { ProgressView().tint(.white) } else { Image(systemName: "seal") }; Text(s.t("checkin.confirm")) }
            }
            .buttonStyle(.wjPrimary)
            .disabled(sending)
            Button(s.t("common.notNow")) { dismiss() }
                .buttonStyle(.wjSecondary)
        }
        .padding(.horizontal, Metrics.margin)
        .padding(.bottom, 8)
        .wjSheet([.height(380)])
    }

    private func confirm() async {
        sending = true
        defer { sending = false }
        error = nil
        do {
            try await API.checkIn(pavilion.id)
            await visitor.afterCheckIn()
            Haptics.stamp()
            let next = visitor.today?.nextStop
            dismiss()
            // the stamp animation plays only after the server confirms
            try? await Task.sleep(for: .milliseconds(350))
            router.stamped = StampedResult(pavilion: pavilion, nextStop: next)
        } catch {
            self.error = AppState.message(error, s)
            Haptics.error()
        }
    }
}

// CHK-02 / CHK-03: the stamp is pressed into the passport
struct StampCeremonyView: View {
    let result: StampedResult
    @Environment(AppSettings.self) private var s
    @Environment(VisitorStore.self) private var visitor
    @Environment(ExpoStore.self) private var expo
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressed = false
    @State private var done = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 12)
            Label(done ? s.t("checkin.recorded") : s.t("checkin.stamping"), systemImage: done ? "checkmark.circle" : "seal")
                .font(WJFont.captionBold)
                .foregroundStyle(Theme.accent)
            Text(done ? s.t("checkin.stamped", s.countryName(result.pavilion.country)) : s.pavilionName(result.pavilion.name))
                .font(WJFont.title1)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .contentTransition(.opacity)

            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Palette.paper)
                    .overlay(
                        VStack(spacing: 22) {
                            ForEach(0..<9, id: \.self) { _ in Rectangle().fill(Palette.paperLine).frame(height: 1) }
                        }
                        .padding(.vertical, 14)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                VStack(spacing: 14) {
                    // a repeat visit presses a new stamp on top of this pavilion's earlier ones (passport already refreshed after check-in)
                    StampStack(imageUrl: stampImage, earned: true, count: visitor.visits(of: result.pavilion.id).count, size: 150)
                        .rotationEffect(.degrees(pressed ? -4 : -12))
                        .scaleEffect(pressed ? 1 : 1.25)
                        .opacity(pressed ? 1 : 0.15)
                    Text(s.countryName(result.pavilion.country))
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(Palette.paperInk)
                    Label(DateText.longDay(Date(), s), systemImage: "checkmark.circle")
                        .font(WJFont.caption.weight(.semibold))
                        .foregroundStyle(Palette.blue600)
                        .opacity(done ? 1 : 0)
                }
            }
            .frame(width: 250, height: 300)
            .shadow(color: .black.opacity(0.35), radius: 20, y: 10)

            HStack(spacing: 34) {
                StatColumn(value: "\(visitor.earnedCount) / \(max(visitor.stamps.count, expo.pavilions.count))", label: s.t("passport.stamps"))
                StatColumn(value: "\(visitor.passport?.visitsCount ?? 0)", label: s.t("passport.visits"))
                StatColumn(value: "\(visitor.pending.count)", label: s.t("passport.pending"))
            }
            .opacity(done ? 1 : 0)

            Spacer()

            VStack(spacing: 10) {
                // one review per visitor per pavilion (backend rule): a repeat visit of a reviewed pavilion gets no review prompt
                let canReview = visitor.pendingIds.contains(result.pavilion.id)
                if canReview {
                    Button {
                        let id = result.pavilion.id
                        dismiss()
                        router.push(.writeReview(pavilionId: id, reviewId: nil, rating: 0))
                    } label: {
                        Label(s.t("checkin.rate", s.pavilionName(result.pavilion.name)), systemImage: "star")
                    }
                    .buttonStyle(.wjPrimary)
                }
                if let next = result.nextStop {
                    Button {
                        dismiss()
                    } label: {
                        Label(s.t("checkin.continueTo", s.pavilionName(next.pavilionName)), systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    }
                    .buttonStyle(canReview ? .wjSecondary : .wjPrimary)
                    if !canReview {
                        Button {
                            dismiss()
                            router.open(.passport)
                        } label: {
                            Label(s.t("checkin.openPassport"), systemImage: "person.text.rectangle")
                        }
                        .buttonStyle(.wjSecondary)
                    }
                } else {
                    Button {
                        dismiss()
                        router.open(.passport)
                    } label: {
                        Label(s.t("checkin.openPassport"), systemImage: "person.text.rectangle")
                    }
                    .buttonStyle(canReview ? .wjSecondary : .wjPrimary)
                }
            }
            .opacity(done ? 1 : 0)
            .padding(.horizontal, Metrics.margin)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .screenBackground(.lime)
        .task {
            if reduceMotion {
                pressed = true
                done = true
                return
            }
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.timingCurve(0.5, 0, 0.75, 0, duration: 0.18)) { pressed = true }
            Haptics.stamp()
            try? await Task.sleep(for: .milliseconds(600))
            withAnimation(.easeOut(duration: 0.4)) { done = true }
        }
    }

    private var stampImage: String? {
        visitor.stamps.first { $0.pavilionId == result.pavilion.id }?.imageUrl
    }
}

// the same country stamp pressed once per visit: one stamp for one visit, overlapping tilted stamps for repeated visits
// `count` is the number of visits of THIS pavilion only (VisitorStore.visits(of:)), never another country's visits
struct StampStack: View {
    let imageUrl: String?
    var earned: Bool
    var count: Int
    var size: CGFloat = 80

    // fixed tilt/offset per copy so the stack looks hand-stamped and stays stable between redraws
    private static let tilts: [Double] = [-8, 10, -16, 6, -3, 14]
    private static let offsets: [CGSize] = [
        CGSize(width: 0, height: 0), CGSize(width: 0.16, height: 0.14), CGSize(width: -0.14, height: 0.10),
        CGSize(width: 0.10, height: -0.14), CGSize(width: -0.12, height: -0.12), CGSize(width: 0.18, height: -0.04)
    ]

    var body: some View {
        let copies = earned ? max(1, min(count, Self.tilts.count)) : 1
        ZStack {
            ForEach(0..<copies, id: \.self) { index in
                let step = Self.offsets[index]
                StampArt(imageUrl: imageUrl, earned: earned, size: size)
                    .rotationEffect(.degrees(copies == 1 ? 0 : Self.tilts[index]))
                    .offset(x: step.width * size, y: step.height * size)
                    .opacity(index == copies - 1 ? 1 : 0.85)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
    }
}

// a country stamp: the stamp art from the backend (/stamps/Country.png), faded when not earned
// the stamp files ship on an opaque paper-coloured square; StampImageLoader makes that square transparent
// so repeated stamps sit directly on top of each other like real ink
struct StampArt: View {
    let imageUrl: String?
    var earned: Bool
    var size: CGFloat = 80
    @State private var image: UIImage?

    private var url: URL? { APIClient.shared.resolveImageURL(imageUrl) }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                ZStack {
                    Circle().stroke(Palette.paperInk.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    Image(systemName: "building.columns")
                        .font(.system(size: size * 0.3))
                        .foregroundStyle(Palette.paperInk.opacity(0.35))
                }
            }
        }
        .frame(width: size, height: size)
        .saturation(earned ? 1 : 0)
        .opacity(earned ? 1 : 0.28)
        .task(id: url) {
            guard let url else { image = nil; return }
            image = await StampImageLoader.shared.image(for: url)
        }
    }
}

// downloads a stamp once, removes its paper background and keeps the result in memory
actor StampImageLoader {
    static let shared = StampImageLoader()
    private var cache: [URL: UIImage] = [:]
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    func image(for url: URL) async -> UIImage? {
        if let hit = cache[url] { return hit }
        if let running = inFlight[url] { return await running.value }
        let task = Task<UIImage?, Never> {
            guard let (data, _) = try? await URLSession.shared.data(from: url), let raw = UIImage(data: data) else { return nil }
            return Self.removingPaperBackground(raw) ?? raw
        }
        inFlight[url] = task
        let result = await task.value
        inFlight[url] = nil
        if let result { cache[url] = result }
        return result
    }

    // the background colour is sampled from the top-left corner; pixels close to it become transparent,
    // pixels a bit further fade out so the inked edges stay smooth
    nonisolated static func removingPaperBackground(_ image: UIImage) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let width = cg.width, height = cg.height
        guard width > 0, height > 0 else { return nil }
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }

        let bgR = Int(pixels[0]), bgG = Int(pixels[1]), bgB = Int(pixels[2])
        let solid = 36      // distance below this: pure background, fully transparent
        let soft = 110      // between solid and soft: partially transparent edge
        var i = 0
        while i < pixels.count {
            let distance = abs(Int(pixels[i]) - bgR) + abs(Int(pixels[i + 1]) - bgG) + abs(Int(pixels[i + 2]) - bgB)
            if distance < solid {
                pixels[i] = 0; pixels[i + 1] = 0; pixels[i + 2] = 0; pixels[i + 3] = 0
            } else if distance < soft {
                let alpha = (distance - solid) * 255 / (soft - solid)
                pixels[i] = UInt8(Int(pixels[i]) * alpha / 255)
                pixels[i + 1] = UInt8(Int(pixels[i + 1]) * alpha / 255)
                pixels[i + 2] = UInt8(Int(pixels[i + 2]) * alpha / 255)
                pixels[i + 3] = UInt8(alpha)
            }
            i += 4
        }

        let output = pixels.withUnsafeMutableBytes { buffer -> CGImage? in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            return context.makeImage()
        }
        guard let output else { return nil }
        return UIImage(cgImage: output, scale: image.scale, orientation: image.imageOrientation)
    }
}
