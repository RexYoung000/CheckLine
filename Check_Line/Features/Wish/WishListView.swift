import SwiftUI

struct WishListView: View {
    @Bindable var workspace: CheckLineWorkspace
    @State private var adding = false
    @State private var walletDetails = false
    @Environment(\.dynamicTypeSize) private var typeSize
    private var activeWishes: [Wish] { wishes(in: .active) }
    private var completedWishes: [Wish] { wishes(in: .completed) }
    private func wishes(in state: WishState) -> [Wish] {
        workspace.ledger.wishes.values.filter { $0.state == state }
            .sorted {
                let lhs = state == .completed ? $0.completedAt ?? $0.createdAt : $0.createdAt
                let rhs = state == .completed ? $1.completedAt ?? $1.createdAt : $1.createdAt
                return lhs == rhs ? $0.name < $1.name : lhs > rhs
            }
    }
    var body: some View {
        WalletRootPage(tab: .wishes, title: String(localized: "wallet.wishes.title"), workspace: workspace, onAdd: activeWishes.isEmpty ? nil : { adding = true }) {
            VStack(alignment: .leading, spacing: 24) {
                Button { walletDetails = true } label: {
                    PaperCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                CheckLineIconLabel(String(localized: "v1.wish.balance"), symbol: "sparkle").font(.subheadline)
                                Spacer()
                                CheckLineIcon(symbol: "arrow.up.right", size: 20).font(.caption)
                            }.foregroundStyle(PaperTheme.muted)
                            Text(MoneyFormat.string(workspace.wallet.balance, currencyCode: workspace.ledger.walletSettings.walletCurrencyCode))
                                .font(.largeTitle.weight(.medium)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                            if workspace.wallet.recoveryGap > 0 {
                                CheckLineIconLabel(String(localized: "v1.wish.recovery") + " " + MoneyFormat.string(workspace.wallet.recoveryGap, currencyCode: workspace.ledger.walletSettings.walletCurrencyCode), symbol: "arrow.counterclockwise")
                                    .font(.subheadline).foregroundStyle(PaperTheme.accent)
                            }
                        }
                    }
                }.buttonStyle(.plain)
                if activeWishes.isEmpty {
                    VStack(spacing: 20) {
                        WalletSymbol(name: "star", size: 72)
                        Button(String(localized: "wallet.wishes.add"), iconSymbol: "plus") { adding = true }
                            .buttonStyle(PaperSolidButtonStyle())
                            .accessibilityIdentifier("wallet.wishes.empty.add")
                    }.frame(maxWidth: .infinity).padding(.vertical, 28)
                } else {
                    wishRows(activeWishes)
                }
                if !completedWishes.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(String(format: String(localized: "ui.wish.completedCount"), completedWishes.count))
                            .font(.subheadline.weight(.medium)).foregroundStyle(PaperTheme.muted)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("wallet.wishes.completed.heading")
                        wishRows(completedWishes)
                    }
                }
            }
        }
        .sheet(isPresented: $adding) { CreateWishSheet(workspace: workspace) }
        .sheet(isPresented: $walletDetails) { WishWalletSummaryView(workspace: workspace) }
    }

    private func wishRows(_ wishes: [Wish]) -> some View {
        LazyVStack(spacing: 4) {
            ForEach(wishes) { wish in
                NavigationLink { WishDetailView(workspace: workspace, wishID: wish.id) } label: {
                    HStack(spacing: 14) {
                        WalletSymbol(name: wish.symbolName ?? "star", size: 48)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(wish.name).font(.headline).lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                            if wish.state == .completed, let date = wish.completedAt {
                                Text(date, format: .dateTime.year().month().day())
                                    .font(.subheadline).foregroundStyle(PaperTheme.muted)
                            } else if let amount = wish.targetAmount {
                                Text(MoneyFormat.string(amount, currencyCode: wish.currencyCode ?? workspace.ledger.walletSettings.walletCurrencyCode))
                                    .font(.subheadline.monospacedDigit()).foregroundStyle(PaperTheme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 0)
                        CheckLineIcon(symbol: wish.state == .completed ? "checkmark.circle" : "arrow.up.right", size: 20)
                            .foregroundStyle(PaperTheme.muted)
                    }.padding(14).frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }.padding(4).walletSurface()
    }
}

struct CreateWishSheet: View {
    @Bindable var workspace: CheckLineWorkspace
    @State private var task: LocalTaskDraftSession
    @State private var showsCover = false
    @State private var errorText: String?
    @State private var discardRequested = false
    @FocusState private var fieldFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    init(workspace: CheckLineWorkspace, draftKind: String = "wishCreate") {
        self.workspace = workspace
        _task = State(initialValue: LocalTaskDraftSession(store: workspace.draftStore, kind: draftKind, currency: workspace.ledger.walletSettings.walletCurrencyCode))
    }

    private func field<Value>(_ path: WritableKeyPath<TaskDraft, Value>) -> Binding<Value> {
        Binding(get: { task.draft[keyPath: path] }, set: { task.draft[keyPath: path] = $0; task.draft.fieldsTouched = true })
    }
    private var canSave: Bool { task.canSubmit && !task.draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "wallet.wishes.name")).font(.subheadline).foregroundStyle(PaperTheme.muted)
                        TextField("", text: field(\.name)).font(.title3).focused($fieldFocused)
                            .accessibilityLabel(String(localized: "wallet.wishes.name")).accessibilityIdentifier("wallet.wishes.name")
                            .onChange(of: task.draft.name) { _, value in if value.count > 80 { task.draft.name = String(value.prefix(80)) } }
                    }.padding(18).walletSurface(radius: 18)
                    Button { showsCover = true } label: {
                        ZStack(alignment: .topLeading) {
                            WishCoverArtwork(cover: workspace.wishCovers.cover(for: task.draft.entityID))
                            Label(String(localized: "native.cover.title"), systemImage: "photo").font(.subheadline).padding(18)
                        }.frame(height: 145).modifier(NativeGlassCard())
                    }.buttonStyle(.plain).accessibilityIdentifier("native.cover.open")
                    estimateFields
                    LocalDraftFailureView(task: task)
                    if let errorText {
                        Text(errorText).font(.subheadline).foregroundStyle(PaperTheme.accent).accessibilityIdentifier("wallet.wishes.create.error")
                    }
                }.padding(22).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }.scrollDismissesKeyboard(.interactively).background(PaperTheme.canvas.ignoresSafeArea())
                .safeAreaInset(edge: .bottom) {
                    PaperSubmitBar(title: String(localized: "wallet.wishes.add"), enabled: canSave, action: save)
                        .accessibilityIdentifier("wallet.wishes.create.save").padding(.vertical, 12).background(PaperTheme.canvas)
                }
                .navigationTitle(String(localized: "wallet.wishes.add")).navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(String(localized: "action.close"), iconSymbol: "xmark") { dismiss() }.labelStyle(.iconOnly)
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        if task.draft.hasInput {
                            Menu { Button(String(localized: "ui.draft.discard"), role: .destructive) { discardRequested = true } }
                            label: { CheckLineIcon(symbol: "ellipsis", size: 20).frame(width: 44, height: 44) }
                                .accessibilityLabel(String(localized: "ui.task.options"))
                        }
                    }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer(); Button(String(localized: "ui.keyboard.done")) { fieldFocused = false }
                    }
                }
        }.modifier(NativeDrawerStyle())
            .sheet(isPresented: $showsCover, onDismiss: { if workspace.wishCovers.hasCover(for: task.draft.entityID) { task.draft.fieldsTouched = true } }) { WishCoverPicker(store: workspace.wishCovers, wishID: task.draft.entityID, name: task.draft.name) }
            .alert(String(localized: "ui.draft.discard.title"), isPresented: $discardRequested) {
                Button(String(localized: "ui.draft.keep"), role: .cancel) { }
                Button(String(localized: "ui.draft.discard.action"), role: .destructive) {
                    let discardedID = task.draft.entityID
                    let fromAgent = task.draft.kind == "agentWishCreate"
                    do {
                        try workspace.wishCovers.remove(discardedID)
                        try task.clear()
                        if fromAgent && workspace.proposedWishDraft?.entityID == discardedID { workspace.proposedWishDraft = nil }
                        errorText = nil
                    } catch { errorText = String(localized: "ui.draft.failed") }
                }
            }
            .onAppear {
                if workspace.ledger.wishes[task.draft.entityID] != nil {
                    do { try task.clear(); dismiss() } catch { errorText = String(localized: "ui.draft.failed") }
                }
            }
    }

    private var estimateFields: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 18)) : AnyLayout(HStackLayout(alignment: .top, spacing: 18))
        return layout {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "wallet.wishes.estimate")).font(.subheadline).foregroundStyle(PaperTheme.muted)
                TextField("0.00", text: field(\.amount)).keyboardType(AmountKeyboard.type).font(.largeTitle).monospacedDigit().focused($fieldFocused)
                    .accessibilityLabel(String(localized: "wallet.wishes.estimate")).accessibilityIdentifier("wallet.wishes.estimate")
            }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "v1.budget.currency")).font(.subheadline).foregroundStyle(PaperTheme.muted)
                CurrencyMenuButton(currency: field(\.currency), preferred: workspace.ledger.walletSettings.walletCurrencyCode)
                    .accessibilityIdentifier("wallet.wishes.currency")
            }
        }.padding(18).walletSurface(radius: 18)
    }

    private func save() {
        guard canSave else { return }
        do {
            try workspace.createWish(name: task.draft.name, amountText: task.draft.amount, currencyCode: task.draft.currency, symbolName: workspace.wishCovers.cover(for: task.draft.entityID).symbol, wishID: task.draft.entityID)
            let fromAgent = task.draft.kind == "agentWishCreate"
            let savedName = task.draft.name
            try task.clear()
            if fromAgent {
                workspace.proposedWishDraft = nil
                workspace.conversation.append(AgentConversationEntry(isUser: false, text: String(format: String(localized: "native.agent.wishSaved"), savedName)))
            }
            dismiss()
        } catch WorkspaceInputError.invalidCurrency { errorText = String(localized: "ui.wish.chooseCurrency") }
        catch LedgerError.zeroOrNegativeAmount, WorkspaceInputError.missingName { errorText = String(localized: "wallet.wishes.invalid") }
        catch { errorText = String(localized: "v1.banner.failed") }
    }
}

