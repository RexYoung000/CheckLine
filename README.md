# 预算线 CheckLine

> 给自己划一条线，线内自由，线外克制。
> Spend on what matters.

预算线是一个 iOS 17+ 个人预算管理 App。它用「时间 + 主题」组成独立预算钱包，让用户随时知道一段时间、一件事还能花多少。

## 当前阶段

项目已经从 Swift Package 原型迁入正式 Xcode App 工程，目前处于 MVP 实装前的工程与产品基线阶段。

已完成：

- 正式 `Check_Line.xcodeproj` 与 iOS 17+ 构建环境
- 产品宪法、当前 PRD、功能循环、设计规范与路线图
- 当前 8 页面范围的单文件 HTML 原型
- 旧「预算钱包」浅色视觉参考整理
- 迁入的 SwiftUI 历史交互原型，可用于工程启动与交互验证

尚未实现：

- 按当前 MVP 范围重建的正式 SwiftUI UI
- SwiftData 模型、领域服务和本地持久化
- Test Target 与自动化测试
- iCloud、Widget、OCR、语音、Shortcuts 与 macOS Target

当前 SwiftUI 启动页仍包含历史心愿和「扣血」文案，不代表当前产品范围。当前 MVP 不包含心愿页面、心愿数据模型或结算转心愿。

## 当前 MVP

- 创建重复型或单次型预算
- 多预算平等并存
- App 内手动记一笔，一笔可归属多个预算
- 预算剩余、分类和最近记录回看
- 关联账确认与预算结算
- 统计概览和消费记录日历
- 我的 / 设置与基础教程
- SwiftData 本地存储

心愿、自动录入、iCloud、Widget、商业化和 macOS 独占能力均按路线图后置。

## 开始使用

1. 用 Xcode 打开 `Check_Line.xcodeproj`。
2. 选择 `Check_Line` Scheme。
3. 选择 iOS 17+ 的 iPhone 或 iPad 模拟器。
4. 按 `Cmd + R` 启动，按 `Cmd + B` 构建。

当前尚无 Test Target，不能把“构建通过”视为“测试通过”。完整环境说明见 [SETUP.md](./docs/engineering/SETUP.md)。

## 文档入口

- [PRODUCT.md](./PRODUCT.md)：产品宪法，任何范围判断先读。
- [docs/README.md](./docs/README.md)：当前文档地图、权威顺序和历史资料边界。
- [AGENTS.md](./AGENTS.md)：项目特定的 AI 协作与实施规则。

不要从历史截图、旧 UI workflow 或迁入的 SwiftUI 原型反推当前需求。

## 仓库结构

```text
Check_Line.xcodeproj/      正式 Xcode 工程
Check_Line/                主 App Target 源码与资源
docs/product/              当前需求、流程、旅程、术语、路线图
docs/design/               当前设计规范、原型与视觉参考
docs/engineering/          架构、开发环境、分阶段权限
docs/compliance/           当前真实隐私与数据处理规则
docs/archive/              历史研究与旧截图，不参与当前决策
scripts/                   原型辅助脚本
```

Git 远端：`https://github.com/RexYoung000/CheckLine.git`
