# DESIGN — 预算线设计规范

> 本文件是 ui-workflow Deep 模式的最终产出。
> 综合了 00-07 七份分析报告，是视觉 + 交互 + 内容的唯一实施参考。
>
> 配套阅读：`PRODUCT.md`（产品宪法）、`FEATURE-LOOP.md`（功能循环）、`ARCHITECTURE.md`（技术架构）
>
> 参考来源：Copilot Money（深空金融设计语言）、Mobbin Finance 分类、YNAB 用户反馈
> 使用的外部技能：`design-dna`（设计 DNA 提取）

---

## 一、设计方向

**「深空暖金」— Deep Space with Warm Gold**

- 记账时刻 → 沉静的深空蓝背景，数据清晰发光
- 心愿达成 → 暖金色绽放，克制变成期待

一句话：**日常克制不冷漠，高光绽放不浮夸。**

---

## 二、设计 Token

### 2.1 颜色

```swift
// 背景层级
static let bgCanvas    = Color(hex: "000814")  // 主背景
static let bgCard      = Color(hex: "0D1B2A")  // 卡片
static let bgElevated  = Color(hex: "1B2838")  // 模态/面板

// 品牌
static let brand       = Color(hex: "1A73E8")  // 主色
static let brandLight  = Color(hex: "4FC3F7")  // 辅助蓝
static let celebration = Color(hex: "FFB300")  // 庆祝金

// 语义
static let deduct      = Color(hex: "FF5252")  // 扣血/支出
static let surplus     = Color(hex: "00C853")  // 结余
static let warning     = Color(hex: "FFB300")  // 超支提醒

// 文字
static let textPrimary   = Color(hex: "E0E1DD")
static let textSecondary = Color(hex: "778DA9")
static let textMuted     = Color(hex: "415A77")

// 分割
static let divider = Color(hex: "1B2838")
```

### 2.2 排版

| Token | 字号 | 字重 | 行高 | 用途 |
|-------|------|------|------|------|
| `display` | 56pt | bold | 1.0 | 预算剩余大数字 |
| `heading1` | 34pt | bold | 1.1 | 页面标题 |
| `heading2` | 22pt | semibold | 1.2 | 区块标题、心愿名称 |
| `heading3` | 17pt | semibold | 1.3 | 卡片标题 |
| `body` | 15pt | regular | 1.5 | 正文 |
| `bodySmall` | 13pt | regular | 1.4 | 辅助信息 |
| `caption` | 11pt | medium | 1.3 | 标签、分类 |
| `overline` | 10pt | semibold | 1.2 | 区块标签 |

- 西文：SF Pro Display / SF Pro Text
- 中文：PingFang SC
- 金额数字：SF Mono（等宽对齐）

### 2.3 间距

| Token | 值 | 用途 |
|-------|---|------|
| `xs` | 4pt | 内联间距 |
| `sm` | 8pt | 卡片内 padding |
| `md` | 16pt | 元素间距、卡片 padding |
| `lg` | 24pt | 区块间距 |
| `xl` | 32pt | 大区块间距 |
| `xxl` | 48pt | 页面顶部/底部留白 |
| `pageMargin` | 20pt | 页面水平边距 |

### 2.4 圆角

| Token | 值 | 用途 |
|-------|---|------|
| `radius-sm` | 8pt | chip、标签 |
| `radius-md` | 12pt | 按钮、小卡片 |
| `radius-lg` | 16pt | 主卡片 |
| `radius-pill` | 999pt | 进度条端点 |

### 2.5 阴影

| Token | 值 | 用途 |
|-------|---|------|
| `shadow-card` | y:2 blur:8 opacity:0.08 | 标准卡片 |
| `shadow-elevated` | y:4 blur:16 opacity:0.12 | 弹窗/模态 |
| `shadow-high` | y:8 blur:32 opacity:0.16 | 全屏覆盖层 |

### 2.6 动效

| Token | 值 | 用途 |
|-------|---|------|
| `duration-micro` | 150ms | chip 选中、切换态 |
| `duration-normal` | 300ms | 扣血、页面转场 |
| `duration-macro` | 800ms | 结算高光 |
| `duration-celebration` | 1200ms | 心愿达成 |
| `ease-micro` | spring(duration:0.4, bounce:0.15) | 微交互 |
| `ease-normal` | easeInOut 0.3s | 页面转场 |

