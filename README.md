# 预算线 · CheckLine

> 给自己划一条线 —— 线内自由，线外克制。
> Spend on what matters, save for what you wish.

---

## 这是什么

**预算线**是基于「时间 + 主题」双维度的预算控制 + 心愿激励 App。

- 同时跑多个预算（生活 / 旅行 / 学习），各走各的
- 一笔消费可同时归属多个预算（平等标签，无主副）
- 每个预算结束都有结算高光仪式（不论循环 / 单次）
- 结余由用户分配进心愿基金，达成解锁庆祝

平台：iOS 17+ / macOS 14+，SwiftUI + SwiftData。

---

## 文档导航

| 文件 | 用途 | 何时看 |
|------|------|------|
| [PRODUCT.md](./PRODUCT.md) | 产品宪法：定位、心智、原则、不做清单 | 任何决策前 |
| [FEATURE-LOOP.md](./FEATURE-LOOP.md) | 功能架构循环：每日 / 结算 / 心愿三层主流程 | 改功能前 |
| [DESIGN.md](./DESIGN.md) | 设计规范：Token、组件、布局、动效、平台适配 | 写 UI 前 |
| [ARCHITECTURE.md](./ARCHITECTURE.md) | 技术架构：技术栈、目录、数据模型、模块边界 | 改代码前 |
| [GLOSSARY.md](./GLOSSARY.md) | 术语表：所有自定义概念的正确定义 + 反面例子 | AI 协作前 |
| [ROADMAP.md](./ROADMAP.md) | 节奏：MVP → 精致 → 平台 → 商业化 | 排期前 |
| [AGENTS.md](./AGENTS.md) | 协作规则：沟通、改动边界、Git、文档纪律 | 开工前 |
| [SETUP.md](./SETUP.md) | Xcode 工程对接说明：怎么把磁盘目录变成可运行工程 | 第一次本地跑 |

---

## 当前状态

```
✅ 完成
  · 产品宪法 + 功能架构循环 + 术语表
  · 设计规范（深空暖金 · ui-workflow Deep 模式产出）
  · 技术架构（8 个 SwiftData 模型 + 模块边界）
  · MVP 范围与验收标准
  · 协作规则与文档纪律
  · 源码目录骨架

⬜ 未开始
  · Xcode 工程（按 SETUP.md 创建）
  · 数据模型代码
  · 首屏 UI
```

---

## 命名分区说明

苹果 App Store 支持按地区显示不同名称：

- 中国大陆：**预算线**
- 其他地区：**CheckLine**

工程内 Bundle Display Name 默认为 `CheckLine`，通过 `Resources/Localizations/zh-Hans.lproj/InfoPlist.strings` 覆盖为「预算线」。

---

## 工作目录

```
/Users/rexyoung/Desktop/vibe coding/mac&ios/CheckLine/
```

参考 planning 来源（不在本仓库内，位于上层目录）：
```
../planning/
  · 详细总结.md
  · 四大核心项目深度头脑风暴.md
  · 市场调研与可行性分析报告.md
  · 开发者画像与头脑风暴候补.md
```
