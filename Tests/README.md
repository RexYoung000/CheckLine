# Tests/

Swift Testing 单测。文件夹结构与 `Sources/` 对应，但被测对象放 `Tests/` 下。

放在这里的内容：
- `CoreServicesTests/` — BudgetEngine / SettlementEngine / LinkedExpenseDetector / WishLedger / OverrunHandler 纯函数单测
- `ModelsTests/` — SwiftData 模型的创建、查询、关联账绑定
- `CaptureTests/` — ExpenseDraft 的构建与校验（OCR / Voice 产出的 draft 结构一致性）

**纪律**：
- 用 Swift Testing，不用 XCTest（除非框架限制）
- 领域服务必须可测，纯函数实现
- 不写 UI 截图测试（页面效果由作者人工验收）
- Mock ModelContainer 放在 `Core/Persistence/` 里，测试共用
