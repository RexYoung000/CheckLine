import SwiftUI

struct WishListView: View {
    @Bindable var workspace: CheckLineWorkspace
    @State private var completed = false
    @State private var adding = false
    @State private var walletDetails = false
    private var wishes: [Wish] {
        workspace.ledger.wishes.values.filter { completed ? $0.state == .completed : $0.state == .active }
            .sorted { $0.createdAt == $1.createdAt ? $0.name < $1.name : $0.createdAt > $1.createdAt }
    }
    var body: some View {
        WalletRootPage(tab: .wishes, title: String(localized: "wallet.wishes.title"), workspace: workspace, onAdd: { adding = true }) {
            VStack(alignment: .leading, spacing: 24) {
                Button { walletDetails = true } label: {
                    PaperCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Label(String(localized: "v1.wish.balance"), systemImage: "sparkle").font(.subheadline)
                                Spacer()
                                Image(systemName: "arrow.up.right").font(.caption)
                            }.foregroundStyle(PaperTheme.muted)
                            Text(MoneyFormat.string(workspace.wallet.balance, currencyCode: workspace.ledger.walletSettings.walletCurrencyCode))
                                .font(.largeTitle.weight(.medium)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                            if workspace.wallet.recoveryGap > 0 {
                                Label(String(localized: "v1.wish.recovery") + " " + MoneyFormat.string(workspace.wallet.recoveryGap, currencyCode: workspace.ledger.walletSettings.walletCurrencyCode), systemImage: "arrow.counterclockwise")
                                    .font(.subheadline).foregroundStyle(PaperTheme.accent)
                            }
                            Text(String(localized: "v1.wish.notRealMoney")).font(.caption).foregroundStyle(PaperTheme.muted)
                        }
                    }
                }.buttonStyle(.plain)
                Picker(String(localized: "wallet.wishes.filter"), selection: $completed) {
                    Text(String(localized: "wallet.wishes.active")).tag(false)
                    Text(String(localized: "wallet.wishes.completed")).tag(true)
                }.pickerStyle(.segmented)
                if wishes.isEmpty {
                    VStack(spacing: 20) {
                        WalletSymbol(name: completed ? "checkmark" : "star", size: 72)
                        Text(completed ? String(localized: "wallet.wishes.completedEmpty") : String(localized: "wallet.wishes.empty")).font(.headline)
                    }.frame(maxWidth: .infinity).padding(.vertical, 28)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 16)], spacing: 16) {
                        ForEach(wishes) { wish in
                            NavigationLink { WishDetailView(workspace: workspace, wishID: wish.id) } label: {
                                HStack(spacing: 16) {
                                    WalletSymbol(name: wish.symbolName ?? "star")
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(wish.name).font(.headline).lineLimit(2)
                                        if let amount = wish.targetAmount {
                                            Text(MoneyFormat.string(amount, currencyCode: wish.currencyCode ?? workspace.ledger.walletSettings.walletCurrencyCode)).font(.subheadline.monospacedDigit()).foregroundStyle(PaperTheme.muted)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: completed ? "checkmark.circle" : "arrow.up.right").font(.caption).foregroundStyle(PaperTheme.muted)
                                }.padding(18).frame(maxWidth: .infinity, minHeight: 110, alignment: .leading).walletSurface()
                            }.buttonStyle(.plain)
                        }
                    }
                }
                Button(String(localized: "wallet.wishes.add"), systemImage: "plus") { adding = true }
                    .buttonStyle(PaperSolidButtonStyle())
            }
        }
        .sheet(isPresented: $adding) { CreateWishSheet(workspace: workspace) }
        .sheet(isPresented: $walletDetails) { WishWalletSummaryView(workspace: workspace) }
    }
}

