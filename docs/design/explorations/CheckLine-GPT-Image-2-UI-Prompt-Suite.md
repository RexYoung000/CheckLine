# CheckLine GPT Image 2 UI Prompt Suite

> 一套用于生成、延展和校正 CheckLine iPhone / iPad UI 视觉探索稿的完整提示词。

## 文档状态

| 项目 | 当前状态 |
|---|---|
| 更新时间 | 2026-08-03 |
| 目标模型 | GPT Image 2 |
| 主要平台 | iPhone；iPad 仅在 iPhone 方向确认后进入适配探索 |
| UI 语言 | 简体中文为主；英文用于本地化压力检查 |
| 提示词语言 | 英文设计指令 + 引号中的中文界面原文 |
| 已确认方向 | 成熟数字产品为主体，克制手绘只作品牌点缀 |
| 完成阶段 | 提示词方案完成；尚未形成可见方向证据 |
| 设计权威 | `../DESIGN.md`；本文件不能覆盖产品与当前设计文档 |

本套件属于 `DESIGN.md` 的“探索与参考”，不是当前实现规范。具体颜色、圆角、阴影、组件和构图都只是待成图验证的候选方案。只有在代表性页面完成渲染并由 Rex 选择、组合或明确接受后，才可以把对应决定回写为当前设计方案。

## 为什么采用英文指令 + 中文原文

这不是因为 GPT Image 2 必须使用英文，也不表示英文天然优于中文。采用混合方式主要是为了：

- 用简洁、稳定的英文视觉词汇描述 hierarchy、spacing、surface、material 和 composition；
- 将所有真实中文 UI 文案放进引号，便于要求逐字渲染和后续定点修正；
- 把设计约束与用户可见内容分开，降低模型自行改写中文或添加营销文案的概率；
- 后续切换到英文 UI 时，只替换内容区，不重新解释视觉方向。

## 交付契约与证据边界

本任务使用 **Visual Direction** 契约。

最低可见证据：

1. 首页普通状态；
2. “记一笔”完整表单；
3. 含关联账选择的结算页；
4. 至少一个边界状态或空状态。

这些静态图可以证明层级、色彩、排版、表面和手绘比例是否可见，但不能证明：

- SwiftUI 中能够实现同样效果；
- 动画、键盘、触控、导航、删除或结算行为可用；
- VoiceOver、Voice Control、文字缩放或减少动态效果已经通过；
- iPad 适配已经成立；
- 中文没有在真实运行时截断；
- 最终体验已经被用户接受。

## 推荐生成顺序

不要一次生成整套多屏拼贴。按下面顺序逐张生成：

1. `01-home-normal-zh`
2. `02-capture-review-zh`
3. `03-settlement-linked-zh`
4. Rex 对三张锚点图选择、组合或提出修订
5. 使用已确认锚点图作为 Image 1，继续生成预算、统计、日历和设置
6. 生成临界、空状态、错误和危险确认
7. 进行英文与长内容压力探索
8. iPhone 方向确认后再进入 iPad 适配
9. 最终回到原生 SwiftUI 样机验证真实视觉与交互

## 推荐输出设置

如果生成入口支持自定义参数：

| 用途 | 建议尺寸 | 建议质量 |
|---|---:|---|
| iPhone 方向探索 | `1024x2208` | `medium` |
| iPhone 文字密集终稿 | `1024x2208` | `high` |
| iPad 宽屏方向探索 | `2736x2048` | `medium` |
| iPad 竖屏 / 紧凑方向探索 | `2048x2736` | `medium` |
| 快速单点修正 | 保持原图尺寸 | `medium` |

共同要求：

- 每张图只显示一个完整 App 页面或一个明确的系统内 Sheet 状态；
- 不放入手机机身、手持场景、桌面、透视模型或营销背景；
- 保持完整安全区、状态栏和适用的底部导航；
- 需要准确小字时使用 `high`，不要靠一次生成解决所有页面；
- 后续修改优先使用单点编辑提示，不重新生成整张图。

### 可选现有结构参考

可以把 [`../evidence/2026-08-01-home-iphone15pro.png`](../evidence/2026-08-01-home-iphone15pro.png) 作为首页的 Image 1。它只用于保留已经确认的首页信息关系，不是本次材质、配色或手绘风格的参考终点。

```text
Image 1 is the current native CheckLine home prototype.

Preserve only its verified product hierarchy and content relationship:
- title and current-budget selector in one top row;
- one dominant remaining amount with the total budget secondary;
- one shared recent-record surface;
- one primary capture action;
- four top-level navigation destinations.

Redesign the visual expression using the restrained hand-drawn direction defined below. Do not preserve Image 1's exact colors, icons, shadows, typography sizes, or surface styling merely because they already exist.
```

---

# Part A — Global Master Prompt

每次生成新页面时，先复制下面的全局母提示词，再附加对应页面提示词。

