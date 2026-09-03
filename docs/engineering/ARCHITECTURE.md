# ARCHITECTURE — CheckLine 技术架构

> 本文定义正式 Xcode 工程事实、新 V1 目标架构与金额模型。SwiftData Schema V1 已建立；不为未发布的旧“多预算重复扣减”样机保留兼容层。

---

## 一、当前工程事实

| 项目 | 当前状态 |
|------|----------|
| 工程 | `Check_Line.xcodeproj` |
| Target / Scheme | `Check_Line` |
| 平台 | iPhone / iPad，最低 iOS 17.0 |
| 当前 UI | `Features/Prototype` 历史启动页（不是新 V1 需求；M4 按 `DESIGN.md` 3.1 替换） |
| 正式数据层 | 领域 `Ledger` + 引擎已落地；App 启动时打开本地 `ModelContainer`（无 CloudKit）。旧样机 UI 仍不读写该账本 |
| Test Target | `Check_LineTests` 覆盖领域引擎、`LedgerStore`、Agent 门禁与理解管线桩 |
| 网络 / 后端 / AI | 理解管线桩已落地（`MockLLMProvider` / 本地回退）；无真实云端 LLM |
| 系统权限 / iCloud | 未启用；SwiftData 配置为 `cloudKitDatabase: .none` |

旧样机的 `budgetIDs` 多预算关系、共享消费删除和旧结算只用于追溯，不是新 Schema 或验收依据。`BudgetEngine` 的 Decimal 基础计算可以继续复用；命名和输入结构在新模型落地时同步收敛。

---

## 二、架构目标

1. **金额可验证**：预算剩余、结算、钱包和待恢复差额全部由确定性领域服务计算。
2. **输入可替换**：文字、语音、图片、Apple Pay、短信、邮件和账单导入共用同一标准化入口。
3. **一笔只结算一次**：交易只有一个结算预算周期，多标签不参与金额。
4. **历史可追溯**：结算后迟到交易和退款通过调整记录修正，不静默覆盖。
5. **设备优先**：完整账本和原始财务数据默认留在设备；云端 AI 只接收用户允许的最少必要字段。
6. **失败可降级**：Agent 或任何被动来源不可用时，手动记录与确定性账本仍可运行。

---

## 三、V1 目标技术栈

| 层 | 目标选择 | 说明 |
|----|----------|------|
| 平台 | iOS 17+ | 当前只有 iPhone / iPad Target；macOS 发布顺序仍待确认 |
| UI | SwiftUI | 使用系统导航和 Sheet 能力，但不由系统默认控件替产品作设计决定 |
| 本地数据 | SwiftData | 金额使用 `Decimal`，不使用 `Double` |
| 同步 | 首发范围待确认 | 当前不启用 iCloud；若后续启用，先设计迁移与冲突策略 |
| 状态 | Observation / `@Observable` | 不引入第三方架构框架 |
| OCR | Vision Framework 优先 | 原图处理后丢弃 |
| 语音 | Speech Framework / 可用端侧能力优先 | 是否完全端侧按语言与系统能力验证 |
| 系统自动化 | App Intents + Shortcuts | Apple Pay、短信等入口按平台公开能力实现 |
| AI | Provider 接口抽象，具体模型待定 | 只做理解、追问和解释，不自由计算金额 |
| 测试 | Swift Testing | 所有领域服务必须覆盖 |

邮箱转发、地区银行连接或云端 AI 如需要后端，必须先更新 `PRIVACY.md`、数据保留策略和合规说明，不能默认接入。

---

## 四、模块边界

```text
App / Navigation
  ↓
Features
  ├─ Home
  ├─ Budget
  ├─ Transactions
  ├─ Settlement
  ├─ Wish
  ├─ DataSources
  └─ AgentPanel
       ↓
Application
  ├─ AgentUnderstander / AgentContextBuilder / IntentValidator
  ├─ LocalRegexFallback / LLMProvider
  ├─ AgentActionCoordinator
  ├─ ConfirmationGate
  ├─ ImportCoordinator
  └─ UndoCoordinator
       ↓
Core
  ├─ Models
  ├─ BudgetEngine
  ├─ AttributionEngine
  ├─ DeduplicationEngine
  ├─ SettlementEngine
  ├─ WalletLedger
  ├─ RetrospectiveAdjustmentEngine
  └─ CurrencyEngine
       ↑
Capture Adapters
  ├─ Manual / Text
  ├─ Voice
  ├─ Image / OCR
  ├─ ApplePay Shortcut
  ├─ SMS Shortcut
  ├─ Email
  └─ Statement Import
```

