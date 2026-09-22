import SwiftUI

struct WalletSurface: ViewModifier {
    var radius: CGFloat = 24
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.065), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .background(PaperTheme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(LinearGradient(colors: [.white.opacity(0.16), .white.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
    }
}

extension View {
    func walletSurface(radius: CGFloat = 24) -> some View { modifier(WalletSurface(radius: radius)) }
}

struct WalletSymbol: View {
    var name: String
    var size: CGFloat = 56
    var body: some View {
        Image(systemName: name)
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(.white.opacity(0.95))
            .frame(width: size, height: size)
            .background(LinearGradient(colors: [Color(red: 0.69, green: 0.62, blue: 0.83), Color(red: 0.39, green: 0.33, blue: 0.51)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: size * 0.32, style: .continuous).strokeBorder(.white.opacity(0.24), lineWidth: 0.8) }
            .shadow(color: .black.opacity(0.2), radius: 8, y: 5)
            .accessibilityHidden(true)
    }
}

struct WalletRootPage<Content: View>: View {
    var title: String
    @Bindable var workspace: CheckLineWorkspace
    var lightHeader = false
    var onAdd: (() -> Void)?
    @ViewBuilder var content: () -> Content
    @Environment(\.shellChrome) private var chrome

    var body: some View {
        NavigationStack {
            ScrollView {
                content()
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                    .frame(maxWidth: PaperTheme.Layout.contentMaxWidth)
                    .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PaperTheme.canvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title).font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
                        if DesignPreviewData.isEnabled { Text(String(localized: "wallet.preview")).font(.caption2) }
                    }
                    Spacer()
                    if let onAdd {
                        Button(action: onAdd) { Image(systemName: "plus").frame(width: 44, height: 44) }
                            .accessibilityLabel(String(localized: "wallet.create"))
                    }
                    Button { chrome?.isSettingsPresented = true } label: {
                        Image(systemName: "person.crop.circle").font(.title3).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(String(localized: "tab.settings"))
                }
                .foregroundStyle(lightHeader ? PaperTheme.paperInk : PaperTheme.ink)
                .padding(.horizontal, 20)
                .padding(.vertical, 3)
                .background(lightHeader ? PaperTheme.paper : PaperTheme.canvas)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                WalletInputBar(workspace: workspace).padding(.horizontal, 18).padding(.vertical, 8)
            }
        }
    }
}

struct WalletInputBar: View {
    @Bindable var workspace: CheckLineWorkspace
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        HStack(spacing: 6) {
            Button { workspace.showAgent = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles").font(.system(size: 17))
                        .frame(width: 30, height: 30).background(PaperTheme.accent.opacity(0.2), in: Circle())
                    Text(typeSize.isAccessibilitySize ? String(localized: "wallet.agent.open") : String(localized: "wallet.agent.prompt"))
                        .font(.subheadline).lineLimit(1)
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 44)
            }
            .accessibilityLabel(String(localized: "wallet.agent.open"))
            if workspace.lastUndo != nil {
                Button { workspace.undoLast() } label: { Image(systemName: "arrow.uturn.backward").frame(width: 44, height: 44) }
                    .accessibilityLabel(String(localized: "action.undo"))
            }
            Button { workspace.openComposer(.record) } label: { Image(systemName: "plus").frame(width: 44, height: 44) }
                .accessibilityLabel(String(localized: "capture.title"))
        }
        .buttonStyle(.plain)
        .foregroundStyle(PaperTheme.ink)
        .padding(.leading, 9).padding(.trailing, 3)
        .paperGlass(.capsule, interactive: true)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }
}