```text
Create one production-oriented, full-screen iOS 17 interface for an existing app named “预算线 CheckLine”.

OUTPUT FORMAT
- Show exactly one complete iPhone 15 Pro portrait app screen.
- Present it as a direct UI screenshot, not as concept art, a mood board, a marketing poster, or a design-tool canvas.
- Include realistic iOS safe areas, status bar, navigation structure, and the bottom tab bar only when the requested screen uses it.
- Do not place the UI inside an iPhone hardware frame.
- No hands, desk, room, perspective view, floating device, annotations, watermark, or surrounding scenery.
- Render only the quoted Chinese strings intentionally specified inside the appended page prompt. Render each of those strings exactly once, clearly and legibly.
- Do not render instructional examples, product explanations, preferred-language lists, or forbidden-language lists from this global prompt.
- Do not add unrequested copy.

PRODUCT
CheckLine helps a person see and understand a spending boundary they deliberately set for a period or a theme. The core question is: how much am I still willing to spend on this?

A budget is not a bank account or a real money container. Multiple budgets coexist independently and equally. One expense may belong to multiple budgets with no primary or secondary hierarchy. The system shows facts and supports review, but it never shames the person, celebrates spending less as an achievement, or silently decides where money belongs.

BRAND CHARACTER
Calm, restrained, warm, bounded, trustworthy, respectful, and quietly distinctive. The interface should feel like a mature daily-use product, not a finance dashboard and not a cute stationery app.

VISUAL DIRECTION
- Flat two-dimensional interface with precise product geometry.
- Quiet Japanese editorial and household-product minimalism: functional, natural, disciplined, and spacious, without copying any brand assets.
- One dominant visual answer per screen.
- Information density progresses from sparse state, to clear action, to denser supporting detail.
- Use typography, alignment, grayscale, and spacing before borders, fills, cards, or dividers.
- Group related information through proximity. Leave complete breathing room between different tasks.
- Avoid turning every section or row into a card.
- Use one large raised surface only when several items truly belong together.

RESTRAINED HAND-DRAWN LAYER
Hand-drawn expression should occupy roughly ten percent of the visual language.
- Use it only for small category icons, a meaningful boundary indicator, selection outlines, or a sparse empty-state illustration.
- Use a consistent thin graphite or ink line with subtle human variation.
- Keep every symbol clear, mature, and systemically consistent.
- Do not use handwriting for Chinese copy, amounts, labels, forms, buttons, charts, or navigation.
- Do not use decorative doodles or repeatedly draw a line merely because the product is called CheckLine.

COLOR AND MATERIAL CANDIDATE
- Base canvas: warm off-white, light flax, or quiet rice-paper neutral.
- Raised surface: near-white ivory with no visible texture that harms legibility.
- Primary content: soft charcoal rather than harsh pure black.
- Secondary content and dividers: warm gray.
- Use only one low-saturation accent family, preferably muted sage or gray olive.
- Reserve a small amount of muted clay for a real boundary or destructive state only.
- Shadows must be soft, broad, low-opacity micro-shadows used only to explain elevation.
- Exact colors and shadow values are proposals awaiting visual acceptance, not approved design tokens.

TYPOGRAPHY AND NUMBERS
- Use a clean contemporary Chinese sans-serif with excellent legibility.
- Use crisp, stable, well-aligned numerals for currency.
- Build hierarchy through size, weight, spacing, and grayscale.
- Supporting text must remain comfortably readable; do not make it tiny for aesthetic effect.
- Do not use a handwritten font.

APPLE-PLATFORM EXPRESSION
- The result should be practical for real SwiftUI implementation without looking like an untouched default template.
- Use familiar iOS placement, dismissal, back navigation, sheet, selection, and tab behavior where it supports understanding.
- Critical controls should look comfortably tappable even when their visible shape is restrained.
- Selection, progress, warning, and destructive meaning must never depend on color alone.
- Preserve obvious text expansion room and do not trap meaningful copy in fixed-height decoration.

PRODUCT LANGUAGE
Preferred visible concepts include:
预算线, 预算, 预算钱包, 记一笔, 记下这笔, 已用, 还能花, 最近记录, 结余, and 这笔归到哪些预算.

Never show these phrases in the visible interface:
扣血
记账
主预算
副预算
总资产
账户余额
超支
AI 智能记账建议
转到心愿
离心愿近了

HARD EXCLUSIONS
- No banking card, credit card, coin, piggy bank, physical wallet, cash pile, transfer, top-up, payment, stock chart, investment graph, leaderboard, trophy, streak badge, confetti, or savings celebration.
- No glassmorphism, glossy transparency, neon, high saturation, decorative gradients, metallic surfaces, leather texture, 3D objects, heavy blur, glow, or dramatic shadow.
- No childish cartoon, kawaii mascot, scrapbook collage, sticker pack, casual scribble, marker font, or diary aesthetic.
- No excessive pills, nested rounded cards, a separate card for every row, or ornamental separators.
- No fake permission alert, fake cloud state, fake service success, or feature that is outside the requested screen.
- No real brand logo, trademarked layout, or copied MUJI asset. Interpret the quiet functional philosophy without imitation.
```

---

# Part B — Anchor Screen Prompts

## B1. `01-home-normal-zh`

```text
SCREEN: HOME — NORMAL POPULATED STATE

Create the everyday home screen for “预算线”. This screen must answer one question immediately: how much remains in the currently selected budget?

TOP TITLE ROW
- Left: “预算线”.
- Right: a compact context selector labeled “7月生活” with a small downward chevron.
- Keep the title and selector on the same row.
- The selector is quiet and compact; it must not compete with the main amount.

PRIMARY STATE
- The only dominant focal point is “¥1,820”.
- Place smaller, light warm-gray text “/ ¥5,000” immediately after or near its baseline.
- Do not put the amount inside a card.
- Do not show an explanatory label above the amount.
- Do not show the current date, the budget period, a decorative progress track, or a bank-style balance label in this normal state.

RECENT RECORDS
- Use the screen’s only large raised surface for the complete recent-record list.
- Header left: “最近记录”.
- Header right: “-¥3,180”.
- Inside the shared surface, use spacing and stable alignment instead of separate row cards.

Show exactly these five records:
1. “市内交通” — “交通 · 7/6” — “-¥38”
2. “晚餐” — “伙食 · 7/5” — “-¥150”
3. “周末采购” — “伙食 · 7/4” — “-¥286”
4. “咖啡” — “伙食 · 7/3” — “-¥28”
5. “订阅续费” — “其他 · 7/2” — “-¥68”

Use one small restrained hand-drawn monoline category icon per row. Keep all amounts right-aligned and all metadata visually secondary.

PRIMARY ACTION
- Place one circular charcoal “+” action above the lower-right corner of the tab bar.
- Give it only a very soft micro-shadow.
- Keep clear separation from the record surface and tab bar.

TAB BAR
Show exactly four tabs:
“首页”, “预算”, “统计”, “我的”.
“首页” is selected with dark content and a second non-color cue. The other tabs are warm gray.

Do not add category summaries, shortcuts to budgets or insights, motivational copy, a greeting, a profile avatar, or any other dashboard widget.
```

## B2. `02-capture-review-zh`

```text
SCREEN: MANUAL CAPTURE — COMPLETED REVIEW STATE

Create a full-height iOS sheet for manually recording one expense. The underlying home screen may be softly dimmed, but the sheet must be the only active surface.

SHEET HEADER
- Centered drag indicator.
- Center title: “记一笔”.
- Leading action: “取消”.
- Do not show voice, OCR, camera, AI, or automation entry points. This is the current manual MVP path.

AMOUNT
- Supporting label: “金额”.
- Large precise value: “¥38”.
- Keep the amount area open and typographic; do not wrap it in a decorative card.

BUDGET ASSIGNMENT
- Section title: “归到哪些预算”.
- Show three equal options: “7月生活”, “京都旅行”, “Q3学习”.
- “7月生活” and “京都旅行” are selected.
- Use check state, outline or shape, and text together. Do not rely on color alone.
- Never imply primary and secondary budget roles.

CATEGORY
- Section title: “分类”.
- Current category: “交通”.
- Use one restrained hand-drawn transport icon.

NOTE
- Section title: “备注（选填）”.
- Content: “地铁到展馆”.

PRIMARY ACTION
- Fixed bottom action: “记下这笔”.
- Use a high-clarity charcoal or muted-sage treatment with a reliable tap area.
- Do not show the keyboard in this review-state image, so the complete form and action remain visible.

LAYOUT
Group amount, budgets, category, and note with spacing and only the minimum number of surfaces. Do not create four thick cards. Preserve room for longer Chinese strings and keyboard-safe implementation later.
```

