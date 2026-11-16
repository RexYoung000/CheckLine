import DistortionWavesKit
import SwiftUI
import UIKit
#if DEBUG
import os

/// Timings only. No budget, amount, record or identifier is attached to events.
nonisolated private enum SettlementPerformanceTrace {
    static let signposter = OSSignposter(subsystem: "Rex.CheckLine", category: "Settlement")
}
#endif

/// A single visible quote is shared by the impact preview and the confirmed write.
struct WalletExchangeQuoteFields: View {
    var sourceCurrencyCode: String
    var walletCurrencyCode: String
    @Binding var rateText: String
    @Binding var quotedAt: Date
    var showsProvenance = true
    var onFocusChange: ((Bool) -> Void)? = nil
    @FocusState private var rateFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "wallet.exchange.title")).font(.headline)
            Text(String(format: String(localized: "wallet.exchange.rateHint"), sourceCurrencyCode, walletCurrencyCode))
                .font(.subheadline).foregroundStyle(PaperTheme.muted)
            TextField(String(localized: "wallet.exchange.rate"), text: $rateText)
                .focused($rateFocused)
                .keyboardType(AmountKeyboard.type)
                .textContentType(.none)
                .padding(16).walletSurface(radius: 18)
                .paperFocusRing(rateFocused, radius: 18)
                .accessibilityIdentifier("wallet.exchange.rate")
                .simultaneousGesture(TapGesture().onEnded { rateFocused = true })
                .onChange(of: rateText) { _, _ in quotedAt = Date() }
                .onChange(of: rateFocused) { _, focused in onFocusChange?(focused) }
            if showsProvenance {
                Text(String(localized: "wallet.exchange.userEstimate"))
                    .font(.caption).foregroundStyle(PaperTheme.muted)
                    .accessibilityIdentifier("wallet.exchange.provenance.input")
                Text(quotedAt, format: .dateTime.year().month().day().hour().minute())
                    .font(.caption).foregroundStyle(PaperTheme.muted)
                    .accessibilityIdentifier("wallet.exchange.provenance.time")
            }
        }
    }
}

struct SettlementReviewView: View {
    @Bindable var workspace: CheckLineWorkspace
    let periodID: UUID
    var endingEarly = false
    let onShowWishes: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var closingReceipt: SettlementOutcomeReceipt?
    @State private var confirmFrame = CGRect.zero
    @State private var reviewHeadingFrame = CGRect.zero
    @State private var waveCaptureView = UIView()
    @State private var reviewSnapshot: UIImage?
    @State private var waveStarted: Date?
    @State private var waveLaunched = false
    @State private var resultIsExposed = true
    @State private var resultEntrance: SettlementResultEntrance?

    private let buttonLeadIn: TimeInterval = 0.24
    private var waveStyle: DistortionWaveStyle {
        var style = DistortionWaveStyle.vertical
        style.cornerRadius = 32
        style.anticipation = 0.30
        style.pull = 6
        style.gatherGlow = 0.15
        style.travel = 2.50
        style.easing = DistortionWaveEasing(0.34, 0.72, 0.48, 1)
        style.rimFade = 1.45
        style.hairlineLinger = 0.12
        style.hairlineFade = 1.55
        style.particleLife = 1.43
        if let outcome, outcome.originalAmount < 0 {
            style.palette = .ocean
            style.strength = 0.48
            style.rimStrength = 0.43
            style.hairlineOpacity = 0.48
            style.particleCount = 24
        }
        return style
    }
    @State private var accepted = false
    @State private var completed = false
    @State private var reviewedLedger: Ledger?
    @State private var exchangeRate = ""
    @State private var quoteDate = Date()
    @State private var errorText: String?
    @State private var showPending = false
    @State private var showUnbudgeted = false

