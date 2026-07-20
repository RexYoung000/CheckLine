import SwiftUI
import UIKit

enum CheckLineColor {
    static let canvas = Color(hex: 0xF6F6F8)
    static let card = Color.white
    static let muted = Color(hex: 0xEEF2F7)
    static let divider = Color(hex: 0xE5E7EB)
    static let brand = Color(hex: 0x135BEC)
    static let brandDark = Color(hex: 0x0E44B3)
    static let brandSoft = Color(hex: 0xE8F0FF)
    static let text = Color(hex: 0x0D121B)
    static let secondary = Color(hex: 0x64748B)
    static let quiet = Color(hex: 0x94A3B8)
    static let success = Color(hex: 0x10B981)
    static let warning = Color(hex: 0xF59E0B)
    static let danger = Color(hex: 0xEF4444)
}

extension Color {
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

struct BudgetProgressBar: View {
    let progress: Double
    var height: CGFloat = 8

    private var color: Color {
        if progress >= 0.95 { return CheckLineColor.danger }
        if progress >= 0.8 { return CheckLineColor.warning }
        return CheckLineColor.brand
    }

    var body: some View {
        ProgressView(value: min(max(progress, 0), 1))
            .progressViewStyle(.linear)
            .tint(color)
            .scaleEffect(y: max(1, height / 4), anchor: .center)
        .animation(.easeInOut(duration: 0.3), value: progress)
        .accessibilityLabel(Text("budget.progress.accessibility"))
        .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
    }
}

struct MoneyText: View {
    let amount: Decimal
    var color: Color = CheckLineColor.text
    var size: CGFloat = 36

    var body: some View {
        Text(currencyText(amount))
            .font(.system(size: size, weight: .black, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .contentTransition(.numericText(value: decimalDouble(amount)))
            .animation(.spring(duration: 0.45, bounce: 0.12), value: amount)
    }
}

enum PrototypeHaptics {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

func currencyText(_ amount: Decimal) -> String {
    amount.formatted(
        .currency(code: "CNY")
        .precision(.fractionLength(0))
    )
}

func dateRangeText(_ budget: PrototypeBudget) -> String {
    let start = budget.startDate.formatted(.dateTime.month(.defaultDigits).day())
    let end = budget.endDate.formatted(.dateTime.month(.defaultDigits).day())
    return "\(start) – \(end)"
}

func categoryColor(_ category: PrototypeCategory) -> Color {
    Color(hex: category.colorHex)
}
