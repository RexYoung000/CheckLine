import SwiftUI

enum ComposerMode: String, CaseIterable, Identifiable {
    case form
    case agent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .form: String(localized: "v1.composer.form")
        case .agent: String(localized: "v1.composer.agent")
        }
    }
}

struct CreateComposerSheet: View {
    @Bindable var workspace: CheckLineWorkspace
    @State private var mode: ComposerMode = .form
    @State private var name = ""
    @State private var amount = ""
    @State private var currency = "CNY"
    @State private var repeating = true
    @State private var merchant = ""
    @State private var note = ""
    @State private var occurredAt = Date()
    @State private var attributionID = "unbudgeted"
    @State private var showingCurrencyPicker = false
    @State private var showingCardPicker = false
    @State private var showingDatePicker = false
    @Environment(\.dismiss) private var dismiss

    private let currencies = ["CNY", "USD", "JPY", "EUR"]

    var body: some View {
        ZStack {
            PaperTheme.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                if mode == .form {
                    formBody
                } else {
                    AgentTaskPanel(workspace: workspace, embedded: true) {
                        workspace.openComposer(.budget)
                        mode = .form
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, 20)
                }
            }

        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if mode == .form {
                PaperSubmitBar(
                    title: workspace.composerIntent == .budget ? String(localized: "v1.budget.create") : String(localized: "wallet.record.save"),
                    enabled: canSubmit,
                    action: submitForm
                ).padding(.top, 12).background(PaperTheme.canvas)
            }
        }
        .presentationBackground(PaperTheme.canvas)
        .tint(PaperTheme.accent)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(PaperTheme.Radius.sheet)
        .onAppear {
            currency = workspace.ledger.walletSettings.walletCurrencyCode
            if let selected = workspace.selectedCard, let choice = workspace.attributionChoices.first(where: { $0.periodID == selected.periodID }) {
                attributionID = choice.id
            }
        }
        .onChange(of: workspace.showComposer) { _, presented in
            if presented == false { dismiss() }
        }
        .onChange(of: mode) { _, mode in
            if mode == .form { workspace.banner = nil }
        }
        .confirmationDialog(
            String(localized: "v1.composer.choose.currency"),
            isPresented: $showingCurrencyPicker,
            titleVisibility: .visible
        ) {
            ForEach(currencies, id: \.self) { code in
                Button(code) { currency = code }
            }
        }
        .confirmationDialog(
            String(localized: "v1.composer.choose.card"),
            isPresented: $showingCardPicker,
            titleVisibility: .visible
        ) {
            ForEach(workspace.attributionChoices) { choice in
                Button(choiceTitle(choice)) { attributionID = choice.id }
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            NavigationStack {
                DatePicker(
                    String(localized: "v1.composer.date"),
                    selection: $occurredAt,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                .navigationTitle(String(localized: "v1.composer.choose.date"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "action.close")) { showingDatePicker = false }
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationBackground(PaperTheme.canvas)
        }
    }

    private var header: some View {
        HStack {
            PaperComposerCloseButton(action: dismiss.callAsFunction)
            Spacer()
            PaperCapsuleSegment(
                items: ComposerMode.allCases.map { ($0, $0.title) },
                selection: $mode
            )
            .frame(maxWidth: 220)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .frame(minHeight: 52)
    }

    private var formBody: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                WalletSymbol(name: workspace.composerIntent == .budget ? "wallet.pass" : "square.and.pencil")
                    .padding(.top, 8)

                if workspace.composerIntent == .budget {
                    PaperHeroField(
                        placeholder: String(localized: "v1.composer.name.placeholder"),
                        text: $name
                    )
                    PaperCapsuleSegment(
                        items: [
                            (true, String(localized: "wallet.cycle.monthly")),
                            (false, String(localized: "v1.cycle.oneShot")),
                        ],
                        selection: $repeating
                    )
                    .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Text(String(localized: "v1.budget.amount"))
                                .font(.body)
                                .foregroundStyle(PaperTheme.muted)
                            TextField("0", text: $amount)
                                .accessibilityLabel(String(localized: "v1.budget.amount"))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.body)
                                .foregroundStyle(PaperTheme.ink)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 52)
                        .walletSurface()
                        .accessibilityLabel(String(localized: "v1.budget.amount"))

                        PaperFormItem(
                            title: String(localized: "v1.budget.currency"),
                            value: currency,
                            showArrow: true
                        ) {
                            showingCurrencyPicker = true
                        }
                    }
                } else {
                    VStack(spacing: 8) {
                        Text(recordCurrency).font(.subheadline).foregroundStyle(PaperTheme.muted)
                        PaperHeroField(
                            placeholder: String(localized: "v1.composer.amount.placeholder"),
                            text: $amount,
                            keyboard: .decimalPad
                        )
                    }

                    VStack(spacing: 12) {
                        merchantRow
                        PaperFormItem(
                            title: String(localized: "v1.agent.attribution"),
                            value: currentAttributionTitle,
                            showArrow: true
                        ) {
                            showingCardPicker = true
                        }
                        PaperFormItem(
                            title: String(localized: "v1.composer.date"),
                            value: occurredAt.formatted(date: .long, time: .omitted),
                            showArrow: true
                        ) {
                            showingDatePicker = true
                        }
                        noteCard
                    }
                }

