# Features/

按用户视角划分的业务模块。一个目录 = 用户能感知的一组完整功能。

| 模块 | 范围 |
|------|------|
| `Budget/` | 预算创建、列表、详情、扣血主屏 |
| `Expense/` | 记一笔（含归类弹窗）、流水列表 |
| `Settlement/` | 结算清单、关联账确认、结算高光仪式 |
| `Wish/` | 心愿设定、进度、达成庆祝 |
| `Insights/` | 仪表盘、月度回顾（v1.1） |

**纪律**：
- Feature 之间不能互相 import，共用逻辑下沉到 `Core/Services/`
- Feature 不直接持有 SwiftData ModelContext，通过 `Core/Services/` 提供的接口访问
- 一个 Feature 内可以有自己的 ViewModel / View / 局部组件
