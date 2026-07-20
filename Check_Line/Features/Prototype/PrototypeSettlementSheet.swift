import SwiftUI

struct PrototypeSettlementSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: PrototypeStore
    let budgetID: UUID
    let onFinished: (PrototypeAppTab) -> Void

    @State private var choices: [UUID: PrototypeSettlementChoice] = [:]
    @State private var completedSurplus: Decimal?

    private var budget: PrototypeBudget? { store.budget(id: budgetID) }
    private var linkedExpenses: [PrototypeExpense] { store.linkedExpenses(for: budgetID) }

    var body: some View {
        NavigationStack {
            Group {
                if let budget {
                    if let completedSurplus {
                        completionView(budget: budget, surplus: completedSurplus)
                    } else {
                        checklistView(budget)
                    }
                } else {
                    ContentUnavailableView("budget.missing", systemImage: "wallet.pass")
                }
            }
            .background(CheckLineColor.canvas)
            .navigationTitle(Text(LocalizedStringKey(budget?.status == .active ? "settlement.preview" : "settlement.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if completedSurplus == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("action.close") { dismiss() }
                    }
                }
            }
        }
    }

    private func checklistView(_ budget: PrototypeBudget) -> some View {
        List {
            Section {
                settlementSummary(budget)
            }

            Section("linked.title") {
                if linkedExpenses.isEmpty {
                    ContentUnavailableView("settlement.linked.empty", systemImage: "link.badge.plus")
                } else {
                    ForEach(linkedExpenses) { expense in
                        linkedRow(expense, budget: budget)
                    }
                }
            }

            Section {
                if budget.status == .active {
                    Text("settlement.preview.message")
                    Button("settlement.return") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .tint(CheckLineColor.brand)
                } else {
                    Button("settlement.complete") { completeSettlement() }
                        .buttonStyle(.borderedProminent)
                        .tint(CheckLineColor.brand)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func settlementSummary(_ budget: PrototypeBudget) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                metric(title: "settlement.total.spent", value: currencyText(budget.spent))
                metric(title: "settlement.total.budget", value: currencyText(budget.total))
            }
            Divider()
            Text("settlement.surplus")
                .font(.caption.bold())
                .foregroundStyle(CheckLineColor.secondary)
            MoneyText(amount: budget.remaining, color: CheckLineColor.success)
            BudgetProgressBar(progress: budget.progress)
        }
        .padding(16)
    }

    private func metric(title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(CheckLineColor.secondary)
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func linkedRow(_ expense: PrototypeExpense, budget: PrototypeBudget) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(currencyText(expense.amount)) · \(expense.title)")
                    Text(linkedBudgetNames(expense))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "link")
                    .foregroundStyle(CheckLineColor.brand)
            }
            Picker("linked.title", selection: choiceBinding(for: expense.id)) {
                Text("linked.decision.all")
                    .tag(PrototypeSettlementChoice.all)
                Text(String(format: String(localized: "linked.decision.current"), budget.name))
                    .tag(PrototypeSettlementChoice.current)
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 4)
    }

    private func completionView(budget: PrototypeBudget, surplus: Decimal) -> some View {
        ScrollView {
            VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(CheckLineColor.success)
            Text("settlement.complete.feedback")
            Text(budget.name)
                .font(.title.bold())
            MoneyText(amount: surplus, color: CheckLineColor.success)
            Text("settlement.complete.message")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
            Button("settlement.back.home") {
                onFinished(.home)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(CheckLineColor.brand)
            .frame(maxWidth: .infinity)

            Button("settlement.view.insights") {
                onFinished(.insights)
                dismiss()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
    }

    private func choice(for expenseID: UUID) -> PrototypeSettlementChoice {
        choices[expenseID] ?? .all
    }

    private func choiceBinding(for expenseID: UUID) -> Binding<PrototypeSettlementChoice> {
        Binding(
            get: { choice(for: expenseID) },
            set: { newValue in
                choices[expenseID] = newValue
                PrototypeHaptics.selection()
            }
        )
    }

    private func linkedBudgetNames(_ expense: PrototypeExpense) -> String {
        let names = expense.budgetIDs.compactMap { store.budget(id: $0)?.name }.joined(separator: " / ")
        return String(format: String(localized: "linked.belongs"), names)
    }

    private func completeSettlement() {
        let surplus = store.completeSettlement(budgetID: budgetID, choices: choices)
        PrototypeHaptics.success()
        withAnimation(.spring(duration: 0.5, bounce: 0.16)) {
            completedSurplus = surplus
        }
    }
}
