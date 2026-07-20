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

struct PrototypeCardModifier: ViewModifier {
    var radius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(CheckLineColor.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(CheckLineColor.divider.opacity(0.75), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.05), radius: 14, y: 8)
    }
}

extension View {
    func prototypeCard(radius: CGFloat = 16) -> some View {
        modifier(PrototypeCardModifier(radius: radius))
    }
}

struct PrototypeSectionHeader<Trailing: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var trailing: Trailing

    init(_ title: LocalizedStringKey, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(CheckLineColor.text)
            Spacer()
            trailing
        }
    }
}

extension PrototypeSectionHeader where Trailing == EmptyView {
    init(_ title: LocalizedStringKey) {
        self.init(title) { EmptyView() }
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
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(CheckLineColor.muted)
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: height)
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

struct PrototypeChip: View {
    let title: String
    var symbol: String?
    var isSelected = false
    var tint = CheckLineColor.brand
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                } else if let symbol {
                    Image(systemName: symbol)
                }
                Text(title)
                    .lineLimit(1)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? Color.white : CheckLineColor.secondary)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(isSelected ? tint : CheckLineColor.card, in: Capsule())
            .overlay {
                Capsule().stroke(isSelected ? tint : CheckLineColor.divider, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct PrototypeToast: Equatable, Identifiable {
    let id = UUID()
    let title: String
    let symbolName: String
    var actionTitle: String?
    var action: (() -> Void)?

    static func == (lhs: PrototypeToast, rhs: PrototypeToast) -> Bool {
        lhs.id == rhs.id
    }
}

struct PrototypeToastView: View {
    let toast: PrototypeToast

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.symbolName)
                .font(.body.weight(.bold))
            Text(toast.title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            if let actionTitle = toast.actionTitle {
                Button(actionTitle) { toast.action?() }
                    .font(.subheadline.bold())
                    .buttonStyle(.plain)
            }
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .background(Color(hex: 0x0F172A), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 18, y: 8)
        .accessibilityElement(children: .combine)
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
