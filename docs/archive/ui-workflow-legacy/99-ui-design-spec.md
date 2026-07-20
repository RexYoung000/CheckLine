# Stage 3 · 最终设计规范（整合）

> 模式：Deep　|　时间：2026-06-11

最终设计规范已产出为项目根目录的 `DESIGN.md`，完整产品需求见 `../../PRD.md`。

该文档涵盖了：
- 设计方向（深空暖金）
- 完整 Design Token（颜色/排版/间距/圆角/阴影/动效）
- 全 App UI 结构：首页 / 预算 / 心愿 / 统计 / 我的
- 统计与消费记录日历
- 线条小助手 IP 方向
- Stitch 全流程原型要求
- 6 个核心组件规范
- 交互状态覆盖表
- iOS/macOS 平台适配
- 实施优先级

## 当前改造补充

- 旧 Stitch「预算钱包」工程作为结构 feel 参考。
- 底部导航改为 5 个主入口：首页 / 预算 / 心愿 / 统计 / 我的。
- 日历放进统计模块，定位为消费记录日历。
- 用户可见文案不出现「扣血」。
- Stitch 原型必须覆盖完整 App，不只生成首页。

## 中间产物索引

| 阶段 | 文件 | 状态 |
|------|------|------|
| Stage 1 | `00-need-summary.md` | ✅ |
| Stage 1.5 | `01-research-report.md` | ✅ |
| Stage 2a | `02-need-report.md` | ✅ |
| Stage 2b-1 | `03-form-report.md` | ✅ |
| Stage 2b-2 | `04-visual-report.md` | ✅ |
| Stage 2b-3 | `05-ia-report.md` | ✅ |
| Stage 2b-4 | `06-interaction-report.md` | ✅ |
| Stage 2b-5 | `07-content-report.md` | ✅ |
| Stage 3 | → `../../DESIGN.md` | ✅ |

## 引用

- 参考来源：Copilot Money、Mobbin Finance、YNAB App Store
- 外部技能：`design-dna`（Phase 2 设计 DNA 提取）
- 其他可用但未使用的技能：`huashu-design`（Stage 4 原型时可用）、`hig-doctor`（未安装）