## B3. `03-settlement-linked-zh`

```text
SCREEN: SETTLEMENT — LINKED EXPENSE REQUIRES USER DECISION

Create the settlement screen for the ended budget “6月生活”. The screen is a neutral stage review, not a success or failure result.

HEADER
- Back navigation.
- Title: “结算”.
- Budget: “6月生活”.
- Period: “6月1日 – 6月30日”.

SUMMARY
- “总支出” — “¥4,380”
- “预算总额” — “¥5,000”
- “结余” — “¥620”
- “¥620” is the main visual focal point, but keep it neutral.
- Do not use green celebration, praise, trophy, confetti, or language that says the user succeeded by spending less.

LINKED EXPENSE DECISION
- Section title: “关联账确认”.
- Record: “6月15日 · 市内交通 · ¥80”.
- Supporting fact: “归属：6月生活、京都旅行”.
- Show three equal explicit choices:
  “都算”
  “仅6月生活”
  “仅京都旅行”
- Do not preselect a choice in this image.
- Every choice must have a clear tappable shape and a visible selected-state design, but the neutral state is shown here.
- The consequence must remain understandable without color.
- Hand-drawn expression may appear only in the small transport icon and subtle option outlines.

PRIMARY ACTION
- Bottom action: “完成结算”.
- Keep it visibly disabled until one linked-expense decision is selected.
- The disabled state must remain legible and clearly different from the enabled state.

Do not show wish allocation, automatic distribution, another budget being silently changed, success animation, or a bank balance.
```

---

# Part C — Core Screen Expansion

只有在锚点图的视觉语言已经被选中后，才生成以下页面。每次附上选中的锚点图作为 Image 1，并在全局母提示词之后加入 `Part F` 的一致性锁定提示。

## C1. `04-budgets-list-zh`

```text
SCREEN: BUDGETS — ALL BUDGETS

Create the top-level budget-management screen.

HEADER
- Title: “预算”.
- Trailing action: “+”.
- The add action is clear but secondary to understanding the current budgets.

Do not show a combined money total. Multiple budgets are independent boundaries, not pieces of one bank balance.

ACTIVE SECTION
- Section title: “进行中”.
- Show three equal budget entries with no featured or primary budget:

“7月生活”
“还能花 ¥1,820”
“已用 ¥3,180 / ¥5,000”

“京都旅行”
“还能花 ¥4,240”
“已用 ¥4,560 / ¥8,800”

“Q3学习”
“还能花 ¥1,660”
“已用 ¥940 / ¥2,600”

SETTLING SECTION
- Section title: “待结算”.
- Show “6月生活” with the status “待结算”.
- Make the state explicit through text and shape, not color alone.

LAYOUT
- Use a calm open list or a small number of shared surfaces.
- Each budget may use one meaningful, slightly hand-drawn boundary indicator to show used versus total.
- Do not style entries as colorful credit cards or physical wallets.
- Do not use a different decorative color for every budget.

TAB BAR
Show “首页”, “预算”, “统计”, “我的”, with “预算” selected.
```

## C2. `05-budget-detail-zh`

```text
SCREEN: BUDGET DETAIL — ACTIVE NORMAL STATE

Create the detail screen for “7月生活”.

HEADER
- Back navigation.
- Title: “7月生活”.
- A quiet trailing menu for edit and record-management actions.

PRIMARY STATE
- Supporting label: “还能花”.
- Main amount: “¥1,820”.
- Secondary line: “已用 ¥3,180 · 总额 ¥5,000”.
- Period: “7月1日 – 7月31日”.

BOUNDARY INDICATOR
- Show one purposeful low-saturation budget boundary indicator for ¥3,180 used out of ¥5,000.
- It may have subtle hand-drawn ink variation, but the measurement must remain precise and easy to understand.
- Do not use a decorative line elsewhere on the screen.

CATEGORIES
- Section title: “分类”.
- Show four stable rows:
  “伙食” — “¥1,420 / ¥2,200”
  “交通” — “¥410 / ¥800”
  “聚会” — “¥820 / ¥1,000”
  “其他” — “¥530 / ¥1,000”
- Use restrained hand-drawn category icons and one shared muted accent family.
- Do not use a rainbow palette.

RECENT RECORDS
- Section title: “最近记录”.
- Show the three most recent records from the home screen with stable amount alignment.

ACTIONS
- Make “记一笔” easy to discover.
- Keep “管理记录” and edit access secondary.
- Keep budget deletion away from the daily primary action; destructive access belongs in the secondary menu or a separate lower section.
```

## C3. `06-budget-create-zh`

```text
SCREEN: CREATE A NEW BUDGET — COMPLETED REVIEW STATE

Create a full-screen iOS form titled “新建预算”. Show a completed example before the person confirms creation.

HEADER
- Leading action: “取消”.
- Center title: “新建预算”.

BUDGET DETAILS
- “预算名称” — “7月生活”
- “模板” — “月度生活”
- “周期类型” — “重复型”

AMOUNT AND PERIOD
- “总额” — “¥5,000”
- “开始日期” — “2026年7月1日”
- “结束日期” — “2026年7月31日”

CATEGORIES
- Section title: “分类”.
- Show editable rows:
  “伙食” — “¥2,200”
  “交通” — “¥800”
  “聚会” — “¥1,000”
  “其他” — “¥1,000”
- Include a quiet “添加分类” action.

BOUNDARY BEHAVIOR
- Use the user-facing section label “预算用完后”.
- Show two explicit choices:
  “继续记录，只提醒”
  “结算时重点回看”
- Select “继续记录，只提醒”.
- Do not show internal values such as warnOnly or strictReview.
- Do not use punitive language.

PRIMARY ACTION
- Bottom action: “创建”.

Use a calm, scan-friendly form. Avoid nested cards, excessive pills, or a decorative illustration. The screen must look buildable and keyboard-safe even though the keyboard is not shown in this review image.
```

