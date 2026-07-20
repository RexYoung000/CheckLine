import SwiftUI

public struct CheckLinePrototypeView: View {
    @State private var prototype = PrototypeState.sample
    @State private var selectedBudgetID = PrototypeState.sample.budgets[0].id
    @State private var isCapturePresented = false
    @State private var isSettlementPresented = false
    @State private var toast: PrototypeToast?

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            CheckLineColor.canvas.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    HomeHeader()

                    BudgetCarousel(
                        budgets: prototype.budgets,
                        selectedBudgetID: selectedBudgetID,
                        onSelect: { selectedBudgetID = $0 }
                    )

                    PrimaryActionPanel(
                        onCapture: { isCapturePresented = true },
                        onSettle: { isSettlementPresented = true }
                    )

                    WishSection(wishes: prototype.wishes)

                    RecentExpenseSection(expenses: prototype.recentExpenses)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 112)
            }

            BottomNavigationBar(onCapture: { isCapturePresented = true })

            if let toast {
                ToastView(toast: toast)
                    .padding(.bottom, 96)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(5)
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $isCapturePresented) {
            CaptureSheet(
                budgets: prototype.budgets,
                defaultBudgetID: selectedBudgetID,
                onConfirm: handleExpenseCapture
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isSettlementPresented) {
            SettlementChecklistView(
                budget: prototype.budget(id: selectedBudgetID) ?? prototype.budgets[0],
                wishes: prototype.wishes,
                onComplete: handleSettlement
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private func handleExpenseCapture(_ draft: ExpenseDraft) {
        isCapturePresented = false

        withAnimation(.spring(duration: 0.45, bounce: 0.18)) {
            prototype.recordExpense(draft)
        }

        let names = prototype.budgets
            .filter { draft.budgetIDs.contains($0.id) }
            .map(\.name)
            .joined(separator: " / ")

        showToast(
            PrototypeToast(
                title: "扣血完成",
                message: "\(names) · -\(draft.amount.formatted(.currency(code: "CNY")))",
                symbolName: "waveform.path.ecg",
                tint: CheckLineColor.danger
            )
        )
    }

    private func handleSettlement(_ result: SettlementResult) {
        isSettlementPresented = false

        withAnimation(.spring(duration: 0.65, bounce: 0.2)) {
            prototype.applySettlement(result)
        }

        showToast(
            PrototypeToast(
                title: "结算完成",
                message: "离心愿近了 \(result.totalAllocated.formatted(.currency(code: "CNY")))",
                symbolName: "sparkles",
                tint: CheckLineColor.gold
            )
        )
    }

    private func showToast(_ value: PrototypeToast) {
        withAnimation(.spring(duration: 0.32, bounce: 0.12)) {
            toast = value
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeInOut(duration: 0.2)) {
                toast = nil
            }
        }
    }
}

private struct HomeHeader: View {
    var body: some View {
        ZStack {
            VStack(spacing: 1) {
                Text("今天")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CheckLineColor.secondaryText.opacity(0.75))
                Text("预算线")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(CheckLineColor.primary)
            }

            HStack {
                Text("线内自由")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CheckLineColor.secondaryText)

                Spacer()

                Button {} label: {
                    Image(systemName: "bell")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .foregroundStyle(CheckLineColor.primaryText)
                        .background(.white, in: Circle())
                        .shadow(color: .black.opacity(0.04), radius: 12, y: 5)
                }
                .accessibilityLabel("通知")
            }
        }
        .frame(height: 50)
    }
}

private struct SectionTitle: View {
    let title: String
    var actionTitle: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
                .foregroundStyle(CheckLineColor.primaryText)

            Spacer()

            if let actionTitle {
                Button(actionTitle) {}
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CheckLineColor.primary)
            }
        }
    }
}

private struct BudgetCarousel: View {
    let budgets: [BudgetDisplay]
    let selectedBudgetID: UUID
    let onSelect: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "当前预算", actionTitle: "全部")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(budgets) { budget in
                        BudgetCard(
                            budget: budget,
                            isSelected: budget.id == selectedBudgetID
                        ) {
                            onSelect(budget.id)
                        }
                    }

                    AddBudgetCard()
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }
}

