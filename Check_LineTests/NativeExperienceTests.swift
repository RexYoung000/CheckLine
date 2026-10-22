import Foundation
import SwiftData
import Testing
import UIKit
@testable import CheckLine

@MainActor struct NativeExperienceTests {
    @Test("卡夹点击和短拖不切层、斜拖不抢手势、边界不越界")
    func holderIntentAndBounds() {
        for stage in BudgetStage.allCases {
            #expect(stage.destination(translation: .zero,predicted: CGSize(width: 0,height: 400)) == stage)
            #expect(stage.destination(translation: CGSize(width: 0,height: 25),predicted: CGSize(width: 0,height: 500)) == stage)
            #expect(stage.destination(translation: CGSize(width: 100,height: 80),predicted: CGSize(width: 100,height: 800)) == stage)
        }
        #expect(BudgetStage.records.destination(translation: CGSize(width: 0,height: -300),predicted: .zero) == .records)
        #expect(BudgetStage.library.destination(translation: CGSize(width: 0,height: 300),predicted: .zero) == .dashboard)
        #expect(BudgetStage.dashboard.destination(translation: CGSize(width: 0,height: -100),predicted: CGSize(width: 0,height: -140)) == .records)
        #expect(BudgetStage.dashboard.destination(translation: CGSize(width: 0,height: 100),predicted: CGSize(width: 0,height: 140)) == .library)
        #expect(BudgetStage.dashboard.position(translation: CGSize(width: 0,height: -125)) == -0.5)
        #expect(BudgetStage.records.position(translation: CGSize(width: 0,height: -999)) == -1)
    }

    @Test("收币整个金额单调且不超真实结果，跨位和大额仍精确")
    func amountClock() {
        for (before,after) in [(Decimal(280),Decimal(400)),(DecimalMath.parse("9.99"),DecimalMath.parse("10.01")),(DecimalMath.parse("99999999.99"),DecimalMath.parse("100000001.01"))] {
            var last=before
            for step in 0...400 {
                let value=RewardTiming.receivedAmount(before: before,after: after,elapsed: Double(step)/100)
                #expect(value>=last && value>=before && value<=after)
                last=value
            }
            #expect(last==after)
        }
        #expect(RewardTiming.receivedAmount(before: 280,after: 0,elapsed: 0.5)==0)
    }

    @Test("碎片覆盖原面且随机种子改变几何，重演不涉及账本")
    func fracture() {
        let first=GlassFracture.make(seed: 1), second=GlassFracture.make(seed: 2)
        #expect(first.count>35)
        #expect(first.map(\.points) != second.map(\.points))
        var area=0.0
        for fragment in first {
            var signed=0.0
            for i in fragment.points.indices {
                let a=fragment.points[i],b=fragment.points[(i+1)%fragment.points.count]
                #expect(a.x>=(-0.0001) && a.x<=1.0001 && a.y>=(-0.0001) && a.y<=1.0001)
                signed += a.x*b.y-b.x*a.y
            }
            area += abs(signed)/2
        }
        #expect(abs(area-1)<0.0001)
    }

    @Test("封面跨实例恢复、按心愿隔离、坏文件安全回退")
    func coverPersistence() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let first=UUID(),second=UUID(),store=WishCoverStore(root: root)
        try store.save(WishCover(symbol: "camera",layout: .inset,imageData: Data([1,2,3])),for: first)
        let restored=WishCoverStore(root: root)
        #expect(restored.cover(for: first).symbol == "camera")
        #expect(restored.cover(for: second,fallback: "book").symbol == "book")
        try Data([0,1]).write(to: root.appendingPathComponent(second.uuidString).appendingPathExtension("json"))
        #expect(WishCoverStore(root: root).cover(for: second,fallback: "tent").symbol == "tent")
        try restored.remove(first)
        #expect(WishCoverStore(root: root).cover(for: first,fallback: "heart").symbol == "heart")
    }

    @Test("图片重编码缩限尺寸，非法内容拒绝而非保存原图")
    func thumbnail() throws {
        let image=UIGraphicsImageRenderer(size: CGSize(width: 1600,height: 800)).image { context in UIColor.purple.setFill();context.fill(CGRect(x: 0,y: 0,width: 1600,height: 800)) }
        let original=try #require(image.pngData())
        let result=try WishCoverStore.thumbnail(original)
        let loaded=try #require(UIImage(data: result))
        #expect(max(loaded.size.width,loaded.size.height)<=1200)
        #expect(result != original)
        #expect(throws: (any Error).self) { try WishCoverStore.thumbnail(Data([0,1,2])) }
    }

    @Test("心愿补填价格不改变钱包，已实现与非法金额不可修改")
    func pricing() throws {
        let container=try CheckLinePersistence.makeContainer(inMemory: true)
        let workspace=CheckLineWorkspace(context: container.mainContext)
        let id=try workspace.createWish(name: "Camera",amountText: "",currencyCode: "CNY")
        let balance=workspace.wallet
        try workspace.setWishPrice(id,amount: 120,currency: "CNY")
        #expect(workspace.ledger.wishes[id]?.targetAmount==120)
        #expect(workspace.wallet==balance)
        #expect(throws: (any Error).self) { try workspace.setWishPrice(id,amount: 0,currency: "CNY") }
        #expect(throws: (any Error).self) { try workspace.setWishPrice(id,amount: 120,currency: "INVALID") }
    }
    @Test("明确想买生成待确认心愿草稿，不当成消费，不触发账本写入")
    func wishPhrases() async throws {
        let now = TestDates.day(2026,10,22)
        let parsed = try #require(WishPhrase.draft(from: "想买副耳机，1200元",currency: "CNY",now: now))
        #expect(parsed.name == "副耳机")
        #expect(parsed.amount == "1200")
        #expect(parsed.kind == "agentWishCreate")
        #expect(WishPhrase.draft(from: "昨天午餐35元",currency: "CNY",now: now) == nil)
        #expect(WishPhrase.draft(from: "耳机退款35元",currency: "CNY",now: now) == nil)
        let container=try CheckLinePersistence.makeContainer(inMemory: true)
        let workspace=CheckLineWorkspace(context: container.mainContext)
        let before=workspace.ledger
        workspace.draftText="想买副耳机，1200元"
        await workspace.submitText(now: now)
        #expect(workspace.proposedWishDraft?.name == "副耳机")
        #expect(workspace.ledger == before)
        #expect(workspace.lastTurn == nil)
        #expect(workspace.conversation.count == 2)
        #expect(!workspace.showComposer)
    }

    @Test("球面卡库正反长距离循环不消失")
    func infiniteLoop() {
        for i in -1000...1000 {
            let value=VisualLoop.wrap(CGFloat(i)*371,span: 420)
            #expect(value >= -210 && value < 210)
            #expect(abs(VisualLoop.wrap(CGFloat(i)*371+420,span: 420)-value)<0.0001)
        }
    }

}
