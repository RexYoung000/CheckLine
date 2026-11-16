import SwiftUI

/// The card library uses the ledger's provisional remaining amount and confirmed risk.
nonisolated struct LibraryCardSummary {
    let name: String
    let label: String
    let amount: Decimal
    let currencyCode: String
    let fill: CGFloat
    let isRisk: Bool

    init(card: HomeBudgetCardModel, now: Date = .now) {
        name = card.name
        currencyCode = card.currencyCode

        let remaining = BudgetPresentation.remaining(card)
        let confirmedOverrun = card.snapshot.certainOverrunAmount
        if BudgetPresentation.isUpcoming(card, now: now) {
            label = String(localized: "native.library.card.upcoming")
            amount = card.snapshot.budgetAmount
            fill = 0
            isRisk = false
        } else if confirmedOverrun > 0 {
            label = String(localized: "wallet.overrun")
            // A pending refund cannot remove a confirmed overrun.
            amount = remaining < 0 ? remaining : -confirmedOverrun
            fill = 0
            isRisk = true
        } else {
            isRisk = remaining < 0
            label = String(localized: isRisk ? "wallet.possibleOverrun" : "v1.card.remaining")
            amount = remaining
            fill = CGFloat(BudgetPresentation.fill(card))
        }
    }

    var amountText: String { MoneyFormat.string(amount, currencyCode: currencyCode) }
    var accessibilityLabel: String { [name, label, amountText].joined(separator: ", ") }
}

struct LibraryBudgetCardFace: View {
    let card: HomeBudgetCardModel
    var compact = false
    var now: Date = .now

    @ScaledMetric(relativeTo: .headline) private var nameScale = 1.0
    @ScaledMetric(relativeTo: .caption) private var labelScale = 1.0
    @ScaledMetric(relativeTo: .title) private var amountScale = 1.0