struct WishPurchaseSummary: View {
    let redemption: WishRedemption
    let entry: WalletLedgerEntry?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "wallet.wishes.actual")).font(.subheadline).foregroundStyle(PaperTheme.muted)
            Text(MoneyFormat.string(redemption.actualAmount, currencyCode: redemption.currencyCode))
                .font(.largeTitle.weight(.medium)).monospacedDigit().fixedSize(horizontal: false, vertical: true)
            Text(redemption.confirmedAt, format: .dateTime.year().month().day().hour().minute())
                .font(.subheadline).foregroundStyle(PaperTheme.muted)
            if let entry {
                PaperValueRow(title: String(localized: "wallet.exchange.walletChange"), value: MoneyFormat.string(entry.walletSignedAmount, currencyCode: entry.walletCurrencyCode))
                if entry.conversion.kind != .identity { WalletConversionDetails(entry: entry) }
            }
        }.accessibilityIdentifier("wallet.wishes.purchaseSummary")
    }
}

struct WishDetailView: View {
    @Bindable var workspace: CheckLineWorkspace
    var wishID: UUID
    @State private var redeem = false
    @State private var expanded = false
    @State private var price = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let wish = workspace.ledger.wishes[wishID] {
                    NativeWishCard(workspace: workspace, wish: wish, onExpand: { expanded = true }, onRedeem: { redeem = true }, onPrice: { price = true })
                    if wish.state == .completed, let redemption = workspace.ledger.redemptions.values.first(where: { $0.wishID == wishID && $0.state == .completed }) {
                        WishPurchaseSummary(redemption: redemption, entry: workspace.ledger.walletEntries[redemption.walletEntryID]).padding(20).walletSurface()
                    }
                } else {
                    ContentUnavailableView(String(localized: "ui.wish.unavailable"), systemImage: "heart")
                    Button(String(localized: "action.back")) { dismiss() }.buttonStyle(PaperQuietButtonStyle())
                }
            }.padding(22).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }.background(PaperTheme.canvas.ignoresSafeArea())
            .navigationTitle(String(localized: "wallet.wishes.detail")).navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar).toolbar(.hidden, for: .tabBar, .bottomBar)
            .sheet(isPresented: $redeem) { WishRedemptionView(workspace: workspace, wishID: wishID).modifier(NativeDrawerStyle()) }
            .sheet(isPresented: $price) { if let wish = workspace.ledger.wishes[wishID] { WishPriceSheet(workspace: workspace, wish: wish) } }
            .fullScreenCover(isPresented: $expanded) { ExpandedWishView(workspace: workspace, wishID: wishID) }
    }
}

