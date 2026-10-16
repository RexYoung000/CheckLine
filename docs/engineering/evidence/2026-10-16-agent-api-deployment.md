# 2026-10-16 小朵 API 内部部署

Rex 已确认 Workflow，随后明确授权 Codex 部署；没有域名，选择先完成内部服务。此记录只验收服务器与合成请求，不代表 App 接通或新增退款等业务可用。

## 运行状态与版本

| 项目 | 已核实事实 |
|---|---|
| 服务器 | 腾讯云广州轻量服务器，`123.207.2.148`，4 核 / 4GB / 40GB |
| 系统 | OpenCloudOS 9.6，x86_64；系统时钟已同步 |
| 运行时 | Node.js 24.22.0；官方固定版本归档经 SHA-256 校验 |
| API 源码基线 | `010ea8a795a22b0118bfd526a7a1735791e5f12f`，生产 Workflow 源码未修改 |
| 运行 release | `/opt/checkline-agent/releases/20261016-6f91586d3b07` |
| 上传归档 SHA-256 | `6f91586d3b07877fb276fe655e935daceb5f2b3db31afdbc517f68906bc6bfc3` |
| 进程管理 | `checkline-agent.service`，独立 `checkline-agent` 无登录账号，active/running、enabled |
| 内部健康检查 | `http://127.0.0.1:8787/health` 返回 `200`，`ready / live` |
| 内部解析接口 | `http://127.0.0.1:8787/v1/agent/interpret`，必须私有 Bearer Token |
| 凭据位置 | `/etc/checkline-agent/agent.env`，root 所有；目录 0700、文件 0600 |

安装脚本和服务配置位于 [`services/agent-api/deploy`](../../../services/agent-api/deploy/)。Node 来源为 [官方固定版本目录](https://nodejs.org/dist/v24.22.0/)，校验值来自 [官方 SHA-256 清单](https://nodejs.org/dist/v24.22.0/SHASUMS256.txt)。DeepSeek 使用既定 `deepseek-flash`、思考 enabled / high、JSON 输出，没有更换模型或思考档位。

## 本次真实检查

- 本机 Node.js 24.16.0：275 / 275 检查通过，Swift 候选与请求字段契约检查通过，部署脚本语法和 Git 空白检查通过。
- 服务器 Node.js 24.22.0：同份源码 275 / 275 检查通过；systemd 配置验证通过。验证器另提示腾讯云既有 TAT 服务的旧 PIDFile 路径，没有修改该云端组件。
- 真实 API 拒绝未认证请求（401）、未知上传字段（400），生产模式不开放 `/review`（404）。
- 完整消费合成样例：真实 DeepSeek 返回 `capture`，金额与明确指定预算均保留，1574 ms。
- 缺金额合成样例：返回 `needsClarification` / `amount`，不伪造金额，1592 ms。
- 相对日期合成样例：使用虚构设备参考 `2026-10-16T12:00:00+08:00` 和 `Asia/Shanghai`，昨天为当地 10 月 15 日（返回 `2026-10-14T16:00:00Z`），1392 ms。日期由程序按设备时区计算。
- 重启后重新通过健康检查，进程仍是独立账号，自动失败重启次数 0；已配置开机启动，没有重启整台服务器。
- 实际监听仅 SSH 22 与回环 8787。服务内存约 18 MiB，限制 256 MiB / 64 tasks；`ProtectSystem=strict` 与 `NoNewPrivileges=yes` 已生效。
- 检查 10 条服务进程日志，只含就绪事件或请求 ID、状态、耗时；运行版本不含实际模型密钥或联调 Token。运行账号不能读取凭据文件或写入源码目录。

3 个成功样例只证明该时间点的真实链路与这些输入可用，不能据此推断整体模型准确率、持续性能或其他地区可用性。健康检查不等于上游可用性检查。

## 运维与后续边界

维护步骤见 [API README](../../../services/agent-api/README.md#腾讯云原生-node--systemd-部署)。首次安装没有前一 release；后续版本保留 `previous`，首次停用可执行 `systemctl disable --now checkline-agent`，不删除其他服务或数据。系统未安装 Docker；此前 Docker 构建与运行仍未验收。

Rex 提供域名后再配置有效 HTTPS 与外部访问；不把内部 HTTP 地址填入 App。公网／海外访问、第三方处理约定、公开用户身份／配额、原生候选合并与归属门禁、手机接入及真机体验仍未验证。此轮没有修改 App、读取或上传账本、打开手机云端开关、部署公开用户服务。