规则：

- `Core` 不依赖 SwiftUI、具体 AI 模型或具体来源 SDK；
- Capture Adapter 只负责提取来源事实，不直接写预算余额；
- Agent 必须把结构化行动交给 Application/Core 执行；
- `ConfirmationGate` 统一处理高影响动作，不能在不同页面各写一套规则；
- Features 之间共享逻辑下沉到 Application/Core；
- 任何来源失败都不能阻断手动记录和本地账本。

---

## 五、交易处理管线

```text
Source Payload
  ↓
Capture Adapter
  ↓
NormalizedTransactionCandidate
  ↓
DeduplicationEngine
  ├─ 高置信重复 → 合并到现有 Expense，追加 SourceEvidence
  └─ 不确定 → PendingDeduplication
  ↓
AttributionEngine
  ├─ 高置信 → 绑定唯一 BudgetPeriod
  ├─ 低置信 → 暂时绑定 + pending attribution
  └─ 无匹配 → unbudgeted
  ↓
BudgetEngine / Home Projection
```

所有可见状态来自模型投影，不在 View 中维护独立余额。

---

## 六、数据模型

> 以下是正式 Schema 的目标字段。领域计算使用无 UI 依赖的 struct（`Ledger` / `Budget` / `Expense` 等）；SwiftData 镜像为 `Persisted*`。`LedgerStore` 负责读写；App 启动打开本地容器且 `cloudKitDatabase` 为 `.none`。旧样机界面仍不使用该账本。CloudKit 同步尚未进入已确认范围。

### 6.0 `WalletSettings`

唯一心愿钱包的账本级设置，全设备一份，不是按心愿拆分的账户。

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 单例主键 |
| `walletCurrencyCode` | String | 钱包基准币；全账本只有这一个 |
| `setAt` | Date | 用户确认或默认生效时间 |
| `updatedAt` | Date | |

尚未产生任何 `WalletLedgerEntry` 时，`walletCurrencyCode` 默认等于第一张预算卡的 `defaultCurrencyCode`，用户可以改。已有分录后 V1 不得更改该字段。余额和待恢复差额只在该币种内派生。

### 6.1 `Budget`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 主键 |
| `name` | String | 预算卡名称 |
| `defaultAmount` | Decimal | 新周期默认额度；不能反向改变已结算周期 |
| `defaultCurrencyCode` | String | 新周期默认基准币 |
| `cycleTypeRaw` | String | `repeating` / `oneShot` |
| `recurrenceRule` | String? | 循环规则，按可迁移格式存储 |
| `optionalDeadline` | Date? | 一次性预算可无截止日期 |
| `stateRaw` | String | `draft` / `active` / `pendingSettlement` / `archived` |
| `sortIndex` | Int | 首页固定顺序 |
| `createdAt` | Date | 创建时间 |
| `updatedAt` | Date | 最后修改时间 |

### 6.2 `BudgetPeriod`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 主键 |
| `budget` | Budget | 所属预算卡 |
| `budgetAmount` | Decimal | 本周期额度快照，历史周期不随 Budget 默认值变化 |
| `currencyCode` | String | 本周期结算基准币 |
| `startDate` | Date | 周期开始 |
| `endDate` | Date? | 无截止日期的一次性预算可为空 |
| `stateRaw` | String | `active` / `pendingSettlement` / `settled` |
| `sequence` | Int | 循环周期序号 |
| `createdAt` | Date | |

到期后尚未结算的新交易不绑定旧周期，使用 `Expense.queuedForBudget` 暂存。新周期创建时复制 Budget 的默认额度/币种，再一次性绑定队列记录。已结算 `BudgetPeriod` 的额度和币种不可直接改写，后续变化使用调整记录。

