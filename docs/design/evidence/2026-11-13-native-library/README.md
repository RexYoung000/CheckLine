# 卡库正式接入与结算保留 · 2026-11-13

Rex 已接受浏览器 `glints-1` 的浅暗完整衔接，并授权移植正式工程，同时要求包含上午结算的 UI 与扫光。本轮已接入 `Check_Line` Target，使用真实领域投影与 SwiftUI Canvas；浏览器样稿已验收、原生模拟器检查通过、Rex 真机体验待验收分别记录。M4 保持开放。

2026-11-14 按 Rex 授权，签名 Release **1.0（19）已原位安装至 iPhone 12 并正常启动**；安装前后版本与进程检查通过，见[个人手机交付记录](phone-install-2026-11-14.md)。下方 11 月 13 日的构建／测试记录保持原有验证边界，最终真机视觉与手感仍待 Rex 验收。

## 可直接查看

- [浅色卡库完整原速录屏](native-light-complete.mp4)、[深色卡库完整原速录屏](native-dark-complete.mp4)：首页 → 卡库 → 连续切两张卡 → 短拖取消 → 下拉选用 → 同一卡落入卡夹。约 12 秒，保留回程和插卡全过程；只裁掉启动等待与第二次进入，不加速、不插值。来自 iPhone 17 Pro / iOS 26.5 模拟器的系统录屏与真实 XCTest 触摸，采集依据见 [native-clips.json](native-clips.json)。容器帧率不代表真机 FPS。
- 首屏：[浅色](library-light-first.png)、[深色](library-dark-first.png)。落位：[浅色](library-light-landed.png)、[深色](library-dark-landed.png)。
- 上午结算在本轮正式代码中的复验：[补差额扫光](settlement-recovery.mp4)、[越线扫光](settlement-overrun.mp4)；[补差额结果](settlement-recovery.png)、[越线结果](settlement-overrun.png)。均先完成真实隔离账本提交，再从确认按钮起光并揭晓已保存结果；原速裁取确认至结果稳定，未改变上午速度。
- iPhone SE 3：[小屏首屏](small-library-light-first.png)、[英文最大辅助字号](small-library-english-accessibility-text.png)。卡库在辅助字号、VoiceOver 或极矮视口采用可滚动卡列；正常减少动态仍保留静态周期环。

## 实现与边界

浅色保留 800 颗细粒及 12 个可能微光位置，只有剩余区段亮点带局部光晕；深色沿用 88 个主光点与 28 个远点。截止日包含当天；待开始、无截止日期不生成虚构进度。名称、含义标签与主金额共用清爽卡面；原待确认入口与金额规则继续保留。已确认越线不会被待确认退款撤销，投影只用于显示，不回写领域金额。

弧线浏览焦点与首页选用分开，侧卡先居中，中卡／返回控件／完成下拉才选用。取消保留浏览位置，正在回弹可重新抓取；场景中断取消未确认手势，已确认回程只完成一次选用。下拉期间首页卡夹隐藏；回程接近落位才出现卡夹，首页摘要与插卡尾部待落位后显示。回程 0.36 秒，再接现有 0.18 秒插卡及接触反馈；不引入旧换卡飞行动画。球面继续双轴浏览，搜索共用新卡面。

光点离屏、遮挡、后台及减少动态时停止连续绘制。首页复用光学外壳，保留既有液面和喷涌；小屏横屏入口按可用高度收紧，辅助字号对工具图标和卡数控制尺寸，避免挤压拉手。

预算详情、结算核对、上午结算结果／波纹以及心愿页面与碎玻璃均与本轮开始时一致：[14 个原生受保护文件哈希](protected-native.json)。正式结果来自本轮开始前已接入的结算代码，未替换成另一套结果。没有改账本 Schema、权限、服务器、公共 API 或真实个人账本。

## 验证

| 检查 | 实际结果 | 本机证据 |
| --- | --- | --- |
| Swift Testing / iOS 27.0 | 304 项 / 60 suites 通过；新增周期日界／DST、中性状态、金额语义、空液位和几何边界 | `/tmp/checkline-library-native-unit.xcresult`、同名前缀 `.log` |
| 合并 UI / iOS 26.5 | 22 项通过：卡库 9 项、结算与早结算、完整心愿碎玻璃、首页拔插／切卡／记录收起 | `/tmp/checkline-library-native-final-ui.xcresult`、同名前缀 `.log` |
| 最终卡库回程 | 浅暗完整过程及上方／边缘下拉 3 项通过；重新进入保持选用结果；该独立包无运行时警告 | `/tmp/checkline-library-native-verified-ui.xcresult`、同名前缀 `.log` |
| SE 3 小屏 | 竖屏完整流程、英文最大辅助字号、横屏进入与返回 3 项通过；随后修正大字工具图标和卡数，独立复验 1 项通过 | `/tmp/checkline-library-native-small2.xcresult`、`/tmp/checkline-library-native-large-final.xcresult` |
| 正式构建 | Debug 模拟器、通用 iOS arm64 Release 通过；SPM Metal 资源正常打包；Release 使用 `CODE_SIGNING_ALLOWED=NO` | `/tmp/checkline-library-native-release-final2.log` |
| 差异保护 | 上述 14 个原生文件未变；已接受样稿 `index.html` SHA-256 仍为 `dfc457e9d711da360aab1e49419c622cb9b4066ba15be9153dfe51ab59c71d12` | [validation.json](validation.json) |

这些是多个有名批次，不把重复用例累加为一次全绿。单元总数包含历史 `PrototypeDeletionTests`，不以此宣布 V1 验收完成。首次 UI 使用 Button 类型查询 SwiftUI 聚合节点导致定位失败，已改为语义查询；侧卡补了可点边缘，搜索移除了多余最小高度。首次 SE 横屏入口超出视口，已按可用高度修复并复验；失败包保留于 `/tmp/checkline-library-integration-ui{,2}.xcresult` 和 `/tmp/checkline-library-native-small.xcresult`。

22 项整组记录了一条未定位的 `Invalid frame dimension` 运行时提示；最终独立卡库包未出现。构建有既有测试 actor 隔离与 AppIntents 元数据提示，不宣称零告警。SE 横屏验证只断言入口、卡列和返回可用，旋转截图存在画布边缘异常，不作为横屏视觉通过依据。超长名称／极大金额的原生数据投影与组件预检已有覆盖，本轮没有逐一跑完其真机视觉矩阵；实际 VoiceOver、反向拖动与重抓的触感、iOS 17 运行、iPad 多任务、真机 GPU／电量和最终视觉仍待验收。

## 验收入口与提交状态

Xcode 选择 `CheckLine Demo` 在模拟器运行，首页右侧向下控件进入卡库。横滑浏览，短拖取消，再下拉松手选用，观察落位后的同卡与插卡反馈；再次进入应从刚选用的卡开始。切换设置里的浅／暗外观可对照两版。`CheckLine Demo` 使用每次启动重置的隔离账本，`CheckLine App` 使用正常本机持久化。

结算合成场景可在 Debug 添加 `-design-preview -design-screen settlement-recovery` 或 `settlement-overrun`，从「周末旅行」进入详情 → 结算 → 核对并确认。`-design-reduce-motion` 用于独立验证静态回退。测试与录屏都没有使用个人账本。

改动留在本地工作区，未提交、未推送、未创建 PR 或公开发布。11 月 13 日完成时尚未安装个人手机；11 月 14 日已按后续授权安装 1.0（19），见上方交付记录。已有上午改动和已暂存的其他文档删除保留原状，没有打包到一次混合提交中。
