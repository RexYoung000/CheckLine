import SwiftUI

struct PrototypeHomeView: View {
    let store: PrototypeStore
    @Binding var selectedBudgetID: UUID
    let onCapture: () -> Void
    let onVoiceCapture: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var amountSize: CGFloat = 64

    @State private var isCaptureMenuExpanded = false

    private var selectedBudget: PrototypeBudget? {
        store.activeBudgets.first { $0.id == selectedBudgetID } ?? store.activeBudgets.first
    }

    var body: some View {
        Group {
            if let selectedBudget {
                budgetContent(selectedBudget)
            } else {
                ContentUnavailableView(
                    "budget.empty.title",
                    systemImage: "wallet.pass",
                    description: Text("budget.empty.message")
                )
            }
        }
        .background(CheckLineColor.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(CheckLineColor.canvas, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onAppear {
            if !store.activeBudgets.contains(where: { $0.id == selectedBudgetID }),
               let first = store.activeBudgets.first {
                selectedBudgetID = first.id
            }
        }
    }

    private func budgetContent(_ budget: PrototypeBudget) -> some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    homeHeader(budget)
                        .padding(.horizontal, 28)

                    budgetHero(budget)
                        .padding(.horizontal, 28)

                    recentRecords(budget)
                        .padding(.horizontal, 16)
                        .padding(.top, 22)
                }
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 132)
            }
            .accessibilityIdentifier("home.scroll")

            if isCaptureMenuExpanded {
                Color.black.opacity(0.025)
                    .contentShape(Rectangle())
                    .onTapGesture { setCaptureMenuExpanded(false) }
                    .accessibilityHidden(true)
            }

            captureLauncher
                .padding(.trailing, 18)
                .padding(.bottom, 14)
        }
    }

    private func homeHeader(_ budget: PrototypeBudget) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text("home.title")
                .font(.title3.weight(.semibold))
                .foregroundStyle(CheckLineColor.text)

            Spacer(minLength: 8)

            budgetMenu(budget)
        }
        .frame(minHeight: 44)
    }

    private func budgetHero(_ budget: PrototypeBudget) -> some View {
        budgetAmount(budget)
            .padding(.top, 36)
            .padding(.bottom, 32)
    }

    private func budgetAmount(_ budget: PrototypeBudget) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    remainingAmount(budget)
                    totalAmount(budget)
                }
            } else {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    remainingAmount(budget)
                    totalAmount(budget)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(
                String(
                    format: String(localized: "home.budget.balance.accessibility"),
                    homeCurrencyText(budget.remaining),
                    homeCurrencyText(budget.total)
                )
            )
        )
    }

    private func remainingAmount(_ budget: PrototypeBudget) -> some View {
        Text(homeCurrencyText(budget.remaining))
            .font(.system(size: amountSize, weight: .regular, design: .default))
            .monospacedDigit()
            .foregroundStyle(CheckLineColor.text)
            .lineLimit(1)
            .minimumScaleFactor(0.68)
            .contentTransition(.numericText(value: decimalDouble(budget.remaining)))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: budget.remaining)
    }

    private func totalAmount(_ budget: PrototypeBudget) -> some View {
        Text(
            String(
                format: String(localized: "home.budget.total.inline"),
                homeCurrencyText(budget.total)
            )
        )
        .font(.footnote.weight(.medium))
        .monospacedDigit()
        .foregroundStyle(CheckLineColor.quiet)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func budgetMenu(_ budget: PrototypeBudget) -> some View {
        Menu {
            ForEach(store.activeBudgets) { candidate in
                Button {
                    selectBudget(candidate.id)
                } label: {
                    if candidate.id == selectedBudgetID {
                        Label(candidate.name, systemImage: "checkmark")
                    } else {
                        Text(candidate.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 7) {
                Text(budget.name)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(CheckLineColor.text)
            .padding(.horizontal, 13)
            .frame(minHeight: 36)
            .background(CheckLineColor.muted, in: Capsule())
        }
        .fixedSize(horizontal: true, vertical: false)
        .buttonStyle(.plain)
        .accessibilityLabel(Text("home.budget.switch"))
        .accessibilityValue(Text(budget.name))
        .accessibilityIdentifier("home.budgetSelector")
    }

    private func recentRecords(_ budget: PrototypeBudget) -> some View {
        let recordLimit = dynamicTypeSize.isAccessibilitySize ? 3 : 5
        let expenses = Array(store.expenses(for: budget.id).prefix(recordLimit))

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("expense.recent.title")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(CheckLineColor.text)

                Spacer(minLength: 8)

                Text(homeCurrencyText(-budget.spent))
                    .font(.headline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(CheckLineColor.text)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityLabel(Text("home.budget.spent.accessibility"))
                    .accessibilityValue(Text(homeCurrencyText(budget.spent)))
            }
            .padding(.bottom, 20)

            if expenses.isEmpty {
                Text("expense.empty")
                    .font(.subheadline)
                    .foregroundStyle(CheckLineColor.secondary)
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            } else {
                VStack(spacing: 18) {
                    ForEach(expenses) { expense in
                        PrototypeHomeExpenseRow(
                            expense: expense,
                            iconName: iconName(for: expense, in: budget)
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(CheckLineColor.card)
        )
        .shadow(color: .black.opacity(0.035), radius: 22, x: 0, y: 10)
    }

    private var captureLauncher: some View {
        ZStack(alignment: .bottomTrailing) {
            if isCaptureMenuExpanded {
                launcherAction(
                    title: "capture.mode.text",
                    systemImage: "square.and.pencil",
                    expandedOffset: CGSize(width: -92, height: -8),
                    animationDelay: 0,
                    accessibilityPriority: 3,
                    action: activateManualCapture
                )

                launcherAction(
                    title: "capture.mode.voice",
                    systemImage: "mic.fill",
                    expandedOffset: CGSize(width: -64, height: -66),
                    animationDelay: 0.035,
                    accessibilityPriority: 2,
                    action: activateVoiceCapture
                )
            }

            Button(action: activateLauncherButton) {
                Image(
                    systemName: reduceMotion && isCaptureMenuExpanded
                        ? "xmark"
                        : "plus"
                )
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(CheckLineColor.text, in: Circle())
                    .rotationEffect(
                        .degrees(!reduceMotion && isCaptureMenuExpanded ? 45 : 0)
                    )
                    .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)
            }
            .buttonStyle(PrototypeCaptureLauncherButtonStyle())
            .accessibilityLabel(
                isCaptureMenuExpanded
                    ? Text("capture.launcher.close")
                    : Text("capture.add.accessibility")
            )
            .accessibilityHint(
                isCaptureMenuExpanded
                    ? Text("")
                    : Text("capture.launcher.hint")
            )
            .accessibilityValue(
                isCaptureMenuExpanded
                    ? Text("capture.launcher.expanded")
                    : Text("")
            )
            .accessibilitySortPriority(1)
            .accessibilityIdentifier("home.captureLauncher")
        }
        .frame(width: 190, height: 190, alignment: .bottomTrailing)
    }

    private func launcherAction(
        title: LocalizedStringKey,
        systemImage: String,
        expandedOffset: CGSize,
        animationDelay: Double,
        accessibilityPriority: Double,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(CheckLineColor.text)
                    .frame(width: 52, height: 52)
                    .background(CheckLineColor.card, in: Circle())
                    .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)

                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(CheckLineColor.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 64)
        }
        .buttonStyle(.plain)
        .offset(expandedOffset)
        .accessibilitySortPriority(accessibilityPriority)
        .transition(
            reduceMotion
                ? .opacity
                : .offset(x: -expandedOffset.width, y: -expandedOffset.height)
                    .combined(with: .scale(scale: 0.62, anchor: .bottomTrailing))
                    .combined(with: .opacity)
        )
        .transaction { transaction in
            if !reduceMotion, animationDelay > 0 {
                transaction.animation = transaction.animation?.delay(animationDelay)
            }
        }
    }

    private func iconName(for expense: PrototypeExpense, in budget: PrototypeBudget) -> String {
        budget.categories.first { $0.name == expense.categoryName }?.iconName ?? "receipt"
    }

    private func selectBudget(_ id: UUID) {
        guard id != selectedBudgetID else { return }
        if reduceMotion {
            selectedBudgetID = id
        } else {
            withAnimation(.easeInOut(duration: 0.22)) {
                selectedBudgetID = id
            }
        }
        PrototypeHaptics.selection()
    }

    private func activateLauncherButton() {
        setCaptureMenuExpanded(!isCaptureMenuExpanded)
        PrototypeHaptics.selection()
    }

    private func activateManualCapture() {
        setCaptureMenuExpanded(false)
        onCapture()
    }

    private func activateVoiceCapture() {
        setCaptureMenuExpanded(false)
        onVoiceCapture()
    }

    private func setCaptureMenuExpanded(_ expanded: Bool) {
        withAnimation(
            reduceMotion
                ? .easeOut(duration: 0.14)
                : .spring(response: 0.3, dampingFraction: 0.76)
        ) {
            isCaptureMenuExpanded = expanded
        }
    }
}

private struct PrototypeCaptureLauncherButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.92 : 1)
            .opacity(reduceMotion && configuration.isPressed ? 0.72 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct PrototypeHomeExpenseRow: View {
    let expense: PrototypeExpense
    let iconName: String

    private var metadata: String {
        String(
            format: String(localized: "home.expense.metadata"),
            expense.categoryName,
            expense.occurredAt.formatted(
                .dateTime
                    .month(.defaultDigits)
                    .day()
            )
        )
    }

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: iconName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(CheckLineColor.text)
                .frame(width: 42, height: 42)
                .background(CheckLineColor.muted, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(expense.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CheckLineColor.text)
                    .lineLimit(1)

                Text(metadata)
                    .font(.caption)
                    .foregroundStyle(CheckLineColor.quiet)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(homeCurrencyText(-expense.amount))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(CheckLineColor.text)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(
                String(
                    format: String(localized: "home.expense.accessibility"),
                    expense.title,
                    metadata,
                    currencyText(expense.amount)
                )
            )
        )
    }
}

private func homeCurrencyText(_ amount: Decimal) -> String {
    amount.formatted(
        .currency(code: "CNY")
        .presentation(.narrow)
        .precision(.fractionLength(0))
    )
}

struct PrototypeCategoryRow: View {
    let category: PrototypeCategory

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.iconName)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(categoryColor(category), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(category.name)
                    .font(.body.weight(.semibold))
                Text("\(String(localized: "budget.used")) \(currencyText(category.spent)) / \(currencyText(category.limit))")
                    .font(.caption)
                    .foregroundStyle(CheckLineColor.secondary)
            }

            Spacer(minLength: 8)
            Text(currencyText(max(0, category.limit - category.spent)))
                .font(.body.weight(.semibold).monospacedDigit())
                .foregroundStyle(CheckLineColor.text)
        }
        .padding(.vertical, 8)
    }
}

struct PrototypeExpenseRow: View {
    let expense: PrototypeExpense
    let store: PrototypeStore

    private var budgetNames: String {
        expense.budgetIDs.compactMap { store.budget(id: $0)?.name }.joined(separator: " / ")
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "receipt")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CheckLineColor.brand)
                .frame(width: 32, height: 32)
                .background(CheckLineColor.brandSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text("\(expense.occurredAt.formatted(.dateTime.month(.defaultDigits).day())) · \(budgetNames)")
                    .font(.caption)
                    .foregroundStyle(CheckLineColor.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
            Text("−\(currencyText(expense.amount))")
                .font(.body.weight(.semibold).monospacedDigit())
                .foregroundStyle(CheckLineColor.text)
        }
        .padding(.vertical, 8)
    }
}
