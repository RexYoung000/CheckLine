# ARCHITECTURE - CheckLine 技术架构

本文定义当前 Xcode 工程事实、第一轮 MVP 的模块与数据边界，以及后续能力进入工程的条件。产品范围以根目录 `PRODUCT.md` 和 `docs/product/PRD.md` 为上位依据。

## 一、当前工程事实

| 项目 | 当前状态 |
|---|---|
| 工程 | `Check_Line.xcodeproj` |
| Target / Scheme | `Check_Line` |
| 产品 | iPhone / iPad App |
| 最低系统 | iOS 17.0 |
| UI | SwiftUI |
| 当前启动页 | 当前浅色预算钱包 SwiftUI 体验样机 |
| 正式数据层 | 未实现 |
| Test Target | 未建立 |
| 外部依赖 | 无 |
| 网络 / 后端 | 无 |
| iCloud / CloudKit | 未启用，后续阶段 |

当前构建用于验证 Xcode 工程、资源与当前浅色预算钱包交互能够运行，不代表第一轮 MVP 的正式数据层、领域服务和测试已经实现。

### 1.1 当前体验样机边界

- 启动页使用原生 SwiftUI 实现当前 HTML 原型的四 Tab、钱包横滑、记一笔、预算、统计、日历、设置和结算体验。
- 状态只存在于当前运行周期，使用 `Decimal` 与虚构示例数据，不写入磁盘。
- 体验样机类型保留在 `Features/Prototype`，不冒充 `Core/Models`、SwiftData Schema 或正式领域服务。
- 正式 MVP 实装时以本文第五至第七节的数据模型与服务边界替换样机状态，不能把样机模型直接当作持久化模型。
- 交互控件优先使用 SwiftUI 原生组件；品牌自定义组件仅承载卡片、图表、进度视觉和反馈展示，不模拟系统导航、表单、选择器或列表语义。

## 二、技术选择

### 第一轮 MVP

| 层 | 选择 | 原因 |
|---|---|---|
| UI | SwiftUI | 原生 iOS、无障碍与后续 Widget 复用 |
| 状态 | SwiftUI 状态 + `@Observable` | 当前复杂度不需要第三方状态框架 |
| 数据 | SwiftData 本地存储 | iOS 17 原生、模型与 SwiftUI 集成简单 |
| 金额 | `Decimal` | 避免浮点金额误差 |
| 测试 | Swift Testing | 领域服务与模型关系作为合并底线 |
| 格式化 | Foundation FormatStyle | 统一货币、日期和百分比本地化 |

### 后续阶段

以下能力不是当前架构事实，启动前必须重新更新本文：

- 第二轮：Widget、通知、Photos + Vision OCR、Speech 语音录入。
- 第三轮：心愿数据模型与结算分配关系。
- 第四轮：App Intents、Shortcuts、分享扩展、Live Activities、macOS Target。
- iCloud：产品与数据迁移策略确认后再启用 CloudKit，不在本地 MVP 中预接。

## 三、仓库结构

```text
CheckLine/
├── Check_Line.xcodeproj/       正式 Xcode 工程
├── Check_Line/                 主 App Target 文件系统同步目录
│   ├── App/                    App 入口与根导航
│   ├── Features/               按用户能力拆分的功能模块
│   ├── Core/                   模型、领域服务、持久化
│   ├── Capture/                记一笔入口，当前只实现 Manual
│   ├── DesignSystem/           Token、组件、动效、Haptic
│   ├── Shared/                 格式化、错误与平台封装
│   ├── Resources/              本地化与 Sample 数据
│   └── Assets.xcassets
├── docs/                       当前文档、设计资料与历史档案
└── scripts/                    原型辅助脚本
```

当前磁盘中尚未出现的模块目录属于实施目标，不需要为结构完整提前创建空目录。

## 四、模块边界

