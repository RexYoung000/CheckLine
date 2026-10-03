# Hugeicons 原生试装来源

2026-10-03，Rex 授权尝试成熟图标来源。功能图标选用 [Hugeicons Stroke Rounded](https://hugeicons.com/icons/stroke-rounded)，使用官方免费包 `@hugeicons/core-free-icons` **4.3.5** 的 68 个矢量图形。官方免费资源为 MIT；Pro 素材不在本次范围。

- [官方仓库](https://github.com/hugeicons/hugeicons)、[许可说明](https://hugeicons.com/license-agreement)。完整版权与许可保存于 `Check_Line/Resources/ThirdPartyLicenses/Hugeicons-MIT.txt`，随 App 打包。
- `scripts/design/hugeicons-manifest.json` 记录官方包地址、SHA-1、导出名、资源名和既有符号别名；`scripts/design/import-hugeicons.py` 校验下载包后解析几何数据，生成模板 SVG 和 Swift 显示映射。脚本不执行包内 JavaScript，不安装运行时依赖。
- 保留原始 24 × 24 画布及 1.5 点线宽，由角色尺寸缩放。模板资源使用项目现有颜色；选中、待确认与完成继续有文字或不同图形表达。`circle` 与带对勾圆圈使用不同几何。
- 持久化心愿符号名、金额和数据模型不变，历史未知符号仍有系统回退。
- 桌面 AppIcon 是 `../app-icon-study/render.swift` 原创绘制的单卡液面候选。Streamline Flex 仅提供曲线设计启发，没有采用其素材。

本轮是可逆试装，最终采用由 Rex 视觉验收。实际构建、操作及截图见本轮原生验证记录；较早的 `2026-10-03-icon-directions.html` 为未定稿自绘比较，不代表这次 Hugeicons 实装。
