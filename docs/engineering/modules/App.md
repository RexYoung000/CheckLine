# App/

App 入口与根 Scene。

放在这里的内容：
- `CheckLineApp.swift` — `@main` 入口
- `RootScene.swift` — iOS `TabView` / macOS `NavigationSplitView` 路由
- `AppEnvironment.swift` — 全局环境对象（SwiftData 容器、服务注入）

不放业务逻辑，业务全部下沉到 `Features/` 与 `Core/`。