```text
App
 ├── Features
 │    ├── Budget
 │    ├── Expense
 │    ├── Settlement
 │    ├── Insights
 │    └── Settings
 ├── Capture/Manual
 ├── Core
 │    ├── Models
 │    ├── Services
 │    └── Persistence
 ├── DesignSystem
 └── Shared
```

约束：

- `App` 只装配根导航、环境和依赖，不放业务计算。
- Feature 之间不直接互相 import；共享规则进入 `Core/Services`。
- `Core` 不 import SwiftUI，金额和结算逻辑保持纯 Swift 可测。
- Feature 不直接散落 SwiftData 查询，统一通过 Core 提供的查询或服务边界。
- `Capture/Manual` 产出统一 `ExpenseDraft`，提交前必须由用户确认。
- `DesignSystem` 不依赖 Feature。
- 平台条件代码集中到 `Shared/Platform`。
- 没有进入当前里程碑的 Widget、OCR、Voice、Wish、Intents 不预建实现。

## 五、第一轮 MVP 数据模型

这些字段是当前实施基线。任何增删、改名或类型变化都先更新本文，再设计 SwiftData Schema 与迁移。

### 5.1 Budget

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | UUID | 本地主键 |
| `name` | String | 预算名称 |
| `themeTemplate` | String | `monthly / travel / study / custom` |
| `cycleType` | String | `repeating / oneShot` |
| `startDate` | Date | 周期开始 |
| `endDate` | Date | 周期结束 |
| `totalAmount` | Decimal | 预算总额 |
| `currencyCode` | String | 默认 `CNY` |
| `overrunStrategy` | String | `warnOnly / strictReview` |
| `state` | String | `draft / active / settling / archived` |
| `createdAt` | Date | 创建时间 |

不持久化的派生值：

- `spent`：有效 binding 的 `recordedAmount` 合计。
- `remaining`：`totalAmount - spent`。
- `progress`：`spent / totalAmount`，总额为 0 时按明确边界返回。

当前 Budget 不包含 `defaultWish` 或任何心愿关系。

### 5.2 BudgetCategory

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | UUID | 本地主键 |
| `budget` | Budget | 所属预算 |
| `name` | String | 分类名称 |
| `allocatedAmount` | Decimal | 分类额度 |
| `iconName` | String | SF Symbol 名称 |
| `colorHex` | String | 主题色 |
| `sortIndex` | Int | 用户排序 |

### 5.3 Expense

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | UUID | 一笔消费只存一份 |
| `amount` | Decimal | 消费金额 |
| `note` | String? | 用户备注 |
| `occurredAt` | Date | 发生时间 |
| `captureSource` | String | 当前只有 `manual` |
| `createdAt` | Date | 创建时间 |

OCR、语音、Widget 等来源进入对应阶段时再扩展 `captureSource`，不为未来来源提前增加权限或业务字段。

### 5.4 BudgetExpenseBinding

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | UUID | 本地主键 |
| `budget` | Budget | 被计入的预算 |
| `expense` | Expense | 同一笔消费 |
| `category` | BudgetCategory | 该预算下的分类 |
| `recordedAmount` | Decimal | 在该预算中计入的金额，默认等于 Expense.amount |
| `finalAttribution` | String? | 结算确认后的 `included / excluded` |
| `createdAt` | Date | 建立关系时间 |

一笔消费选择两个预算时生成两个 binding，但 Expense 只有一份。关联账处理必须由用户确认，系统不自动选归属。

### 5.5 Settlement

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | UUID | 本地主键 |
| `budget` | Budget | 被结算预算 |
| `settledAt` | Date | 结算时间 |
| `totalSpent` | Decimal | 用户确认后的最终支出 |
| `surplus` | Decimal | `totalAmount - totalSpent` |
| `triggerType` | String | `auto / manual` |

当前 Settlement 只保存结算结果，不包含 `WishAllocation`。

## 六、领域服务