private struct BudgetCard: View {
    let budget: BudgetDisplay
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(budget.name)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(CheckLineColor.primaryText)
                            .lineLimit(1)
                        Text(budget.cycleLabel)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(CheckLineColor.secondaryText)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("还能花")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(CheckLineColor.secondaryText)
                        Text(budget.remaining, format: .currency(code: budget.currencyCode))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(budget.tint)
                            .minimumScaleFactor(0.62)
                            .lineLimit(1)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("预算线")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(CheckLineColor.secondaryText)
                        Spacer()
                        Text(budget.progress, format: .percent.precision(.fractionLength(0)))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(budget.tint)
                    }

                    Capsule()
                        .fill(CheckLineColor.track)
                        .frame(height: 7)
                        .overlay(alignment: .leading) {
                            GeometryReader { proxy in
                                Capsule()
                                    .fill(budget.tint)
                                    .frame(width: max(10, proxy.size.width * budget.progress))
                            }
                        }
                }

                HStack(spacing: 10) {
                    ForEach(budget.categorySummaries, id: \.title) { summary in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(summary.title)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(CheckLineColor.secondaryText)
                            Text(summary.amount)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(CheckLineColor.primaryText)
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .background(CheckLineColor.canvas, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(18)
            .frame(width: 322, height: 204)
            .background(.white, in: RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(isSelected ? CheckLineColor.primary.opacity(0.35) : CheckLineColor.stroke, lineWidth: 1)
            )
            .shadow(color: .black.opacity(isSelected ? 0.08 : 0.045), radius: isSelected ? 22 : 14, y: isSelected ? 12 : 8)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

private struct AddBudgetCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.title3.weight(.bold))
                .frame(width: 52, height: 52)
                .foregroundStyle(CheckLineColor.secondaryText)
                .background(CheckLineColor.track, in: Circle())
            Text("新建预算")
                .font(.headline.weight(.bold))
                .foregroundStyle(CheckLineColor.secondaryText)
        }
        .frame(width: 156, height: 204)
        .background(CheckLineColor.canvas, in: RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(CheckLineColor.stroke, style: StrokeStyle(lineWidth: 1.5, dash: [7, 7]))
        )
    }
}

private struct PrimaryActionPanel: View {
    let onCapture: () -> Void
    let onSettle: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            RoundActionButton(title: "结算", symbolName: "receipt", tint: CheckLineColor.gold, size: 56, action: onSettle)

            RoundActionButton(title: "记一笔", symbolName: "plus", tint: CheckLineColor.primary, size: 78, isPrimary: true, action: onCapture)

            RoundActionButton(title: "心愿", symbolName: "sparkles", tint: CheckLineColor.success, size: 56, action: {})
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

private struct RoundActionButton: View {
    let title: String
    let symbolName: String
    let tint: Color
    let size: CGFloat
    var isPrimary = false
    let action: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: action) {
                Image(systemName: symbolName)
                    .font(isPrimary ? .title.weight(.bold) : .title3.weight(.semibold))
                    .frame(width: size, height: size)
                    .foregroundStyle(isPrimary ? .white : tint)
                    .background(isPrimary ? tint : CheckLineColor.cardMuted, in: Circle())
                    .shadow(color: isPrimary ? tint.opacity(0.24) : .clear, radius: 16, y: 9)
            }
            .buttonStyle(.plain)

            Text(title)
                .font(.caption.weight(isPrimary ? .bold : .semibold))
                .foregroundStyle(CheckLineColor.primaryText)
        }
        .frame(width: 82)
    }
}

private struct WishSection: View {
    let wishes: [WishDisplay]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "心愿进展", actionTitle: "全部")

            VStack(spacing: 12) {
                ForEach(wishes) { wish in
                    HStack(spacing: 14) {
                        MiniProgressRing(progress: wish.progress, tint: wish.tint)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(wish.name)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(CheckLineColor.primaryText)
                                Spacer()
                                Image(systemName: "sparkles")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(wish.tint)
                            }

                            Text("离心愿近了，还差 \(wish.remaining.formatted(.currency(code: wish.currencyCode)))")
                                .font(.caption)
                                .foregroundStyle(CheckLineColor.secondaryText)
                        }
                    }
                    .padding(14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(CheckLineColor.stroke))
                }
            }
        }
    }
}

private struct RecentExpenseSection: View {
    let expenses: [RecentExpense]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近扣血")
                .font(.headline)
                .foregroundStyle(CheckLineColor.primaryText)

