# 预算线 CheckLine

> 给自己划一条线，线内自由，线外克制。
> Spend on what matters.

CheckLine 是一个 iOS 17+ 的 Agent 驱动个人预算循环工具。用户自己划消费边界，CheckLine 降低记录成本，并把周期结算结果带入唯一心愿钱包。

## 当前产品循环

```text
创建预算卡
→ Agent 或可选数据来源记录消费
→ 首页查看已用、剩余、待确认和数据覆盖
→ 用户检查并主动结算
→ 结余或越线影响唯一心愿钱包
→ 真实购买确认后兑现心愿
→ 循环预算进入下一周期
```

关键规则：

- 一笔消费最多影响一张结算预算卡，其他含义用标签表达。
- Agent 只处理预算循环行动，不做完整财务规划。
- Apple Pay、银行短信、邮箱和近期账单导入都可跳过。
- 心愿钱包是预算表现形成的虚拟可用额度，不是真实资金账户。
- 高影响金额变化必须在执行前由用户确认。

## 当前工程状态

正式工程已从历史 Swift Package 迁入：

- Xcode 工程：`Check_Line.xcodeproj`
- Target / Scheme：`Check_Line`
- 平台：iPhone / iPad，最低 iOS 17.0
- 测试：`Check_LineTests` Swift Testing Target
- 远端：`https://github.com/RexYoung000/CheckLine.git`

当前 SwiftUI 启动页和部分测试来自上一版“多预算重复扣减、心愿后置”的内存样机。它们可以帮助追溯视觉和工程过程，但不代表 2026-08-10 后的新 V1 规则。

已经完成：

- 新 V1 产品宪法、PRD、功能循环、术语、旅程和内部里程碑；
- 目标数据模型、金额规则、权限和隐私边界；
- `BudgetEngine` 基础 Decimal 计算与旧样机测试基线；
- 首页“预算状态 + 常驻 Agent + 底部任务面板”的框架决定；
- 首页多卡层级、无四 Tab 导航、Agent 面板三态与结算/心愿确认页字段契约（`docs/design/DESIGN.md` 第 3.1 节）；
- 唯一心愿钱包基准币、确认时换算与汇率来源（`PRODUCT.md` 第 6.5 节）；
- 目标视口与真实内容核对清单（`docs/design/DESIGN.md` 第 3.1.6 节；真实页面验收属于 M4）；
- 旧 SwiftUI 样机已标明为历史参考，不再作为新 V1 需求；
- M1 确定性账本：领域引擎、Swift Testing、SwiftData Schema V1，以及 App 本地 `ModelContainer`（无 CloudKit）；
- M2 行动层：`AgentSession`、`ConfirmationGate`、理解管线、默认关闭的 `CloudLLMProvider`；
- M4 功能骨架：新首页与文字 Agent 面板写入本地账本；视觉、结算全屏和语音/图片尚未验收。

尚未完成：

- 结算/心愿全屏确认、真实 LLM、语音/图片 Capture 与被动数据来源；
- 真实页面视觉验收与公开发布准备。

## V1 范围

- 循环型与一次性预算卡；
- 文字、语音、图片统一行动 Agent；
- Apple Pay、银行短信、邮件三类可选被动入口；
- 近期账单导入、标准化、去重、待确认和规则学习；
- 首页预算状态与数据覆盖；
- 主动结算和循环卡下周期队列；
- 唯一心愿钱包、待恢复差额和真实购买兑现；
- 迟到交易与退款追溯；
- 多币种与设备优先隐私。

不做财务健康总分、完整收入/债务画像、投资/借贷/税务/保险，也不承诺全渠道无需配置的实时同步。

## 开始使用

1. 用 Xcode 打开 `Check_Line.xcodeproj`。
2. 选择 `Check_Line` Scheme。
3. 选择 iOS 17+ 的 iPhone 或 iPad 模拟器。
4. `Cmd + R` 启动，`Cmd + B` 构建，`Cmd + U` 运行测试。

当前构建仍是旧体验样机。构建/测试通过只能证明现有样机没有回归，不能证明新 V1 已实现。

## 文档入口

- [PRODUCT.md](./PRODUCT.md)：产品宪法，任何范围判断先读。
- [docs/README.md](./docs/README.md)：文档地图、权威顺序与历史边界。
- [docs/product/PRD.md](./docs/product/PRD.md)：新 V1 需求与验收。
- [docs/product/FEATURE-LOOP.md](./docs/product/FEATURE-LOOP.md)：完整预算—结算—心愿循环。
- [docs/engineering/ARCHITECTURE.md](./docs/engineering/ARCHITECTURE.md)：目标模型、金额规则与实现边界。
- [AGENTS.md](./AGENTS.md)：项目特定协作规则。

不要从 `Features/Prototype`、旧截图或 `docs/archive/` 反推当前需求。

## 仓库结构

```text
Check_Line.xcodeproj/      正式 Xcode 工程
Check_Line/                主 App Target 源码与资源
docs/product/              当前产品定义与路线图
docs/design/               设计原则、历史样机方案与后续交互收敛
docs/engineering/          架构、开发环境、权限
docs/compliance/           隐私与数据处理规则
docs/archive/              历史研究，不参与当前决策
scripts/                   原型辅助脚本
```
