# PERMISSIONS — 预算线 CheckLine 权限申请规范

> 这份文档定义所有 iOS / macOS 系统权限的申请时机、用途、文案、降级策略。
> App Store 审核会检查每个权限的 `usageDescription`，必须言之有物。
> 配套阅读：`docs/compliance/PRIVACY.md`（隐私约束）、`docs/spec/PRD.md`（功能需求）。

---

## 一、原则

### 1.1 时机原则：**用到才问，不用不问**

- 不在启动时一次性申请所有权限。每项权限只在用户第一次触发对应功能时弹窗。
- 申请前用一句话解释「为什么需要这个权限」+ 「拒绝会怎样」，让用户做明白决定。

### 1.2 文案原则：**说人话，不威胁**

- 不说「不开启将无法使用」。该说的是「开启后你能用 X 功能」。
- 中文 1-2 短句，英文 1-2 short sentences，不堆叠技术术语。
- 调性参考 `PRODUCT.md` 第六节：温柔不教育、不制造焦虑。

### 1.3 降级原则：**拒绝也能用**

- 任何权限被拒绝后，对应功能给出 fallback 路径，不能阻塞核心流程。
- 在「我的 → 设置」页提供权限状态总览和重新申请的引导（跳转系统设置）。

---

## 二、权限清单（MVP）

| 权限 | Info.plist Key | 触发功能 | 申请时机 | 必需性 |
|------|---------------|---------|---------|------|
| 通知 | — (UNUserNotificationCenter) | 预算/结算/心愿提醒 | 首次引导后第 2 屏 | 强烈推荐 |
| 照片 | `NSPhotoLibraryUsageDescription` | 截图识别录入 | 首次点击「截图录入」按钮 | 可选 |
| 语音识别 | `NSSpeechRecognitionUsageDescription` | 语音记一笔 | 首次长按「语音」按钮 | 可选 |
| 麦克风 | `NSMicrophoneUsageDescription` | 语音记一笔 | 与语音识别同步申请 | 可选 |
| iCloud | — (CloudKit 自动) | Mac/iPhone 同步 | 首次启动检测 iCloud 账户 | 强烈推荐 |

---

## 三、各权限详细规范

### 3.1 通知（Notifications）

**触发时机：**
- 首次引导完成「建第一个预算 + 第一个心愿」后，进入主屏前。
- 弹出前先展示一张「为什么开启通知」的预解释卡片，再触发系统弹窗。

**预解释卡片文案：**

> **中文（zh-Hans）：**
> 标题：「不错过每一条预算线」
> 说明：「开启通知，预算快用完时温柔提醒，结算日和心愿即将达成时第一时间告诉你。」
> 按钮：「开启通知」/「先不」
>
> **英文（en）：**
> Title: "Stay aware of your line"
> Body: "Turn on notifications to get gentle reminders when your budget is running low, when settlement is ready, and when your wish is close."
> Buttons: "Turn on" / "Not now"

**系统弹窗后：**
- 同意 → 注册本地通知调度器，按 PRD 4.12 通知策略推送。
- 拒绝 → 设置页通知开关默认关闭。用户手动开启时引导跳转系统设置。

**降级策略：**
- 拒绝通知不影响任何 App 内功能。
- 在「我的 → 通知」页面用横幅提示「通知已关闭，开启后能更好提醒你」+ 跳转按钮。

---

### 3.2 照片（Photo Library）

**触发时机：**
- 首次点击「截图录入」入口（首页 + 号 → 截图录入 / Widget 截图入口）。
- 不在 App 启动时申请。

**Info.plist 文案：**

```xml
<!-- zh-Hans -->
<key>NSPhotoLibraryUsageDescription</key>
<string>预算线需要访问你的照片，识别支付截图里的金额，自动填入归类弹窗。识别在你的设备上完成，不上传任何图片。</string>

<!-- en -->
<key>NSPhotoLibraryUsageDescription</key>
<string>CheckLine reads payment screenshots from your photos to auto-fill amounts. Recognition happens on your device — no images leave your phone.</string>
```

**关键点：**
- 必须明确「识别在设备上完成 / on your device」，否则 App Store 审核会要求提供云端处理的隐私说明。
- 用 `PHPickerViewController` 而不是 `UIImagePickerController`，可只要求受限照片访问，不需要全部相册。
- 优先申请 `.readWrite` 还是 `.readOnly`？**只要 `.readOnly`**。

**降级策略：**
- 拒绝 → 「截图录入」入口隐藏或灰显，提示「需要照片权限才能识别」+ 跳转系统设置按钮。
- 用户仍可通过手动 / Widget / 语音 / Shortcuts 录入。

---

### 3.3 语音识别（Speech Recognition）

**触发时机：**
- 首次长按「语音」按钮。
- 与麦克风权限同时申请（系统会自动连续弹两次）。

