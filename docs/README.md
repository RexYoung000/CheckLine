# CheckLine 文档地图

本目录只保留能够指导当前产品判断、实现和验收的文档。历史研究与旧原型统一放入 `archive/`，不参与当前版本决策。

## 权威顺序

出现冲突时，按以下顺序判断：

1. 根目录 `PRODUCT.md`：产品定位、核心心智、不做清单。
2. `product/PRD.md` 与 `product/FEATURE-LOOP.md`：当前版本范围和业务流程。
3. `product/ROADMAP.md`：当前阶段与后续顺序。
4. `design/DESIGN.md`：当前视觉、布局、交互和文案规范。
5. `engineering/ARCHITECTURE.md`：当前工程结构、数据边界与实施约束。
6. `compliance/PRIVACY.md`：当前真实数据行为与未来能力边界。

下层文档不得自行扩大上层范围。原型、参考图和历史报告不能覆盖产品与当前版本文档。

## 当前文档

### 产品

| 文件 | 作用 |
|---|---|
| `../PRODUCT.md` | 产品宪法 |
| `product/PRD.md` | 当前 MVP 需求与验收 |
| `product/FEATURE-LOOP.md` | 每日、结算、统计、设置循环 |
| `product/USER-JOURNEY.md` | Day 1-30 用户旅程 |
| `product/GLOSSARY.md` | 当前术语与后续概念边界 |
| `product/ROADMAP.md` | 里程碑、顺序与实际产出 |

### 设计

| 文件或目录 | 作用 |
|---|---|
| `design/DESIGN.md` | 唯一 UI 实施规范 |
| `design/prototype/checkline-current.html` | 当前 8 页面范围的单文件交互原型 |
| `design/prototype/layout-check.md` | 当前原型的 iOS 布局检查 |
| `design/prototype/stitch/` | 当前 Stitch brief 与线上项目说明 |
| `design/references/stitch-budget-wallet/` | 当前浅色预算钱包视觉参考 |

### 工程与合规

| 文件 | 作用 |
|---|---|
| `engineering/ARCHITECTURE.md` | Xcode 工程、模块、当前数据模型、测试边界 |
| `engineering/SETUP.md` | 开发环境、构建和本地化验证 |
| `engineering/PERMISSIONS.md` | 当前无权限基线与后续分阶段权限 |
| `compliance/PRIVACY.md` | 当前构建和 MVP 的真实数据处理方式 |

## 当前实现状态

- 正式工程是根目录 `Check_Line.xcodeproj`，当前只有 iOS App Target。
- 最低系统版本为 iOS 17.0。
- App 当前运行与 HTML 原型对齐的原生 SwiftUI 体验样机，只用于工程与交互验证。
- 正式 MVP UI、SwiftData 模型、领域服务、Test Target、iCloud、Widget、OCR 和语音均未实现。
- 当前产品范围不包含心愿页面、心愿数据模型或结算转心愿。

## 历史资料

`archive/` 中的材料用于追溯设计过程，不是当前需求或实施依据。需要恢复被合并或删除的旧文件时，使用 Git 历史，不为历史内容继续维护当前路径。

## 维护规则

- 产品范围变化：先改 `PRODUCT.md`，再同步 PRD、功能循环、路线图和相关实施文档。
- 数据模型、模块边界或依赖变化：同步 `engineering/ARCHITECTURE.md`。
- 权限或数据流变化：同步 `engineering/PERMISSIONS.md` 与 `compliance/PRIVACY.md`。
- 页面、交互、文案变化：同步 `design/DESIGN.md` 和当前原型说明。
- 完成一个里程碑：更新 `product/ROADMAP.md` 的实际产出，不保留已经完成的“当前计划”。