## C4. `07-insights-overview-zh`

```text
SCREEN: INSIGHTS — BUDGET REVIEW

Create the “统计” screen as a calm review of spending boundaries, not a professional finance dashboard.

HEADER
- Title: “统计”.
- Trailing action: “日历” with a small calendar icon.

BUDGET CONTEXT
- Compact selector label: “查看预算”.
- Selected value: “7月生活”.

PRIMARY STATE
- Supporting label: “还能花”.
- Main amount: “¥1,820”.
- Secondary context: “已用 ¥3,180 · 总额 ¥5,000”.

BUDGET VS ACTUAL
- Section title: “预算 vs 实际”.
- Show three simple comparisons:
  “7月生活” — budget ¥5,000, actual ¥3,180
  “京都旅行” — budget ¥8,800, actual ¥4,560
  “Q3学习” — budget ¥2,600, actual ¥940
- Use warm gray for budget and one muted-sage family for actual.
- Use text labels and shape, not color alone.
- Keep the chart flat, quiet, and easy to scan.

CATEGORY ANALYSIS
- Section title: “分类分析”.
- Show “伙食”, “交通”, “聚会”, and “其他” with aligned amounts and simple proportion marks.
- Use the same accent family, not a multicolor chart.

Do not show investment curves, forecasting, net worth, achievement scores, complex filters, or dense business analytics.

TAB BAR
Show “首页”, “预算”, “统计”, “我的”, with “统计” selected.
```

## C5. `08-calendar-day-zh`

```text
SCREEN: EXPENSE RECORD CALENDAR — SELECTED DAY

Create the calendar view inside the insights task.

HEADER
- Back navigation to “统计”.
- Title: “消费记录日历”.

FILTER
- Label: “日历范围”.
- Two options: “全部预算” and “当前预算”.
- Select “全部预算” with both a shape cue and a text cue.

MONTH
- Title: “2026年7月”.
- Show a correct month grid with weekday labels “日”, “一”, “二”, “三”, “四”, “五”, “六”.
- July 1, 2026 falls under Wednesday.
- Record days use a small dot or short ink mark.
- Select July 6 with a calm outline and a second non-color cue.
- Do not create a heat map or achievement calendar.

DAY RECORDS
- Section title: “7月6日记录”.
- Show one record:
  “市内交通”
  “交通 · 7/6”
  “-¥38”
- Show two equal budget labels: “7月生活” and “京都旅行”.
- The two labels must not imply primary and secondary status.

Use restrained hand-drawn expression only for date marks and the small transport icon. Keep calendar geometry precise.
```

## C6. `09-settings-zh`

```text
SCREEN: MINE AND SETTINGS

Create the top-level “我的” screen.

HEADER
- Title: “我的”.

NEUTRAL STATUS
- Title: “预算回看”.
- Supporting line: “连续使用 12 天 · 当前有 3 个预算”.
- Present this as neutral continuity information, not an achievement card.
- No score, badge, ring, streak flame, praise, or ranking.

FINANCIAL MANAGEMENT
- Section title: “财务管理”.
- “预算设置” — “管理模板、分类和提醒”
- “记录管理” — “查看和修正历史记录”

GENERAL
- Section title: “通用设置”.
- “通知” — “预算快用完和结算提醒”
- “外观” — “浅色优先，暗色后续”
- “货币” — “默认 CNY”

ABOUT
- Section title: “关于”.
- “教程” — “重新了解预算线的使用方式”
- “隐私” — “数据只保存在本地”
- “反馈” — “告诉我哪里不好用”
- “版本” — “当前体验样机 0.2”

Do not show a social profile, membership promotion, advertising, cloud-sync success, export success, or unavailable feature as if it already works.

TAB BAR
Show “首页”, “预算”, “统计”, “我的”, with “我的” selected.
```

## C7. `10-settlement-complete-zh`

```text
SCREEN: SETTLEMENT COMPLETE — NEUTRAL CONFIRMATION

Create the result screen after “6月生活” has been successfully settled.

CONTENT
- Title: “结算完成”.
- Main amount: “结余 ¥620”.
- Supporting message: “这段预算已经归档，可以回到首页继续查看当前预算。”.
- Show two actions:
  Primary: “回到首页”
  Secondary: “查看统计”

Use a calm, conclusive layout with a small restrained hand-drawn completion mark, such as a closed line or simple check, but no celebration metaphor.

Do not use green success flooding, trophy, confetti, savings praise, wish allocation, or language that evaluates the amount of surplus.
```

## C8. `11-home-capture-menu-prototype-only-zh`

此页面只用于延续当前 SwiftUI 体验样机对录入入口可发现性的探索，不表示语音已进入 MVP。

```text
SCREEN: HOME — CAPTURE METHOD MENU EXPANDED — PROTOTYPE-ONLY VISUAL

Start from the approved normal home image and preserve everything else exactly.

Expand the lower-right “+” action into two visible choices arranged around the same circular anchor:
- “文本” to the left.
- “语音” to the upper-left.
- Change the center action from “+” to a clear close symbol.

Each choice must use a visible short label plus an icon. Do not let position, color, or motion be the only carrier of meaning.

Keep the arc compact and away from the record list and tab bar. Use the same restrained hand-drawn icon language.

This is only a static prototype state. Do not show microphone permission, live recognition, recorded data, or any claim that voice capture works.
```

---

# Part D — Material States and Sensitive Decisions

这些状态用于检查方向是否只在理想普通态中成立。危险操作必须准确表达对象、范围和结果；静态图不能证明数据已经正确删除或结算。

## D1. `12-home-near-boundary-zh`

```text
STATE VARIANT: HOME — BUDGET NEARLY USED

Use the approved home image as Image 1. Preserve layout, typography, navigation, record rows, spacing, surface, and all brand details.

Change only the budget state:
- Main amount: “¥240”.
- Total: “/ ¥5,000”.
- Add one concise factual message: “这个预算快用完了”.
- Introduce a small amount of muted clay in the message and one meaningful boundary indicator.
- Pair the color with text and shape.

Keep the tone calm and factual. Do not use a red alert banner, warning triangle, shake metaphor, broken line, punishment, countdown, or advice about whether the user should spend.
```

## D2. `13-home-line-crossed-zh`

