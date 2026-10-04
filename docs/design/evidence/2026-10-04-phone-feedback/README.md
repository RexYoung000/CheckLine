# 2026-10-04 手机试用反馈：原生实现与验证

本轮对应 Rex 的六项试用反馈，沿用已确认的四 Tab、材质和 App Icon。状态为代码已接入、具名操作路径已验证；云端模型仍关闭，真实音频识别和 Rex 真机体验验收未完成。

## 实际改动与状态流

| 入口 | 当前行为与取消／恢复 |
| --- | --- |
| 小朵文字 | 输入 → 缺字段逐次追问 → 同一任务补全 → 正文内核对 → 保存／撤销。输入区一直保留；明确低风险记录仍按原门禁直接执行。未知句子不强行创建消费。 |
| 任务恢复／切手动 | 持久化当前已解析字段、已发送原文与待补字段；对话仅在本次会话。切手动只吸收未发送输入，避免最早金额覆盖后来的修正。主动另起消费清旧金额；明确添加的附件、日期、币种保留。 |
| 语音 | 点击 → 用途说明 → 端侧支持检查 → 按需系统授权 → 转写到输入框 → 停止／检查文字 → 用户发送。取消恢复录音前文字，关闭／后台／中断保留已转写文字并停止采集。失败可继续文字输入；不自动提交、不开云端回退。 |
| 创建预算 | 右上「请小朵帮我填」；原生周期选择与真实生效日期联动。放弃只出现一个破坏性动作，保留草稿后字段仍在。 |
| 添加心愿 | 名称、可选预计花费、独立币种选择、保存；移除创建页图标。USD 选择随保存及购买页保留，添加不换算、不占用钱包。 |
| 心愿余额 | 主金额 → 三个增减区块 → 变动记录 → 可展开完整规则；有待恢复差额时先说明补齐。辅助功能字号直接大面板，内容可滚动。 |
| 无预算的分析 | 一处创建引导，不展示无依据的日期；创建真实预算后，才出现对应周期日历。 |

语音通过 Apple [设备端支持检查](https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportsondevicerecognition)和[强制设备端请求](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition)约束；不持久化音频、不打印输入。周期控件使用标准 SwiftUI Picker，系统按运行时提供选择与玻璃反馈，参考 [Apple 标准控件说明](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)。没有新增第三方 SDK。

## 验证结果

- 完整领域回归：**171 项 / 41 suites，参数展开 199 次，通过**，结果 `/tmp/checkline-phone-feedback-oct4-domain-v4.xcresult`。
- 最后修正成功清草稿保留 Agent 模式后：**31 项对话、交互与草稿定向回归通过**，`/tmp/checkline-phone-feedback-domain-final.xcresult`。两组不能相加当作独立覆盖数。
- iOS 27：**6 项 UI 通过**，覆盖缺金额追问、正文核对、输入保持、保存撤销、语音首次说明取消、周期选择／取消放弃后建卡、USD 心愿保存／购买币种／钱包说明、无预算分析到真实周期，以及 VoiceOver 手动输入并保存。结果 `/tmp/checkline-phone-feedback-ui-final.xcresult`。
- iOS 26.5 小屏：**4 项 UI 通过**，英文键盘、最大辅助字号 Agent／语音说明／切手动保存、最大辅助字号深色心愿滚动选择 USD 并保存、预算追问切手动。结果 `/tmp/checkline-phone-feedback-small.xcresult`。
- iOS 26.5 iPad mini：**1 项心愿路径通过**，英文最大辅助字号、深色、USD 选择保存和钱包仍为零。初轮结果 `/tmp/checkline-phone-feedback-ipad.xcresult`，自动大面板修正后的最终同一路径复测 `/tmp/checkline-phone-feedback-ipad-final.xcresult` 亦通过。
- iOS 26.5 常规 iPhone 的初轮中，共享字段切换及关闭恢复、语音取消后手动保存、空首页 Agent 建卡、心愿币种、分析路径通过；失败项已修复并在上述分组复测。结果 `/tmp/checkline-phone-feedback-ui-oct4.xcresult` 本身是失败包，不标记为整体通过。
- 共 **13 个不同 UI 用例**有通过结果，跨设备重复不叠加。小屏心愿余额自动大面板的最终定向复测通过：`/tmp/checkline-phone-feedback-large-balance-final.xcresult`，截图已替换为复测产物。
- Debug 模拟器与签名 Release iOS 构建通过；中英文各 690 个本地化键一致，无重复，`.strings` 格式与 `git diff --check` 通过。已有隔离相关编译警告未在本轮扩大处理。

