import SwiftUI
import UIKit

enum CheckLineColor {
    static let canvas = Color(hex: 0xF8F8F5)
    static let card = Color.white
    static let muted = Color(hex: 0xF0F0EC)
    static let divider = Color(hex: 0xE7E7E2)
    static let surfaceStroke = Color(hex: 0xE9E9E4)
    static let brand = Color(hex: 0x1B1B1A)
    static let brandDark = Color(hex: 0x10100F)
    static let brandSoft = Color(hex: 0xECECE7)
    static let text = Color(hex: 0x1B1B1A)
    static let secondary = Color(hex: 0x74746E)
    static let quiet = Color(hex: 0x9A9A94)
    static let success = Color(hex: 0x426B57)
    static let warning = Color(hex: 0xA36B24)
    static let danger = Color(hex: 0xC84845)
}

struct CheckLineSurface<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 20

    init(
        cornerRadius: CGFloat = 20,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(CheckLineColor.card)
            )
            .shadow(color: .black.opacity(0.035), radius: 20, x: 0, y: 10)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let progress: Double
    var height: CGFloat = 5

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
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: progress)
            .accessibilityLabel(Text("budget.progress.accessibility"))
            .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
    }
}

struct MoneyText: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let amount: Decimal
    var color: Color = CheckLineColor.text
    var size: CGFloat = 40

    var body: some View {
        Text(currencyText(amount))
            .font(.system(size: size, weight: .regular, design: .default))
            .monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .contentTransition(.numericText(value: decimalDouble(amount)))
            .animation(
                reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.84),
                value: amount
            )
    }
}

struct CheckLinePrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                CheckLineColor.text.opacity(isEnabled ? 1 : 0.3),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.975 : 1)
            .opacity(reduceMotion && configuration.isPressed ? 0.72 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct CheckLineSectionHeader<Trailing: View>: View {
    let title: LocalizedStringKey
    let trailing: Trailing

    init(
        _ title: LocalizedStringKey,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(CheckLineColor.text)

            Spacer(minLength: 8)
            trailing
        }
    }
}

extension CheckLineSectionHeader where Trailing == EmptyView {
    init(_ title: LocalizedStringKey) {
        self.init(title) { EmptyView() }
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
                .foregroundStyle(CheckLineColor.text)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(CheckLineColor.card, in: Capsule())
        .overlay(
            Capsule()
                .stroke(CheckLineColor.surfaceStroke.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 8)
        .accessibilityElement(children: .contain)
    }
}
