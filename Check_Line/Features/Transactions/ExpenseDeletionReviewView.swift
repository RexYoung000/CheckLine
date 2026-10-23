import SwiftUI

struct ExpenseDeletionSelection: Identifiable { let id: UUID }

/// Both the row swipe and detail action lead here; neither removes a record on entry.
struct ExpenseDeletionReviewView: View {
    @Bindable var workspace: CheckLineWorkspace
    let expenseID: UUID
    var onDeleted: () -> Void = {}
    @State private var reviewed: Ledger?
    @State private var failed = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let reviewed, let expense = reviewed.expenses[expenseID] {
                        Text(MoneyFormat.string(expense.originalAmount, currencyCode: expense.originalCurrencyCode))
                            .font(.largeTitle.weight(.medium)).monospacedDigit()
                        Text(expense.merchant ?? String(localized: "v1.card.record.untitled")).font(.title3)
                        Text(expense.occurredAt, format: .dateTime.year().month().day()).foregroundStyle(PaperTheme.muted)
                        if let evaluation = workspace.expenseDeletionPreview(expenseID, in: reviewed) {
                            if case .deleteExpense(let snapshot) = evaluation.impact, let snapshot,
                               let periodID = expense.budgetPeriodID, let period = reviewed.periods[periodID] {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(String(localized: "cloud.agent.remainingAfterDelete")).font(.subheadline).foregroundStyle(PaperTheme.muted)
                                    Text(MoneyFormat.string(snapshot.remaining, currencyCode: period.currencyCode)).font(.title2).monospacedDigit()
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(20).walletSurface()
                            }
                            Text(String(localized: "expense.delete.impact")).font(.subheadline).foregroundStyle(PaperTheme.muted)
                            if workspace.ledger != reviewed {
                                Text(String(localized: "cloud.agent.staleReview")).foregroundStyle(PaperTheme.accent)
                                Button(String(localized: "expense.delete.refresh")) { self.reviewed = workspace.ledger; failed = false }
                                    .frame(minHeight: 44).accessibilityIdentifier("expense.delete.refresh")
                            }
                            if failed { Text(String(localized: "wallet.expense.retrySave")).foregroundStyle(PaperTheme.accent) }
                        } else {
                            Text(String(localized: "cloud.agent.deleteBlocked")).foregroundStyle(PaperTheme.muted)
                                .accessibilityIdentifier("expense.delete.blocked")
                        }
                    } else {
                        ContentUnavailableView(String(localized: "ui.record.unavailable"), systemImage: "receipt")
                    }
                }.padding(24).frame(maxWidth: 650, alignment: .leading).frame(maxWidth: .infinity)
            }
            .background(PaperTheme.canvas.ignoresSafeArea())
            .navigationTitle(String(localized: "cloud.agent.deleteTitle")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(String(localized: "action.close")) { dismiss() }.accessibilityIdentifier("expense.delete.close") } }
            .safeAreaInset(edge: .bottom) {
                if let reviewed, workspace.expenseDeletionPreview(expenseID, in: reviewed) != nil {
                    Button(String(localized: "cloud.agent.confirmDelete"), role: .destructive) {
                        do {
                            try workspace.confirmExpenseDeletion(expenseID, reviewed: reviewed)
                            onDeleted(); dismiss()
                        } catch { failed = true }
                    }.buttonStyle(PaperSolidButtonStyle()).disabled(workspace.ledger != reviewed)
                        .accessibilityIdentifier("expense.delete.confirm")
                        .padding(22).background(PaperTheme.canvas)
                }
            }
        }
        .onAppear { if reviewed == nil { reviewed = workspace.ledger } }
        .modifier(NativeDrawerStyle())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "cloud.agent.deleteTitle"))
        .accessibilityIdentifier("expense.delete.review")
    }
}
