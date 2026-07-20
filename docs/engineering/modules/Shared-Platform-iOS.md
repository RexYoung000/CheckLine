# Shared/Platform/iOS/

iOS 独占代码。所有 `#if os(iOS)` 条件编译集中放在这里，不让业务代码直接写。

放在这里的内容：
- **Widget 数据桥接**：SwiftData 在 App Group 容器的配置
- **Photos 监听**：截图识别入口的相册权限与监听
- **Lock Screen 交互**：Stand By / Widget 刷新策略
- **Haptic 适配**：iOS 特有的触感强度分级（light / medium / heavy）
- **Speech 权限**：SFSpeechRecognizer 请求
