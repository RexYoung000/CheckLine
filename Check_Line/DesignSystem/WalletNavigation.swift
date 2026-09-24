import SwiftUI

/// The dark front of the wallet rises at both edges and overlaps the budget card.
struct WalletCardholderSurface: View {
    var opening: CGFloat = 1
    var body: some View {
        WalletPocketShape(opening: opening)
            .fill(LinearGradient(colors: [Color(red: 0.105, green: 0.12, blue: 0.135), PaperTheme.canvas], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(alignment: .top) {
                WalletPocketRim()
                    .stroke(LinearGradient(colors: [.white.opacity(0.17), .white.opacity(0.025), .white.opacity(0.11)], startPoint: .leading, endPoint: .trailing), lineWidth: 0.8)
                    .frame(height: 24 * opening)
            }
            .overlay { WalletGrain().opacity(0.24).clipShape(WalletPocketShape(opening: opening)) }
            .shadow(color: .black.opacity(0.16), radius: 8, y: -4)
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
        HStack(spacing: 10) {
            Button { chrome?.isSettingsPresented = true } label: {
                Image(systemName: "person.fill")
                    .font(.system(size: 19, weight: .regular))
                    .frame(width: 36, height: 36)
                    .background((light ? PaperTheme.paperInk : PaperTheme.ink).opacity(0.08), in: Circle())
                    .overlay { Circle().strokeBorder((light ? PaperTheme.paperInk : PaperTheme.ink).opacity(0.10), lineWidth: 0.8) }
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(String(localized: "tab.settings"))
            .accessibilityIdentifier("wallet.profile")
            if let title {
                Text(title).font(.title2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7).accessibilityAddTraits(.isHeader)
            } else if DesignPreviewData.isEnabled {
                Text(String(localized: "wallet.preview")).font(.caption2).foregroundStyle(PaperTheme.paperInk.opacity(0.5))
            }
            Spacer(minLength: 0)
            if let onAdd {
                Button(action: onAdd) { Image(systemName: "plus").frame(width: 44, height: 44) }
                    .accessibilityLabel(String(localized: "wallet.create"))
            }
            if light {
                Button { chrome?.isAttentionPresented = true } label: {
                    Image(systemName: "bell")
                        .overlay(alignment: .topTrailing) {
                            if !workspace.processingItems.isEmpty {
                                Circle().fill(PaperTheme.accent).frame(width: 6, height: 6).offset(x: 3, y: -3)
                            }
                        }
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(String(localized: "wallet.attention.title"))
                .accessibilityValue(String(format: String(localized: "wallet.attention.count"), workspace.processingItems.count))
                .accessibilityIdentifier("wallet.attention")
            }
            Menu {
                Button(String(localized: "capture.title"), systemImage: "plus") { workspace.openComposer(.record) }
                Button(String(localized: "v1.budget.create"), systemImage: "wallet.pass") { workspace.openComposer(.budget) }
                Button(String(localized: "wallet.budget.manage"), systemImage: "square.grid.2x2") { chrome?.selectedTab = .budgets }
                if workspace.lastUndo != nil {
                    Button(String(localized: "action.undo"), systemImage: "arrow.uturn.backward") { workspace.undoLast() }
                }
                Divider()
                Button(String(localized: "tab.settings"), systemImage: "gearshape") { chrome?.isSettingsPresented = true }
            } label: {
                Image(systemName: "line.3.horizontal").frame(width: 44, height: 44)
            }
            .accessibilityLabel(String(localized: "wallet.functions"))
            .accessibilityIdentifier("wallet.functions")
        }
        .font(.system(size: 20, weight: .regular))
        .buttonStyle(.plain)
        .foregroundStyle(light ? PaperTheme.paperInk : PaperTheme.ink)
        .opacity(visibility)
        .offset(y: light ? -12 * (1 - visibility) : 6 * (1 - visibility))
        .padding(.horizontal, 16).padding(.vertical, 5)
        .background {
            if light {
                PaperTheme.paper.overlay { PaperTheme.canvas.opacity(Double(chrome?.pocketClosure ?? 0)) }
                    .ignoresSafeArea(edges: .top)
            } else {
                Color.clear
            }
        }
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
                navigationButtons(selected: selected)
                .padding(5)
                .background { Capsule().fill(PaperTheme.navigationBase).allowsHitTesting(false) }
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
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder private func navigationButtons(selected: CheckLineAppTab) -> some View {
        if #available(iOS 26.0, *) {
            ZStack {
                GlassEffectContainer(spacing: 0) { selectionRow(selected: selected) }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                buttonRow(selected: selected)
            }
            .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.76), value: selected)
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
                    if selected == tab { selectionGlass.padding(.horizontal, 3).padding(.vertical, 2) }
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
        Image(systemName: tab.systemImage)
            .symbolVariant(.fill)
            .font(.system(size: 24, weight: .regular))
            .foregroundStyle(selected ? PaperTheme.accent : PaperTheme.ink)
            .frame(maxWidth: .infinity).frame(height: 50)
            .contentShape(Capsule())
    }

    @ViewBuilder private var selectionGlass: some View {
        if #available(iOS 26.0, *) {
            Capsule().fill(.clear)
                .glassEffect(.clear.interactive(!reduceMotion), in: .capsule)
                .glassEffectID("selected-tab-lens", in: glassNamespace)
        } else {
            Capsule().fill(.regularMaterial)
        }
    }

    private func select(_ tab: CheckLineAppTab) {
        guard chrome?.selectedTab != tab else { return }
        PaperHaptics.selection()
        chrome?.selectedTab = tab
    }
}

struct WalletAgentButton: View {
    @Bindable var workspace: CheckLineWorkspace
    @Environment(\.walletReduceMotion) private var reduceMotion

    var body: some View {
        Button { workspace.showAgent = true } label: {
            WalletAgentAvatar().scaleEffect(32.0 / 44).frame(width: 60, height: 60)
                .paperGlass(.circle, interactive: !reduceMotion)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "wallet.agent.open"))
        .accessibilityHint(String(localized: "wallet.agent.resume.hint"))
        .accessibilityIdentifier("wallet.agent.avatar")
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

    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Color(red: 0.71, green: 0.68, blue: 0.96), Color(red: 0.36, green: 0.33, blue: 0.69)], startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(LinearGradient(colors: [Color.white, Color(red: 0.78, green: 0.79, blue: 0.97)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 31, height: 27).rotationEffect(.degrees(-5))
                .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
            HStack(spacing: 8) {
                Capsule().frame(width: 3, height: 6)
                Capsule().frame(width: 3, height: 6)
            }.foregroundStyle(Color(red: 0.23, green: 0.21, blue: 0.40)).offset(y: -1)
            Capsule().fill(Color(red: 0.42, green: 0.39, blue: 0.60)).frame(width: 7, height: 1.5).offset(y: 6)
        }
        .frame(width: 44, height: 44)
        .overlay { Circle().strokeBorder(.white.opacity(0.34), lineWidth: 0.8) }
        .accessibilityHidden(true)
    }
}

struct WalletAttentionSheet: View {
    @Bindable var workspace: CheckLineWorkspace
    @Environment(\.dismiss) private var dismiss
    private var cards: [HomeBudgetCardModel] {
        workspace.cards.filter { BudgetPresentation.pendingCount($0, in: workspace.ledger) > 0 || $0.snapshot.certainOverrunAmount > 0 || $0.snapshot.possibleOverrunAmount > 0 }
    }
    private var unbudgetedCount: Int {
        workspace.ledger.expenses.values.filter { $0.attributionState == .unbudgeted && $0.wishRedemptionID == nil }.count
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if cards.isEmpty && unbudgetedCount == 0 {
                        ContentUnavailableView(String(localized: "wallet.attention.empty"), systemImage: "bell.badge")
                    }
                    ForEach(cards) { card in
                        let count = BudgetPresentation.pendingCount(card, in: workspace.ledger)
                        NavigationLink {
                            BudgetDetailContent(workspace: workspace, budgetID: card.id, section: count > 0 ? .pending : .overview)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: count > 0 ? "clock" : "exclamationmark.circle").font(.title3).foregroundStyle(PaperTheme.accent)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(card.name).font(.headline)
                                    Text(count > 0 ? String(format: String(localized: "wallet.pending.count"), count) : (card.snapshot.certainOverrunAmount > 0 ? String(localized: "wallet.overrun") : String(localized: "wallet.possibleOverrun")))
                                        .font(.subheadline).foregroundStyle(PaperTheme.muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption)
                            }.padding(18).walletSurface()
                        }.buttonStyle(.plain)
                    }
                    if unbudgetedCount > 0 {
                        NavigationLink { UnbudgetedRecordsView(workspace: workspace) } label: {
                            HStack {
                                Label(String(localized: "v1.unbudgeted"), systemImage: "tray")
                                Spacer()
                                Text(unbudgetedCount, format: .number)
                                Image(systemName: "chevron.right").font(.caption)
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
                    Button(String(localized: "action.close"), systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly)
                }
            }
        }
        .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        .presentationBackground(PaperTheme.canvas)
    }
}
