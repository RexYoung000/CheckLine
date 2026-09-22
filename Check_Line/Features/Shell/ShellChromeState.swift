import SwiftUI

enum CheckLineAppTab: String, CaseIterable, Identifiable, Hashable {
    case home
    case budgets
    case insights
    case wishes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: String(localized: "tab.home")
        case .budgets: String(localized: "tab.budgets")
        case .insights: String(localized: "wallet.analysis.title")
        case .wishes: String(localized: "wallet.wishes.title")
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .budgets: "wallet.pass"
        case .insights: "chart.bar.xaxis"
        case .wishes: "heart"
        }
    }
}

@MainActor
@Observable
final class ShellChromeState {
    var selectedTab: CheckLineAppTab = .home
    var isSettingsPresented = false
    var isShowingDetail = false
    var isCreateMenuPresented = false

    var isHidden: Bool { isShowingDetail }

    func closeOverlays() {
        isCreateMenuPresented = false
    }
}

private struct ShellChromeKey: EnvironmentKey {
    static let defaultValue: ShellChromeState? = nil
}

extension EnvironmentValues {
    var shellChrome: ShellChromeState? {
        get { self[ShellChromeKey.self] }
        set { self[ShellChromeKey.self] = newValue }
    }
}

struct PaperEmptyHint: View {
    var title: String
    var message: String = String(localized: "v1.shell.empty.hint")

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(PaperTheme.Typography.title)
                .foregroundStyle(PaperTheme.ink)
                .multilineTextAlignment(.center)
            Text(message)
                .font(PaperTheme.Typography.empty)
                .foregroundStyle(PaperTheme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
        .accessibilityElement(children: .combine)
    }
}
