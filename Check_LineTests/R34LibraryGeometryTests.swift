import Foundation
import Testing
@testable import CheckLine

@MainActor struct R34LibraryGeometryTests {
    @Test("少量预算优先多行，水平与垂直间距各自一致")
    func sparseLibrariesUseMultipleRows() {
        for size in [CGSize(width: 320, height: 390), CGSize(width: 390, height: 520), CGSize(width: 700, height: 780)] {
            for count in 2...8 {
                let metrics = LibraryDomeMetrics(count: count, size: size)
                #expect(metrics.rows >= 2)
                #expect(metrics.columns * metrics.rows >= count)
                #expect(metrics.pitchX - metrics.cardWidth >= 29 - 0.001)
                #expect(metrics.pitchY - metrics.cardHeight >= 25 - 0.001)
                let positions = (0..<count).map { metrics.position(index: $0, offset: .zero) }
                let yValues = positions.map(\.y)
                #expect((yValues.max() ?? 0) - (yValues.min() ?? 0) > metrics.cardHeight * 0.8)
                #expect(positions.allSatisfy { $0.opacity > 0 })
            }
        }
    }

    @Test("球面横向与纵向均可循环，同一卡片回到同一位置与可见度")
    func bothAxesWrapToTheSameCard() {
        for count in [2, 3, 8, 9, 12, 23, 64] {
            let metrics = LibraryDomeMetrics(count: count, size: CGSize(width: 390, height: 500))
            for index in 0..<count {
                let origin = CGPoint(x: 31.75, y: -19.25)
                let baseline = metrics.position(index: index, offset: origin)
                for turns in [-100, -3, 1, 4, 100] {
                    let xLoop = metrics.position(index: index, offset: CGPoint(x: origin.x + CGFloat(turns) * metrics.periodX, y: origin.y))
                    let yLoop = metrics.position(index: index, offset: CGPoint(x: origin.x, y: origin.y + CGFloat(turns) * metrics.periodY))
                    for looped in [xLoop, yLoop] {
                        #expect(abs(looped.x - baseline.x) < 0.0001)
                        #expect(abs(looped.y - baseline.y) < 0.0001)
                        #expect(abs(looped.angleX - baseline.angleX) < 0.0001)
                        #expect(abs(looped.angleY - baseline.angleY) < 0.0001)
                        #expect(abs(looped.opacity - baseline.opacity) < 0.0001)
                        #expect(abs(looped.scale - baseline.scale) < 0.0001)
                    }
                }
            }
        }
    }

    @Test("连续双轴浏览不产生非法几何，离开边缘后原卡可再次浮现")
    func continuousSurfaceStaysBoundedAndReappears() {
        let metrics = LibraryDomeMetrics(count: 3, size: CGSize(width: 390, height: 500))
        var visible = 0
        var hidden = 0
        for step in 0...200 {
            let position = metrics.position(index: 0, offset: CGPoint(x: metrics.periodX * CGFloat(step) / 200,
                                                                      y: metrics.periodY * CGFloat(step) / 200))
            #expect(position.x.isFinite && position.y.isFinite)
            #expect(position.angleX.isFinite && position.angleY.isFinite)
            #expect(position.scale >= 0.82 && position.scale <= 1)
            #expect(position.opacity >= 0 && position.opacity <= 1)
            if position.opacity > 0.5 { visible += 1 }
            if position.opacity == 0 { hidden += 1 }
        }
        #expect(visible > 0)
        #expect(hidden > 0)
        let first = metrics.position(index: 0, offset: .zero)
        let returned = metrics.position(index: 0, offset: CGPoint(x: metrics.periodX, y: metrics.periodY))
        #expect(abs(first.x - returned.x) < 0.0001)
        #expect(abs(first.y - returned.y) < 0.0001)
        #expect(abs(first.opacity - returned.opacity) < 0.0001)
    }
}
