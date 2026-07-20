# Widgets/

Widget Extension 源码。不依赖 Features，只读 Core。

| 子目录 | 角色 | 优先级 |
|------|------|------|
| `BudgetStatusWidget/` | 预算剩余 + 心愿进度展示（中尺寸） | MVP |
| `QuickCaptureWidget/` | 锁屏一点直进归类弹窗（速记入口） | v1.1 |

**数据共享**：
- 通过 App Group 容器共享 SwiftData 持久化文件
- Widget 通过 `Core/Intents/` 中定义的 App Intents 读数据
- Widget 不直接持有 ModelContainer，走只读查询