```text
STATE VARIANT: HOME — BUDGET LINE CROSSED

Use the approved home image as Image 1 and preserve everything except the budget state.

Show:
- Main amount: “-¥180”.
- Total: “/ ¥5,000”.
- Factual message: “今日预算已用完”.
- A secondary line: “已超过预算线 ¥180”.

Use muted clay only where needed and keep all other content neutral. Use text, number sign, and a boundary shape together.

Do not block the primary capture entry in this visual. Do not use the Chinese term for overspending, failure red, punishment, vibration graphics, cracks, shame, automatic transfer, or a recommendation to move the expense to another budget.
```

## D3. `14-budgets-empty-zh`

```text
STATE: NO BUDGETS YET

Create the empty state of the “预算” screen.

Show exactly:
- Title: “预算”.
- Empty-state title: “还没有预算”.
- Supporting message: “创建第一个预算，给自己划一条线。”.
- Primary action: “新建预算”.

Use one sparse restrained hand-drawn illustration: a plain sheet or simple field with one deliberate boundary mark. Keep it abstract and mature.

The illustration should occupy no more than about fifteen percent of the visual weight. No wallet, card, coin, piggy bank, mascot, sticker, plant, desk scene, or decorative stationery collection.

Show the bottom tab bar with “预算” selected.
```

## D4. `15-records-empty-zh`

```text
STATE VARIANT: HOME — CURRENT BUDGET HAS NO RECORDS

Use the approved home image as Image 1.

Preserve the header, selected budget, main amount, total, primary action, and tab bar.

Replace the recent-record list content with:
- Header: “最近记录”.
- Empty message: “暂无记录”.
- Supporting message: “记下第一笔后，会在这里看到预算变化。”.

Use only a tiny hand-drawn receipt or dot-line icon. Keep “+” as the single primary action. Do not add a second large button inside the empty surface.
```

## D5. `16-capture-invalid-amount-zh`

```text
STATE VARIANT: MANUAL CAPTURE — INVALID AMOUNT

Use the approved manual-capture image as Image 1 and preserve the entire form structure.

Change the amount field to “¥0”.
Show one inline error immediately below the amount: “请输入大于 0 的金额”.
Keep “记下这笔” visibly disabled.

Use muted clay plus an error icon or outline; do not rely on color alone. Keep the entered budget, category, and note preserved.

Do not use a modal alert, raw error code, blame, shake illustration, or destructive red flooding.
```

## D6. `17-settlement-no-linked-records-zh`

```text
STATE VARIANT: SETTLEMENT — NO LINKED RECORDS

Use the approved settlement visual language.

Show the same “6月生活” summary:
- “总支出 ¥4,380”
- “预算总额 ¥5,000”
- “结余 ¥620”

Replace linked-expense choices with this factual message:
“没有需要确认的关联账，可以直接完成结算。”.

Show “完成结算” enabled. Do not add a success state before the action is completed.
```

## D7. `18-delete-budget-first-confirmation-zh`

```text
SENSITIVE FLOW: DELETE BUDGET — FIRST CONFIRMATION

Create an iOS confirmation sheet opened from the detail screen for “京都旅行”. The underlying detail screen is dimmed.

CONTENT HIERARCHY
- Title: “删除这个预算？”.
- Message: ““京都旅行”的预算、分类、结算和独占消费将被删除。”.
- Supporting fact: “删除预算和批量删除确认后无法撤销。”.

ACTIONS
- Destructive action: “继续删除”.
- Safe alternative: “取消”.

Make the destructive consequence clear without making the destructive action visually dominant over cancellation. Use muted clay for destructive semantics and pair it with text and iconography.

Do not claim shared expenses will be deleted yet. Do not promise recovery or a recycle bin. Do not use a generic affirmative button whose label hides the destructive consequence.
```

## D8. `19-delete-budget-shared-records-zh`

```text
SENSITIVE FLOW: DELETE BUDGET — SHARED EXPENSE REVIEW

Create the second confirmation screen after the user continues deleting “京都旅行”.

HEADER
- Title: “确认共享消费”.
- Message: ““京都旅行”包含以下共享消费。默认只从当前预算移除；勾选后会从其他预算和消费历史中一并删除。”.

SHARED RECORDS
Show two records:
1. “市内交通” — “¥38” — “仍在：7月生活”
2. “机场线” — “¥120” — “仍在：7月生活”

For each record, show an unchecked option meaning deletion from all budgets. Nothing is selected by default.

Show a separate unchecked bulk option:
“从所有预算删除全部共享消费”.

Supporting message:
“默认全部不勾选；未勾选的记录只会从当前预算移除。”.

ACTIONS
- Destructive action: “确认删除预算”.
- Safe alternative: “取消”.

Use explicit check state, text, and structure. Do not preselect destructive options. Do not hide the budgets where each record will remain. Do not show internal terms such as binding, cascade, relation, or entity.
```

## D9. `20-delete-shared-expense-scope-zh`

```text
SENSITIVE FLOW: DELETE ONE SHARED EXPENSE — CHOOSE SCOPE

Create an iOS confirmation sheet for deleting “市内交通” from the current budget “京都旅行”.

Show:
- Title: “这笔消费还在其他预算里”.
- Message: ““市内交通”仍关联“7月生活”。请选择删除范围。”.

Two explicit actions:
- Recommended safe action: “只从当前预算移除”.
- Destructive action: “从所有预算删除”.
- A clear “取消” path.

Visually separate the safe scope from the global destructive scope. Do not make global deletion the default. Do not use a generic Yes / No pattern, and do not claim the action can be recovered.
```

## D10. `21-batch-delete-review-zh`

```text
SENSITIVE FLOW: BATCH DELETE — REVIEW BEFORE ACTION

Create the record-management confirmation for three selected records in “7月生活”.

HEADER
- Title: “确认删除所选记录”.
- Summary: “将处理 3 笔记录，其中 2 笔只属于当前预算并会直接删除。”.

SHARED EXPENSE SECTION
- Section title: “共享消费”.
- Show “市内交通 · ¥38”.
- Supporting fact: “仍在：京都旅行”.
- Show an unchecked choice for deleting it from all budgets.

Supporting message:
“默认全部不勾选；未勾选的记录只会从当前预算移除。”.

ACTIONS
- “确认删除”
- “取消”

Use explicit hierarchy and calm destructive semantics. Do not promise undo for this confirmed batch action.
```

---

# Part E — Localization, Content Expansion, and iPad Exploration

