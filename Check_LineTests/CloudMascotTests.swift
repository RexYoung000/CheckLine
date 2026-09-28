import Foundation
import SwiftData
import Testing
@testable import CheckLine

struct CloudMascotMotionTests {
    @Test("思考参数与获认可 HTML 的独立采样一致")
    func matchesApprovedStudy() {
        // Reference coordinates sampled from cloud-inner-flow.mjs, not this Swift implementation.
        let expected: [(Double, Double, Double)] = [
            (0, -11.290998095435437, -12.412527393258033),
            (1.5, 2.9953606007401032, -14.529738314215557),
            (7.25, -22.493042328350544, 5.0382437536734415)
        ]
        for (t, x, y) in expected {
            let light = CloudMascotMotion.sample(.thinking, elapsed: t).lights[0]
            #expect(abs(light.position.x - x) < 0.00001)
            #expect(abs(light.position.y - y) < 0.00001)
        }
    }

    @Test("双色团仅在真实思考状态可见")
    func internalLightsOnlyDuringThinking() {
        for state in CloudMascotState.allCases where state != .thinking {
            #expect(CloudMascotMotion.sample(state, elapsed: 3).lights.allSatisfy { $0.opacity == 0 })
        }
        #expect(CloudMascotMotion.sample(.thinking, elapsed: 3).lights.allSatisfy { $0.opacity > 0 })
    }

    @Test("中途取消及再次打断都从当前姿态接续，后台恢复不跳帧")
    func interruptsAndPauses() {
        var player = CloudMascotPlayer()
        player.setRunning(true, at: 10)
        player.select(.thinking, at: 11)
        let thinking = player.frame(at: 11.21)
        player.select(.waiting, at: 11.21)
        #expect(player.frame(at: 11.21) == thinking)
        let waiting = player.frame(at: 11.36)
        player.select(.idle, at: 11.36)
        #expect(player.frame(at: 11.36) == waiting)
        player.setRunning(false, at: 12)
        let paused = player.frame(at: 12)
        #expect(player.frame(at: 80) == paused)
        player.setRunning(true, at: 80)
        #expect(player.frame(at: 80) == paused)
        #expect(player.frame(at: 81) != paused)
    }

    @Test("所有状态保持内色漂移；减少动态固定姿态；成功表情仅一次")
    func motionPreferencesAndSettling() {
        for state in CloudMascotState.allCases {
            let a = CloudMascotMotion.sample(state, elapsed: 0, stateTime: 2)
            let b = CloudMascotMotion.sample(state, elapsed: 2, stateTime: 4)
            #expect(a.lights != b.lights)
            #expect(CloudMascotMotion.sample(state, elapsed: 0, reduced: true) == CloudMascotMotion.sample(state, elapsed: 500, reduced: true))
        }
        #expect(CloudMascotMotion.sample(.success, elapsed: 2, stateTime: 2).eyes == CloudMascotMotion.sample(.idle, elapsed: 2).eyes)
        var player = CloudMascotPlayer()
        player.setRunning(true, at: 0)
        player.select(.thinking, at: 1)
        player.setReduced(true, at: 2)
        #expect(player.frame(at: 2) == player.frame(at: 30))
        player.select(.error, at: 30)
        #expect(player.frame(at: 30).error == 1)
    }
}

@MainActor
struct CloudMascotWorkspaceTests {
    @MainActor private final class SaveSwitch { var fails = true }
    @Test("确认前不成功，保存失败保留草稿；重试落盘后才完成，取消回待机")
    func persistenceControlsExpression() async throws {
        enum SaveError: Error { case unavailable }
        let now = TestDates.day(2026, 1, 5)
        let container = try CheckLinePersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let saveSwitch = SaveSwitch()
        let workspace = CheckLineWorkspace(context: context, now: now, calendar: TestDates.calendar, saveLedger: { ledger, context in
            if saveSwitch.fails { throw SaveError.unavailable }
            try LedgerStore.replaceAll(ledger, in: context)
        })
        workspace.draftText = "咖啡 35 元"
        await workspace.submitText(now: now)
        #expect(workspace.showsStructuredConfirm)
        #expect(workspace.mascotState == .waiting)
        workspace.confirmStructured(now: now)
        #expect(workspace.mascotState == .error)
        #expect(workspace.showsStructuredConfirm)
        #expect(workspace.ledger.expenses.isEmpty)
        saveSwitch.fails = false
        workspace.confirmStructured(now: now)
        #expect(workspace.mascotState == .success)
        #expect(try LedgerStore.load(from: context, now: now).expenses.count == 1)
        workspace.draftText = "午餐 28 元"
        await workspace.submitText(now: now)
        #expect(workspace.mascotState == .waiting)
        workspace.cancelAgentProposal()
        #expect(workspace.mascotState == .idle)
        #expect(workspace.ledger.expenses.count == 1)
    }
}
