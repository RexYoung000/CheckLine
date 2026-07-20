# Shared/Platform/macOS/

macOS 独占代码。所有 `#if os(macOS)` 条件编译集中放在这里，不让业务代码直接写。

放在这里的内容：
- **菜单栏速记**：NSStatusBar 图标 + 弹出小窗（v1.1）
- **全局快捷键**：⌘⇧L 或自定义快捷键呼出速记（v1.1）
- **剪贴板监听**：识别复制金额 → 弹速记提示（v1.1）
- **窗口策略**：NavigationSplitView 的侧栏宽度、关闭策略
- **键盘导航**：macOS 全键盘支持（Tab / Enter / 方向键）
- **菜单栏命令**：File → New Expense / Settlement 等
