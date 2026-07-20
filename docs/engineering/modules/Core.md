# Core/

业务核心，不依赖 SwiftUI，全部纯逻辑可单测。

| 子目录 | 角色 |
|------|------|
| `Models/` | SwiftData `@Model` 定义（Budget / Wish / Expense / Settlement / WishAllocation 等） |
| `Services/` | 领域服务（BudgetEngine / SettlementEngine / LinkedExpenseDetector / WishLedger / OverrunHandler / CycleScheduler） |
| `Persistence/` | SwiftData 容器、迁移策略、Mock 容器 |
| `Intents/` | App Intents（Widget 与 Shortcuts 共用） |

**纪律**：
- 不要 `import SwiftUI`
- 服务对象通过协议暴露，方便单测替换
- 所有纯计算（扣血、结余、心愿累积）必须有对应单测
