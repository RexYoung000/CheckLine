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
        .preferredColorScheme(chrome.presentedTab == .home ? .light : .dark)
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
            if scenePhase == .active { await chrome.transitionToSelection(reduceMotion: reduceMotion) }
            else { chrome.settleNavigation() }
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
            case "create-wish", "budget-detail", "records", "calendar", "wish-detail", "redemption": showsPreviewDetail = true
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

    private var rootTabs: some View {
        TabView(selection: $chrome.presentedTab) {
            ForEach([CheckLineAppTab.home, .budgets, .wishes, .insights]) { tab in
                page(tab)
                    .tabItem { Image(systemName: tab.systemImage).accessibilityLabel(tab.title) }
                    .tag(tab)
            }
        }
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
