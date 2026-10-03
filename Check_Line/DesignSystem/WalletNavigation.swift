import SwiftUI
import UIKit

/// The dark front of the wallet rises at both edges and overlaps the budget card.
struct WalletCardholderSurface: View {
    var opening: CGFloat = 1
    var body: some View {
        WalletPocketShape(opening: opening)
            .fill(LinearGradient(colors: [PaperTheme.pocket, PaperTheme.canvas], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(alignment: .top) {
                WalletPocketRim()
                    .stroke(LinearGradient(colors: [PaperTheme.ink.opacity(0.13), PaperTheme.ink.opacity(0.02), PaperTheme.ink.opacity(0.08)], startPoint: .leading, endPoint: .trailing), lineWidth: 0.8)
                    .frame(height: 24 * opening)
            }
            .overlay { WalletGrain().opacity(0.24).clipShape(WalletPocketShape(opening: opening)) }
            .shadow(color: .black.opacity(0.08), radius: 8, y: -4)
            .accessibilityHidden(true)
    }
}

private struct WalletPocketRim: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let shoulder = min(48, rect.width * 0.14)
        path.move(to: .zero)
        path.addCurve(to: CGPoint(x: shoulder, y: rect.height), control1: CGPoint(x: shoulder * 0.4, y: 0), control2: CGPoint(x: shoulder * 0.45, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width - shoulder, y: rect.height))
        path.addCurve(to: CGPoint(x: rect.width, y: 0), control1: CGPoint(x: rect.width - shoulder * 0.45, y: rect.height), control2: CGPoint(x: rect.width - shoulder * 0.4, y: 0))
        return path
    }
}

