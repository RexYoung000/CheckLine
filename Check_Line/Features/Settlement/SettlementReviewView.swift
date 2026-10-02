import SwiftUI

/// A single visible quote is shared by the impact preview and the confirmed write.
struct WalletExchangeQuoteFields: View {
    var sourceCurrencyCode: String
    var walletCurrencyCode: String
    @Binding var rateText: String
    @Binding var quotedAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "wallet.exchange.title")).font(.headline)
            Text(String(format: String(localized: "wallet.exchange.rateHint"), sourceCurrencyCode, walletCurrencyCode))
                .font(.subheadline).foregroundStyle(PaperTheme.muted)
            TextField(String(localized: "wallet.exchange.rate"), text: $rateText)
                .keyboardType(AmountKeyboard.type)
                .textContentType(.none)
                .padding(16).walletSurface(radius: 18)
                .accessibilityIdentifier("wallet.exchange.rate")
                .onChange(of: rateText) { _, _ in quotedAt = Date() }
            Text(String(localized: "wallet.exchange.userEstimate"))
                .font(.caption).foregroundStyle(PaperTheme.muted)
            Text(quotedAt, format: .dateTime.year().month().day().hour().minute())
                .font(.caption).foregroundStyle(PaperTheme.muted)
        }
    }
}

struct SettlementReviewView: View {
    @Bindable var workspace: CheckLineWorkspace
    let periodID: UUID
    let onShowWishes: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var accepted = false
    @State private var completed = false
    @State private var reviewedLedger: Ledger?
    @State private var exchangeRate = ""
    @State private var quoteDate = Date()
    @State private var errorText: String?
    @State private var showPending = false
    @State private var showUnbudgeted = false

