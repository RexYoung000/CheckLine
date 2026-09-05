import SwiftData
import SwiftUI
import UIKit

struct CheckLineHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var workspace: CheckLineWorkspace?
    @State private var showWish = false
    @State private var showSettings = false

    var body: some View {
        Group {
            if let workspace {
                HomeContentView(workspace: workspace, showWish: $showWish, showSettings: $showSettings)
            } else {
                ProgressView()
                    .onAppear {
                        workspace = CheckLineWorkspace(context: modelContext)
                    }
            }
        }
    }
}

private struct HomeContentView: View {
    @Bindable var workspace: CheckLineWorkspace
    @Binding var showWish: Bool
    @Binding var showSettings: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if workspace.processingItems.isEmpty == false {
                        HomeProcessingStrip(items: workspace.processingItems)
                    }

                    if workspace.isEmpty {
                        emptyState
                    } else {
                        ForEach(workspace.cards) { card in
                            NavigationLink {
                                HomeBudgetDetailView(card: card, ledger: workspace.ledger)
                            } label: {
                                HomeBudgetCardView(card: card)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(String(localized: "v1.home.title"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "v1.wish.entry")) { showWish = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "v1.settings.entry")) { showSettings = true }
                }
            }
            .safeAreaInset(edge: .bottom) {
                AgentTaskPanel(workspace: workspace)
            }
            .sheet(isPresented: $showWish) {
                WishWalletSummaryView(projection: workspace.wallet, currencyCode: workspace.ledger.walletSettings.walletCurrencyCode)
            }
            .sheet(isPresented: $showSettings) {
                SettingsPlaceholderView()
            }
            .sheet(isPresented: $workspace.showCreateBudget) {
                CreateBudgetSheet(workspace: workspace)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "v1.home.empty.title"))
                .font(.title2.weight(.semibold))
            Text(String(localized: "v1.home.empty.message"))
                .foregroundStyle(.secondary)
            Button(String(localized: "v1.budget.create")) {
                workspace.showCreateBudget = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 24)
        .accessibilityElement(children: .combine)
    }
}

private struct HomeProcessingStrip: View {
    var items: [HomeProcessingItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items) { item in
                Text(label(for: item.kind))
                    .font(.subheadline)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel(label(for: item.kind))
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func label(for kind: HomeProcessingKind) -> String {
        switch kind {
        case .pendingTransactions(let count):
            String(format: String(localized: "v1.process.pending"), locale: .current, count)
        case .unbudgetedTransactions(let count):
            String(format: String(localized: "v1.process.unbudgeted"), locale: .current, count)
        case .possibleOverrun(let name):
            String(format: String(localized: "v1.process.possible"), locale: .current, name)
        case .certainOverrun(let name):
            String(format: String(localized: "v1.process.certain"), locale: .current, name)
        case .noDataSources:
            String(localized: "v1.process.coverage")
        }
    }
}

private struct HomeBudgetCardView: View {
    var card: HomeBudgetCardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(card.name)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                Text(cycleLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            labeledAmount(String(localized: "v1.card.used"), card.snapshot.confirmedSpent)
            labeledAmount(String(localized: "v1.card.remaining"), card.snapshot.availableToSpend)
            if card.snapshot.pendingAmount != 0 {
                labeledAmount(String(localized: "v1.card.pending"), card.snapshot.pendingAmount)
            }
            ProgressView(value: NSDecimalNumber(decimal: card.snapshot.progress).doubleValue)
                .accessibilityLabel(String(localized: "v1.card.progress"))
                .accessibilityValue("\(card.snapshot.progress)")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private var cycleLabel: String {
        card.cycleType == .repeating
            ? String(localized: "v1.cycle.repeating")
            : String(localized: "v1.cycle.oneShot")
    }

    private func labeledAmount(_ title: String, _ amount: Decimal) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(MoneyFormat.string(amount, currencyCode: card.currencyCode))
                .monospacedDigit()
        }
        .font(.subheadline)
    }
}

struct HomeBudgetDetailView: View {
    var card: HomeBudgetCardModel
    var ledger: Ledger

    var body: some View {
        List {
            Section(String(localized: "v1.card.section.status")) {
                LabeledContent(String(localized: "v1.card.used")) {
                    Text(MoneyFormat.string(card.snapshot.confirmedSpent, currencyCode: card.currencyCode))
                }
                LabeledContent(String(localized: "v1.card.remaining")) {
                    Text(MoneyFormat.string(card.snapshot.availableToSpend, currencyCode: card.currencyCode))
                }
                if card.snapshot.pendingAmount != 0 {
                    LabeledContent(String(localized: "v1.card.pending")) {
                        Text(MoneyFormat.string(card.snapshot.pendingAmount, currencyCode: card.currencyCode))
                    }
                }
            }
            Section(String(localized: "v1.card.section.records")) {
                let expenses = ledger.expenses.values
                    .filter { $0.budgetPeriodID == card.periodID }
                    .sorted { $0.occurredAt > $1.occurredAt }
                if expenses.isEmpty {
                    Text(String(localized: "v1.card.records.empty"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(expenses) { expense in
                        VStack(alignment: .leading) {
                            Text(expense.merchant ?? String(localized: "v1.card.record.untitled"))
                            Text(MoneyFormat.string(expense.originalAmount, currencyCode: expense.originalCurrencyCode))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(card.name)
    }
}

private struct CreateBudgetSheet: View {
    @Bindable var workspace: CheckLineWorkspace
    @State private var name = ""
    @State private var amount = ""
    @State private var currency = "CNY"
    @State private var repeating = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField(String(localized: "v1.budget.name"), text: $name)
                TextField(String(localized: "v1.budget.amount"), text: $amount)
                    .keyboardType(.decimalPad)
                Picker(String(localized: "v1.budget.currency"), selection: $currency) {
                    Text("CNY").tag("CNY")
                    Text("USD").tag("USD")
                    Text("JPY").tag("JPY")
                    Text("EUR").tag("EUR")
                }
                Picker(String(localized: "v1.budget.cycle"), selection: $repeating) {
                    Text(String(localized: "v1.cycle.repeating")).tag(true)
                    Text(String(localized: "v1.cycle.oneShot")).tag(false)
                }
            }
            .navigationTitle(String(localized: "v1.budget.create"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.create")) {
                        workspace.createBudget(
                            name: name,
                            amountText: amount,
                            currencyCode: currency,
                            cycleType: repeating ? .repeating : .oneShot
                        )
                        if workspace.banner == .createdBudget {
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