struct CreateWishSheet: View {
    @Bindable var workspace: CheckLineWorkspace
    @State private var name = ""
    @State private var amount = ""
    @State private var symbol = "star"
    @State private var hasError = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack { Spacer(); WalletSymbol(name: symbol, size: 84); Spacer() }.padding(.vertical, 12)
                    TextField("", text: $name, prompt: Text(String(localized: "wallet.wishes.name")).foregroundStyle(PaperTheme.muted))
                        .font(.title3).padding(18).walletSurface(radius: 18)
                        .accessibilityLabel(String(localized: "wallet.wishes.name"))
                        .onChange(of: name) { _, value in if value.count > 80 { name = String(value.prefix(80)) } }
                    HStack {
                        Text(workspace.ledger.walletSettings.walletCurrencyCode).foregroundStyle(PaperTheme.muted)
                        TextField("", text: $amount, prompt: Text(String(localized: "wallet.wishes.estimate")).foregroundStyle(PaperTheme.muted)).keyboardType(.decimalPad).accessibilityLabel(String(localized: "wallet.wishes.estimate"))
                    }.padding(18).walletSurface(radius: 18)
                    Text(String(localized: "wallet.wishes.symbol")).font(.subheadline).foregroundStyle(PaperTheme.muted)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 16)], spacing: 16) {
                        ForEach(WishSymbols.allowed, id: \.self) { choice in
                            Button { symbol = choice } label: {
                                WalletSymbol(name: choice).overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(symbol == choice ? PaperTheme.accent : .clear, lineWidth: 3) }
                            }.buttonStyle(.plain)
                                .accessibilityLabel(Text(LocalizedStringKey("wallet.symbol." + choice)))
                                .accessibilityAddTraits(symbol == choice ? .isSelected : [])
                        }
                    }
                    if hasError { Text(String(localized: "wallet.wishes.invalid")).font(.subheadline).foregroundStyle(PaperTheme.accent) }
                    Button(String(localized: "wallet.wishes.add")) {
                        do { try workspace.createWish(name: name, amountText: amount, symbolName: symbol); dismiss() }
                        catch { hasError = true }
                    }.buttonStyle(PaperSolidButtonStyle()).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }.padding(22).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PaperTheme.canvas.ignoresSafeArea())
            .navigationTitle(String(localized: "wallet.wishes.add")).navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(String(localized: "action.close"), systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly) } }
        }.presentationDetents([.large]).presentationBackground(PaperTheme.canvas).presentationCornerRadius(30)
    }
}

struct WishDetailView: View {
    @Bindable var workspace: CheckLineWorkspace
    var wishID: UUID
    @State private var redeem = false
    private var wish: Wish? { workspace.ledger.wishes[wishID] }
    var body: some View {
        ScrollView {
            if let wish {
                VStack(alignment: .leading, spacing: 26) {
                    HStack { Spacer(); WalletSymbol(name: wish.symbolName ?? "star", size: 100); Spacer() }.padding(.vertical, 28)
                    Text(wish.name).font(.title.weight(.medium))
                    if let amount = wish.targetAmount {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "wallet.wishes.estimate")).font(.subheadline).foregroundStyle(PaperTheme.muted)
                            Text(MoneyFormat.string(amount, currencyCode: wish.currencyCode ?? workspace.ledger.walletSettings.walletCurrencyCode)).font(.largeTitle.weight(.medium)).monospacedDigit()
                        }
                    }
                    if wish.state == .completed {
                        Label(String(localized: "wallet.wishes.completed"), systemImage: "checkmark.circle").foregroundStyle(PaperTheme.accent)
                        if let redemption = workspace.ledger.redemptions.values.first(where: { $0.wishID == wish.id && $0.state == .completed }) {
                            PaperFormItem(title: String(localized: "wallet.wishes.actual"), value: MoneyFormat.string(redemption.actualAmount, currencyCode: redemption.currencyCode))
                        }
                    } else {
                        PaperCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(String(localized: "v1.wish.balance")).font(.subheadline).foregroundStyle(PaperTheme.muted)
                                Text(MoneyFormat.string(workspace.wallet.balance, currencyCode: workspace.ledger.walletSettings.walletCurrencyCode)).font(.title2).monospacedDigit()
                                Text(String(localized: "wallet.wishes.noReservation")).font(.caption).foregroundStyle(PaperTheme.muted)
                            }
                        }
                        Button(String(localized: "wallet.wishes.purchased")) { redeem = true }.buttonStyle(PaperSolidButtonStyle())
                    }
                }.padding(24).frame(maxWidth: 650).frame(maxWidth: .infinity)
            }
        }
        .background(PaperTheme.canvas.ignoresSafeArea())
        .navigationTitle(String(localized: "wallet.wishes.detail")).navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar).toolbar(.hidden, for: .tabBar, .bottomBar).toolbarBackground(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $redeem) { WishRedemptionView(workspace: workspace, wishID: wishID) }
    }
}

