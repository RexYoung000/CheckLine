# 冰蓝浅暗稿原生移植证据

固定参考为 Rex 接受的 `770ad6a`：[冰蓝交互稿](../../explorations/material-themes-2026-10-23/budget-home.html)及其同提交的材质来源。当前实现以 SwiftUI、Canvas 与本地 Metal Shader 接回原有账本和导航，没有嵌入网页。签名 Release **1.0（18）构建成功**；本轮尚未手机安装、发布或完成 Rex 真机验收，M4 保持开放。

先看[原生浅暗对照](index.html)。这里展示实际模拟器截图，不是重新绘制的网页。21 个入口加已实现收藏状态，共 **22 组、44 张**浅暗图；附件来源、测试名、设备及采集时间见 [captures.json](captures.json)。本目录的交互图、无障碍朗读与绘制计数是补充证据，不重复计入 44 张。

## 入口映射与截图边界

以下 `-design-screen` 仅随 DEBUG 的 `-design-preview` 使用；`CheckLine Demo` 每次建立隔离合成账本。多数入口截图额外使用 `-design-reduce-motion` 以固定姿态，卡库为展示弧线布局未加此参数。静态对照不能代替正常速度交互或实际系统动态偏好验证。

| 已接受页面／状态 | 原生隔离入口 | 实际页面与对照 |
| --- | --- | --- |
| 预算首页 | `budgets` | [卡夹、摘要与票据](index.html?view=budgets) |
| 首页全部记录层 | `records-layer` | [既有卡夹压缩／记录层](index.html?view=records-layer) |
| 预算卡库 | `library` | [既有弧线卡库](index.html?view=library)；球面与返回另有交互图 |
| 预算详情 | `budget-detail` | [概览、上限与去向](index.html?view=budget-detail) |
| 预算消费记录 | `records` | [记录与待确认筛选](index.html?view=records) |
| 单笔消费详情 | `expense-detail` | [真实记录详情](index.html?view=expense-detail) |
| 消费日历 | `calendar` | [日期选中面与消费圆点](index.html?view=calendar) |
| 历史周期 | `history-review` | [已结算周期回看](index.html?view=history-review) |
| 预算信息 | `budget-info` | [周期、币种与管理入口](index.html?view=budget-info) |
| 未实现心愿清单 | `wishes` | [玻璃外壳、两列与末张横卡](index.html?view=wishes) |
| 心愿正反大卡 | `wish-expanded` | [已展开的背面](index.html?view=wish-expanded)；正面、翻面另有交互图 |
| 心愿余额 | `wallet` | [余额及分组变动](index.html?view=wallet) |
| 余额变动详情 | `wallet-entry` | [单条来源与金额](index.html?view=wallet-entry) |
| 记一笔 | `record` | [共享手动任务面板](index.html?view=record) |
| 创建预算卡 | `create-budget` | [预算创建面板](index.html?view=create-budget) |
| 添加心愿 | `create-wish` | [心愿创建面板](index.html?view=create-wish) |
| 心愿封面 | `wish-cover` | [本地预设与封面预览](index.html?view=wish-cover) |
| 小朵 | `agent` | [原主动 Agent 面板](index.html?view=agent) |
| 设置 | `settings` | [主题与既有设置](index.html?view=settings) |
| 结算核对 | `settlement-fx` | [异币种确认](index.html?view=settlement-fx) |
| 真实购买核对 | `redemption` | [成交金额、币种与购买确认](index.html?view=redemption) |
| 补充：已实现收藏 | `collection` | [无玻璃的金属收藏卡](index.html?view=collection)，单独浅暗复验 |

截图测试检查页面和控制存在；没有因此宣称 22 个页面的全部操作、错误和系统组合均已验收。`library`、`records-layer` 进入既有状态机；`wish-expanded` 等待心愿 Tab 完成布局后打开真实大卡，预览不复制页面。

## 本轮实现与状态数据