---

## 三、页面设计规范

### 3.1 主屏 Home

```
┌─────────────────────────────────┐
│  [时间/日期]            [设置]   │  ← 顶栏
│                                 │
│  ┌─────────────────────────┐   │
│  │  6月生活                  │   │  ← BudgetCard (C 位)
│  │  还能花                   │   │
│  │  ¥1,520                  │   │  ← display 56pt bold
│  │  ━━━━━━━━━━━━━━━━━━ 70%  │   │  ← BudgetBar
│  │  伙食 ¥320 · 聚会 ¥200    │   │  ← 分类摘要
│  │  点击查看详情 →            │   │
│  └─────────────────────────┘   │
│                                 │
│  ┌─────────────────────────┐   │
│  │  心愿                    │   │  ← 心愿区
│  │  ● 京都樱花季  65%       │   │  ← WishProgress 环形
│  │    还差 ¥2,100           │   │
│  │  ● 富士相机    23%       │   │
│  └─────────────────────────┘   │
│                                 │
│  其他预算                       │
│  [京都旅行] [Q3 学习] →         │  ← 横滑
│                    ┌────┐      │
│                    │ +  │      │  ← 浮动记一笔按钮
│                    └────┘      │
└─────────────────────────────────┘
```

### 3.2 归类弹窗

```
┌─────────────────────────────────┐
│          ━━━━━ 拖动条            │
│  记一笔                    [✕]  │
│                                 │
│  ¥ [__________]  38.00          │  ← 金额输入
│                                 │
│  归到哪些预算                    │
│  ┌──────┐ ┌──────┐ ┌────┐     │
│  │✓京都  │ │✓生活  │ │+添加│     │  ← BudgetTagChip
│  └──────┘ └──────┘ └────┘     │
│                                 │
│  分类                           │
│  ┌────┐ ┌────┐ ┌────┐         │
│  │✓交通│ │伙食 │ │娱乐 │         │  ← CategoryPill
│  └────┘ └────┘ └────┘         │
│                                 │
│  备注  [_______________]        │
│                                 │
│  ┌─────────────────────────┐   │
│  │       扣血确认            │   │  ← 主色填充按钮
│  └─────────────────────────┘   │
└─────────────────────────────────┘
```

### 3.3 结算清单

```
┌─────────────────────────────────┐
│  ← 结算  6月生活                 │
│                                 │
│  总支出    ¥4,400               │
│  预算总额  ¥5,000               │
│  ━━━━━━━━━━━━━━━━━━ 88%        │
│                                 │
│  ⚠ 关联账确认（3 笔）            │
│  ┌─────────────────────────┐   │
│  │ ¥80  打车  6/15 14:30    │   │
│  │ 归属：京都 / 生活          │   │
│  │ [都算] [仅京都] [仅生活]   │   │
│  └─────────────────────────┘   │
│  （重复每条关联账）               │
│                                 │
│  省下了  ¥600                  │
│                                 │
│  转到心愿                       │
│  ▣ 京都樱花季  ¥600  [✏️]     │  ← 预设，可改
│  □ 富士相机   ¥0    [✏️]     │
│  □ 不转入                     │
│  💡 总和 = ¥600                │
│                                 │
│  ┌─────────────────────────┐   │
│  │      ✨ 结算              │   │  ← 庆祝金按钮
│  └─────────────────────────┘   │
└─────────────────────────────────┘
```

---

## 四、组件规范

### 4.1 BudgetCard

| 属性 | 值 |
|------|---|
| 背景 | `bgCard` |
| 圆角 | 16pt |
| 内间距 | 20pt |
| 阴影 | `shadow-card` |
| 选中态 | 1pt `brand` 边框 |

### 4.2 BudgetBar（扣血进度条）

| 属性 | 值 |
|------|---|
| 背景 | `bgElevated` |
| 高度 | 6pt |
| 圆角 | pill |
| 填充色 | `brand` → 超过80% `warning` → 超过95% `deduct` |
| 动效 | 缩短 + 颜色渐变，300ms easeInOut |

