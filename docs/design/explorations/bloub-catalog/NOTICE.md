# bloub 动画选型页来源

- 仓库：https://github.com/jeremy-prt/bloub
- 固定提交：`b4bb3c1b5f93c7b87a2e8d620f667c4093d97749`
- `vendor/*.ts`：该提交 `src/bot/` 下同名原版源码，保持原样。
- `vendor/*.mjs`：由 Node 24 `stripTypeScriptTypes` 去除类型，补齐浏览器模块扩展名。运行 `node docs/design/explorations/bloub-catalog/build-vendor.mjs` 可重新生成；不安装依赖。
- 采用原版 BotEngine、14 种目录动画、形状、表情、粒子、轨道、眼部校正和进出形变。SVG 绘制顺序、蒙版和配色规则依据上游 `src/components/BloubBot.vue`，转换成独立 DOM 绘制适配器。未使用上一版 CheckLine 五态动作函数。
- 本页新增：中文场景建议、审阅布局、单项播放器、时间轴、云朵进出片段、主题配色预览与本机选择记录。各场景仅为建议。
- 默认使用上游墨黑配色、Cloud Shape、静态缩略图；默认一次播放后停止。切换“灰紫预览”只调整主体色，不修改原版动作和彩色轨道。
- 此为内部参考页，不接原生 App、账本或模型，不是 Spine 文件。上游 MIT 授权覆盖代码；上游 README 声明其模仿的 x.ai 设计不属于该授权。本页不宣称品牌或形象权利已完成发布核查。

## 云朵改版对照

- `cloud-variants.mjs`：CheckLine 提案，新增云朵轨道、聚合、彗星姿态。继承固定版本 BotEngine 的姿态求值与眼部定位方法，未修改 vendor 文件，也未修改全局原版状态表。该适配依赖当前固定版本的方法结构，升级上游时须重新核对。
- `comparison.mjs`：同步时间轴、可中断的带时间戳状态序列、重播 / 取消 / 循环 / 慢放与减少动态控制。
- 原版参考保留原始动作；云朵版轨道采用原版三条轨道参数并降低速度、宽度和透明度；2026-09-25 最新轨道改版取消整体旋转，使用不同时间点的云瓣轮廓与独立眼神姿态，连续插值收紧、侧身、翻动、舒展与落稳，轨道中心延迟跟随身体位移。聚合与彗星沿用原版颗粒 / 拖尾，云瓣在长大早期恢复。所有幅度和节奏待用户审阅。

## 云朵聚散试作

- `cloud-flow.mjs`、`cloud-flow-page.mjs`：CheckLine 独立的固定风向聚散循环，仅复用固定版本 Cloud 轮廓与路径生成方法；未复用轨道姿态或引入外部颗粒库。
- 沿风向局部生长与消散、短距离云絮融合、稳定双眼、大图与头像同步播放。Animation Patterns Primitive Cluster 和 ZachSaucier/Disintegrate 仅为运动机制参考，未复制其代码或资产。
- 小尺寸使用独立的 3.2 秒云团聚散姿态、收紧的画布和局部轮廓变化，省去细碎颗粒；保留直接缩小版作对照。
- 试作参数等待审阅，未接入原生 App / Spine。

## 整片聚散思考态

- `cloud-dissolve.mjs` 根据固定上游 Cloud 的五个圆形构成重新生成云团；用独立的分散、缩小、云状轮廓和透明度曲线表达整片化开与重组，双眼随主体隐去及重现。每轮以固定种子生成受限落点、不同进出弧线、云团时间差和约 2.2–2.7 秒的时长；这些变化不是业务完成进度。重播保留当前种子，换一轮使用下一组参数。
- 旧版小尺寸聚散按独立 3.2 秒时钟保留作对照。未新增外部依赖，未生成 Spine 工程。

## 后续状态衔接小样（2026-09-25）

`cloud-states.mjs` / `cloud-states-page.mjs` 与 `2026-09-25-cloud-states.html` 为 CheckLine 的隔离设计提案。待机复用固定上游 `liveliness` / `blinkScale`，抬眼、等待与单眼回应参考 `wide` / `notify` / `wink` 的眼形比例和朝向，适配为正面二维面部；提示点改用本项目颜色。异常为新增的云朵旁感叹提示，原版 `exclaim` 仅在参考区展示。原版引擎用于参考区，未修改 vendor 文件。主体继续调用已确认的聚散引擎，新增当前姿态到目标状态的云团及眼部插值。没有新增外部依赖，不生成 Spine 文件，不连接真实任务或账本。

## 透光材质小样（2026-09-26）

`cloud-material.mjs` / `cloud-material-page.mjs` 与 `2026-09-26-cloud-material.html` 新增分层渐变、模糊内色、边缘厚度和整体悬浮，继续调用原有六状态播放器与已确认聚散采样器。Cloud 轮廓的来源和许可沿用上文。用户提供图片及 Rive 教程仅为材质层次参考，未复制其中的图片、角色或代码；未新增依赖、改动 vendor 文件或生成 Rive / Spine 工程。

## 内部流动思考态（2026-09-26）

`cloud-inner-flow.mjs` 新增受限平滑随机的内色色团漂移及轮廓变化、连续流转思考态、沿基础 Cloud 的局部行波、小幅眼神追视与可中断衔接。仍复用固定上游 Cloud 轮廓、路径生成与眨眼，参考范围和 MIT 声明不变。`cloud-material.mjs` 改为完整云壳裁切内部色团；本页已撤下聚散动作，历史聚散页及其采样器保留。未引入 Rive 运行时或外部资产。

## MIT License

Copyright (c) 2026 Jérémy Perret

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
