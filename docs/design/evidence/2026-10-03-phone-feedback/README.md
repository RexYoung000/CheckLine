# 首页、心愿、分析与真机试装验证

2026-10-03。原生页面已实装，当前阶段仍为 M4；视觉和手感待 Rex 验收。测试使用 Debug 的隔离示例账本，不读写手机正式账本。功能图标已接受，桌面 App Icon 仍在讨论，三个小朵构图没有替换正式资源。

## 实际变化与验收路径

| 入口 | 预期结果 | 原生证据 |
| --- | --- | --- |
| 首页，浅／深色 | 卡夹前沿有独立材质和遮挡；已用与日历为紧凑独立区块，最近记录不被拉远 | [浅色小屏](home-small-light.png)、[深色小屏](home-small-dark.png) |
| 首页 → 铃铛 → 已到期预算 | 关闭任务面板后进入完整预算工作区；记录返回概览，再返回原首页，不叠两张预算卡 | [工作区](overdue-full-workspace.png)、[返回首页](overdue-back-home.png)、[原速往返录像](overdue-workspace-navigation.mp4) |
| 首页 → 铃铛 → 待确认预算 | 完整页的待确认筛选直接选中，返回恢复原卡片 | [待确认目录](pending-full-workspace-from-home.png) |
| 心愿 | 名称为心愿余额，空态只有一处添加；完成项为静态「已实现」章节，条目仍可打开实际购买详情 | [已实现章节](completed-wish-static-section.png)、[购买详情](completed-wish-static-detail.png)、[iPad 英文](wishes-ipad-en.png) |
| 分析 → 选择预算 → 已用 | 预算／周期与金额／图表分层；完整记录页返回后保持选择 | [分析](analysis-keeps-selected-card.png)、[完整记录](analysis-full-records.png)、[iPad](analysis-ipad-light.png) |
| 分析空周期 | 仍可浏览日期并查看数据覆盖，不用重复空态区块 | [日期与覆盖](analysis-empty-date-and-coverage.png) |
| 首页，最大辅助字号／英文／深色／减少动态效果 | 摘要纵向，卡片上滑优先滚动，记一笔和摘要可滚到悬浮底栏上方使用 | [大字号摘要](large-english-summaries.png) |
| VoiceOver → 待处理 → 已到期预算 → 返回 | 朗读预算名和到期状态，双击打开完整页再返回 | [真实朗读文本](overdue-voiceover-speech.txt)、[返回画面](voiceover-overdue-return.png) |

到期示例只在 Debug 设计预览中构造；不改正式周期规则。正常安装不携带设计预览参数，使用原本的持久化账本。自动触控录像为正常速度，截去启动等待，未加速；录制于最后的抽卡手势修正前，完整工作区导航未再改变，最新构建另有相同路径回归通过。截图不能单独证明动效或触控体验。

## 构建、安装和测试事实

- 模拟器 Debug、模拟器 Release 和签名 iPhone Debug 构建通过；双语字符串格式与 Git 差异检查通过。
- 最新签名构建覆盖安装到已连接的 iPhone 12，正式 Bundle ID 为 `Rex.Check-Line`，显示名为「预算线」。没有卸载或重置账本。设备安装返回成功；启动返回设备锁屏，未完成手机打开和真机视觉检查。
- 147 个不同领域测试通过，含动态参数共 171 次执行，零失败／跳过；本轮没有改领域金额逻辑。结果包：`/tmp/checkline-feedback-domain.xcresult`。
- 10 个不同 UI 用例分别通过：7 项在 iPhone 18 Pro / iOS 27.0 通过，2 项小屏布局／到期导航在 iPhone SE 3 / iOS 26.5 通过，大字号真实操作在同一小屏修复后通过。实际点击验证记一笔打开／关闭、已用展开／关闭、日历展开／关闭，未把存在性检查当作操作验证。
- iPad mini / iOS 26.5 的英文心愿和浅色分析已查看实际渲染；这只证明这些页面的布局，没有重新验证 iPad 全流程和键盘。

[测试结果摘录](test-results.json)保存最终通过用例与设备信息；完整复验结果包保存在本机 `/tmp`，不作为仓库长期二进制材料：

| 结果包 | 覆盖 |
| --- | --- |
| `/tmp/checkline-feedback-complete.xcresult` | 7 项通过：心愿空态／完成详情与创建，分析空态／完整记录与选择恢复，待确认全页往返，VoiceOver 到期往返，工作区记录确认与逐级返回 |
| `/tmp/checkline-feedback-gesture-final.xcresult` | 小屏浅深色紧凑摘要、到期全页往返各通过；当时的大字号用例上滑过头，后续修正自动滚动定位并复测 |
| `/tmp/checkline-feedback-large-actions-final.xcresult` | 最大辅助字号、英文、深色、减少动态效果：上滑、记一笔打开／关闭、已用展开／关闭、日历展开／关闭通过 |

调试中纠正了测试对「已到期」文案和首页铃铛入口的错误假设；最大字号真实上滑曾被卡片长按拖动抢走并误开详情，现已在单卡、辅助字号、减少动态效果下彻底移除该识别器。之后的测试定位改为短距离双向滚动，避免自动化甩动越过目标；摘要使用既有集中展开界面，不能误以为消费记录导航。

## 验收边界

本轮未重跑整个 App 的所有 UI 回归，也未覆盖所有设备／语言／字号组合、旧版 iOS 17、iPad 分屏、整个 App 的 VoiceOver、真实导入或真机手动触控。云端模型、Speech、Vision 与被动来源仍未启用。卡夹材料、区块比例、动效手感和品牌视觉由 Rex 在实际设备上验收；这些通过结果不关闭 M4。
