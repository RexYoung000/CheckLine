# CheckLine 项目协作规则

本文件只记录 CheckLine 的项目特定约束。沟通、需求对齐、Git 与交付流程遵循 Rex 的全局协作规则。

## 一、开工顺序

1. `PRODUCT.md`：确认产品心智、不做清单和金额原则。
2. `docs/README.md`：确认权威顺序与历史资料边界。
3. `docs/product/PRD.md`：确认 V1 范围。
4. `docs/product/FEATURE-LOOP.md`：确认改动属于哪个业务循环。
5. `docs/product/GLOSSARY.md`：确认术语和废弃概念。
6. `docs/product/ROADMAP.md`：确认当前内部里程碑。
7. 按任务读取 `docs/design/DESIGN.md`、`docs/engineering/ARCHITECTURE.md`、`docs/engineering/PERMISSIONS.md` 和隐私文档。

发现文档、样机或代码冲突时，先按 `docs/README.md` 的权威顺序收敛文档。历史原型和现有样机代码不能覆盖 2026-08-10 之后的新产品定义。

## 二、当前工程事实

- 正式工程：`Check_Line.xcodeproj`
- 主 App Target / Scheme：`Check_Line`
- 当前平台：iPhone / iPad，最低 iOS 17.0
- 当前源码根目录：`Check_Line/`
- 当前阶段：M0。首页/导航/Agent/确认页交互契约已写入 `docs/design/DESIGN.md` 第 3.1 节；仍待钱包跨币种规则与视口核对。正式数据模型未开始。
- 当前启动页：基于上一版“多预算重复扣减”的 SwiftUI 内存样机，只可用于历史视觉/工程参考
- 当前已有：`Check_LineTests` Swift Testing Target、`BudgetEngine` 基础金额规则、旧样机删除关系测试
- 当前尚无：SwiftData 正式模型、新 V1 完整领域服务、行动 Agent、被动数据来源、心愿钱包账本

不得把 `Features/Prototype` 的多预算关系、四 Tab、悬浮“文本/语音”入口或旧结算流程视为当前需求。它们会在后续实现切片中按新文档重做；本次文档任务不直接修改代码。

## 三、当前 V1 产品边界

### V1 包含

- 循环型与一次性预算卡
- 一笔消费最多一张结算预算卡，多标签只表达含义
- 文字、语音、图片统一预算循环行动 Agent
- Apple Pay、银行短信、邮件三类可跳过的被动入口
- 近期账单导入、标准化、跨来源去重、待确认和纠正规则学习
- 首页预算状态、数据覆盖和常驻 Agent 底部任务面板
- 用户检查后主动结算、循环卡下周期队列
- 唯一心愿钱包、待恢复差额、心愿清单和真实购买兑现
- 迟到交易与退款追溯原周期
- 多币种与设备优先隐私

### V1 不包含

- 财务健康总分、收入/债务画像和完整财务规划
- 投资、借贷、税务、保险建议或交易
- 一笔消费同时扣减多张预算卡
- 多个心愿钱包、逐心愿资金分配和资金冻结
- 偷读其他 App 通知、模拟登录支付或银行账号
- Agent 根据消费记录主动推荐用户买什么
- 未经确认的全球银行全自动连接承诺

## 四、金额与业务规则

- 金额使用 `Decimal`，不能使用 `Double`。
- 预算剩余、结算、钱包余额和待恢复差额都是派生结果，不持久化会漂移的余额字段。
- 一笔 Expense 最多绑定一个结算 `BudgetPeriod`；标签不参与金额。
- 低置信归属可以暂计最可能预算卡，但必须单独显示待确认金额。
- 待确认金额只能触发“可能”风险，不能形成确定越线结论。
- 循环卡到期后等待用户结算；期间新消费进入下周期队列。
- 结余先补待恢复差额，再进入唯一心愿钱包。
- 越线先扣钱包；钱包不足部分成为同一账本的待恢复差额。
- 心愿只有真实购买确认后才按实际成交金额扣钱包，且不再扣普通预算卡。
- 迟到交易和退款必须展示追溯影响，经确认后修正原周期。
- 所有金额由确定性领域服务计算；Agent 只理解、追问、解释和发起行动。

涉及金额算法、Schema 或关系模型时，先更新 `docs/engineering/ARCHITECTURE.md`，再实施和测试。

## 五、Agent 风险门禁

- 信息明确的低风险单笔记录可以直接执行，并立即提供撤销。
- 归属不确定、图片包含多笔或信息缺失时，先确认结构化结果。
- 调额度、改周期、删除、批量修改必须先展示影响。
- 结算、心愿钱包变化、心愿兑现和追溯修正必须明确确认。
- Agent 不得直接写数据库，必须调用 Application/Core 的结构化服务。

