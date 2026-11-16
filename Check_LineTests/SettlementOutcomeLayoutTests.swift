#if DEBUG
import SwiftUI
import Testing
import UIKit
@testable import CheckLine

@Suite(.serialized) @MainActor struct SettlementOutcomeLayoutTests {
    @Observable final class Playback {
        var started: Date?
        var entrance: SettlementResultEntrance?
    }

    private final class Measurements {
        var frames: [SettlementOutcomePart: CGRect] = [:]
        var detailsEvaluations = 0

        func record(_ event: SettlementOutcomeEvent) {
            switch event {
            case .frame(let part, let frame): frames[part] = frame
            case .detailsEvaluated: detailsEvaluations += 1
            }
        }
    }

    private struct Host: View {
        let playback: Playback
        let measurements: Measurements
        let receipt: SettlementOutcomeReceipt

        var body: some View {
            SettlementOutcomeView(
                receipt: receipt, waveStarted: playback.started,
                entrance: playback.entrance, onSkipMotion: {}, onDone: {}
            )
            .frame(width: 300, height: 640)
            .environment(\.dynamicTypeSize, .xxxLarge)
            .environment(\.locale, Locale(identifier: "en_US"))
            .environment(\.settlementOutcomeProbe, measurements.record)
        }
    }

    @Test("结算扫光结束时标题、日期、金额及返回按钮保持落位")
    func closingWaveDoesNotReflowSavedResult() async throws {
        let playback = Playback()
        playback.started = Date().addingTimeInterval(-1.4)
        playback.entrance = entrance
        let measurements = Measurements()
        try await withHostedResult(playback, measurements) {
            let before = measurements.frames
            playback.started = nil
            playback.entrance = nil
            try await Task.sleep(for: .milliseconds(180))

            for part in SettlementOutcomePart.allCases {
                let initial = try #require(before[part])
                let final = try #require(measurements.frames[part])
                let difference = max(
                    abs(initial.minX - final.minX), abs(initial.minY - final.minY),
                    abs(initial.width - final.width), abs(initial.height - final.height)
                )
                #expect(difference <= 2, "\(part) moved from \(initial) to \(final)")
            }
        }
    }

    @Test("有波面位移时已保存金额区域不随动画帧反复构建")
    func waveDoesNotReevaluateReceiptDetailsOnEveryFrame() async throws {
        let playback = Playback()
        let measurements = Measurements()
        try await withHostedResult(playback, measurements) {
            let evaluationsBeforeWave = measurements.detailsEvaluations
            playback.started = Date().addingTimeInterval(-0.54)
            playback.entrance = entrance
            try await Task.sleep(for: .milliseconds(550))
            let evaluationsDuringWave = measurements.detailsEvaluations - evaluationsBeforeWave
            print("Settlement outcome detail evaluations across 550 ms of title and button motion: \(evaluationsDuringWave)")
            #expect(evaluationsDuringWave <= 3)
        }
    }

    private var entrance: SettlementResultEntrance {
        SettlementResultEntrance(
            heading: CGRect(x: 32, y: 110, width: 185, height: 42),
            button: CGRect(x: 76, y: 575, width: 166, height: 44), start: 0.54, duration: 0.71
        )
    }

    private func withHostedResult(
        _ playback: Playback, _ measurements: Measurements, check: () async throws -> Void
    ) async throws {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try #require(scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = UIHostingController(rootView: Host(playback: playback, measurements: measurements, receipt: receipt))
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKey()
        }

        let deadline = ContinuousClock.now + .seconds(2)
        while measurements.frames.count < SettlementOutcomePart.allCases.count && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(measurements.frames.count == SettlementOutcomePart.allCases.count)
        try await check()
    }

    private var receipt: SettlementOutcomeReceipt {
        let start = Date(timeIntervalSince1970: 1_791_936_000)
        let end = start.addingTimeInterval(14 * 86_400)
        return SettlementOutcomeReceipt(
            title: "Weekend travel plans and shared expenses for the November school holiday",
            settlement: Settlement(
                id: UUID(), periodID: UUID(), settledAt: end, budgetAmountSnapshot: 1_000,
                currencyCode: "CNY", confirmedSpent: 250, baseSurplus: 750,
                coverage: CoverageSnapshot(sources: []), acceptedIncompleteData: true, createdWalletEntryID: UUID()
            ),
            periodStart: start, periodEnd: end, walletCurrency: "CNY",
            before: WalletProjection(net: -500, balance: 0, recoveryGap: 500),
            after: WalletProjection(net: 250, balance: 250, recoveryGap: 0)
        )
    }
}
#endif