                if let banner = workspace.banner {
                    Text(banner.localizedText)
                        .font(PaperTheme.Typography.meta)
                        .foregroundStyle(PaperTheme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var merchantRow: some View {
        HStack(spacing: 12) {
            Text(String(localized: "v1.composer.merchant"))
                .font(.body)
                .foregroundStyle(PaperTheme.muted)
            TextField("", text: $merchant, prompt: Text(String(localized: "v1.composer.merchant.placeholder")).foregroundStyle(PaperTheme.muted))
                .accessibilityLabel(String(localized: "v1.composer.merchant"))
                .font(.body)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(PaperTheme.ink)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .walletSurface()
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $note)
                    .font(.subheadline)
                    .foregroundStyle(PaperTheme.ink)
                    .scrollContentBackground(.hidden)
                    .accessibilityLabel(String(localized: "v1.composer.note.placeholder"))
                    .frame(height: 120)
                    .onChange(of: note) { _, newValue in
                        if newValue.count > 150 {
                            note = String(newValue.prefix(150))
                        }
                    }
                if note.isEmpty {
                    Text(String(localized: "v1.composer.note.placeholder"))
                        .font(.subheadline)
                        .foregroundStyle(PaperTheme.muted)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
            }
            HStack {
                Spacer()
                Text("\(note.count)/150")
                    .font(.caption2)
                    .foregroundStyle(PaperTheme.muted)
            }
        }
        .padding(12)
        .walletSurface()
    }

    private var canSubmit: Bool {
        switch workspace.composerIntent {
        case .budget:
            name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                && MoneyFormat.parseAmount(amount) != nil
        case .record:
            MoneyFormat.parseAmount(amount) != nil
        }
    }

    private var recordCurrency: String {
        let periodID = workspace.attributionChoices.first { $0.id == attributionID }?.periodID
        return workspace.cards.first { $0.periodID == periodID }?.currencyCode ?? workspace.ledger.walletSettings.walletCurrencyCode
    }

    private var currentAttributionTitle: String {
        if let choice = workspace.attributionChoices.first(where: { $0.id == attributionID }) {
            return choiceTitle(choice)
        }
        return String(localized: "v1.unbudgeted")
    }

    private func choiceTitle(_ choice: AttributionChoice) -> String {
        choice.periodID == nil ? String(localized: "v1.unbudgeted") : choice.title
    }

    private func submitForm() {
        PaperHaptics.light()
        switch workspace.composerIntent {
        case .budget:
            workspace.createBudget(
                name: name,
                amountText: amount,
                currencyCode: currency,
                cycleType: repeating ? .repeating : .oneShot
            )
        case .record:
            workspace.recordExpense(
                amountText: amount,
                merchant: merchant,
                note: note,
                attributionID: attributionID,
                occurredAt: occurredAt
            )
        }
    }
}
