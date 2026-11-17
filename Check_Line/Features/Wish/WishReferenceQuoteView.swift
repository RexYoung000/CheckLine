import SwiftUI

/// Editing is transient. Only Apply replaces the separately stored reference.
struct WishReferenceQuoteView: View {
    @Bindable var workspace: CheckLineWorkspace
    let wish: Wish
    private let walletCurrencyAtOpen: String
    @State private var rateText = ""
    @State private var quotedAt = Date()
    @State private var failed = false
    @State private var rateFocused = false
    @Environment(\.dismiss) private var dismiss
    private var source: String { wish.currencyCode ?? workspace.ledger.walletSettings.walletCurrencyCode }
    private var target: String { walletCurrencyAtOpen }
    init(workspace: CheckLineWorkspace, wish: Wish) {
        self.workspace = workspace; self.wish = wish
        walletCurrencyAtOpen = workspace.ledger.walletSettings.walletCurrencyCode
        do {
            let existing = try workspace.wishReferenceQuotes.reference(for: wish.id, source: wish.currencyCode ?? walletCurrencyAtOpen, target: walletCurrencyAtOpen)
            _rateText = State(initialValue: existing?.rate.description ?? "")
            _quotedAt = State(initialValue: existing?.quotedAt ?? Date())
        } catch { _failed = State(initialValue: true) }
    }
    private var reference: WishReferenceQuote? {
        guard let rate = MoneyFormat.parseAmount(rateText) else { return nil }
        let value = WishReferenceQuote(wishID: wish.id, sourceCurrency: source, walletCurrency: target, rate: rate, quotedAt: quotedAt)
        return value.isValid ? value : nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(wish.name).font(.title2.weight(.medium)).foregroundStyle(PaperTheme.ink)
                    Text(String(localized: "native.wish.referenceExplanation")).font(.subheadline).foregroundStyle(PaperTheme.muted)
                    WalletExchangeQuoteFields(sourceCurrencyCode: source, walletCurrencyCode: target,
                                              rateText: $rateText, quotedAt: $quotedAt,
                                              onFocusChange: { rateFocused = $0 })
                    if let reference,
                       let required = WishCoverage.calculate(wish: wish, walletBalance: workspace.wallet.balance,
                            walletCurrency: target, reference: reference).targetInWallet {
                        PaperValueRow(title: String(localized: "native.wish.referenceTarget"), value: MoneyFormat.string(required, currencyCode: target))
                            .accessibilityIdentifier("native.wish.referenceTarget")
                    }
                    if failed {
                        Text(String(localized: "native.wish.referenceFailed")).font(.subheadline).foregroundStyle(PaperTheme.ink)
                            .accessibilityIdentifier("native.wish.referenceFailed")
                    }
                }.padding(PaperTheme.Layout.sheetPadding).frame(maxWidth: PaperTheme.Layout.sheetMaxWidth).frame(maxWidth: .infinity)
            }.scrollDismissesKeyboard(.interactively).background(PaperTheme.canvas.ignoresSafeArea())
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 0) {
                        if rateFocused {
                            PaperKeyboardDoneBar { rateFocused = false }
                        }
                        PaperSubmitBar(title: String(localized: "native.wish.applyReference"), enabled: reference != nil) { apply() }
                            .accessibilityIdentifier("native.wish.applyReference").padding(.vertical, 12).background(PaperTheme.canvas)
                    }
                }
                .navigationTitle(String(localized: "native.wish.checkRate")).navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "action.cancel")) { dismiss() }.accessibilityIdentifier("native.wish.cancelReference")
                    }
                }
        }.modifier(NativeDrawerStyle())
    }

    private func apply() {
        guard let reference else { return }
        do { try workspace.applyWishReference(reference); PaperHaptics.success(); dismiss() }
        catch { failed = true }
    }
}