### 6.3 `Expense`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 同一笔交易只存一份 |
| `originalAmount` | Decimal | 原币金额 |
| `originalCurrencyCode` | String | 原币 |
| `postedAmount` | Decimal? | 银行实际入账金额 |
| `postedCurrencyCode` | String? | 实际入账币种 |
| `estimatedBudgetAmount` | Decimal? | 未入账时暂估金额 |
| `estimateRateSource` | String? | 汇率来源与时间摘要 |
| `kindRaw` | String | `purchase` / `refund` |
| `reversesExpense` | Expense? | 退款所追溯的原消费；普通消费为空 |
| `occurredAt` | Date | 发生时间 |
| `merchant` | String? | 商家 |
| `note` | String? | 备注 |
| `budgetPeriod` | BudgetPeriod? | 唯一结算周期；为空表示未纳入或排队 |
| `queuedForBudget` | Budget? | 循环卡待结算空窗期间的下周期队列 |
| `attributionStateRaw` | String | `confirmed` / `pending` / `unbudgeted` |
| `attributionConfidence` | Decimal? | 仅用于解释，不直接决定金额规则 |
| `tags` | [ExpenseTag] | 多标签，不参与金额扣减 |
| `sourceEvidence` | [SourceEvidence] | 一个或多个来源证据 |
| `wishRedemption` | WishRedemption? | 属于心愿兑现时设置；此时不得绑定普通预算周期 |
| `createdAt` | Date | |
| `updatedAt` | Date | |

**结算金额派生顺序**：

1. 若有与预算基准币一致的 `postedAmount`，使用实际入账；
2. 否则使用明确标记的 `estimatedBudgetAmount`；
3. 原币金额始终保留；
4. 最终入账更新同一 `Expense`，不创建重复交易；
5. 退款作为独立证据记录并链接 `reversesExpense`，金额影响由追溯调整引擎作用到原周期，不计入当前周期制造新结余。

### 6.4 `ExpenseTag`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | |
| `name` | String | 餐饮、人情、聚会等 |
| `createdAt` | Date | |

标签只表达含义，不拥有额度，不参与结算。

### 6.5 `SourceEvidence`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | |
| `expense` | Expense | 所属交易 |
| `sourceTypeRaw` | String | `manual` / `agentText` / `voice` / `image` / `applePay` / `sms` / `email` / `statement` |
| `externalReferenceHash` | String? | 来源侧标识的本地不可逆摘要，不存账号明文 |
| `capturedAt` | Date | 捕获时间 |
| `coverageTimestamp` | Date? | 该来源覆盖到的时间 |
| `metadataEnvelope` | Data? | 只存去重必要的最少结构化字段，不存原图/原音频 |

### 6.6 `DataSourceConnection`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | |
| `sourceTypeRaw` | String | Apple Pay / 短信 / 邮箱 / 账单导入等 |
| `stateRaw` | String | `disconnected` / `connected` / `needsAttention` |
| `lastCoveredAt` | Date? | 最后覆盖时间 |
| `coverageNote` | String? | 对用户可读的缺口说明 |
| `lastErrorCode` | String? | 脱敏错误码，不保存真实金融数据 |
| `updatedAt` | Date | |

### 6.7 `Settlement`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | |
| `period` | BudgetPeriod | 唯一周期 |
| `settledAt` | Date | 用户确认时间 |
| `budgetAmountSnapshot` | Decimal | 结算时的周期额度 |
| `currencyCode` | String | 结算基准币 |
| `confirmedSpent` | Decimal | 当时确认的支出 |
| `baseSurplus` | Decimal | `budgetAmountSnapshot - confirmedSpent`，可正可负 |
| `coverageSnapshot` | Data? | 结算时各来源覆盖的结构化快照 |
| `acceptedIncompleteData` | Bool | 用户是否明确接受仍可能不完整的数据 |
| `createdWalletEntry` | WalletLedgerEntry? | 对钱包账本的基础影响 |

### 6.8 `SettlementAdjustment`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | |
| `settlement` | Settlement | 被修正的原结算 |
| `reasonRaw` | String | `lateExpense` / `refund` / `postedAmountChange` |
| `amountDelta` | Decimal | 对原周期支出的变化 |
| `confirmedAt` | Date | 用户确认时间 |
| `sourceExpense` | Expense? | 追溯来源 |
| `walletEntry` | WalletLedgerEntry? | 对钱包的对应调整 |

原 `Settlement` 保留当时事实，当前有效结果由基础值加全部调整派生。