struct LiquidWave: Shape {
    var level: CGFloat
    var phase: Double
    var amplitude: CGFloat
    var animatableData: CGFloat {
        get { level }
        set { level = newValue }
    }
    func path(in rect: CGRect) -> Path {
        let edge = min(1, level * 12, (1-level) * 12)
        var path = Path()
        for index in 0...60 {
            let x = rect.width * CGFloat(index) / 60
            let position = Double(x / max(rect.width, 1))
            let y = rect.height * (1-level) + edge * amplitude * CGFloat(sin(position * .pi * 2 + phase) + sin(position * .pi * 3.3 - phase) * 0.23)
            if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct LiquidBudgetCard: View {
    var card: HomeBudgetCardModel
    var flows = false
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var visible = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.40, green: 0.39, blue: 0.52), Color(red: 0.20, green: 0.21, blue: 0.32)], startPoint: .topLeading, endPoint: .bottomTrailing)
            TimelineView(.animation(minimumInterval: 1.0/30, paused: !flows || reduceMotion || !visible || scenePhase != .active)) { timeline in
                let phase = reduceMotion || !flows ? 0 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6.83) / 6.83 * .pi * 2
                let level = CGFloat(BudgetPresentation.fill(card))
                ZStack {
                    LiquidWave(level: level > 0 ? min(1, level + 0.009) : 0, phase: phase + 1.2, amplitude: reduceMotion ? 0 : 3)
                        .fill(PaperTheme.accent.opacity(0.48))
                    LiquidWave(level: level, phase: phase, amplitude: reduceMotion ? 0 : 3.5)
                        .fill(LinearGradient(colors: [Color(red: 0.58, green: 0.52, blue: 1), Color(red: 0.27, green: 0.24, blue: 0.77)], startPoint: .top, endPoint: .bottom))
                        .overlay {
                            LiquidWave(level: level, phase: phase, amplitude: reduceMotion ? 0 : 3.5)
                                .stroke(.white.opacity(0.26), lineWidth: 0.8)
                        }
                }.animation(reduceMotion ? nil : .easeOut(duration: 0.65), value: level)
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 18) {
                Text(card.name).font(.title3.weight(.medium)).lineLimit(2).padding(.trailing, 40)
                Spacer(minLength: 8)
                HStack {
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 5) {
                        if BudgetPresentation.remaining(card) < 0 {
                            Text(card.snapshot.certainOverrunAmount > 0 ? String(localized: "wallet.overrun") : String(localized: "wallet.possibleOverrun"))
                                .font(.caption)
                        }
                        Text(MoneyFormat.string(abs(BudgetPresentation.remaining(card)), currencyCode: card.currencyCode))
                            .font(.system(.largeTitle).weight(.medium)).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.5)
                    }
                }
            }
            .padding(22)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.16), radius: 6, y: 2)
        }
        .frame(minHeight: typeSize.isAccessibilitySize ? 250 : 202)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(.white.opacity(0.28), lineWidth: 0.8) }
        .shadow(color: .black.opacity(0.18), radius: 12, y: 7)
        .onAppear { visible = true }.onDisappear { visible = false }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(card.name)
        .accessibilityValue(String(localized: "v1.card.remaining") + " " + MoneyFormat.string(BudgetPresentation.remaining(card), currencyCode: card.currencyCode))
    }
}

struct WalletExpenseRow: View {
    var expense: Expense
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: BudgetPresentation.symbol(for: expense))
                .foregroundStyle(PaperTheme.accent).frame(width: 36, height: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.merchant ?? String(localized: "v1.card.record.untitled")).font(.subheadline).lineLimit(2)
                Text(expense.occurredAt, format: .dateTime.month().day())
                    .font(.caption).foregroundStyle(PaperTheme.muted)
                if expense.attributionState == .pending {
                    Text(String(localized: "v1.card.pending")).font(.caption).foregroundStyle(PaperTheme.accent)
                }
            }
            Spacer(minLength: 4)
            Text(MoneyFormat.string(expense.kind == .refund ? expense.originalAmount : -expense.originalAmount, currencyCode: expense.originalCurrencyCode))
                .font(.subheadline).monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
        }
        .foregroundStyle(PaperTheme.ink).padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}
