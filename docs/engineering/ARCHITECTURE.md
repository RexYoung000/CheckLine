# ARCHITECTURE — 预算线 CheckLine 技术架构

> 这份文档定义工程结构、技术栈、模块边界、数据模型。
> 改架构前先更新这份文档，再动代码。
> 配套阅读：`PRODUCT.md`（产品宪法）、`FEATURE-LOOP.md`（功能架构循环）。

---

## 一、技术栈

| 层 | 选择 | 理由 |
|----|------|------|
| 平台 | iOS 17+ / macOS 14+（multiplatform App） | 一套代码两端跑，主开发在 Mac，iOS 借测试机验收 |
| UI | SwiftUI | 声明式、跨平台、Widget 友好 |
| 数据 | SwiftData | 比 Core Data 轻量，原生 SwiftUI 集成，支持 iCloud |
| 同步 | iCloud（CloudKit + SwiftData） | 免费、零运维、Mac/iPhone 互通 |
| 状态 | SwiftUI 内置 + `@Observable` 服务对象 | 不引入第三方架构框架 |
| 测试 | Swift Testing（默认）+ XCTest（必要时） | 新项目用新框架 |
| OCR | Vision Framework | 端侧识别支付截图 |
| 语音 | Speech Framework + 端侧 AI 解析 | 离线、隐私 |
| 自动化 | App Intents + Shortcuts | iOS 自动化录入入口 |
| 包管理 | Swift Package Manager | 内置 |
| 最低系统 | iOS 17 / macOS 14 | SwiftData / Observation 起步要求 |

**不用的东西**：Combine（除非必要）、第三方架构框架、第三方记账 SDK。

---

## 二、目录结构

工作目录：`/Users/rexyoung/Desktop/vibe coding/mac&ios/CheckLine/`

```
CheckLine/
├── README.md              ← 文档门户与导航
├── AGENTS.md              ← 协作规则
├── PRODUCT.md             ← 产品宪法（根目录最常读）
├── .gitignore
│
├── CheckLine.xcodeproj/   ← Xcode 工程（按 docs/engineering/SETUP.md 创建后存在）
│
├── docs/
│   ├── spec/              ← 产品规格层
│   │   ├── PRD.md                ← 完整产品需求
│   │   ├── FEATURE-LOOP.md       ← 功能架构循环
│   │   ├── USER-JOURNEY.md       ← Day 1-30 用户旅程
│   │   ├── ROADMAP.md            ← 路线图
│   │   └── GLOSSARY.md           ← 术语表
│   ├── design/            ← 设计层
│   │   └── DESIGN.md             ← 设计规范
│   ├── engineering/       ← 技术层
│   │   ├── ARCHITECTURE.md       ← 本文件
│   │   ├── SETUP.md              ← Xcode 工程对接
│   │   └── PERMISSIONS.md        ← iOS 权限申请文案与时机
│   ├── compliance/        ← 合规层
│   │   └── PRIVACY.md            ← 隐私说明
│   ├── ui-workflow/       ← UI workflow 分析报告
│   └── prototype/         ← Stitch 原型 brief 与生成物
│
├── Sources/
│   ├── App/               ← App 入口、根 Scene、Tab/Sidebar
│   ├── Features/          ← 业务功能模块（按用户视角拆分）
│   │   ├── Budget/        ← 预算钱包创建、列表、详情、主屏预算状态
│   │   ├── Expense/       ← 记一笔（含归类弹窗、多入口分发）
│   │   ├── Settlement/    ← 结算清单、关联账确认、结算高光
│   │   ├── Wish/          ← 心愿设定、进度、达成庆祝
│   │   └── Insights/      ← 统计概览、分类分析、消费记录日历（PRD/Stitch 先完整覆盖）
│   ├── Core/              ← 业务核心（与 UI 解耦）
│   │   ├── Models/        ← SwiftData @Model 定义
│   │   ├── Services/      ← 领域服务：BudgetEngine / SettlementEngine 等
│   │   ├── Persistence/   ← SwiftData 容器、迁移、Mock 容器
│   │   └── Intents/       ← App Intents（Widget / Shortcuts 共用）
│   ├── Capture/           ← 录入子系统（多入口）
│   │   ├── Manual/        ← 手动归类弹窗
│   │   ├── OCR/           ← 截图识别
│   │   ├── Voice/         ← 语音记一笔
│   │   └── Share/         ← 分享扩展（v1.1）
│   ├── DesignSystem/      ← 颜色、字体、间距、组件、动效
│   └── Shared/            ← 工具类、扩展、Localization 辅助
│
├── Widgets/               ← Widget Extension 源码
│   ├── BudgetStatusWidget/      ← 预算剩余 + 心愿进度
│   └── QuickCaptureWidget/      ← 锁屏速记入口
│
├── Tests/
│   └── CheckLineTests/    ← Swift Testing 单测，对应 Core/Features
│
├── Resources/
│   ├── Assets.xcassets    ← 颜色、图标
│   ├── Localizations/     ← zh-Hans、en（命名分区在这里）
│   │   ├── zh-Hans.lproj/InfoPlist.strings   ← CFBundleDisplayName = 预算线
│   │   └── en.lproj/InfoPlist.strings        ← CFBundleDisplayName = CheckLine
│   └── Sample/            ← 调试用 sample 数据
│
└── planning/              ← 不在本仓库，参考 ../planning/
```