### 6.9 `WalletLedgerEntry`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | |
| `typeRaw` | String | `surplus` / `overrun` / `wishRedemption` / `refund` / `retrospectiveAdjustment` |
| `sourceSignedAmount` | Decimal | 来源币种金额：结余为正，越线和兑现为负 |
| `sourceCurrencyCode` | String | 来源币种 |
| `walletSignedAmount` | Decimal | 换算为钱包基准币后的金额；同币种时等于 `sourceSignedAmount` |
| `walletCurrencyCode` | String | 写入时的钱包基准币，必须等于当时的 `WalletSettings.walletCurrencyCode` |
| `conversionSnapshot` | Data | 汇率、来源（`posted` / `estimated` / `identity`）和时间；同币种也记录 identity |
| `settlement` | Settlement? | 结算来源 |
| `adjustment` | SettlementAdjustment? | 追溯来源 |
| `wishRedemption` | WishRedemption? | 心愿来源 |
| `occurredAt` | Date | |
| `note` | String? | 用户可读摘要，不存敏感原文 |

**唯一钱包计算（同一钱包基准币内）**：

```text
net = sum(WalletLedgerEntry.walletSignedAmount)
walletBalance = max(net, 0)
recoveryGap = max(-net, 0)
```

因此待恢复差额不是第二个账户，也不需要单独维护可漂移的余额字段。

**换算规则**（`CurrencyEngine`，金额规则见 `PRODUCT.md` 第 6.5 节）：

```text
确认结算 / 兑现 / 退款 / 追溯调整
  ↓
sourceSignedAmount + sourceCurrencyCode
  ↓
sourceCurrency == walletCurrency
  ├─ 是 → walletSignedAmount = sourceSignedAmount；snapshot.kind = identity
  └─ 否 → 优先实际入账汇率，否则确认页可见的暂估汇率
         得不到汇率则拒绝写入
  ↓
写入 WalletLedgerEntry（含 conversionSnapshot）
```

事后汇率变化不回写旧分录。入账差异或迟到交易先按预算基准币算差额，再在用户确认该调整时换算为新的钱包分录。V1 在已有分录后拒绝更改 `WalletSettings.walletCurrencyCode`。

### 6.10 `Wish`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | |
| `name` | String | 用户真实表达的心愿 |
| `targetAmount` | Decimal? | 参考价格，可空 |
| `currencyCode` | String? | 参考价格币种 |
| `referenceURL` | String? | 商品链接，可空 |
| `stateRaw` | String | `active` / `completed` / `archived` |
| `createdAt` | Date | |
| `completedAt` | Date? | |

Wish 不持有独立余额。

### 6.11 `WishRedemption`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | |
| `wish` | Wish | |
| `expense` | Expense? | 捕获到真实交易时关联 |
| `actualAmount` | Decimal | 实际成交金额 |
| `currencyCode` | String | 实际成交币种 |
| `confirmedAt` | Date | 用户确认时间 |
| `stateRaw` | String | `completed` / `refunded` |
| `walletEntry` | WalletLedgerEntry | 对钱包的实际扣减 |

创建前必须按钱包基准币换算后的余额校验是否足够。目标价格不参与扣款。跨币种兑现与结算使用同一套确认时换算规则；得不到可展示汇率时不能完成兑现。

### 6.12 `MatchingRule`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | |
| `humanReadableRule` | String | 给用户看的规则摘要 |
| `structuredPredicate` | Data | 可确定执行的条件 |
| `targetBudget` | Budget? | 目标结算预算卡 |
| `targetTags` | [ExpenseTag] | 可选标签 |
| `stateRaw` | String | `proposed` / `active` / `disabled` |
| `confirmedAt` | Date? | 批量/未来应用前的用户确认 |

---

## 七、关键领域服务

金额计算以 `Check_Line/Core/Services` 中的纯 Swift 引擎为准，输入输出都是领域 struct，不读写 SwiftUI 状态。

