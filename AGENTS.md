# AGENTS — 预算线 CheckLine 协作规则

> 本文件继承全局规则 `~/.pi/agent/AGENTS.md`，并叠加 CheckLine 项目特定约定。
> 全局规则与项目规则冲突时，**项目规则优先**。

---

## 一、阅读顺序（每次开工前）

1. `PRODUCT.md` — 产品宪法，看核心心智、不做清单
2. `FEATURE-LOOP.md` — 功能架构循环，确认改动落在哪一层
3. `ARCHITECTURE.md` — 技术结构、目录、数据模型
4. `ROADMAP.md` — 当前轮次的范围与边界
5. 全局 `AGENTS.md` — 沟通、节奏、Git 规范

任何改动前先把上面 4 份扫一遍。文档跟代码不一致 = 先改文档。

---

## 二、CheckLine 项目特定约定

### 2.1 沟通约定

- **不替用户拍板「钱怎么算」**。所有涉及金额分配 / 心愿归属 / 关联账归属的功能，必须把决策权留给用户。代码里不能有「智能猜测用户意图」的隐式行为。
- **遇到金额计算不确定就停下问**。预算是涉及钱的产品，宁可慢一点也别错。
- **任何动到「不做清单」的需求**，立刻回头跟产品（你）确认。

### 2.2 改动边界

可以顺手改：
- 同一个 Feature 内的明显 bug、文案问题
- DesignSystem 内的微调（颜色/间距）
- 注释、命名、单测补全

必须先问的：
- 跨 Feature 的逻辑改动（可能要下沉到 Core）
- 数据模型字段增减（影响 SwiftData 迁移）
- 任何动到 PRODUCT.md 第三节「核心心智」的改动
- 任何动到 ARCHITECTURE.md 第三节「模块边界」的改动
- 任何引入第三方包的改动

### 2.3 命名约定

- **模型类**：单数名词，如 `Budget` / `Wish` / `Expense` / `Settlement`
- **Service 类**：动名词或后缀 `Engine` / `Service` / `Center`，如 `BudgetEngine` / `SettlementEngine` / `HapticsCenter`
- **View**：后缀 `View` / `Sheet` / `Card`，如 `BudgetDetailView` / `ExpenseCaptureSheet`
- **enum case**：camelCase，如 `repeating` / `oneShot` / `warnOnly` / `deductFromWish`
- **不要用「主预算 / 副预算」这类废弃概念命名**，统一用「预算 / 关联预算」

### 2.4 视觉与文案约定

参见 `PRODUCT.md` 第六节。重点：
- 不说「省钱」，说「离心愿近了」
- 不说「超支」，说「今日预算用完了」
- 不说「记账」，说「记一笔」
- 中文 3-4 字短句，英文不绕弯

### 2.5 测试约定

- **领域服务必须有单测**：`BudgetEngine` / `SettlementEngine` / `LinkedExpenseDetector` / `WishLedger` / `OverrunHandler`
- **UI 组件不强制单测**，但关键交互（归类弹窗、结算清单）建议写 ViewModel 单测
- **不为 UI 写截图测试**（页面效果由作者人工验收）
- 用 Swift Testing，不用 XCTest（除非框架限制）

### 2.6 平台约定

- 所有平台条件编译集中在 `Sources/Shared/Platform/`
- 业务代码不写 `#if os(iOS)` / `#if os(macOS)`
- 平台差异通过协议或封装解决

---

## 三、Git 规范（项目特化）

### 3.1 Commit 类型对照

| 前缀 | 用法 |
|------|------|
| `feat:` | 新功能 |
| `fix:` | 修 bug |
| `improve:` | 体验 / 视觉 / 文案优化 |
| `refactor:` | 结构调整不改功能 |
| `test:` | 单测 |
| `docs:` | 改 PRODUCT / ARCHITECTURE / ROADMAP / FEATURE-LOOP 等文档 |
| `chore:` | 配置、依赖、构建 |

### 3.2 Commit 范例

- `feat: 新增单次型预算结算高光动画`
- `fix: 修复关联账识别在跨月时遗漏的问题`
- `improve: 优化结算清单的关联账批量操作交互`
- `refactor: 拆分 SettlementEngine 让心愿分配独立可测`
- `docs: PRODUCT.md 更新「结余分配权归用户」原则`
- `chore: 升级 SwiftData 包`

### 3.3 提交粒度

- 一个 commit 解决一件事
- 不把「修 bug」和「加新功能」混一起
- 不把「文档」和「代码」混一起，除非它们必须同时改才有意义（如新增字段同时更新 ARCHITECTURE.md）

### 3.4 分支与推送

- 默认在 `main`，开发周期短任务可直接 commit
- 大功能用 `feature/xxx` 分支
- 不强制 PR，但开关键 PR 用于自我 review
- 真机测试涉及到敏感凭据时，确认 `.gitignore` 没漏

---

## 四、文档维护纪律

- **代码与文档不一致 = 文档优先更新**，再回来改代码
- **PRODUCT.md 是宪法**：动它必须先在对话里跟产品（你）显式确认
- **FEATURE-LOOP.md 是地图**：每次新功能 / 改流程都要回头改图
- **ARCHITECTURE.md 是地基**：动数据模型 / 模块边界 / 依赖必须改它
- **ROADMAP.md 是节奏表**：每轮结束追加「实际产出」附录

---

## 五、卡点处理

按全局规则处理：遇到以下情况立即停下来跟产品（你）对齐，不硬推进：
1. 技术方案不确定，多个走向
2. 可能动到 PRODUCT.md 核心心智或不做清单
3. 涉及金额计算 / 数据迁移 / 隐私的边界
4. 需要外部服务、密钥、账号
5. 改动范围超出当前 ROADMAP 这一轮
