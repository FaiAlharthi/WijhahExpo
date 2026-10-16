import SwiftUI
import UIKit

// Design tokens from the Figma design system (وجهة — Design System).
// Dark mode follows the design exactly, light mode is the same identity on a light canvas.
enum Palette {
    // ink ramp
    static let ink1000 = Color(hex: 0x000611)
    static let ink950 = Color(hex: 0x010B1F)
    static let ink900 = Color(hex: 0x01112D)
    static let ink850 = Color(hex: 0x061934)
    static let ink800 = Color(hex: 0x0B2140)
    static let ink750 = Color(hex: 0x11294D)
    static let ink700 = Color(hex: 0x18355B)
    static let ink650 = Color(hex: 0x20406B)
    static let ink600 = Color(hex: 0x2C4E7D)
    static let ink500 = Color(hex: 0x4A6894)
    static let ink400 = Color(hex: 0x7189B0)
    static let ink300 = Color(hex: 0x9AAECB)
    static let ink200 = Color(hex: 0xC3D0E2)
    static let ink100 = Color(hex: 0xE3E9F2)
    static let ink50 = Color(hex: 0xF4F7FB)

    // blue ramp
    static let blue900 = Color(hex: 0x001A75)
    static let blue800 = Color(hex: 0x0127A8)
    static let blue700 = Color(hex: 0x0232D6)
    static let blue600 = Color(hex: 0x023CF6)
    static let blue500 = Color(hex: 0x2A5BFF)
    static let blue400 = Color(hex: 0x5A82FF)
    static let blue300 = Color(hex: 0x8CA8FF)
    static let blue200 = Color(hex: 0xBCCCFF)
    static let blue100 = Color(hex: 0xE3EAFF)

    // lime ramp
    static let lime700 = Color(hex: 0x4E8A00)
    static let lime600 = Color(hex: 0x6CC000)
    static let lime500 = Color(hex: 0x8AED03)
    static let lime400 = Color(hex: 0xA6F43A)
    static let lime300 = Color(hex: 0xC3F87A)
    static let lime200 = Color(hex: 0xDDFBB0)

    // mint ramp
    static let mint900 = Color(hex: 0x06392C)
    static let mint700 = Color(hex: 0x0E8A63)
    static let mint500 = Color(hex: 0x2BD9A0)
    static let mint300 = Color(hex: 0x9CEFCB)

    // brand green ramp (from the Wijha logo pin: deep green -> emerald -> teal)
    static let green950 = Color(hex: 0x001C12)
    static let green900 = Color(hex: 0x002D1E)
    static let green800 = Color(hex: 0x04402B)
    static let green700 = Color(hex: 0x0A5A3B)
    static let green600 = Color(hex: 0x0E7A4E)
    static let green500 = Color(hex: 0x12A266)
    static let green400 = Color(hex: 0x27C487)
    static let green300 = Color(hex: 0x7FE0B8)
    static let green200 = Color(hex: 0xBEF2DC)

    // amber and red ramps
    static let amber900 = Color(hex: 0x3D2A04)
    static let amber700 = Color(hex: 0x9A6400)
    static let amber500 = Color(hex: 0xFFB020)
    static let amber300 = Color(hex: 0xFFD98A)
    static let red900 = Color(hex: 0x3D0A12)
    static let red700 = Color(hex: 0xB4232F)
    static let red500 = Color(hex: 0xF0444F)
    static let red300 = Color(hex: 0xFFA3A9)

    // passport paper
    static let paper = Color(hex: 0xF6F0E2)
    static let paperLine = Color(hex: 0xE4DCC8)
    static let paperInk = Color(hex: 0x1F2A3D)
}

// Semantic colors, each with a dark and a light value
enum Theme {
    // surfaces
    static let canvas = Color.dynamic(dark: Palette.ink900, light: Palette.ink50)
    static let canvasDeep = Color.dynamic(dark: Palette.ink950, light: Color(hex: 0xEAF0F8))
    static let surface = Color.dynamic(dark: Palette.ink800, light: .white)
    static let surfaceRaised = Color.dynamic(dark: Palette.ink750, light: .white)
    static let surfaceSunken = Color.dynamic(dark: Palette.ink850, light: Color(hex: 0xEEF2F8))
    static let sheet = Color.dynamic(dark: Palette.ink800, light: .white)
    static let border = Color.dynamic(dark: Palette.ink700, light: Palette.ink100)
    static let borderStrong = Color.dynamic(dark: Palette.ink600, light: Palette.ink200)
    static let divider = Color.dynamic(dark: Palette.ink700.opacity(0.7), light: Palette.ink100)
    static let scrim = Palette.ink1000.opacity(0.6)

    // text
    static let textPrimary = Color.dynamic(dark: Palette.ink50, light: Palette.ink900)
    static let textSecondary = Color.dynamic(dark: Palette.ink300, light: Palette.ink500)
    static let textTertiary = Color.dynamic(dark: Palette.ink400, light: Palette.ink400)
    static let textOnPrimary = Color.white
    static let textOnLime = Palette.ink900