| Service | 职责 |
|---------|------|
| `BudgetEngine` | 计算周期已用、剩余、进度和风险输入 |
| `CycleEngine` | 周期到期、待结算、下周期队列和新周期创建 |
| `AttributionEngine` | 唯一预算归属、低置信和未纳入状态 |
| `DeduplicationEngine` | 跨来源重复判断和证据合并 |
| `CurrencyEngine` | 原币、暂估、实际入账、预算基准币金额，以及进入钱包时的确认换算与快照 |
| `SettlementEngine` | 结算预览、数据覆盖检查、确认提交 |
| `WalletLedger` | 追加账本、派生钱包余额与待恢复差额 |
| `WishRedemptionEngine` | 余额校验、实际购买扣减和退款 |
| `RetrospectiveAdjustmentEngine` | 迟到交易、退款和入账差异的追溯影响预览 |
| `AgentContextBuilder` | Application：从账本投影只读上下文（卡名/周期/货币、最近商家、标签；不含金额与钱包） |
| `AgentUnderstander` | Application：本地拒答 → `LLMProvider` → 失败则 `LocalRegexFallback` → `IntentValidator` |
| `IntentValidator` | Application：把未信任的 `AgentIntentCandidate` 校验成 `AgentIntent` 或 `needsClarification` |
| `AgentActionCoordinator` | Application：将结构化意图路由到领域服务，不自行计算余额 |
| `ConfirmationGate` | Application：按风险决定直接执行、确认结构、确认影响或拒绝 |
| `UndoCoordinator` | Application：低风险记一笔的账本快照撤销 |

所有 Service 必须使用 `Decimal` 并有 Swift Testing 单测。

---

## 八、结算事务

```text
生成结算预览
  · 锁定 period 当前交易快照
  · 读取 pending / unbudgeted / data source coverage
  · 计算 confirmedSpent 与预估 baseSurplus
  · 计算钱包影响（含跨币种确认换算预览）
  ↓
用户处理关键项或接受不完整数据
  ↓
ConfirmationGate 展示最终影响并确认
  ↓
单一事务提交
  · 创建 Settlement
  · 追加 WalletLedgerEntry
  · period → settled
  · repeating: 创建新 period 并迁移 queued expenses
  · oneShot: Budget → archived
```

任何一步失败都回滚整个提交，避免预算结算成功但钱包未更新。

---

## 九、Agent 安全边界

- LLM 输出只能是结构化候选意图，不能直接写数据库；当前 M2 由 `AgentUnderstander` 产出 `AgentIntent`，再交给 `AgentActionCoordinator`，金额一律回算自 Core；
- 所有金额重新由 Core 校验和计算；
- LLM 不得编造汇率或钱包数字；跨币种写入必须使用 `CurrencyEngine` 的确认换算结果；
- 低风险单笔新增可执行后提供撤销（`UndoCoordinator`）；
- 调额度、改周期、删除、批量修改、结算、钱包和追溯必须经过 `ConfirmationGate`；
- Agent 不可见完整账本，除非任务确实需要且用户已允许；
- 云端请求只发送完成当前判断所需的最少字段；
- Agent 不可调用投资、借贷、保险、税务等产品范围外动作。

### 9.1 Agent Harness 规格

#### 9.1.1 整体管线

```text
用户输入（文字 / 语音转写 / OCR 文字）
  ↓
AgentContextBuilder
  · 从 Ledger 投影生成只读上下文
  · 只含：活跃预算卡名称 + 周期 + 货币、
         最近 ≤10 条去重商家名、已有标签名
  · 不含：金额、完整记录、钱包余额
  ↓
LLMProvider.complete(prompt, context) → AgentIntentCandidate
  ↓
IntentValidator
  · 校验 amount 是否 Decimal、periodID 是否存在等
  · 校验不过 → needsClarification（交给 UI）
  ↓
ConfirmationGate.decide(...)
  ├─ executeDirectly → AgentActionCoordinator → Core
  ├─ confirmStructured → 返回 UI 让用户确认
  ├─ confirmImpact → 返回 UI 展示领域预览
  └─ refuse → 返回 UI 说明原因
```

模型只做约束结构化输出——接收用户输入 + 上下文，返回一个经校验的 `AgentIntent`。不能调工具、不算余额、不直接写库。模型侧不暴露任何 function-calling / tool-use；执行由 `AgentActionCoordinator` + Core 引擎完成。

#### 9.1.2 LLMProvider 协议

```swift
protocol LLMProvider: Sendable {
    func complete(prompt: AgentPrompt) async throws -> AgentIntentCandidate
}
```

- V1 目标实现是云端 HTTP；当前代码只有 `MockLLMProvider`，不发起网络请求。
- 离线或失败 → `LocalRegexFallback` 提取金额/商家，归属留空。
- `AgentIntentCandidate` 是模型返回的未校验 JSON（金额字段为字符串）；经 `IntentValidator` 解码和校验后才生成正式 `AgentIntent` 或 `needsClarification`。