    private var outcome: SettlementOutcomeReceipt? {
        if let closingReceipt { return closingReceipt }
        guard let receipt = workspace.latestSettlementReceipt, receipt.settlement.periodID == periodID else { return nil }
        return receipt
    }

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
    private var previewResult: Result<SettlementPreview, Error> {
        Result {
            if endingEarly { try workspace.previewEarlySettlement(periodID, quote: quote) }
            else { try workspace.estimateSettlement(periodID, quote: quote) }
        }
    }
    private var preview: SettlementPreview? { try? previewResult.get() }
    private var previewFailure: String {
        guard case .failure(let error) = previewResult else { return "" }
        switch error {
        case LedgerError.missingExchangeRate: return String(localized: "wallet.exchange.required")
        case LedgerError.invalidExchangeRate: return String(localized: "wallet.exchange.required")
        case LedgerError.futureRecordsBlockEarlySettlement: return String(localized: "settlement.early.futureRecords")
        case LedgerError.periodNotReadyToSettle, LedgerError.periodNotFound: return String(localized: "ui.settlement.periodUnavailable")
        default: return String(localized: "wallet.settlement.previewUnavailable")
        }
    }
    private var isDue: Bool {
        guard let period, let budget else { return false }
        if budget.cycleType == .oneShot { return true }
        if period.state == .pendingSettlement { return true }
        return CycleEngine.isDue(period, now: Date(), calendar: .current)
    }
    private var canFinalize: Bool {
        isDue || (endingEarly && SettlementEngine.canEndEarly(ledger: workspace.ledger, periodID: periodID, now: Date(), calendar: .current))
    }
    private var nextStart: Date? {
        guard let period, let budget, budget.cycleType == .repeating else { return nil }
        if completed {
            return workspace.ledger.periods(forBudget: budget.id).first(where: { $0.sequence == period.sequence + 1 })?.startDate
        }
        return try? CycleEngine.nextPeriodPlan(budget: budget, settledPeriod: period, calendar: .current).startDate
    }

    var body: some View {
        ZStack {
            if let outcome {
                SettlementOutcomeView(
                    receipt: outcome,
                    waveStarted: waveStarted,
                    entrance: resultEntrance,
                    onSkipMotion: finishWave,
                    onDone: closeResult
                )
                .allowsHitTesting(resultIsExposed)
                .accessibilityHidden(!resultIsExposed)
            } else {
                reviewScreen
            }
        }
        .overlay {
            if !reduceMotion, outcome == nil || reviewSnapshot != nil {
                settlementWave.allowsHitTesting(false).accessibilityHidden(true)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active, outcome != nil { finishWave() }
        }
        .onChange(of: reduceMotion) { _, enabled in
            if enabled, outcome != nil { finishWave() }
        }
        .task(id: waveStarted) {
            guard waveStarted != nil else { return }
            do {
                try await Task.sleep(for: .seconds(buttonLeadIn))
                try Task.checkCancellation()
                waveLaunched = true
                try await Task.sleep(for: .seconds(waveStyle.anticipation + 0.36))
                try Task.checkCancellation()
                resultIsExposed = true
            } catch {
                // A skipped or dismissed wave no longer controls the result.
            }
        }
        .modifier(NativeDrawerStyle())
        .sheet(isPresented: $showPending) {
            NavigationStack {
                BudgetDetailContent(workspace: workspace, budgetID: budget?.id ?? UUID(), section: .pending, periodID: periodID)
                    .navigationDestination(for: BudgetWorkspaceRoute.self) { route in
                        BudgetWorkspaceDestination(workspace: workspace, route: route)
                    }
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
                    .navigationDestination(for: BudgetWorkspaceRoute.self) { route in
                        BudgetWorkspaceDestination(workspace: workspace, route: route)
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(String(localized: "action.close")) { showUnbudgeted = false }
                        }
                    }
            }
            .presentationDetents([.large])
        }
    }