本节只能生成设计评审素材，不能代替真实 App 的本地化、Dynamic Type 或 iPad 运行验证。

## E1. `22-home-en-localization-check`

```text
LOCALIZATION VARIANT: HOME — ENGLISH

Use the approved Chinese home image as Image 1. Preserve the exact visual system, component roles, spacing logic, and information hierarchy. Adapt spacing only where English content genuinely needs it.

Replace visible copy with exactly:
- App title: “CheckLine”
- Budget selector: “July living”
- Main amount: “CNY 1,820”
- Total: “/ CNY 5,000”
- Section title: “Recent records”
- Section total: “-CNY 3,180”

Records:
1. “City transit” — “Transport · Jul 6” — “-CNY 38”
2. “Dinner” — “Food · Jul 5” — “-CNY 150”
3. “Weekend groceries” — “Food · Jul 4” — “-CNY 286”
4. “Coffee” — “Food · Jul 3” — “-CNY 28”
5. “Subscription” — “Other · Jul 2” — “-CNY 68”

Tabs:
“Home”, “Budgets”, “Insights”, “Mine”.

Do not mechanically shrink all English text. Allow natural wrapping or spacing adjustments while preserving the single amount focal point.
```

## E2. `23-capture-en-localization-check`

```text
LOCALIZATION VARIANT: MANUAL CAPTURE — ENGLISH

Use the approved Chinese manual-capture image as Image 1. Preserve visual identity and task order.

Use exactly:
- “Add expense”
- “Cancel”
- “Amount”
- “CNY 38”
- “Assign to budgets”
- “July living”
- “Kyoto trip”
- “Q3 study”
- “Category”
- “Transport”
- “Note (optional)”
- “Subway to venue”
- “Record expense”

Keep “July living” and “Kyoto trip” equally selected. Reflow content rather than truncating it. Do not reduce tap areas or supporting-text legibility.
```

## E3. `24-home-content-stress-zh`

```text
DESIGN STRESS IMAGE: HOME — LONG CONTENT AND LARGE CURRENCY

Use the approved Chinese home image as Image 1. Preserve the design DNA but intentionally test content expansion.

Change only the representative content:
- Budget selector: “在国外长期学习与工作准备”.
- Main amount: “¥123,456.78”.
- Total: “/ ¥200,000.00”.
- Record title: “为下学期准备的专业课程与软件订阅”.
- Metadata: “学习 · 2026/07/26”.
- Amount: “-¥12,680.50”.

Reflow or widen internal layout intelligently. Do not silently truncate the amount, hide the budget context, overlap controls, or reduce critical text below comfortable readability.

This image is a design hypothesis only. It does not prove real Dynamic Type or localization behavior.
```

## E4. `25-home-large-text-concept-zh`

```text
DESIGN STRESS IMAGE: HOME — ACCESSIBILITY TEXT-SIZE CONCEPT

Use the approved Chinese home image as Image 1. Show a plausible layout concept for substantially enlarged text.

Preserve the task priority:
1. Current budget context.
2. Remaining amount and total.
3. Recent records.
4. Primary capture action.
5. Tab navigation.

Allow the title row to reflow vertically, allow record metadata to wrap, and increase row height. Keep all four tabs understandable. Do not overlap the floating action, record surface, or tab bar.

Do not claim this is a verified Dynamic Type implementation. It is only a static reflow proposal.
```

## E5. iPad adaptation boundary

iPad 提示词只在 iPhone 锚点图完成选择后使用。它保留同一产品心智和视觉 DNA，但不能把 iPhone 截图等比例拉宽。

使用 E6 或 E7 时，仍保留全局母提示词中的产品、品牌、手绘比例、颜色、排版与禁止项，但以下 iPad 页面块会覆盖母提示词中的 iPhone 输出格式。

## E6. `26-ipad-home-expansive-hypothesis`

```text
PLATFORM ADAPTATION HYPOTHESIS: IPAD HOME — EXPANSIVE WIDTH

Use the approved iPhone home image as Image 1 for shared product DNA only. Do not scale or stretch its screen geometry.

Create one full-screen 13-inch iPadOS landscape interface for the same CheckLine home task. This iPad instruction overrides the iPhone output format in the global prompt.

SHARED PRODUCT DNA TO PRESERVE
- Warm restrained neutral palette.
- One muted accent family.
- Precise Chinese typography and currency numerals.
- Roughly ten percent restrained hand-drawn iconography.
- One dominant answer: the remaining amount for the selected budget.
- Quiet surfaces, broad whitespace, and micro-shadows only for meaningful elevation.

IPAD-SPECIFIC HIERARCHY HYPOTHESIS
- Use a compact left navigation column for the four top-level areas and the equal budget contexts.
- In the main content area, show the selected “7月生活” state with “¥1,820 / ¥5,000” as the dominant focus.
- Allow recent records and one supporting budget context to coexist only when the relationship remains immediately clear.
- Keep “记一笔” reachable with touch and pointer without relying on a floating phone-style control in the far corner.
- Use the available width to create simultaneous context, not empty margins.

VISIBLE COPY
- “预算线”
- “首页”
- “预算”
- “统计”
- “我的”
- “7月生活”
- “京都旅行”
- “Q3学习”
- “最近记录”
- “记一笔”

Do not show an enlarged phone tab bar across the entire iPad width. Do not add desktop-only features, drag-and-drop claims, cloud sync, or new product scope.

This is an unapproved platform hypothesis, not the final iPad information architecture.
```

## E7. `27-ipad-compact-width-hypothesis`

```text
PLATFORM ADAPTATION HYPOTHESIS: IPAD — COMPACT WINDOW

Use the approved iPhone direction as Image 1.

Create a compact-width iPadOS portrait or split-view window that preserves the same task order as iPhone while adapting safe areas, readable measure, pointer-friendly spacing, and window context. This instruction overrides the iPhone output format in the global prompt.

Do not force a multi-column layout when the width cannot support it. Do not crop the iPhone screen or leave a narrow phone screenshot floating inside a large blank canvas.

Keep current budget, remaining amount, recent records, capture action, and top-level navigation complete and understandable.
```

---

# Part F — Consistency and Surgical Edit Prompts

## F1. Style lock for every new screen