- 页面、内容、UI 重点色与物理材质分开：浅色白底及冰蓝提示，暗色控件黑白灰，主按钮黑白；预算水体和未实现心愿外壳保持冰蓝。原生系统 Tab 切换透镜及原有低版本分支保留。
- 首页与详情共用前后自由液面、满水顶空、透明细泡与可见时间累计；横甩／换卡／插入沿原事件提供限幅惯性及短水花，空水不绘制。卡库弧线、球面和放大共用静态水体。记录层、弹层、离屏、离开预算与后台暂停，返回不补跑。
- 未实现心愿为玻璃前片与内卡，暗色内卡冷银灰；已实现使用姿态驱动的反射金属，静止不持续重绘。正面、横条、大卡、购买事实背面及结果卡读取共享来源；本地参考许可保留于 `Check_Line/Resources/Licenses/ReactBits-ReflectiveCard.txt`。
- 大卡和卡库聚焦采用浅色 32%／暗色 40% 黑遮罩；底页可辨识、不可操作。减少动态效果保留静态材质与必要结果；减少透明度使用清楚底片，增强对比度强化边界。
- 金额仍由 Decimal 领域服务和真实账本投影提供，动画只读取已保存结果。默认合成预算额度 3,000，已确认支出 1,680，加待确认 40 后暂计已用 1,720、还能花 1,280；待确认不形成确定越线。另一张卡额度 2,400、支出 680。演示日期按启动时本地日历生成，不是真实消费证据。
- 合成心愿钱包为 860；耳机 699 可进入核对，露营 1,200 未达覆盖门槛。`collection` 通过原领域服务确认合成书籍购买 89，产生真实演示购买与金属收藏状态，钱包变为 771；没有直接把显示标志改为已实现。
- 参考汇率用例以 USD 100 心愿／CNY 860 钱包检查：应用 10 时未达覆盖；取消编辑 7 不替换已应用值；明确应用 7 后可进入核对，实际 USD 200 换算超过钱包时仍不能确认。参考报价不提前改变钱包，真实成交仍经原服务校验。

## 实际有效验证

原始 `.xcresult` 位于本机 `/tmp`，不随本目录归档；可持久审阅的是截图、清单、朗读文本、计数和本说明。以下按结果包分别记录，不能相加成“一次完整全绿”。

| 环境／范围 | 最终有效结果 | 原始结果包 |
| --- | --- | --- |
| iPad mini 模拟器，iOS 27.0，领域／状态 | 259 项、54 suites 通过；动态参数展开不另算新增测试 | `/tmp/checkline-native-unit-ios27.xcresult` |
| 375pt 小屏模拟器，iOS 26.5，清洁环境领域／状态 | 259 项、54 suites 通过，0 跳过 | `/tmp/checkline-native-unit-ios26-clean.xcresult` |
| iPhone 18 Pro 模拟器，iOS 27.0，核心交互 | 19/19 通过：NativePort 10、R34Home 5、R34Wish 3、手动任务 VoiceOver 1 | `/tmp/checkline-native-final-flows.xcresult` |
| iPad mini 模拟器，iOS 26.5，心愿操作 | R34Wish 3/3：两列／横条、放大翻面与真实兑换点击、不足覆盖操作隔离 | `/tmp/checkline-native-ipad-final.xcresult` |
| 375pt 小屏，iOS 26.5，环境组合 | 4/4：减少透明度／增强对比度、英文暗色大字未定价心愿、英文键盘任务、实际系统减少动态效果下保存 | `/tmp/checkline-native-small-env.xcresult` |
| 小屏，实际系统辅助设置恢复 | 2/2：减少动态效果、减少透明度／增强对比度均在测试后断言恢复原值 | `/tmp/checkline-native-a11y-restoration.xcresult` |
| iPhone 18 Pro，iOS 27.0，液体测量与汇率门禁 | 两项性能／暂停用例及参考汇率用例分别通过；该包共 7 项中 5 过、2 个旧心愿点击失败，不能把整包称为通过 | `/tmp/checkline-native-verified-ui.xcresult` |
| 最终 21 入口浅暗截图 | 21 个入口均产生截图；额外 collection 的两主题断言失败，整包 4 过、2 失败 | `/tmp/checkline-native-delivery.xcresult` |
| 收藏入口补验 | 单个用例逐个检查浅暗收藏状态，两主题均通过，替换失败时的收藏截图 | `/tmp/checkline-native-collection.xcresult` |

