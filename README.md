# 预算线 · CheckLine

> 给自己划一条线 - 线内自由，线外克制。
> *Spend on what matters.*

iOS 17+ 个人预算管理 App。当前已建立正式 Xcode App 工程，处于“文档 + 可运行 SwiftUI 原型先行”阶段；macOS 版本按路线图后续接入。

---

## 一句话定位

**预算线**是基于「时间 + 主题」双维度的预算控制 App。

当前版本先把预算钱包体验做顺：

- 同时跑多个预算（生活 / 旅行 / 学习），各走各的
- 一笔消费可同时归属多个预算（平等标签，无主副）
- 首页一眼看到每个预算还能花多少
- 记一笔后，预算进度和最近记录立即更新
- 结算先展示预算结果、结余和关联账确认

心愿功能保留为长期愿景：省下的钱以后可以进入心愿基金，但它不进入当前版本页面、当前原型主线或 MVP 验收。

国区显示「预算线」，海外显示「CheckLine」。

---

## 当前设计方向

当前设计主参考改为旧 Stitch「预算钱包」项目：

https://stitch.withgoogle.com/projects/11707032164273888537

这套设计要继承的是：

- 浅色背景 + 白色卡片
- 钱包横滑卡片
- 分组列表
- 简洁统计图表
- 安静清晰的设置页

不能继承的是旧项目里的真实头像、真实姓名、AI 智能记账建议、真实账户余额心智，以及任何会让「钱包」压过「预算线」品牌的表达。

Apple HIG Layout 作为布局检查底线，用来检查安全区域、触控区域、底部导航、表单和页面边距；它不替代当前浅色预算钱包视觉方向。

之前生成的深色 14 页 CheckLine Stitch 原型属于历史产物，不再作为当前主设计方向。

---

## 文档导航

AI Agent / 新人开工前请按这个顺序读。

### 根目录

| 文件 | 用途 | 何时看 |
|------|------|------|
| [PRODUCT.md](./PRODUCT.md) | 产品宪法：定位、心智、原则、不做清单 | 任何决策前 |
| [AGENTS.md](./AGENTS.md) | 协作规则：沟通、改动边界、Git、文档纪律 | 开工前 |

### 产品规格层 · `docs/spec/`

| 文件 | 用途 | 何时看 |
|------|------|------|
| [PRD.md](./docs/spec/PRD.md) | 当前版本需求：预算钱包、记一笔、统计、设置、结算 | 做产品/UI 改造前 |
| [FEATURE-LOOP.md](./docs/spec/FEATURE-LOOP.md) | 当前功能循环：每日 / 结算 / 统计 / 设置 | 改功能前 |
| [USER-JOURNEY.md](./docs/spec/USER-JOURNEY.md) | Day 1-30 新用户旅程 | 排通知节奏 / 设计 onboarding 前 |
| [ROADMAP.md](./docs/spec/ROADMAP.md) | 当前 MVP 与后续节奏 | 排期前 |
| [GLOSSARY.md](./docs/spec/GLOSSARY.md) | 术语表：概念定义 + 反面例子 | AI 协作前 |

### 设计层 · `docs/design/`

| 文件 | 用途 | 何时看 |
|------|------|------|
| [DESIGN.md](./docs/design/DESIGN.md) | 当前设计规范：浅色预算钱包方向、Token、组件、无障碍 | 写 UI 前 |

### 技术层 · `docs/engineering/`

| 文件 | 用途 | 何时看 |
|------|------|------|
| [ARCHITECTURE.md](./docs/engineering/ARCHITECTURE.md) | 技术架构：技术栈、目录、数据模型、模块边界 | 改代码前 |
| [SETUP.md](./docs/engineering/SETUP.md) | Xcode 工程对接说明 | 第一次本地跑 |
| [PERMISSIONS.md](./docs/engineering/PERMISSIONS.md) | iOS 权限申请文案、时机、降级策略 | 接 Photos / Speech / 通知前 |

### 合规层 · `docs/compliance/`

| 文件 | 用途 | 何时看 |
|------|------|------|
| [PRIVACY.md](./docs/compliance/PRIVACY.md) | 隐私说明：数据存储、不收集清单、App Store 隐私标签 | 上架前 |

### 过程档案

| 目录 | 内容 |
|------|------|
| `docs/ui-workflow/` | 旧 UI workflow 分析报告 |
| `docs/prototype/` | 当前单 HTML 原型、Stitch 参考页、布局检查记录、当前 brief 说明 |

---

## 当前状态

```
已完成
   · 产品宪法、PRD、功能循环、路线图、设计规范
   · 旧预算钱包 Stitch 参考资料
   · 当前单文件闭环原型：docs/prototype/checkline-current-prototype.html
   · Apple HIG Layout 布局检查记录
   · 正式 Xcode App 工程与 iOS 17+ 构建环境
   · SwiftUI 闭环原型已接入 App 启动入口

可验证
   · Xcode iOS Simulator Debug 构建通过
   · 已生成 iOS 17+ 模拟器 App 包，等待作者在 Xcode 中完成视觉与真实交互验收

历史产物
   · 历史深色 CheckLine Stitch 生成目录已清理
   · docs/prototype/screenshots/ 保留既有截图档案
   · docs/prototype/stitch-reference/ 保留旧预算钱包参考资料

未开始
   · SwiftData 正式模型代码
   · 领域服务
   · 按当前 MVP 范围重构正式 App UI（现有 SwiftUI 页面仍是交互原型）
   · Widget Extension
   · 单元测试
```

---

## 推进节奏

| 轮次 | 当前目标 |
|------|----------|
| 第一轮：MVP | 跑通「创建预算 → 记一笔 → 结算 → 统计回看」 |
| 第二轮：录入加速 | Widget、截图识别、语音录入、通知细化 |
| 第三轮：心愿闭环 | 心愿列表、心愿详情、结算分配、达成反馈 |
| 第四轮：平台扩展 | macOS 独占、Live Activities、Shortcuts 自动化 |

---

## 工作目录

```
/Users/rexyoung/Desktop/vibe coding/Check_Line/
```

---

## 协作约定

- 所有 commit message 用中文，前缀按 `feat: / fix: / improve: / refactor: / test: / docs: / chore:`
- 文档与代码不一致时，先改文档再回来改代码
- AI 协作请先读 `PRODUCT.md` + `AGENTS.md`，再按需读规格层文档
