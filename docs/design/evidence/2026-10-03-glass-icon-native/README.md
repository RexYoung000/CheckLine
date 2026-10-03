# 留白玻璃 App Icon 实装

2026-10-03，Rex 授权替换并安装手机版本。正式唯一资源为 `Check_Line/Resources/AppIcon.icon`，首次接入与已接受的 `round-6/glass/CheckLine-Glass-Dark.icon` 完全一致。之后修改正式资源；探索副本只保留历史。浅色为紫色与奶白，深色为紫灰与浅薰衣草，沿用已确认轮廓与 0.65 半透明材质。功能图标及 App 内小朵不随此项修改。

旧 `AppIcon.appiconset` 已移除，构建名保持 `AppIcon`。按 [Apple 官方接入方法](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer) 由 Xcode 编译 `.icon`。当前 Xcode 27.0 的真实产物包含浅色、深色、着色原生 `IconImageStack`，以及 iPhone／iPad 兼容图片和对应图标声明；最低 iOS 17.0 保持。

## 构建与手机安装

| 检查 | 结果 |
| --- | --- |
| `CheckLine App` Debug，iOS 27 模拟器 | BUILD SUCCEEDED |
| `CheckLine App` 签名 Release，iPhone 12 | BUILD SUCCEEDED，签名校验通过 |
| 已安装手机版本查询 | `Rex.Check-Line`，1.0（3） |
| 手机启动命令 | devicectl 返回成功并创建 App 进程 |
| iOS 26.5 与 27 模拟器 | 覆盖安装后，从新图标打开正常首页 |

手机为 iPhone 12、iOS 27.0；使用正常持久化 Scheme，覆盖现有安装，未卸载、清空或重置账本，未传入演示启动参数。没有修改账本模型、金额规则或权限。代理没有读取手机账本或对比安装前后记录，不能将覆盖安装命令当作逐条数据验收。

构建日志保存在本机 `/tmp/checkline-glass-icon-debug-build.log` 与 `/tmp/checkline-glass-icon-phone-build.log`。已有未使用变量、两处 MainActor 与 AppIntents 元数据提示仍存在，无新增图标错误；原始设备日志不提交。脱敏的资源、产物与安装结果见 [validation.json](validation.json)。

## 原生界面

以下均为 Device Hub 中实际运行的模拟器截图，并非 HTML 或 Icon Composer 静态效果。截图前隐藏设备侧栏；没有裁切、重绘图标或改动 QA 账本。

| 场景 | 截图 |
| --- | --- |
| iOS 27 默认图标、浅色外观 | [主屏](home-screen-ios27-light.png) |
| iOS 27 深色图标 | [主屏](home-screen-ios27-dark.png) |
| iOS 27 系统着色，灰色、亮度 100%、壁纸来源 | [主屏与自定义面板](home-screen-ios27-tinted.png) |
| iOS 27 透明图标，浅色子模式 | [主屏与自定义面板](home-screen-ios27-clear.png) |
| iOS 27 点击图标打开 App | [正常首页](app-open-ios27.png) |
| iOS 26.5 主屏 | [主屏](home-screen-ios26.png) |
| iOS 26.5 点击图标打开 App | [正常首页](app-open-ios26.png) |

已观察上述模式下的轮廓与显示，iOS 27 检查后恢复默认图标和浅色外观。iOS 26.5 既有深色 QA 首页包含原有测试预算；未新建消费或预算。手机启动已确认，但未直接观察手机主屏、物理触控和材质变化。iOS 17、iPad 主屏、其他着色色值及透明深色未运行验证；兼容图片存在不等于各设备视觉均已验收。本轮资源改动未重跑金额业务测试，已有领域／UI 测试记录不算本轮新增结果。

Rex 可在手机主屏打开「预算线」，检查图标缩小后的识别、浅／深色壁纸上的质感及 App 内实际体验。最终视觉与使用体验仍由 Rex 验收，M4 未关闭。
