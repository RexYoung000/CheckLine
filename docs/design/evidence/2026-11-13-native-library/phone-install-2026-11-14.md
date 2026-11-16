# 2026-11-14 个人手机交付

Rex 要求「接上手机」，授权将已接受的卡库与上午结算效果装到现有 iPhone。签名 Release **1.0（19）已原位安装并正常启动**，设备为 iPhone 12 / iOS 27.0.1。安装前设备查询为 1.0（18），安装后为 1.0（19）；正常启动及后续运行进程查询均通过。最终真机视觉与手感仍由 Rex 验收。

## 构建与范围

- `CheckLine App` Scheme、Release、通用 iOS arm64 构建通过；主 App Debug／Release 构建号从 18 更新为 19。
- 使用现有开发团队、相同 `Rex.Check-Line` Bundle ID 自动签名；严格 `codesign --verify --deep --strict` 通过，描述文件包含目标手机，至 2027-09-24 有效。
- 现有卡库源文件与 [validation.json](validation.json) 的已验证哈希一致；[14 个受保护文件](protected-native.json) 仍未改变。预算详情、结算核对、已接入的结算结果／扫光、心愿碎玻璃均保持已交付实现。
- App 自有 Metal 与 `Libraries.dev_DistortionWavesKit.bundle` 的 Metal 资源均打包。构建仅记录既有的 AppIntents 元数据提取提示。
- 本次只调整构建号，没有新的行为变更，因此沿用上一轮具名模拟器回归，不重复运行测试或在个人手机写入测试账本。

本机已安装的签名包：`/tmp/checkline-phone19/CheckLine.app`；构建日志：`/tmp/checkline-phone19-build.log`。主可执行文件 SHA-256：`ee71e0aaf15950f12931623033dd08af416342f764ba8394aee88930e4fd19d2`。

## 设备状态与验证边界

手机通过 USB 配对，开发者模式已开启。初次查询和安装因 `CoreDeviceError 10003`（手机锁定，开发者磁盘镜像无法挂载）失败；Rex 完成解锁并停留主屏后恢复。随后查询安装前版本、执行 `devicectl device install app`、查询安装后版本均成功。原始安装前后及安装结果保留在本机 `/tmp/checkline-phone19-{before,after,install}.json`，设备标识不加入仓库。

已采用同 Bundle ID 原位更新，没有卸载、删除容器、替换账本或重置设置。首次启动命令的空环境参数被工具拒绝解析，移除该参数并清除调用进程中 `DEVICECTL_CHILD_` 前缀的环境传递后正常启动；设备记录的启动参数为空，仅有工具自带 `TERM=dumb`。没有传演示、测试或清空参数，未启动个人手机 UI 自动化。

正常启动返回成功，后续进程查询确认 CheckLine 运行（PID 1922）；证据在本机 `/tmp/checkline-phone19-{launch,processes}.json`。未执行任何账本操作、读取个人账本内容或截取个人账本画面，未作原有数据的前后逐条比较。版本、正常启动和进程存活证明安装交付，不代表浅暗视觉、回收触感、真实结算体验、GPU 或长时间稳定性已经验收。

改动留在本地；未提交、未推送、未创建 PR 或公开发布。M4 及 Rex 最终真机验收保持开放。
