# 2026-11-14—16 输入修复与全流程回归

**当前：模拟器待跑 7 项与键盘警告修复后复验全部通过（0 运行时告警）；真机复验与装机暂缓。** 按 Rex 2026-11-16 确认，本阶段先完成模拟器复验、清理 `.gitignore` 忽略 2026-11-14 大体积录屏（视频留本地不入库）并提交推送；正式手机仍为 1.0（20），此前签名的 1.0（21）早于 `PaperKeyboardDoneBar` 修复，后续上机前需重新构建签名。不能把多轮局部通过相加后宣称全 App 真机验收完成。

## 实际修复

| 项目 | 修复与证据 | 当前边界 |
| --- | --- | --- |
| 心愿名称点标题／留白不弹键盘 | 先用真实触摸复现，再补完整输入面命中；金额标题、装饰描边一并处理。相同失败用例修后通过 | 在独立 CheckLine QA 真机通过，正式版尚未更新 |
| 其他表单输入 | 新建预算名称／额度、记一笔商家／原始文字、心愿金额可从标题或输入面聚焦，币种独立点击 | 最新三条完整输入保存路径真机通过 |
| 结算扫光中转后台丢结果 | 原结果只存在局部 View 状态；重建后退回已无法提交的核对页。改为同会话、按周期匹配的精确成功快照，恢复显示静态结果，不重复保存 | 修前真机失败，修后模拟器同操作通过；修后真机仍待验证 |
| 首页待确认／未纳入行 | 补齐 Spacer 留白处矩形点击范围，不改布局 | 待确认行默认中心点按、进入和返回已通过 |
| 照片封面底栏 | 截图复查发现固定按钮背景仅包住中间，位置滑条从两侧透出；补齐背景宽度，按钮样式不变 | 2026-11-16 在专用临时模拟器注入合成图片重跑 `WishPhotoFlowUITests` 通过，并目检滑条位于固定保存按钮之上 |
| 空记录页进入记一笔 | 按既有 10-23 契约，从整个预算详情退出后再打开共享录入；与总览入口共用，避免嵌套页面自己切换模态 | 总览、空记录真实录入回程通过；12.34 草稿关闭后从同卡首页重开仍保留 |
| 键盘工具栏布局告警 | 定位 7 条输入框用例的 `Invalid frame dimension (negative or non-finite)` 来自 iOS 27 下 `.toolbar { ToolbarItemGroup(placement: .keyboard) }`；改用底部 `safeAreaInset` 内的 `PaperKeyboardDoneBar` | 28 项修复后模拟器 UI 回归（27 项输入/导航/异币种/结算 + 1 项照片封面）全部通过且运行时警告降为 0；真机待后续更新 |

没有修改金额规则、Schema、预算详情布局、结算核对样式或心愿碎玻璃。卡库／结算性能阶段的 20 版证据见[单独记录](../2026-11-14-interaction-performance/README.md)，不能用其局部通过代替本轮全流程验收。

## 覆盖和失败分层

已执行现行双导航的预算创建、月度区间与草稿、消费录入与详情、待确认归属、日历和数据覆盖、额度编辑、卡库浏览与取消／回收、钱包明细、心愿创建／兑现／封面、Agent 补字段和撤销、持久化重启、英文大字、VoiceOver 与减少动态等路径。照片选择只在专用模拟器注入合成图片后运行，没有打开个人手机的照片库。

首轮多个旧测试仍引用已移除的四 Tab、旧按钮标识或未滚动挂载的网格；现已改走真实入口，保留金额、确认门禁、归属和回程断言。旧分析趋势页不在当前导航，不能凭历史测试声称已实现。

另几类失败已留证并修订测试，但仍须实际复跑：

- 英文最大字号输入：旧 `isHittable` 判断将固定按钮下面的输入框当作可点击，实际触发保存。限定无遮挡视口后，真实金额输入、USD 保存及钱包不变已通过，没有重做页面布局。
- 异币种结算：DEBUG `settlement-fx` 入口用“仍待结算的周期”决定是否创建页面；保存后该条件消失，演示抽屉因此变空。正常预算详情按固定 period ID 保留结果。测试已改为关闭直接演示入口，再从同一合成预算卡进入，继续检查 +US$75、+¥525 和钱包 ¥1,385；新版本尚未跑过。
- 异币种兑现：旧测试从 DEBUG 根抽屉开始导致回程不代表真实入口；改走心愿卡后，又发现购买开关位于固定按钮下方，测试误判可点击。现已限定可交互区域并断言开关值，再检查真实购买、已实现和 ¥790 钱包；最新修订尚未跑过，不标通过。
- 最新预算周期测试在成功进入管理后，无障碍查询跨越约 965 秒休眠并超时；同一断言上一轮通过。休眠中完成的 VoiceOver、月周期和结算后台用例仅保留功能观察，不能用其耗时作性能结论，最后一轮仍列入复验。

## 精确运行记录

以下为各次运行，存在大量重复，**不累加为独立覆盖数**。机器可读结果、待跑方法和已签名包源码指纹见 [validation.json](validation.json)。