struct WishRedemptionView: View {
    @Bindable var workspace: CheckLineWorkspace
    var wishID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var purchaseCurrency = ""
    @State private var exchangeRate = ""
    @State private var quoteDate = Date()
    @State private var purchased = false
    @State private var complete = false
    @State private var failed = false
    private var wish: Wish? { workspace.ledger.wishes[wishID] }
    private var walletCurrency: String { workspace.ledger.walletSettings.walletCurrencyCode }
    private var currency: String { purchaseCurrency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
    private var currencyValid: Bool { Locale.commonISOCurrencyCodes.contains(currency) }
    private var needsQuote: Bool { currencyValid && currency != walletCurrency }
    private var quote: ExchangeQuote? {
        guard needsQuote, let rate = MoneyFormat.parseAmount(exchangeRate), rate > 0 else { return nil }
        return .estimated(rate: rate, at: quoteDate, sourceName: "user_provided_estimate")
    }
    private var parsed: Decimal? { MoneyFormat.parseAmount(amount) }
    private var preview: WishRedemptionPreview? {
        guard let parsed, currencyValid else { return nil }
        return try? WishRedemptionEngine.preview(ledger: workspace.ledger, wishID: wishID, actualAmount: parsed, currencyCode: currency, quote: quote, now: Date())
    }
    private var savedRedemption: WishRedemption? {
        workspace.ledger.redemptions.values.first { $0.wishID == wishID && $0.state == .completed }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let wish {
                        HStack { Spacer(); WalletSymbol(name: wish.symbolName ?? "star", size: 90)
                            .overlay(alignment: .bottomTrailing) { if complete { Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(PaperTheme.accent, PaperTheme.canvas).offset(x: 8, y: 8) } }; Spacer() }.padding(.vertical, 20)
                        Text(wish.name).font(.title2.weight(.medium))
                        if complete {
                            Text(String(localized: "wallet.wishes.success")).font(.headline).foregroundStyle(PaperTheme.accent)
                            if let savedRedemption {
                                PaperFormItem(title: String(localized: "wallet.wishes.actual"), value: MoneyFormat.string(savedRedemption.actualAmount, currencyCode: savedRedemption.currencyCode))
                            }
                            PaperFormItem(title: String(localized: "v1.wish.balance"), value: MoneyFormat.string(workspace.wallet.balance, currencyCode: workspace.ledger.walletSettings.walletCurrencyCode))
                            Button(String(localized: "action.close")) { dismiss() }.buttonStyle(PaperSolidButtonStyle())
                        } else {
                            Text(String(localized: "wallet.wishes.actual")).font(.subheadline).foregroundStyle(PaperTheme.muted)
                            HStack {
                                Text(currency).font(.subheadline).foregroundStyle(PaperTheme.muted)
                                TextField("0.00", text: $amount).keyboardType(.decimalPad).font(.largeTitle).monospacedDigit().accessibilityLabel(String(localized: "wallet.wishes.actual"))
                            }.padding(18).walletSurface()
                            HStack {
                                Text(String(localized: "wallet.wishes.purchaseCurrency"))
                                    .font(.subheadline).foregroundStyle(PaperTheme.muted)
                                Spacer(minLength: 12)
                                TextField("CNY", text: $purchaseCurrency)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: 110)
                                    .accessibilityIdentifier("wallet.wishes.purchaseCurrency")
                            }.padding(18).walletSurface()
                            if !currencyValid {
                                Text(String(localized: "wallet.wishes.invalidCurrency"))
                                    .font(.subheadline).foregroundStyle(PaperTheme.accent)
                            }
                            if needsQuote {
                                WalletExchangeQuoteFields(sourceCurrencyCode: currency, walletCurrencyCode: walletCurrency, rateText: $exchangeRate, quotedAt: $quoteDate)
                            }
                            if let preview {
                                if needsQuote {
                                    PaperFormItem(title: String(localized: "wallet.exchange.walletChange"), value: MoneyFormat.string(preview.walletSignedAmount, currencyCode: walletCurrency))
                                }
                                PaperFormItem(title: String(localized: "wallet.wishes.balanceAfter"), value: MoneyFormat.string(preview.balanceAfter, currencyCode: workspace.ledger.walletSettings.walletCurrencyCode))
                            } else if parsed != nil {
                                Label(needsQuote && quote == nil ? String(localized: "wallet.wishes.exchangeMissing") : String(localized: "wallet.wishes.insufficient"), systemImage: "exclamationmark.circle")
                                    .font(.subheadline).foregroundStyle(PaperTheme.accent)
                            }
                            Text(String(localized: "wallet.wishes.onlyWallet")).font(.subheadline).foregroundStyle(PaperTheme.muted)
                            Toggle(String(localized: "wallet.wishes.purchaseConfirmed"), isOn: $purchased).tint(PaperTheme.accent)
                            if failed { Text(String(localized: "v1.banner.failed")).foregroundStyle(PaperTheme.accent) }
                            Button(String(localized: "wallet.wishes.confirm")) {
                                guard purchased, let parsed, preview != nil else { return }
                                do { try workspace.redeemWish(wishID, actualAmount: parsed, currencyCode: currency, realPurchaseConfirmed: purchased, quote: quote); complete = true }
                                catch { failed = true }
                            }.buttonStyle(PaperSolidButtonStyle(enabled: purchased && preview != nil)).disabled(!purchased || preview == nil)
                        }
                    }
                }.padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PaperTheme.canvas.ignoresSafeArea())
            .navigationTitle(String(localized: "wallet.wishes.redemption")).navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(String(localized: "action.close"), systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly) } }
        }
        .onAppear {
            if purchaseCurrency.isEmpty { purchaseCurrency = wish?.currencyCode ?? walletCurrency }
        }
    }
}
