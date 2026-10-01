# 结算小票 · 第二轮优化

2026-10-02。交付阶段：**原生小样完成，待 Rex 审阅**。Rex 授权优化第一版的信息层级、出纸质感、重复查看与完成后的去向；本轮继续使用固定示例和独立内存容器。

## 可见变化

- 结算状态、预算 / 周期和核心金额稳定置于纸面上方，出纸时即可读取。
- 默认票面只突出资金去向、结算后的心愿钱包及待恢复差额；本期额度和支出通过「查看本期明细」展开。
- 出纸总时长保持不变，启停增加缓冲，槽口阴影随纸张出现减弱。展开明细、查看钱包和退出立即结束出纸。
- 同一次演示会话中，每个示例仅首次查看自动出纸；再次查看直接显示完整结果，并保留明细展开状态。重播、直接看结果和示例切换收至右上「演示选项」。
- 「返回预算」「查看心愿钱包」提供可操作、明确标注的示例目的页；没有连接真实预算或钱包。

## 直接审阅

- [正常出纸 · 7 秒原速录像](normal-original-speed.mp4)
- [减少动态效果 · 6 秒静态版本录像](reduced-motion-original-speed.mp4)
- [结余默认票面](01-surplus-compact.png)、[越线](02-overrun.png)、[展开明细](03-details-expanded.png)、[钱包示例页](04-wallet-example.png)
- [小屏 / 大字号滚至末尾](05-small-large-text-scrolled.png)、[VoiceOver 返回结果](06-voiceover-returned.png)、[英文 / 深色](07-english-dark.png)
- [出纸中的核心结果](08-result-during-print.png)、[原生 VoiceOver 朗读记录](voiceover-spoken-example.txt)

录像来自运行中的原生 App，按源时间戳转换为 60fps，不加速；静态录像裁去启动前的等待段。模拟器录像不代表真机帧率。原始 MOV 留存在本机视觉产物目录，第一版记录见 [2026-10-01](../2026-10-01-settlement-receipt/README.md)。

## 运行与验收路径

Xcode 打开 `Check_Line.xcodeproj`，选择 **CheckLine Receipt Study** Scheme 和 iPhone 模拟器后 Run。运行 CheckLine App，不要手动打开 UI Tests Runner。

1. 首次进入：核心金额应先可读，纸张随后出槽，主要按钮始终可用。
2. 展开明细：立即出现完整纸面，并显示本期额度及支出。收起恢复精简票面。
3. 查看心愿钱包并返回：显示同一示例结果，返回后不自动重播。
4. 返回预算示例页，再点「查看小样」：保留示例与明细选择，直接显示完整结果。
5. 右上演示选项切换越线、重播或直接看结果：金额与票面应一致，旧播放不能覆盖新状态。
6. 添加 `-design-reduce-motion`，或开启系统减少动态效果：完整静态小票；VoiceOver 开启后同样静态呈现。

自动出纸的已查看状态只保存在演示会话，重启重置。正式接入需要读取已持久化的真实结算记录，并按稳定标识区分首次完成与历史重看。

示例结余 ¥532：补待恢复差额 ¥120，进入钱包 ¥412，结算后钱包 ¥1,092、差额 ¥0。示例越线 ¥240：扣钱包 ¥160，新增差额 ¥80，结算后钱包 ¥0、差额 ¥80。数字仅为展示用固定数据，不能替代金额引擎验证。

## 实际验证

| 环境与路径 | 结果 | 证据 |
| --- | --- | --- |
| iPhone 17 Pro / iOS 26.5，重播、直接看结果、示例切换、关闭后重看；静态降级；滚动；明细与示例目的页 | 4 个用例通过；VoiceOver 用例因系统版本跳过 | `ui-main-summary.json` |
| iPhone SE 3 / iOS 26.5，系统 accessibility-medium 字号，滚到票面末尾 | 大字号用例再次通过，关闭 / 返回预算 / 演示选项可达 | `ui-small-large-text-summary.json`、小屏截图 |
| iPhone 18 Pro / iOS 27，启用原生 VoiceOver，逐项朗读结果，打开钱包并返回 | VoiceOver 用例通过，读到 ¥532 与钱包 ¥1,092，完成往返 | `ui-voiceover-summary.json`、朗读记录与截图 |
| 槽口阴影最后调整后，iPhone 17 Pro / iOS 26.5 | 明细 / 目的页和重播 / 重看两个相关用例再次通过 | `ui-final-details-summary.json`、`ui-final-replay-summary.json` |
| iPhone 18 Pro / iOS 27，英文 / 深色 | 原生截图检查，无可见文字截断 | 英文截图 |
| Debug build-for-testing / Release generic iOS 无签名构建 | 通过；页面仍只在 DEBUG 中编译 | 本机构建日志 |

合计 **5 个不同 UI 用例分别通过**，其中 2 个新增、3 个更新；设备复测不计为新增用例。VoiceOver 使用真实系统服务朗读与操作，不以语义树检查代替。减少动态效果本轮以 Debug 标志验证静态降级，没有重新执行系统设置路径。

主测试与小屏 / VoiceOver 截图完成后，仅调整了槽口装饰的阴影叠放，随后重建并复测上述两个相关用例。结余 / 越线 / 明细 / 钱包及英文截图、录像使用该最终构建；小屏 / VoiceOver 证据来自调整前的同一功能实现。

本轮未改 Core、账本与金额算法，未重复运行此前 147 项领域与任务测试。没有接入真实结算写入、失败恢复或历史结算记录；没有新增声音。本轮未验收 iPad、真机触控 / 帧率 / 视觉或极端字号，最终体验仍由 Rex 验收，M4 未关闭。

## 实现边界

- 页面：`Check_Line/Features/Settlement/SettlementReceiptStudyView.swift`；测试：`Check_LineUITests/SettlementReceiptStudyUITests.swift`。
- 启动：Debug + `-design-preview -design-screen settlement-receipt`，隔离内存容器，不填充或修改用户账本。Release 不包含该页面。
- 复用项目材质、语义字号、按钮与面板动效，新增文案同步中文和英文。
- 后续正式集成只能在保存成功后出具小票；读取领域服务保存的结果，恢复原预算位置，失败仍停留在确认页。示例状态和固定金额不能进入正式数据流。
