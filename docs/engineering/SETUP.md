# SETUP — 把磁盘目录变成可运行的 Xcode 工程

> 这份文档告诉你怎么对接现有的源码骨架到一个新建的 Xcode 工程。
> AI 不会替你手写 `.xcodeproj`（那种文件手写很容易翻车），但下面的步骤照着走 5 分钟可搞定。

---

## 一、前置

- Xcode 16 或更高（支持 iOS 17 / macOS 14 SDK）
- Apple ID（用于真机测试 / iCloud 同步）

---

## 二、新建工程

1. **打开 Xcode** → File → New → Project
2. 选 **Multiplatform → App**，Next
3. 字段填写：

   | 字段 | 值 |
   |------|---|
   | Product Name | `CheckLine` |
   | Team | 你的 Apple ID |
   | Organization Identifier | `com.yourname.checkline`（按你自己的） |
   | Bundle Identifier | 自动 = `com.yourname.checkline.CheckLine` |
   | Interface | SwiftUI |
   | Language | Swift |
   | Storage | **SwiftData** |
   | Include Tests | ✅ |

4. **Save 位置**：选 `/Users/rexyoung/Desktop/vibe coding/mac&ios/CheckLine/` 这个目录本身（不要再嵌套一层）。

   勾选「Create Git repository」如果你想立刻 git init（也可以稍后再做）。

---

## 三、把现有目录纳入工程

新建后 Xcode 会自动生成一个 `CheckLine/` 子文件夹。我们要把它替换成自己的 `Sources/` 结构。

### 3.1 删掉默认目录

删除 Xcode 默认生成的：
- `CheckLine/` 整个文件夹
- 默认的 `ContentView.swift` / `CheckLineApp.swift`（稍后我们会在 `Sources/App/` 里重建）

### 3.2 把磁盘目录拖进工程

将以下目录从 Finder 拖进 Xcode 左侧 Project Navigator：

```
Sources/
Widgets/
Resources/
Tests/
```

拖进时勾选：
- ✅ **Copy items if needed** → 不勾（已经在工程目录里）
- ✅ **Create groups**（不要 folder reference）
- ✅ **Add to targets** → 勾「CheckLine」

### 3.3 建议的 Group 与磁盘对应

让 Xcode 的 Group 与磁盘目录一一对应。`Sources/Features/Budget/` 的 Swift 文件就放在工程里 `Sources > Features > Budget` Group 下。

---

## 四、命名分区（中文「预算线」/ 英文 CheckLine）

### 4.1 工程 Info 中开启本地化

1. 选中工程 → Info 标签
2. Localizations 部分 → 添加 `Chinese, Simplified (zh-Hans)` 和 `English (en)`
3. Use Base Internationalization 保持勾选

### 4.2 创建 InfoPlist.strings

在 `Resources/Localizations/zh-Hans.lproj/InfoPlist.strings`：

```
"CFBundleDisplayName" = "预算线";
```

在 `Resources/Localizations/en.lproj/InfoPlist.strings`：

```
"CFBundleDisplayName" = "CheckLine";
```

### 4.3 Info.plist 默认值

主 Info.plist：
- `CFBundleDisplayName` = `CheckLine`（默认值，本地化文件会按地区覆盖）
- `CFBundleName` = `CheckLine`（不本地化，给系统用）

### 4.4 验证

- 在 iOS 模拟器或 Mac，把系统语言切到「简体中文」，App 名应显示「预算线」
- 切回英文，应显示「CheckLine」

---

## 五、能力（Capabilities）

按需开启：

| Capability | 何时开 |
|-----------|------|
| **iCloud → CloudKit** | 第一版就开（数据同步） |
| **App Groups** | 主 App 与 Widget 共用数据时（第一版就开） |
| **Push Notifications** | 后期通知策略上线时 |
| **Personal Voice / Speech Recognition** | 语音录入功能上线时 |

App Group 命名建议：`group.com.yourname.checkline`

---

## 六、Widget Extension（可选第一版加，可选 v1.1）

如果第一版要做 Widget：

1. File → New → Target → Widget Extension
2. Product Name: `BudgetStatusWidget`
3. 勾「Include Configuration Intent」
4. 把生成的源文件挪进磁盘 `Widgets/BudgetStatusWidget/`
5. 在两个 target（主 App + Widget）都开启 App Group
6. 共用 SwiftData 容器：通过 `ModelConfiguration(groupContainer:)`

---

## 七、第一次构建检查清单

- [ ] Xcode 选中 `CheckLine` scheme
- [ ] Destination 选 Mac 或 iOS 模拟器
- [ ] `Cmd + B` 能编译过
- [ ] `Cmd + U` 跑测试不报错（即使没测试用例）
- [ ] 切系统语言看 App 名是否正确切换

---

## 八、常见问题

### 拖进去后报「找不到文件」

在 File Inspector 里检查 Path 是否「Relative to Project」，并且实际文件存在于该相对路径。

### SwiftData 编译报错「Cannot find type 'Model'」

Deployment Target 必须是 iOS 17 / macOS 14 或更高，否则 SwiftData 不可用。

### iCloud 同步本地测试

- iOS 模拟器：登录 Apple ID → 启用 iCloud Drive
- Mac：系统设置 → Apple ID → 同账号
- 同账号下两端 App 数据互通

---

## 九、构建命令（CLI）

工程创建后，可以在命令行：

```bash
# 列出 schemes
xcodebuild -list

# 构建 macOS 版
xcodebuild -scheme CheckLine -destination 'platform=macOS' build

# 构建 iOS 模拟器版
xcodebuild -scheme CheckLine -destination 'platform=iOS Simulator,name=iPhone 15' build

# 跑测试
xcodebuild -scheme CheckLine test -destination 'platform=macOS'
```

---

## 十、跑通后第一件事

回到 [ARCHITECTURE.md](./ARCHITECTURE.md) 第四节「数据模型」，按字段表创建第一批 `@Model class`，提交一个 `feat: 初始化 SwiftData 数据模型` commit。