struct WishRedemptionView: View {
    @Bindable var workspace: CheckLineWorkspace
    let wishID: UUID
    @State private var task: LocalTaskDraftSession
    @Environment(\.shellChrome) private var chrome
    @State private var priceSheet = false
    @State private var outcome: OutcomeReceipt?
    @State private var purchased = false
    @State private var failed = false
    @State private var discardRequested = false
    @FocusState private var amountFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    init(workspace: CheckLineWorkspace, wishID: UUID) {
        self.workspace = workspace
        self.wishID = wishID
        _task = State(initialValue: LocalTaskDraftSession(store: workspace.draftStore, kind: "wishRedemption", currency: workspace.ledger.wishes[wishID]?.currencyCode ?? workspace.ledger.walletSettings.walletCurrencyCode, wishID: wishID))
    }

    private var wish: Wish? { workspace.ledger.wishes[wishID] }
    private var walletCurrency: String { workspace.ledger.walletSettings.walletCurrencyCode }
    private var currency: String { task.draft.currency }
    private var needsQuote: Bool { currency != walletCurrency }
    private var parsed: Decimal? { MoneyFormat.parseAmount(task.draft.amount) }
    private var rate: Binding<String> { Binding(get: { task.draft.exchangeRateText ?? "" }, set: { task.draft.exchangeRateText = $0 }) }
    private var quoteDate: Binding<Date> { Binding(get: { task.draft.exchangeQuotedAt ?? task.draft.occurredAt }, set: { task.draft.exchangeQuotedAt = $0 }) }
    private var quote: ExchangeQuote? {
        guard needsQuote, let value = MoneyFormat.parseAmount(rate.wrappedValue) else { return nil }
        return .estimated(rate: value, at: quoteDate.wrappedValue, sourceName: "user_provided_estimate")
    }
    private var previewResult: Result<WishRedemptionPreview, Error>? {
        guard let parsed else { return nil }
        return Result { try WishRedemptionEngine.preview(ledger: workspace.ledger, wishID: wishID, actualAmount: parsed, currencyCode: currency, quote: quote, now: Date()) }
    }
    private var preview: WishRedemptionPreview? { try? previewResult?.get() }
    private var saved: WishRedemption? { workspace.ledger.redemptions.values.first { $0.wishID == wishID && $0.state == .completed } }
    private var canSubmit: Bool { purchased && preview != nil && task.canSubmit && saved == nil && wish?.targetAmount != nil }
    private func field<Value>(_ path: WritableKeyPath<TaskDraft, Value>) -> Binding<Value> {
        Binding(get: { task.draft[keyPath: path] }, set: { task.draft[keyPath: path] = $0; task.draft.fieldsTouched = true })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let wish {
                        Text(wish.name).font(.title2.weight(.medium))
                        if let saved {
                            CheckLineIconLabel(String(localized: "wallet.wishes.success"), symbol: "checkmark.circle").font(.headline).foregroundStyle(PaperTheme.accent)
                            WishPurchaseSummary(redemption: saved, entry: workspace.ledger.walletEntries[saved.walletEntryID])
                            PaperValueRow(title: String(localized: "ui.wish.currentBalance"), value: MoneyFormat.string(workspace.wallet.balance, currencyCode: walletCurrency))
                        } else if wish.state == .active {
                            if wish.targetAmount == nil {
                                Button(String(localized: "native.wish.setPrice")) { priceSheet=true }.buttonStyle(PaperQuietButtonStyle())
                            }
                            purchaseFields
                            if !amountFocused && !task.draft.amount.isEmpty && parsed == nil {
                                Text(String(localized: "wallet.wishes.invalid")).font(.caption).foregroundStyle(PaperTheme.accent)
                                    .accessibilityIdentifier("wallet.wishes.invalidAmount")
                            }
                            LocalDraftFailureView(task: task)
                            if needsQuote || parsed != nil { walletImpact }
                            Toggle(String(localized: "wallet.wishes.purchaseConfirmed"), isOn: $purchased).tint(PaperTheme.accent)
                                .accessibilityIdentifier("wallet.wishes.purchaseConfirmed")
                            if failed { Text(String(localized: "wallet.settlement.saveFailed")).font(.subheadline).foregroundStyle(PaperTheme.accent) }
                        } else {
                            Text(String(localized: "ui.wish.unavailable")).foregroundStyle(PaperTheme.muted)
                        }
                    } else {
                        ContentUnavailableView(String(localized: "ui.wish.unavailable"), systemImage: "heart")
                    }
                }.padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }.scrollDismissesKeyboard(.interactively).background(PaperTheme.canvas.ignoresSafeArea())
                .safeAreaInset(edge: .bottom) {
                    if saved != nil {
                        PaperSubmitBar(title: String(localized: "action.close"), enabled: true) { dismiss() }
                            .padding(.vertical, 12).background(PaperTheme.canvas)
                    } else if wish?.state == .active {
                        PaperSubmitBar(title: String(localized: "wallet.wishes.confirm"), enabled: canSubmit, action: submit)
                            .accessibilityIdentifier("wallet.wishes.confirm").padding(.vertical, 12).background(PaperTheme.canvas)
                    }
                }
                .navigationTitle(String(localized: "wallet.wishes.redemption")).navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(String(localized: "action.close"), iconSymbol: "xmark") { dismiss() }.labelStyle(.iconOnly)
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        if task.draft.hasInput && saved == nil {
                            Menu { Button(String(localized: "ui.draft.discard"), role: .destructive) { discardRequested = true } }
                            label: { CheckLineIcon(symbol: "ellipsis", size: 20).frame(width: 44, height: 44) }
                                .accessibilityLabel(String(localized: "ui.task.options"))
                        }
                    }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer(); Button(String(localized: "ui.keyboard.done")) {
                            amountFocused = false
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    }
                }
        }.overlay {
            if let outcome { OutcomeCelebration(receipt: outcome) {
                chrome?.wishesShowCompleted = true
                chrome?.selectedTab = .wishes
                chrome?.isShowingDetail = false
                workspace.showAgent = false; workspace.showComposer = false
                dismiss()
            }.transition(.opacity) }
        }.sheet(isPresented: $priceSheet) { if let wish { WishPriceSheet(workspace: workspace,wish: wish) } }
        .alert(String(localized: "ui.draft.discard.title"), isPresented: $discardRequested) {
            Button(String(localized: "ui.draft.keep"), role: .cancel) { }
            Button(String(localized: "ui.draft.discard.action"), role: .destructive) {
                do { try task.clear(); purchased = false; failed = false } catch { failed = true }
            }
        }.onAppear {
            purchased = false
            if saved != nil { try? task.clear() }
        }.onChange(of: task.draft.amount) { _, _ in purchased = false; failed = false }
            .onChange(of: task.draft.currency) { _, _ in purchased = false; failed = false; amountFocused = false }
            .onChange(of: task.draft.exchangeRateText) { _, _ in purchased = false; failed = false }
            .onChange(of: workspace.ledger) { _, _ in purchased = false }
    }

    private var purchaseFields: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 18)) : AnyLayout(HStackLayout(alignment: .top, spacing: 18))
        return layout {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "wallet.wishes.actual")).font(.subheadline).foregroundStyle(PaperTheme.muted)
                TextField("0.00", text: field(\.amount)).keyboardType(AmountKeyboard.type).font(.largeTitle).monospacedDigit().focused($amountFocused)
                    .accessibilityLabel(String(localized: "wallet.wishes.actual")).accessibilityIdentifier("wallet.wishes.actual")
            }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "wallet.wishes.purchaseCurrency")).font(.subheadline).foregroundStyle(PaperTheme.muted)
                CurrencyMenuButton(currency: field(\.currency), preferred: walletCurrency, label: String(localized: "wallet.wishes.purchaseCurrency"))
                    .accessibilityIdentifier("wallet.wishes.purchaseCurrency")
            }
        }.padding(18).walletSurface()
    }

    private var walletImpact: some View {
        VStack(alignment: .leading, spacing: 16) {
            if needsQuote { WalletExchangeQuoteFields(sourceCurrencyCode: currency, walletCurrencyCode: walletCurrency, rateText: rate, quotedAt: quoteDate) }
            if let preview {
                PaperValueRow(title: String(localized: "wallet.exchange.walletChange"), value: MoneyFormat.string(preview.walletSignedAmount, currencyCode: walletCurrency))
                    .accessibilityElement(children: .combine).accessibilityIdentifier("wallet.exchange.walletChange")
                PaperValueRow(title: String(localized: "wallet.wishes.balanceAfter"), value: MoneyFormat.string(preview.balanceAfter, currencyCode: walletCurrency))
                    .accessibilityElement(children: .combine).accessibilityIdentifier("wallet.wishes.balanceAfter")
            } else if case .failure(let error) = previewResult {
                let message = switch error {
                case LedgerError.missingExchangeRate: String(localized: "wallet.wishes.exchangeMissing")
                case LedgerError.invalidExchangeRate: String(localized: "wallet.exchange.required")
                case LedgerError.insufficientWishWallet: String(localized: "wallet.wishes.insufficient")
                default: String(localized: "ui.wish.unavailable")
                }
                CheckLineIconLabel(message, symbol: "exclamationmark.circle").font(.subheadline).foregroundStyle(PaperTheme.accent)
            }
        }.padding(18).walletSurface()
    }

    private func submit() {
        guard canSubmit, let parsed, let wish else { return }
        let before = workspace.wallet.balance
        do {
            try workspace.redeemWish(wishID, actualAmount: parsed, currencyCode: currency, realPurchaseConfirmed: purchased, quote: quote)
            // Persistence has succeeded. Draft cleanup is independent of that saved purchase.
            outcome = OutcomeReceipt(kind: .wish, title: wish.name, before: before, after: workspace.wallet.balance,
                currency: walletCurrency, originalAmount: parsed, originalCurrency: currency,
                date: saved?.confirmedAt ?? Date(), cover: workspace.wishCovers.cover(for: wishID, fallback: wish.symbolName),
                progress: (wish.currencyCode ?? walletCurrency) == walletCurrency ? wish.targetAmount.map { CGFloat(NSDecimalNumber(decimal: min(1,before / $0)).doubleValue) } : nil)
            try? task.clear()
            failed = false
        } catch { failed = true }
    }
}
