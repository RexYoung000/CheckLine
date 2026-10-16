import SwiftUI

/// Select local objects; the model never supplies an executable ID.
struct CloudAgentActionsView: View {
    @Bindable var workspace: CheckLineWorkspace
    let candidate: AgentIntentCandidate
    @State private var destination: Destination?
    private enum Destination: Identifiable {
        case budget(UUID), expense(UUID), wish(UUID), records
        var id: String {
            switch self { case .budget(let id): "b" + id.uuidString; case .expense(let id): "e" + id.uuidString
            case .wish(let id): "w" + id.uuidString; case .records: "records" }
        }
    }
    private var operation: String { candidate.requestedIntent ?? candidate.intentType }
    private var expenses: [Expense] {
        workspace.ledger.expenses.values.filter { expense in
            (candidate.merchant.map { (expense.merchant ?? "").localizedCaseInsensitiveContains($0) } ?? true)
                && (candidate.amount.flatMap(MoneyFormat.parseAmount).map { expense.originalAmount == $0 } ?? true)
                && (candidate.currencyCode.map { expense.originalCurrencyCode == $0 } ?? true)
                && (candidate.occurredAt.flatMap { ISO8601DateFormatter().date(from: $0) }.map { Calendar.current.isDate(expense.occurredAt, inSameDayAs: $0) } ?? true)
        }.sorted { $0.occurredAt > $1.occurredAt }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if operation == "deleteExpense" {
                Text(String(localized: "cloud.agent.deleteSelect")).font(.headline)
                if expenses.isEmpty { Text(String(localized: "cloud.agent.noMatchingRecord")).foregroundStyle(PaperTheme.muted) }
                ForEach(Array(expenses.prefix(12))) { expense in
                    Button { destination = .expense(expense.id) } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack { Text(expense.merchant ?? String(localized: "cloud.agent.record")); Spacer()
                                Text(MoneyFormat.string(expense.originalAmount, currencyCode: expense.originalCurrencyCode)) }
                            Text(expense.occurredAt, format: .dateTime.year().month().day()).font(.caption).foregroundStyle(PaperTheme.muted)
                        }.frame(minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            } else if ["settlePeriod", "adjustPeriodAmount", "lateExpense"].contains(operation) {
                ForEach(workspace.cards) { card in
                    Button { destination = .budget(card.id) } label: {
                        HStack { Text(card.name); Spacer(); CheckLineIcon(symbol: "chevron.right", size: 18) }.frame(minHeight: 44)
                    }.buttonStyle(.plain)
                }
            } else if operation == "redeemWish" {
                ForEach(workspace.ledger.wishes.values.filter { $0.state != .completed }.sorted { $0.createdAt < $1.createdAt }) { wish in
                    Button(wish.name) { destination = .wish(wish.id) }.frame(minHeight: 44)
                }
            } else if (workspace.taskDraft.agentRequestText ?? "").range(of: "退款|refund", options: [.regularExpression, .caseInsensitive]) != nil {
                Text(String(localized: "cloud.agent.localActionBody")).font(.subheadline).foregroundStyle(PaperTheme.muted)
            } else {
                Button(String(localized: "cloud.agent.recordAction")) { workspace.resolveCloudOperation(.record) }.frame(minHeight: 44)
                Button(String(localized: "v1.budget.create")) { workspace.resolveCloudOperation(.budget) }.frame(minHeight: 44)
            }
            Button(String(localized: "cloud.agent.viewRecords")) { destination = .records }.frame(minHeight: 44)
            Button(String(localized: "cloud.agent.pause")) { workspace.cloudPendingAction = nil; workspace.leaveTaskReview() }.frame(minHeight: 44)
        }.padding(16).walletSurface()
        .fullScreenCover(item: $destination) { destination in
            NavigationStack {
                Group {
                    switch destination {
                    case .budget(let id): BudgetDetailContent(workspace: workspace, budgetID: id, section: .overview)
                    case .expense(let id): CloudDeleteReview(workspace: workspace, expenseID: id)
                    case .wish(let id): WishDetailView(workspace: workspace, wishID: id)
                    case .records: List {
                        ForEach(workspace.ledger.expenses.values.sorted { $0.occurredAt > $1.occurredAt }) { expense in
                            NavigationLink { WalletExpenseDetail(workspace: workspace, expenseID: expense.id, standalone: false) } label: {
                                VStack(alignment: .leading) {
                                    Text(expense.merchant ?? String(localized: "cloud.agent.record"))
                                    Text(MoneyFormat.string(expense.originalAmount, currencyCode: expense.originalCurrencyCode)).font(.subheadline)
                                }
                            }
                        }
                    }
                    }
                }.toolbar { ToolbarItem(placement: .topBarTrailing) { Button(String(localized: "action.close")) { self.destination = nil } } }
            }
        }
    }
}

private struct CloudDeleteReview: View {
    @Bindable var workspace: CheckLineWorkspace
    let expenseID: UUID
    @State private var reviewed: Ledger?
    @State private var failed = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let reviewed, let expense = reviewed.expenses[expenseID] {
                    Text(MoneyFormat.string(expense.originalAmount, currencyCode: expense.originalCurrencyCode)).font(.largeTitle).monospacedDigit()
                    Text(expense.merchant ?? String(localized: "cloud.agent.record")).font(.title2)
                    Text(expense.occurredAt, format: .dateTime.year().month().day()).foregroundStyle(PaperTheme.muted)
                    if let evaluation = workspace.cloudDeletePreview(expenseID, in: reviewed) {
                        if case .deleteExpense(let snapshot) = evaluation.impact, let snapshot,
                           let periodID = expense.budgetPeriodID, let period = reviewed.periods[periodID] {
                            Text(String(localized: "cloud.agent.remainingAfterDelete"))
                            Text(MoneyFormat.string(snapshot.remaining, currencyCode: period.currencyCode)).font(.title2)
                        }
                        Text(String(localized: "cloud.agent.deleteImpact")).foregroundStyle(PaperTheme.muted)
                        if failed { Text(String(localized: "cloud.agent.staleReview")).foregroundStyle(PaperTheme.accent) }
                        Button(String(localized: "cloud.agent.confirmDelete"), role: .destructive) {
                            if workspace.confirmCloudDelete(expenseID, reviewed: reviewed) { dismiss() } else { failed = true }
                        }.buttonStyle(PaperSolidButtonStyle()).disabled(workspace.ledger != reviewed)
                    } else {
                        Text(String(localized: "cloud.agent.deleteBlocked")).foregroundStyle(PaperTheme.muted)
                        NavigationLink(String(localized: "cloud.agent.viewRecord")) { WalletExpenseDetail(workspace: workspace, expenseID: expenseID, standalone: false) }
                    }
                }
            }.padding(24).frame(maxWidth: 650).frame(maxWidth: .infinity, alignment: .leading)
        }.background(PaperTheme.canvas).navigationTitle(String(localized: "cloud.agent.deleteTitle"))
            .onAppear { if reviewed == nil { reviewed = workspace.ledger } }
    }
}