> 实际 Xcode 工程的 Group 结构与上面磁盘目录保持一一对应，避免出现「工程里看到 A，磁盘上找不到 A」。

---

## 三、模块边界（重要）

```
App
 ↓
Features (Budget / Expense / Settlement / Wish / Insights)
 ↓                                   ↓
Capture (Manual / OCR / Voice)       │
 ↓                                   │
Core (Models / Services / Persistence / Intents)  ← DesignSystem  ← Shared
 ↑
Widgets （只读 Core）
```

规则：
- **Features 之间不能直接互相 import**。两个 Feature 共用的逻辑下沉到 `Core/Services/`。
- **Core 不能 import SwiftUI**（保持纯逻辑可测）。
- **Capture 子模块只能向上调用 Core**，不能跨 Feature。
- **DesignSystem 不能 import Features**（被所有 Feature 共用）。
- **Widgets 只读 Core / Intents**，不依赖 Features。
- **App Intents 必须放在 Core/Intents/**，因为 Widget Extension 也要共用。

> AI 协作时如果发现要跨边界引用，先停下来跟产品（你）对齐：是不是需要把某段逻辑下沉。

---

## 四、数据模型（基于功能架构循环）

> 用 SwiftData，下面是字段表，进 Xcode 后翻成 `@Model class`。

### 4.1 `Budget` 预算

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 主键 |
| `name` | String | 例：「6 月生活」「京都旅行」 |
| `themeTemplate` | String | 模板枚举：`monthly` / `travel` / `date` / `study` / `custom` |
| `cycleType` | enum | `repeating`（重复型）/ `oneShot`（单次型） |
| `startDate` | Date | 周期开始 |
| `endDate` | Date | 周期结束 |
| `totalAmount` | Decimal | 预算总额 |
| `currencyCode` | String | 默认 `CNY` |
| `categories` | [BudgetCategory] | 分类列表（关系） |
| `overrunStrategy` | enum | `warnOnly` / `deductFromWish` |
| `defaultWish` | Wish? | 预设结余转入心愿，可空 |
| `state` | enum | `draft` / `active` / `settling` / `archived` |
| `createdAt` | Date | |

**派生属性（运行时算，不持久化）**：
- `spent`：本预算已用总和
- `remaining`：`totalAmount - spent`
- `progress`：`spent / totalAmount`

### 4.2 `BudgetCategory` 预算分类

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | |
| `budget` | Budget | 所属预算 |
| `name` | String | 例：「伙食」「聚会」「市内交通」 |
| `allocatedAmount` | Decimal | 分到该类的额度 |
| `iconName` | String | SF Symbol 名 |
| `colorHex` | String | 主题色 |
| `sortIndex` | Int | 排序 |

### 4.3 `Expense` 一笔消费

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 主键（同一笔只有一份） |
| `amount` | Decimal | 金额 |
| `note` | String? | 备注 |
| `occurredAt` | Date | 发生时间 |
| `captureSource` | enum | `manual` / `widget` / `ocr` / `voice` / `share` / `shortcut` |
| `bindings` | [BudgetExpenseBinding] | 关联的预算们（多对多） |
| `merchantHint` | String? | OCR / 通知抓到的商户线索 |

### 4.4 `BudgetExpenseBinding` 预算-消费 关联表

> 多对多中间表。一笔消费在每个被关联的预算里都有一条 binding，预算消耗是按 binding 算的。

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | |
| `budget` | Budget | |
| `expense` | Expense | |
| `category` | BudgetCategory | 该预算下的分类 |
| `recordedAmount` | Decimal | 在此预算下的计入金额（默认 = expense.amount） |
| `finalAttribution` | enum? | 结算时确定：`included` / `excluded` / `partial`（v2） |
| `createdAt` | Date | |

> **关键**：一笔 ¥38 同时归到「京都」和「生活」两个预算，会产生 2 条 binding，每条 binding 的 `recordedAmount = 38`。结算时用户可以把生活那条标记为 `excluded`，让生活预算的计入金额回滚。

### 4.5 `Settlement` 结算

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | |
| `budget` | Budget | |
| `settledAt` | Date | 结算时间 |
| `totalSpent` | Decimal | 该预算最终支出 |
| `surplus` | Decimal | 结余 = totalAmount - totalSpent |
| `triggerType` | enum | `auto`（重复型自动）/ `manual`（用户点击） |
| `wishAllocations` | [WishAllocation] | 用户分配到各心愿的金额 |

### 4.6 `WishAllocation` 心愿分配

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | |
| `settlement` | Settlement | |
| `wish` | Wish | |
| `amount` | Decimal | 分配到该心愿的金额 |

> 同一次结算可以拆分到多个心愿，所有 amount 之和 = settlement.surplus。

### 4.7 `Wish` 心愿

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | |
| `name` | String | 例：「京都樱花季」 |
| `targetAmount` | Decimal | 目标金额 |
| `iconName` | String | |
| `colorHex` | String | |
| `state` | enum | `active` / `achieved` / `archived` |
| `createdAt` | Date | |
| `achievedAt` | Date? | |

**派生属性**：
- `accruedAmount`：所有 `WishAllocation` + 手动 `WishContribution` 的总和
- `progress`：`accruedAmount / targetAmount`

### 4.8 `WishContribution` 心愿手动入账

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | |
| `wish` | Wish | |
| `amount` | Decimal | 可正可负（用户调整） |
| `note` | String? | |
| `occurredAt` | Date | |

---

## 五、关键领域服务

| Service | 职责 | 所在层 |
|---------|------|------|
| `BudgetEngine` | 给定 Budget 算已用、剩余、进度、日均 | Core/Services |
| `SettlementEngine` | 触发结算、计算结余、生成关联账清单 | Core/Services |
| `LinkedExpenseDetector` | 识别同时归多预算的关联账（按 ExpenseID） | Core/Services |
| `WishLedger` | 心愿入账、达成判断、累积计算 | Core/Services |
| `CycleScheduler` | 重复型预算到期自动延续 / 单次型归档 | Core/Services |
| `OverrunHandler` | 处理超支策略（warn / deductFromWish） | Core/Services |
| `Formatters` | 货币、日期、百分比统一格式化 | Shared |
| `HapticsCenter` | 预算消耗 / 结算 / 达成 / 提醒 四种触感反馈 | DesignSystem |
| `OCRParser` | 截图识别金额 + 商户 | Capture/OCR |
| `VoiceParser` | 语音转 Expense 的解析 | Capture/Voice |

### 5.1 SettlementEngine 关键流程

```
触发结算（auto 或 manual）
  ↓
读取 Budget 所有 Bindings
  ↓
计算 totalSpent（sum of binding.recordedAmount where finalAttribution != excluded）
  ↓
LinkedExpenseDetector 找出 ExpenseID 在 ≥ 2 个 Budget 中的记录
  ↓
返回结算清单 ViewModel：
  · 总支出
  · 关联账列表（待用户确认）
  · 预估结余
  ↓
用户在 UI 上做：
  · 关联账归属决策（更新对应 binding.finalAttribution）
  · 心愿分配（创建 WishAllocations）
  ↓
提交结算：
  · 创建 Settlement 记录
  · 写入 WishAllocations
  · 触发结算高光动画
  · 更新 Budget.state = archived
  · 如果是 repeating，CycleScheduler 创建下一周期
```

---

## 六、跨平台与命名分区

- **App Display Name**：通过 `InfoPlist.strings` 给 zh-Hans 设为「预算线」，en 设为「CheckLine」。代码里所有字符串走 `String(localized:)`。
- **平台条件编译**：`#if os(iOS)` / `#if os(macOS)` 集中在 `Shared/Platform/` 下，业务代码不直接写。
- **窗口/导航**：iOS 走 `TabView`，macOS 走 `NavigationSplitView`，由 `App/RootScene.swift` 路由。
- **Mac 独占特性**（v1.1）：菜单栏速记、全局快捷键、剪贴板速记 —— 全部走 `Shared/Platform/macOS/`。

---

## 七、依赖与三方包策略

- 默认零依赖。
- 真要加，必须满足：开源活跃、维护稳定、license 兼容（MIT / Apache 2 优先）。
- 加之前在本文档「依赖清单」一节登记理由，避免越加越多。

### 依赖清单

（暂无）

---

## 八、构建与运行

> 待 Xcode 工程创建后补全具体命令。先占位。

- 本地构建：`xcodebuild -scheme CheckLine -destination 'platform=macOS' build`
- 单测：`xcodebuild -scheme CheckLine test`
- 运行：在 Xcode 选择 Mac 或 iPhone 模拟器/真机

---

## 九、可观测性与调试

- 所有领域服务的关键计算（预算消耗 / 结算 / 心愿入账）必须可单测，纯函数实现。
- 统计与消费日历当前先作为 PRD 和 Stitch 原型范围存在；正式实现前如需新增聚合字段或索引，必须先回到本文件登记数据模型影响。
- 调试模式下 `Resources/Sample/` 提供 sample 数据，一键塞进 SwiftData 容器。
- 错误用 `OSLog` 分 category：`Budget` / `Settlement` / `Capture` / `Sync`。

---

## 十、未决问题（先记录，不阻塞）

- iCloud schema 演进策略：第一次发版前定 schema version 命名规则
- Widget Family 覆盖范围：MVP 上线哪几个尺寸
- macOS 菜单栏入口：是否做菜单栏小窗口（倾向 v1.1）
- 通知策略：是否在「线快用完」时提醒，频率怎么控
- OCR 精度：截图识别准确率怎么衡量、识别失败怎么 fallback
- 语音解析模型：用 Apple 端侧还是接小模型 API
- 关联账识别策略升级：v2 是否引入 LLM 智能识别（不止 ExpenseID 关联，还能按时间+金额近似匹配）
