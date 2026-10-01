# 结算完成 · 打印小票原生小样

2026-10-01。交付阶段：**原生小样完成，待 Rex 审阅**。本轮只探索结算完成的表现，尚未接入正式结算页。

参考 [Richard Zhang 的打印效果](https://x.com/RichardZhang_/status/2105558891488739655) 的槽口遮挡和出纸方式；全部用原生绘制，沿用 CheckLine 材质和紫色 Token。示例来自固定展示数据，不调用领域结算服务、不改用户账本。声音不在本轮实现内。

## 直接查看

- [正常出纸 · 原速录像](normal-original-speed.mp4)
- [减少动态效果 · 静态版本录像](reduced-motion-original-speed.mp4)
- [结余结果](01-surplus-zh.png)、[越线结果](02-overrun-zh.png)、[静态结果](03-reduced-motion-zh.png)
- [英文 / 深色](04-english-dark.png)、[小屏 / 大字号首屏](05-small-large-text-zh.png)、[滚动至小票末尾](06-small-large-text-scrolled.png)

录像来自运行中的原生 App，保留原始时间戳并转为 60fps 便于播放；只裁去等待段，不加速。它们证明所呈现的出纸 / 静态效果，不代表真机帧率。

## 运行与审阅

在 Xcode 打开 `Check_Line.xcodeproj`，选择共享 Scheme **CheckLine Receipt Study**，选择 iPhone 模拟器后 Run。运行的是 CheckLine App；不要手动打开 UI Tests Runner。

1. 看一次完整出纸，核对周期、结余和钱包变化的阅读顺序。
2. 连点「重播出纸」，随时点「直接看结果」：完整小票应立即出现，旧动画不能继续覆盖结果。
3. 切换「越线示例」：纸面语言保持一致，金额说明改为扣减钱包和新增待恢复差额。
4. 在出纸时关闭，再打开小样：可以重新播放，不排队、不丢失当前示例选择。
5. 开启系统减少动态效果后重新进入，或在 Scheme 添加 `-design-reduce-motion`：完整静态小票直接可读。

示例结余：额度 ¥3,000、已确认支出 ¥2,468、结余 ¥532，其中 ¥120 补差额、¥412 进入钱包。示例越线：支出 ¥3,240、越线 ¥240，其中扣钱包 ¥160、新增差额 ¥80。这些数值只用于设计状态，不能替代金额引擎验证。

## 本轮验证

| 环境 / 路径 | 实际结果 | 证据 |
| --- | --- | --- |
| iPhone 17 Pro / iOS 26.5，普通出纸、连续重播、立即看结果、切换结果、关闭重开 | 1 个 UI 用例通过 | `ui-replay-reduced-summary.json`、正常录像 |
| 同设备，Debug 减少动态效果降级 | 1 个 UI 用例通过，完整静态结果，示例切换可用 | 同一结果摘要、静态录像 |
| iPhone SE 3 / iOS 26.5，中文 accessibility-medium / 深色，滚至末尾 | 1 个 UI 用例通过，内容完整，关闭和示例切换仍可达 | `ui-small-large-text-summary.json`、首屏 / 末尾截图 |
| iPhone 17 Pro，英文 / 深色 | 原生截图人工检查，无可见文字截断 | 英文截图 |
| Debug build-for-testing / Release generic iOS 构建 | 通过；小样页面及启动分支受 DEBUG 限制 | 本地构建日志 |

第一轮普通动画中断测试失败：目标进度已经是 1，但纸面的呈现动画仍继续。修正为取消原动画任务并替换纸面呈现，两个原有 UI 用例重新通过；随后新增小屏 / 大字号滚动用例通过。未更改金额服务，本轮未重复运行此前 147 项领域与任务测试。

本轮没有运行 iPad、VoiceOver、真机触控 / 帧率 / 视觉验收或真实结算写入；系统减少动态效果本轮使用 Debug 标志验证降级，尚未重新执行系统设置路径。VoiceOver 静态分支已有代码，不能据此声称辅助技术体验通过。M4 未关闭。

## 代码与边界

- 展示页：`Check_Line/Features/Settlement/SettlementReceiptStudyView.swift`。
- 启动契约：Debug + `-design-preview -design-screen settlement-receipt`，使用独立内存容器，不填充演示账本。
- 真实结算页保持现有行为。将来接入时必须读取已经保存的结算结果；失败不能出具完成小票，钱包与差额仍由领域服务计算。
- 设计契约见 `docs/design/DESIGN.md` 3.1.11；最终采用范围、打印声音及真机表现待后续确认。
