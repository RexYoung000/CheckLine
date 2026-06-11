# Sources/

工程源码根目录。Group 与磁盘目录一一对应（见 ARCHITECTURE.md 第二节）。

| 子目录 | 角色 |
|------|------|
| `App/` | App 入口、根 Scene、平台路由 |
| `Features/` | 业务功能模块（Budget / Expense / Settlement / Wish / Insights） |
| `Core/` | 业务核心（Models / Services / Persistence / Intents），不依赖 SwiftUI |
| `Capture/` | 录入子系统（Manual / OCR / Voice / Share），多入口分发 |
| `DesignSystem/` | 颜色、字体、间距、组件、动效 |
| `Shared/` | 工具类、扩展、平台条件代码 |

依赖方向严格自上而下，跨边界请下沉到 Core（详见 ARCHITECTURE.md 第三节）。
