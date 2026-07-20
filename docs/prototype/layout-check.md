# CheckLine 当前原型布局检查

> 检查对象：`docs/prototype/checkline-current-prototype.html`
> 检查日期：2026-07-06
> 参考：Apple Human Interface Guidelines - Layout
> https://developer.apple.com/design/human-interface-guidelines/layout

---

## 一、检查定位

Apple HIG Layout 用于检查当前原型是否具备 iOS App 的基础布局纪律。

它不是视觉风格参考，不改变当前浅色预算钱包方向。当前视觉仍然沿用旧「预算钱包」参考：浅灰背景、白色卡片、横滑钱包、分组列表、简洁统计和安静设置页。

---

## 二、检查结果

| 项目 | 结果 | 说明 |
|------|------|------|
| 页面安全区域 | 已调整 | 原型新增 safe area 变量，顶部内容、底部导航、浮动按钮和底部弹窗都按 safe area 预留空间 |
| 底部导航 | 通过 | 当前 4 个 Tab，未超过 iOS 常规底部导航承载范围；底部已预留 Home Indicator 区域 |
| 浮动记一笔按钮 | 通过 | 按钮尺寸 58px，高于 44pt 最低触控目标；位置已高于底部导航和 safe area |
| 页面边距 | 通过 | 主内容保持 20px 横向边距；横滑钱包使用边缘延展但内容仍对齐 |
| 触控区域 | 通过 | 图标按钮、底部导航、chip、主按钮、二级按钮均达到或超过 44px 最小触控目标 |
| 记一笔弹窗 | 已调整 | 底部弹窗支持滚动，底部 padding 已加入 safe area，避免主按钮贴近设备底边 |
| 新建预算表单 | 需 SwiftUI 阶段复核 | HTML 原型可操作；真实 App 中还要验证键盘弹起后金额输入和主按钮不被遮挡 |
| 统计与日历 | 通过 | 当前为单列布局，图表、分类列表和日历在手机宽度内可扫读 |
| macOS / iPad | 后续 | 当前 HTML 原型先服务 iPhone 竖屏闭环；macOS / iPad 等真实平台适配进入 SwiftUI 阶段处理 |

---

## 三、本次原型调整

- 增加 `--safe-top`、`--safe-bottom`、`--tabbar-height`、`--page-x` 布局变量。
- `app-scroll` 顶部和底部 padding 改为基于 safe area 计算。
- 底部导航高度和底部 padding 改为基于 safe area 计算。
- 右下角「记一笔」按钮位置改为高于底部导航和 safe area。
- Toast 和底部弹窗底部间距改为基于 safe area 计算。
- 移动端高度使用 `100dvh`，减少移动浏览器地址栏造成的高度误差。

---

## 四、后续 SwiftUI 落地时必须复核

- 使用 `safeAreaInset` 或系统 TabView，不手动硬压底部导航。
- 记一笔弹窗使用系统 sheet，并验证键盘弹起后的可操作性。
- Dynamic Type 放大时，大金额、按钮文字和列表行不能重叠。
- 所有交互控件保持 44x44pt 以上触控区域。
- iPhone 小屏、Pro Max、iPad 分屏和 macOS 窗口宽度分别做一次人工验收。
