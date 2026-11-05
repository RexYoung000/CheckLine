# Figma 原生图层续作记录

设计文件：<https://www.figma.com/design/W9DmbsQnul4IJblT2R185b>

`figma-state.json` 记录已写入的 28 个浅暗画面、14 个组件、变量、样式和待连接的跳转。Starter / View 的 MCP 调用额度耗尽后，停止了原生图层写入；这些图层尚未连接原型交互，不能当作完整点击流程。

完整可运行原型的维护来源为相邻 `2026-11-05-checkline/`：`screen-model.js` 定义 31 个核心页面，`states.json` 定义 48 个补充状态，`assets/` 保存四个项目自有矢量资产。`states.js` 是 JSON 的离线浏览器包装；修改 JSON 后需同步生成。无需复制新的设计源。

额度恢复后的续作需先读取 Figma 最新画布，再复用现有组件、变量和样式。`screen-model.js` 的 `buildScreens(figma, STATE, BATCH)` 使用与 Figma 相同的页面构建 API；浏览器适配器仅用于本地预览。原生调用前应移除浏览器独有的 `systemAction` 赋值，保留系统行为说明，不伪造系统授权。

本地后续验证修正了心愿背面只保留覆盖比例和兑换、暗色收藏文字对比度、书籍购买记录入口及结算背景的待确认状态。这些修正位于完整可运行原型中，28 个原生图层内对应旧画面仍需同步，不作为最终实现规格。

此目录不保存令牌、上传凭据或账户配置。
