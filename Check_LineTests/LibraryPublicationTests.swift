import Observation
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import CheckLine

@Suite(.serialized) @MainActor struct LibraryPublicationTests {
    @MainActor @Observable final class Probe {
        var returnPull: CGFloat = 0
        @ObservationIgnored var publicationCount = 0
        @ObservationIgnored var renderedFocusID: UUID?
        @ObservationIgnored var renderedSpent: Decimal?
    }

    private struct Host: View {
        let workspace: CheckLineWorkspace
        let now: Date
        let probe: Probe
        @State private var focusedCard: HomeBudgetCardModel?

        var body: some View {
            CartridgeLibraryView(
                workspace: workspace, onChoose: { _ in }, onClose: {},
                returnPull: probe.returnPull, now: now, active: false,
                onArcPresentation: { _, card in
                    probe.publicationCount += 1
                    // Keep a feedback regression from taking over the test run loop.
                    guard probe.publicationCount <= 20 else { return }
                    focusedCard = card
                }
            )
            .frame(width: 375, height: 550)
            .environment(\.dynamicTypeSize, .medium)
            .onChange(of: focusedCard, initial: true) { _, card in
                probe.renderedFocusID = card?.id
                probe.renderedSpent = card?.snapshot.confirmedSpent
            }
        }
    }

    @Test("卡库静置及回弹刷新不会重复发布同一卡片", arguments: [true, false])
    func stableFocusPublication(hasDeadline: Bool) async throws {
        let fixture = try makeFixture(hasDeadline: hasDeadline)
        let probe = Probe()
        let window = try host(fixture.workspace, now: fixture.now, probe: probe)
        defer { window.close(); withExtendedLifetime(fixture.container) {} }

        try await wait { probe.renderedFocusID == fixture.budgetID }
        try await Task.sleep(for: .milliseconds(180))
        let publications = probe.publicationCount
        #expect(publications <= 3, "Opening the library published the same focus \(publications) times.")
        try await Task.sleep(for: .milliseconds(360))
        #expect(probe.publicationCount == publications, "The idle library kept publishing its focus.")

        for pull: CGFloat in [0.14, 0.08, 0.03, 0] {
            probe.returnPull = pull
            try await Task.sleep(for: .milliseconds(75))
        }
        #expect(probe.publicationCount == publications, "Return motion republished an unchanged card.")
        #expect(probe.renderedFocusID == fixture.budgetID)
    }

    @Test("原焦点卡保持选中并刷新账本投影")
    func focusedCardUpdatesAfterRecording() async throws {
        let fixture = try makeFixture(hasDeadline: false)
        let probe = Probe()
        let window = try host(fixture.workspace, now: fixture.now, probe: probe)
        defer { window.close(); withExtendedLifetime(fixture.container) {} }

        try await wait { probe.renderedFocusID == fixture.budgetID && probe.renderedSpent == 0 }
        let id = fixture.workspace.recordExpense(
            amountText: "25", merchant: "Lunch", note: "", attributionID: fixture.periodID.uuidString,
            occurredAt: fixture.now, now: fixture.now, currencyCode: "CNY"
        )
        try #require(id != nil)
        try await wait { probe.renderedSpent == 25 }
        #expect(probe.renderedFocusID == fixture.budgetID)
    }

    private func makeFixture(hasDeadline: Bool) throws -> (
        workspace: CheckLineWorkspace, container: ModelContainer, now: Date, budgetID: UUID, periodID: UUID
    ) {
        let now = Date()
        let week: TimeInterval = 7 * 24 * 60 * 60
        var ledger = Ledger.blank(walletCurrencyCode: "CNY", now: now)
        let (budget, period) = try ledger.insertBudgetCard(
            name: "Daily", amount: 300, currencyCode: "CNY", cycleType: .oneShot, recurrence: nil,
            startDate: now.addingTimeInterval(-week), endDate: hasDeadline ? now.addingTimeInterval(week) : nil,
            now: now
        )
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        try LedgerStore.replaceAll(ledger, in: container.mainContext)
        return (CheckLineWorkspace(context: container.mainContext, now: now), container, now, budget.id, period.id)
    }

    @MainActor private struct HostedWindow {
        let window: UIWindow
        let previousKeyWindow: UIWindow?

        func close() {
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKey()
        }
    }

    private func host(_ workspace: CheckLineWorkspace, now: Date, probe: Probe) throws -> HostedWindow {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try #require(scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        let controller = UIHostingController(rootView: Host(workspace: workspace, now: now, probe: probe))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        return HostedWindow(window: window, previousKeyWindow: previousKeyWindow)
    }

    private func wait(until condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !condition() && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(condition())
    }
}
