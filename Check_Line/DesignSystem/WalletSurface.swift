import SwiftUI

struct WalletSurface: ViewModifier {
    var radius: CGFloat = 24
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: [PaperTheme.ink.opacity(0.025), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .background(PaperTheme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(LinearGradient(colors: [PaperTheme.ink.opacity(0.1), PaperTheme.ink.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: .black.opacity(0.07), radius: 12, y: 5)
    }
}

extension View {
    func walletSurface(radius: CGFloat = 24) -> some View { modifier(WalletSurface(radius: radius)) }
}

struct WalletTransitionSource: ViewModifier {
    var id: UUID
    var namespace: Namespace.ID
    @Environment(\.walletReduceMotion) private var reduceMotion

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 18.0, *), !reduceMotion {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}

struct WalletSymbol: View {
    var name: String
    var size: CGFloat = 56
    var body: some View {
        Image(systemName: name)
            .font(.system(size: size * 0.42, weight: .regular))
            .foregroundStyle(PaperTheme.accent)
            .frame(width: size, height: size)
            .background(PaperTheme.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: size * 0.32, style: .continuous).strokeBorder(PaperTheme.accent.opacity(0.18), lineWidth: 0.8) }
            .accessibilityHidden(true)
    }
}

private struct WalletTopScrollEdge: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
    }
}

private struct WalletHeaderBar: ViewModifier {
    var title: String?
    var workspace: CheckLineWorkspace
    var light: Bool
    var onAdd: (() -> Void)?

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.safeAreaBar(edge: .top, spacing: 0) { header }
        } else {
            content.safeAreaInset(edge: .top, spacing: 0) { header }
        }
    }

    private var header: some View {
        WalletPageHeader(title: title, workspace: workspace, light: light, onAdd: onAdd)
    }
}

struct WalletRootPage<Content: View>: View {
    var tab: CheckLineAppTab
    var title: String
    @Bindable var workspace: CheckLineWorkspace
    var lightHeader = false
    var fullPaperBackground = false
    var onAdd: (() -> Void)?
    var detailPresented: Binding<Bool> = .constant(false)
    var detail: (() -> AnyView)? = nil
    @ViewBuilder var content: () -> Content
    @Environment(\.shellChrome) private var chrome
    @Environment(\.walletReduceMotion) private var reduceMotion

    @State private var path = NavigationPath()
    private enum RootDetailRoute: Hashable { case detail }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                if lightHeader {
                    WalletHomeBackdrop(showsSymbols: !fullPaperBackground).ignoresSafeArea()
                } else {
                    WalletInteriorSurface().ignoresSafeArea()
                }
            ScrollViewReader { reader in
            ScrollView {
                content()
                    .id("wallet-page-top")
                    .padding(.horizontal, lightHeader ? 0 : 18)
                    .padding(.top, lightHeader ? 0 : 12)
                    .padding(.bottom, (WalletTabTransition.usesSystemBar ? 24 : 104) + (workspace.actionFeedback == nil ? 0 : 56))
                    .frame(maxWidth: PaperTheme.Layout.contentMaxWidth)
                    .frame(maxWidth: .infinity)
                    .opacity(lightHeader ? 1 : chrome?.interiorReveal ?? 1)
                    .offset(y: !lightHeader && !reduceMotion ? 16 * (1 - (chrome?.interiorReveal ?? 1)) : 0)
                    .rotation3DEffect(.degrees(!lightHeader && !reduceMotion ? -5 * (1 - (chrome?.interiorReveal ?? 1)) : 0), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.25)
            }
            .modifier(WalletTopScrollEdge())
            .scrollDisabled(chrome?.isTransitioning == true)
            .scrollDismissesKeyboard(.interactively)
            .toolbar(.hidden, for: .navigationBar)
            .modifier(WalletHeaderBar(title: lightHeader ? nil : title, workspace: workspace, light: lightHeader, onAdd: onAdd))
            .overlay(alignment: .bottom) {
                if WalletTabTransition.usesSystemBar && chrome?.isShowingDetail != true {
                    WalletActionFeedback(workspace: workspace)
                        .frame(maxWidth: 560)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 8)
                }
            }
            .opacity(chrome?.stageOpacity ?? 1)
            .toolbar(WalletTabTransition.usesSystemBar && chrome?.isShowingDetail != true ? .visible : .hidden, for: .tabBar)
            .toolbar(.hidden, for: .bottomBar)
            .onAppear {
                if chrome?.selectedTab == tab { chrome?.isShowingDetail = false }
            }
            .onDisappear {
                if chrome?.selectedTab == tab { chrome?.isShowingDetail = true }
            }
            .onChange(of: chrome?.presentedTab) { _, tab in
                if lightHeader && tab == .home { reader.scrollTo("wallet-page-top", anchor: .top) }
            }
            }
            }
            .environment(\.budgetWorkspacePush, { path.append($0) })
            .navigationDestination(for: BudgetWorkspaceRoute.self) { BudgetWorkspaceDestination(workspace: workspace, route: $0) }
            .navigationDestination(for: RootDetailRoute.self) { _ in detail?() }
            .onChange(of: detailPresented.wrappedValue) { _, showing in
                if showing && path.isEmpty { path.append(RootDetailRoute.detail) }
            }
            .onChange(of: path.count) { _, count in
                if chrome?.selectedTab == tab { chrome?.isShowingDetail = count > 0 }
                if count == 0 && detailPresented.wrappedValue { detailPresented.wrappedValue = false }
            }
        }
    }
}

