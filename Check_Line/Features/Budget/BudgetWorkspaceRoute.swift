import SwiftUI

nonisolated enum BudgetWorkspaceRoute: Hashable {
    case budget(UUID, UUID?, BudgetDetailSection)
    case expense(UUID)
}

private struct BudgetWorkspacePushKey: EnvironmentKey {
    static let defaultValue: ((BudgetWorkspaceRoute) -> Void)? = nil
}
extension EnvironmentValues {
    var budgetWorkspacePush: ((BudgetWorkspaceRoute) -> Void)? {
        get { self[BudgetWorkspacePushKey.self] }
        set { self[BudgetWorkspacePushKey.self] = newValue }
    }
}

struct BudgetWorkspaceDestination: View {
    @Bindable var workspace: CheckLineWorkspace
    let route: BudgetWorkspaceRoute
    var body: some View {
        switch route {
        case .budget(let id, let period, let section):
            BudgetDetailContent(workspace: workspace, budgetID: id, section: section, periodID: period)
        case .expense(let id):
            WalletExpenseDetail(workspace: workspace, expenseID: id, standalone: false)
        }
    }
}
