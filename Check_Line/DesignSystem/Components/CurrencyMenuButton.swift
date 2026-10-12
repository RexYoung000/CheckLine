import SwiftUI

struct CurrencyMenuButton: View {
    @Binding var currency: String
    var preferred: String = "CNY"
    var label: String = String(localized: "v1.budget.currency")

    private var codes: [String] {
        var seen = Set<String>()
        return ([preferred, currency, "CNY", "USD", "EUR", "JPY", "HKD", "GBP"] + Locale.commonISOCurrencyCodes.sorted())
            .filter { Locale.commonISOCurrencyCodes.contains($0) && seen.insert($0).inserted }
    }

    var body: some View {
        Menu {
            Picker(label, selection: $currency) {
                ForEach(codes, id: \.self) { code in
                    Text(code + " · " + (Locale.current.localizedString(forCurrencyCode: code) ?? code)).tag(code)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(currency).font(.body.weight(.medium)).monospacedDigit()
                CheckLineIcon(symbol: "chevron.down", size: 12)
            }.foregroundStyle(PaperTheme.ink).padding(.horizontal, 14).frame(minHeight: 44)
                .background(PaperTheme.accent.opacity(0.1), in: Capsule())
        }.accessibilityLabel(label).accessibilityValue(currency)
    }
}

struct LocalDraftFailureView: View {
    @Bindable var task: LocalTaskDraftSession
    var body: some View {
        if task.saveFailed {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "ui.draft.failed")).font(.caption).foregroundStyle(PaperTheme.accent)
                Button(String(localized: "ui.draft.retry")) { task.retry() }.frame(minHeight: 44)
            }
        }
    }
}