```text
Image 1 is the approved visual anchor for “预算线 CheckLine”.

Preserve from Image 1:
- the exact warm-neutral palette and single muted accent family;
- Chinese type character, numeric style, weight contrast, and text color hierarchy;
- spacing rhythm, readable content measure, and amount focal-point logic;
- corner character, surface elevation, border intensity, and micro-shadow softness;
- hand-drawn stroke weight, irregularity level, icon geometry, and overall hand-drawn proportion;
- status-bar treatment, navigation scale, and bottom-tab proportions when applicable;
- the mature, calm, bounded, and trustworthy brand character.

Create only the new screen described below. Do not redesign the brand, add a new color family, switch fonts, increase card density, make the hand-drawn layer more playful, or add decorative imagery.
```

## F2. Text-only correction

```text
Change only the following visible UI text and render it exactly:

FROM: “...”
TO: “...”

Keep every other pixel-level decision as stable as possible: layout, positions, spacing, sizes, colors, typography style, icons, corner treatment, shadows, navigation, and background. Add no extra text.
```

## F3. Remove invented copy

```text
Remove only the unrequested text “...”.

Close the resulting space naturally while preserving the original hierarchy and all other interface elements. Do not replace it with a tagline, helper text, greeting, motivation, or marketing copy.
```

## F4. Reduce hand-drawn intensity

```text
Keep the interface, layout, copy, palette, typography, and components unchanged.

Reduce the hand-drawn expression by approximately one third:
- preserve small category icons and one meaningful state mark;
- make strokes thinner and more consistent;
- remove decorative irregularity from buttons, cards, amounts, text baselines, and navigation.

The result must remain warm and distinctive, but more mature and product-precise.
```

## F5. Increase restrained hand-drawn identity

```text
Keep the interface, layout, copy, palette, typography, and component geometry unchanged.

Increase only the restrained hand-drawn identity slightly:
- refine the existing category icons with consistent graphite variation;
- add one small meaningful boundary or selection mark where it explains state;
- keep the total hand-drawn layer below roughly fifteen percent of visual attention.

Do not alter Chinese typography, currency numerals, forms, button geometry, navigation, or surface edges. Do not introduce cartoons, stickers, handwriting, or decoration without information value.
```

## F6. Reduce card density

```text
Preserve all content, task order, navigation, palette, and typography.

Reduce unnecessary card density:
- remove individual row cards;
- group related rows into one shared surface or an open list;
- use proximity, alignment, and whitespace for structure;
- keep elevation only where a complete content group truly needs it.

Do not remove the information relationship or make actions harder to discover.
```

## F7. Restore CheckLine product meaning

```text
Preserve the strongest visual qualities of the current image, but correct the product meaning.

Remove any bank-account, credit-card, real-wallet, total-asset, transfer, top-up, payment, investment, saving-achievement, or traditional-accounting cues.

Reframe the screen around one user-defined budget boundary, its current amount, related expenses, and explicit user control. Keep multiple budgets equal. Do not invent wish features or automatic money movement.
```

## F8. Correct excessive color

```text
Keep content, layout, hierarchy, typography, icons, and component geometry unchanged.

Convert the interface to a quiet low-saturation system:
- warm neutral base;
- warm gray secondary content;
- one muted sage or gray-olive accent family;
- muted clay only for real boundary or destructive meaning.

Remove rainbow category colors, decorative color coding, gradients, neon, and color-only state differences.
```

## F9. Preserve layout while changing one state

```text
Use Image 1 as the exact base.

Change only this state:
STATE CHANGE: ...

Preserve all other content, layout, spacing, colors, typography, surfaces, icons, navigation, camera framing, and output dimensions. Do not reinterpret or redesign unaffected areas.
```

## F10. Repair iOS framing

```text
Keep the full interface design unchanged.

Present it as one direct, complete iOS app screenshot:
- remove the phone hardware frame, hand, background scene, perspective, tilt, and mockup presentation;
- restore full safe areas, status bar, and bottom home-indicator region where appropriate;
- keep the screen flat, front-facing, edge-to-edge, and ready for product review.
```

---

# Part G — Generation Manifest

建议保存文件时沿用下面的命名，避免后续把普通态、探索态和危险确认混在一起。

| 顺序 | 文件名 | 类型 | 用途 |
|---:|---|---|---|
| 01 | `01-home-normal-zh.png` | 锚点 | 验证主金额、留白、列表和手绘比例 |
| 02 | `02-capture-review-zh.png` | 锚点 | 验证输入层级、多预算平等和表单密度 |
| 03 | `03-settlement-linked-zh.png` | 锚点 | 验证结算语气与用户决定权 |
| 04 | `04-budgets-list-zh.png` | 核心页 | 验证多预算平等与分组 |
| 05 | `05-budget-detail-zh.png` | 核心页 | 验证边界线、分类和记录关系 |
| 06 | `06-budget-create-zh.png` | 核心页 | 验证长表单和边界行为选择 |
| 07 | `07-insights-overview-zh.png` | 核心页 | 验证低噪声统计表达 |
| 08 | `08-calendar-day-zh.png` | 核心页 | 验证日历与多预算标签 |
| 09 | `09-settings-zh.png` | 核心页 | 验证安静分组和中性回看 |
| 10 | `10-settlement-complete-zh.png` | 补充页 | 验证不庆祝的完成反馈 |
| 11 | `11-home-capture-menu-prototype-only-zh.png` | 样机探索 | 验证录入入口，不表示语音可用 |
| 12 | `12-home-near-boundary-zh.png` | 边界态 | 验证温柔但真实的临界表达 |
| 13 | `13-home-line-crossed-zh.png` | 边界态 | 验证越线事实表达 |
| 14 | `14-budgets-empty-zh.png` | 空状态 | 验证手绘插画上限 |
| 15 | `15-records-empty-zh.png` | 空状态 | 验证单一主操作 |
| 16 | `16-capture-invalid-amount-zh.png` | 错误态 | 验证非惩罚性纠错 |
| 17 | `17-settlement-no-linked-records-zh.png` | 状态变体 | 验证直接完成结算 |
| 18 | `18-delete-budget-first-confirmation-zh.png` | 危险确认 | 验证首次删除范围 |
| 19 | `19-delete-budget-shared-records-zh.png` | 危险确认 | 验证共享消费默认保留 |
| 20 | `20-delete-shared-expense-scope-zh.png` | 危险确认 | 验证单笔删除范围 |
| 21 | `21-batch-delete-review-zh.png` | 危险确认 | 验证批量删除后果 |
| 22 | `22-home-en-localization-check.png` | 本地化探索 | 验证英文长度 |
| 23 | `23-capture-en-localization-check.png` | 本地化探索 | 验证英文表单 |
| 24 | `24-home-content-stress-zh.png` | 内容压力 | 验证长名称与大金额 |
| 25 | `25-home-large-text-concept-zh.png` | 无障碍设计探索 | 只验证静态重排假设 |
| 26 | `26-ipad-home-expansive-hypothesis.png` | iPad 探索 | 验证宽屏信息共存 |
| 27 | `27-ipad-compact-width-hypothesis.png` | iPad 探索 | 验证紧凑窗口重排 |

