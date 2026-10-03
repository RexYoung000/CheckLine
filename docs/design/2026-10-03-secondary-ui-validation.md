# 2026-10-03 次级状态与金额核对减负验证

本轮依据 Rex 对上一轮复查的实施授权，处理空态、分组记录与金额核对中的五类问题。沿用紫色材质、液位卡、四 Tab 与小朵；没有改变金额算法、原币保存或确认门禁。以下验证限定于具名原生任务，最终真机视觉与使用体验仍待 Rex 验收，M4 保持开放。

## 已实现与操作路径

| 场景 | 当前表现与验收路径 |
| --- | --- |
| 追溯确认 | 已结算周期的待确认记录 → 确认当前归属 → 查看真实操作说明、完整原周期、消费影响、钱包与待恢复差额 → 取消返回或确认。内部设计指令仅保留在隔离管理演示，正式确认页不显示。 |
| 已实现心愿为空 | 心愿 → 已实现 → 查看想实现，返回活跃清单；页首添加入口仍可用，不会引导创建后仍停留在空筛选。 |
| 日期分组记录 | 预算工作区 → 消费记录 → 按日期分组；行内只显示商家、金额与必要状态，日期由组标题表达。未分组列表保留日期，VoiceOver 仍读完整日期与待确认状态。 |
| 月度额度 | 调整月度额度 → 预览；旧额度与「本月及以后每月」新额度成组，剩余前后成组。旧默认额度确有差异时仍显示，已确认／待确认与两种越线风险保留，大字号纵向排列。 |
| 心愿购买与结算 | 心愿 → 购买兑现：实际金额与可编辑币种同组，汇率、换算与扣后余额合入钱包变化。结算：有效预览只显示一次完整暂估来源／时间，填写前或清空汇率后仍显示输入依据，提交条件不变。 |
| 首页／分析空态 | 无预算首页以小朵创建为主、邻近手动为次；分析整卡无消费时将行动合入日历，不再重复当天空态，日期浏览、周期外提示与数据覆盖仍在。 |

本轮隔离种子只用于 Debug 原生验证，并调用现有本地业务服务；不读写用户持久化账本，不表示真实导入或云端 Agent 已接通。跨币种结算种子显式确认 CNY 钱包，追溯种子持有稳定消费标识以便确认后继续查看详情。

## 验证结果

147 项 Swift Testing／38 suites 通过，参数展开 171 次；本轮没有改变金额领域逻辑。[领域原始摘要](evidence/2026-10-03-secondary-ui/domain-test-summary.json)直接导出自结果包。

15 个不同 UI 用例各有通过结果，重复运行不重复计数；这是分组及修复复测的结果，并非一次全套 15 项通过。[逐用例、原始摘要及警告](evidence/2026-10-03-secondary-ui/ui-test-evidence.json)保留了初轮和复测结果。

| 原生验证 | 实际结果 | 结果包（前缀 `/tmp/checkline-secondary-oct03-`） |
| --- | --- | --- |
| 主要操作／iPhone 17 Pro、iOS 26.5 | 14 项中 12 项通过；两处自动输入／滚动操作失败，随后定向复测通过。包含空首页双入口、无记录分析、消费筛选与逐级返回、英文键盘、额度、结算→购买。 | `ui-final.xcresult` |
| 金额与追溯复测／同一 iPhone | 5 项通过：已实现心愿空态→活跃清单→创建，英文最大辅助字号额度预览与取消，汇率填写／清空时依据准确切换，10 USD 购买按 7 换算为 CNY70、保存仍为 10 USD，追溯取消后保持待确认、再次确认成功。 | `amount-final.xcresult` |
| 小屏／iPhone SE 3、375 pt、iOS 26.5 | 操作区调整后 4 项通过，含英文最大辅助字号／深色额度核对→滚动到操作→返回编辑→取消；常规额度取消与保存、列表创建录入、精度与待确认风险、减少动态效果分支也通过。 | `small-final.xcresult` |
| iPad mini A17 Pro、iOS 26.5 | USD 购买→填写汇率→真实购买开关→确认→原币结果与钱包余额通过，停靠键盘下控件可达。 | `ipad.xcresult` |
| 原生 VoiceOver／iPhone 18 Pro、iOS 27 | 实际启用 VoiceOver，逐项读到咖啡记录，包含完整日期与待确认，双击进入详情后确认动作可用，最后关闭 VoiceOver。仅此具名任务通过。 | `voiceover.xcresult` |
| 原速触控记录／iPhone 17 Pro、iOS 26.5 | 追溯详情→影响核对→取消→重开→确认，通过同一具名原生用例。 | `recorded.xcresult` |