private struct WalletPocketShape: Shape {
    var opening: CGFloat = 1
    var animatableData: CGFloat {
        get { opening }
        set { opening = newValue }
    }
    func path(in rect: CGRect) -> Path {
        var path = WalletPocketRim().path(in: CGRect(x: 0, y: 0, width: rect.width, height: min(24 * opening, rect.height)))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

struct WalletPageHeader: View {
    var title: String?
    @Bindable var workspace: CheckLineWorkspace
    var light = false
    var onAdd: (() -> Void)?
    @Environment(\.shellChrome) private var chrome

    private var visibility: Double { light ? 1 - Double(chrome?.pocketClosure ?? 0) : chrome?.interiorReveal ?? 1 }

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 12) { headerRow }
            } else {
                headerRow
            }
        }
        .font(.system(size: 20, weight: .regular))
        .buttonStyle(.plain)
        .foregroundStyle(PaperTheme.ink)
        .opacity(visibility)
        .offset(y: light ? -12 * (1 - visibility) : 6 * (1 - visibility))
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            profileControl
                .paperGlass(.circle, interactive: true)
            if let title {
                Text(title).font(.title2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7).accessibilityAddTraits(.isHeader)
            } else if DesignPreviewData.isEnabled {
                Text(String(localized: "wallet.preview")).font(.caption2).foregroundStyle(PaperTheme.paperInk.opacity(0.5))
            }
            Spacer(minLength: 8)
            trailingControls
        }
    }

    private var profileControl: some View {
        Button { chrome?.isSettingsPresented = true } label: {
            CheckLineIcon(symbol: "person", size: 20)
                .font(.system(size: 20, weight: .medium))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .accessibilityLabel(String(localized: "tab.settings"))
        .accessibilityIdentifier("wallet.profile")
    }

    @ViewBuilder private var trailingControls: some View {
        if #available(iOS 26.0, *) {
            trailingButtons
                .glassEffect(.regular, in: .capsule)
        } else {
            trailingButtons.paperGlass(.capsule)
        }
    }

    private var trailingButtons: some View {
        HStack(spacing: 0) {
            if let onAdd { createControl(onAdd) }
            if light { attentionControl }
            functionsControl
        }
    }

    private func createControl(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            CheckLineIcon(symbol: "plus")
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(String(localized: "wallet.create"))
        .accessibilityIdentifier("wallet.header.create")
    }

    private var attentionControl: some View {
        Button { chrome?.isAttentionPresented = true } label: {
            CheckLineIcon(symbol: "bell")
                .overlay(alignment: .topTrailing) {
                    if !workspace.processingItems.isEmpty {
                        Circle().fill(PaperTheme.accent).frame(width: 6, height: 6).offset(x: 3, y: -3)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(String(localized: "wallet.attention.title"))
        .accessibilityValue(String(format: String(localized: "wallet.attention.count"), workspace.processingItems.count))
        .accessibilityIdentifier("wallet.attention")
    }

    private var functionsControl: some View {
        Menu {
            Button(String(localized: "capture.title"), iconSymbol: "plus") { workspace.openComposer(.record) }
            Button(String(localized: "v1.budget.create"), iconSymbol: "wallet.pass") { workspace.openComposer(.budget) }
            Button(String(localized: "wallet.budget.manage"), iconSymbol: "square.grid.2x2") { chrome?.selectedTab = .budgets }
            if workspace.lastUndo != nil {
                Button(String(localized: "action.undo"), iconSymbol: "arrow.uturn.backward") { workspace.undoLast() }
            }
            Divider()
            Button(String(localized: "ui.sources.title"), iconSymbol: "tray.and.arrow.down") { chrome?.isSourcesPresented = true }
            Button(String(localized: "tab.settings"), iconSymbol: "gearshape") { chrome?.isSettingsPresented = true }
        } label: {
            CheckLineIcon(symbol: "ellipsis")
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(String(localized: "wallet.functions"))
        .accessibilityIdentifier("wallet.functions")
    }
}

struct WalletGlassNavigation: View {
    @Bindable var workspace: CheckLineWorkspace
    @Environment(\.shellChrome) private var chrome
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection
    @GestureState private var dragLocation: CGPoint?
    @Namespace private var glassNamespace
    private let tabs: [CheckLineAppTab] = [.home, .budgets, .wishes, .insights]

    var body: some View {
        HStack(spacing: 12) {
            GeometryReader { geometry in
                let preview = dragLocation.flatMap { WalletTabHitTarget.tab(at: $0, size: geometry.size, rightToLeft: layoutDirection == .rightToLeft) }
                let selected = preview ?? chrome?.selectedTab ?? .home
                navigationButtons(selected: selected, slotWidth: geometry.size.width / CGFloat(tabs.count))
                .padding(5)
                .background { navigationBackground.allowsHitTesting(false) }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 10)
                        .updating($dragLocation) { value, location, _ in
                            location = abs(value.translation.width) > abs(value.translation.height) ? value.location : nil
                        }
                        .onEnded { value in
                            guard abs(value.translation.width) > abs(value.translation.height),
                                  let tab = WalletTabHitTarget.tab(at: value.location, size: geometry.size, rightToLeft: layoutDirection == .rightToLeft) else { return }
                            select(tab)
                        }
                )
                .accessibilityElement(children: .contain)
            }
            .frame(height: 60)

            WalletAgentButton(workspace: workspace)
        }
    }

    @ViewBuilder private var navigationBackground: some View {
        if #available(iOS 26.0, *) {
            Capsule().fill(.clear)
                .glassEffect(.regular, in: .capsule)
        } else {
            Capsule().fill(.clear).paperGlass(.capsule)
        }
    }

    @ViewBuilder private func navigationButtons(selected: CheckLineAppTab, slotWidth: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            ZStack {
                GlassEffectContainer(spacing: slotWidth + 8) { selectionRow(selected: selected) }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                buttonRow(selected: selected)
            }
            .animation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.72), value: selected)
        } else {
            ZStack {
                selectionRow(selected: selected)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                buttonRow(selected: selected)
            }
            .animation(reduceMotion ? nil : .smooth(duration: 0.24), value: selected)
        }
    }

    private func selectionRow(selected: CheckLineAppTab) -> some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                ZStack {
                    if selected == tab {
                        selectionGlass
                            .padding(.horizontal, 3).padding(.vertical, 2)
                            .matchedGeometryEffect(id: "selected-tab-position", in: glassNamespace)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
        }
    }

    private func buttonRow(selected: CheckLineAppTab) -> some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                Button { select(tab) } label: { selectionLabel(tab, selected: selected == tab) }
                    .accessibilityLabel(tab.title)
                    .accessibilityAddTraits(chrome?.selectedTab == tab ? .isSelected : [])
                    .accessibilityIdentifier("wallet.tab.\(tab.rawValue)")
            }
        }.buttonStyle(.plain)
    }

    private func selectionLabel(_ tab: CheckLineAppTab, selected: Bool) -> some View {
        CheckLineIcon(symbol: tab.systemImage)
            .font(.system(size: 23, weight: .medium))
            .foregroundStyle(selected ? PaperTheme.accent : PaperTheme.ink)
            .frame(maxWidth: .infinity).frame(height: 50)
            .contentShape(Capsule())
    }

    @ViewBuilder private var selectionGlass: some View {
        if #available(iOS 26.0, *) {
            Capsule().fill(.clear)
                .glassEffect(.clear.interactive(!reduceMotion), in: .capsule)
                .glassEffectID("selected-tab-lens", in: glassNamespace)
                .glassEffectTransition(.matchedGeometry)
        } else {
            Capsule().fill(.regularMaterial)
        }
    }

    private func select(_ tab: CheckLineAppTab) {
        guard chrome?.selectedTab != tab else { return }
        PaperHaptics.selection()
        withAnimation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.72)) {
            chrome?.selectedTab = tab
        }
    }
}