            VStack(spacing: 0) {
                ForEach(expenses) { expense in
                    HStack(spacing: 12) {
                        SymbolTile(symbolName: expense.symbolName, tint: CheckLineColor.secondaryText, size: 40)

                        VStack(alignment: .leading, spacing: 7) {
                            Text(expense.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(CheckLineColor.primaryText)

                            HStack(spacing: 6) {
                                ForEach(expense.budgetNameList, id: \.self) { name in
                                    Text(name)
                                        .font(.caption2.weight(.bold))
                                        .lineLimit(1)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .foregroundStyle(name.contains("京都") ? CheckLineColor.primary : CheckLineColor.goldText)
                                        .background(name.contains("京都") ? CheckLineColor.primary.opacity(0.1) : CheckLineColor.gold.opacity(0.18), in: Capsule())
                                }
                            }
                        }

                        Spacer()

                        Text("-\(expense.amount.formatted(.currency(code: "CNY")))")
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(CheckLineColor.danger)
                    }
                    .padding(.vertical, 14)

                    if expense.id != expenses.last?.id {
                        Divider().overlay(CheckLineColor.stroke)
                    }
                }
            }
            .padding(.horizontal, 14)
            .background(.white, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(CheckLineColor.stroke))
        }
    }
}

private struct BottomNavigationBar: View {
    let onCapture: () -> Void

    var body: some View {
        HStack {
            BottomNavItem(title: "首页", symbolName: "house.fill", isSelected: true)
            BottomNavItem(title: "预算", symbolName: "chart.line.uptrend.xyaxis")

            Button(action: onCapture) {
                Image(systemName: "plus")
                    .font(.title3.weight(.bold))
                    .frame(width: 58, height: 58)
                    .foregroundStyle(.white)
                    .background(CheckLineColor.primary, in: Circle())
                    .shadow(color: CheckLineColor.primary.opacity(0.25), radius: 14, y: 8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("记一笔")
            .offset(y: -10)

            BottomNavItem(title: "心愿", symbolName: "sparkles")
            BottomNavItem(title: "设置", symbolName: "gearshape")
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.white.opacity(0.96))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(CheckLineColor.stroke)
                .frame(height: 1)
        }
    }
}

private struct BottomNavItem: View {
    let title: String
    let symbolName: String
    var isSelected = false

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbolName)
                .font(.headline)
            Text(title)
                .font(.caption2.weight(.medium))
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(isSelected ? CheckLineColor.primary : CheckLineColor.secondaryText)
    }
}

