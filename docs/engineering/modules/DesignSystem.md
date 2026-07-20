# DesignSystem/

颜色、字体、间距、组件、动效、Haptic 的统一定义。

放在这里的内容：
- `Colors.swift` — 主色 / 中性色 / 庆祝色 / 状态色
- `Typography.swift` — 中英文字体规范
- `Spacing.swift` — 8pt 网格
- `Components/` — 通用卡片、进度条、按钮、空状态
- `Animations/` — 扣血 / 结算高光 / 心愿达成 三大动效
- `HapticsCenter.swift` — 触感反馈

**纪律**：
- 不能 `import` 任何 Feature
- 所有颜色 / 字号 / 圆角 / 间距走 token，不写魔法数字
- 暗黑模式平等对待，不是「附加」
