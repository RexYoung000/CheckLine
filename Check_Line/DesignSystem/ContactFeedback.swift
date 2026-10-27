import SwiftUI

/// Finite decorations are removed at their deadline, rather than freezing the
/// timeline's last, possibly nontransparent frame. The shared contact date stays
/// available to longer-lived liquid effects and never controls ledger state.
struct ContactEffectTimeline<Content: View>: View {
    let startedAt: Date?
    let duration: TimeInterval
    @ViewBuilder var content: (TimeInterval) -> Content
    @State private var completedContact: Date?
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private struct Playback: Equatable {
        let contact: Date?
        let enabled: Bool
    }

    var body: some View {
        let playback = Playback(contact: startedAt, enabled: !reduceMotion && scenePhase == .active)
        ZStack {
            if playback.enabled, let startedAt, completedContact != startedAt {
                TimelineView(.animation(minimumInterval: 1.0 / 60)) { clock in
                    let elapsed = clock.date.timeIntervalSince(startedAt)
                    if elapsed >= 0 && elapsed < duration { content(elapsed) }
                }
                .id(startedAt)
            }
        }
        .allowsHitTesting(false).accessibilityHidden(true)
        .task(id: playback) {
            guard playback.enabled, let contact = playback.contact else { return }
            let remaining = max(0, duration - Date().timeIntervalSince(contact))
            do {
                if remaining > 0 { try await Task.sleep(for: .seconds(remaining)) }
                try Task.checkCancellation()
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) { completedContact = contact }
            } catch { /* A cancelled contact must not finish a newer one. */ }
        }
    }
}

enum ComponentLightOrigin {
    case top, leading, trailing

    /// CSS conic angles start at the top, SwiftUI angles at the right.
    var degrees: Double {
        switch self {
        case .top: -90
        case .leading: 180
        case .trailing: 0
        }
    }
}

struct ComponentLightSweep: View {
    let startedAt: Date?
    var radius: CGFloat = 24
    var origin: ComponentLightOrigin = .top

    var body: some View {
        ContactEffectTimeline(startedAt: startedAt, duration: 0.8) { elapsed in
            ComponentLightFrame(progress: elapsed / 0.8, radius: radius, origin: origin)
        }
    }
}

/// R34's 62-degree iridescent band, mirrored into two travelling fronts. Only
/// the component's own continuous rounded border is drawn; its interior stays clear.
struct ComponentLightFrame: View {
    let progress: Double
    var radius: CGFloat = 24
    var origin: ComponentLightOrigin = .top

    private var band: AngularGradient {
        let iceBlue = Color.paper(light: 0xA6E0ED, dark: 0x95D4E2)
        let paleLavender = Color.paper(light: 0xD1C1E7, dark: 0xC1B5D3)
        let softPink = Color.paper(light: 0xF0BDD5, dark: 0xDFAFC5)
        let silverWhite = Color.paper(light: 0xF3F6F7, dark: 0xDDE2E5)
        return AngularGradient(stops: [
            .init(color: iceBlue.opacity(0), location: 0),
            .init(color: iceBlue, location: 12.0 / 360),
            .init(color: paleLavender, location: 26.0 / 360),
            .init(color: softPink, location: 39.0 / 360),
            .init(color: silverWhite, location: 50.0 / 360),
            .init(color: silverWhite.opacity(0), location: 62.0 / 360),
            .init(color: silverWhite.opacity(0), location: 1)
        ], center: .center, angle: .degrees(origin.degrees - 50 + 200 * progress))
    }

    private func opacity(peak: Double, held: Double) -> Double {
        guard progress > 0 && progress < 1 else { return 0 }
        if progress < 0.12 { return peak * progress / 0.12 }
        if progress < 0.75 { return peak + (held - peak) * (progress - 0.12) / 0.63 }
        return held * (1 - progress) / 0.25
    }

    var body: some View {
        ZStack {
            ForEach(0..<2) { direction in
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(band, lineWidth: 5)
                        .blur(radius: 3)
                        .opacity(opacity(peak: 0.38, held: 0.3))
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(band, lineWidth: 1.8)
                        .opacity(opacity(peak: 0.85, held: 0.7))
                }
                .scaleEffect(x: direction == 1 && origin == .top ? -1 : 1,
                             y: direction == 1 && origin != .top ? -1 : 1)
            }
        }
    }
}
