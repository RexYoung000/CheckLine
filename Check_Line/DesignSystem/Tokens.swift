import SwiftUI
import UIKit

enum CheckLineAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var title: String {
        switch self {
        case .system: String(localized: "wallet.appearance.system")
        case .light: String(localized: "wallet.appearance.light")
        case .dark: String(localized: "wallet.appearance.dark")
        }
    }
}

/// Shared neutral UI roles and independent optical colors for the budget liquid.
enum PaperTheme {
    private static let lightCanvasHex: UInt32 = 0xFFFFFF
    private static let darkCanvasHex: UInt32 = 0x101113
    private static let selectedFillLightHex: UInt32 = 0xDDF3F8
    private static let selectedFillDarkHex: UInt32 = 0x34383B
    private static let selectedInkLightHex: UInt32 = 0x17272C
    private static let selectedInkDarkHex: UInt32 = 0xF0F2F3

    static let canvas = Color.paper(light: lightCanvasHex, dark: darkCanvasHex)
    static let card = Color.paper(light: 0xFFFFFF, dark: 0x1B1D20)
    static let pocket = Color.paper(light: 0xF5F7F8, dark: 0x17191C)
    static let cardholderSurface = Color.paper(light: 0xEBF0F2, dark: 0x25282B)
    static let cardholderBottom = Color.paper(light: 0xF6F8F9, dark: 0x1C1F22)
    static let cardholderSummary = Color.paper(light: 0xF4F7F8, dark: 0x292C30)
    static let ink = Color.paper(light: 0x17191B, dark: 0xF2F4F5)
    static let muted = Color.paper(light: 0x686E73, dark: 0xA9AFB4)

    /// High-contrast primary actions use black on light surfaces and white on dark ones.
    static let primary = Color.paper(light: 0x17191B, dark: 0xF2F4F5)
    static let primaryInk = Color.paper(light: 0xFFFFFF, dark: 0x17191B)

    /// Selected controls use a small ice-blue cue in light mode and neutral gray in dark mode.
    static let selectedFill = Color.paper(light: selectedFillLightHex, dark: selectedFillDarkHex)
    static let selectedInk = Color.paper(light: selectedInkLightHex, dark: selectedInkDarkHex)
    static let selectedStroke = Color.paper(light: 0x8BD2E2, dark: 0x747C82)
    static let focus = Color.paper(light: 0x57B7D0, dark: 0xAEB6BB)

    /// Default text and icon accent; focus remains a brighter, separate role.
    static let accent = Color.paper(light: 0x0A647B, dark: 0xAEB6BB)
    static let gold = Color.paper(light: 0xB99C72, dark: 0xD2B78B)
    static let waterTop = Color.paper(light: 0xD8F4FA, dark: 0x82D4E8)
    static let waterBottom = Color.paper(light: 0x8DD7EA, dark: 0x388FA7)
    static let waveBack = Color.paper(light: 0xBCEAF4, dark: 0x4F9DB2)
    static let paper = canvas
    static let paperInk = ink
    static let stroke = ink.opacity(0.10)
    static let lineTrack = ink.opacity(0.10)
    static let lineInk = focus
    static let chipIdle = ink.opacity(0.07)
    static let navigationBase = card
    static let shadow = Color.black.opacity(0.18)

    static var overlayScrim: Color {
        Color(uiColor: UIColor { trait in
            UIColor.black.withAlphaComponent(trait.userInterfaceStyle == .dark ? 0.40 : 0.32)
        })
    }

    static var canvasUIColor: UIColor {
        dynamicUIColor(light: lightCanvasHex, dark: darkCanvasHex)
    }

    static var segmentedSelectedFillUIColor: UIColor {
        dynamicUIColor(light: selectedFillLightHex, dark: selectedFillDarkHex)
    }

    static var segmentedSelectedInkUIColor: UIColor {
        dynamicUIColor(light: selectedInkLightHex, dark: selectedInkDarkHex)
    }

    static var segmentedMutedUIColor: UIColor {
        dynamicUIColor(light: 0x686E73, dark: 0xA9AFB4)
    }

    private static func dynamicUIColor(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { trait in
            let hex = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 255) / 255,
                           green: CGFloat((hex >> 8) & 255) / 255,
                           blue: CGFloat(hex & 255) / 255, alpha: 1)
        }
    }

    enum Space {
        static let xs: CGFloat = 6
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
    }

    static let dockSelected = Color.white.opacity(0.12)

    enum Radius {
        static let card: CGFloat = 24
        static let field: CGFloat = 12
        static let chip: CGFloat = 20
        static let bar: CGFloat = 18
        static let dock: CGFloat = 28
        static let sheet: CGFloat = 30
    }

    enum Dock {
        static let height: CGFloat = 64
        static let control: CGFloat = 60
        static let icon: CGFloat = 24
        static let maxWidth: CGFloat = 440
        static let bottomPadding: CGFloat = 6
        static let horizontalPadding: CGFloat = 18
        static let gap: CGFloat = 12
        /// Scroll content can pass behind the floating dock; its final item
        /// must still clear the controls and the home-indicator safe area.
        static let contentBottomClearance: CGFloat = 120

        static var plusBottom: CGFloat {
            if #available(iOS 26.0, *) { return 130 }
            return 8
        }

        static var menuBottom: CGFloat {
            plusBottom + control + 12
        }
    }

    enum Elevation {
        static let radius: CGFloat = 4
        static let y: CGFloat = 2
    }

    enum Stroke {
        static let hairline: CGFloat = 1
        static let progress: CGFloat = 1.5
        static let emphasis: CGFloat = 2
    }

    enum Typography {
        static let display: Font = .title2.weight(.semibold)
        static let displayTracking: CGFloat = -0.5
        static let remaining: Font = .system(.largeTitle, design: .default).weight(.medium)
        static let title: Font = .title2.weight(.semibold)
        static let cardName: Font = .headline
        static let body: Font = .body
        static let meta: Font = .subheadline
        static let caption: Font = .caption
        static let chip: Font = .subheadline.weight(.medium)
        static let empty: Font = .subheadline
        static let bar: Font = .headline
    }

    enum Layout {
        static let contentMaxWidth: CGFloat = 900
        static let minTap: CGFloat = 44
        static let cardPadding: CGFloat = 16
        static let titleBarHeight: CGFloat = 54
    }

    enum Motion {
        static let panel: Animation = .easeInOut(duration: 0.22)
        static let spring: Animation = .spring(response: 0.3, dampingFraction: 0.7)
        static let press: Animation = .easeInOut(duration: 0.1)
    }
}

extension EnvironmentValues {
    /// Mirrors the system preference; the isolated debug preview can also exercise its fallback.
    var walletReduceMotion: Bool {
        accessibilityReduceMotion || DesignPreviewData.reducesMotion
    }
}

extension Color {
    static func paper(light: UInt32, dark: UInt32) -> Color {
        Color(
            uiColor: UIColor { trait in
                let hex = trait.userInterfaceStyle == .dark ? dark : light
                return UIColor(
                    red: CGFloat((hex >> 16) & 0xFF) / 255,
                    green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255,
                    alpha: 1
                )
            }
        )
    }
}