    // brand
    static let primary = Color.dynamic(dark: Palette.blue500, light: Palette.blue600)
    static let primaryPressed = Color.dynamic(dark: Palette.blue600, light: Palette.blue700)
    static let primarySoft = Color.dynamic(dark: Palette.blue500.opacity(0.18), light: Palette.blue100)
    static let primaryText = Color.dynamic(dark: Palette.blue300, light: Palette.blue700)
    static let accent = Color.dynamic(dark: Palette.lime500, light: Palette.lime700)       // step labels, "next"
    static let accentFill = Palette.lime500                                                 // lime chips (dark text)
    static let accentSoft = Color.dynamic(dark: Palette.lime500.opacity(0.14), light: Palette.lime200)

    // brand green (logo) — used by the mark, splash glow and subtle brand touches
    static let brand = Color.dynamic(dark: Palette.green400, light: Palette.green600)
    static let brandDeep = Color.dynamic(dark: Palette.green800, light: Palette.green500)
    static let brandSoft = Color.dynamic(dark: Palette.green500.opacity(0.16), light: Palette.green200)

    // status
    static let success = Color.dynamic(dark: Palette.mint500, light: Palette.mint700)
    static let successSoft = Color.dynamic(dark: Palette.mint500.opacity(0.16), light: Color(hex: 0xDDF7EC))
    static let warning = Color.dynamic(dark: Palette.amber500, light: Palette.amber700)
    static let warningSoft = Color.dynamic(dark: Palette.amber900, light: Color(hex: 0xFFF1D6))
    static let danger = Color.dynamic(dark: Palette.red500, light: Palette.red700)
    static let dangerSoft = Color.dynamic(dark: Palette.red900, light: Color(hex: 0xFDE3E5))
    static let info = Color.dynamic(dark: Palette.blue300, light: Palette.blue700)
    static let infoSoft = Color.dynamic(dark: Color(hex: 0x0A2A47), light: Palette.blue100)
    static let star = Color(hex: 0xFFC233)

    // map and route
    static let routeAhead = Color.dynamic(dark: Palette.lime500, light: Palette.lime600)
    static let routeWalked = Color.dynamic(dark: Palette.blue400, light: Palette.blue600)
    static let mapBase = Color.dynamic(dark: Palette.ink950, light: Color(hex: 0xE6ECF5))
    static let mapZone = Color.dynamic(dark: Color(hex: 0x123A34).opacity(0.60), light: Color(hex: 0xDCEFE9))
    static let mapZoneStroke = Color.dynamic(dark: Color(hex: 0x2E6B5E).opacity(0.45), light: Color(hex: 0x0E7A63).opacity(0.30))
    static let mapLine = Color.dynamic(dark: Palette.ink600.opacity(0.55), light: Palette.ink200)
    static let mapLabel = Color.dynamic(dark: Color(hex: 0x5FD4BD), light: Color(hex: 0x0E7A63))
    static let mapGate = Color.dynamic(dark: Palette.ink100, light: Palette.ink700)

    // header glow (top of the screens)
    static let glowTop = Color.dynamic(dark: Palette.blue700, light: Palette.blue200)
    static let glowMid = Color.dynamic(dark: Palette.blue800.opacity(0.55), light: Palette.blue100.opacity(0.7))

    // tab bar
    static let tabBar = Color.dynamic(dark: Palette.ink900, light: .white)
    static let tabActivePill = Color.dynamic(dark: Color(hex: 0x15306E), light: Palette.blue100)
}

// spacing, radius and sizes from the layout grid (8 pt, 20 pt margins, 44 pt targets)
enum Metrics {
    static let margin: CGFloat = 20
    static let gap: CGFloat = 12
    static let cardRadius: CGFloat = 18
    static let smallRadius: CGFloat = 12
    static let fieldHeight: CGFloat = 52
    static let buttonHeight: CGFloat = 52
    static let touch: CGFloat = 44
    static let maxContentWidth: CGFloat = 560
    static let dialogWidth: CGFloat = 320
}

// Text styles of the "wj" group, built on Dynamic Type so they scale up to 130%
enum WJFont {
    static let display = Font.system(.largeTitle, design: .default).weight(.bold)    // 34/44
    static let title1 = Font.system(.title, design: .default).weight(.bold)          // 28
    static let title2 = Font.system(.title2, design: .default).weight(.bold)         // 22
    static let title3 = Font.system(.title3, design: .default).weight(.bold)         // 20
    static let headline = Font.system(.headline, design: .default)                   // 17 semibold
    static let body = Font.system(.body, design: .default)                           // 17
    static let bodyMedium = Font.system(.body, design: .default).weight(.medium)
    static let callout = Font.system(.callout, design: .default)                     // 16
    static let label = Font.system(.subheadline, design: .default).weight(.semibold) // 15
    static let subhead = Font.system(.subheadline, design: .default)                 // 15
    static let footnote = Font.system(.footnote, design: .default)                   // 13
    static let caption = Font.system(.caption, design: .default)                     // 12/18
    static let captionBold = Font.system(.caption, design: .default).weight(.bold)
    static let micro = Font.system(.caption2, design: .default).weight(.semibold)    // 11
    static let stat = Font.system(.title2, design: .rounded).weight(.bold).monospacedDigit()
    static let button = Font.system(.callout, design: .default).weight(.bold)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }

    // a color that follows the light / dark mode of the screen
    static func dynamic(dark: Color, light: Color) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}