struct WalletActionFeedback: View {
    @Bindable var workspace: CheckLineWorkspace

    var body: some View {
        if let banner = workspace.actionFeedback {
            HStack {
                Text(banner.localizedText).font(.caption).lineLimit(2)
                Spacer(minLength: 8)
                if workspace.lastUndo != nil {
                    Button(String(localized: "action.undo")) { workspace.undoLast() }
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                }
                Button(String(localized: "action.close"), iconSymbol: "xmark") {
                    workspace.dismissActionFeedback()
                }
                .labelStyle(.iconOnly)
                .font(.caption)
                .frame(width: 44, height: 44)
            }
            .foregroundStyle(PaperTheme.ink)
            .padding(.horizontal, 16)
            .walletSurface(radius: 22)
        }
    }
}

struct WalletAgentButton: View {
    @Bindable var workspace: CheckLineWorkspace
    @Environment(\.walletReduceMotion) private var reduceMotion
    @State private var floating = false

    var body: some View {
        Button { workspace.showAgent = true } label: {
            ZStack {
                Ellipse()
                    .fill(PaperTheme.accent.opacity(0.22))
                    .frame(width: floating && !reduceMotion ? 24 : 32, height: 6)
                    .blur(radius: 3)
                    .offset(y: 28)
                WalletAgentAvatar(size: 67)
                    .shadow(color: PaperTheme.accent.opacity(0.15), radius: 8, y: 5)
                    .offset(y: floating && !reduceMotion ? -5 : 0)
            }
            .frame(width: 68, height: 68)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PaperCirclePressStyle())
        .accessibilityLabel(String(localized: "wallet.agent.open"))
        .accessibilityHint(String(localized: "wallet.agent.resume.hint"))
        .accessibilityIdentifier("wallet.agent.avatar")
        .onAppear { floating = true }
        .onChange(of: reduceMotion) { _, value in floating = !value }
        .animation(reduceMotion ? nil : .easeInOut(duration: 4.6).repeatForever(autoreverses: true), value: floating)
    }
}

enum WalletTabHitTarget {
    static func tab(at point: CGPoint, size: CGSize, rightToLeft: Bool = false) -> CheckLineAppTab? {
        let inset: CGFloat = 5
        let width = size.width - inset * 2
        guard width > 0, point.x >= inset, point.x < size.width - inset,
              point.y >= inset, point.y <= size.height - inset else { return nil }
        let tabs: [CheckLineAppTab] = [.home, .budgets, .wishes, .insights]
        let column = min(tabs.count - 1, Int((point.x - inset) / (width / CGFloat(tabs.count))))
        return tabs[rightToLeft ? tabs.count - 1 - column : column]
    }
}

