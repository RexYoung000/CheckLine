# Shared/

工具类、扩展、平台条件代码。

| 子目录 | 角色 |
|------|------|
| `Platform/iOS/` | iOS 独占代码（Lock Screen Widget intent、Photos 监听等） |
| `Platform/macOS/` | macOS 独占代码（菜单栏、全局快捷键、剪贴板速记） |

**纪律**：
- 业务代码不写 `#if os(iOS)` / `#if os(macOS)`，平台差异都进 `Platform/`
- 通用扩展（Date / Decimal / String）放在本目录根
- 不放业务逻辑，业务进 `Core/Services`