    private var reviewScreen: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let period, let budget, let snapshot = periodSnapshot {
                        header(budget: budget, period: period)
                            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                                if !completed { reviewHeadingFrame = frame }
                            }
                        if endingEarly && !completed, let nextStart {
                            Text(String(format: String(localized: "settlement.early.schedule"),
                                        Date().formatted(date: .abbreviated, time: .omitted),
                                        nextStart.formatted(date: .abbreviated, time: .omitted)))
                                .font(.subheadline).foregroundStyle(PaperTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("settlement.early.schedule")
                        }
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
                                    quotedAt: $quoteDate,
                                    showsProvenance: preview == nil
                                )
                                if quote == nil {
                                    CheckLineIconLabel(String(localized: "wallet.exchange.required"), symbol: "exclamationmark.circle")
                                        .font(.subheadline).foregroundStyle(PaperTheme.accent)
                                }
                            }
                            if let preview {
                                walletImpact(preview)
                            } else if !needsQuote || quote != nil {
                                CheckLineIconLabel(previewFailure, symbol: "exclamationmark.circle")
                                    .foregroundStyle(PaperTheme.accent)
                            }
                            if !canFinalize {
                                Text(String(localized: "wallet.settlement.repeatingNotDue"))
                                    .font(.subheadline).foregroundStyle(PaperTheme.muted)
                            }
                        }
                        if let errorText {
                            CheckLineIconLabel(errorText, symbol: "exclamationmark.circle")
                                .font(.subheadline).foregroundStyle(PaperTheme.accent)
                        }
                    } else {
                        ContentUnavailableView { Label { Text(String(localized: "budget.missing")) } icon: { CheckLineIcon(symbol: "wallet.pass", size: 48) } }
                    }
                }
                .padding(22)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PaperTheme.canvas.ignoresSafeArea())
            .foregroundStyle(PaperTheme.ink)
            .navigationTitle(completed ? String(localized: "wallet.settlement.complete") : String(localized: endingEarly ? "settlement.early.title" : isDue ? "wallet.settlement.review" : "ui.settlement.estimate"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "action.close"), iconSymbol: "xmark") { dismiss() }
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
    }

    private var settlementWave: some View {
        GeometryReader { geometry in
            let origin = geometry.frame(in: .global).origin
            let source = (resultEntrance?.button ?? confirmFrame).offsetBy(dx: -origin.x, dy: -origin.y)
            // The departing frame includes the native toolbar and scroll position.
            // The saved result is already underneath, with its original materials.
            DistortionWave(
                isRevealed: waveLaunched,
                source: source,
                style: waveStyle,
                onFinish: finishWave
            ) {
                if let reviewSnapshot {
                    Image(uiImage: reviewSnapshot)
                        .resizable()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: waveStyle.cornerRadius))
                } else {
                    Color.clear
                }
            } revealed: {
                Color.clear
            }
            .overlay {
                if let waveStarted, reviewSnapshot != nil {
                    TimelineView(.animation(minimumInterval: 1.0 / 60, paused: resultIsExposed)) { clock in
                        let elapsed = clock.date.timeIntervalSince(waveStarted)
                        let glowDuration = buttonLeadIn + waveStyle.anticipation
                        if elapsed < glowDuration {
                            let progress = max(0, elapsed / glowDuration)
                            let glow = sin(progress * .pi)
                            Capsule()
                                .strokeBorder(Color(red: 0.60, green: 0.86, blue: 1), lineWidth: 2)
                                .background(Color(red: 0.60, green: 0.86, blue: 1).opacity(0.20), in: Capsule())
                                .shadow(color: Color(red: 0.39, green: 0.73, blue: 1), radius: 8)
                                .opacity(glow)
                                .frame(width: source.width, height: source.height)
                                .position(x: source.midX, y: source.midY)
                        }
                    }
                }
            }
            .background(SettlementWaveCapture(view: waveCaptureView))
            .onChange(of: geometry.size) { _, _ in
                if outcome != nil { finishWave() }
            }
        }
        .ignoresSafeArea()
    }

    private func finishWave() {
        reviewSnapshot = nil
        resultEntrance = nil
        waveStarted = nil
        resultIsExposed = true
    }

    private func closeResult() {
        finishWave()
        // Retain the result locally while the drawer animates out.
        if let outcome, workspace.latestSettlementReceipt?.settlement.id == outcome.settlement.id {
            closingReceipt = outcome
            workspace.latestSettlementReceipt = nil
        }
        dismiss()
    }

    private func header(budget: Budget, period: BudgetPeriod) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(budget.name).font(.title.weight(.semibold))
            HStack(spacing: 6) {
                Text(period.startDate, format: .dateTime.year().month().day())
                Text("–")
                if endingEarly && !completed {
                    Text(Date(), format: .dateTime.year().month().day())
                } else if let end = period.endDate {
                    Text(end, format: .dateTime.year().month().day())
                } else {
                    Text(String(localized: "wallet.noDeadline"))
                }
            }
            .font(.subheadline).foregroundStyle(PaperTheme.muted)
            if completed {
                CheckLineIconLabel(String(localized: "wallet.settlement.saved"), symbol: "checkmark.circle.fill")
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
                    .buttonStyle(.plain).disabled(pending.isEmpty).accessibilityIdentifier("wallet.settlement.pending")
                    Button { showUnbudgeted = true } label: {
                        dataReviewRow(String(localized: "wallet.settlement.unbudgeted"), value: String(unbudgeted.count), showsArrow: !unbudgeted.isEmpty)
                    }
                    .buttonStyle(.plain).disabled(unbudgeted.isEmpty).accessibilityIdentifier("wallet.settlement.unbudgeted")
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
                    CheckLineIconLabel(String(localized: "wallet.settlement.coverageGap"), symbol: "exclamationmark.circle")
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
                CheckLineIcon(symbol: "chevron.right", size: 16).foregroundStyle(PaperTheme.muted)
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
                        .accessibilityIdentifier("wallet.exchange.provenance.preview")
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
                if let nextStart, nextStart > Date() {
                    Text(String(format: String(localized: "settlement.early.resumes"), nextStart.formatted(date: .abbreviated, time: .omitted)))
                        .font(.subheadline).foregroundStyle(PaperTheme.muted)
                } else {
                    Text(String(localized: budget?.cycleType == .repeating ? "wallet.settlement.nextPeriod" : "wallet.settlement.archived"))
                        .font(.subheadline).foregroundStyle(PaperTheme.muted)
                }
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
            } else if canFinalize {
                Button { accepted.toggle() } label: {
                    HStack(alignment: .top, spacing: 12) {
                        CheckLineIcon(symbol: accepted ? "checkmark.circle.fill" : "circle", size: 24)
                            .foregroundStyle(PaperTheme.accent)
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
                Button(String(localized: endingEarly ? "settlement.early.confirm" : "wallet.settlement.confirm")) { confirm() }
                    .buttonStyle(PaperSolidButtonStyle(enabled: accepted && preview != nil && canFinalize))
                    .disabled(!accepted || preview == nil || !canFinalize)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                        confirmFrame = frame
                    }
                    .accessibilityIdentifier("wallet.settlement.confirm")
            } else {
                Text(String(localized: "ui.settlement.currentEstimate"))
                    .font(.caption).foregroundStyle(PaperTheme.muted)
                    .accessibilityIdentifier("wallet.settlement.estimateOnly")
            }
        }
        .frame(maxWidth: 600)
    }

    private func confirm() {
        guard outcome == nil, !completed, let reviewedLedger, let savedPeriod = period,
              accepted, preview != nil, canFinalize else { return }
        let before = workspace.wallet
        let savedTitle = budget?.name ?? String(localized: "wallet.settlement.complete")
        let snapshot = !reduceMotion && scenePhase == .active && !confirmFrame.isEmpty
            ? SettlementWaveCapture.snapshot(of: waveCaptureView)
            : nil
        do {
            try {
                #if DEBUG
                let trace = SettlementPerformanceTrace.signposter
                let interval = trace.beginInterval("SettlementSave", id: trace.makeSignpostID())
                defer { trace.endInterval("SettlementSave", interval) }
                #endif
                try workspace.settlePeriod(periodID, quote: quote, reviewedLedger: reviewedLedger, acceptedIncompleteData: true, endingEarly: endingEarly)
            }()
            completed = true
            self.reviewedLedger = nil
            errorText = nil
            guard let savedSettlement = workspace.ledger.settlement(forPeriod: periodID) else { return }
            workspace.latestSettlementReceipt = SettlementOutcomeReceipt(
                title: savedTitle, settlement: savedSettlement, periodStart: savedPeriod.startDate,
                periodEnd: workspace.ledger.periods[periodID]?.endDate, walletCurrency: walletCurrency,
                before: before, after: workspace.wallet
            )
            if let snapshot {
                reviewSnapshot = snapshot
                resultEntrance = SettlementResultEntrance(
                    heading: reviewHeadingFrame,
                    button: confirmFrame,
                    start: buttonLeadIn + waveStyle.anticipation,
                    duration: 0.71
                )
                waveStarted = Date()
                resultIsExposed = false
            }
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

/// Provides the wave's bounds in the native window so it can retain the exact
/// outgoing frame, including the system toolbar and the current scroll position.
private struct SettlementWaveCapture: UIViewRepresentable {
    let view: UIView

    func makeUIView(context: Context) -> UIView { view }
    func updateUIView(_ uiView: UIView, context: Context) {}

    static func snapshot(of view: UIView) -> UIImage? {
        guard let window = view.window, !view.bounds.isEmpty else { return nil }
        #if DEBUG
        let trace = SettlementPerformanceTrace.signposter
        let interval = trace.beginInterval("SettlementCapture", id: trace.makeSignpostID())
        defer { trace.endInterval("SettlementCapture", interval) }
        #endif
        let rect = view.convert(view.bounds, to: window)
        let format = UIGraphicsImageRendererFormat()
        format.scale = window.traitCollection.displayScale
        let renderer = UIGraphicsImageRenderer(size: rect.size, format: format)
        var captured = false
        let image = renderer.image { _ in
            captured = window.drawHierarchy(
                in: window.bounds.offsetBy(dx: -rect.minX, dy: -rect.minY),
                afterScreenUpdates: false
            )
        }
        return captured ? image : nil
    }
}