private struct CaptureSheet: View {
    let budgets: [BudgetDisplay]
    let defaultBudgetID: UUID
    let onConfirm: (ExpenseDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amountText = "38"
    @State private var selectedBudgetIDs: Set<UUID>
    @State private var selectedCategory = "市内交通"
    @State private var note = ""

    private let categories = [
        ("市内交通", "tram.fill", CheckLineColor.primary),
        ("伙食", "fork.knife", CheckLineColor.orange),
        ("聚会", "person.2.fill", CheckLineColor.purple),
        ("学习", "book.closed.fill", CheckLineColor.teal),
    ]

    init(budgets: [BudgetDisplay], defaultBudgetID: UUID, onConfirm: @escaping (ExpenseDraft) -> Void) {
        self.budgets = budgets
        self.defaultBudgetID = defaultBudgetID
        self.onConfirm = onConfirm
        _selectedBudgetIDs = State(initialValue: [defaultBudgetID])
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                CheckLineColor.canvas.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("金额")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(CheckLineColor.secondaryText)

                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("CNY")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(CheckLineColor.primary)

                                TextField("38", text: $amountText)
                                    .font(.system(size: 52, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .minimumScaleFactor(0.55)
                                    .foregroundStyle(CheckLineColor.primaryText)
                            }

                            HStack(spacing: 10) {
                                ForEach(["18", "38", "68"], id: \.self) { value in
                                    Button {
                                        amountText = value
                                    } label: {
                                        Text(value)
                                            .font(.subheadline.weight(.bold))
                                            .frame(minWidth: 62, minHeight: 42)
                                            .foregroundStyle(CheckLineColor.primaryText)
                                            .background(.white, in: Capsule())
                                            .overlay(Capsule().stroke(CheckLineColor.stroke))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(18)
                        .background(.white, in: RoundedRectangle(cornerRadius: 24))
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(CheckLineColor.stroke))

                        SheetSection(title: "归到哪些预算") {
                            FlowLayout(spacing: 10) {
                                ForEach(budgets) { budget in
                                    SelectableChip(
                                        title: budget.name,
                                        symbolName: budget.symbolName,
                                        tint: budget.tint,
                                        isSelected: selectedBudgetIDs.contains(budget.id)
                                    ) {
                                        toggleBudget(budget.id)
                                    }
                                }
                            }
                        }

                        SheetSection(title: "分类") {
                            FlowLayout(spacing: 10) {
                                ForEach(categories, id: \.0) { item in
                                    SelectableChip(
                                        title: item.0,
                                        symbolName: item.1,
                                        tint: item.2,
                                        isSelected: selectedCategory == item.0
                                    ) {
                                        selectedCategory = item.0
                                    }
                                }
                            }
                        }

                        SheetSection(title: "备注") {
                            TextField("例如：地铁到展馆", text: $note)
                                .font(.body)
                                .padding(16)
                                .frame(minHeight: 54)
                                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(CheckLineColor.stroke))
                        }

                        Color.clear.frame(height: 84)
                    }
                    .padding(20)
                }

                Button {
                    onConfirm(
                        ExpenseDraft(
                            amount: parsedAmount,
                            budgetIDs: selectedBudgetIDs,
                            category: selectedCategory,
                            note: note
                        )
                    )
                } label: {
                    Label("扣血确认", systemImage: "waveform.path.ecg")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(canConfirm ? CheckLineColor.primary : CheckLineColor.secondaryText, in: RoundedRectangle(cornerRadius: 18))
                .padding(20)
                .background(
                    LinearGradient(
                        colors: [CheckLineColor.canvas.opacity(0), CheckLineColor.canvas],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea(edges: .bottom)
                )
                .disabled(!canConfirm)
            }
            .navigationTitle("记一笔")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private var parsedAmount: Decimal {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    private var canConfirm: Bool {
        parsedAmount > 0 && !selectedBudgetIDs.isEmpty
    }

    private func toggleBudget(_ id: UUID) {
        if selectedBudgetIDs.contains(id), selectedBudgetIDs.count > 1 {
            selectedBudgetIDs.remove(id)
        } else {
            selectedBudgetIDs.insert(id)
        }
    }
}

private struct SettlementChecklistView: View {
    let budget: BudgetDisplay
    let wishes: [WishDisplay]
    let onComplete: (SettlementResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var decision = LinkedDecision.all
    @State private var allocations: [UUID: Decimal]
    @State private var isHighlightVisible = false

    init(budget: BudgetDisplay, wishes: [WishDisplay], onComplete: @escaping (SettlementResult) -> Void) {
        self.budget = budget
        self.wishes = wishes
        self.onComplete = onComplete

        var initial: [UUID: Decimal] = [:]
        if let firstWishID = wishes.first?.id {
            initial[firstWishID] = budget.surplus
        }
        _allocations = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CheckLineColor.canvas.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .center, spacing: 12) {
                            Text(budget.name)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(CheckLineColor.primaryText)

                            Text(budget.surplus, format: .currency(code: budget.currencyCode))
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(CheckLineColor.success)
                                .minimumScaleFactor(0.58)

                            Text("本次可转入心愿")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(CheckLineColor.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(22)
                        .background(.white, in: RoundedRectangle(cornerRadius: 26))
                        .overlay(RoundedRectangle(cornerRadius: 26).stroke(CheckLineColor.stroke))

                        SheetSection(title: "结算清单") {
                            VStack(spacing: 12) {
                                MetricRow(title: "本预算总支出", value: budget.spent.formatted(.currency(code: budget.currencyCode)))
                                MetricRow(title: "预算总额", value: budget.total.formatted(.currency(code: budget.currencyCode)))
                                MetricRow(title: "结余", value: budget.surplus.formatted(.currency(code: budget.currencyCode)), tint: CheckLineColor.success)
                            }
                        }

                        SheetSection(title: "关联账确认") {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 12) {
                                    SymbolTile(symbolName: "tram.fill", tint: CheckLineColor.primary, size: 42)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("¥38 市内交通")
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(CheckLineColor.primaryText)
                                        Text("这笔同时归到京都旅行 / 6 月生活，请你确认实际归属。")
                                            .font(.caption)
                                            .foregroundStyle(CheckLineColor.secondaryText)
                                    }
                                }

                                Picker("关联账归属", selection: $decision) {
                                    ForEach(LinkedDecision.allCases) { item in
                                        Text(item.label).tag(item)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }

                        SheetSection(title: "转到心愿") {
                            VStack(spacing: 12) {
                                ForEach(wishes) { wish in
                                    AllocationRow(
                                        wish: wish,
                                        amount: binding(for: wish),
                                        maxAmount: budget.surplus
                                    )
                                }

                                HStack {
                                    Text("已分配")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(CheckLineColor.secondaryText)
                                    Spacer()
                                    Text(totalAllocated, format: .currency(code: "CNY"))
                                        .font(.caption.weight(.bold))
                                        .monospacedDigit()
                                        .foregroundStyle(totalAllocated <= budget.surplus ? CheckLineColor.primaryText : CheckLineColor.danger)
                                }
                            }
                        }

                        Button {
                            isHighlightVisible = true
                        } label: {
                            Label("触发结算高光", systemImage: "sparkles")
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity, minHeight: 56)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .background(canSettle ? CheckLineColor.gold : CheckLineColor.secondaryText, in: RoundedRectangle(cornerRadius: 18))
                        .disabled(!canSettle)
                    }
                    .padding(20)
                    .padding(.bottom, 18)
                }

                if isHighlightVisible {
                    SettlementHighlightOverlay(amount: totalAllocated) {
                        onComplete(SettlementResult(allocations: allocations, totalAllocated: totalAllocated))
                    }
                    .transition(.opacity)
                }
            }
            .navigationTitle("结算")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("返回") { dismiss() }
                }
            }
        }
    }

