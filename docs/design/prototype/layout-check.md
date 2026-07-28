# CheckLine 当前原型布局检查

> 检查对象：`docs/design/prototype/checkline-current.html`
> 检查日期：2026-07-06
> 参考：Apple Human Interface Guidelines - Layout
> https://developer.apple.com/design/human-interface-guidelines/layout
>
> 本文只记录当时 HTML 原型的检查结果，不是当前设计规范。现行规则以 `../DESIGN.md` 为准。

---

## 一、检查定位

Apple HIG Layout 用于辅助检查当时原型的基础布局可用性，不决定 CheckLine 的视觉与交互形式。

浅灰背景、白色卡片、横滑钱包、分组列表和简洁统计是该版本原型采用的设计方案。它们可以继续使用，但外部参考和 Apple HIG 都不具有当前设计权威。

---

## 二、检查结果

| 项目 | 结果 | 说明 |
|------|------|------|
| 页面安全区域 | 已调整 | 原型新增 safe area 变量，顶部内容、底部导航、浮动按钮和底部弹窗都按 safe area 预留空间 |
| 底部导航 | 通过 | 当前 4 个 Tab，未超过 iOS 常规底部导航承载范围；底部已预留 Home Indicator 区域 |
| 浮动记一笔按钮 | 通过 | 当时按钮尺寸 58px，并以 44pt 作为点击可靠性检查参考；位置已高于底部导航和 safe area |
| 页面边距 | 通过 | 该版本主内容使用 20px 横向边距；这是原型参数，不是当前固定规则 |
| 触控区域 | 通过 | 当时图标按钮、底部导航、chip、主按钮和二级按钮均达到或超过 44px 参考值 |
| 记一笔弹窗 | 已调整 | 底部弹窗支持滚动，底部 padding 已加入 safe area，避免主按钮贴近设备底边 |
| 新建预算表单 | 需 SwiftUI 阶段复核 | HTML 原型可操作；真实 App 中还要验证键盘弹起后金额输入和主按钮不被遮挡 |
| 统计与日历 | 通过 | 当前为单列布局，图表、分类列表和日历在手机宽度内可扫读 |
| iPad / macOS | 后续 | 该 HTML 原型只检查 iPhone 竖屏；iPad 按实际任务重新组织空间，macOS 进入对应路线图阶段后再设计 |

---

## 三、本次原型调整

- 增加 `--safe-top`、`--safe-bottom`、`--tabbar-height`、`--page-x` 布局变量。
- `app-scroll` 顶部和底部 padding 改为基于 safe area 计算。
- 底部导航高度和底部 padding 改为基于 safe area 计算。
- 右下角「记一笔」按钮位置改为高于底部导航和 safe area。
- Toast 和底部弹窗底部间距改为基于 safe area 计算。
- 移动端高度使用 `100dvh`，减少移动浏览器地址栏造成的高度误差。

---

## 四、后续真实界面复核

- 关键内容和操作不被状态栏、设备切口、Home Indicator、键盘或导航遮挡，具体实现方式不限。
- 记一笔在键盘弹起后仍然保留必要上下文并可以完成主要操作。
- Dynamic Type 放大时，大金额、按钮文字和列表行不能重叠。
- 所有关键操作容易触达且不易误触；44 x 44pt 作为默认检查参考，不限制视觉尺寸。
- iPhone 小屏、Pro Max 和 iPad 分屏分别做人工验收；macOS 在对应阶段单独定义验收方案。
