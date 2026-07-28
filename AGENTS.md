# CheckLine 项目协作规则

本文件只记录 CheckLine 的项目特定约束。沟通方式、需求对齐、Git 与交付流程遵循 Rex 的全局协作规则。

## 一、开工顺序

1. `PRODUCT.md`：确认产品心智和不做清单。
2. `docs/README.md`：确认当前文档、权威顺序和历史资料边界。
3. `docs/product/PRD.md`：确认当前版本范围。
4. `docs/product/FEATURE-LOOP.md`：确认改动属于哪个业务循环。
5. `docs/product/ROADMAP.md`：确认当前里程碑和依赖顺序。
6. 按任务读取 `docs/design/DESIGN.md`、`docs/engineering/ARCHITECTURE.md` 或合规文档。

能从当前工程和文档确认的信息不要重复询问。发现当前文档互相冲突时先停止相关实施，按 `docs/README.md` 的权威顺序收敛文档。

## 二、当前事实

- 正式工程：`Check_Line.xcodeproj`
- 主 App Target / Scheme：`Check_Line`
- 当前平台：iPhone / iPad，最低 iOS 17.0
- 当前源码根目录：`Check_Line/`
- 当前阶段：第一轮 MVP 正式实装
- 当前启动页：SwiftUI 体验样机，不是正式 MVP UI
- 当前已有：`Check_LineTests` Swift Testing Target、`BudgetEngine` 首批规则与关系删除样机测试
- 当前尚无：SwiftData 正式模型、完整领域服务、iCloud、Widget、OCR、语音和 macOS Target

不得因为历史原型、旧截图或 `docs/archive/` 中出现某项能力，就把它视为当前需求。

## 三、当前产品边界

### 当前 MVP 包含

- 重复型与单次型预算
- 多预算平等并存
- App 内手动记一笔
- 一笔消费归属多个预算
- 预算详情、统计回看和消费记录日历
- 关联账确认和预算结算
- 我的 / 设置与基础教程
- SwiftData 本地持久化

### 当前 MVP 不包含

- 心愿页面、心愿数据模型、心愿分配和心愿达成
- 超支从心愿或其他预算自动扣回
- Widget、OCR、语音、分享扩展、Shortcuts、iCloud
- macOS 独占能力、付费墙、暗黑模式精修

后续能力只能在 `docs/product/ROADMAP.md` 对应阶段启动，并先更新当前文档。

## 四、金额与业务规则

- 金额使用 `Decimal`，不能使用 `Double`。
- 预算剩余是派生结果，不持久化可被并发写坏的 `remaining` 字段。
- 一笔消费只存一份，通过 `BudgetExpenseBinding` 关联多个预算。
- 多预算标签平等，不建立主预算 / 副预算层级。
- 关联账最终如何计入必须由用户确认。
- 当前超支策略只有 `warnOnly` 和 `strictReview`。
- 系统不得自动替用户调整预算、分配结余或推断钱的归属。

涉及金额算法、关系模型或 Schema 变化时，先更新 `docs/engineering/ARCHITECTURE.md`，再实施和测试。

## 五、文案与设计

`docs/design/DESIGN.md` 是当前视觉与交互的唯一事实来源，但其中内容按规则等级管理，不默认全部属于强规则：

- **设计原则**：产品心智、品牌边界与用户决定权，不得违背。
- **体验底线**：可读、可操作、状态明确、能够纠错与无障碍，必须通过验收，实现方式不限。
- **当前设计方案**：开发默认遵循；色彩、排版、布局、组件与动效可以经明确设计判断调整。
- **探索与参考**：不能直接作为开发或验收要求。

当前核心产品语言包括：

- 预算线 / CheckLine
- 预算钱包
- 记一笔 / 记下这笔
- 已用 / 还能花 / 最近记录 / 结余
- 这个预算快用完了 / 今日预算已用完

具体按钮、状态和辅助文案可以在不改变产品含义的前提下迭代。用户界面禁止使用会造成错误心智或违背品牌边界的表达：

