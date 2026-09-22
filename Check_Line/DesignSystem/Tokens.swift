import SwiftUI
import UIKit

/// Shared matte wallet surfaces. Native glass is reserved for controls and navigation.
enum PaperTheme {
    static let canvas = Color(red: 20/255, green: 23/255, blue: 26/255)
    static let card = Color(red: 34/255, green: 38/255, blue: 43/255)
    static let ink = Color(red: 248/255, green: 247/255, blue: 252/255)
    static let muted = Color(red: 184/255, green: 186/255, blue: 197/255)
    static let accent = Color(red: 182/255, green: 170/255, blue: 255/255)
    static let paper = Color(red: 246/255, green: 246/255, blue: 240/255)
    static let paperInk = Color(red: 23/255, green: 24/255, blue: 29/255)
    static let stroke = Color.white.opacity(0.10)
    static let lineTrack = Color.white.opacity(0.10)
    static let lineInk = accent
    static let chipIdle = Color.white.opacity(0.07)
    static let navigationBase = Color(red: 0.19, green: 0.21, blue: 0.23)
    static let shadow = Color.black.opacity(0.18)

    static var canvasUIColor: UIColor {
        UIColor(red: 20/255, green: 23/255, blue: 26/255, alpha: 1)
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
