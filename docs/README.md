# CheckLine 文档地图

本目录只保留能够指导当前产品判断、实现和验收的文档。历史研究与旧原型统一放入 `archive/`，不参与当前版本决策。

## 权威顺序

出现冲突时：

1. 根目录 `PRODUCT.md`：定位、核心心智、金额原则、不做清单。
2. `product/PRD.md` 与 `product/FEATURE-LOOP.md`：V1 范围和业务流程。
3. `product/GLOSSARY.md`：当前术语、金额含义和废弃概念。
4. `product/ROADMAP.md`：内部里程碑与当前阶段。
5. `design/DESIGN.md`：设计原则、体验底线、已确认交互和历史样机边界。
6. `engineering/ARCHITECTURE.md`：工程结构、目标数据模型和实施约束。
7. `compliance/PRIVACY.md`：当前构建事实与 V1 数据边界。

下层文档不得扩大上层范围。`Features/Prototype`、历史测试、截图、HTML 原型和 `archive/` 不能覆盖新产品定义。

## 当前文档

### 产品

| 文件 | 作用 |
|------|------|
| `../PRODUCT.md` | 产品宪法 |
| `product/PRD.md` | V1 需求、范围与验收 |
| `product/FEATURE-LOOP.md` | 引导、每日预算、结算、心愿与追溯循环 |
| `product/USER-JOURNEY.md` | 从第一张预算卡到首个完整周期 |
| `product/GLOSSARY.md` | 术语、金额规则与废弃概念 |
| `product/ROADMAP.md` | 完整 V1 与内部里程碑 |

### 设计

| 文件或目录 | 作用 |
|------------|------|
| `design/DESIGN.md` | 设计原则、已确认交互契约（3.1）和目标视口清单（3.1.6）；2026-08-01 旧样机只作历史参考 |
| `design/explorations/` | 视觉探索，不直接作为实现要求 |
| `design/prototype/` | 历史流程/布局参考，不代表当前产品行为 |

### 工程与合规

| 文件 | 作用 |
|------|------|
| `engineering/ARCHITECTURE.md` | Xcode 工程事实、新 V1 目标模型和领域服务 |
| `engineering/SETUP.md` | 开发环境、构建和本地化验证 |
| `engineering/PERMISSIONS.md` | Agent 与可选数据来源的权限/降级要求 |
| `compliance/PRIVACY.md` | 当前构建事实、设备优先原则和 V1 数据流 |

## 当前实现状态

- 正式工程：根目录 `Check_Line.xcodeproj`，iOS App + Swift Testing Target。
- 当前 App 仍运行 2026-08-01 的内存 SwiftUI 体验样机，只作历史视觉/工程参考；**启动页不是新 V1 需求**。
- 样机的四 Tab、多预算重复扣减、旧结算和悬浮文本/语音入口已经被新产品定义取代，见 `DESIGN.md` 3.1 与 3.4。
- 正式 SwiftData Schema V1 与本地 `ModelContainer` 已接入 App（无 CloudKit）；**启动页仍是旧样机**，不读写新账本。
- `BudgetEngine`、`LedgerStore` 及 M1 领域服务单测是新 V1 验收入口；`PrototypeDeletionTests` 只证明旧样机行为。
- 当前构建仍无网络、无 iCloud 同步、无真实 AI、无被动来源、无系统权限。
- **M2 行动门禁已落地。** 下一步是 LLM/语音/图片或 M4 面板，不要改旧样机外观。

## 维护规则

- 产品范围：先改 `PRODUCT.md`，再同步 PRD、功能循环、术语和路线图。
- 页面、导航、交互和文案：同步 `DESIGN.md`。历史样机说明不能覆盖第 3.1 节。
- 数据模型、模块和依赖：同步 `ARCHITECTURE.md`。
- 权限或数据流：同步 `PERMISSIONS.md` 与 `PRIVACY.md`。
- 阶段结束：更新 `ROADMAP.md` 的实际产出。
- 历史材料归档到 `docs/archive/`，不能继续占用当前文档入口。
