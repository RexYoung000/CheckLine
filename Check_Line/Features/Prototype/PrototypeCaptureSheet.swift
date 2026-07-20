import SwiftUI

struct PrototypeCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: PrototypeStore
    let defaultBudgetID: UUID
    let onSave: (PrototypeExpenseDraft) -> Void

    @State private var amountText = "38"
    @State private var selectedBudgetIDs: Set<UUID>
    @State private var selectedCategory = String(localized: "category.transport")
    @State private var note = String(localized: "sample.expense.transit.note")
    @FocusState private var focusedField: Field?

    private enum Field {
        case amount
        case note
    }

    init(store: PrototypeStore, defaultBudgetID: UUID, onSave: @escaping (PrototypeExpenseDraft) -> Void) {
        self.store = store
        self.defaultBudgetID = defaultBudgetID
        self.onSave = onSave
        _selectedBudgetIDs = State(initialValue: [defaultBudgetID])
    }

    private var amount: Decimal? { Decimal(string: amountText) }
    private var canSave: Bool { (amount ?? 0) > 0 && !selectedBudgetIDs.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    amountField
                } header: {
                    Text("capture.amount.title")
                }

                Section("capture.budgets.title") {
                    ForEach(store.activeBudgets) { budget in
                        Button {
                            toggleBudget(budget.id)
                        } label: {
                            Label(
                                budget.name,
                                systemImage: selectedBudgetIDs.contains(budget.id)
                                    ? "checkmark.circle.fill"
                                    : "circle"
                            )
                            .foregroundStyle(
                                selectedBudgetIDs.contains(budget.id)
                                    ? CheckLineColor.brand
                                    : CheckLineColor.text
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("capture.category.title") {
                    Picker("capture.category.title", selection: $selectedCategory) {
                        ForEach(categoryOptions, id: \.name) { option in
                            Label(option.name, systemImage: option.symbol)
                                .tag(option.name)
                        }
                    }
                }

                Section("capture.note.title") {
                    TextField("capture.note.placeholder", text: $note, axis: .vertical)
                        .lineLimit(2 ... 4)
                        .focused($focusedField, equals: .note)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                captureButton
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(CheckLineColor.canvas)
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(CheckLineColor.canvas)
            .navigationTitle(Text("capture.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
            }
            .onAppear { focusedField = .amount }
        }
    }

    private var amountField: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("CNY")
                .font(.subheadline.bold())
                .foregroundStyle(CheckLineColor.brand)
            TextField("0", text: $amountText)
                .font(.system(size: 42, weight: .black, design: .rounded))
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .amount)
                .monospacedDigit()
                .accessibilityLabel(Text("capture.amount.title"))
        }
    }

    private var captureButton: some View {
        Button("capture.confirm") { save() }
            .font(.headline)
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(CheckLineColor.brand, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.45)
    }

    private var categoryOptions: [(name: String, symbol: String, color: Color)] {
        [
            (String(localized: "category.food"), "fork.knife", Color(hex: 0xF97316)),
            (String(localized: "category.transport"), "tram.fill", CheckLineColor.brand),
            (String(localized: "category.social"), "person.2.fill", Color(hex: 0x8B5CF6)),
            (String(localized: "category.study"), "book.fill", Color(hex: 0x14B8A6)),
            (String(localized: "category.other"), "ellipsis", CheckLineColor.quiet)
        ]
    }

    private func toggleBudget(_ id: UUID) {
        if selectedBudgetIDs.contains(id), selectedBudgetIDs.count > 1 {
            selectedBudgetIDs.remove(id)
        } else {
            selectedBudgetIDs.insert(id)
        }
        PrototypeHaptics.selection()
    }

    private func save() {
        guard let amount, amount > 0, !selectedBudgetIDs.isEmpty else { return }
        onSave(
            PrototypeExpenseDraft(
                amount: amount,
                categoryName: selectedCategory,
                budgetIDs: selectedBudgetIDs,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
        dismiss()
    }
}