初轮真实发现并修复：旧查询回复被清空；裸商家续句继承旧金额；恢复后切手动重新解析原话导致金额／币种回退；成功清草稿重置为表单导致撤销不可点。新增语音测试的宏写法曾导致测试目标编译失败，修正后完整运行。预算空态入口和对话无障碍标签变更后的旧定位器已修正，保留原行为断言。

## 原生画面与操作证据

全部使用隔离测试账本，没有采集手机真实财务内容。

| 场景 | 截图／录像 |
| --- | --- |
| 缺金额继续对话 | [追问](agent-followup-ios27.png) |
| 同面板核对，继续输入 | [核对卡](agent-inline-confirmation-ios27.png) |
| 保存后仍在对话内撤销 | [撤销结果](agent-undo-ios27.png) |
| 首次语音用途说明 | [说明](voice-first-use-ios27.png)，仅验证取消；未点击授权开始录音 |
| 创建预算与原生周期 | [表单](budget-native-cycle-ios27.png)、[Device Hub 原速操作录像](native-cycle-interaction-ios27.mp4) |
| 单一放弃动作 | [确认提示](discard-single-action-ios27.png) |
| 心愿货币可选且保存 | [USD 表单](wish-currency-ios26.png)、[保存后详情](wish-saved-usd-ios26.png) |
| 心愿余额层级 | [默认说明](wish-balance-ios26.png)、[展开规则](wish-balance-rules-ios26.png) |
| 分析无预算 | [空态](analysis-no-budget-ios26.png) |
| 小屏英文／最大辅助字号／深色 | [心愿可达并保存](wish-small-english-dark-large.png)、[Agent 键盘与操作](agent-small-english-large-keyboard.png)、[余额](balance-small-english-dark-large.png) |
| iPad 英文／最大辅助字号／深色 | [心愿](wish-ipad-english-dark-large.png) |
| 具名 VoiceOver 任务 | [手动输入并保存](voiceover-record-saved-ios27.png)，完整朗读附件保留在 UI 结果包 |

周期录像由 Device Hub 录制按钮保存，真实点击／拖动后日期说明与最终选项一致。录像与模拟器行为不代表真机触摸手感、帧耗时或最终玻璃观感已验收。

## 手机安装与验收路径

签名 Release **1.0（4）已覆盖安装 iPhone 12**，设备应用查询确认 `Rex.Check-Line` 的 `bundleVersion=4`。未卸载、重置账本或传入演示参数。首次设备清单显示断开，但实际安装建立连接并成功；自动启动随后被系统以 **Locked** 拒绝。辅助字号大面板的最终 Release 重建及第二次覆盖安装也返回成功（`/tmp/checkline-phone-feedback-device-final.log`、`/tmp/checkline-phone-feedback-install-final.json`）；私人设备标识与完整安装日志未提交。

解锁后点「预算线」：

1. 打开小朵，发送「我想录一笔」，补「午餐 35 元」；应连续追问／核对，保存后仍可撤销。
2. 从预算页创建，检查右上助手入口，切每月／一次性，再选择放弃并保留草稿。
3. 心愿 → 添加心愿 → USD → 填金额并保存，查看详情及心愿余额。
4. 无预算的分析空态请在隔离模拟器查看，勿为验收删除手机已有卡片。
5. 麦克风按钮由 Rex 主动授权后测试「说话 → 停止 → 检查文字 → 发送」；不支持的设备／语言应明确失败并保留文字入口。

## 尚未验证或接通

- **真实模型未接入。** 当前是本地规则追问，不能称为完整模型对话。服务商、模型、密钥保存和授权数据流需确定后实施。
- **真实音频未验证。** 已有状态测试覆盖取消、旧回调、部分结果、中断、拒绝、无声与结束；这些不替代麦克风／Speech 系统授权、真实设备语言资产、识别准确性、来电或实际后台的运行测试。
- 本轮未全面重跑系统减少动态效果、所有页面 VoiceOver、iOS 17 运行时或真机帧耗时。对话滚动遵循现有 Reduce Motion 环境，周期控件采用系统行为。
- 手机自动启动受锁屏阻止；Rex 真机视觉与使用体验、M4 和完整 V1 验收均保持开放。
