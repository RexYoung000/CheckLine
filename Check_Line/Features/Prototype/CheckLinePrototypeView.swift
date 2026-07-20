import SwiftUI

enum PrototypeAppTab: Hashable {
    case home
    case budgets
    case insights
    case settings
}

private enum PrototypeSheet: Identifiable {
    case capture
    case createBudget
    case settlement(UUID)

    var id: String {
        switch self {
        case .capture: "capture"
        case .createBudget: "create-budget"
        case .settlement(let id): "settlement-\(id)"
        }
    }
}

public struct CheckLinePrototypeView: View {
    @State private var store = PrototypeStore.sample()
    @State private var selectedTab: PrototypeAppTab = .home
    @State private var selectedBudgetID = PrototypeStore.sample().activeBudgets[0].id
    @State private var activeSheet: PrototypeSheet?
    @State private var alert: PrototypeAlert?

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                PrototypeHomeView(
                    store: store,
                    selectedBudgetID: $selectedBudgetID,
                    onShowBudgets: { selectedTab = .budgets },
                    onCapture: { activeSheet = .capture }
                )
            }
            .tabItem { Label("tab.home", systemImage: "house.fill") }
            .tag(PrototypeAppTab.home)

            NavigationStack {
                PrototypeBudgetListView(
                    store: store,
                    selectedBudgetID: $selectedBudgetID,
                    onCreate: { activeSheet = .createBudget },
                    onCapture: { budgetID in
                        selectedBudgetID = budgetID
                        activeSheet = .capture
                    },
                    onSettle: { activeSheet = .settlement($0) }
                )
            }
            .tabItem { Label("tab.budgets", systemImage: "wallet.pass.fill") }
            .tag(PrototypeAppTab.budgets)

            NavigationStack {
                PrototypeInsightsView(
                    store: store,
                    selectedBudgetID: $selectedBudgetID,
                    onCapture: { activeSheet = .capture }
                )
            }
            .tabItem { Label("tab.insights", systemImage: "chart.bar.xaxis") }
            .tag(PrototypeAppTab.insights)

            NavigationStack {
                PrototypeSettingsView(store: store) { title in
                    showAlert(PrototypeAlert(title: title))
                }
            }
            .tabItem { Label("tab.settings", systemImage: "person.crop.circle") }
            .tag(PrototypeAppTab.settings)
        }
        .tint(CheckLineColor.brand)
        .preferredColorScheme(.light)
        .alert(item: $alert) { value in
            if let actionTitle = value.actionTitle {
                return Alert(
                    title: Text(value.title),
                    message: value.message.map(Text.init),
                    primaryButton: .default(Text(actionTitle), action: value.action),
                    secondaryButton: .cancel()
                )
            }
            return Alert(
                title: Text(value.title),
                message: value.message.map(Text.init),
                dismissButton: .default(Text("action.close"))
            )
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .capture:
                PrototypeCaptureSheet(
                    store: store,
                    defaultBudgetID: selectedBudgetID,
                    onSave: handleExpenseCapture
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)

            case .createBudget:
                PrototypeCreateBudgetSheet(store: store) { budgetID in
                    selectedBudgetID = budgetID
                    selectedTab = .home
                    showAlert(PrototypeAlert(title: String(localized: "toast.budget.created")))
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)

            case .settlement(let budgetID):
                PrototypeSettlementSheet(store: store, budgetID: budgetID) { destination in
                    selectedTab = destination
                    showAlert(PrototypeAlert(title: String(localized: "toast.settlement.completed")))
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func handleExpenseCapture(_ draft: PrototypeExpenseDraft) {
        let expense = withAnimation(.easeInOut(duration: 0.3)) {
            store.record(draft)
        }
        PrototypeHaptics.success()
        showAlert(
            PrototypeAlert(
                title: String(format: String(localized: "toast.expense.recorded"), currencyText(draft.amount)),
                actionTitle: String(localized: "action.undo"),
                action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        store.undoExpense(id: expense.id)
                    }
                    showAlert(PrototypeAlert(title: String(localized: "toast.expense.undone")))
                }
            )
        )
    }

    private func showAlert(_ value: PrototypeAlert) {
        alert = value
    }
}

private struct PrototypeAlert: Identifiable {
    let id = UUID()
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?
}

#Preview("Current iOS Prototype") {
    CheckLinePrototypeView()
}
