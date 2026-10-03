# 2026-10-03 图标原生试装验证

本轮已实装功能图标和原创单卡液面 AppIcon，仍是待 Rex 视觉验收的方向试用，不关闭 M4。

## 本轮结果

- Hugeicons 免费 Stroke Rounded 4.3.5：68 个本地模板矢量图、75 个显示别名。当前活跃 UI（含预设心愿、消费分类及隔离设计页）映射无遗漏；任意历史心愿符号保留系统回退。完整 MIT 许可实际复制进 App。
- Debug 主 App、Release 模拟器构建通过。存在原有领域代码的 actor 隔离与未使用局部值警告；本轮未修改金额服务，也未重跑先前 147 项领域基线。
- iPhone 18 Pro / iOS 27 的 5 个不同 UI 用例通过：设置与功能菜单入口、系统四 Tab 与 Agent 往返、Agent／手动保留字段与关闭返回、待确认目录／详情／确认／逐级返回、VoiceOver 手动填写并保存。iPhone 17 Pro / iOS 26.5 额外运行菜单入口用例通过，共 6 次成功运行。
- 初次菜单回归未通过：自定义 IconLabel 包装影响命令识别，测试点击命中被遮挡的同名首页按钮。按钮改为原生 `Label<Text, Image>`，同一用例在 iOS 26.5 与 27 通过；保留菜单截图，未通过结果不计入成功验证。
- 新版已安装到四台已启动模拟器并以正常本机持久化模式启动，不写入预览样例到账本。桌面名称是「预算线」，包 ID 为 `Rex.Check-Line`。

## 截图范围

以下财务内容来自显式隔离预览，不是用户真实账本。

| 文件 | 环境与所见 |
| --- | --- |
| [home-light.png](home-light.png) | iPhone 17 Pro / iOS 26.5：浅色首页与兼容底栏，圆角线条和消费分类正常显示 |
| [agent-light.png](agent-light.png) | 同设备：小朵、手动切换、话筒、发送、关闭与菜单图标 |
| [budget-overview.png](budget-overview.png) | 同设备深色：预算工作区、待确认、记录与日历入口 |
| [agent-small-dark.png](agent-small-dark.png) | iPhone SE 3 / iOS 26.5：小屏深色面板，输入与按钮可见 |
| [wishes-ipad-light.png](wishes-ipad-light.png) | iPad mini A17 Pro / iOS 26.5：心愿预设符号与居中兼容底栏 |
| [native-tabs-ios27.png](native-tabs-ios27.png) | iPhone 18 Pro / iOS 27：系统 Tab、选中透镜与小朵入口 |
| [record-detail.png](record-detail.png) | 同设备：记录详情与待确认状态 |
| [function-menu-ios26.png](function-menu-ios26.png) | iPhone 17 Pro / iOS 26.5：修正后的原生菜单图标，点击记录入口测试通过 |
| [function-menu-ios27.png](function-menu-ios27.png) | iPhone 18 Pro / iOS 27：同一菜单命令与图标，复测通过 |
| [springboard-small.png](springboard-small.png) | iPhone SE 3：新版桌面 Icon 已显示 |

AppIcon 普通、深色及系统着色源均为 1024 × 1024 不透明 PNG。三种源与小尺寸预览见 `../../explorations/app-icon-study/app-icon-preview.png`；实际桌面截图只证明普通资源显示，本轮未通过桌面定制操作验收深色／着色模式。

## 复验与验收

构建：`xcodebuild -project Check_Line.xcodeproj -scheme 'CheckLine App' -configuration Debug -destination 'platform=iOS Simulator,id=3CB2FE0C-0CBD-4108-B7B9-6BCD71DA63EF' -derivedDataPath /tmp/checkline-icon-trial build`。Release 使用 `generic/platform=iOS Simulator` 与独立构建目录。

测试使用 `CheckLine UI` Scheme，选择 `WalletNavigationUITests/testFloatingHeaderProfileAndMenuOpenTheirDestinations`、`testNativeTabsAndAgentKeepTheCurrentPage`，`TaskWorkspaceUITests/testSharedTaskSwitchRetainsFieldsAndClosesToSamePage`、`testWorkspaceRecordsPendingDetailAndBackRestore`，以及 `TaskEnvironmentUITests/testVoiceOverCanReadAndSaveManualRecord`。本机结果为 `/tmp/checkline-icon-ui-final.xcresult` 与 `/tmp/checkline-icon-menu-final.xcresult`。

iOS 27 全部用例结束后，Xcode 的额外 `simctl diagnose` 收集长时间等待；仅取消该诊断子进程，未中断测试用例。随后 xcodebuild 正常退出 0、报告 `TEST SUCCEEDED`，结果包及截图导出成功。

Rex 可在模拟器点击「预算线」：查看四 Tab → 打开小朵 → 手动填写 → 打开预算卡工作区 → 查看记录详情与功能菜单，比较线条、语义、尺寸和紫色材质的协调性。正常本机模式若尚无预算，先创建一张即可检查卡片场景；隔离样例只通过 `CheckLine Demo` Scheme 或显式 Debug 预览参数进入。

本轮没有新增动效、语音识别、导入解析、云端功能或权限。大字号／英文的整套图标视觉、减少动态效果完整回归、iPad 触摸全流程及真机体验未在本轮重新覆盖，不沿用旧证据宣称通过。最终视觉采用由 Rex 验收。
