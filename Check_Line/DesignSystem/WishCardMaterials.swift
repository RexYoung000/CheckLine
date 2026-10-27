import SwiftUI
import Metal

enum WishMaterialRole { case unfulfilled, collection }

/// The optical layers are shared by list cards, cover previews and saved receipts.
/// Pose is supplied by the card's existing gesture owner; this surface has no clock.
struct WishCardBackdrop: View {
    var role: WishMaterialRole = .unfulfilled
    var radius: CGFloat = 25
    var pose = CGSize.zero
    var roll = 0.0
    var glare = UnitPoint(x: 0.3, y: 0.2)
    var photoFill = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            if role == .collection {
                WishMetalSurface(radius: radius, pose: pose, roll: roll, glare: glare)
            } else if !photoFill {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(WishMaterialPalette.glassTint.opacity(reduceTransparency ? 1 : 0.12))
                Group {
                    if scheme == .dark {
                        WishMetalSurface(radius: max(0, radius - 2), pose: pose, roll: roll, glare: glare)
                    } else {
                        RoundedRectangle(cornerRadius: max(0, radius - 2), style: .continuous)
                            .fill(LinearGradient(colors: [.white.opacity(0.68), Color(red: 0.72, green: 0.89, blue: 0.95).opacity(reduceTransparency ? 1 : 0.48)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay { RoundedRectangle(cornerRadius: max(0, radius - 2), style: .continuous).strokeBorder(.white.opacity(0.5), lineWidth: 0.8) }
                    }
                }
                .padding(EdgeInsets(top: 4, leading: 7, bottom: 8, trailing: 4))
                .rotationEffect(.degrees(-0.8))
                .shadow(color: .black.opacity(scheme == .dark ? 0.3 : 0.08), radius: 4, x: 2, y: 4)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}

enum WishMaterialPalette {
    static let glassTint = Color.paper(light: 0xD6F2FC, dark: 0xBCDDEA)
    static let ink = Color.paper(light: 0x213D4B, dark: 0xF2F3F5)
    static let meta = Color.paper(light: 0x405D6B, dark: 0xD3D3D7)
    static let mount = Color.paper(light: 0xD3EBF3, dark: 0x4A4A4E)
    static let edge = Color.paper(light: 0xFFFFFF, dark: 0xE1E1E3)
}

/// Clear front pane. Perimeter return light is used on both faces; the reverse
/// intentionally has no enclosed diagonal highlight over its percentage.
struct WishGlassPane: View {
    var radius: CGFloat = 25
    var glare = UnitPoint(x: 0.3, y: 0.2)
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if !reduceTransparency {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(WishMaterialPalette.glassTint.opacity(0.025))
                    Ellipse().fill(.white.opacity(0.36))
                        .frame(width: proxy.size.width * 0.8, height: proxy.size.height * 0.2)
                        .blur(radius: 14).position(x: proxy.size.width * glare.x, y: -proxy.size.height * 0.015)
                    Ellipse().fill(WishMaterialPalette.glassTint.opacity(0.5))
                        .frame(width: proxy.size.width * 0.62, height: 5)
                        .blur(radius: 3).position(x: proxy.size.width * 0.42, y: proxy.size.height - 2)
                }
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(LinearGradient(stops: [.init(color: .white.opacity(0.86), location: 0), .init(color: .white.opacity(0.12), location: 0.42), .init(color: WishMaterialPalette.glassTint.opacity(0.42), location: 0.72), .init(color: .white.opacity(0.62), location: 1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: contrast == .increased ? 1.8 : 1.2)
                RoundedRectangle(cornerRadius: max(0, radius - 2), style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1).padding(2)
            }.clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct WishMetalSurface: View {
    var radius: CGFloat = 25
    var pose = CGSize.zero
    var roll = 0.0
    var glare = UnitPoint(x: 0.3, y: 0.2)
    @Environment(\.colorScheme) private var scheme
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    private static let supportsShader = MTLCreateSystemDefaultDevice() != nil && !ProcessInfo.processInfo.arguments.contains("-design-static-materials")

    var body: some View {
        GeometryReader { proxy in
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            let activePose = reduceMotion || scenePhase != .active ? CGSize.zero : pose
            let activeRoll = reduceMotion || scenePhase != .active ? 0 : roll
            ZStack {
                fallback
                if Self.supportsShader, proxy.size.width > 0, proxy.size.height > 0 {
                    shape.fill(ShaderLibrary.wishCollectionMetal(
                        .float2(Float(proxy.size.width), Float(proxy.size.height)), .float(Float(radius)),
                        .float(scheme == .light ? 1 : 0),
                        .float2(Float(activePose.height * .pi / 180), Float(activePose.width * .pi / 180)),
                        .float(Float(activeRoll * .pi / 180)),
                        .float2(Float(glare.x - 0.5), Float(glare.y - 0.5)),
                        .float(activePose == .zero && activeRoll == 0 ? 0 : 0.16)))
                }
                shape.strokeBorder(LinearGradient(colors: [WishMaterialPalette.edge.opacity(scheme == .light ? 0.8 : 0.35), .black.opacity(scheme == .light ? 0.16 : 0.45)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8)
            }.clipShape(shape)
        }.allowsHitTesting(false).accessibilityHidden(true)
    }

    private var fallback: some View {
        GeometryReader { proxy in
            let light = scheme == .light
            ZStack {
                Color.paper(light: 0xAFD4E0, dark: 0x454547)
                Ellipse().fill(.white.opacity(light ? 0.6 : 0.22))
                    .frame(width: proxy.size.width * 0.58, height: proxy.size.height * 0.62)
                    .blur(radius: 14).position(x: proxy.size.width * 0.28, y: proxy.size.height * 0.2)
                Rectangle().fill(.black.opacity(light ? 0.13 : 0.35))
                    .frame(width: proxy.size.width * 0.07, height: proxy.size.height * 0.74)
                    .blur(radius: 7).rotationEffect(.degrees(-7))
                    .position(x: proxy.size.width * 0.65, y: proxy.size.height * 0.69)
                LinearGradient(colors: [.clear, .white.opacity(light ? 0.18 : 0.09), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }
}

struct WishFocusScrim: View {
    var onTap: (() -> Void)?
    // The dimming veil carries no content. Keep its accepted alpha even when
    // transparency is reduced; content surfaces become opaque independently.
    var body: some View {
        PaperTheme.overlayScrim.ignoresSafeArea().contentShape(Rectangle())
            .onTapGesture { onTap?() }
            .accessibilityHidden(true)
    }
}
