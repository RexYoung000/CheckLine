# 2026-10-28 小朵 Harness / Workflow 修复与回归

基于 `0b64445` 修复本轮审查的两个 P1、归属修正、动作追问与日期处理。先更新 `ARCHITECTURE`、`FEATURE-LOOP` 和 `DESIGN` 的契约再实施。没有修改账本 Schema、金额算法、页面配色、卡片材质或动效；保留工作区已有 HTML 实验。

## 已实现

| 问题 | 修复与验证重点 |
|---|---|
| P1：明确预算入口把“没有花35元”写成消费 | 本地解析和字段合并前检查实际消费语义；否定、计划、报价、退款等转现有追问，保留输入和未完成任务。正常肯定消费仍可保存并撤销。 |
| P1：两次同商家同金额主动记录被吞并 | 主动任务不按相似度合并；同一实体重试保持幂等。稳定外部标识和有依据的跨来源去重保留，冲突与多匹配不任取一笔。历史记录不清理、不重算。 |
| 新归属被旧预算覆盖 | 新卡名或待核对归属使旧选择失效，按消费日重新求周期；否定、未知、重名、无可用周期均不能退回旧卡。 |
| 动作追问丢字段 | 选择继续同一操作时保留任务身份、金额、商家、日期、备注和附件；明确另记／切操作不搬运旧任务事实。取消和迟到回调不能修改新任务。 |
| 否定／未来日期与毫秒解析不一致 | 服务端按请求设备日历核对；原生草稿和校验共用 ISO／纯日期解析。不支持或非法日期不被旧日期／今天掩盖；小数秒和时区不再被草稿忽略。 |
| 动作、归属、日期组合追问绕过门禁 | 服务端可选 `requiresDateReview`、`requiresBudgetReview` 独立保留未决状态，模型不得伪造；继续同任务后仍须逐项核对。HTTP 请求及账本 Schema 不变，旧响应仍兼容。 |
| 离线降级忽略日期、把年份当金额 | 简单今天／昨天／前天按设备日历处理，其余日期表达保守核对；先隔离日期数字再提取消费金额，不新增通用自然语言日期能力。 |

取消、重启恢复、保存失败后重试、重复确认、币种修正与归属选择均使用隔离候选和账本验证。没有增加退款、已保存消费编辑或多笔自动处理等业务能力。

## 实际验证

| 范围 | 最终结果 | 本机结果包／日志 |
|---|---|---|
| 原生全部领域与任务测试，iOS 27 | **298 项 / 58 suites 通过** | `/tmp/checkline-agent-fix-final2-ios27.xcresult`、同名 `.log` |
| 原生全部领域与任务测试，iOS 26.5 | **298 项 / 58 suites 通过** | `/tmp/checkline-agent-fix-final-ios26.xcresult`、同名 `.log` |
| Node 24.16.0 服务端、HTTP、审阅任务与合成候选 | **335/335 通过，无跳过** | `/tmp/checkline-agent-fix-server-final.log` |
| Swift／服务端候选契约 | `npm run check-contract` 通过，包括新增字段类型与模型排除 | `services/agent-api/scripts/check-contract.mjs` |
| 原生 UI，iOS 27 | **6 条不同路径均有通过结果**；分批运行，首次旧导航测试失败后修正重跑 | 下表 |

本轮新增 4 个原生测试文件，共 39 个测试方法（参数展开另计），最终全量由 259 增至 298。服务端由 276 增至 335。两个运行时的同名测试不合计为不同用例。

| UI 用例 | 结果包 |
|---|---|
| `AgentSafetyUITests.testNegatedExpenseFromExplicitBudgetKeepsInputWithoutSaving` | `/tmp/checkline-agent-fix-ui-ios27.xcresult` |
| `AgentConversationUITests.testMissingAmountKeepsConversationAndInputThroughSaveAndUndo` | 同上 |
| `AgentConversationUITests.testCancellingFirstVoiceExplanationPreservesUnsentInput` | 同上；只验证说明层取消，不是实际语音识别 |
| `TaskEnvironmentUITests.testEnglishTaskKeepsItsFieldsAndSaveReachableWithKeyboard` | 同上 |
| `TaskEnvironmentUITests.testPersistentDraftSurvivesAppRelaunchWithoutSubmittingLedger` | `/tmp/checkline-agent-fix-ui-relaunch-ios27.xcresult` |
| `AgentSafetyUITests.testOfflineDateClarificationDoesNotSaveUntilDateIsAnswered` | `/tmp/checkline-agent-fix-ui-offline-ios27.xcresult` |

首轮 UI 批次 4/5 通过：草稿恢复测试点击旧 `wallet.functions` 入口失败，已改为当前 `wallet.header.create` 并独立复验通过。复合更正的服务端新增反例先 3/3 失败，修正提前返回顺序及待核对状态后通过；审阅任务在候选不重复提供金额时也曾丢失旧金额，补充反例失败后修正为只合并明确字段。离线独立复现曾把 `2026-10-29午餐35` 提取为金额 2026，正式回归现在验证金额 35 且必须核对日期。

截图均为隔离演示内容，已实际查看；没有用户账本截图：

- [否定消费保留输入，没有保存](negated-expense-not-saved.png)
- [离线日期先核对，再接受“昨天”并完成保存／撤销](offline-date-review.png)

复现命令：在 `services/agent-api` 运行 `npm test`、`npm run check-contract`；原生运行 `CheckLine App` Scheme 的 `Check_LineTests`（iOS 27 / 26.5 模拟器），UI 使用 `CheckLine UI` Scheme 按上表具名筛选。命令统一使用 `-parallel-testing-enabled NO -collect-test-diagnostics never`。本轮没有向真实模型发送请求；单元测试使用内存账本和注入候选，UI 使用 Demo 或模拟器持久化沙盒，未清空真实设备数据。

## 交付边界

- **代码和回归完成**；本轮未部署腾讯云服务、未更换手机安装版本、未发布 App Store。手机仍是此前已安装的 1.0（18），不能把本轮模拟器结果当成手机已经生效。
- **真实模型与端到端云手机链路未复测**。合成候选验证程序门禁，不证明模型对所有表达都正确；公开服务、凭据续期及实际手机体验不据此宣称已验收。
- iOS 17–25 本轮没有可用运行时；未重新跑全页面视觉、VoiceOver 或实际语音识别。UI 日志仍有既有 `Invalid frame dimension` 警告，以及 Xcode 27 SDK／调试器诊断；断言通过不等于日志完全无告警。这些渲染问题不在本轮 Agent 修复内。
- 没有读取或修改手机真实账本、清空草稿、卸载 App 或改变云端许可。已有 HTML 实验的跟踪文件 diff 与开工快照逐字一致，未纳入本轮提交。