    private var totalAllocated: Decimal {
        allocations.values.reduce(0, +)
    }

    private var canSettle: Bool {
        totalAllocated >= 0 && totalAllocated <= budget.surplus
    }

    private func binding(for wish: WishDisplay) -> Binding<Decimal> {
        Binding(
            get: { allocations[wish.id, default: 0] },
            set: { allocations[wish.id] = min(max(0, $0), budget.surplus) }
        )
    }
}

private struct SheetSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(CheckLineColor.primaryText)

            content
                .padding(16)
                .background(.white, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(CheckLineColor.stroke))
        }
    }
}

private struct SelectableChip: View {
    let title: String
    let symbolName: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : symbolName)
                Text(title)
            }
            .font(.subheadline.weight(.bold))
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .foregroundStyle(isSelected ? .white : tint)
            .background(isSelected ? tint : tint.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct AllocationRow: View {
    let wish: WishDisplay
    @Binding var amount: Decimal
    let maxAmount: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(wish.name, systemImage: wish.symbolName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(CheckLineColor.primaryText)
                Spacer()
                Text(amount, format: .currency(code: wish.currencyCode))
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(wish.tint)
            }

            Stepper("调整 \(wish.name)", value: $amount, in: 0...maxAmount, step: 50)
                .labelsHidden()
        }
        .padding(14)
        .background(CheckLineColor.canvas, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct MetricRow: View {
    let title: String
    let value: String
    var tint: Color = CheckLineColor.primaryText

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(CheckLineColor.secondaryText)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
    }
}

private struct SettlementHighlightOverlay: View {
    let amount: Decimal
    let onFinish: () -> Void

    @State private var isActive = false

    var body: some View {
        ZStack {
            CheckLineColor.primaryText.opacity(0.76)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(CheckLineColor.gold)
                    .scaleEffect(isActive ? 1.12 : 0.9)

                Text("离心愿近了")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)

                Text(amount, format: .currency(code: "CNY"))
                    .font(.system(size: 50, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(CheckLineColor.gold)
                    .minimumScaleFactor(0.58)

                Text("这笔结余由你亲手分配")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
            .padding(24)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.8, bounce: 0.25)) {
                isActive = true
            }

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.25))
                onFinish()
            }
        }
    }
}

private struct SymbolTile: View {
    let symbolName: String
    let tint: Color
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: symbolName)
            .font(.headline.weight(.semibold))
            .frame(width: size, height: size)
            .foregroundStyle(tint)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.32))
            .accessibilityHidden(true)
    }
}

