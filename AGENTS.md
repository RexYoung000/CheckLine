# AGENTS — 预算线 CheckLine 协作规则

> 本文件继承全局规则 `~/.pi/agent/AGENTS.md`，并叠加 CheckLine 项目特定约定。
> 全局规则与项目规则冲突时，**项目规则优先**。

---

## 一、阅读顺序（每次开工前）

1. `PRODUCT.md` — 产品宪法，看核心心智、不做清单
2. `FEATURE-LOOP.md` — 功能架构循环，确认改动落在哪一层
3. `DESIGN.md` — 设计规范，Token / 组件 / 动效
4. `ARCHITECTURE.md` — 技术结构、目录、数据模型
5. `GLOSSARY.md` — 术语表，确认概念用法一致
6. `PRIVACY.md` — 隐私约束，确认不动到数据安全红线
7. `ROADMAP.md` — 当前轮次的范围与边界
8. 全局 `AGENTS.md` — 沟通、节奏、Git 规范

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

---

## 六、金额数据安全约束

> 预算线是「钱的 App」。以下规则没有例外。

### 6.1 日志与输出

- **禁止** `print` / `NSLog` / `os_log` 输出真实金额、用户名、心愿名称等敏感字段
- 调试时用脱敏 placeholder：`print("扣血: amount=***.** budget=***")`
- Release 构建必须关闭所有 `print`（用 `#if DEBUG` 包裹）

### 6.2 Sample / Mock 数据

- 不使用真实人名、真实金额、真实心愿名称
- 统一使用 `Resources/Sample/` 下的虚构数据
- 示例：`"测试用户"` / `"¥999.00"` / `"示例心愿"`
- 不把调试截图中的真实数据提交到仓库

### 6.3 Commit / PR

- commit message 中不出现用户测试数据或真实金额
- diff 中如果包含 sample 数据更新，确认是虚构数据

### 6.4 网络与三方

- **MVP 不接入任何 Analytics / Tracking / 崩溃收集 SDK**
- 截图 OCR 和语音识别产生的原始数据处理后即丢弃，不存入 SwiftData
- iCloud 容器只存 SwiftData 模型定义的字段，不偷塞额外数据
- 完整隐私约束参见 `PRIVACY.md`

---

## 七、本地化纪律

### 7.1 字符串

- **所有用户可见字符串**必须走 `String(localized:)` 或 `LocalizedStringKey`
- **禁止**直接拼接：`"还能花 ¥" + String(amount)` ❌
- **正确方式**：`String(localized: "budget.remaining \(formatted)")` ✅

### 7.2 数字与货币

- 金额格式化必须用 `Decimal.FormatStyle.Currency`
- 日期格式化必须用 `Date.FormatStyle` 或 `DateFormatter`
- 不手写 `"¥"` 符号，走 `currencyCode` 自动适配

### 7.3 句子结构

- 不拼接句子片段（中英文语序不同会错乱）
- 用整句 key + 插值，不拆成前半句 + 后半句
- 例：`"wish.closer \(amount)"` → zh-Hans: `"离心愿近了 %@"` / en: `"%@ closer to your wish"`

### 7.4 新增字符串

- 每新增一个用户可见字符串，**同步更新** `zh-Hans.lproj/Localizable.strings` 和 `en.lproj/Localizable.strings`
- 不留空 key，即使暂时只有一种语言也先写上占位

---

## 八、可访问性最低线

> 以下是底线，不是加分项。不满足不合并。

### 8.1 Dynamic Type

- 所有文字必须使用 `.font(.body)` / `.font(.headline)` 等系统语义字号，或 `@ScaledMetric` 自适应
- 不硬写 `.font(.system(size: 15))`（无法跟随 Dynamic Type）
- 例外：`display` 级别的大数字（如预算剩余 56pt）可以用固定字号，但要设 `minimumScaleFactor(0.5)`

### 8.2 触控目标

- 所有可交互元素最小点击区域 **44×44pt**（Apple HIG 标准）
- chip / pill / 小按钮视觉上可以小于 44pt，但 tap area 必须撑到 44pt

### 8.3 VoiceOver

