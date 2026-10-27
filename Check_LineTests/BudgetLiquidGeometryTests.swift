import Foundation
import Testing
@testable import CheckLine

struct BudgetLiquidGeometryTests {
    private let size = CGSize(width: 350, height: 258)

    @Test("空预算没有水体、自由液面或气泡")
    func emptyWater() {
        for morph: CGFloat in [0, 1] {
            let shape = LiquidSurfaceGeometry.make(size: size, level: 0, morph: morph, time: 31)
            #expect(shape.volume.isEmpty && shape.surface.isEmpty && shape.front.isEmpty && shape.rear.isEmpty)
            #expect(LiquidBubbleField.ambient(size: size, level: 0, morph: morph, time: 31, seed: 41).isEmpty)
        }
    }

    @Test("近空到满水均保留有限、分离的前后自由液面")
    func boundedFreeSurfaces() {
        for level: CGFloat in [0.001, 0.12, 0.43, 0.95, 1] {
            for morph: CGFloat in [0, 1] {
                for time in [0.0, 0.3, 5, 50] {
                    for impulse in [-1000.0, 0, 1000] {
                        let shape = LiquidSurfaceGeometry.make(size: size, level: level, morph: morph, time: time, tilt: impulse, impact: impulse)
                        #expect(shape.front.count == 41 && shape.rear.count == 41)
                        for (front, rear) in zip(shape.front, shape.rear) {
                            #expect(front.x.isFinite && front.y.isFinite && rear.x.isFinite && rear.y.isFinite)
                            if morph == 0 {
                                #expect(front.y >= rear.y)
                                #expect(rear.y >= 0 && front.y <= size.height)
                            } else {
                                #expect(rear.x >= front.x)
                                #expect(front.x >= 0 && rear.x <= size.width)
                            }
                        }
                    }
                }
            }
        }
    }

    @Test("满水仍流动且窄封边内不会裁掉波峰")
    func fullWaterFlowsInsideRim() {
        let first = LiquidSurfaceGeometry.make(size: size, level: 1, time: 0)
        let next = LiquidSurfaceGeometry.make(size: size, level: 1, time: 1)
        #expect(first.front != next.front)
        #expect(first.rear.allSatisfy { $0.y > 8 })
        #expect(first.front.allSatisfy { $0.y < 25 })
        let middle = LiquidSurfaceGeometry.make(size: size, level: 0.43, time: 7)
        let mean = middle.front.reduce(0) { $0+$1.y }/CGFloat(middle.front.count)
        #expect(abs(mean-size.height*0.57) < 0.5)
    }

    @Test("中断期间只冻结可见时间，恢复不追赶后台时长")
    func visibleTimeDoesNotSeek() {
        var clock = LiquidMotionClock()
        clock.setRunning(true, at: 10)
        let before = clock.elapsedTime(at: 13)
        clock.setRunning(false, at: 13)
        #expect(clock.elapsedTime(at: 1000) == before)
        clock.setRunning(true, at: 1000)
        #expect(clock.elapsedTime(at: 1000) == before)
        let paused = LiquidSurfaceGeometry.make(size: size, level: 1, time: before)
        let resumed = LiquidSurfaceGeometry.make(size: size, level: 1, time: clock.elapsedTime(at: 1000))
        #expect(paused.front == resumed.front && paused.rear == resumed.rear)
        #expect(clock.elapsedTime(at: 1001) == before+1)
    }

    @Test("卡库静态气泡只在实际水体内，不产生独立动态场")
    func staticLibraryBubbles() {
        let a = LiquidBubbleField.ambient(size: size, level: 1, morph: 0, time: 0, seed: 41, count: 10)
        let b = LiquidBubbleField.ambient(size: size, level: 1, morph: 0, time: 0, seed: 41, count: 10)
        #expect(a.count == 10 && a.map(\.center) == b.map(\.center))
        #expect(a.allSatisfy { $0.center.y > 18 && $0.center.y <= size.height })
    }
}
