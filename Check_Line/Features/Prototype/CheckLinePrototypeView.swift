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
    @State private var toast: PrototypeToast?

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
                    showToast(PrototypeToast(message: title))
                }
            }
            .tabItem { Label("tab.settings", systemImage: "person.crop.circle") }
            .tag(PrototypeAppTab.settings)
        }
        .tint(CheckLineColor.brand)
        .preferredColorScheme(.light)
        .overlay(alignment: .top) {
            if let toast {
                PrototypeToastView(toast: toast)
                .padding(.horizontal, 16)
                .padding(.top, 56)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: toast?.id)
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
                    showToast(PrototypeToast(message: String(localized: "toast.budget.created")))
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)

            case .settlement(let budgetID):
                PrototypeSettlementSheet(store: store, budgetID: budgetID) { destination in
                    selectedTab = destination
                    showToast(PrototypeToast(message: String(localized: "toast.settlement.completed")))
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
        showToast(
            PrototypeToast(
                message: String(format: String(localized: "toast.expense.recorded"), currencyText(draft.amount)),
                actionTitle: String(localized: "action.undo"),
                action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        store.undoExpense(id: expense.id)
                    }
                    showToast(PrototypeToast(message: String(localized: "toast.expense.undone")))
                }
            )
        )
    }

    private func showToast(_ value: PrototypeToast) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            toast = value
        }

        let toastID = value.id
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard toast?.id == toastID else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                toast = nil
            }
        }
    }
}

#Preview("Current iOS Prototype") {
    CheckLinePrototypeView()
}
