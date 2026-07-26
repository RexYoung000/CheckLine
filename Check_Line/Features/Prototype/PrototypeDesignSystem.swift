import SwiftUI
import UIKit

enum CheckLineColor {
    static let canvas = Color(hex: 0xF6F6F8)
    static let card = Color.white
    static let muted = Color(hex: 0xEEF2F7)
    static let divider = Color(hex: 0xE5E7EB)
    static let surfaceStroke = Color(hex: 0xE2E8F0)
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

struct CheckLineSurface<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 18

    init(
        cornerRadius: CGFloat = 18,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(CheckLineColor.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(CheckLineColor.surfaceStroke.opacity(0.75), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.045), radius: 18, x: 0, y: 8)
    }
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
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                Capsule()
                    .fill(CheckLineColor.muted)
            )
            .clipShape(Capsule())
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

struct PrototypeToast: Identifiable {
    let id = UUID()
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
}

struct PrototypeToastView: View {
    let toast: PrototypeToast

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(CheckLineColor.success)

            Text(toast.message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CheckLineColor.text)
                .lineLimit(2)

            Spacer(minLength: 4)

            if let actionTitle = toast.actionTitle, let action = toast.action {
                Button(actionTitle) {
                    action()
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(CheckLineColor.brand)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(CheckLineColor.surfaceStroke.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 8)
        .accessibilityElement(children: .contain)
    }
}
