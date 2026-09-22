import Foundation
import Testing
@testable import CheckLine

@MainActor
struct WalletNavigationTests {
    @Test("卡夹合起再进入内页，返回后恢复打开状态")
    func roundTrip() async {
        let state = ShellChromeState()
        state.selectedTab = .budgets
        await state.transitionToSelection(reduceMotion: false)
        #expect(state.presentedTab == .budgets)
        #expect(state.pocketClosure == 1)
        #expect(state.interiorReveal == 1)
        #expect(!state.isTransitioning)
        state.selectedTab = .home
        await state.transitionToSelection(reduceMotion: false)
        #expect(state.presentedTab == .home)
        #expect(state.pocketClosure == 0)
        #expect(state.interiorReveal == 1)
        #expect(!state.isTransitioning)
    }

    @Test("合夹中途返回不会被过期任务切到预算页")
    func reverseBeforeCovered() async throws {
        let state = ShellChromeState()
        state.selectedTab = .budgets
        let oldRoute = Task { await state.transitionToSelection(reduceMotion: false) }
        try await Task.sleep(for: .milliseconds(60))
        #expect(state.presentedTab == .home)
        oldRoute.cancel()
        state.selectedTab = .home
        await state.transitionToSelection(reduceMotion: false)
        await oldRoute.value
        #expect(state.presentedTab == .home)
        #expect(state.pocketClosure == 0)
        #expect(!state.isTransitioning)
    }

    @Test("快速选择另一内页以最后选择为准")
    func newestDestinationWins() async throws {
        let state = ShellChromeState()
        state.selectedTab = .budgets
        let oldRoute = Task { await state.transitionToSelection(reduceMotion: false) }
        try await Task.sleep(for: .milliseconds(60))
        oldRoute.cancel()
        state.selectedTab = .wishes
        await state.transitionToSelection(reduceMotion: false)
        await oldRoute.value
        #expect(state.presentedTab == .wishes)
        #expect(state.selectedTab == .wishes)
        #expect(state.interiorReveal == 1)
        #expect(!state.isTransitioning)
    }

    @Test("减少动态效果与后台收敛不会留下遮挡层")
    func fallbackAndBackground() async throws {
        let state = ShellChromeState()
        state.selectedTab = .insights
        await state.transitionToSelection(reduceMotion: true)
        #expect(state.presentedTab == .insights)
        #expect(state.stageOpacity == 1)
        state.selectedTab = .home
        let oldRoute = Task { await state.transitionToSelection(reduceMotion: false) }
        try await Task.sleep(for: .milliseconds(40))
        oldRoute.cancel()
        state.settleNavigation()
        await oldRoute.value
        #expect(state.presentedTab == .home)
        #expect(state.pocketClosure == 0)
        #expect(state.stageOpacity == 1)
        #expect(!state.isTransitioning)
    }

    @Test("导航拖动按实际栏宽定位，移出或窄容器不误切页")
    func dragTargetsAndCancellation() {
        let size = CGSize(width: 290, height: 60)
        #expect(WalletTabHitTarget.tab(at: CGPoint(x: 40, y: 30), size: size) == .home)
        #expect(WalletTabHitTarget.tab(at: CGPoint(x: 110, y: 30), size: size) == .budgets)
        #expect(WalletTabHitTarget.tab(at: CGPoint(x: 180, y: 30), size: size) == .wishes)
        #expect(WalletTabHitTarget.tab(at: CGPoint(x: 250, y: 30), size: size) == .insights)
        #expect(WalletTabHitTarget.tab(at: CGPoint(x: 40, y: 30), size: size, rightToLeft: true) == .insights)
        #expect(WalletTabHitTarget.tab(at: CGPoint(x: 110, y: 30), size: size, rightToLeft: true) == .wishes)
        for point in [CGPoint(x: -1, y: 30), CGPoint(x: 291, y: 30), CGPoint(x: 140, y: -1), CGPoint(x: 140, y: 61)] {
            #expect(WalletTabHitTarget.tab(at: point, size: size) == nil)
        }
        #expect(WalletTabHitTarget.tab(at: .zero, size: .zero) == nil)
    }
}