### 4.3 WishProgress（心愿进度环）

| 属性 | 值 |
|------|---|
| 尺寸 | 80pt 直径（主屏）/ 160pt（详情） |
| 线宽 | 6pt / 10pt |
| 背景环 | `bgElevated` |
| 进度环 | 渐变色 `brand` → `celebration` |
| 中心文字 | 百分比 + 目标名 |

### 4.4 BudgetTagChip

| 状态 | 样式 |
|------|------|
| 未选 | 描边 `brand` 1pt + 透明底 + `brand` 文字 |
| 选中 | 填充 `brand` + `#FFFFFF` 文字 + ✓ 图标 |
| 尺寸 | 高度 36pt，圆角 pill |

### 4.5 CategoryPill

| 属性 | 值 |
|------|---|
| 尺寸 | 高度 32pt，圆角 pill |
| 选中 | 填充分类专属色 + 白字 |
| 未选 | `bgElevated` + `textSecondary` |

### 4.6 CelebrationOverlay

| 属性 | 值 |
|------|---|
| 背景 | 渐变 `bgCanvas` → `celebration`（30% 透明度） |
| 粒子 | 金色 confetti，Canvas/TimelineView 实现 |
| 文字 | 大号文案居中，display 字号 |
| 时长 | 结算 800ms / 达成 1200ms |
| Haptic | heavy（庆祝） |
| 后续 | 自动转场或点击继续 |

---

## 五、交互状态覆盖

| 页面 | 空状态 | 正常 | 边界 | 错误 |
|------|--------|------|------|------|
| 主屏 | 引导创建预算 | 预算剩余+心愿进度 | 剩余¥0、心愿99% | iCloud 横幅 |
| 预算详情 | 引导记一笔 | 进度+分类+流水 | 超支红色标记 | — |
| 归类弹窗 | — | 正常录入 | 金额>剩余警告 | OCR/语音失败 toast |
| 结算清单 | — | 关联账确认 | 无关联账隐藏该区 | — |
| 心愿详情 | — | 进度环+来源 | 即将达成(>95%) | — |

---

## 六、平台适配

| 特性 | iOS | macOS |
|------|-----|-------|
| 导航 | TabView 4 tab | NavigationSplitView 侧栏 |
| 主屏布局 | 单列全宽 + 20pt 边距 | 居中 640pt |
| 归类弹窗 | .sheet bottom | .sheet popover |
| 结算 | .fullScreenCover | .sheet 窗口 |
| 速记 | 锁屏 Widget | 菜单栏 + 全局快捷键 |
| 暗黑模式 | 系统跟随 | 系统跟随 |
| 字体缩放 | Dynamic Type | 固定（macOS 无 Dynamic Type） |

---

## 七、实施优先级

| 优先级 | 内容 | 所属轮次 |
|--------|------|---------|
| P0 | 颜色/排版/间距 token 定义 | MVP |
| P0 | 主屏 + BudgetCard + BudgetBar | MVP |
| P0 | 归类弹窗 + BudgetTagChip + CategoryPill | MVP |
| P0 | 心愿区 + WishProgress | MVP |
| P0 | 扣血动效 + Haptic | MVP |
| P1 | 结算清单 + 结算高光 | MVP |
| P1 | 心愿达成动画 + 粒子 | MVP |
| P1 | 空状态 / Loading / 错误状态 | MVP |
| P2 | 暗黑模式精修（二刷） | 第二轮 |
| P2 | 动效细节打磨 | 第二轮 |
| P2 | macOS 独占交互 | 第三轮 |

---

## 八、待确认项

- [ ] 中文字号是否需要比西文大 1pt（PingFang 视觉偏小）
- [ ] 庆祝金 `#FFB300` 在浅色模式下是否需要调整饱和度
- [ ] 扣血进度条是否需要分类分段色（伙食蓝、聚会紫 → MVP 先统一品牌色）
- [ ] Widget 的深色背景是否能与主 App 的 `#000814` 完全一致（Widget 渲染差异）
