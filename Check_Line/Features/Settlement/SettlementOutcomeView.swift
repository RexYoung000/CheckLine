import SwiftUI

struct SettlementResultEntrance {
    let heading: CGRect
    let button: CGRect
    let start: TimeInterval
    let duration: TimeInterval

    func remaining(at elapsed: TimeInterval) -> CGFloat {
        let progress = CGFloat(min(1, max(0, (elapsed - start) / duration)))
        return 1 - progress * progress * (3 - 2 * progress)
    }
}

struct SettlementOutcomeView: View {
    let receipt: SettlementOutcomeReceipt
    let waveStarted: Date?
    let entrance: SettlementResultEntrance?
    let onSkipMotion: () -> Void
    let onDone: () -> Void

    @State private var finishedEntrance: Date?
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ScaledMetric(relativeTo: .largeTitle) private var settlementAmountSize = 52.0
    #if DEBUG
    @Environment(\.settlementOutcomeProbe) private var probe
    #endif

    private let settlementCredit = Color.paper(light: 0x0A647B, dark: 0x9BDEED)
    private let settlementOverrun = Color.paper(light: 0x8A4D15, dark: 0xFFC27F)

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: geometry.size.height < 700 ? 14 : 22) {
                    header
                    settlementScene(compact: geometry.size.height < 550 ||
                                    (geometry.size.height < 700 && receipt.recoveryBefore != receipt.recoveryAfter))
                }
                .padding(geometry.size.height < 700 ? 18 : 22)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .foregroundStyle(PaperTheme.ink)
            .safeAreaInset(edge: .bottom) { footer }
            .background(PaperTheme.canvas.ignoresSafeArea())
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("native.outcome.result")
        .task(id: waveStarted) {
            guard let waveStarted, let entrance else { return }
            let deadline = waveStarted.addingTimeInterval(entrance.start + entrance.duration)
            do {
                try await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow)))
                try Task.checkCancellation()
                finishedEntrance = waveStarted
            } catch {
                // A skipped or dismissed wave no longer owns this entrance.
            }
        }
    }

    private var header: some View {
        HStack {
            settlementContext
                .modifier(entranceMotion(for: .heading))
                .layoutPriority(1)
            Spacer(minLength: 4)
            Button(String(localized: "native.outcome.skip"), action: onSkipMotion)
                .font(.subheadline)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier("native.outcome.skip")
                .opacity(waveStarted == nil ? 0 : 1)
                .allowsHitTesting(waveStarted != nil)
                .accessibilityHidden(waveStarted == nil)
            Button(action: onDone) {
                Image(systemName: "xmark")
                    .font(.subheadline)
                    .frame(width: 44, height: 44)
                    .background(PaperTheme.ink.opacity(0.06), in: Circle())
            }
            .accessibilityLabel(String(localized: "action.close"))
        }
    }

    private var footer: some View {
        Button(action: onDone) {
            Text(String(localized: "native.returnBudget")).frame(maxWidth: .infinity)
        }
        .buttonStyle(PaperSolidButtonStyle(foreground: PaperTheme.primaryInk, background: PaperTheme.primary))
        #if DEBUG
        .reportSettlementFrame(.button, to: probe)
        #endif
        .modifier(entranceMotion(for: .button))
        .frame(maxWidth: 560)
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(PaperTheme.canvas)
    }

    private var settlementContext: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(receipt.title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                #if DEBUG
                .reportSettlementFrame(.title, to: probe)
                #endif
            HStack(spacing: 5) {
                Text(receipt.periodStart, format: .dateTime.year().month().day())
                Text(verbatim: "–")
                if let end = receipt.periodEnd {
                    Text(end, format: .dateTime.year().month().day())
                } else {
                    Text(String(localized: "wallet.noDeadline"))
                }
            }
            .font(.caption)
            .foregroundStyle(PaperTheme.muted)
            .accessibilityElement(children: .combine)
            #if DEBUG
            .reportSettlementFrame(.dates, to: probe)
            #endif
        }
        #if DEBUG
        .reportSettlementFrame(.context, to: probe)
        #endif
    }

    private func entranceMotion(for part: SettlementEntranceMotion.Part) -> SettlementEntranceMotion {
        let started = waveStarted == finishedEntrance ? nil : waveStarted
        return SettlementEntranceMotion(started: started, entrance: entrance, part: part)
    }

    private func settlementScene(compact: Bool) -> some View {
        #if DEBUG
        probe?(.detailsEvaluated)
        #endif
        return VStack(spacing: compact ? 12 : 20) {
            settlementHero(compact: compact)
            PaperCard {
                VStack(spacing: 0) {
                    settlementLine("wallet.settlement.budget", amount: receipt.settlement.budgetAmountSnapshot, currency: receipt.originalCurrency)
                    Divider()
                    settlementLine("wallet.settlement.confirmed", amount: receipt.settlement.confirmedSpent, currency: receipt.originalCurrency)
                    if receipt.recoveryBefore > receipt.recoveryAfter {
                        Divider()
                        settlementLine(
                            "native.outcome.recoveryReduced",
                            amount: receipt.recoveryAfter - receipt.recoveryBefore,
                            showsSign: true,
                            emphasis: settlementCredit
                        )
                    }
                    if receipt.net != 0 {
                        Divider()
                        settlementLine(
                            receipt.net > 0 ? "native.outcome.transferred" : "native.outcome.walletDeducted",
                            amount: receipt.net,
                            showsSign: true,
                            emphasis: receipt.net > 0 ? settlementCredit : settlementOverrun
                        )
                    }
                    if receipt.recoveryAfter > 0 {
                        Divider()
                        settlementLine("wallet.settlement.recoveryAfter", amount: receipt.recoveryAfter, emphasis: settlementOverrun)
                    }
                    Divider()
                    settlementLine("wallet.settlement.walletAfter", amount: receipt.after.balance)
                        .accessibilityIdentifier("native.outcome.wallet")
                }
                .padding(.vertical, -5)
            }
        }
    }

    private func settlementHero(compact: Bool) -> some View {
        let amountLabel: LocalizedStringKey = receipt.originalAmount < 0 ? "wallet.settlement.overrun" : "wallet.settlement.surplus"
        let resultColor = receipt.originalAmount < 0 ? settlementOverrun : receipt.originalAmount > 0 ? settlementCredit : PaperTheme.ink
        return VStack(spacing: compact ? 7 : 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(resultColor)
                .frame(width: 46, height: 46)
                .background(resultColor.opacity(0.12), in: Circle())
                .overlay { Circle().strokeBorder(resultColor.opacity(0.24)) }
                .accessibilityHidden(true)
            Text(String(localized: "wallet.settlement.saved"))
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 2) {
                Text(MoneyFormat.string(receipt.originalAmount, currencyCode: receipt.originalCurrency, showsSign: true))
                    .font(.system(size: settlementAmountSize, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .accessibilityIdentifier("native.outcome.periodAmount")
                    #if DEBUG
                    .reportSettlementFrame(.amount, to: probe)
                    #endif
                Text(amountLabel)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(resultColor)
            .accessibilityElement(children: .combine)
        }
        .multilineTextAlignment(.center)
        .padding(.vertical, compact ? 12 : 20)
        .frame(maxWidth: .infinity)
        .background {
            if !reduceTransparency {
                RadialGradient(colors: [resultColor.opacity(0.09), .clear], center: .top, startRadius: 0, endRadius: 175)
            }
        }
    }

    private func settlementLine(
        _ title: LocalizedStringKey, amount: Decimal, currency rowCurrency: String? = nil,
        showsSign: Bool = false, emphasis: Color = PaperTheme.ink
    ) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
        let value = MoneyFormat.string(amount, currencyCode: rowCurrency ?? receipt.walletCurrency, showsSign: showsSign)
        return layout {
            Text(title).foregroundStyle(PaperTheme.muted)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
            Text(verbatim: value)
                .foregroundStyle(emphasis)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.subheadline)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

private struct SettlementEntranceMotion: ViewModifier {
    nonisolated enum Part {
        case heading, button
    }

    let started: Date?
    let entrance: SettlementResultEntrance?
    let part: Part

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: started == nil)) { clock in
            let remaining = started.flatMap { start in
                entrance?.remaining(at: clock.date.timeIntervalSince(start))
            } ?? 0
            content.visualEffect { content, proxy in
                let frame = proxy.frame(in: .global)
                let source = (part == .heading ? entrance?.heading : entrance?.button) ?? frame
                let centered = part == .button
                let scale = centered ? 1 + (source.width / max(1, frame.width) - 1) * remaining : 1
                let dx = centered ? source.midX - frame.midX : source.minX - frame.minX
                let dy = centered ? source.midY - frame.midY : source.minY - frame.minY
                return content.scaleEffect(x: scale, y: 1).offset(x: dx * remaining, y: dy * remaining)
            }
        }
    }
}

#if DEBUG
nonisolated enum SettlementOutcomePart: CaseIterable, Hashable {
    case context, title, dates, amount, button
}

enum SettlementOutcomeEvent {
    case frame(SettlementOutcomePart, CGRect)
    case detailsEvaluated
}

private struct SettlementOutcomeProbeKey: EnvironmentKey {
    static let defaultValue: ((SettlementOutcomeEvent) -> Void)? = nil
}

extension EnvironmentValues {
    var settlementOutcomeProbe: ((SettlementOutcomeEvent) -> Void)? {
        get { self[SettlementOutcomeProbeKey.self] }
        set { self[SettlementOutcomeProbeKey.self] = newValue }
    }
}

private extension View {
    @ViewBuilder
    func reportSettlementFrame(
        _ part: SettlementOutcomePart, to probe: ((SettlementOutcomeEvent) -> Void)?
    ) -> some View {
        if let probe {
            onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                probe(.frame(part, frame))
            }
        } else {
            self
        }
    }
}
#endif