259 项覆盖原确定性引擎、覆盖／汇率边界、预算水面几何、可见时钟、气泡体积、持久化与既有循环；不是 259 项视觉验收。空水、0.1%、43%、95%、100%、极端冲量与暂停恢复有几何／状态检查；本目录没有逐档完整真机动态采样。

19 项交互包含插拔断联与恢复、双向横甩、短拖回弹、弧线聚焦／球面双轴浏览、空白不误切层、记录层返回、两列／末张横铺／横条、大卡翻面、禁用入口不穿透、实际购买后的已实现清单、当前页结算、封面局部更新、未定价禁用、Agent 草稿明确确认／放弃，以及原生 VoiceOver 读取预算与完成手动保存。实际朗读留在 [预算 VoiceOver 文本](flows-native-budget-voiceover.txt)与[手动任务朗读文本](flows-voiceover-manual-task-speech.txt)。真实照片选择没有包含在预设封面用例中。

### Canvas CPU 区间与暂停计数

标准 `XCTOSSignpostMetric` 使用 `Rex.CheckLine / Liquid / LiquidFrame`。最终有效日志 `/tmp/checkline-native-verified-ui.log` 报告值为 **0.000161 秒（0.161 ms）**，来自一次含 3 秒等待的可见预算采样。它测量 Canvas 绘图闭包的 CPU 区间，不能解释成 GPU 完成时间、屏幕 FPS、真机功耗或长期稳定性基准。

| 包含 3 秒静置的窗口 | 绘制计数 | running |
| --- | --- | --- |
| [Agent 打开前](main-liquid-draw-count-visible-before-agent.txt) | 137 → 261 | 1 → 1 |
| [Agent 覆盖并落稳后](main-liquid-draw-count-agent-covered.txt) | 311 → 311 | 0 → 0 |
| [关闭 Agent 返回](main-liquid-draw-count-visible-after-agent.txt) | 457 → 580 | 1 → 1 |

计数只在 DEBUG 且同时传 `-design-preview -design-liquid-metrics` 时启用；使用普通加锁存储与按需无障碍 getter，不发布 SwiftUI 状态，不由计数触发下一帧。Release 无探针／计数调用。计数涵盖 `NativeLiquidSurface` 的 Canvas 提交，包含结构性重绘；主题、尺寸或数据变化下静态缩略图仍可必要重绘，不从次数反推显示帧率。

## 失败、修复与复验边界

