# Capture/

录入子系统 —— 多入口的「记一笔」分发。所有入口最终都汇聚到归类弹窗（Manual）。

| 子目录 | 角色 | 优先级 |
|------|------|------|
| `Manual/` | 归类弹窗 + 手动录入。所有入口的最终汇聚点 | MVP |
| `OCR/` | 截图识别（Photos + Vision） | MVP |
| `Voice/` | 语音录入（Speech + 端侧解析） | MVP |
| `Share/` | 分享扩展（长按通知 → 分享到 CheckLine） | v1.1 |

**纪律**：
- Capture 子模块只调用 `Core/Services`，不跨 Feature
- 所有入口产出统一的 `ExpenseDraft`，由 Manual 弹窗最终确认提交
- iOS 平台特性集中在 `Shared/Platform/iOS`，不在 Capture 内直接条件编译
