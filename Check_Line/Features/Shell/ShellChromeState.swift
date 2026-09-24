import SwiftUI
import UIKit

enum WalletTabTransition {
    static var usesSystemBar: Bool {
        if #available(iOS 27.0, *) { UIDevice.current.userInterfaceIdiom == .phone }
        else { false }
    }

    static var usesImmediateContent: Bool {
        if usesSystemBar { true }
        else if #available(iOS 26.0, *) { UIDevice.current.userInterfaceIdiom == .phone }
        else { false }
    }
}

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
    var presentedTab: CheckLineAppTab = .home
    var pocketClosure: CGFloat = 0
    var interiorReveal: Double = 1
    var stageOpacity: Double = 1
    var isTransitioning = false
    var isSettingsPresented = false
    var isAttentionPresented = false
    var isShowingDetail = false
    var isCreateMenuPresented = false

    var isHidden: Bool { isShowingDetail }

    func closeOverlays() {
        isCreateMenuPresented = false
    }

    /// Called by a cancellable view task. A new selection cancels the old route.
    func transitionToSelection(reduceMotion: Bool) async {
        let destination = selectedTab
        if presentedTab == destination, pocketClosure == (destination == .home ? 0 : 1), interiorReveal == 1, stageOpacity == 1, !isTransitioning { return }
        isTransitioning = true
        defer { if !Task.isCancelled { isTransitioning = false } }
        do {
            if reduceMotion {
                withAnimation(.easeOut(duration: 0.07)) { stageOpacity = 0 }
                try await Task.sleep(for: .milliseconds(70))
                try Task.checkCancellation()
                withoutAnimation {
                    presentedTab = destination
                    pocketClosure = destination == .home ? 0 : 1
                    interiorReveal = 1
                }
                withAnimation(.easeOut(duration: 0.12)) { stageOpacity = 1 }
                try await Task.sleep(for: .milliseconds(120))
                return
            }
            stageOpacity = 1
            if presentedTab == .home && destination != .home {
                try await closePocket()
                try Task.checkCancellation()
                interiorReveal = 0
                withoutAnimation { presentedTab = destination }
                try await Task.sleep(for: .milliseconds(16))
            } else if destination == .home {
                if presentedTab != .home {
                    withAnimation(.easeOut(duration: 0.12)) { interiorReveal = 0 }
                    try await Task.sleep(for: .milliseconds(120))
                    try Task.checkCancellation()
                    withoutAnimation { pocketClosure = 1; presentedTab = .home }
                    try await Task.sleep(for: .milliseconds(16))
                }
                try Task.checkCancellation()
                interiorReveal = 1
                withAnimation(.smooth(duration: 0.44)) { pocketClosure = 0 }
                try await Task.sleep(for: .milliseconds(440))
                return
            } else if presentedTab != destination {
                withAnimation(.easeOut(duration: 0.1)) { interiorReveal = 0 }
                try await Task.sleep(for: .milliseconds(100))
                try Task.checkCancellation()
                withoutAnimation { presentedTab = destination }
                try await Task.sleep(for: .milliseconds(16))
            }
            try Task.checkCancellation()
            withAnimation(.easeOut(duration: 0.22)) { interiorReveal = 1 }
            try await Task.sleep(for: .milliseconds(220))
        } catch is CancellationError {
            // Keep the in-flight position so a new task can reverse it naturally.
        } catch {
            settleNavigation()
        }
    }

    func settleNavigation() {
        withoutAnimation {
            presentedTab = selectedTab
            pocketClosure = selectedTab == .home ? 0 : 1
            interiorReveal = 1
            stageOpacity = 1
            isTransitioning = false
        }
    }

    private func withoutAnimation(_ update: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction, update)
    }

    private func closePocket() async throws {
        // Wait for the actual rendered animation as well as the nominal duration.
        // A fixed delay alone can switch tabs before a busy first frame closes the lid.
        async let minimumDuration: Void = Task.sleep(for: .milliseconds(360))
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            withAnimation(.easeInOut(duration: 0.36), completionCriteria: .removed) {
                pocketClosure = 1
            } completion: {
                continuation.resume()
            }
        }
        try await minimumDuration
        try Task.checkCancellation()
    }
}

struct WalletNavigationRequest: Hashable {
    var tab: CheckLineAppTab
    var reduceMotion: Bool
    var active: Bool
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