---

# Part H — Visual Acceptance Path

## H1. 第一轮只检查三个锚点

### 首页

- 第一眼是否只有 “¥1,820” 一个强焦点？
- 是否能立刻理解当前正在看“7月生活”？
- 最近记录是否与总支出建立清楚关系？
- 手绘是否只停留在小图标，而没有侵入金额、正文和布局？
- 页面是否安静但不虚弱？
- 是否误导为银行余额、资产首页或传统记账首页？

### 记一笔

- 金额、多预算、分类、备注和确认顺序是否自然？
- “7月生活”和“京都旅行”是否完全平等？
- 选中态是否不依赖颜色？
- 页面是否仍有充分留白，而不是四张表单卡片堆叠？
- 主按钮是否容易找到？

### 结算

- 结余是否被中性呈现，而不是包装成成功？
- 关联账影响哪些预算是否清楚？
- 三个选项是否平等、明确且未被预选？
- 未决定前，“完成结算”是否明确不可用？
- 是否完全没有心愿、自动分配或惩罚性表达？

## H2. 选择结果

Rex 对三张锚点图应作出以下一种决定：

- **接受**：三张共同形成一个可继续延展的方向；
- **组合**：明确保留哪张的排版、哪张的材质、哪张的手绘比例；
- **修订**：使用 `Part F` 单点调整后重新评审；
- **否决**：回到视觉方向，而不是用大量局部修补掩盖错误方向。

只有接受或组合后的锚点图，才能作为后续页面的 Image 1。

## H3. 全套静态图检查

全套页面完成后，检查：

1. 同一种内容是否保持相同的字号角色、对齐和灰度；
2. 同一种图标是否保持相同笔触，不在不同页面变成插画、涂鸦或系统图标混用；
3. 是否始终只有一个低饱和强调色家族；
4. 是否有页面重新出现彩色卡片、资产总览或银行心智；
5. 是否为了“极简”隐藏预算归属、删除后果或关联账选择；
6. 是否为了“手绘”牺牲金额、日历和表单的精确度；
7. 中文是否逐字正确，标点、货币、日期和负号是否一致；
8. 空状态、错误态、临界态和危险确认是否保持同一品牌态度；
9. iPad 是否形成真实空间组织，而不是拉宽 iPhone；
10. 静态图中无法证明的交互、语义与运行状态是否仍被明确标记为未验证。

## H4. 原生体验验收

静态方向确认后，正式实现仍需在原生 SwiftUI 中检查：

- iPhone 小屏、当前目标机型和较大屏幕；
- iPad 紧凑与宽窗口；
- 中文与英文；
- 长预算名、大金额、本地化日期和货币；
- 键盘出现与收起；
- 文字缩放和内容重排；
- VoiceOver 语义与真实任务路径；
- 选中态、临界态和危险操作不只依赖颜色；
- 减少动态效果；
- 共享消费删除、撤销和结算的真实数据结果。

静态图片通过不等于设计完成，原生构建通过也不等于体验通过。最终视觉与真实体验仍由 Rex 在模拟器或真机中确认。

---

# Part I — Source Boundaries

## I1. 提示词内新增文案的状态

以下文案来自当前产品原则或本轮设计推导，但尚未全部存在于当前本地化资源。它们只是待成图评审的文案候选，不能因为出现在生成图中就直接进入实现：

| 候选文案 | 用途 | 接受后需要同步 |
|---|---|---|
| “还能花” | 替代容易产生账户心智的可见“余额”表达 | `DESIGN.md`、中英文本地化、对应界面 |
| “消费记录日历” | 明确日历首先用于消费回看 | `DESIGN.md`、中英文本地化、导航标题 |
| “预算用完后” | 用用户语言承载边界行为选择 | PRD / DESIGN 复核、中英文本地化、创建流程 |
| “继续记录，只提醒” | `warnOnly` 的用户可见候选 | 中英文本地化、创建流程 |
| “结算时重点回看” | `strictReview` 的用户可见候选 | 中英文本地化、创建与结算流程 |
| “已超过预算线 ¥180” | 越线事实表达候选 | DESIGN、金额格式化、本地化、边界状态 |
| “请输入大于 0 的金额” | 金额输入错误候选 | 中英文本地化、输入验证 |
| “记下第一笔后，会在这里看到预算变化。” | 最近记录空状态候选 | 中英文本地化、空状态 |

如果成图评审否决这些文案，继续以当前产品与本地化资源为准，不回写实现。

## I2. 当前依据

本套件依据当前项目事实编写：

- [`../../../PRODUCT.md`](../../../PRODUCT.md)：产品定位、用户心智与不做清单；
- [`../../product/PRD.md`](../../product/PRD.md)：当前 MVP 页面与验收范围；
- [`../../product/FEATURE-LOOP.md`](../../product/FEATURE-LOOP.md)：每日、结算、统计和设置循环；
- [`../DESIGN.md`](../DESIGN.md)：当前设计事实、极简注意力原则和探索边界；
- [`../../product/ROADMAP.md`](../../product/ROADMAP.md)：当前里程碑与后续能力；
- [`../../../Check_Line/Resources/Localizations/zh-Hans.lproj/Localizable.strings`](../../../Check_Line/Resources/Localizations/zh-Hans.lproj/Localizable.strings)：当前中文文案；
- [`../../../Check_Line/Resources/Localizations/en.lproj/Localizable.strings`](../../../Check_Line/Resources/Localizations/en.lproj/Localizable.strings)：当前英文文案；
- [OpenAI GPT Image Generation Models Prompting Guide](https://developers.openai.com/cookbook/examples/multimodal/image-gen-models-prompting-guide)：提示结构、UI mockup、文字约束和小步迭代依据。

出现冲突时，始终按项目文档权威顺序判断。本文件中为探索而提出的新布局或文案，不能静默覆盖上位产品规则、当前设计方案或真实本地化资源。