| 运行 | 通过／失败／跳过 | 解释 |
| --- | --- | --- |
| `checkline-input-surface-before` | 2 / 1 / 0 | 标题点击不弹键盘，搜索和持久化正常 |
| `checkline-input-surface-after` | 3 / 0 / 0 | 同三条修复后通过 |
| `checkline-input-phone-retry` | 8 / 1 / 0 | 真机；新增结算后台恢复失败，其余通过 |
| `checkline-input-phone-final` | 3 / 0 / 0 | 最新预算／消费／心愿输入面真机通过 |
| `checkline-full-flow-ui` | 125 / 11 / 1 | 137 项首轮；唯一跳过为真实云端 opt-in |
| `checkline-final-flow-probe` | 2 / 3 / 0 | 大字输入、结算后台通过；其余为待修订回程／照片选择器判断 |
| `checkline-final-flow-regression` | 16 / 3 / 0 | 照片、录入回程、首页点击和五条结算结果通过；两条 FX 与 VoiceOver 前的滚动需修订 |
| `checkline-final-edge-regression` | 3 / 3 / 0 | 两条 FX 尚未通过，预算管理查询受休眠影响超时；不作为最终全通过 |
| `checkline-input-final-unit` | 311 / 0 / 0 | 63 suites，包含输入／结算／回程修复，13.925 秒；之后封面底栏绘制修正待 UI 复验 |
| `checkline-closeout-baseline` | 11 / 0 / 0 | `PaperKeyboardDoneBar` 修复前复跑 6 项待跑模拟器用例 + `InputInteractionUITests`；全部通过，含 7 条键盘 `Invalid frame dimension` 警告 |
| `checkline-closeout-photo` | 1 / 0 / 0 | `PaperKeyboardDoneBar` 修复前在专用临时模拟器跑通 `WishPhotoFlowUITests`；含 1 条键盘警告 |
| `checkline-closeout-verify` | 27 / 0 / 0 | `PaperKeyboardDoneBar` 修复后复跑上述 6 项 + `InputInteraction` / `ComposerNavigationRegression` / `BudgetAmountEdit` / `PhoneFeedbackEnvironment`；0 失败、0 运行时警告 |
| `checkline-closeout-photo2` | 1 / 0 / 0 | `PaperKeyboardDoneBar` 修复后在专用临时模拟器跑通 `WishPhotoFlowUITests`（`CHECKLINE_SYNTHETIC_PHOTO_QA=1`）；0 失败、0 运行时警告，跑完已清理临时模拟器 |
| `checkline-closeout-unit2` | 311 / 0 / 0 | `PaperKeyboardDoneBar` 修复后全量 Swift Testing 单元测试（63 suites）；0 失败、0 运行时警告 |

原始结果路径均为 `/tmp/<运行名>.xcresult`。初次手机执行被新装 QA 的系统无线数据提示挡住，用户处理后重试；被中断的 `/tmp/checkline-input-phone-run.xcresult` 不算产品失败。准备 xctestrun 时曾修正 v1/v2 格式误判，也不算 App 缺陷。

## 原速证据

- iPhone 12： [心愿名称／金额输入保存](phone-wish-input-1x.mp4)、[预算名称／额度输入保存](phone-budget-input-1x.mp4)、[记一笔多输入区与模式切换](phone-record-input-1x.mp4)。均为隔离 QA 合成账本。
- 模拟器：[系统照片选择、保存后重开封面](sim-photo-cover-before-footer-fix-1x.mp4)、[底栏修复前截图](sim-photo-cover-before-footer-fix.png)。这两份显示的是基础导入通过时的画面；已据此修正底部背景宽度，新显示效果仍待复验。
- 模拟器：[结算扫光转后台、恢复结果并检查单次入账](sim-settlement-background-1x.mp4)。来自未跨休眠的 20.757 秒通过用例，不代替修后真机验证。

## 后续真机装机时的剩余步骤

1. 模拟器待跑 7 项已在 2026-11-16 全部完成并通过（0 运行时警告）。
2. 真机重新构建独立 `Rex.Check-Line.MotionQA`，复验结算后台／越线、待确认入口、空记录录入回程。QA 工程 `/tmp/checkline-motion-qa/Check_Line.xcodeproj`，产物 `/tmp/checkline-motion-qa-build`。不重置或自动化个人账本。
3. 因 2026-11-16 新增了 `PaperKeyboardDoneBar` 修复，旧的 `/tmp/checkline-phone21/CheckLine.app` 与当前源码已不一致；后续上机前须重新构建签名 Release 再原位安装正式 `Rex.Check-Line`。正常启动不带演示参数，核对版本和进程；不得卸载正式 App。然后清理独立 QA。

原首轮 37 条 `Invalid frame dimension (negative or non-finite)` 告警已定位至 iOS 27 `.toolbar(.keyboard)`，替换为 `PaperKeyboardDoneBar` 后本轮 28 项修复后 UI 复验均实现 0 告警。iOS 17 运行、实际 Speech 音频识别、真实云端调用、长时发热和 Rex 最终视觉／触感验收仍单列未覆盖。

本轮已按 Rex 确认于 2026-11-16 分主题提交并推送 `origin/main`（2026-11-14 大体积 `.mp4` 录屏通过 `.gitignore` 保留在本地，不入库）。
