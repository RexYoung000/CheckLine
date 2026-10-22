import SwiftUI

/// A fixed, low-contrast grain. It is separate from the animated liquid layer.
struct WalletGrain: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<1_600 {
                let x = grainCoordinate(UInt64(index * 2)) * size.width
                let y = grainCoordinate(UInt64(index * 2 + 1)) * size.height
                let dot = CGRect(x: x, y: y, width: index.isMultiple(of: 3) ? 0.8 : 0.5, height: 0.5)
                context.fill(Path(ellipseIn: dot), with: .color(.white.opacity(index.isMultiple(of: 2) ? 0.085 : 0.035)))
            }
        }
        .allowsHitTesting(false).accessibilityHidden(true)
    }

    private func grainCoordinate(_ index: UInt64) -> CGFloat {
        var value = index &+ 0x9e3779b97f4a7c15
        value = (value ^ (value >> 30)) &* 0xbf58476d1ce4e5b9
        value = (value ^ (value >> 27)) &* 0x94d049bb133111eb
        value ^= value >> 31
        return CGFloat(value & 0xffffff) / CGFloat(0xffffff)
    }
}

struct WalletInteriorSurface: View {
    var body: some View {
        ZStack(alignment: .top) {
            PaperTheme.canvas
            LinearGradient(colors: [PaperTheme.pocket.opacity(0.65), PaperTheme.canvas], startPoint: .top, endPoint: .bottom)
            WalletGrain().opacity(0.12)
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(LinearGradient(colors: [PaperTheme.ink.opacity(0.055), .clear], startPoint: .top, endPoint: .center), lineWidth: 0.8)
                .padding(.horizontal, 9).padding(.top, 8)
        }
        .accessibilityHidden(true)
    }
}

struct WalletReceiptCard: View {
    var expense: Expense
    var depth: Int
    var contact: Date? = nil

    private var colors: [Color] {
        depth == 0
            ? [Color.paper(light: 0xE5DDEB, dark: 0x413749), Color.paper(light: 0xDDD3E6, dark: 0x3C3244)]
            : [Color.paper(light: 0xD8CDE2, dark: 0x372F3E), Color.paper(light: 0xCABBD8, dark: 0x2F2934)]
    }

    var body: some View {
        HStack(spacing: 12) {
            CheckLineIcon(symbol: BudgetPresentation.symbol(for: expense), size: 20)
                .font(.system(size: 19, weight: .regular)).frame(width: 22).accessibilityHidden(true)
            Text(expense.merchant ?? String(localized: "v1.card.record.untitled")).lineLimit(1).modifier(ContactTextEntrance(contact: contact))
            Spacer(minLength: 8)
            ContactAmountText(value: expense.kind == .refund ? expense.originalAmount : -expense.originalAmount,currency: expense.originalCurrencyCode,contact: contact)
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
        }
        .font(.subheadline).foregroundStyle(PaperTheme.ink)
        .padding(.horizontal, 18).frame(minHeight: 57)
        .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(LinearGradient(colors: [PaperTheme.ink.opacity(0.1), PaperTheme.ink.opacity(0.02)], startPoint: .top, endPoint: .bottom), lineWidth: 0.8)
        }
        .shadow(color: Color(red: 0.09, green: 0.06, blue: 0.14).opacity(0.16), radius: 2, y: 2)
        .accessibilityElement(children: .combine)
    }
}

struct WalletReceiptStack: View {
    var rows: [Expense]
    @Binding var position: Int
    var contact: Date? = nil
    var active = true
    var openExpense: (Expense) -> Void
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @GestureState private var drag: CGFloat = 0

    private var start: Int { max(0, min(position, max(0, rows.count - 1))) }
    private var location: CGFloat {
        let raw = CGFloat(start) + (reduceMotion ? 0 : drag / 92)
        return min(CGFloat(max(0, rows.count - 1)), max(0, raw))
    }

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    ForEach(Array(rows.dropFirst(start).prefix(3))) { expense in
                        Button { openExpense(expense) } label: { WalletReceiptCard(expense: expense, depth: 0,contact: contact) }
                    }
                }
            } else {
                ZStack(alignment: .top) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, expense in
                        let depth = CGFloat(index) - location
                        if depth > -1 && depth < 3 {
                            Button { openExpense(expense) } label: { WalletReceiptCard(expense: expense, depth: depth < 0.7 ? 0 : 1,contact: contact).overlay { ComponentLightSweep(startedAt: contact,radius: 17) } }
                                .frame(height: 57)
                                .scaleEffect(1 - max(0, depth) * 0.055)
                                .offset(y: CGFloat(min(2, rows.count - 1)) * 44 - depth * 44)
                                .opacity(depth < 0 ? max(0, 1 + depth) : min(1, 3 - depth))
                                .zIndex(Double(rows.count - index))
                                .accessibilityHidden(depth < -0.01 || depth > 2.01)
                        }
                    }
                }
                .frame(height: CGFloat(min(2, max(0, rows.count - 1))) * 44 + 63, alignment: .top)
                .clipped()
            }
        }
        .buttonStyle(.plain)
        .allowsHitTesting(active)
        .contentShape(Rectangle())
        .highPriorityGesture(DragGesture(minimumDistance: 8)
            .updating($drag) { value, state, _ in
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                state = value.translation.height
            }
            .onEnded { value in
                guard abs(value.translation.height) > 36, abs(value.translation.height) > abs(value.translation.width)*1.2 else { return }
                let travel=value.translation.height/92
                let step=max(-1,min(1,Int(travel.rounded())))
                move(to: start+(step == 0 ? (value.translation.height>0 ? 1 : -1) : step))
            })
        .accessibilityAction(named: Text("wallet.records.older")) { move(to: start + 1) }
        .accessibilityAction(named: Text("wallet.records.newer")) { move(to: start - 1) }
    }

    private func move(to target: Int) {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.42)) {
            position = max(0, min(rows.count - 1, target))
        }
    }
}

/// Shared contact event gives labels and the receipt content one entrance, without delayed tasks.
struct ContactTextEntrance: ViewModifier {
    let contact: Date?
    @State private var revealed = true
    @Environment(\.walletReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content.opacity(revealed ? 1 : 0.12).offset(y: revealed ? 0 : 6)
            .task(id: contact) {
                guard !reduceMotion, let contact, Date().timeIntervalSince(contact)<0.56 else { revealed=true;return }
                var instant=Transaction(animation: nil);instant.disablesAnimations=true
                withTransaction(instant) { revealed=false }
                withAnimation(.easeOut(duration: max(0.1,0.56-Date().timeIntervalSince(contact)))) { revealed=true }
            }
    }
}