private struct ProgressRing: View {
    let progress: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(CheckLineColor.track, lineWidth: 6)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(progress, format: .percent.precision(.fractionLength(0)))
                .font(.caption.weight(.bold))
                .foregroundStyle(CheckLineColor.primaryText)
        }
        .frame(width: 76, height: 76)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("预算进度")
        .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
    }
}

private struct MiniProgressRing: View {
    let progress: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(CheckLineColor.track, lineWidth: 5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(progress, format: .percent.precision(.fractionLength(0)))
                .font(.caption2.weight(.bold))
                .foregroundStyle(tint)
        }
        .frame(width: 52, height: 52)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("心愿进度")
        .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
    }
}

private struct ToastView: View {
    let toast: PrototypeToast

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.symbolName)
                .font(.headline)
                .frame(width: 42, height: 42)
                .foregroundStyle(toast.tint)
                .background(toast.tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(toast.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(CheckLineColor.primaryText)
                Text(toast.message)
                    .font(.caption)
                    .foregroundStyle(CheckLineColor.secondaryText)
            }

            Spacer()
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(CheckLineColor.stroke))
        .shadow(color: .black.opacity(0.08), radius: 22, y: 12)
        .padding(.horizontal, 20)
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(in: proposal.width ?? 320, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = layout(in: bounds.width, subviews: subviews).rows
        for row in rows {
            for item in row.items {
                item.subview.place(
                    at: CGPoint(x: bounds.minX + item.origin.x, y: bounds.minY + item.origin.y),
                    proposal: ProposedViewSize(item.size)
                )
            }
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> (rows: [FlowRow], size: CGSize) {
        var rows: [FlowRow] = []
        var current = FlowRow()
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, !current.items.isEmpty {
                rows.append(current)
                y += rowHeight + spacing
                current = FlowRow()
                x = 0
                rowHeight = 0
            }

            current.items.append(FlowItem(subview: subview, origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        rows.append(current)
        return (rows, CGSize(width: width, height: y + rowHeight))
    }
}

private struct FlowRow {
    var items: [FlowItem] = []
}

private struct FlowItem {
    let subview: LayoutSubview
    let origin: CGPoint
    let size: CGSize
}

private enum CheckLineColor {
    static let canvas = Color(hex: 0xF6F6F8)
    static let cardMuted = Color(hex: 0xEEF2F7)
    static let primary = Color(hex: 0x135BEC)
    static let primaryDark = Color(hex: 0x0E44B3)
    static let primaryText = Color(hex: 0x0D121B)
    static let secondaryText = Color(hex: 0x64748B)
    static let stroke = Color(hex: 0xE5E7EB)
    static let track = Color(hex: 0xE9EEF5)
    static let success = Color(hex: 0x10B981)
    static let gold = Color(hex: 0xF59E0B)
    static let goldText = Color(hex: 0x855300)
    static let danger = Color(hex: 0xEF4444)
    static let orange = Color(hex: 0xF97316)
    static let purple = Color(hex: 0x8B5CF6)
    static let teal = Color(hex: 0x14B8A6)
}

private extension Color {
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

private struct PrototypeState {
    var budgets: [BudgetDisplay]
    var wishes: [WishDisplay]
    var recentExpenses: [RecentExpense]

    static let sample = PrototypeState(
        budgets: [
            BudgetDisplay(name: "6 月生活", cycleLabel: "月度预算", total: 5000, spent: 3480, currencyCode: "CNY", symbolName: "house.fill", tint: CheckLineColor.primary),
            BudgetDisplay(name: "京都旅行", cycleLabel: "单次预算", total: 6800, spent: 2460, currencyCode: "CNY", symbolName: "airplane.departure", tint: CheckLineColor.gold),
            BudgetDisplay(name: "Q3 学习", cycleLabel: "单次预算", total: 2200, spent: 540, currencyCode: "CNY", symbolName: "book.closed.fill", tint: CheckLineColor.purple),
        ],
        wishes: [
            WishDisplay(name: "京都樱花季", targetAmount: 9000, accruedAmount: 5850, currencyCode: "CNY", symbolName: "camera.aperture", tint: CheckLineColor.gold),
            WishDisplay(name: "富士相机", targetAmount: 12000, accruedAmount: 2760, currencyCode: "CNY", symbolName: "camera.fill", tint: CheckLineColor.primary),
        ],
        recentExpenses: [
            RecentExpense(title: "市内交通", budgetNames: "京都旅行 / 6 月生活", amount: 38, symbolName: "tram.fill"),
            RecentExpense(title: "工作日午餐", budgetNames: "6 月生活", amount: 32, symbolName: "fork.knife"),
            RecentExpense(title: "线上课程", budgetNames: "Q3 学习", amount: 180, symbolName: "book.closed.fill"),
        ]
    )

    func budget(id: UUID) -> BudgetDisplay? {
        budgets.first { $0.id == id }
    }

    mutating func recordExpense(_ draft: ExpenseDraft) {
        for index in budgets.indices where draft.budgetIDs.contains(budgets[index].id) {
            budgets[index].spent += draft.amount
        }

        let names = budgets
            .filter { draft.budgetIDs.contains($0.id) }
            .map(\.name)
            .joined(separator: " / ")

        recentExpenses.insert(
            RecentExpense(
                title: draft.category,
                budgetNames: names,
                amount: draft.amount,
                symbolName: draft.categorySymbolName
            ),
            at: 0
        )

        if recentExpenses.count > 4 {
            recentExpenses.removeLast()
        }
    }

    mutating func applySettlement(_ result: SettlementResult) {
        for index in wishes.indices {
            wishes[index].accruedAmount += result.allocations[wishes[index].id, default: 0]
        }
    }
}

private struct BudgetDisplay: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let cycleLabel: String
    let total: Decimal
    var spent: Decimal
    let currencyCode: String
    let symbolName: String
    let tint: Color

    var remaining: Decimal {
        max(0, total - spent)
    }

    var surplus: Decimal {
        max(0, total - spent)
    }

    var progress: Double {
        let totalNumber = NSDecimalNumber(decimal: total).doubleValue
        guard totalNumber > 0 else { return 0 }
        let spentNumber = NSDecimalNumber(decimal: spent).doubleValue
        return min(1, max(0, spentNumber / totalNumber))
    }

    var categorySummaries: [CategorySummary] {
        switch name {
        case "6 月生活":
            return [
                CategorySummary(title: "伙食", amount: "¥320"),
                CategorySummary(title: "聚会", amount: "¥200"),
            ]
        case "京都旅行":
            return [
                CategorySummary(title: "交通", amount: "¥380"),
                CategorySummary(title: "餐食", amount: "¥620"),
            ]
        default:
            return [
                CategorySummary(title: "课程", amount: "¥360"),
                CategorySummary(title: "书籍", amount: "¥180"),
            ]
        }
    }
}

private struct CategorySummary: Equatable {
    let title: String
    let amount: String
}

private struct WishDisplay: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let targetAmount: Decimal
    var accruedAmount: Decimal
    let currencyCode: String
    let symbolName: String
    let tint: Color

    var remaining: Decimal {
        max(0, targetAmount - accruedAmount)
    }

    var progress: Double {
        let targetNumber = NSDecimalNumber(decimal: targetAmount).doubleValue
        guard targetNumber > 0 else { return 0 }
        let accruedNumber = NSDecimalNumber(decimal: accruedAmount).doubleValue
        return min(1, max(0, accruedNumber / targetNumber))
    }
}

private struct RecentExpense: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let budgetNames: String
    let amount: Decimal
    let symbolName: String

    var budgetNameList: [String] {
        budgetNames.components(separatedBy: " / ")
    }
}

private struct ExpenseDraft {
    let amount: Decimal
    let budgetIDs: Set<UUID>
    let category: String
    let note: String

    var categorySymbolName: String {
        switch category {
        case "伙食":
            return "fork.knife"
        case "聚会":
            return "person.2.fill"
        case "学习":
            return "book.closed.fill"
        default:
            return "tram.fill"
        }
    }
}

private struct SettlementResult {
    let allocations: [UUID: Decimal]
    let totalAllocated: Decimal
}

private struct PrototypeToast: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let symbolName: String
    let tint: Color
}

private enum LinkedDecision: String, CaseIterable, Identifiable {
    case all
    case travelOnly
    case livingOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:
            return "都算"
        case .travelOnly:
            return "仅京都"
        case .livingOnly:
            return "仅生活"
        }
    }
}

#Preview("预算线 · Stitch 结构改版") {
    CheckLinePrototypeView()
}
