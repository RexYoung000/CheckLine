import SwiftUI

struct WalletAgentSheet: View {
    @Bindable var workspace: CheckLineWorkspace
    @Environment(\.dismiss) private var dismiss
    private var discussion: HomeBudgetCardModel? { workspace.cards.first { $0.id == workspace.agentBudgetID } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 16) {
                        WalletSymbol(name: "bubble.left.and.bubble.right", size: 64)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(String(localized: "wallet.agent.heading")).font(.title3.weight(.medium))
                            Text(String(localized: "wallet.agent.localCapability")).font(.caption).foregroundStyle(PaperTheme.muted)
                        }
                    }
                    if let discussion {
                        Label(discussion.name, systemImage: "wallet.pass").font(.subheadline)
                            .padding(.horizontal, 16).padding(.vertical, 12).walletSurface(radius: 18)
                    }
                    if let selected = workspace.selectedCard, selected.id != workspace.agentBudgetID {
                        Button { workspace.agentBudgetID = selected.id } label: {
                            Label(String(localized: "wallet.agent.currentBudget") + " · " + selected.name, systemImage: "arrow.turn.down.right")
                        }.buttonStyle(PaperQuietButtonStyle())
                    }
                    if workspace.banner == nil && workspace.draftText.isEmpty, let discussion {
                        Button {
                            workspace.draftText = discussion.name + " " + String(localized: "wallet.agent.askRemaining")
                            Task { await workspace.submitText() }
                        } label: {
                            Label(String(localized: "wallet.agent.askRemaining"), systemImage: "chart.pie")
                        }.buttonStyle(PaperQuietButtonStyle())
                    }
                    AgentTaskPanel(workspace: workspace, embedded: true) {
                        workspace.composerAfterAgent = .budget
                        dismiss()
                    }
                }.padding(22).frame(maxWidth: 650).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PaperTheme.canvas.ignoresSafeArea())
            .navigationTitle(String(localized: "v1.composer.agent"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(String(localized: "action.close"), systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly) } }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(PaperTheme.canvas)
        .presentationCornerRadius(PaperTheme.Radius.sheet)
        .onAppear { if workspace.agentBudgetID == nil { workspace.agentBudgetID = workspace.selectedCard?.id } }
    }
}
