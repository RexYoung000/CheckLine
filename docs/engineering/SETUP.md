# SETUP - CheckLine Xcode 开发环境

> 正式工程已于 2026-07-20 建立并完成旧 Swift Package 项目迁移。本文件记录当前唯一有效的开发入口与环境约束。

## 一、环境要求

- Xcode 16 或更高
- iOS 17+ Simulator Runtime，或可用于开发签名的 Apple ID 与真机
- 正式工程：`Check_Line.xcodeproj`
- 主 Scheme / Target：`Check_Line`
- App 默认显示名：`CheckLine`；简体中文环境显示「预算线」

当前产品先以 iPhone/iPad App 为主。macOS Target、Widget Extension、SwiftData/iCloud 能力均按路线图在对应阶段添加，不在迁移阶段预建空 Target。

## 二、打开与运行

1. 用 Xcode 打开仓库根目录下的 `Check_Line.xcodeproj`。
2. Scheme 选择 `Check_Line`。
3. Destination 选择 iOS 17+ 的 iPhone/iPad 模拟器，或完成签名的真机。
4. 按 `Cmd + R` 启动；按 `Cmd + B` 仅构建。

当前启动页是从旧项目迁入的 SwiftUI 闭环原型，用于确认工程、资源和主要交互已经成功接入。它仍包含历史原型范围，不等于 ROADMAP 第一轮 MVP 已经完成。

## 三、磁盘与 Xcode 结构

`Check_Line/` 是主 App Target 的 Xcode 文件系统同步目录。放入该目录的 Swift 源码与资源会自动出现在 Project Navigator 中，Group 与磁盘目录保持一致。

模块说明文档统一放在 `docs/engineering/modules/`，不要把多个同名 `README.md` 放进 App Target 目录；Xcode 会把它们当作资源复制到 App 包并产生同名冲突。

```text
Check_Line/
├── App/                 # App 入口与根 Scene
├── Features/            # 业务功能；迁移后的 Prototype 位于这里
├── Core/                # 数据模型、领域服务、持久化、Intents
├── Capture/             # 手动/OCR/语音等录入能力
├── DesignSystem/        # 设计 Token、组件、动效
├── Shared/              # 平台封装与通用能力
├── Resources/           # 本地化、Sample 数据
└── Assets.xcassets      # App 图标、颜色与图片
```

旧项目的 `Package.swift` 和独立 Runner 已退出当前工程，避免同时维护 Swift Package 与 Xcode App 两套入口。它们仍可从 Git 历史中追溯。

## 四、本地化显示名

- `Check_Line/Resources/Localizations/zh-Hans.lproj/InfoPlist.strings`：`预算线`
- `Check_Line/Resources/Localizations/en.lproj/InfoPlist.strings`：`CheckLine`
- 工程默认 `CFBundleDisplayName`：`CheckLine`

验收时分别切换模拟器语言为简体中文和英文，确认桌面 App 名随地区变化。

## 五、命令行检查

```bash
# 查看工程与 Scheme
xcodebuild -project Check_Line.xcodeproj -list

# 无签名构建 iOS 模拟器版本
xcodebuild \
  -project Check_Line.xcodeproj \
  -scheme Check_Line \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

当前尚未建立 Test Target，因此不能把“没有测试”误报成测试通过。进入正式 Core/Services 实现前，应先添加 Swift Testing Target，再以 `Cmd + U` 和命令行测试共同验收。

## 六、签名与能力边界

- 模拟器构建不需要开发签名。
- 真机运行时在 Xcode 的 Signing & Capabilities 中选择 Rex 的 Team。
- iCloud、App Groups、Widget、通知、语音等能力只在对应功能进入当前里程碑时开启。
- 不提交 `xcuserdata/`、DerivedData、证书、Provisioning Profile、脚本密钥与 `.env`。

## 七、迁移后基线

- 最低系统版本：iOS 17.0
- 产品代码与文档的主目录：当前仓库
- 旧目录 `/Users/rexyoung/Desktop/vibe coding/mac&ios/CheckLine/` 保持不动，仅作为迁移完成后的本地安全备份
- Git 远端继续使用 `https://github.com/RexYoung000/CheckLine.git`
