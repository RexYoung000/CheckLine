import SwiftUI

struct CheckLineShellView: View {
    @Bindable var workspace: CheckLineWorkspace
    @State private var chrome = ShellChromeState()
    @State private var showsPreviewDetail = false
    #if DEBUG
    @State private var previewExpenseID: UUID?
    #endif
    @AppStorage("checkline.appearance") private var appearance = CheckLineAppearance.system.rawValue
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        rootTabs
        // Native sheets own modal accessibility. Hiding the entire TabView
        // from task flags can also hide navigation after a presentation changes.
        .tint(PaperTheme.accent)
        .preferredColorScheme((CheckLineAppearance(rawValue: appearance) ?? .system).colorScheme)
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
        .sheet(isPresented: Binding(get: { workspace.showComposer || workspace.showAgent }, set: {
            if !$0 { workspace.showComposer = false; workspace.showAgent = false }
        })) { CreateComposerSheet(workspace: workspace).liquidMetricsProbe() }
        .sheet(isPresented: $chrome.isSourcesPresented) {
            NavigationStack { SourceReviewView().toolbar { ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "action.close"), iconSymbol: "xmark") { chrome.isSourcesPresented = false }.labelStyle(.iconOnly)
            } } }.presentationDetents([.large]).presentationBackground(PaperTheme.canvas)
        }
        .sheet(isPresented: $chrome.isSettingsPresented) { SettingsPlaceholderView(workspace: workspace) }
        .sheet(isPresented: $chrome.isAttentionPresented, onDismiss: {
            guard let route = chrome.attentionDestination else { return }
            chrome.attentionDestination = nil
            chrome.workspaceRequest = WalletWorkspaceRequest(tab: chrome.selectedTab, route: route)
        }) {
            WalletAttentionSheet(workspace: workspace) { route in
                chrome.attentionDestination = route
                chrome.isAttentionPresented = false
            }
        }
        .sheet(isPresented: $showsPreviewDetail, onDismiss: { chrome.detailDidDismiss(workspace: workspace) }) { previewDetail }
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
            if let tab = CheckLineAppTab(rawValue: DesignPreviewData.screen) { chrome.selectedTab = tab == .home || tab == .insights ? .budgets : tab; chrome.settleNavigation() }
            if DesignPreviewData.screen == "budget-empty" { chrome.selectedTab = .budgets; chrome.settleNavigation() }
            if DesignPreviewData.screen == "wishes-empty" { chrome.selectedTab = .wishes; chrome.settleNavigation() }
            if ["wishes-fx", "collection", "wish-expanded", "wallet", "wallet-entry", "wish-cover"].contains(DesignPreviewData.screen) {
                chrome.selectedTab = .wishes; chrome.wishesShowCompleted = DesignPreviewData.screen == "collection"; chrome.settleNavigation()
            }
            if ["analysis-empty", "analysis-no-records"].contains(DesignPreviewData.screen) { chrome.selectedTab = .insights; chrome.settleNavigation() }
            if DesignPreviewData.screen == "budget-inline" { chrome.selectedTab = .budgets; chrome.settleNavigation() }
            #if DEBUG
            if DesignPreviewData.screen == "retrospective-record" {
                previewExpenseID = workspace.ledger.expenses.values.first(where: { $0.attributionState == .pending })?.id
            }
            #endif
            switch DesignPreviewData.screen {
            case "settings": chrome.isSettingsPresented = true
            case "attention", "attention-overdue": chrome.isAttentionPresented = true
            case "agent": workspace.showAgent = true
            case "agent-confirm":
                workspace.beginTask(.record, mode: "agent")
                workspace.draftText = String(localized: "wallet.demo.coffee") + " 35"
                await workspace.submitText()
                workspace.showAgent = true
            case "record": workspace.openComposer(.record)
            case "attachment-review":
                workspace.beginTask(.record, mode: "form")
                workspace.taskDraft.amount = "35"
                workspace.taskDraft.merchant = String(localized: "wallet.demo.coffee")
                if let image = CheckLineIconAssets.templateImage(for: "receipt").pngData() {
                    do { try workspace.addTaskAttachment(image) }
                    catch { workspace.banner = .failed }
                }
                workspace.showComposer = true
            case "create-budget": workspace.openComposer(.budget)
            case "create-wish", "budget-detail", "records", "calendar", "wish-detail", "redemption", "agent-mascot", "import-review", "management-review", "retrospective-record", "settlement-fx", "history-review", "budget-info", "expense-detail", "wallet", "wallet-entry", "wish-cover": showsPreviewDetail = true
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
        TabView(selection: $chrome.selectedTab) {
            ForEach([CheckLineAppTab.budgets, .wishes]) { tab in
                page(tab)
                    .tabItem { tabLabel(tab) }
                    .tag(tab)
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private func tabLabel(_ tab: CheckLineAppTab) -> some View {
        Label { Text(tab.title) } icon: {
            Image(uiImage: CheckLineIconAssets.templateImage(for: tab.systemImage)).renderingMode(.template)
        }.labelStyle(.iconOnly).accessibilityLabel(tab.title).accessibilityIdentifier("wallet.tab.\(tab.rawValue)")
    }

    @ViewBuilder private func page(_ tab: CheckLineAppTab) -> some View {
        Group {
            switch tab {
            case .home: CartridgeBudgetHomeView(workspace: workspace)
            case .budgets: CartridgeBudgetHomeView(workspace: workspace)
            case .wishes: NativeWishListView(workspace: workspace)
            case .insights: CycleReviewView(workspace: workspace)
            }
        }
    }

    @ViewBuilder private var previewDetail: some View {
        if DesignPreviewData.isEnabled {
            switch DesignPreviewData.screen {
            #if DEBUG
            case "settlement-fx":
                if let period = workspace.ledger.periods.values.first(where: { $0.state == .pendingSettlement }) {
                    SettlementReviewView(workspace: workspace, periodID: period.id, onShowWishes: { chrome.selectedTab = .wishes })
                }
            case "retrospective-record":
                if let previewExpenseID {
                    NavigationStack { WalletExpenseDetail(workspace: workspace, expenseID: previewExpenseID) }
                }
            case "import-review": NavigationStack { ImportReviewPrototype() }
            case "management-review": NavigationStack { ManagementReviewPrototype() }
            case "agent-mascot": CloudMascotReview()
            #endif
            case "create-wish": CreateWishSheet(workspace: workspace)
            case "wallet": WishWalletSummaryView(workspace: workspace)
            case "wallet-entry":
                if let entry = workspace.ledger.sortedWalletEntries.last { NavigationStack { WalletEntryDetailView(workspace: workspace, entryID: entry.id) } }
            case "wish-cover":
                if let wish = workspace.ledger.wishes.values.first(where: { $0.symbolName == "headphones" }) {
                    WishCoverPicker(store: workspace.wishCovers, wishID: wish.id, name: wish.name)
                }
            case "expense-detail":
                if let expense = workspace.ledger.expenses.values.filter({ $0.attributionState != .pending }).max(by: { $0.occurredAt < $1.occurredAt }) {
                    NavigationStack { WalletExpenseDetail(workspace: workspace, expenseID: expense.id) }
                }
            case "budget-info":
                if let card = workspace.selectedCard { BudgetDetailSheet(workspace: workspace, budgetID: card.id, initialSection: .information) }
            case "budget-detail":
                if let card = workspace.selectedCard { BudgetDetailSheet(workspace: workspace, budgetID: card.id, initialSection: .overview) }
            case "records", "calendar":
                if let card = workspace.selectedCard { BudgetDetailSheet(workspace: workspace, budgetID: card.id, initialSection: DesignPreviewData.screen == "records" ? .records : .calendar) }
            case "history-review":
                if let card = workspace.selectedCard { BudgetDetailSheet(workspace: workspace, budgetID: card.id, initialSection: .history) }
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