#### 9.1.3 AgentPrompt 与上下文构建规则

- **system prompt 固定**：角色 + 可返回的 intent 类型 + JSON schema。
- **user message** = 用户原文（文字 / 语音转写 / OCR 提取的文字）。
- **context** = `AgentContextBuilder.build(ledger)` 的 JSON，内容：
  - 活跃预算卡名称、周期、货币
  - 最近 ≤10 条去重商家名
  - 已有标签名
  - **不含**：金额、完整交易记录、商家历史明细、钱包余额
- 语音：先 Speech → text，用同一条 prompt。
- 图片：先 Vision OCR → text，用同一条 prompt。
- 如果用户显式 opt-in「发给模型帮我看」，才发 base64（V1 不默认开启）。

#### 9.1.4 一问一答与追问

- 模型只返回一次。
- 返回 `needsClarification(field, options)` 时，UI 展示选项/表单，用户选完后本地组装 `AgentIntent`，不再调模型。
- 不存在多轮 session / history。

#### 9.1.5 离线降级

- Agent 入口始终可见。
- 离线或模型不可用 → `LocalRegexFallback`：
  - 正则提取：金额、货币符号、商家关键词。
  - 填入 `CaptureDraft(amount, currency, merchant)`。
  - 归属留 `nil` → `ConfirmationGate` 判为 `confirmStructured` → UI 引导用户选预算卡。
- 查询、结算、心愿等动作离线时全部可用——纯本地 Core 计算，不依赖模型。

#### 9.1.6 多模态输入统一

```text
文字 ───────────────────────→ prompt text ─→ LLMProvider / Fallback
语音 ─→ SpeechAdapter → text → prompt text ─→ LLMProvider / Fallback
图片 ─→ VisionOCRAdapter → text → prompt text ─→ LLMProvider / Fallback
```

三条路汇入同一个 `LLMProvider.complete()` 或 `LocalRegexFallback`。原音频和原图处理后丢弃，不发云端。

---

## 十、隐私与数据保留

- 完整 Expense、Settlement、WalletLedger 默认仅存用户设备本地；iCloud 尚未进入已确认首发范围；
- 图片和语音原始数据处理后丢弃；
- 短信、邮件只提取交易必要字段，不保存整段无关内容；
- 来源账号标识优先保存不可逆摘要；
- 调试日志不得输出真实金额、商家、邮箱、短信或心愿名称；
- 云端 AI、邮箱转发和地区连接器上线前必须分别完成数据流审查。

详细规则见 `../compliance/PRIVACY.md`。

---

## 十一、迁移说明

当前仓库没有已发布的正式 SwiftData 账本，因此：

- 领域引擎与 `CheckLineSchemaV1` 从本文模型新建，不为旧样机 `budgetIDs` 建立兼容层；
- App 通过 `CheckLinePersistence.makeAppContainer()` 打开本地容器，失败时回退内存容器；`LedgerStore` 做领域账本整本替换读写；
- 当前启动页不调用 `LedgerStore`，因此不会把旧样机 Sample 写入 Schema；
- `Features/Prototype` 中的 `budgetIDs`、共享消费删除和旧结算保持为历史样机，M4 替换启动页；不作为新 Schema 或验收依据；
- 旧草案的 `BudgetExpenseBinding` 和 `WishAllocation` 不进入正式 Schema；
- 旧 `PrototypeDeletionTests` 不作为新 V1 验收；新归属测试覆盖“一笔消费一个结算周期”；
- 若后续发现已有真实用户数据，必须暂停并重新制定迁移计划。

---

## 十二、待技术确认

- SwiftData 对上述关系和 `Data` 快照字段的最终兼容性；
- 预算 recurrence rule 的可迁移编码格式；
- Apple Pay 与银行短信自动化在目标系统版本的真实事件字段；
- 邮件入口是否完全端侧，还是需要最小中转服务；
- AI Provider、端侧/云端分工和离线降级；
- 暂估汇率的具体系统/服务来源（产品只要求确认页可见来源名称与时间，不绑定供应商）；
- 多设备并发结算的冲突策略（若启用同步）；
- 各地区银行连接器和隐私合规要求。