- 所有图标必须有 `accessibilityLabel`
- 金额读为完整文本：`accessibilityLabel("还能花一千五百二十元")`，不读 `"¥1,520"`
- 进度条提供 `accessibilityValue`：`"百分之七十"`
- 装饰性元素标记 `accessibilityHidden(true)`

### 8.4 颜色与对比

- **颜色不能单独承担信息**。扣血进度条除颜色变化外必须有数字或图标辅助
- 文字对比度满足 WCAG AA（4.5:1 for body, 3:1 for large text）
- 暗黑模式下所有语义色要单独验证对比度

---

## 九、SwiftData / iCloud 红线

### 9.1 Model 字段约束

- `Decimal` 在 SwiftData 中以 `NSDecimalNumber` 桥接存储，读写时注意精度
- **不要用 `Double` 存金额**。浮点精度会导致 ¥0.01 的误差
- 枚举字段用 `String` rawValue 存储（CloudKit 不支持自定义枚举编码）
- Optional 关系不要用 `@Relationship` 的 cascade delete，防止误删联动数据

### 9.2 Schema 迁移

- **任何 `@Model` 字段增减、改名、类型变更**都算 Schema 变更
- 变更前先在 `ARCHITECTURE.md` 第四节登记改了什么
- 写对应的 `VersionedSchema` + `SchemaMigrationPlan`
- **不允许直接删字段**。先标记 `@Attribute(.externalStorage)` 废弃，下个版本再删
- 每个 Schema version 用日期命名：`SchemaV20260615`

### 9.3 CloudKit 限制

- CloudKit 不支持 `unique` 约束 —— 不要给 Model 加 `#unique`
- CloudKit 不支持复合索引 —— 需要查询优化时用冗余字段
- CloudKit record 大小限制 1MB —— 不在 Model 里存大 blob
- 首次部署后 CloudKit schema 只能加字段、不能删字段

---

## 十、错误处理风格

### 10.1 用户可见错误

- **不暴露技术词**。用户永远不该看到 `SQLITE_BUSY`、`CloudKit error 15` 等内容
- 统一走 `Shared/Errors/` 下的 `UserFacingError` 枚举
- 每个 case 提供 `localizedDescription` 走本地化
- 调性参考 `PRODUCT.md` 第六节文案原则：不责备、不制造焦虑

### 10.2 异步错误

- `async throws` 方法的错误在 ViewModel 层捕获，转换为 `UserFacingError`
- Service 层抛出的错误用 `OSLog` 记录（脱敏），不 `print`
- 不用 `try!` / `fatalError()` 处理可恢复错误

---

## 十一、性能预算

| 指标 | 目标 | 说明 |
|------|------|------|
| 主屏冷启动（首屏可见） | ≤ 800ms | SwiftData 容器初始化 + 首屏数据查询 |
| 记一笔弹窗响应 | ≤ 200ms | 从 tap + 到弹窗可见 |
| 扣血动效帧率 | ≥ 60fps | 不掉帧 |
| 结算高光动效帧率 | ≥ 60fps | 粒子 + 渐变不掉帧 |
| SwiftData 单次查询 | ≤ 50ms | 常规数据量（≤ 1000 条 Expense） |
| iCloud 同步延迟 | 用户无感 | 后台静默同步，不阻塞 UI |

如果性能不达标，先在 `OSLog` 加时间戳定位瓶颈，不要为了速度牺牲代码清晰度。

---

## 十二、Apple HIG 遵从

- **导航**：用 `NavigationStack` / `NavigationSplitView`，不自造 navigation
- **TabView**：底部 tab 不超过 5 个，图标用 SF Symbols
- **Sheet**：iOS 用 `.sheet` / `.fullScreenCover`，macOS 用 `.sheet`
- **Alert**：用系统 `.alert` modifier，不自制弹窗
- **Haptic**：遵循 Apple 触感设计指南（`UIImpactFeedbackGenerator`），不在不恰当的时机触发
- **Safe Area**：不手动忽略 safe area（`.ignoresSafeArea`），除非是全屏庆祝覆盖层
- **系统手势**：不阻断 iOS 边缘滑动返回、下拉关闭等系统手势
- **macOS 菜单**：提供标准 Edit / View / Window 菜单项，不留空菜单

> 不确定是否符合 HIG 时，查 Apple Human Interface Guidelines 原文再决定。
