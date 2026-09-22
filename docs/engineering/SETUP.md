# SETUP - CheckLine Xcode 开发环境

> 正式工程已于 2026-07-20 建立并完成旧 Swift Package 项目迁移。本文件记录当前唯一有效的开发入口与环境约束。

## 一、环境要求

- Xcode 26 或更高（本轮验证：Xcode 27.0 / iOS 27 模拟器）
- iOS 17+ Simulator Runtime，或可用于开发签名的 Apple ID 与真机
- 正式工程：`Check_Line.xcodeproj`
- 主 Scheme / Target：`Check_Line`
- App 默认显示名：`CheckLine`；简体中文环境显示「预算线」

当前产品先以 iPhone/iPad App 为主。正式页面已读写本地 SwiftData 账本；macOS Target、Widget Extension 和 iCloud 是否进入首发仍待确认，不提前创建空 Target 或启用 Capability。

## 二、打开与运行

1. 用 Xcode 打开仓库根目录下的 `Check_Line.xcodeproj`。
2. Scheme 选择 `Check_Line`。
3. Destination 选择 iOS 17+ 的 iPhone/iPad 模拟器，或完成签名的真机。
4. 按 `Cmd + R` 启动；按 `Cmd + B` 仅构建。

当前启动页是 `CheckLineRootView`，进入首页 / 预算 / 心愿 / 分析四个页面。底部左侧原生玻璃图标导航、右侧 Agent 头像；页首个人头像打开设置。正常启动使用用户的本地账本，空账本显示创建入口。`Features/Prototype` 仅作历史参考。当前范围以 `PRODUCT.md`、`docs/product/PRD.md`、`docs/product/FEATURE-LOOP.md` 和 `DESIGN.md` 为准。

### 独立示例预览

Debug Scheme 的 Arguments Passed On Launch 可添加 `-design-preview`。该模式使用独立内存容器、标注「示例数据」，不读取或覆盖用户账本，Release 构建不启用。

可附加 `-design-screen wishes` 直接预览页面。支持 `home`、`budgets`、`wishes`、`insights`、`settings`、`agent`、`attention`、`record`、`create-budget`、`create-wish`、`budget-detail`、`wish-detail`、`redemption`。详情直达只用于布局检查，不能代替真实点击路径验证。

附加 `-design-reduce-motion` 可在示例模式中检查静态液位和取消位移动效的降级。正常启动遵循系统「减少动态效果」设置；此调试参数不等于验证过系统开关。

附加 `-design-motion-tour` 会通过实际导航状态依次展示首页 → 预算 → 心愿 → 首页、中途返回及连续改选。仅在隔离 Debug 示例模式生效，用于录制原生过渡和检查取消逻辑；不是触控操作证据，可与 `-design-reduce-motion` 组合检查淡入降级。

验收入口：预算页 `+` 创建卡片，卡片进入详情；心愿页 `+` 选符号并创建，心愿详情进入真实购买确认；分析页点日期看当天记录；底部右侧 Agent 头像打开面板，首页卡片 `+` 或页首功能菜单打开记一笔；左上个人头像打开设置，首页铃铛打开待处理事项（可用 `-design-screen attention` 直达布局预览）。

## 三、磁盘与 Xcode 结构

`Check_Line/` 是主 App Target 的 Xcode 文件系统同步目录。放入该目录的 Swift 源码与资源会自动出现在 Project Navigator 中，Group 与磁盘目录保持一致。

当前文档入口统一放在 `docs/`，不要把 README 等开发文档放进 App Target；Xcode 会把目标目录内的非源码文件当作 App 资源处理。

```text
Check_Line/
├── App/                 # 当前 App 入口
├── Application/         # Agent 意图、ConfirmationGate、协调器与撤销
├── Capture/Text/        # 文字只提取事实，不写账本
├── Core/Services/       # M1 领域引擎（纯 Swift，不依赖 SwiftUI）
├── Core/Models/         # 领域 struct / Ledger
├── Core/Persistence/    # Schema V1、本地容器、LedgerStore
├── DesignSystem/        # 共享颜色、字体、哑光表面、液面卡与玻璃控件
├── Features/            # Home / Budget / Wish / Insights / AgentPanel / Capture / Shell
├── Features/Prototype/  # 历史 SwiftUI 样机，未挂载到当前启动页
├── Shared/              # 金额、日期和错误格式化
├── Resources/           # 中英文本地化
└── Assets.xcassets      # App 图标、颜色与图片资源

Check_LineTests/         # Swift Testing 单元测试
```

`Core/Models`、`Core/Services` 与 `Core/Persistence` 已随 M1 账本建立。`Application` 与 `Capture/Text` 已随 M2 行动层建立。M4 正式页面接入上述服务，金额由确定性领域层计算；尚未实现的能力见 `ROADMAP.md`，不能从页面外观推断完整 V1 已交付。

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

# 构建模拟器版本（设备名与 OS 按本机已安装运行时调整）
xcodebuild \
  -project Check_Line.xcodeproj \
  -scheme Check_Line \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' \
  build
```

当前已建立 `Check_LineTests` Swift Testing Target。使用 Xcode 的 `Cmd + U` 或以下命令运行测试：

```bash
xcodebuild \
  -project Check_Line.xcodeproj \
  -scheme Check_Line \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' \
  -parallel-testing-enabled NO \
  -collect-test-diagnostics never \
  test
```

新增正式领域服务或 SwiftData 行为时，必须在同一实施切片补齐对应测试，不能用 App 编译成功代替业务规则验证。

## 六、签名与能力边界

- 模拟器使用本地签名，不需要开发者证书；需要安装运行时不要禁用构建的默认签名步骤。
- 真机运行时在 Xcode 的 Signing & Capabilities 中选择 Rex 的 Team。
- iCloud、App Groups、Widget、通知、语音、自动化和邮箱/AI 网络能力只在对应实现切片进入当前里程碑并完成隐私审查后开启。
- 不提交 `xcuserdata/`、DerivedData、证书、Provisioning Profile、脚本密钥与 `.env`。

## 七、迁移后基线

- 最低系统版本：iOS 17.0
- 产品代码与文档的唯一主目录：当前 `Check_Line` 仓库
- 旧目录 `/Users/rexyoung/Desktop/vibe coding/mac&ios/CheckLine/` 已由 Rex 确认废弃并删除，不再作为备份或文档来源
- Git 远端继续使用 `https://github.com/RexYoung000/CheckLine.git`

文档入口见 `../README.md`，当前工程结构和未来模块边界见 `ARCHITECTURE.md`。
