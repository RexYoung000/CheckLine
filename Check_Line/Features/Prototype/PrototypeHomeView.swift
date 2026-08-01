import SwiftUI

private enum PrototypeHomePalette {
    static let canvas = Color(hex: 0xF8F8F5)
    static let surface = Color.white
    static let control = Color(hex: 0xF0F0EC)
    static let ink = Color(hex: 0x1B1B1A)
    static let secondary = Color(hex: 0x74746E)
    static let quiet = Color(hex: 0x9A9A94)
}

private enum PrototypeCaptureLauncherState {
    case collapsed
    case peeking
    case expanded
}

struct PrototypeHomeView: View {
    let store: PrototypeStore
    @Binding var selectedBudgetID: UUID
    let onCapture: () -> Void
    let onVoiceCapture: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var amountSize: CGFloat = 64

    @State private var launcherState = PrototypeCaptureLauncherState.collapsed
    @State private var didRecognizeLongPress = false
    @State private var hasShownLauncherHint = false

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
        .background(PrototypeHomePalette.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(PrototypeHomePalette.canvas, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onAppear {
            if !store.activeBudgets.contains(where: { $0.id == selectedBudgetID }),
               let first = store.activeBudgets.first {
                selectedBudgetID = first.id
            }
        }
        .task { await showLauncherHintOnce() }
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

            if launcherState == .expanded {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { setLauncherState(.collapsed) }
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
                .foregroundStyle(PrototypeHomePalette.ink)

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
            .foregroundStyle(PrototypeHomePalette.ink)
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
        .foregroundStyle(PrototypeHomePalette.quiet)
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
            .foregroundStyle(PrototypeHomePalette.ink)
            .padding(.horizontal, 13)
            .frame(minHeight: 36)
            .background(PrototypeHomePalette.control, in: Capsule())
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
                    .foregroundStyle(PrototypeHomePalette.ink)

                Spacer(minLength: 8)

                Text(homeCurrencyText(-budget.spent))
                    .font(.headline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(PrototypeHomePalette.ink)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityLabel(Text("home.budget.spent.accessibility"))
                    .accessibilityValue(Text(homeCurrencyText(budget.spent)))
            }
            .padding(.bottom, 20)

            if expenses.isEmpty {
                Text("expense.empty")
                    .font(.subheadline)
                    .foregroundStyle(PrototypeHomePalette.secondary)
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
                .fill(PrototypeHomePalette.surface)
        )
        .shadow(color: .black.opacity(0.035), radius: 22, x: 0, y: 10)
    }

    private var captureLauncher: some View {
        ZStack(alignment: .bottomTrailing) {
            if launcherState != .collapsed {
                launcherAction(
                    title: "capture.mode.manual",
                    systemImage: "square.and.pencil",
                    expandedOffset: CGSize(width: -92, height: -38),
                    action: activateManualCapture
                )

                launcherAction(
                    title: "capture.mode.voice",
                    systemImage: "mic.fill",
                    expandedOffset: CGSize(width: -150, height: -66),
                    action: activateVoiceCapture
                )
            }

            Button(action: activateLauncherButton) {
                Image(
                    systemName: reduceMotion && launcherState == .expanded
                        ? "xmark"
                        : "plus"
                )
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(PrototypeHomePalette.ink, in: Circle())
                    .rotationEffect(
                        .degrees(!reduceMotion && launcherState == .expanded ? 45 : 0)
                    )
                    .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)
            }
            .buttonStyle(PrototypeCaptureLauncherButtonStyle())
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.35, maximumDistance: 44)
                    .onEnded { _ in
                        didRecognizeLongPress = true
                        setLauncherState(.expanded)
                        PrototypeHaptics.selection()
                    }
            )
            .accessibilityLabel(Text("capture.add.accessibility"))
            .accessibilityHint(Text("capture.launcher.hint"))
            .accessibilityValue(
                launcherState == .expanded
                    ? Text("capture.launcher.expanded")
                    : Text("")
            )
            .accessibilityAction(named: Text("capture.mode.manual")) {
                activateManualCapture()
            }
            .accessibilityAction(named: Text("capture.mode.voice")) {
                activateVoiceCapture()
            }
            .accessibilityIdentifier("home.captureLauncher")
        }
        .frame(width: 190, height: 190, alignment: .bottomTrailing)
    }

    private func launcherAction(
        title: LocalizedStringKey,
        systemImage: String,
        expandedOffset: CGSize,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PrototypeHomePalette.ink)
                    .frame(width: 52, height: 52)
                    .background(PrototypeHomePalette.surface, in: Circle())
                    .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)

                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(PrototypeHomePalette.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .opacity(launcherState == .expanded ? 1 : 0)
            }
            .frame(width: 64)
        }
        .buttonStyle(.plain)
        .offset(launcherOffset(expanded: expandedOffset))
        .scaleEffect(launcherState == .peeking ? 0.82 : 1)
        .opacity(launcherState == .peeking ? 0.72 : 1)
        .allowsHitTesting(launcherState == .expanded)
        .accessibilityHidden(launcherState != .expanded)
        .transition(
            reduceMotion
                ? .opacity
                : .offset(x: -expandedOffset.width, y: -expandedOffset.height)
                    .combined(with: .opacity)
        )
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

    private func launcherOffset(expanded: CGSize) -> CGSize {
        if reduceMotion || launcherState == .expanded {
            return expanded
        }
        if launcherState == .peeking {
            return CGSize(width: expanded.width * 0.66, height: expanded.height * 0.66)
        }
        return .zero
    }

    private func activateLauncherButton() {
        if didRecognizeLongPress {
            didRecognizeLongPress = false
            return
        }

        if launcherState == .expanded {
            setLauncherState(.collapsed)
        } else {
            activateManualCapture()
        }
    }

    private func activateManualCapture() {
        setLauncherState(.collapsed)
        onCapture()
    }

    private func activateVoiceCapture() {
        setLauncherState(.collapsed)
        onVoiceCapture()
    }

    private func setLauncherState(_ state: PrototypeCaptureLauncherState) {
        withAnimation(
            reduceMotion
                ? .easeOut(duration: 0.18)
                : .spring(response: 0.34, dampingFraction: 0.78)
        ) {
            launcherState = state
        }
    }

    @MainActor
    private func showLauncherHintOnce() async {
        guard !hasShownLauncherHint else { return }
        hasShownLauncherHint = true
        try? await Task.sleep(for: .milliseconds(700))
        guard !Task.isCancelled, launcherState == .collapsed else { return }

        setLauncherState(.peeking)
        try? await Task.sleep(for: .milliseconds(720))
        guard !Task.isCancelled, launcherState == .peeking else { return }
        setLauncherState(.collapsed)
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
                .foregroundStyle(PrototypeHomePalette.ink)
                .frame(width: 42, height: 42)
                .background(PrototypeHomePalette.control, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(expense.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PrototypeHomePalette.ink)
                    .lineLimit(1)

                Text(metadata)
                    .font(.caption)
                    .foregroundStyle(PrototypeHomePalette.quiet)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(homeCurrencyText(-expense.amount))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(PrototypeHomePalette.ink)
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