struct WalletHomeBackdrop: View {
    var showsSymbols = true
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = false
    private let symbols = ["cup.and.saucer", "book.closed", "headphones", "heart", "star", "globe"]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15, paused: reduceMotion || scenePhase != .active || !visible)) { timeline in
            GeometryReader { geometry in
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                ZStack(alignment: .top) {
                    PaperTheme.canvas
                    RadialGradient(colors: [PaperTheme.accent.opacity(0.16), .clear], center: UnitPoint(x: 0.5 - 0.28 * cos(time * .pi / 6), y: 0.15 + 0.07 * sin(time * .pi / 9)), startRadius: 0, endRadius: geometry.size.width * 0.78)
                    RadialGradient(colors: [PaperTheme.gold.opacity(0.11), .clear], center: UnitPoint(x: 0.5 + 0.28 * cos(time * .pi / 6), y: 0.24 - 0.06 * sin(time * .pi / 8 + 0.7)), startRadius: 0, endRadius: geometry.size.width * 0.58)
                    if showsSymbols {
                        ForEach(0..<4, id: \.self) { index in
                            let duration = 7.0 + Double(index) * 1.8
                            let cycle = time / duration + Double(index) * 0.23
                            let turn = floor(cycle)
                            let progress = cycle - turn
                            let x = index < 2 ? 0.15 + 0.70 * symbolSeed(index, Int(turn), 43)
                                : (index == 2 ? 0.055 : 0.945)
                            let y = index < 2 ? 0.10 + 0.14 * symbolSeed(index, Int(turn), 67)
                                : 0.25 + 0.24 * symbolSeed(index, Int(turn), 67)
                            Image(systemName: symbols[(index + Int(turn.magnitude) % symbols.count) % symbols.count])
                                .font(.system(size: 15 + CGFloat(index % 3) * 2, weight: .light))
                                .foregroundStyle(PaperTheme.accent)
                                .opacity(reduceMotion ? 0.11 : 0.17 * pow(sin(.pi * progress), 2))
                                .position(x: geometry.size.width * x + CGFloat(progress) * 7, y: geometry.size.height * y - CGFloat(progress) * 5)
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .onAppear { visible = true }
        .onDisappear { visible = false }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func symbolSeed(_ index: Int, _ turn: Int, _ multiplier: Int) -> CGFloat {
        CGFloat((index * multiplier + turn * 29 + 43) % 97) / 97
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
    var showsRemainingRatio = true
    var flows = false
    var reflectionPoint: CGPoint?
    var remainingChange: BudgetRemainingChange?
    var remainingMotionContext = RemainingMotionContext()
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var visible = false
    @State private var motionClock = LiquidMotionClock()
    @State private var hoverPoint: CGPoint?
    private var animates: Bool { flows && !reduceMotion && visible && scenePhase == .active }
    private var activeReflection: CGPoint? { reduceMotion ? nil : reflectionPoint ?? hoverPoint }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.paper(light: 0xFBFAF8, dark: 0x302B35), Color.paper(light: 0xF4EFF5, dark: 0x28232D)], startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [PaperTheme.accent.opacity(0.07), .clear], center: .topLeading, startRadius: 0, endRadius: 260)
            TimelineView(.animation(minimumInterval: 1.0/30, paused: !animates)) { _ in
                let elapsed = motionClock.elapsedTime(at: ProcessInfo.processInfo.systemUptime)
                let phase = motionClock.phase(at: ProcessInfo.processInfo.systemUptime)
                let level = CGFloat(BudgetPresentation.fill(card))
                ZStack {
                    LiquidWave(level: level, phase: phase, amplitude: reduceMotion ? 0 : 3.5)
                        .fill(LinearGradient(stops: [
                            .init(color: PaperTheme.waterTop.opacity(0.88), location: 0),
                            .init(color: PaperTheme.waterBottom.opacity(0.96), location: 1)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing))
                    if level > 0 {
                        BudgetBubbleField(level: level, phase: phase, elapsed: elapsed)
                            .mask { LiquidWave(level: level, phase: phase, amplitude: reduceMotion ? 0 : 3.5) }
                        LiquidWave(level: level, phase: phase, amplitude: reduceMotion ? 0 : 3.5, surfaceOnly: true)
                            .stroke(.white.opacity(0.23), lineWidth: 0.7)
                    }
                }.animation(reduceMotion ? nil : .easeOut(duration: 0.65), value: level)
            }
            .accessibilityHidden(true)
            reflection
            VStack(alignment: .leading, spacing: 10) {
                Text(card.name).font(.title2.weight(.semibold)).lineLimit(2).padding(.trailing, 44)
                Text((card.cycleType == .repeating ? String(localized: "v1.cycle.repeating") : String(localized: "v1.cycle.oneShot")) + " · " + card.currencyCode)
                    .font(.caption).foregroundStyle(PaperTheme.muted)
                Spacer(minLength: 8)
                HStack {
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 5) {
                        Text(BudgetPresentation.remaining(card) >= 0 ? String(localized: "v1.card.remaining") : (card.snapshot.certainOverrunAmount > 0 ? String(localized: card.snapshot.possibleOverrunAmount > 0 ? "wallet.provisionalOverrun" : "wallet.overrun") : String(localized: "wallet.possibleOverrun")))
                            .font(.caption)
                        BudgetRemainingAmountText(card: card, change: remainingChange, context: remainingMotionContext)
                            .font(.system(.largeTitle).weight(.medium)).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.5)
                        if showsRemainingRatio && BudgetPresentation.remaining(card) >= 0 {
                            Text("\(Int((BudgetPresentation.fill(card) * 100).rounded()))% " + String(localized: "budget.remaining.short"))
                                .font(.caption2).foregroundStyle(PaperTheme.muted)
                        }
                    }
                }
            }
            .padding(22)
            .foregroundStyle(PaperTheme.ink)
        }
        .frame(minHeight: typeSize.isAccessibilitySize ? 280 : 258)
        .clipShape(RoundedRectangle(cornerRadius: 29, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 29, style: .continuous)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.66), PaperTheme.accent.opacity(0.10), PaperTheme.ink.opacity(0.09)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.9)
        }
        .shadow(color: PaperTheme.accent.opacity(0.12), radius: 14, y: 8)
        .onContinuousHover { phase in
            switch phase {
            case .active(let point): hoverPoint = point
            case .ended: hoverPoint = nil
            }
        }
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

    private var reflection: some View {
        GeometryReader { proxy in
            let point = activeReflection ?? CGPoint(x: proxy.size.width * 0.5, y: proxy.size.height * 0.35)
            let center = UnitPoint(x: min(1, max(0, point.x / max(proxy.size.width, 1))), y: min(1, max(0, point.y / max(proxy.size.height, 1))))
            ZStack {
                RadialGradient(colors: [.white.opacity(0.12), .clear], center: center, startRadius: 0, endRadius: 230)
                RoundedRectangle(cornerRadius: 29, style: .continuous)
                    .strokeBorder(.white.opacity(0.75), lineWidth: 1.4)
                    .mask { RadialGradient(colors: [.white, .clear], center: center, startRadius: 12, endRadius: 135) }
            }
            .opacity(activeReflection == nil ? 0 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: activeReflection == nil)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct WalletEmptyBudgetCard: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                Image(systemName: "plus")
                    .font(.title3.weight(.medium))
                    .frame(width: 52, height: 52)
                    .background(PaperTheme.accent.opacity(0.12), in: Circle())
                Text(String(localized: "wallet.empty.firstCard"))
                    .font(.headline)
            }
            .foregroundStyle(PaperTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 258)
            .background(LinearGradient(colors: [PaperTheme.card.opacity(0.85), PaperTheme.accent.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 29, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 29, style: .continuous).strokeBorder(PaperTheme.accent.opacity(0.18), lineWidth: 1) }
        }
        .buttonStyle(PaperScalePressStyle())
        .accessibilityIdentifier("wallet.empty.card")
    }
}