    var body: some View {
        let summary = LibraryCardSummary(card: card, now: now)
        GeometryReader { geometry in
            let width = geometry.size.width
            let radius = min(compact ? 18 : 27, width * 0.125)
            let inset = min(compact ? 14 : 20, width * 0.08)

            VStack(alignment: .leading, spacing: 0) {
                Text(summary.name)
                    .font(.system(size: min(width * 0.115, min(width * 0.072, 24) * nameScale), weight: .semibold))
                    .lineLimit(2)
                    .layoutPriority(1)

                Spacer(minLength: 2)

                VStack(alignment: .leading, spacing: min(4, width * 0.011)) {
                    Text(summary.label)
                        .font(.system(size: min(width * 0.075, min(width * 0.0465, 14) * labelScale), weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(summary.isRisk ? LibraryCardOptics.riskInk : LibraryCardOptics.metadata)
                    Text(summary.amountText)
                        .font(.system(size: min(width * 0.16, min(width * 0.1165, 42) * amountScale), weight: .semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.14)
                }
                .layoutPriority(1)
            }
            .foregroundStyle(LibraryCardOptics.ink)
            .padding(inset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .background {
                LibraryCardMaterial(radius: radius, layer: .complete(fill: summary.fill))
                    .shadow(color: LibraryCardOptics.shadow, radius: 6, y: 3)
            }
        }
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary.accessibilityLabel)
    }
}

/// The shell can wrap the live home card. The original liquid remains between the shell's layers.
struct LibraryCardOptics: ViewModifier {
    let radius: CGFloat

    static let ink = Color.paper(light: 0x102F41, dark: 0xEDFAFF)
    static let metadata = Color.paper(light: 0x2C5669, dark: 0xC4E6F4)
    fileprivate static let riskInk = Color.paper(light: 0x704019, dark: 0xFFDDA9)
    fileprivate static let shadow = Color.paper(light: 0x245E78, dark: 0x040F18).opacity(0.18)

    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .background {
                LibraryCardMaterial(radius: radius, layer: .shell)
                    .shadow(color: Self.shadow, radius: 8, y: 4)
            }
            .overlay { LibraryCardMaterial(radius: radius, layer: .edge) }
    }
}

private struct LibraryCardMaterial: View {
    enum Layer {
        case shell
        case edge
        case complete(fill: CGFloat)
    }

    let radius: CGFloat
    let layer: Layer

    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            let outline = RoundedRectangle(cornerRadius: radius).path(in: bounds)
            let palette = LibraryCardPalette(dark: scheme == .dark)
            var drawing = context
            drawing.clip(to: outline)

            switch layer {
            case .shell:
                drawShell(drawing, size: size, palette: palette)
            case .edge:
                drawEdge(drawing, size: size, palette: palette)
            case .complete(let fill):
                drawShell(drawing, size: size, palette: palette)
                drawWater(drawing, size: size, fill: fill, palette: palette)
                drawEdge(drawing, size: size, palette: palette)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawShell(_ context: GraphicsContext, size: CGSize, palette: LibraryCardPalette) {
        let bounds = Path(CGRect(origin: .zero, size: size))
        let opacity = reduceTransparency ? 1.0 : 0.92
        context.fill(bounds, with: .linearGradient(Gradient(stops: [
            .init(color: palette.shellTop.opacity(opacity), location: 0),
            .init(color: palette.shellMid.opacity(opacity), location: 0.49),
            .init(color: palette.shellBase.opacity(opacity), location: 1)
        ]), startPoint: CGPoint(x: size.width * 0.08, y: 0), endPoint: CGPoint(x: size.width * 0.82, y: size.height)))

        let center = CGPoint(x: size.width * 0.08, y: size.height * 0.04)
        drawGlow(context, in: size, center: center, radius: size.width * 0.79, squash: 0.57, stops: [
            .init(color: palette.frost.opacity(0.34), location: 0),
            .init(color: palette.frost.opacity(0.08), location: 0.52),
            .init(color: .clear, location: 1)
        ])
    }

    private func drawEdge(_ context: GraphicsContext, size: CGSize, palette: LibraryCardPalette) {
        let bounds = CGRect(origin: .zero, size: size)
        let width = size.width
        let height = size.height
        let horizontal = CGPoint(x: width, y: 0)

        context.fill(Path(bounds), with: .linearGradient(Gradient(stops: [
            .init(color: palette.facet.opacity(0.43), location: 0),
            .init(color: palette.frost.opacity(0.14), location: 0.022),
            .init(color: .clear, location: 0.065),
            .init(color: .clear, location: 0.88),
            .init(color: palette.depth.opacity(0.30), location: 0.979),
            .init(color: palette.facet.opacity(0.21), location: 1)
        ]), startPoint: .zero, endPoint: horizontal))

        let lineWidth = contrast == .increased ? 1.6 : max(0.6, width * 0.004)
        let edge = RoundedRectangle(cornerRadius: radius).inset(by: lineWidth / 2).path(in: bounds)
        context.stroke(edge, with: .linearGradient(Gradient(stops: [
            .init(color: palette.frost.opacity(0.94), location: 0),
            .init(color: palette.edge.opacity(0.58), location: 0.32),
            .init(color: palette.edge.opacity(0.47), location: 0.70),
            .init(color: palette.rimLight.opacity(0.88), location: 1)
        ]), startPoint: CGPoint(x: width * 0.05, y: 0), endPoint: CGPoint(x: width * 0.95, y: height)), lineWidth: lineWidth)

        let inset = max(1.5, width * 0.015)
        let corner = radius + inset * 0.35
        var upper = Path()
        upper.move(to: CGPoint(x: inset, y: max(corner, height * 0.28)))
        upper.addLine(to: CGPoint(x: inset, y: corner))
        upper.addQuadCurve(to: CGPoint(x: corner, y: inset), control: CGPoint(x: inset, y: inset))
        upper.addLine(to: CGPoint(x: width * 0.61, y: inset))
        context.stroke(upper, with: .linearGradient(Gradient(stops: [
            .init(color: .clear, location: 0),
            .init(color: palette.frost.opacity(0.89), location: 0.17),
            .init(color: palette.frost.opacity(0.49), location: 0.51),
            .init(color: .clear, location: 1)
        ]), startPoint: CGPoint(x: 0, y: height * 0.7), endPoint: CGPoint(x: width * 0.72, y: 0)),
                       style: StrokeStyle(lineWidth: max(0.5, width * 0.0034), lineCap: .round))

        var lower = Path()
        lower.move(to: CGPoint(x: width * 0.265, y: height - inset))
        lower.addLine(to: CGPoint(x: width - corner, y: height - inset))
        lower.addQuadCurve(to: CGPoint(x: width - inset, y: height - corner),
                           control: CGPoint(x: width - inset, y: height - inset))
        lower.addLine(to: CGPoint(x: width - inset, y: min(height - corner, height * 0.82)))
        context.stroke(lower, with: .linearGradient(Gradient(stops: [
            .init(color: .clear, location: 0.265),
            .init(color: palette.facet.opacity(0.21), location: 0.35),
            .init(color: palette.rimLight.opacity(0.88), location: 0.76),
            .init(color: .clear, location: 1)
        ]), startPoint: .zero, endPoint: horizontal), style: StrokeStyle(lineWidth: max(0.55, width * 0.0041), lineCap: .round))
    }

    private func drawWater(_ context: GraphicsContext, size: CGSize, fill: CGFloat, palette: LibraryCardPalette) {
        guard fill > 0 else { return }

        let width = size.width
        let height = size.height
        let scale = width / 400
        let base = height * 0.99
        let depth = (base - height * 0.05) * fill
        let waterY = base - depth
        let swell = min(depth * 0.33, 3.7 * scale)

        var surface = Path()
        surface.move(to: CGPoint(x: 0, y: waterY))
        surface.addCurve(to: CGPoint(x: width * 0.465, y: waterY - swell * 0.35),
                         control1: CGPoint(x: width * 0.195, y: waterY + swell),
                         control2: CGPoint(x: width * 0.275, y: waterY - swell))
        surface.addCurve(to: CGPoint(x: width, y: waterY - swell * 0.42),
                         control1: CGPoint(x: width * 0.655, y: waterY + swell * 0.30),
                         control2: CGPoint(x: width * 0.7925, y: waterY + swell))

        var volume = surface
        volume.addLine(to: CGPoint(x: width, y: base))
        volume.addLine(to: CGPoint(x: 0, y: base))
        volume.closeSubpath()

        context.fill(volume, with: .linearGradient(Gradient(stops: [
            .init(color: palette.waterTop.opacity(0.37), location: 0),
            .init(color: palette.waterMid.opacity(0.43), location: 0.44),
            .init(color: palette.waterBase.opacity(0.66), location: 1)
        ]), startPoint: CGPoint(x: 0, y: waterY), endPoint: CGPoint(x: 0, y: base)))

        var water = context
        water.clip(to: volume)
        drawGlow(water, in: size, center: CGPoint(x: width * 0.695, y: height * 0.987),
                 radius: width * 0.535, squash: 0.47, stops: [
                    .init(color: palette.core.opacity(0.78), location: 0),
                    .init(color: palette.core.opacity(0.37), location: 0.39),
                    .init(color: .clear, location: 1)
                 ])

        for (x, relativeDepth, radius) in Self.bubbles where depth > (radius * 5 + 8) * scale {
            let center = CGPoint(x: x * scale, y: waterY + 5 * scale + (depth - 10 * scale) * relativeDepth)
            drawBubble(water, center: center, radius: radius * scale, palette: palette)
        }

        let rearSurface = surface.offsetBy(dx: 0, dy: -min(3.6 * scale, depth * 0.26))
        context.stroke(rearSurface, with: .color(palette.facet.opacity(0.38)), lineWidth: max(0.4, 0.85 * scale))
        context.stroke(surface, with: .linearGradient(Gradient(stops: [
            .init(color: palette.frost.opacity(0.22), location: 0),
            .init(color: palette.frost.opacity(0.63), location: 0.18),
            .init(color: palette.rimLight.opacity(0.49), location: 0.49),
            .init(color: palette.rimLight.opacity(0.80), location: 0.76),
            .init(color: palette.rimLight.opacity(0.36), location: 1)
        ]), startPoint: .zero, endPoint: CGPoint(x: width, y: 0)), lineWidth: max(0.6, 1.35 * scale))
    }

    private static let bubbles: [(CGFloat, CGFloat, CGFloat)] = [
        (342, 0.24, 2.0), (319, 0.41, 3.4), (371, 0.53, 1.3), (350, 0.64, 4.1),
        (365, 0.82, 2.0), (297, 0.69, 1.5), (283, 0.86, 2.0), (81, 0.88, 1.3)
    ]

    private func drawBubble(_ context: GraphicsContext, center: CGPoint, radius: CGFloat, palette: LibraryCardPalette) {
        let bubble = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius))
        context.stroke(bubble, with: .color(palette.rimLight.opacity(0.38)), lineWidth: max(0.25, radius * 0.20))
        let glint = Path(ellipseIn: CGRect(x: center.x - radius * 0.51, y: center.y - radius * 0.59,
                                           width: radius * 0.4, height: radius * 0.4))
        context.fill(glint, with: .color(palette.frost.opacity(0.79)))
    }

    private func drawGlow(_ context: GraphicsContext, in size: CGSize, center: CGPoint, radius: CGFloat,
                          squash: CGFloat, stops: [Gradient.Stop]) {
        var glow = context
        glow.scaleBy(x: 1, y: squash)
        glow.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: size.height / squash)),
                  with: .radialGradient(Gradient(stops: stops), center: CGPoint(x: center.x, y: center.y / squash),
                                        startRadius: 0, endRadius: radius))
    }
}

private struct LibraryCardPalette {
    let dark: Bool

    var shellTop: Color { color(0xEAF8FC, 0x244F65) }
    var shellMid: Color { color(0xDBF1F8, 0x19384A) }
    var shellBase: Color { color(0xBCDDE9, 0x112B3E) }
    var frost: Color { color(0xFFFFFF, 0xC3F0FF) }
    var facet: Color { color(0x72AEC6, 0x8CDBF5) }
    var depth: Color { color(0x4C9CBD, 0x031321) }
    var edge: Color { color(0x528CA8, 0x89CBE6) }
    var waterTop: Color { color(0x77D4ED, 0x559AB9) }
    var waterMid: Color { color(0x59BDDD, 0x246384) }
    var waterBase: Color { color(0x308EB7, 0x0A304F) }
    var core: Color { color(0xAFF2FF, 0x65D6FF) }
    var rimLight: Color { color(0xE9FCFF, 0xBDEFFF) }

    private func color(_ light: UInt32, _ dark: UInt32) -> Color {
        let hex = self.dark ? dark : light
        return Color(red: Double((hex >> 16) & 0xFF) / 255,
                     green: Double((hex >> 8) & 0xFF) / 255,
                     blue: Double(hex & 0xFF) / 255)
    }
}