| 服务 | 当前职责 |
|---|---|
| `BudgetEngine` | 计算已用、剩余、进度、分类状态 |
| `SettlementEngine` | 生成结算清单并计算最终支出与结余 |
| `LinkedExpenseDetector` | 按 ExpenseID 识别一笔多属 |
| `OverrunPolicy` | 生成 `warnOnly / strictReview` 对应的用户反馈，不自动挪钱 |
| `CycleScheduler` | 处理重复型下一周期和单次型归档 |
| `Formatters` | 统一货币、日期与百分比展示 |

当前没有 `WishLedger`、`deductFromWish` 或结算转心愿服务。

## 七、关键数据流

### 记一笔

```text
用户输入金额
 -> 选择一个或多个预算
 -> 为每个预算选择分类
 -> 用户点击「记下这笔」
 -> 创建一份 Expense
 -> 为每个已选预算创建一份 Binding
 -> BudgetEngine 重新派生各预算状态
```

### 结算

```text
预算到期或用户主动进入结算
 -> SettlementEngine 汇总 binding
 -> LinkedExpenseDetector 列出关联账
 -> 用户确认每条关联账归属
 -> 重新计算 totalSpent 与 surplus
 -> 保存 Settlement
 -> 重复型开启下一周期 / 单次型归档
```

## 八、存储与隐私边界

- 第一轮 MVP 只使用本地 SwiftData，不启用 CloudKit。
- 不连接银行、支付宝、微信或任何真实资金账户。
- 不接自有后端，不上传预算、金额、分类或备注。
- 不接 Analytics、Tracking、广告或第三方崩溃收集 SDK。
- Sample 数据使用虚构名称和金额。
- 日志不得输出真实金额、预算名或备注。

## 九、本地化与错误

- App 默认名 `CheckLine`，简体中文通过 `InfoPlist.strings` 显示「预算线」。
- 所有用户可见字符串同时维护 `zh-Hans` 与 `en`。
- 金额使用 `Decimal.FormatStyle.Currency`，日期使用系统 FormatStyle。
- 用户错误不暴露 SQLite、SwiftData 或系统错误码。
- 可恢复错误由 ViewModel 转换为用户可理解的状态，Service 不使用 `fatalError()`。

## 十、测试基线

当前没有 Test Target。开始正式模型与服务实现前必须先建立 Swift Testing Target。

最低覆盖：

- BudgetEngine 的 0 金额、边界金额、超出金额与多 binding。
- SettlementEngine 的重复型、单次型、结余与负结余。
- LinkedExpenseDetector 的单预算、多预算、包含/排除确认。
- OverrunPolicy 的两种策略，确认不会自动修改其他预算。
- SwiftData 的模型关系、删除行为和迁移。

UI 仍需在 iPhone 小屏、Pro Max、iPad 分屏和 Dynamic Type 下人工验收。

## 十一、依赖与能力门槛

- 当前不引入第三方运行时依赖。
- 新依赖必须说明解决的问题、包体与维护成本、隐私影响和可替代方案。
- iCloud、Widget、通知、OCR、语音或新 Target 启动前，先同步路线图、权限、隐私与架构。
- 心愿阶段启动前，先更新 PRODUCT、PRD、FEATURE-LOOP、GLOSSARY 和本文，再设计 Schema。

## 十二、已知缺口

- 当前 SwiftUI 体验样机已对齐现行产品文案，但尚未接入正式 MVP 数据层与领域服务。
- SwiftData Schema 与迁移计划尚未建立。
- Test Target 和 CI 尚未建立。
- 真机签名、App 图标和 App Store 配置尚未完成。

## 相关文档

- `../../PRODUCT.md`
- `../product/PRD.md`
- `../product/FEATURE-LOOP.md`
- `../product/ROADMAP.md`
- `../design/DESIGN.md`
- `SETUP.md`
- `PERMISSIONS.md`
- `../compliance/PRIVACY.md`