- 扣血
- 记账
- 主预算 / 副预算
- 转到心愿 / 离心愿近了
- 总资产 / 账户余额
- AI 智能记账建议

「扣血」只能作为内部动效比喻，不得进入用户可见字符串、无障碍标签或通知。

SwiftUI 是当前 UI 实现框架，不拥有设计决策权。只有在不损害用户理解、产品心智、交互可靠性和品牌表达时，才优先复用系统能力。会改变信息层级、导航、品牌视觉或核心流程的调整，必须先完成设计确认并更新 `DESIGN.md`，不能由开发或 AI 因实现便利自行改变。

## 六、工程结构

当前与计划中的模块都放在 `Check_Line/` 文件系统同步目录下：

```text
Check_Line/
├── App/             App 入口与根导航
├── Features/        Budget / Expense / Settlement / Insights / Settings
├── Core/            Models / Services / Persistence
├── Capture/         当前 Manual；后续 OCR / Voice
├── DesignSystem/    Token、组件、动效、Haptic
├── Shared/          格式化、错误、平台封装
├── Resources/       本地化与 Sample 数据
└── Assets.xcassets
```

模块边界：

- `Core` 不依赖 SwiftUI。
- Feature 之间不直接互相引用，共用逻辑下沉 `Core/Services`。
- `DesignSystem` 不依赖 Feature。
- 平台差异集中到 `Shared/Platform`，业务代码不散落条件编译。
- 没有进入当前里程碑的目录和 Target 不预建空壳。
- 不把多个同名 README 放入 App Target，避免被 Xcode 当作重复资源。

## 七、隐私与权限

- 当前构建不请求系统权限，不连接服务器，不启用 iCloud。
- 第一轮 MVP 数据只保存在本地 SwiftData。
- MVP 不接 Analytics、Tracking、广告或第三方崩溃收集 SDK。
- Sample 数据不能使用真实姓名、真实金额或真实心愿。
- 禁止日志输出真实金额、预算名、备注等用户数据。
- OCR、语音、通知、iCloud 等后续能力启动前，先同步 `PERMISSIONS.md` 和 `PRIVACY.md`。

## 八、本地化与无障碍

- 所有用户可见字符串走 `String(localized:)` 或 `LocalizedStringKey`。
- 金额使用 `Decimal.FormatStyle.Currency`，日期使用系统格式化 API。
- 不手写货币符号，不拼接中英文句子片段。
- 新增字符串同步维护 `zh-Hans` 和 `en`。
- 排版系统由 CheckLine 自主定义；不同设备、语言和文字缩放后，关键信息必须保持可读。
- 44 x 44pt 是点击可靠性的默认验收参考，不是控件视觉尺寸的绝对规定。
- 图标操作、金额和进度必须向辅助技术提供完整、可理解的含义，不机械要求逐元素标注。
- 颜色不能单独承担关键信息，核心文字与控件在实际使用环境中必须清晰可辨。
- 支持 VoiceOver、减少动态效果等系统辅助能力时，核心任务必须仍可完成。

## 九、测试底线

当前尚无 Test Target。进入正式数据层和领域服务实现前先建立 Swift Testing Target。

以下能力必须有单元测试后才能视为完成：

- `BudgetEngine`：已用、剩余、进度与边界值
- `SettlementEngine`：总支出、结余、重复型与单次型结算
- `LinkedExpenseDetector`：一笔多属和用户确认结果
- `OverrunPolicy`：`warnOnly / strictReview`
- SwiftData：模型关系、删除行为和迁移

UI 自动化检查不能替代 Rex 的模拟器或真机视觉验收。

## 十、文档同步

- 产品范围变化：`PRODUCT` -> `PRD` -> `FEATURE-LOOP` -> `ROADMAP`
- 页面或文案变化：同步 `DESIGN`
- 数据模型、模块、依赖变化：同步 `ARCHITECTURE`
- 权限或数据流变化：同步 `PERMISSIONS` 与 `PRIVACY`
- 阶段结束：在 `ROADMAP` 记录实际产出

历史材料统一归档到 `docs/archive/`，不要让历史文件继续出现在当前文档导航中。
