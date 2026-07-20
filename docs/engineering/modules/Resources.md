# Resources/

静态资源 —— 图标、本地化、采样数据。

| 子目录 | 角色 |
|------|------|
| `Assets.xcassets/` | 颜色 / 图标 / 启动图 |
| `Localizations/zh-Hans.lproj/` | 国区「预算线」命名 + 中文字符串 |
| `Localizations/en.lproj/` | 海外「CheckLine」命名 + 英文字符串 |
| `Sample/` | 调试用 sample 数据（一键塞 SwiftData 容器） |

**命名分区**：
- `zh-Hans.lproj/InfoPlist.strings` → `CFBundleDisplayName = "预算线"`
- `en.lproj/InfoPlist.strings` → `CFBundleDisplayName = "CheckLine"`
