import SwiftUI

@main
struct WijhaApp: App {
    @State private var settings = AppSettings()
    @State private var app = AppState()
    @State private var expo = ExpoStore()
    @State private var visitor = VisitorStore()
    @State private var group = GroupShareStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(app)
                .environment(expo)
                .environment(visitor)
                .environment(group)
                .environment(\.layoutDirection, settings.layoutDirection)
                .environment(\.locale, settings.locale)
                .preferredColorScheme(settings.appearance.colorScheme)
                .tint(Theme.primary)
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var app
    @Environment(ExpoStore.self) private var expo
    @Environment(VisitorStore.self) private var visitor

    var body: some View {
        ZStack {
            Group {
                if app.restoring {
                    SplashView()
                } else if app.role == .visitor || app.guest {
                    VisitorRootView()
                } else if app.role == .admin {
                    AdminRootView()
                } else {
                    AuthFlowView()
                }
            }
            .transition(.opacity)

            ToastHost()
            DialogHost()
        }
        .animation(.easeInOut(duration: 0.3), value: app.role)
        .animation(.easeInOut(duration: 0.3), value: app.guest)
        .animation(.easeInOut(duration: 0.3), value: app.restoring)
        .task {
            async let data: Void = expo.load()
            if app.restoring { await app.restore(visitorStore: visitor) }
            await data
        }
    }
}

struct SplashView: View {
    @Environment(AppSettings.self) private var s
    @State private var appear = false
    @State private var float = false

    var body: some View {
        ZStack {
            // premium navy backdrop — the app's own identity (same family as the icon)
            LinearGradient(colors: [Palette.ink800, Palette.ink1000], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            RadialGradient(colors: [Palette.blue700.opacity(0.35), Palette.ink1000.opacity(0)], center: .top, startRadius: 0, endRadius: 520)
                .ignoresSafeArea()
            RadialGradient(colors: [Palette.mint500.opacity(0.14), .clear], center: .center, startRadius: 0, endRadius: 320)
                .ignoresSafeArea()

            VStack(spacing: 26) {
                ZStack {
                    // a soft glow behind the pin so it reads cleanly on the dark backdrop (matches the icon)
                    Circle()
                        .fill(Palette.mint500.opacity(0.30))
                        .frame(width: 230, height: 230)
                        .blur(radius: 60)
                    WijhaMark(size: 136)
                        .offset(y: float ? -5 : 5)
                }
                .scaleEffect(appear ? 1 : 0.86)
                .opacity(appear ? 1 : 0)

                VStack(spacing: 10) {
                    Text("وجهة")
                        .font(.system(size: 48, weight: .heavy))
                        .foregroundStyle(.white)
                        .tracking(1)
                    Text(s.t("splash.tagline"))
                        .font(WJFont.subhead.weight(.semibold))
                        .foregroundStyle(Palette.mint300)
                        .multilineTextAlignment(.center)
                }
                .opacity(appear ? 1 : 0)

                ProgressView()
                    .tint(.white.opacity(0.8))
                    .padding(.top, 6)
                    .opacity(appear ? 1 : 0)
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.7)) { appear = true }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { float = true }
        }
    }
}

// the app mark: the Wijha location-pin logo
struct WijhaMark: View {
    var size: CGFloat = 72
    var body: some View {
        Image("WijhaLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: Palette.mint900.opacity(0.55), radius: size * 0.16, y: size * 0.05)
            .accessibilityLabel("Wijha")
    }
}
