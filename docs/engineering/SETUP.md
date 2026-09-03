# SETUP - CheckLine Xcode 开发环境

> 正式工程已于 2026-07-20 建立并完成旧 Swift Package 项目迁移。本文件记录当前唯一有效的开发入口与环境约束。

## 一、环境要求

- Xcode 16 或更高
- iOS 17+ Simulator Runtime，或可用于开发签名的 Apple ID 与真机
- 正式工程：`Check_Line.xcodeproj`
- 主 Scheme / Target：`Check_Line`
- App 默认显示名：`CheckLine`；简体中文环境显示「预算线」

当前产品先以 iPhone/iPad App 为主。SwiftData 是新 V1 确定性账本的下一阶段能力；macOS Target、Widget Extension 和 iCloud 是否进入首发仍待确认，不提前创建空 Target 或启用 Capability。

## 二、打开与运行

1. 用 Xcode 打开仓库根目录下的 `Check_Line.xcodeproj`。
2. Scheme 选择 `Check_Line`。
3. Destination 选择 iOS 17+ 的 iPhone/iPad 模拟器，或完成签名的真机。
4. 按 `Cmd + R` 启动；按 `Cmd + B` 仅构建。

当前启动页是 2026-08-01 版本的 8 页面 SwiftUI 内存样机。它用于追溯旧视觉与工程验证，但其中四 Tab、多预算重复扣减、旧结算和悬浮录入入口已经被 2026-08-10 新产品定义取代，不能继续作为正式 V1 需求来源。新实现以 `PRODUCT.md`、`docs/product/PRD.md`、`docs/product/FEATURE-LOOP.md` 和更新后的 `DESIGN.md` 为准。

## 三、磁盘与 Xcode 结构

`Check_Line/` 是主 App Target 的 Xcode 文件系统同步目录。放入该目录的 Swift 源码与资源会自动出现在 Project Navigator 中，Group 与磁盘目录保持一致。

当前文档入口统一放在 `docs/`，不要把 README 等开发文档放进 App Target；Xcode 会把目标目录内的非源码文件当作 App 资源处理。

```text
Check_Line/
├── App/                 # 当前 App 入口
├── Core/Services/       # M1 领域引擎（纯 Swift，不依赖 SwiftUI）
├── Core/Models/         # 领域 struct / Ledger
├── Core/Persistence/    # SwiftData Schema V1（Persisted*），尚未接入启动页
├── Features/Prototype/  # 历史 SwiftUI 样机，不是新 V1 需求；M4 替换启动页
├── Resources/           # 中英文本地化
└── Assets.xcassets      # App 图标、颜色与图片资源

Check_LineTests/         # Swift Testing 单元测试
```

`Core/Models`、`Core/Services` 与 `Core/Persistence` 已随 M1 账本建立。其他正式 Feature、Application、Capture、DesignSystem 与 Shared 会按新 `ARCHITECTURE.md` 的内部里程碑逐步建立，不预建空目录。旧 `Features/Prototype` 不是新 V1 需求；M4 用真实首页替换启动页。

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

当前已建立 `Check_LineTests` Swift Testing Target。使用 Xcode 的 `Cmd + U` 或以下命令运行测试：

```bash
xcodebuild \
  -project Check_Line.xcodeproj \
  -scheme Check_Line \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

新增正式领域服务或 SwiftData 行为时，必须在同一实施切片补齐对应测试，不能用 App 编译成功代替业务规则验证。

## 六、签名与能力边界

- 模拟器构建不需要开发签名。
- 真机运行时在 Xcode 的 Signing & Capabilities 中选择 Rex 的 Team。
- iCloud、App Groups、Widget、通知、语音、自动化和邮箱/AI 网络能力只在对应实现切片进入当前里程碑并完成隐私审查后开启。
- 不提交 `xcuserdata/`、DerivedData、证书、Provisioning Profile、脚本密钥与 `.env`。

## 七、迁移后基线

- 最低系统版本：iOS 17.0
- 产品代码与文档的唯一主目录：当前 `Check_Line` 仓库
- 旧目录 `/Users/rexyoung/Desktop/vibe coding/mac&ios/CheckLine/` 已由 Rex 确认废弃并删除，不再作为备份或文档来源
- Git 远端继续使用 `https://github.com/RexYoung000/CheckLine.git`

文档入口见 `../README.md`，当前工程结构和未来模块边界见 `ARCHITECTURE.md`。
