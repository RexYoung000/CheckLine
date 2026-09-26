# 小朵原生接入证据 · 2026-09-26

范围：静态系统 Tab 头像、原生动画组件、助手面板标题与状态，不含整套清透 UI 改版、Rive / Spine 资产或云端模型。

## 已检查

- `native-tabs.png`、`agent-panel.png`：iPhone 18 Pro / iOS 27 模拟器，中文。既有系统导航 UI 测试点击四入口，连续开关助手两次，确认关闭后保留原页面；1 项通过，结果 `/tmp/checkline-xiaoduo-ui.xcresult`。
- `thinking-normal-speed.mp4`：同一模拟器，原生 Debug 隔离动效审阅页。8 秒正常速度片段，保留原始时间，不加速；大图与 44 pt 头像均显示双色内流。已抽帧检查内色位置变化；最终节奏和真机帧耗时未验收。这是模拟思考状态，不代表真实模型延迟。
- 104 项 Swift Testing / 32 suites 通过，包含新增 4 项：已认可 JS 采样与 Swift 坐标对照、中途打断与暂停恢复、各态持续内色与减少动态、真实确认 / 保存失败 / 重试 / 取消的状态映射。套件包含历史测试，不作为全部 V1 业务已验收的依据。最终成功表情缓慢回正调整后，新增 4 项再次通过。
- Debug 模拟器构建、Release iPhone 12 构建通过。保留工程既有的 actor 隔离及未使用变量等警告；新增测试中的捕获变量警告已消除。本地化状态键显示问题经实际截图发现并修正。
- 额外静态检查：iPad mini / iOS 27 英文助手面板；375 pt iPhone SE / iOS 26.5，英文辅助功能最大字号、确认态及 Debug 减少动态。标题与说明纵向换行，没有横向裁切；最大字号需要滚动查看表单，未核验该组合的完整触控流程。截图在 `/tmp/checkline-xiaoduo-review/`。
- 最终 Release 已安装到 iPhone 12，包名 `Rex.Check-Line`；保留本地账本。自动启动被设备锁屏拒绝，安装成功不代表真机视觉验收。

## 复现

使用 `CheckLine Demo` Debug 配置；`-design-preview -design-screen agent` 查看隔离示例助手，`agent-confirm` 查看待确认，`agent-mascot -mascot-state thinking` 查看纯动效；加 `-design-reduce-motion` 查看静态表达。Release 不启用这些入口。

正常 App 从右侧云朵打开小朵。本地查询可能立即返回，不为展示思考动画增加延时。系统 Tab 图片静态，动画在面板内播放。

## 未验证

真机正常速度观感、Debug / Release 帧耗时与能耗，VoiceOver 实际朗读、系统减少动态开关、键盘完整路径、iOS 17 运行时。Device Hub 的人工 UI 控制本轮超时；导航操作证据来自原生 XCTest，不能表述为人工触控验收。

3.1.8 的浅紫清透整体 UI 仍为 HTML 设计稿，本轮未改首页、预算、心愿、分析与设置的整体布局。后续先按 Rex 要求重新审稿。
