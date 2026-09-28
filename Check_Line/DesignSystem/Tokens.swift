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

/// Shared brand surfaces. Native glass is reserved for controls and navigation.
enum PaperTheme {
    static let canvas = Color.paper(light: 0xF5F4F1, dark: 0x1C1B20)
    static let card = Color.paper(light: 0xFAF9F6, dark: 0x29262F)
    static let pocket = Color.paper(light: 0xEEECE9, dark: 0x242228)
    static let ink = Color.paper(light: 0x302A38, dark: 0xF1ECF5)
    static let muted = Color.paper(light: 0x645B6D, dark: 0xB6AEBF)
    static let accent = Color.paper(light: 0x76618E, dark: 0xC2ACDC)
    static let gold = Color.paper(light: 0xB99C72, dark: 0xD2B78B)
    static let waterTop = Color.paper(light: 0xD5CCE2, dark: 0x61516F)
    static let waterBottom = Color.paper(light: 0xA392BC, dark: 0x51415F)
    static let waveBack = Color.paper(light: 0xB6A2C9, dark: 0x766185)
    static let paper = canvas
    static let paperInk = ink
    static let stroke = ink.opacity(0.10)
    static let lineTrack = ink.opacity(0.10)
    static let lineInk = accent
    static let chipIdle = ink.opacity(0.07)
    static let navigationBase = card
    static let shadow = Color.black.opacity(0.18)

    static var canvasUIColor: UIColor {
        UIColor { trait in
            let hex: UInt32 = trait.userInterfaceStyle == .dark ? 0x1C1B20 : 0xF5F4F1
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
