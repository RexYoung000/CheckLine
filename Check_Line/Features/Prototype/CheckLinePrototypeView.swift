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
    @State private var toastDismissTask: Task<Void, Never>?

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    PrototypeHomeView(
                        store: store,
                        selectedBudgetID: $selectedBudgetID,
                        onShowBudgets: { selectedTab = .budgets }
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
                    PrototypeInsightsView(store: store, selectedBudgetID: $selectedBudgetID)
                }
                .tabItem { Label("tab.insights", systemImage: "chart.bar.xaxis") }
                .tag(PrototypeAppTab.insights)

                NavigationStack {
                    PrototypeSettingsView(store: store) { title in
                        showToast(PrototypeToast(title: title, symbolName: "info.circle.fill"))
                    }
                }
                .tabItem { Label("tab.settings", systemImage: "person.crop.circle") }
                .tag(PrototypeAppTab.settings)
            }
            .tint(CheckLineColor.brand)

            if selectedTab != .settings {
                Button {
                    activeSheet = .capture
                    PrototypeHaptics.selection()
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundStyle(Color.white)
                        .frame(width: 58, height: 58)
                        .background(CheckLineColor.brand, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
                        .shadow(color: CheckLineColor.brand.opacity(0.3), radius: 16, y: 8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("capture.add.accessibility"))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 20)
                .padding(.bottom, 62)
            }

            if let toast {
                PrototypeToastView(toast: toast)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 72)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .preferredColorScheme(.light)
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
                    showToast(PrototypeToast(title: String(localized: "toast.budget.created"), symbolName: "checkmark.circle.fill"))
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)

            case .settlement(let budgetID):
                PrototypeSettlementSheet(store: store, budgetID: budgetID) { destination in
                    selectedTab = destination
                    showToast(PrototypeToast(title: String(localized: "toast.settlement.completed"), symbolName: "checkmark.seal.fill"))
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
                title: String(format: String(localized: "toast.expense.recorded"), currencyText(draft.amount)),
                symbolName: "checkmark.circle.fill",
                actionTitle: String(localized: "action.undo"),
                action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        store.undoExpense(id: expense.id)
                    }
                    showToast(PrototypeToast(title: String(localized: "toast.expense.undone"), symbolName: "arrow.uturn.backward.circle.fill"))
                }
            )
        )
    }

    private func showToast(_ value: PrototypeToast) {
        toastDismissTask?.cancel()
        withAnimation(.spring(duration: 0.32, bounce: 0.12)) {
            toast = value
        }
        toastDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(value.actionTitle == nil ? 2 : 4.2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                toast = nil
            }
        }
    }
}

#Preview("Current iOS Prototype") {
    CheckLinePrototypeView()
}