1. **真实心愿点击缺陷**：背面虽然在无障碍树中显示 enabled／hittable，额外的 180° 变换仍会把实际兑换点击反向映射到翻面手势。现在翻面过程中保留双 3D 面、关闭命中及无障碍；落稳只渲染对应单面承担实际点击，44pt 操作区继续与翻面区隔离。iPhone 最终 19 项及 iPad 3 项包含真实点击通过，未用“属性可点”代替操作结果。
2. **预算透影与卡尾**：实际浅色图曾透出后卡巨大金额／名称，卡尾上部还成为主卡内的直角蓝条。仅弱化并柔化后卡内容，保留真实卡片轮廓；遮掉卡尾与主卡重叠的上部 20pt，原位移、手势和时序保持。当前 44 张首页对照来自修订后截图；最终透光观感仍由 Rex 验收。
3. **隔离预览 fixture**：合成心愿创建时间曾相同，依 UUID 排序使首卡不稳定；现在用递减时间固定样本顺序。collection 的 TabView 选择时序曾停留未实现，已在隔离预览选择已实现并独立浅暗复验。大卡预览等待心愿 Tab 拥有呈现上下文后打开；均不改变正式账本。
4. **测试环境与反馈宿主**：iOS 26.5 首轮三个 ContactFeedback 测试出现 appearances=0；实际系统减少动态效果曾被环境用例遗留开启，不能据此认定生产动画退化。测试宿主建立可见窗口并等待出现后才启动有限接触，系统动态偏好恢复后再运行；辅助设置用例恢复原值并实际复验 2/2，清洁环境 259/54 通过。
5. **性能测试采集器**：早期手工调用 `XCTMetric` 抛出 `_startDate` 的 Objective-C 异常，已移除。CPU 耗时保留标准 `measure`；生命周期改用上述明确开启的计数探针，最终两项均实际通过，没有把异常跳过计为通过。
6. **仍有运行警告**：部分最终交互／环境结果记录 `Invalid frame dimension (negative or non-finite).`。可复核的 9 次均发生在输入框点击后、键盘输入前；对应输入视图没有已证实的负尺寸路径，日志缺少视图调用栈。尚未定位具体绘制来源，不归因为预览或系统，也不描述为“无运行时问题”。

## 原速片段与待验收

交付路径为 [插卡与液体回稳](motion/insertion.mp4)、[心愿大卡翻面](motion/flip.mp4)、[结算收币](motion/settlement.mp4)、[购买破壳与收藏](motion/redemption.mp4)。四段均已检查连续画面和最终状态，保留原速度，仅裁去启动与等待并压缩分辨率，裁剪范围、来源 SHA-256 和时长在 [motion/manifest.json](motion/manifest.json)。破壳片段在 App 完成启动后重新录制，完整保留聚光、裂纹、碎裂、内卡揭晓和钱包结果。模拟器启动／退出段曾发生 PTS 回退，最终片段避开这些异常段；没有用改快动画掩盖问题。兑换补录测试 `/tmp/checkline-native-reward-loaded.xcresult` 1/1 通过，原展开购买、结算 `/tmp/checkline-native-rewards.xcresult` 2/2 通过。

补充实际截图：[运行中系统切换浅色](screens/system-theme-light.png)、[同一进程切换暗色](screens/system-theme-dark.png)；强制关闭 Shader 后的[浅色静态环境倒影](screens/static-metal-light.png)和[暗色静态环境倒影](screens/static-metal-dark.png)。后者证明当前运行时的静态材质路径可见，不代替旧系统运行验证。

开发包为签名 Release 1.0（18），严格 codesign 校验通过；IPA SHA-256：`e9f2f1fe2116fe162c972ce4953898b07c8e6ce1403e429bd7a7f1653bf2fa5d`。构建仍有既有领域服务的 actor 隔离与未使用值警告，不描述为零告警。

当前完成的是代码、具名模拟器路径、原生截图／录屏和签名构建。以下仍开放：

- Rex 对浅暗透光、金属倒影、液体节奏和最终使用体验的验收。
- 本轮 1.0（18）尚未在手机安装；真机触感、GPU 帧耗时及长时间性能没有证据。
- 实测系统为 iOS 27.0 与 26.5 模拟器。最低部署目标仍为 iOS 17；17–25 缺少运行时，没有实际交互／材质／Shader 回退验收。
- 实际照片库选图、不同照片嵌入／铺满、真实图片失败恢复及其设备权限组合未在本轮完整走通；预设封面通过不替代这些任务。
- 无障碍有具名 VoiceOver、系统减少动态效果、减少透明度和增强对比度用例，不代表所有页面、语言、字号及辅助功能组合已验收。

工作区原有未提交 HTML 试色文件保持，未混入固定参考、原生业务或截图 fixture；本轮没有通过构建 HTML 覆盖它们。结算、兑现和绘制仍各自遵循既有确认／持久化边界，没有为了展示复制 HTML 示例金额逻辑。
