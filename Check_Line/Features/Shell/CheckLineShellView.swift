import SwiftUI

struct CheckLineShellView: View {
    @Bindable var workspace: CheckLineWorkspace
    @State private var chrome = ShellChromeState()
    @State private var showsPreviewDetail = false
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        rootTabs
        .tint(PaperTheme.accent)
        .preferredColorScheme((WalletTabTransition.usesImmediateContent ? chrome.selectedTab : chrome.presentedTab) == .home ? .light : .dark)
        .overlay(alignment: .bottom) {
            if !WalletTabTransition.usesSystemBar && !chrome.isShowingDetail {
                VStack(spacing: 8) {
                    WalletActionFeedback(workspace: workspace)
                    WalletGlassNavigation(workspace: workspace)
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity)
            }
        }
        .environment(\.shellChrome, chrome)
        .sheet(isPresented: $workspace.showComposer) { CreateComposerSheet(workspace: workspace).preferredColorScheme(.dark) }
        .sheet(isPresented: $workspace.showAgent, onDismiss: {
            if let intent = workspace.composerAfterAgent {
                workspace.composerAfterAgent = nil
                workspace.openComposer(intent)
            }
        }) { WalletAgentSheet(workspace: workspace).preferredColorScheme(.dark) }
        .sheet(isPresented: $chrome.isSettingsPresented) { SettingsPlaceholderView().preferredColorScheme(.dark) }
        .sheet(isPresented: $chrome.isAttentionPresented) { WalletAttentionSheet(workspace: workspace).preferredColorScheme(.dark) }
        .sheet(isPresented: $showsPreviewDetail) { previewDetail.preferredColorScheme(.dark) }
        .background(PaperTheme.canvas.ignoresSafeArea())
        .task(id: WalletNavigationRequest(tab: chrome.selectedTab, reduceMotion: reduceMotion, active: scenePhase == .active)) {
            if WalletTabTransition.usesImmediateContent { chrome.settleNavigation() }
            else if scenePhase == .active { await chrome.transitionToSelection(reduceMotion: reduceMotion) }
            else { chrome.settleNavigation() }
        }
        .onChange(of: chrome.selectedTab) { _, _ in
            if WalletTabTransition.usesImmediateContent { chrome.settleNavigation() }
        }
        .task {
            guard DesignPreviewData.isEnabled else { return }
            if let tab = CheckLineAppTab(rawValue: DesignPreviewData.screen) { chrome.selectedTab = tab; chrome.settleNavigation() }
            if DesignPreviewData.screen == "budget-inline" { chrome.selectedTab = .budgets; chrome.settleNavigation() }
            switch DesignPreviewData.screen {
            case "settings": chrome.isSettingsPresented = true
            case "attention": chrome.isAttentionPresented = true
            case "agent": workspace.showAgent = true
            case "agent-confirm":
                workspace.draftText = String(localized: "wallet.demo.coffee") + " 35"
                await workspace.submitText()
                workspace.showAgent = true
            case "record": workspace.openComposer(.record)
            case "create-budget": workspace.openComposer(.budget)
            case "create-wish", "budget-detail", "records", "calendar", "wish-detail", "redemption", "agent-mascot": showsPreviewDetail = true
            default: break
            }
            if DesignPreviewData.runsMotionTour {
                let steps: [(Int, CheckLineAppTab)] = [(2_000, .budgets), (1_600, .wishes), (1_200, .home), (1_800, .budgets), (130, .home), (1_400, .insights), (150, .wishes), (1_400, .home)]
                for (delay, tab) in steps {
                    do { try await Task.sleep(for: .milliseconds(delay)) } catch { return }
                    chrome.selectedTab = tab
                }
                do {
                    try await Task.sleep(for: .milliseconds(1_200))
                    workspace.showAgent = true
                    try await Task.sleep(for: .milliseconds(1_800))
                    workspace.showAgent = false
                } catch { return }
            }
        }
    }

    @ViewBuilder private var rootTabs: some View {
        if #available(iOS 27.0, *), WalletTabTransition.usesSystemBar {
            TabView(selection: systemSelection) {
                Tab(value: WalletSystemTab.page(.home)) { page(.home) } label: { tabLabel(.home) }
                Tab(value: WalletSystemTab.page(.budgets)) { page(.budgets) } label: { tabLabel(.budgets) }
                Tab(value: WalletSystemTab.page(.wishes)) { page(.wishes) } label: { tabLabel(.wishes) }
                Tab(value: WalletSystemTab.page(.insights)) { page(.insights) } label: { tabLabel(.insights) }
                Tab(value: WalletSystemTab.agent, role: .prominent) {
                    Color.clear
                } label: {
                    Image(uiImage: WalletAgentAvatar.tabImage)
                        .renderingMode(.original)
                        .accessibilityLabel(String(localized: "wallet.agent.open"))
                        .accessibilityIdentifier("wallet.agent.avatar")
                }
            }
            .tabViewStyle(.tabBarOnly)
            .tabBarMinimizeBehavior(.never)
            .toolbarColorScheme(.dark, for: .tabBar)
        } else {
            TabView(selection: WalletTabTransition.usesImmediateContent ? $chrome.selectedTab : $chrome.presentedTab) {
                ForEach([CheckLineAppTab.home, .budgets, .wishes, .insights]) { tab in
                    page(tab)
                        .tabItem { tabLabel(tab) }
                        .tag(tab)
                }
            }
        }
    }

    private var systemSelection: Binding<WalletSystemTab> {
        Binding {
            .page(chrome.selectedTab)
        } set: { destination in
            switch destination {
            case .page(let tab): chrome.selectedTab = tab
            case .agent: workspace.showAgent = true
            }
        }
    }

    private func tabLabel(_ tab: CheckLineAppTab) -> some View {
        Image(systemName: tab.systemImage)
            .accessibilityLabel(tab.title)
            .accessibilityIdentifier("wallet.tab.\(tab.rawValue)")
    }

    @ViewBuilder private func page(_ tab: CheckLineAppTab) -> some View {
        Group {
            switch tab {
            case .home: CheckLineHomeView(workspace: workspace)
            case .budgets: BudgetListView(workspace: workspace)
            case .wishes: WishListView(workspace: workspace)
            case .insights: CycleReviewView(workspace: workspace)
            }
        }
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder private var previewDetail: some View {
        if DesignPreviewData.isEnabled {
            switch DesignPreviewData.screen {
            #if DEBUG
            case "agent-mascot": CloudMascotReview()
            #endif
            case "create-wish": CreateWishSheet(workspace: workspace)
            case "budget-detail":
                if let card = workspace.selectedCard { BudgetDetailSheet(workspace: workspace, budgetID: card.id, initialSection: .overview) }
            case "records", "calendar":
                if let card = workspace.selectedCard { BudgetDetailSheet(workspace: workspace, budgetID: card.id, initialSection: DesignPreviewData.screen == "records" ? .records : .calendar) }
            case "wish-detail":
                if let wish = workspace.ledger.wishes.values.first(where: { $0.symbolName == "headphones" }) {
                    NavigationStack { WishDetailView(workspace: workspace, wishID: wish.id) }
                }
            case "redemption":
                if let wish = workspace.ledger.wishes.values.first(where: { $0.symbolName == "headphones" }) {
                    WishRedemptionView(workspace: workspace, wishID: wish.id)
                }
            default: EmptyView()
            }
        }
    }
}

private enum WalletSystemTab: Hashable {
    case page(CheckLineAppTab)
    case agent
}
