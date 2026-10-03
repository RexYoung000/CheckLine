# CheckLine App Icon 试用

本轮试用采用原创的「单卡液面」标记：一张清晰的预算卡、一条轻柔液面和上方预算边界。沿用已确认紫色材质，不使用勾号、通用钱包搭扣、金额或文字。该图标属于本轮图标试用，最终视觉仍待 Rex 验收。

- `render.swift`：可复现的 AppKit 几何绘制源，未使用第三方图标或素材。
- `app-icon-preview.png`：浅色、深色、系统着色方案及 60 / 40 / 29 pt 小尺寸检查。
- 正式候选资产位于 `Check_Line/Assets.xcassets/AppIcon.appiconset/`；三张 1024 × 1024 PNG 均无透明通道，不预制外圆角。外圆角仅用于本目录预览，实际由系统裁切。
- 系统着色资产采用明暗关系，实际系统色调的原生表现须在设备中检查。

在仓库根目录执行：

```sh
swift docs/design/explorations/app-icon-study/render.swift
```

不代表独立品牌终稿；本目录不改变产品规则、导航或金额行为。