Debug 构建由 UI 测试完成；最终 Release 通用 iOS 构建通过（仅构建、关闭签名），日志 `/tmp/checkline-secondary-oct03-release-delivery.log`。中英文各 643 个唯一键，键集合一致，无重复；`git diff --check` 通过。

## 截图与操作记录

以下均来自运行中的原生界面或 XCTest 原始截图附件，没有重绘。演示金额属于隔离测试数据。

| 证据 | 内容 |
| --- | --- |
| [首页空态](evidence/2026-10-03-secondary-ui/01-home-empty.png)／[分析空态](evidence/2026-10-03-secondary-ui/02-analysis-empty.png) | 主次创建入口、日历内的单一记录行动 |
| [已实现心愿为空](evidence/2026-10-03-secondary-ui/03-completed-wish-empty.png)／[日期分组待确认](evidence/2026-10-03-secondary-ui/04-grouped-pending-records.png) | 返回活跃清单与精简记录行 |
| [额度前后变化](evidence/2026-10-03-secondary-ui/05-monthly-amount-pairs.png)／[追溯影响](evidence/2026-10-03-secondary-ui/06-retrospective-impact.png) | 成组金额、原周期和修正后的钱包 |
| [购买钱包影响](evidence/2026-10-03-secondary-ui/07-wish-purchase-impact.png)／[原币保存结果](evidence/2026-10-03-secondary-ui/08-wish-original-currency-saved.png)／[结算汇率依据](evidence/2026-10-03-secondary-ui/09-settlement-single-quote-source.png) | 原币与换算影响连续保留，结算不重复显示来源／时间 |
| [iPad 购买与键盘](evidence/2026-10-03-secondary-ui/10-ipad-purchase-and-keyboard.png)／[小屏大字金额](evidence/2026-10-03-secondary-ui/11-small-dark-large-amounts.png)／[小屏大字操作](evidence/2026-10-03-secondary-ui/12-small-dark-large-actions.png) | 大字号内容通过连续滚动查看，按钮不再固定挤占正文；不要求金额和全部操作同屏 |
| [VoiceOver 原始朗读](evidence/2026-10-03-secondary-ui/grouped-record-voiceover-speech.txt)／[原速追溯自动触控录像](evidence/2026-10-03-secondary-ui/13-retrospective-native-touch.mp4) | 16.5 秒原始录制，以 XCTest 操作原生控件，无加速 |

## 修复与验收边界

- 初轮金额分组父层标识覆盖子项标识，已移除；隔离 FX 种子首卡自动切换钱包币种，已显式确认 CNY 钱包；隔离追溯预览按待确认状态动态查找导致确认后详情为空，已固定记录标识。这些失败没有计作通过。
- 后续两处测试失败来自尾端光标与键盘区域手势，已改为明确定位光标及在正文内滚动，并实际完成原币保存和汇率切换复测。小屏截图发现固定大字操作区过高，改为随正文滚动后复测通过。
- Release 保留既有两处 actor 隔离警告和一处未使用预览警告。输入用例仍记录 `Invalid frame dimension (negative or non-finite)`；上一轮已在改动前基线复现，详见 [既有警告对照](2026-10-02-ui-cleanup-validation.md)。本轮没有消除其根因。
- 没有物理设备操作、帧耗时测量、全 App VoiceOver 巡检或全部横竖屏组合。减少动态效果本轮只复查现有隔离分支，没有重跑系统设置路径；iOS 17 仅经最低部署目标编译。当前没有新增动效，语音、云端 Agent、图片解析、被动来源和真实导入仍未接通。

Rex 可运行 `CheckLine Demo`，依次检查心愿筛选空态、预算消费记录、额度预览与返回、心愿购买、分析日历。新建空账本可检查首页创建；真实追溯需已有已结算周期的待确认记录，亦可先查看本页隔离截图与录像。`CheckLine App` 为本机持久化 App，日常使用不要打开 `Check_LineUITests-Runner`。
