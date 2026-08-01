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
    @State private var showsVoiceCapture = false
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
                VStack(alignment: .leading, spacing: 24) {
                    amountField

                    CheckLineSurface {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("capture.budgets.title")
                                .font(.headline.weight(.semibold))
                                .padding(.bottom, 10)

                            ForEach(Array(store.activeBudgets.enumerated()), id: \.element.id) { index, budget in
                                Button {
                                    toggleBudget(budget.id)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(
                                            systemName: selectedBudgetIDs.contains(budget.id)
                                                ? "checkmark.circle.fill"
                                                : "circle"
                                        )
                                        .foregroundStyle(
                                            selectedBudgetIDs.contains(budget.id)
                                                ? CheckLineColor.text
                                                : CheckLineColor.quiet
                                        )
                                        Text(budget.name)
                                            .foregroundStyle(CheckLineColor.text)
                                        Spacer()
                                    }
                                    .frame(minHeight: 44)
                                }
                                .buttonStyle(.plain)

                                if index < store.activeBudgets.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }

                    CheckLineSurface {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("capture.category.title")
                                .font(.headline.weight(.semibold))
                            Picker("capture.category.title", selection: $selectedCategory) {
                                ForEach(categoryOptions, id: \.name) { option in
                                    Label(option.name, systemImage: option.symbol)
                                        .tag(option.name)
                                }
                            }
                            .tint(CheckLineColor.text)
                        }
                    }

                    CheckLineSurface {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("capture.note.title")
                                .font(.headline.weight(.semibold))
                            TextField("capture.note.placeholder", text: $note, axis: .vertical)
                                .lineLimit(2 ... 4)
                                .textFieldStyle(.plain)
                                .focused($focusedField, equals: .note)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 108)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                captureButton
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(CheckLineColor.canvas)
            }
            .background(CheckLineColor.canvas.ignoresSafeArea())
            .navigationTitle(Text("capture.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsVoiceCapture = true
                    } label: {
                        Image(systemName: "mic.fill")
                    }
                    .accessibilityLabel(Text("capture.mode.voice"))
                    .accessibilityIdentifier("capture.voiceEntry")
                }
            }
            .onAppear { focusedField = .amount }
            .sheet(isPresented: $showsVoiceCapture) {
                PrototypeVoiceCaptureSheet {
                    showsVoiceCapture = false
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("capture.amount.title")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CheckLineColor.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("currency.cny")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CheckLineColor.secondary)
                TextField("0", text: $amountText)
                    .font(.system(size: 52, weight: .regular, design: .default))
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .amount)
                    .monospacedDigit()
                    .textFieldStyle(.plain)
                    .accessibilityLabel(Text("capture.amount.title"))
            }
        }
        .padding(.horizontal, 4)
    }

    private var captureButton: some View {
        Button("capture.confirm") { save() }
            .buttonStyle(CheckLinePrimaryButtonStyle())
            .frame(maxWidth: .infinity)
            .disabled(!canSave)
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