struct WalletAgentAvatar: View {
    var size: CGFloat = 44
    @MainActor static let tabImage: UIImage = {
        let renderer = ImageRenderer(content: CloudMascotDrawing(frame: CloudMascotMotion.sample(.idle, elapsed: 0, reduced: true), compact: true).frame(width: 32, height: 32))
        renderer.scale = 3
        return (renderer.uiImage ?? UIImage()).withRenderingMode(.alwaysOriginal)
    }()

    var body: some View {
        CloudMascotView().frame(width: size, height: size).accessibilityHidden(true)
    }
}

struct WalletAttentionSheet: View {
    @Bindable var workspace: CheckLineWorkspace
    @Environment(\.dismiss) private var dismiss
    private var cards: [HomeBudgetCardModel] {
        workspace.cards.filter { card in
            let due = workspace.ledger.periods[card.periodID].map {
                $0.state == .pendingSettlement || CycleEngine.isDue($0, now: Date(), calendar: .current)
            } ?? false
            return due || BudgetPresentation.pendingCount(card, in: workspace.ledger) > 0
                || card.snapshot.certainOverrunAmount > 0 || card.snapshot.possibleOverrunAmount > 0
        }
    }
    private var unbudgetedCount: Int {
        workspace.ledger.expenses.values.filter { $0.attributionState == .unbudgeted && $0.wishRedemptionID == nil }.count
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if cards.isEmpty && unbudgetedCount == 0 {
                        ContentUnavailableView {
                            Label { Text(String(localized: "wallet.attention.empty")) } icon: {
                                CheckLineIcon(symbol: "bell.badge", size: 48)
                            }
                        }
                    }
                    ForEach(cards) { card in
                        let count = BudgetPresentation.pendingCount(card, in: workspace.ledger)
                        let due = workspace.ledger.periods[card.periodID].map {
                            $0.state == .pendingSettlement || CycleEngine.isDue($0, now: Date(), calendar: .current)
                        } ?? false
                        NavigationLink {
                            BudgetDetailContent(workspace: workspace, budgetID: card.id, section: due ? .overview : (count > 0 ? .pending : .overview))
                        } label: {
                            HStack(spacing: 14) {
                                CheckLineIcon(symbol: due ? "checkmark.seal" : (count > 0 ? "clock" : "exclamationmark.circle")).font(.title3).foregroundStyle(PaperTheme.accent)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(card.name).font(.headline)
                                    Text(due ? String(localized: "wallet.attention.settlementDue") : (count > 0 ? String(format: String(localized: "wallet.pending.count"), count) : (card.snapshot.certainOverrunAmount > 0 ? String(localized: "wallet.overrun") : String(localized: "wallet.possibleOverrun"))))
                                        .font(.subheadline).foregroundStyle(PaperTheme.muted)
                                }
                                Spacer()
                                CheckLineIcon(symbol: "chevron.right", size: 20).font(.caption)
                            }.padding(18).walletSurface()
                        }.buttonStyle(.plain)
                    }
                    if unbudgetedCount > 0 {
                        NavigationLink { UnbudgetedRecordsView(workspace: workspace) } label: {
                            HStack {
                                CheckLineIconLabel(String(localized: "v1.unbudgeted"), symbol: "tray")
                                Spacer()
                                Text(unbudgetedCount, format: .number)
                                CheckLineIcon(symbol: "chevron.right", size: 20).font(.caption)
                            }.padding(18).walletSurface()
                        }.buttonStyle(.plain)
                    }
                }.padding(20).frame(maxWidth: 650).frame(maxWidth: .infinity)
            }
            .background(PaperTheme.canvas.ignoresSafeArea()).foregroundStyle(PaperTheme.ink)
            .navigationTitle(String(localized: "wallet.attention.title")).navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "action.close"), iconSymbol: "xmark") { dismiss() }.labelStyle(.iconOnly)
                }
            }
        }
        .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        .presentationBackground(PaperTheme.canvas)
    }
}
