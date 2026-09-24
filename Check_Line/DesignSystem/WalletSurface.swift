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
    @Environment(\.walletReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollViewReader { reader in
            ScrollView {
                content()
                    .id("wallet-page-top")
                    .padding(.horizontal, lightHeader ? 0 : 18)
                    .padding(.top, lightHeader ? 0 : 12)
                    .padding(.bottom, 24)
                    .frame(maxWidth: PaperTheme.Layout.contentMaxWidth)
                    .frame(maxWidth: .infinity)
                    .opacity(lightHeader ? 1 : chrome?.interiorReveal ?? 1)
                    .offset(y: !lightHeader && !reduceMotion ? 16 * (1 - (chrome?.interiorReveal ?? 1)) : 0)
                    .rotation3DEffect(.degrees(!lightHeader && !reduceMotion ? -5 * (1 - (chrome?.interiorReveal ?? 1)) : 0), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.25)
            }
            .scrollDisabled(chrome?.isTransitioning == true)
            .scrollDismissesKeyboard(.interactively)
            .background {
                if lightHeader {
                    GeometryReader { geometry in
                        ZStack(alignment: .top) {
                            PaperTheme.canvas.ignoresSafeArea()
                            PaperTheme.paper
                                .frame(height: min(geometry.size.height * 0.42, 340))
                                .frame(maxWidth: .infinity, alignment: .top)
                                .ignoresSafeArea(edges: .top)
                        }
                    }
                }
                else { WalletInteriorSurface().ignoresSafeArea() }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                WalletPageHeader(title: lightHeader ? nil : title, workspace: workspace, light: lightHeader, onAdd: onAdd)
            }
            .opacity(chrome?.stageOpacity ?? 1)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 8) {
                    if let banner = workspace.actionFeedback {
                        HStack {
                            Text(banner.localizedText).font(.caption).lineLimit(2)
                            Spacer(minLength: 8)
                            if workspace.lastUndo != nil {
                                Button(String(localized: "action.undo")) { workspace.undoLast() }
                                    .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                            }
                            Button(String(localized: "action.close"), systemImage: "xmark") { workspace.dismissActionFeedback() }
                                .labelStyle(.iconOnly).font(.caption).frame(width: 44, height: 44)
                        }
                        .padding(.horizontal, 16).walletSurface(radius: 22)
                    }
                    if !WalletTabPresentation.usesSystemBar {
                        WalletGlassNavigation(workspace: workspace)
                    } else {
                        HStack {
                            Spacer()
                            WalletAgentButton(workspace: workspace)
                        }
                    }
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 6)
                .frame(maxWidth: .infinity)
                .background { if lightHeader && !WalletTabPresentation.usesSystemBar { PaperTheme.canvas.ignoresSafeArea(edges: .bottom) } }
            }
            .toolbar(WalletTabPresentation.usesSystemBar ? .visible : .hidden, for: .tabBar)
            .toolbar(.hidden, for: .bottomBar)
            .onChange(of: chrome?.presentedTab) { _, tab in
                if lightHeader && tab == .home { reader.scrollTo("wallet-page-top", anchor: .top) }
            }
            }
        }
    }
}

struct LiquidWave: Shape {
    var level: CGFloat
    var phase: Double
    var amplitude: CGFloat
    var surfaceOnly = false
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
        if !surfaceOnly {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
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
    @State private var motionClock = LiquidMotionClock()
    private var animates: Bool { flows && !reduceMotion && visible && scenePhase == .active }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.42, green: 0.42, blue: 0.55), Color(red: 0.23, green: 0.24, blue: 0.35), Color(red: 0.18, green: 0.19, blue: 0.29)], startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [.white.opacity(0.17), .clear], center: .topLeading, startRadius: 0, endRadius: 280)
            TimelineView(.animation(minimumInterval: 1.0/30, paused: !animates)) { _ in
                let phase = motionClock.phase(at: ProcessInfo.processInfo.systemUptime)
                let level = CGFloat(BudgetPresentation.fill(card))
                ZStack {
                    LiquidWave(level: level > 0 ? min(1, level + 0.009) : 0, phase: phase + 1.2, amplitude: reduceMotion ? 0 : 3)
                        .fill(PaperTheme.accent.opacity(0.48))
                    LiquidWave(level: level, phase: phase, amplitude: reduceMotion ? 0 : 3.5)
                        .fill(LinearGradient(stops: [
                            .init(color: Color(red: 0.64, green: 0.58, blue: 1), location: 0),
                            .init(color: Color(red: 0.47, green: 0.42, blue: 0.96), location: 0.46),
                            .init(color: Color(red: 0.29, green: 0.27, blue: 0.82), location: 0.8),
                            .init(color: Color(red: 0.20, green: 0.18, blue: 0.61), location: 1)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay {
                            RadialGradient(colors: [Color(red: 0.80, green: 0.76, blue: 1).opacity(0.4), .clear], center: .leading, startRadius: 0, endRadius: 270)
                                .mask { LiquidWave(level: level, phase: phase, amplitude: reduceMotion ? 0 : 3.5) }
                        }
                        .overlay {
                            LiquidWave(level: level, phase: phase, amplitude: reduceMotion ? 0 : 3.5, surfaceOnly: true)
                                .stroke(LinearGradient(colors: [.white.opacity(0.10), .white.opacity(0.8), PaperTheme.accent.opacity(0.3)], startPoint: .leading, endPoint: .trailing), lineWidth: 1)
                        }
                }.animation(reduceMotion ? nil : .easeOut(duration: 0.65), value: level)
            }
            .accessibilityHidden(true)
            WalletGrain().opacity(0.7)
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
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.08), .white.opacity(0.22)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                .overlay { RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.07), lineWidth: 0.5).padding(2) }
        }
        .shadow(color: .black.opacity(0.18), radius: 12, y: 7)
        .onAppear { visible = true }
        .onDisappear {
            visible = false
            motionClock.setRunning(false, at: ProcessInfo.processInfo.systemUptime)
        }
        .onChange(of: animates, initial: true) { _, running in
            motionClock.setRunning(running, at: ProcessInfo.processInfo.systemUptime)
        }
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