**Info.plist 文案：**

```xml
<!-- zh-Hans -->
<key>NSSpeechRecognitionUsageDescription</key>
<string>预算线用语音识别帮你快速记一笔。说一句「打车 38」就能录入。识别走苹果端侧引擎，不上传录音。</string>

<!-- en -->
<key>NSSpeechRecognitionUsageDescription</key>
<string>CheckLine uses speech recognition to log expenses fast. Just say "Coffee 5" and it's recorded. Recognition runs on Apple's on-device engine — no audio leaves your phone.</string>
```

**关键点：**
- 必须使用 `SFSpeechRecognizer.supportsOnDeviceRecognition` 检测端侧支持，启用 `requiresOnDeviceRecognition = true`。
- iOS 13+ 支持的语言才能端侧识别，中文 / 英文都支持。
- 不支持端侧识别的语言要 fallback 到手动输入（不偷偷上传到苹果服务器）。

---

### 3.4 麦克风（Microphone）

**触发时机：**
- 与语音识别同时申请。系统会先弹麦克风、再弹语音识别。

**Info.plist 文案：**

```xml
<!-- zh-Hans -->
<key>NSMicrophoneUsageDescription</key>
<string>预算线需要麦克风录下你的语音，配合识别引擎转成文字。录音不保存、不上传，识别完即丢弃。</string>

<!-- en -->
<key>NSMicrophoneUsageDescription</key>
<string>CheckLine needs the microphone to capture your voice for transcription. Audio is discarded after recognition — never saved or uploaded.</string>
```

**降级策略（语音 + 麦克风）：**
- 任一拒绝 → 语音按钮隐藏或灰显，长按时提示「需要麦克风和语音识别权限才能使用」。
- 用户仍可通过手动 / 截图 / Widget / Shortcuts 录入。

---

### 3.5 iCloud（Sync）

**触发时机：**
- App 首次启动时检测 `FileManager.default.ubiquityIdentityToken`。
- 不主动弹申请窗（iCloud 本身不需要权限弹窗，只需要用户已登录 iCloud 账户）。

**未登录处理：**
- 在主屏顶部展示 `iCloud 横幅`：「未登录 iCloud，数据只保存在本机」+ 跳转系统设置按钮。
- 不阻塞使用，只提示。

**降级策略：**
- 未登录 iCloud → SwiftData 走本地 sqlite 存储，所有功能正常。
- 用户登录后自动迁移到 CloudKit 容器，无感切换。

**冲突处理：**
- 同一笔 Expense 在两台设备同时编辑时，按 SwiftData CloudKit 默认 last-write-wins。
- 重要冲突（如金额对不上）记 OSLog，不弹窗打扰。

---

## 四、权限状态总览页（设置页内）

`我的 → 通用设置 → 权限管理` 提供所有权限的状态总览：

```
┌─────────────────────────────────┐
│  权限管理                        │
│                                 │
│  ✅ 通知                         │
│      预算 / 结算 / 心愿提醒      │
│                                 │
│  ⚠️ 照片                         │
│      未授权 · 截图录入不可用     │
│      [前往系统设置 →]            │
│                                 │
│  ✅ 语音 + 麦克风                │
│      语音记一笔可用              │
│                                 │
│  ✅ iCloud                       │
│      已登录 · 同步正常           │
└─────────────────────────────────┘
```

**交互要求：**
- 状态实时反映系统设置。
- 未授权项点击跳转 `UIApplication.openSettingsURLString`。
- 不在此页嵌入「重新申请」逻辑（系统不允许应用重复弹申请窗）。

---

## 五、App Store 提交检查清单

提交前确认：

- [ ] 所有 `*UsageDescription` key 都填了人话文案，不写「为了使用 X 功能」这种空话。
- [ ] 中英文文案均已本地化到 `InfoPlist.strings`。
- [ ] `Privacy Manifest`（PrivacyInfo.xcprivacy）登记所有访问的 API 类别（`NSPrivacyAccessedAPICategoryUserDefaults` 等）。
- [ ] App Store Connect 隐私问卷如实填写（参考 `docs/compliance/PRIVACY.md` 第三节）。
- [ ] 录屏一段「申请权限 → 拒绝 → 重新申请」的流程，确认无崩溃、无空白页。

---

## 六、未决问题（先记录）

- [ ] iOS 17+ 受限照片访问（`PHPickerViewController` + `PHAccessLevel.addOnly`）是否够用，还是必须申请全部相册？
- [ ] 语音识别在中国大陆走端侧是否会触发 SiriKit 网络上报？需要测试。
- [ ] 通知申请时机：建预算之前还是之后？目前定在第一个预算和心愿建完后，但要观察用户拒绝率。
- [ ] iCloud 容器在不同 Apple ID 切换时如何处理？目前依赖 SwiftData 默认行为，需要测试。
