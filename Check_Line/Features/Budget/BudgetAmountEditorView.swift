import SwiftUI

struct BudgetAmountEditorView: View {
    @Bindable var workspace: CheckLineWorkspace
    let card: HomeBudgetCardModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var amountText: String
    @State private var preview: BudgetAmountEditPreview?
    @State private var errorText: String?
    @State private var isSaving = false
    @State private var discardRequested = false
    @FocusState private var amountFocused: Bool

    init(workspace: CheckLineWorkspace, card: HomeBudgetCardModel) {
        self.workspace = workspace
        self.card = card
        _amountText = State(initialValue: workspace.budgetAmountDraft(for: card))
    }

    private var isEditable: Bool {
        BudgetAmountEditEngine.isEditable(budgetID: card.id, periodID: card.periodID, ledger: workspace.ledger)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(card.name).font(.title2.weight(.semibold))
                    Text(card.periodStart, format: .dateTime.year().month())
                        .font(.subheadline).foregroundStyle(PaperTheme.muted)
                    Text(String(localized: "wallet.budget.edit.scope"))
                        .font(.subheadline).foregroundStyle(PaperTheme.muted)
                    if let preview {
                        impact(preview)
                    } else {
                        Text(String(localized: "wallet.budget.edit.amount")).font(.headline)
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(card.currencyCode).foregroundStyle(PaperTheme.muted)
                            TextField(String(localized: "wallet.budget.edit.amount"), text: $amountText)
                                .keyboardType(AmountKeyboard.type).focused($amountFocused)
                                .font(.title2.monospacedDigit())
                                .accessibilityIdentifier("wallet.budget.edit.amount")
                        }.padding(16).walletSurface(radius: 18)
                        Text(String(localized: "wallet.budget.edit.inputHint"))
                            .font(.subheadline).foregroundStyle(PaperTheme.muted)
                    }
                    if !isEditable {
                        Text(String(localized: "wallet.budget.edit.unavailable")).foregroundStyle(PaperTheme.gold)
                    }
                    if let errorText {
                        Text(errorText).font(.subheadline).foregroundStyle(PaperTheme.gold)
                            .accessibilityIdentifier("wallet.budget.edit.error")
                    }
                    if workspace.budgetDraftStorageFailed {
                        Text(String(localized: "ui.draft.failed")).font(.subheadline).foregroundStyle(PaperTheme.gold)
                        if !workspace.budgetDraftLoadFailed {
                            Button(String(localized: "ui.draft.retry")) { workspace.retainBudgetAmountDraft(amountText, for: card) }.frame(minHeight: 44)
                        }
                        Button(String(localized: "ui.draft.discard")) { discardRequested = true }.frame(minHeight: 44)
                    }
                }
                .padding(22).frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity)
            }
            .background(PaperTheme.canvas)
            .navigationTitle(String(localized: "wallet.budget.edit.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                        .accessibilityIdentifier("wallet.budget.edit.cancel")
                        .disabled(isSaving)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    if let preview {
                        Button(String(localized: "wallet.budget.edit.save")) { save(preview) }
                            .buttonStyle(PaperSolidButtonStyle()).disabled(isSaving || !isEditable || workspace.budgetDraftStorageFailed)
                            .accessibilityIdentifier("wallet.budget.edit.save")
                        Button(String(localized: "wallet.budget.edit.back")) {
                            self.preview = nil
                            errorText = nil
                        }.frame(minHeight: 44).disabled(isSaving)
                            .accessibilityIdentifier("wallet.budget.edit.back")
                    } else {
                        Button(String(localized: "wallet.budget.edit.preview")) { review() }
                            .buttonStyle(PaperSolidButtonStyle()).disabled(!isEditable || isSaving || workspace.budgetDraftStorageFailed)
                            .accessibilityIdentifier("wallet.budget.edit.preview")
                    }
                }.padding(.horizontal, 22).padding(.vertical, 12)
                    .frame(maxWidth: 640).frame(maxWidth: .infinity).background(PaperTheme.canvas)
            }
            .onChange(of: amountText) { _, text in
                workspace.retainBudgetAmountDraft(text, for: card)
                preview = nil
                errorText = nil
            }
            .onChange(of: workspace.ledger) { _, _ in
                guard preview != nil, !isSaving else { return }
                preview = nil
                errorText = String(localized: "wallet.budget.edit.stale")
            }
        }
        .interactiveDismissDisabled(isSaving)
        .confirmationDialog(String(localized: "ui.draft.discard"), isPresented: $discardRequested) {
            Button(String(localized: "ui.draft.discard"), role: .destructive) {
                workspace.discardBudgetAmountDraft(for: card)
                if !workspace.budgetDraftStorageFailed { amountText = card.snapshot.budgetAmount.description }
            }
        }
    }

    private func impact(_ preview: BudgetAmountEditPreview) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "wallet.budget.edit.preview")).font(.headline)
            row("wallet.budget.edit.oldAmount", preview.previousAmount, preview)
            row("wallet.budget.edit.newAmount", preview.newAmount, preview)
            if preview.previousDefaultAmount != preview.previousAmount {
                row("wallet.budget.edit.oldDefault", preview.previousDefaultAmount, preview)
            }
            row("wallet.budget.edit.newDefault", preview.newAmount, preview)
            Divider()
            row("v1.card.used", preview.snapshotAfter.confirmedSpent, preview)
            row("v1.card.pending", preview.snapshotAfter.pendingAmount, preview)
            row("wallet.budget.edit.remainingBefore", preview.snapshotBefore.remaining - preview.snapshotBefore.pendingAmount, preview)
            row("wallet.budget.edit.remainingAfter", preview.snapshotAfter.remaining - preview.snapshotAfter.pendingAmount, preview)
            if preview.snapshotAfter.certainOverrunAmount > 0 {
                row("wallet.budget.edit.certain", preview.snapshotAfter.certainOverrunAmount, preview)
            }
            if preview.snapshotAfter.possibleOverrunAmount > 0 {
                row("wallet.budget.edit.possible", preview.snapshotAfter.possibleOverrunAmount, preview)
            }
            if preview.snapshotAfter.pendingAmount != 0 {
                Text(String(localized: "wallet.budget.edit.pendingHint")).font(.subheadline).foregroundStyle(PaperTheme.muted)
            }
        }.padding(18).walletSurface(radius: 22)
    }

    private func row(_ key: String, _ value: Decimal, _ preview: BudgetAmountEditPreview) -> some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
        return layout {
            Text(String(localized: String.LocalizationValue(key))).font(.subheadline).foregroundStyle(PaperTheme.muted)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            Text(MoneyFormat.string(value, currencyCode: preview.currencyCode)).font(.subheadline.weight(.medium)).monospacedDigit()
                .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
        }.accessibilityElement(children: .combine)
    }

    private func review() {
        amountFocused = false
        do {
            preview = try workspace.previewBudgetAmount(budgetID: card.id, periodID: card.periodID, amountText: amountText)
            errorText = nil
        } catch LedgerError.unchangedBudgetAmount {
            errorText = String(localized: "wallet.budget.edit.unchanged")
        } catch {
            errorText = String(localized: isEditable ? "wallet.budget.edit.invalid" : "wallet.budget.edit.unavailable")
        }
    }

    private func save(_ preview: BudgetAmountEditPreview) {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try workspace.saveBudgetAmount(preview)
            dismiss()
        } catch LedgerError.staleBudgetAmountPreview {
            self.preview = nil
            errorText = String(localized: "wallet.budget.edit.stale")
        } catch {
            errorText = String(localized: "wallet.budget.edit.failed")
        }
    }
}
