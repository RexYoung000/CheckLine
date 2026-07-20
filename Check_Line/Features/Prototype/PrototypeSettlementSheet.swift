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
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 20) {
                settlementSummary(budget)

                PrototypeSectionHeader("linked.title")
                if linkedExpenses.isEmpty {
                    Text("settlement.linked.empty")
                        .font(.subheadline)
                        .foregroundStyle(CheckLineColor.secondary)
                        .frame(maxWidth: .infinity, minHeight: 74)
                        .prototypeCard()
                } else {
                    linkedList(budget)
                }

                if budget.status == .active {
                    Text("settlement.preview.message")
                        .font(.footnote)
                        .foregroundStyle(CheckLineColor.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(CheckLineColor.brandSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Button("settlement.return") { dismiss() }
                        .font(.headline)
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(CheckLineColor.brand, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                } else {
                    Button("settlement.complete") { completeSettlement() }
                        .font(.headline)
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(CheckLineColor.brand, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
            }
            .padding(20)
            .padding(.bottom, 24)
        }
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
        .prototypeCard()
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

    private func linkedList(_ budget: PrototypeBudget) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(linkedExpenses.enumerated()), id: \.element.id) { index, expense in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Image(systemName: "link")
                            .foregroundStyle(CheckLineColor.brand)
                            .frame(width: 42, height: 42)
                            .background(CheckLineColor.brandSoft, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(currencyText(expense.amount)) · \(expense.title)")
                                .font(.subheadline.bold())
                            Text(linkedBudgetNames(expense))
                                .font(.caption)
                                .foregroundStyle(CheckLineColor.secondary)
                        }
                    }
                    HStack(spacing: 8) {
                        PrototypeChip(
                            title: String(localized: "linked.decision.all"),
                            isSelected: choice(for: expense.id) == .all
                        ) {
                            choices[expense.id] = .all
                            PrototypeHaptics.selection()
                        }
                        PrototypeChip(
                            title: String(format: String(localized: "linked.decision.current"), budget.name),
                            isSelected: choice(for: expense.id) == .current
                        ) {
                            choices[expense.id] = .current
                            PrototypeHaptics.selection()
                        }
                    }
                }
                .padding(14)
                if index < linkedExpenses.count - 1 { Divider() }
            }
        }
        .prototypeCard()
    }

    private func completionView(budget: PrototypeBudget, surplus: Decimal) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(CheckLineColor.success)
                .frame(width: 72, height: 72)
                .background(CheckLineColor.success.opacity(0.14), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            Text("settlement.complete.feedback")
                .font(.caption.bold())
                .foregroundStyle(CheckLineColor.secondary)
            Text(budget.name)
                .font(.title.bold())
            MoneyText(amount: surplus, color: CheckLineColor.success)
            Text("settlement.complete.message")
                .font(.subheadline)
                .foregroundStyle(CheckLineColor.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
            Button("settlement.back.home") {
                onFinished(.home)
                dismiss()
            }
            .font(.headline)
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(CheckLineColor.brand, in: RoundedRectangle(cornerRadius: 15, style: .continuous))

            Button("settlement.view.insights") {
                onFinished(.insights)
                dismiss()
            }
            .font(.headline)
            .foregroundStyle(CheckLineColor.brand)
            .frame(maxWidth: .infinity, minHeight: 50)
        }
        .padding(20)
    }

    private func choice(for expenseID: UUID) -> PrototypeSettlementChoice {
        choices[expenseID] ?? .all
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