## 六、设计与文案

- `docs/design/DESIGN.md` 中设计原则和体验底线继续有效。
- 其 2026-08-01 旧样机方案基于已废弃业务模型，不再是当前页面实现基线；等待交互设计收敛后重写。
- 已确认首页框架：预算状态为主体、顶部集中处理待确认/覆盖/风险、底部常驻 Agent、唤起后使用底部任务面板，复杂任务再全屏。
- 主导航、卡片层级和具体视觉尚未确认，不能沿用旧四 Tab 当作定案。

用户界面禁止：

- 扣血、记账
- 主预算 / 副预算 / 关联预算
- 总资产 / 账户余额
- AI 自动替你管钱
- 把心愿钱包描述成真实资金或绝对安全可花额度

推荐术语：预算线、预算卡、记一笔、已用、还能花、待确认、未纳入预算、数据覆盖、结算、心愿钱包、待恢复差额。

## 七、工程结构目标

```text
Check_Line/
├── App/               App 入口与根导航
├── Features/          Home / Budget / Transactions / Settlement / Wish / DataSources / AgentPanel
├── Application/       AgentActionCoordinator / ConfirmationGate / ImportCoordinator / UndoCoordinator
├── Core/              Models / Services / Persistence
├── Capture/           Text / Voice / Image / ApplePay / SMS / Email / Statement
├── DesignSystem/      Token、组件、动效、Haptic
├── Shared/            格式化、错误、本地化、平台封装
└── Resources/         本地化与 Sample 数据
```

- `Core` 不依赖 SwiftUI、具体 AI Provider 或具体来源 SDK。
- Feature 之间不直接互相 import；共享逻辑下沉 Application/Core。
- Capture 只提取来源事实，不直接改预算、结算或钱包。
- 不为尚未进入实施切片的模块机械创建空目录。

## 八、隐私与权限

- 当前构建仍无网络、无正式数据持久化、无系统权限；隐私文档必须区分“当前构建事实”与“V1 目标”。
- V1 完整账本默认保存在设备；iCloud 是否进入首发仍待确认，不提前启用。
- 所有数据来源可跳过和断开，文字 Agent 与本地账本必须可独立运行。
- 不接 Analytics、Tracking、广告或第三方崩溃收集 SDK，除非单独完成隐私评审。
- 原图、原音频、短信/邮件无关全文和导入临时文件处理后丢弃。
- 云端 AI 只接收用户允许的最少必要字段，不发送完整账本。
- 禁止日志输出真实金额、商家、预算名、备注、邮件、短信和心愿名称。

## 九、本地化与无障碍

- 所有用户可见字符串走 `String(localized:)` 或 `LocalizedStringKey`。
- 金额使用 `Decimal.FormatStyle.Currency`，日期使用系统格式化 API。
- 新增字符串同步维护 `zh-Hans` 与 `en`。
- 核心任务在不同设备、文字缩放、VoiceOver 和减少动态效果下必须完整可用。
- 颜色不能单独承担待确认、风险或完成状态。

## 十、测试底线

必须有 Swift Testing 覆盖：

- `BudgetEngine`：已用、剩余、进度、待确认金额与边界值
- `CycleEngine`：循环/一次性周期、待结算、下周期队列
- `AttributionEngine`：唯一预算归属、未纳入、待确认
- `DeduplicationEngine`：多来源自动合并与不确定分流
- `SettlementEngine`：覆盖检查、结余/越线、事务提交
- `WalletLedger`：钱包余额、待恢复差额、结余和越线顺序
- `WishRedemptionEngine`：余额校验、实际购买和退款
- `RetrospectiveAdjustmentEngine`：迟到交易、退款和入账差异
- SwiftData：模型关系、删除、迁移和多设备冲突（如启用同步）

旧 `PrototypeDeletionTests` 验证的是已废弃多预算模型，不能作为新 V1 验收证据；后续改模型时替换，不为未发布旧行为保留兼容层。

## 十一、文档同步

- 产品范围：`PRODUCT` → `PRD` → `FEATURE-LOOP` → `GLOSSARY` → `ROADMAP`
- 页面/文案：同步 `DESIGN`
- 数据模型/模块/依赖：同步 `ARCHITECTURE`
- 权限/数据流：同步 `PERMISSIONS` 与 `PRIVACY`
- 阶段结束：在 `ROADMAP` 记录实际产出

历史资料归档到 `docs/archive/`，不能继续出现在当前文档导航中。
