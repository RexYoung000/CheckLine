# 预算线 · CheckLine

> 给自己划一条线 —— 线内自由，线外克制。
> *Spend on what matters, save for what you wish.*

iOS 17+ / macOS 14+ 个人预算管理 App。SwiftUI + SwiftData + iCloud。

---

## 一句话定位

**预算线**是基于「**时间 + 主题**」双维度的预算控制 + 心愿激励 App。

- 同时跑多个预算（生活 / 旅行 / 学习），各走各的
- 一笔消费可同时归属多个预算（平等标签，无主副）
- 每个预算结束都有结算高光仪式（不论循环 / 单次）
- 结余由用户分配进心愿基金，达成解锁庆祝

国区显示「**预算线**」，海外显示「**CheckLine**」。

---

## 文档导航

> AI Agent / 新人开工前请按这个顺序读。

### 🏛 根目录（最常读）

| 文件 | 用途 | 何时看 |
|------|------|------|
| [`PRODUCT.md`](./PRODUCT.md) | 产品宪法：定位、心智、原则、不做清单、北极星指标 | 任何决策前 |
| [`AGENTS.md`](./AGENTS.md) | 协作规则：沟通、改动边界、Git、文档纪律 | 开工前 |

### 📐 产品规格层 · `docs/spec/`

| 文件 | 用途 | 何时看 |
|------|------|------|
| [`PRD.md`](./docs/spec/PRD.md) | 完整产品需求：模块、导航、教程、通知、超支处理 | 做全盘产品/UI 改造前 |
| [`FEATURE-LOOP.md`](./docs/spec/FEATURE-LOOP.md) | 功能架构循环：每日 / 结算 / 心愿 / 通知主流程 | 改功能前 |
| [`USER-JOURNEY.md`](./docs/spec/USER-JOURNEY.md) | Day 1-30 新用户旅程，每个阶段的情绪与转折 | 排通知节奏 / 设计 onboarding 前 |
| [`ROADMAP.md`](./docs/spec/ROADMAP.md) | 节奏：MVP → 精致 → 平台 → 商业化 | 排期前 |
| [`GLOSSARY.md`](./docs/spec/GLOSSARY.md) | 术语表：所有自定义概念的正确定义 + 反面例子 | AI 协作前 |

### 🎨 设计层 · `docs/design/`

| 文件 | 用途 | 何时看 |
|------|------|------|
| [`DESIGN.md`](./docs/design/DESIGN.md) | 设计规范：Token、组件、布局、动效、无障碍 | 写 UI 前 |

### 🔧 技术层 · `docs/engineering/`

| 文件 | 用途 | 何时看 |
|------|------|------|
| [`ARCHITECTURE.md`](./docs/engineering/ARCHITECTURE.md) | 技术架构：技术栈、目录、数据模型、模块边界 | 改代码前 |
| [`SETUP.md`](./docs/engineering/SETUP.md) | Xcode 工程对接说明：怎么把磁盘目录变成可运行工程 | 第一次本地跑 |
| [`PERMISSIONS.md`](./docs/engineering/PERMISSIONS.md) | iOS 权限申请文案、时机、降级策略 | 接 Photos / Speech / 通知前 |

### 🛡 合规层 · `docs/compliance/`

| 文件 | 用途 | 何时看 |
|------|------|------|
| [`PRIVACY.md`](./docs/compliance/PRIVACY.md) | 隐私说明：数据存储、不收集清单、App Store 隐私标签 | 上架前 |

### 🔍 过程档案

| 目录 | 内容 |
|------|------|
| `docs/ui-workflow/` | UI workflow Deep 模式 7 份分析报告（00-07）+ 99 设计规格 |
| `docs/prototype/` | Stitch brief、参考页、生成 HTML 原型与截图 |

---

## 当前状态

```
✅ 文档完成
   · 产品宪法 + 功能架构循环 + 术语表
   · PRD（教程/通知/超支/Widget/多入口/无障碍 全覆盖）
   · 设计规范（深空暖金主题 + Token + 组件 + 空状态 + 无障碍）
   · 技术架构（8 个 SwiftData 模型 + 模块边界 + 性能预算）
   · 权限申请规范（5 类权限 + 中英文文案 + 降级策略）
   · Day 1-30 用户旅程（关键转折点 + 通知节奏）
   · MVP 范围与验收标准
   · 协作规则与文档纪律

📋 原型完成
   · ui-workflow 全流程分析
   · Stitch brief + 参考页
   · 部分页面已生成 HTML 原型

⬜ 未开始
   · Xcode 工程（按 docs/engineering/SETUP.md 创建）
   · SwiftData 数据模型代码
   · 领域服务（BudgetEngine / SettlementEngine 等）
   · 正式 App UI 实现
   · Widget Extension
   · 单元测试
```

---

## 推进节奏（双轮逻辑）

| 轮次 | 目标 | 参考 |
|------|------|------|
| **第一轮：MVP** | 跑通「创建预算 → 记一笔 → 结算 → 心愿累积」完整闭环 | `docs/spec/ROADMAP.md` 第一节 |
| **第二轮：精致与录入加速** | 暗黑模式精修、动效打磨、截图/语音/锁屏 Widget | 第二节 |
| **第三轮：平台扩展** | macOS 独占特性、Live Activities、Shortcuts 自动化 | 第三节 |
| **第四轮：商业化与增长** | 付费墙、ASO、内容投放 | 第四节 |

---

## 工作目录

```
/Users/rexyoung/Desktop/vibe coding/mac&ios/CheckLine/
```

参考来源（不在本仓库内）：

```
../planning/
  · 详细总结.md
  · 四大核心项目深度头脑风暴.md
  · 市场调研与可行性分析报告.md
  · 开发者画像与头脑风暴候补.md
```

---

## 协作约定

- 所有 commit message 用中文，前缀按 `feat: / fix: / improve: / refactor: / test: / docs: / chore:`
- 文档与代码不一致时，**先改文档**再回来改代码
- AI 协作请先读 `PRODUCT.md` + `AGENTS.md`，再按需读规格层文档
