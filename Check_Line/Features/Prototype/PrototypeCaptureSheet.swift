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
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    amountField
                    budgetSelection
                    categorySelection
                    noteField
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                captureButton
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(CheckLineColor.canvas)
            }
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
        VStack(alignment: .leading, spacing: 8) {
            Text("capture.amount.title")
                .font(.caption.bold())
                .foregroundStyle(CheckLineColor.secondary)
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
            .padding(16)
            .prototypeCard()
        }
    }

    private var budgetSelection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("capture.budgets.title")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.activeBudgets) { budget in
                        PrototypeChip(
                            title: budget.name,
                            symbol: "wallet.pass",
                            isSelected: selectedBudgetIDs.contains(budget.id)
                        ) {
                            toggleBudget(budget.id)
                        }
                    }
                }
            }
        }
    }

    private var categorySelection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("capture.category.title")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 98), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(categoryOptions, id: \.name) { option in
                    PrototypeChip(
                        title: option.name,
                        symbol: option.symbol,
                        isSelected: selectedCategory == option.name,
                        tint: option.color
                    ) {
                        selectedCategory = option.name
                        PrototypeHaptics.selection()
                    }
                }
            }
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("capture.note.title")
                .font(.headline)
            TextField("capture.note.placeholder", text: $note, axis: .vertical)
                .lineLimit(2 ... 4)
                .focused($focusedField, equals: .note)
                .padding(14)
                .prototypeCard(radius: 14)
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