private struct BudgetBubbleField: View {
    var level: CGFloat
    var phase: Double
    var elapsed: TimeInterval

    var body: some View {
        Canvas { context, size in
            let liquidHeight = size.height * level
            guard liquidHeight > 12 else { return }
            for index in 0..<30 {
                let xSeed = seed(index, 73)
                let sizeSeed = seed(index, 41)
                let pace = 3.4 + seed(index, 89) * 4.2
                let progress = (elapsed / pace + seed(index, 23)).truncatingRemainder(dividingBy: 1)
                let radius = CGFloat(0.8 + sizeSeed * 2.4)
                let x = CGFloat(xSeed * 0.94 + 0.03) * size.width + CGFloat(sin(progress * .pi * 2 + Double(index) + phase * 0.2)) * 4
                let y = size.height - CGFloat(progress) * liquidHeight * 0.96
                let fade = min(1, min(progress * 8, (1 - progress) * 7))
                let bubble = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                context.stroke(Path(ellipseIn: bubble), with: .color(.white.opacity(0.58 * fade)), lineWidth: 0.7)
                if index.isMultiple(of: 4) {
                    context.fill(Path(ellipseIn: CGRect(x: x - radius * 0.4, y: y - radius * 0.5, width: radius * 0.45, height: radius * 0.45)), with: .color(.white.opacity(0.48 * fade)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func seed(_ index: Int, _ multiplier: Int) -> Double {
        Double((index * multiplier + 17) % 101) / 101
    }
}

struct WalletExpenseRow: View {
    var expense: Expense
    var showsDate = true
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: BudgetPresentation.symbol(for: expense))
                .foregroundStyle(PaperTheme.accent).frame(width: 36, height: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.merchant ?? String(localized: "v1.card.record.untitled")).font(.subheadline).lineLimit(2)
                if showsDate {
                    Text(expense.occurredAt, format: .dateTime.month().day())
                        .font(.caption).foregroundStyle(PaperTheme.muted)
                }
                if expense.attributionState == .pending {
                    Text(String(localized: "v1.card.pending")).font(.caption).foregroundStyle(PaperTheme.accent)
                }
            }
            Spacer(minLength: 4)
            Text(MoneyFormat.string(expense.kind == .refund ? expense.originalAmount : -expense.originalAmount, currencyCode: expense.originalCurrencyCode))
                .font(.subheadline).monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
        }
        .foregroundStyle(PaperTheme.ink).padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(showsDate ? "" : expense.occurredAt.formatted(date: .abbreviated, time: .omitted))
    }
}
