import SwiftUI

struct WalletAgentSheet: View {
    @Bindable var workspace: CheckLineWorkspace
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var detent: PresentationDetent = .height(330)
    private var discussion: HomeBudgetCardModel? { workspace.cards.first { $0.id == workspace.agentBudgetID } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    mascotHeader
                    if let discussion {
                        Label(discussion.name, systemImage: "wallet.pass").font(.subheadline)
                            .padding(.horizontal, 16).padding(.vertical, 12).walletSurface(radius: 18)
                    }
                    if let selected = workspace.selectedCard, selected.id != workspace.agentBudgetID {
                        Button { workspace.discussBudget(selected.id) } label: {
                            Label(String(localized: "wallet.agent.currentBudget") + " · " + selected.name, systemImage: "arrow.turn.down.right")
                        }.buttonStyle(PaperQuietButtonStyle())
                    }
                    if workspace.agentBanner == nil && workspace.draftText.isEmpty, let discussion {
                        Button {
                            workspace.draftText = discussion.name + " " + String(localized: "wallet.agent.askRemaining")
                            Task { await workspace.submitText() }
                        } label: {
                            Label(String(localized: "wallet.agent.askRemaining"), systemImage: "chart.pie")
                        }.buttonStyle(PaperQuietButtonStyle())
                    }
                    AgentTaskPanel(workspace: workspace, embedded: true, part: .content) {
                        workspace.composerAfterAgent = .budget
                        workspace.composerPrefillFromAgent = true
                        dismiss()
                    }
                }.padding(.horizontal, 22).padding(.top, 10).frame(maxWidth: 650).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PaperTheme.canvas.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                AgentTaskPanel(workspace: workspace, embedded: true, part: .footer)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 8)
                    .frame(maxWidth: 650)
                    .frame(maxWidth: .infinity)
                    .background(PaperTheme.card)
            }
            .navigationTitle(String(localized: "wallet.mascot.name"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        workspace.composerAfterAgent = workspace.isEmpty || workspace.budgetProposal != nil ? .budget : .record
                        workspace.composerPrefillFromAgent = true
                        dismiss()
                    } label: { Image(systemName: "square.and.pencil") }
                    .accessibilityLabel(String(localized: workspace.isEmpty || workspace.budgetProposal != nil ? "wallet.empty.manual" : "capture.title"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "action.close"), systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly).accessibilityIdentifier("wallet.agent.close")
                }
            }
        }
        .presentationDetents([.height(330), .medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationBackground(PaperTheme.canvas)
        .tint(PaperTheme.accent)
        .presentationCornerRadius(PaperTheme.Radius.sheet)
        .onAppear { if workspace.agentBudgetID == nil { workspace.agentBudgetID = workspace.selectedCard?.id } }
        .onChange(of: workspace.showsStructuredConfirm, initial: true) { _, confirms in
            if confirms { detent = .large }
        }
    }

    private var mascotHeader: some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            CloudMascotView(state: workspace.mascotState)
                .frame(width: 70, height: 66)
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "wallet.agent.heading")).font(.headline)
                Text(workspace.mascotState.label).font(.subheadline)
                    .accessibilityIdentifier("wallet.mascot.status")
            }
        }
    }
}