    private var period: BudgetPeriod? { workspace.ledger.periods[periodID] }
    private var budget: Budget? { period.flatMap { workspace.ledger.budgets[$0.budgetID] } }
    private var walletCurrency: String { workspace.ledger.walletSettings.walletCurrencyCode }
    private var periodSnapshot: PeriodBudgetSnapshot? {
        period.map { BudgetEngine.periodSnapshot(period: $0, expenses: Array(workspace.ledger.expenses.values)) }
    }
    private var needsQuote: Bool {
        guard let period, let periodSnapshot else { return false }
        return period.currencyCode != walletCurrency && periodSnapshot.remaining != 0
    }
    private var quote: ExchangeQuote? {
        guard needsQuote, let rate = MoneyFormat.parseAmount(exchangeRate), rate > 0 else { return nil }
        return .estimated(rate: rate, at: quoteDate, sourceName: "user_provided_estimate")
    }
    private var preview: SettlementPreview? {
        try? workspace.previewSettlement(periodID, quote: quote)
    }
    private var isDue: Bool {
        guard let period, let budget else { return false }
        if budget.cycleType == .oneShot { return true }
        if period.state == .pendingSettlement { return true }
        return CycleEngine.isDue(period, now: Date(), calendar: .current)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let period, let budget, let snapshot = periodSnapshot {
                        header(budget: budget, period: period)
                        if completed {
                            settlementResult(period: period)
                        } else {
                            amounts(period: period, snapshot: snapshot)
                            dataReview(period: period)
                            if needsQuote {
                                WalletExchangeQuoteFields(
                                    sourceCurrencyCode: period.currencyCode,
                                    walletCurrencyCode: walletCurrency,
                                    rateText: $exchangeRate,
                                    quotedAt: $quoteDate
                                )
                                if quote == nil {
                                    Label(String(localized: "wallet.exchange.required"), systemImage: "exclamationmark.circle")
                                        .font(.subheadline).foregroundStyle(PaperTheme.accent)
                                }
                            }
                            if let preview {
                                walletImpact(preview)
                            } else if !needsQuote || quote != nil {
                                Label(String(localized: "wallet.settlement.previewUnavailable"), systemImage: "exclamationmark.circle")
                                    .foregroundStyle(PaperTheme.accent)
                            }
                            if !isDue {
                                Text(String(localized: "wallet.settlement.repeatingNotDue"))
                                    .font(.subheadline).foregroundStyle(PaperTheme.muted)
                            }
                        }
                        if let errorText {
                            Label(errorText, systemImage: "exclamationmark.circle")
                                .font(.subheadline).foregroundStyle(PaperTheme.accent)
                        }
                    } else {
                        ContentUnavailableView(String(localized: "budget.missing"), systemImage: "wallet.pass")
                    }
                }
                .padding(22)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PaperTheme.canvas.ignoresSafeArea())
            .foregroundStyle(PaperTheme.ink)
            .navigationTitle(completed ? String(localized: "wallet.settlement.complete") : String(localized: "wallet.settlement.review"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "action.close"), systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if period != nil {
                    bottomAction
                        .padding(.horizontal, 22).padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(PaperTheme.canvas)
                }
            }
        }
        .onAppear { reviewedLedger = workspace.ledger }
        .onChange(of: workspace.ledger) { _, updated in
            guard !completed else { return }
            reviewedLedger = updated
            accepted = false
            errorText = nil
        }
        .onChange(of: exchangeRate) { _, _ in accepted = false }
        .sheet(isPresented: $showPending) {
            NavigationStack {
                BudgetDetailContent(workspace: workspace, budgetID: budget?.id ?? UUID(), section: .pending)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(String(localized: "action.close")) { showPending = false }
                        }
                    }
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showUnbudgeted) {
            NavigationStack {
                UnbudgetedRecordsView(workspace: workspace)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(String(localized: "action.close")) { showUnbudgeted = false }
                        }
                    }
            }
            .presentationDetents([.large])
        }
    }

    private func header(budget: Budget, period: BudgetPeriod) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(budget.name).font(.title.weight(.semibold))
            HStack(spacing: 6) {
                Text(period.startDate, format: .dateTime.year().month().day())
                Text("–")
                if let end = period.endDate {
                    Text(end, format: .dateTime.year().month().day())
                } else {
                    Text(String(localized: "wallet.noDeadline"))
                }
            }
            .font(.subheadline).foregroundStyle(PaperTheme.muted)
            if completed {
                Label(String(localized: "wallet.settlement.saved"), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(PaperTheme.accent)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }

    private func amounts(period: BudgetPeriod, snapshot: PeriodBudgetSnapshot) -> some View {
        PaperCard {
            VStack(spacing: 12) {
                impactRow(String(localized: "wallet.settlement.budget"), MoneyFormat.string(period.budgetAmount, currencyCode: period.currencyCode))
                impactRow(String(localized: "wallet.settlement.confirmed"), MoneyFormat.string(snapshot.confirmedSpent, currencyCode: period.currencyCode))
                Divider()
                impactRow(
                    snapshot.remaining >= 0 ? String(localized: "wallet.settlement.surplus") : String(localized: "wallet.settlement.overrun"),
                    MoneyFormat.string(abs(snapshot.remaining), currencyCode: period.currencyCode)
                )
            }
        }
    }

    private func dataReview(period: BudgetPeriod) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "wallet.settlement.dataTitle")).font(.headline)
            let pending = workspace.ledger.expenses(inPeriod: period.id).filter { $0.attributionState == .pending }
            let unbudgeted = workspace.ledger.expenses.values.filter { $0.attributionState == .unbudgeted && $0.wishRedemptionID == nil }
            PaperCard {
                VStack(spacing: 14) {
                    Button { showPending = true } label: {
                        dataReviewRow(
                            String(localized: "wallet.settlement.pending"),
                            value: "\(pending.count) · \(MoneyFormat.string(periodSnapshot?.pendingAmount ?? 0, currencyCode: period.currencyCode))",
                            showsArrow: !pending.isEmpty
                        )
                    }
                    .buttonStyle(.plain).disabled(pending.isEmpty)
                    Button { showUnbudgeted = true } label: {
                        dataReviewRow(String(localized: "wallet.settlement.unbudgeted"), value: String(unbudgeted.count), showsArrow: !unbudgeted.isEmpty)
                    }
                    .buttonStyle(.plain).disabled(unbudgeted.isEmpty)
                }
            }
            if !workspace.ledger.dataSources.isEmpty {
                ForEach(workspace.ledger.dataSources.values.sorted { $0.sourceType.rawValue < $1.sourceType.rawValue }) { source in
                    PaperFormItem(
                        title: sourceTitle(source.sourceType),
                        value: source.lastCoveredAt?.formatted(date: .abbreviated, time: .shortened)
                            ?? String(localized: "wallet.settlement.notCovered")
                    )
                }
                if preview?.hasCoverageGap == true {
                    Label(String(localized: "wallet.settlement.coverageGap"), systemImage: "exclamationmark.circle")
                        .font(.subheadline).foregroundStyle(PaperTheme.accent)
                }
            }
            Text(String(localized: "wallet.settlement.missingData"))
                .font(.caption).foregroundStyle(PaperTheme.muted)
        }
    }

    private func dataReviewRow(_ title: String, value: String, showsArrow: Bool) -> some View {
        HStack(spacing: 12) {
            impactRow(title, value)
            if showsArrow {
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(PaperTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func walletImpact(_ preview: SettlementPreview) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "wallet.settlement.impactTitle")).font(.headline)
                if needsQuote {
                    impactRow(String(localized: "wallet.exchange.walletChange"), MoneyFormat.string(preview.walletSignedAmount, currencyCode: walletCurrency))
                    impactRow(String(localized: "wallet.exchange.rate"), preview.conversion.rate.formatted())
                    Text(String(localized: "wallet.exchange.userEstimate") + " · " + preview.conversion.quotedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption).foregroundStyle(PaperTheme.muted)
                }
                impactRow(String(localized: "wallet.settlement.walletBefore"), MoneyFormat.string(workspace.wallet.balance, currencyCode: walletCurrency))
                impactRow(String(localized: "wallet.settlement.walletAfter"), MoneyFormat.string(preview.balanceAfter, currencyCode: walletCurrency))
                impactRow(String(localized: "wallet.settlement.recoveryBefore"), MoneyFormat.string(workspace.wallet.recoveryGap, currencyCode: walletCurrency))
                impactRow(String(localized: "wallet.settlement.recoveryAfter"), MoneyFormat.string(preview.recoveryGapAfter, currencyCode: walletCurrency))
                Text(String(localized: "wallet.wishes.recoveryOrder"))
                    .font(.caption).foregroundStyle(PaperTheme.muted)
            }
        }
    }

    private func settlementResult(period: BudgetPeriod) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 16) {
                if let settlement = workspace.ledger.settlement(forPeriod: periodID) {
                    impactRow(String(localized: "wallet.settlement.confirmed"), MoneyFormat.string(settlement.confirmedSpent, currencyCode: period.currencyCode))
                    impactRow(
                        settlement.baseSurplus >= 0 ? String(localized: "wallet.settlement.surplus") : String(localized: "wallet.settlement.overrun"),
                        MoneyFormat.string(abs(settlement.baseSurplus), currencyCode: period.currencyCode)
                    )
                }
                Divider()
                impactRow(String(localized: "wallet.settlement.walletAfter"), MoneyFormat.string(workspace.wallet.balance, currencyCode: walletCurrency))
                impactRow(String(localized: "wallet.settlement.recoveryAfter"), MoneyFormat.string(workspace.wallet.recoveryGap, currencyCode: walletCurrency))
                Text(String(localized: budget?.cycleType == .repeating ? "wallet.settlement.nextPeriod" : "wallet.settlement.archived"))
                    .font(.subheadline).foregroundStyle(PaperTheme.muted)
            }
        }
    }

    private func impactRow(_ title: String, _ value: String) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
        return layout {
            Text(title).font(.subheadline).foregroundStyle(PaperTheme.muted)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            Text(value).font(.subheadline.weight(.medium)).monospacedDigit()
                .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
        }
    }

    private var bottomAction: some View {
        VStack(spacing: 10) {
            if completed {
                Button(String(localized: "wallet.settlement.viewWishes")) {
                    onShowWishes()
                }
                .buttonStyle(PaperSolidButtonStyle())
                .accessibilityIdentifier("wallet.settlement.viewWishes")
                Button(String(localized: "action.close")) { dismiss() }
                    .frame(minHeight: 44)
            } else {
                Button { accepted.toggle() } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: accepted ? "checkmark.circle.fill" : "circle")
                            .font(.title3).foregroundStyle(PaperTheme.accent)
                        Text(String(localized: "wallet.settlement.acceptData"))
                            .font(.subheadline).multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(accepted ? .isSelected : [])
                    .accessibilityIdentifier("wallet.settlement.acceptData")
                Button(String(localized: "wallet.settlement.confirm")) { confirm() }
                    .buttonStyle(PaperSolidButtonStyle(enabled: accepted && preview != nil && isDue))
                    .disabled(!accepted || preview == nil || !isDue)
                    .accessibilityIdentifier("wallet.settlement.confirm")
            }
        }
        .frame(maxWidth: 600)
    }

    private func confirm() {
        guard let reviewedLedger, accepted, preview != nil, isDue else { return }
        do {
            try workspace.settlePeriod(periodID, quote: quote, reviewedLedger: reviewedLedger, acceptedIncompleteData: true)
            completed = true
            errorText = nil
        } catch LedgerError.staleSettlementPreview {
            accepted = false
            self.reviewedLedger = workspace.ledger
            errorText = String(localized: "wallet.settlement.changed")
        } catch {
            errorText = String(localized: "wallet.settlement.saveFailed")
        }
    }

    private func sourceTitle(_ source: SourceType) -> String {
        switch source {
        case .manual: String(localized: "wallet.source.manual")
        case .agentText: String(localized: "wallet.source.agentText")
        case .voice: String(localized: "wallet.source.voice")
        case .image: String(localized: "wallet.source.image")
        case .applePay: String(localized: "wallet.source.applePay")
        case .sms: String(localized: "wallet.source.sms")
        case .email: String(localized: "wallet.source.email")
        case .statement: String(localized: "wallet.source.statement")
        }
    }
}
