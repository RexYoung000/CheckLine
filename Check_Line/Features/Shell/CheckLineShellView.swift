import SwiftUI

struct CheckLineShellView: View {
    @Bindable var workspace: CheckLineWorkspace
    @State private var chrome = ShellChromeState()
    @State private var showsPreviewDetail = false

    var body: some View {
        TabView(selection: $chrome.selectedTab) {
            CheckLineHomeView(workspace: workspace)
                .tabItem { Image(systemName: CheckLineAppTab.home.systemImage).accessibilityLabel(CheckLineAppTab.home.title) }.tag(CheckLineAppTab.home)
            BudgetListView(workspace: workspace)
                .tabItem { Image(systemName: CheckLineAppTab.budgets.systemImage).accessibilityLabel(CheckLineAppTab.budgets.title) }.tag(CheckLineAppTab.budgets)
            WishListView(workspace: workspace)
                .tabItem { Image(systemName: CheckLineAppTab.wishes.systemImage).accessibilityLabel(CheckLineAppTab.wishes.title) }.tag(CheckLineAppTab.wishes)
            CycleReviewView(workspace: workspace)
                .tabItem { Image(systemName: CheckLineAppTab.insights.systemImage).accessibilityLabel(CheckLineAppTab.insights.title) }.tag(CheckLineAppTab.insights)
        }
        .tint(PaperTheme.accent)
        .preferredColorScheme(chrome.selectedTab == .home ? .light : .dark)
        .environment(\.colorScheme, .dark)
        .toolbarColorScheme(.dark, for: .tabBar)
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
        .task {
            guard DesignPreviewData.isEnabled else { return }
            if let tab = CheckLineAppTab(rawValue: DesignPreviewData.screen) { chrome.selectedTab = tab }
            switch DesignPreviewData.screen {
            case "settings": chrome.isSettingsPresented = true
            case "attention": chrome.isAttentionPresented = true
            case "agent": workspace.showAgent = true
            case "record": workspace.openComposer(.record)
            case "create-budget": workspace.openComposer(.budget)
            case "create-wish", "budget-detail", "wish-detail", "redemption": showsPreviewDetail = true
            default: break
            }
        }
    }

    @ViewBuilder private var previewDetail: some View {
        if DesignPreviewData.isEnabled {
            switch DesignPreviewData.screen {
            case "create-wish": CreateWishSheet(workspace: workspace)
            case "budget-detail":
                if let card = workspace.selectedCard { BudgetDetailSheet(workspace: workspace, budgetID: card.id, initialSection: .overview) }
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
