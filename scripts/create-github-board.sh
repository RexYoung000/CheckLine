#!/usr/bin/env bash
# Bootstrap CheckLine GitHub execution board: M0–M5 milestones, labels,
# six epics, and seven M0 slice issues.
#
# One-shot. After the board exists, GitHub is the task tracker — do not treat
# this script as a living checklist.
#
# Requires: gh authenticated with Issues write (repo scope, or fine-grained
# Issues: write + Metadata: read).
#
# Usage: ./scripts/create-github-board.sh

set -euo pipefail

REPO="${REPO:-RexYoung000/CheckLine}"
ROADMAP="docs/product/ROADMAP.md"

need_gh() {
  if ! command -v gh >/dev/null 2>&1; then
    echo "Need GitHub CLI (gh)." >&2
    exit 1
  fi
  if ! gh auth status -h github.com >/dev/null 2>&1; then
    echo "gh is not logged in to github.com." >&2
    exit 1
  fi
}

ensure_label() {
  local name="$1" color="$2" description="$3"
  gh label create "$name" \
    --repo "$REPO" \
    --color "$color" \
    --description "$description" \
    --force
}

ensure_milestone() {
  local title="$1" description="$2"
  local number
  number="$(
    gh api "repos/${REPO}/milestones?state=all&per_page=100" \
      --jq ".[] | select(.title == \"${title}\") | .number" | head -n1
  )"
  if [[ -n "$number" ]]; then
    gh api --method PATCH "repos/${REPO}/milestones/${number}" \
      -f title="$title" \
      -f description="$description" \
      -f state=open >/dev/null
    echo "$number"
    return
  fi
  gh api --method POST "repos/${REPO}/milestones" \
    -f title="$title" \
    -f description="$description" \
    -f state=open \
    --jq '.number'
}

issue_number_by_title() {
  local title="$1"
  gh issue list --repo "$REPO" --state all --limit 100 \
    --json number,title \
    --jq ".[] | select(.title == \"${title}\") | .number" | head -n1
}

ensure_issue() {
  local title="$1"
  local milestone="$2"
  shift 2
  local -a labels=()
  while [[ $# -gt 0 && "$1" != "--" ]]; do
    labels+=("$1")
    shift
  done
  if [[ $# -gt 0 && "$1" == "--" ]]; then
    shift
  fi
  local body="$1"

  local existing
  existing="$(issue_number_by_title "$title")"
  if [[ -n "$existing" ]]; then
    local -a edit_args=(--repo "$REPO" "$existing" --body "$body" --milestone "$milestone")
    local label
    for label in "${labels[@]}"; do
      edit_args+=(--add-label "$label")
    done
    gh issue edit "${edit_args[@]}" >/dev/null
    echo "$existing"
    return
  fi

  local -a create_args=(--repo "$REPO" --title "$title" --body "$body" --milestone "$milestone")
  local label
  for label in "${labels[@]}"; do
    create_args+=(--label "$label")
  done
  local url
  url="$(gh issue create "${create_args[@]}")"
  echo "${url##*/}"
}

need_gh

echo "Creating labels…"
ensure_label "type:epic" "6f42c1" "Milestone epic; split slices only after the gate"
ensure_label "type:slice" "0366d6" "Executable slice for the current milestone"
ensure_label "milestone:m0" "5319e7" "Search: M0 文档与交互原型"
ensure_label "milestone:m1" "0052cc" "Search: M1 确定性预算账本"
ensure_label "milestone:m2" "1d76db" "Search: M2 预算循环行动 Agent"
ensure_label "milestone:m3" "006b75" "Search: M3 数据来源与可信度"
ensure_label "milestone:m4" "0e8a16" "Search: M4 首页、结算与心愿体验"
ensure_label "milestone:m5" "bfd4f2" "Search: M5 V1 可靠性与公开准备"
ensure_label "area:product" "c2e0c6" "Product constitution, scope, or amount rules"
ensure_label "area:design" "d4c5f9" "Interaction contract, copy, or visual"
ensure_label "area:architecture" "1d76db" "Schema, domain services, or amount model"
ensure_label "blocked" "b60205" "Waiting on the previous milestone gate"

echo "Creating milestones…"
m0_ms="$(ensure_milestone "M0" "文档与交互原型。产品定义、金额规则和关键交互一致后再进入正式模型。当前进行中。权威来源：${ROADMAP}")"
m1_ms="$(ensure_milestone "M1" "确定性预算账本。门禁：M0 交互契约写入 DESIGN.md；唯一钱包基准币、换算时点、汇率来源写入 PRODUCT.md 与 ARCHITECTURE.md。未定时不得生成 walletSignedAmount。")"
m2_ms="$(ensure_milestone "M2" "预算循环行动 Agent。门禁：M1 测试不依赖 AI 和外部来源，跑通一个循环预算和一个一次性预算。")"
m3_ms="$(ensure_milestone "M3" "数据来源与可信度。门禁：同 M1。与 M2 不互阻；任一来源可跳过。")"
m4_ms="$(ensure_milestone "M4" "首页、结算与心愿体验。门禁：M1 完成；M2/M3 可并行收口。启动页不再是 Prototype。")"
m5_ms="$(ensure_milestone "M5" "V1 可靠性与公开准备。门禁：M4 真实页面走通。只做回归、降级、隐私和发布材料，不扩范围。")"
unset m0_ms m1_ms m2_ms m3_ms m4_ms m5_ms

echo "Creating epics…"

epic_m0="$(ensure_issue \
  "[Epic] M0 文档与交互原型" \
  "M0" \
  "type:epic" "milestone:m0" "area:product" "area:design" \
  -- \
  "$(cat <<EOF
## 循环

首次引导、每日预算、周期结算、心愿与追溯的交互契约尚未锁定。本 epic 只收 M0 文档工作，不开始正式模型。

权威切片来源：\`${ROADMAP}\`。GitHub 只负责任务分配，不另建第三份清单。

## 文档先行

- 交互契约：\`docs/design/DESIGN.md\`
- 钱包跨币种：\`PRODUCT.md\` 与 \`docs/engineering/ARCHITECTURE.md\`
- 阶段结束：更新 \`${ROADMAP}\` 实际产出

## 验收

- \`DESIGN.md\` 已确认交互契约可指导后续实现，而不是停留在原则层
- 钱包跨币种规则已写入产品宪法和架构，足以让 M1 生成或明确拒绝 \`walletSignedAmount\`
- 旧样机不再出现在当前需求入口

## 明确不做 / 依赖

- 正式 SwiftData Schema、领域服务重写、可发布 UI
- 在旧四 Tab 样机上叠加新 V1 功能
- 不改 Swift、不建空模块
- **过门禁后再拆 M1 切片。** 不要在本 epic 下预拆 Schema / Agent / 来源子 issue

### M0 切片

创建后回填。

### Blocks

M1 epic（过门禁后）
EOF
)"
)"

epic_m1="$(ensure_issue \
  "[Epic] M1 确定性预算账本" \
  "M1" \
  "type:epic" "milestone:m1" "area:architecture" "blocked" \
  -- \
  "$(cat <<EOF
## 循环

本地确定性账本：预算卡、唯一结算归属、结算、唯一心愿钱包、待恢复差额、心愿兑现、迟到交易与退款。不依赖 AI 和外部来源。

权威切片来源：\`${ROADMAP}\` 第五节 M1。**过门禁后再按该节拆子 issue**（\`BudgetEngine\`、\`CycleEngine\`、结算事务等），现在不要预拆。

## 文档先行

- Schema / 金额：先改 \`docs/engineering/ARCHITECTURE.md\`
- 钱包换算必须已由 M0 写入 \`PRODUCT.md\` 与 \`ARCHITECTURE.md\`

## 验收

- Swift Testing 覆盖 ROADMAP M1 列出的领域服务
- 不依赖 AI 和外部来源，同一币种跑通一个循环预算和一个一次性预算（含结算、钱包、待恢复差额、心愿兑现、迟到交易和退款）

## 明确不做 / 依赖

- 行动 Agent、系统权限、网络、被动数据来源、正式首页与主导航
- 币种规则未定时不得生成 \`walletSignedAmount\`

### Blocked by

M0 门禁：交互契约写入 \`DESIGN.md\`；唯一钱包基准币、换算时点、汇率来源写入 \`PRODUCT.md\` 与 \`ARCHITECTURE.md\`。

### Blocks

M2、M3、M4
EOF
)"
)"

epic_m2="$(ensure_issue \
  "[Epic] M2 预算循环行动 Agent" \
  "M2" \
  "type:epic" "milestone:m2" "blocked" \
  -- \
  "$(cat <<EOF
## 循环

每日预算循环中的行动 Agent：文字、语音、图片共用同一套行动与风险门禁。

权威切片来源：\`${ROADMAP}\` 第五节 M2。**过 M1 门禁后再拆子 issue。**

## 文档先行

- 风险门禁与确认页字段以 M0 写入的 \`DESIGN.md\` 为准
- 权限：\`docs/engineering/PERMISSIONS.md\` 与 \`docs/compliance/PRIVACY.md\`

## 验收

- 文字、语音、图片进入同一套结构化行动，不拆成多个产品入口
- Agent 只调用确定性领域服务，不自行生成余额、结余或钱包数字
- AI 不可用时，手动结构化记录仍能工作

## 明确不做 / 依赖

- 正式首页信息层级、被动数据来源连接器、按消费记录主动推荐购买
- 可以有能跑通门禁的任务面板；首页视觉与主导航定稿仍归 M4
- 与 M3 不互阻

### Blocked by

M1：测试跑通一个循环预算和一个一次性预算。
EOF
)"
)"

epic_m3="$(ensure_issue \
  "[Epic] M3 数据来源与可信度" \
  "M3" \
  "type:epic" "milestone:m3" "blocked" \
  -- \
  "$(cat <<EOF
## 循环

被动记录与导入：标准化、跨来源去重、覆盖时间与缺口。全部可跳过。

权威切片来源：\`${ROADMAP}\` 第五节 M3。**过 M1 门禁后再拆子 issue。** 先做平台风险最低的账单文件导入。

## 文档先行

- 数据流：\`docs/engineering/PERMISSIONS.md\` 与 \`docs/compliance/PRIVACY.md\`
- 若邮件需要中转，先更新隐私文档再接入

## 验收

- 高度一致的重复记录自动合并并保留来源证据；无法确定时再询问用户
- 设置页可跳过、断开和之后补连
- 任一来源失败不得阻断手动记录和本地账本

## 明确不做 / 依赖

- 宣称全渠道或全球银行「安装后自动同步」
- 偷读其他 App 通知、模拟登录支付或银行账号
- 与 M2 不互阻

### Blocked by

M1：测试跑通一个循环预算和一个一次性预算。
EOF
)"
)"

epic_m4="$(ensure_issue \
  "[Epic] M4 首页、结算与心愿体验" \
  "M4" \
  "type:epic" "milestone:m4" "area:design" "blocked" \
  -- \
  "$(cat <<EOF
## 循环

把 M1–M3 收成可日常使用的产品：首页、检查式结算、心愿兑现、来源覆盖，并替换启动页。

权威切片来源：\`${ROADMAP}\` 第五节 M4。**过门禁后再拆子 issue。** 按 M0 契约实现，不要把旧四 Tab 当定案。

## 文档先行

- 页面 / 文案：\`docs/design/DESIGN.md\`
- 不在本阶段发明新的金额规则或新的数据来源类型

## 验收

- 用户能在真实页面完成「创建预算卡 → 记一笔 → 查看已用/剩余/覆盖 → 结算 → 心愿兑现」
- 待确认金额只触发「可能」风险，不能形成确定越线结论
- 核心任务在不同设备、文字缩放、VoiceOver 和减少动态效果下完整可用
- \`CheckLineApp\` 不再启动 \`CheckLinePrototypeView\`

## 明确不做 / 依赖

- 新的金额规则或新的数据来源类型
- 把旧四 Tab 样机当作定案导航

### Blocked by

M1 完成；M2 与 M3 可并行收口。
EOF
)"
)"

epic_m5="$(ensure_issue \
  "[Epic] M5 V1 可靠性与公开准备" \
  "M5" \
  "type:epic" "milestone:m5" "blocked" \
  -- \
  "$(cat <<EOF
## 循环

完整预算循环的发布准备。只做回归、降级、隐私和发布材料，不补新功能。

权威切片来源：\`${ROADMAP}\` 第五节 M5。**过 M4 门禁后再拆子 issue。**

## 文档先行

- App Store 申报只能依据待提交二进制的真实行为
- 隐私说明必须与 \`docs/compliance/PRIVACY.md\` 一致

## 验收

- 金额回归全绿
- 降级路径可演示：文字 Agent 与本地账本在无网络、无权限、无被动来源时仍可用
- 二进制行为与隐私说明一致

## 明确不做 / 依赖

- 商业化范围扩张、macOS Target、Widget 或其他 V1 之后能力

### Blocked by

M4：首页、结算、心愿、来源覆盖在真实页面和目标视口可走通；启动页不再是 Prototype。
EOF
)"
)"

echo "Creating M0 slices…"

slice_home="$(ensure_issue \
  "[M0] 首页多卡信息层级与固定顺序" \
  "M0" \
  "type:slice" "milestone:m0" "area:design" \
  -- \
  "$(cat <<EOF
## 循环

每日预算循环 · 首页：预算卡主体按用户固定顺序展示已用、剩余、周期进度；待确认金额单独展示。顶部处理区与底部 Agent 不在本 issue 定视觉像素。

## 文档先行

- 只改 \`docs/design/DESIGN.md\` 已确认交互契约
- 产出是信息层级，不是可发布 UI，也不是改 \`Features/Prototype\`

## 验收

- 多张预算卡的信息层级和固定顺序已写入 DESIGN，可指导 M4
- 不定视觉定案到像素；预算卡不因风险每天自动跳位

## 明确不做 / 依赖

- 不改 Swift、不建空模块、不在旧样机上加功能
- 不定死旧四 Tab

### Blocks

视口核对切片；M0 epic
EOF
)"
)"

slice_nav="$(ensure_issue \
  "[M0] 主导航与记录/心愿/设置入口" \
  "M0" \
  "type:slice" "milestone:m0" "area:design" \
  -- \
  "$(cat <<EOF
## 循环

信息架构：记录、心愿、设置各自入口。首页主体仍是预算状态，不是聊天记录。

## 文档先行

- 只改 \`docs/design/DESIGN.md\`
- 主导航尚未确认，不能沿用旧四 Tab 当作定案

## 验收

- DESIGN 写清记录 / 心愿 / 设置如何进入，以及与首页、底部 Agent 的关系
- 不把旧样机四 Tab 写成当前需求

## 明确不做 / 依赖

- 不改 Swift、不建空模块
- 不实现可发布导航壳（那是 M4）

### Blocks

视口核对切片；M0 epic
EOF
)"
)"

slice_agent="$(ensure_issue \
  "[M0] Agent 底部任务面板状态与全屏升级条件" \
  "M0" \
  "type:slice" "milestone:m0" "area:design" \
  -- \
  "$(cat <<EOF
## 循环

每日预算循环 · 底部常驻 Agent。唤起后使用底部任务面板；简单操作原地完成，复杂或高风险任务再全屏确认。

## 文档先行

- 只改 \`docs/design/DESIGN.md\`
- 风险门禁字段要能被 M2 的 \`ConfirmationGate\` 使用，但不在本 issue 实现 Agent

## 验收

- 面板状态、反馈、全屏升级条件已写入 DESIGN
- 低风险单笔、不确定归属、高影响金额三类路径可区分

## 明确不做 / 依赖

- 不接真实 AI、不申请麦克风/照片权限、不改 Swift

### Blocks

视口核对切片；M0 epic
EOF
)"
)"

slice_confirm="$(ensure_issue \
  "[M0] 结算检查页与心愿兑现确认页金额影响" \
  "M0" \
  "type:slice" "milestone:m0" "area:design" "area:product" \
  -- \
  "$(cat <<EOF
## 循环

周期结算循环与心愿循环：结算前必须看见支出、结余或越线、待确认、数据覆盖；心愿兑现必须确认真实购买和实际成交金额。

## 文档先行

- 改 \`docs/design/DESIGN.md\`（确认页必须出现的字段，不是可发布 UI）
- 金额含义以 \`PRODUCT.md\` 与 \`docs/product/GLOSSARY.md\` 为准，本 issue 不改金额公式

## 验收

- 结算检查页与心愿兑现确认页要展示的金额影响已写成契约
- 能支持后续 \`ConfirmationGate\`，但不实现结算引擎

## 明确不做 / 依赖

- 不改 Swift、不实现钱包账本、不在旧结算 Sheet 上继续加功能

### Blocks

视口核对切片；M0 epic
EOF
)"
)"

slice_fx="$(ensure_issue \
  "[M0] 唯一钱包基准币、换算时点与汇率来源" \
  "M0" \
  "type:slice" "milestone:m0" "area:product" "area:architecture" \
  -- \
  "$(cat <<EOF
## 循环

结算与心愿循环：多币种预算进入唯一心愿钱包。这是 **M1 钱包账本硬门禁**。

## 文档先行

- 必须写入 \`PRODUCT.md\` 与 \`docs/engineering/ARCHITECTURE.md\`
- 确认前只能保存来源金额，不能生成 \`walletSignedAmount\`、合并不同币种余额或判断跨币种心愿是否可兑现

## 验收

- 钱包基准币、换算时点、汇率来源已由产品确认并写入宪法和架构
- M1 足以生成或明确拒绝 \`walletSignedAmount\`

## 明确不做 / 依赖

- 不实现 \`CurrencyEngine\` / \`WalletLedger\` 代码
- 不在规则未定时预拆 M1 子 issue

### Blocks

M1 epic；M0 epic
EOF
)"
)"

slice_viewport="$(ensure_issue \
  "[M0] 用真实内容核对关键状态和目标视口" \
  "M0" \
  "type:slice" "milestone:m0" "area:design" \
  -- \
  "$(cat <<EOF
## 循环

用真实内容走一遍首页处理区、预算卡、Agent 面板、结算确认、心愿确认，核对应在目标视口上可读。

## 文档先行

- 只更新 \`docs/design/DESIGN.md\` 已确认框架
- 产出是契约可验收，不是改旧样机，也不是可发布 UI

## 验收

- 关键状态（待确认、未纳入、覆盖缺口、可能/确定风险、结余/越线、待恢复差额）在目标视口有真实内容核对记录
- 发现的信息层级问题回写 DESIGN，而不是直接改 \`Features/Prototype\`

## 明确不做 / 依赖

- 不改 Swift、不把旧 8 页样机当新 V1 实现

### Blocked by

首页信息层级、主导航、Agent 面板、结算/心愿确认页四个切片完成后再做。
EOF
)"
)"

slice_archive="$(ensure_issue \
  "[M0] 旧样机降为历史参考并清出当前需求入口" \
  "M0" \
  "type:slice" "milestone:m0" "area:design" \
  -- \
  "$(cat <<EOF
## 循环

文档治理：历史原型不能覆盖 2026-08-10 之后的产品定义。可与其他 M0 切片并行。

## 文档先行

- 核对 \`docs/design/DESIGN.md\`、\`docs/README.md\`、\`docs/engineering/SETUP.md\` 的当前需求入口
- 历史材料只留在 \`docs/archive/\` 或明确标成历史样机

## 验收

- 旧四 Tab、多预算重复扣减、悬浮文本/语音入口不再出现在当前需求入口
- 不在 \`Features/Prototype\` 的多预算模型上继续加新 V1 功能
- 启动页仍可暂时指向旧样机，直到 M4 替换；文档必须写明这一点

## 明确不做 / 依赖

- 不删除样机代码（M4 之前仍作历史视觉/工程参考）
- 不创建空的 Home / AgentPanel 模块目录
EOF
)"
)"

echo "Linking Blocked by / Blocks…"

gh issue edit "$epic_m0" --repo "$REPO" --body "$(cat <<EOF
## 循环

首次引导、每日预算、周期结算、心愿与追溯的交互契约尚未锁定。本 epic 只收 M0 文档工作，不开始正式模型。

权威切片来源：\`${ROADMAP}\`。GitHub 只负责任务分配，不另建第三份清单。

## 文档先行

- 交互契约：\`docs/design/DESIGN.md\`
- 钱包跨币种：\`PRODUCT.md\` 与 \`docs/engineering/ARCHITECTURE.md\`
- 阶段结束：更新 \`${ROADMAP}\` 实际产出

## 验收

- \`DESIGN.md\` 已确认交互契约可指导后续实现，而不是停留在原则层
- 钱包跨币种规则已写入产品宪法和架构，足以让 M1 生成或明确拒绝 \`walletSignedAmount\`
- 旧样机不再出现在当前需求入口

## 明确不做 / 依赖

- 正式 SwiftData Schema、领域服务重写、可发布 UI
- 在旧四 Tab 样机上叠加新 V1 功能
- 不改 Swift、不建空模块
- **过门禁后再拆 M1 切片。** 不要在本 epic 下预拆 Schema / Agent / 来源子 issue

### M0 切片

- #${slice_home}
- #${slice_nav}
- #${slice_agent}
- #${slice_confirm}
- #${slice_fx}
- #${slice_viewport}
- #${slice_archive}

### Blocks

- #${epic_m1}
EOF
)" >/dev/null

gh issue edit "$epic_m1" --repo "$REPO" --body "$(cat <<EOF
## 循环

本地确定性账本：预算卡、唯一结算归属、结算、唯一心愿钱包、待恢复差额、心愿兑现、迟到交易与退款。不依赖 AI 和外部来源。

权威切片来源：\`${ROADMAP}\` 第五节 M1。**过门禁后再按该节拆子 issue**（\`BudgetEngine\`、\`CycleEngine\`、结算事务等），现在不要预拆。

## 文档先行

- Schema / 金额：先改 \`docs/engineering/ARCHITECTURE.md\`
- 钱包换算必须已由 M0 写入 \`PRODUCT.md\` 与 \`ARCHITECTURE.md\`

## 验收

- Swift Testing 覆盖 ROADMAP M1 列出的领域服务
- 不依赖 AI 和外部来源，同一币种跑通一个循环预算和一个一次性预算（含结算、钱包、待恢复差额、心愿兑现、迟到交易和退款）

## 明确不做 / 依赖

- 行动 Agent、系统权限、网络、被动数据来源、正式首页与主导航
- 币种规则未定时不得生成 \`walletSignedAmount\`

### Blocked by

- #${epic_m0}
- #${slice_fx}（钱包币种硬门禁）

### Blocks

- #${epic_m2}
- #${epic_m3}
- #${epic_m4}
EOF
)" >/dev/null

gh issue edit "$epic_m2" --repo "$REPO" --body "$(cat <<EOF
## 循环

每日预算循环中的行动 Agent：文字、语音、图片共用同一套行动与风险门禁。

权威切片来源：\`${ROADMAP}\` 第五节 M2。**过 M1 门禁后再拆子 issue。**

## 文档先行

- 风险门禁与确认页字段以 M0 写入的 \`DESIGN.md\` 为准
- 权限：\`docs/engineering/PERMISSIONS.md\` 与 \`docs/compliance/PRIVACY.md\`

## 验收

- 文字、语音、图片进入同一套结构化行动，不拆成多个产品入口
- Agent 只调用确定性领域服务，不自行生成余额、结余或钱包数字
- AI 不可用时，手动结构化记录仍能工作

## 明确不做 / 依赖

- 正式首页信息层级、被动数据来源连接器、按消费记录主动推荐购买
- 可以有能跑通门禁的任务面板；首页视觉与主导航定稿仍归 M4
- 与 M3 不互阻

### Blocked by

- #${epic_m1}

### Blocks

- #${epic_m4}
EOF
)" >/dev/null

gh issue edit "$epic_m3" --repo "$REPO" --body "$(cat <<EOF
## 循环

被动记录与导入：标准化、跨来源去重、覆盖时间与缺口。全部可跳过。

权威切片来源：\`${ROADMAP}\` 第五节 M3。**过 M1 门禁后再拆子 issue。** 先做平台风险最低的账单文件导入。

## 文档先行

- 数据流：\`docs/engineering/PERMISSIONS.md\` 与 \`docs/compliance/PRIVACY.md\`
- 若邮件需要中转，先更新隐私文档再接入

## 验收

- 高度一致的重复记录自动合并并保留来源证据；无法确定时再询问用户
- 设置页可跳过、断开和之后补连
- 任一来源失败不得阻断手动记录和本地账本

## 明确不做 / 依赖

- 宣称全渠道或全球银行「安装后自动同步」
- 偷读其他 App 通知、模拟登录支付或银行账号
- 与 M2 不互阻

### Blocked by

- #${epic_m1}

### Blocks

- #${epic_m4}
EOF
)" >/dev/null

gh issue edit "$epic_m4" --repo "$REPO" --body "$(cat <<EOF
## 循环

把 M1–M3 收成可日常使用的产品：首页、检查式结算、心愿兑现、来源覆盖，并替换启动页。

权威切片来源：\`${ROADMAP}\` 第五节 M4。**过门禁后再拆子 issue。** 按 M0 契约实现，不要把旧四 Tab 当定案。

## 文档先行

- 页面 / 文案：\`docs/design/DESIGN.md\`
- 不在本阶段发明新的金额规则或新的数据来源类型

## 验收

- 用户能在真实页面完成「创建预算卡 → 记一笔 → 查看已用/剩余/覆盖 → 结算 → 心愿兑现」
- 待确认金额只触发「可能」风险，不能形成确定越线结论
- 核心任务在不同设备、文字缩放、VoiceOver 和减少动态效果下完整可用
- \`CheckLineApp\` 不再启动 \`CheckLinePrototypeView\`

## 明确不做 / 依赖

- 新的金额规则或新的数据来源类型
- 把旧四 Tab 样机当作定案导航

### Blocked by

- #${epic_m1}
- #${epic_m2}
- #${epic_m3}

### Blocks

- #${epic_m5}
EOF
)" >/dev/null

gh issue edit "$epic_m5" --repo "$REPO" --body "$(cat <<EOF
## 循环

完整预算循环的发布准备。只做回归、降级、隐私和发布材料，不补新功能。

权威切片来源：\`${ROADMAP}\` 第五节 M5。**过 M4 门禁后再拆子 issue。**

## 文档先行

- App Store 申报只能依据待提交二进制的真实行为
- 隐私说明必须与 \`docs/compliance/PRIVACY.md\` 一致

## 验收

- 金额回归全绿
- 降级路径可演示：文字 Agent 与本地账本在无网络、无权限、无被动来源时仍可用
- 二进制行为与隐私说明一致

## 明确不做 / 依赖

- 商业化范围扩张、macOS Target、Widget 或其他 V1 之后能力

### Blocked by

- #${epic_m4}
EOF
)" >/dev/null

gh issue edit "$slice_home" --repo "$REPO" --body "$(cat <<EOF
## 循环

每日预算循环 · 首页：预算卡主体按用户固定顺序展示已用、剩余、周期进度；待确认金额单独展示。顶部处理区与底部 Agent 不在本 issue 定视觉像素。

## 文档先行

- 只改 \`docs/design/DESIGN.md\` 已确认交互契约
- 产出是信息层级，不是可发布 UI，也不是改 \`Features/Prototype\`

## 验收

- 多张预算卡的信息层级和固定顺序已写入 DESIGN，可指导 M4
- 不定视觉定案到像素；预算卡不因风险每天自动跳位

## 明确不做 / 依赖

- 不改 Swift、不建空模块、不在旧样机上加功能
- 不定死旧四 Tab

### Blocks

- #${slice_viewport}
- #${epic_m0}
EOF
)" >/dev/null

gh issue edit "$slice_nav" --repo "$REPO" --body "$(cat <<EOF
## 循环

信息架构：记录、心愿、设置各自入口。首页主体仍是预算状态，不是聊天记录。

## 文档先行

- 只改 \`docs/design/DESIGN.md\`
- 主导航尚未确认，不能沿用旧四 Tab 当作定案

## 验收

- DESIGN 写清记录 / 心愿 / 设置如何进入，以及与首页、底部 Agent 的关系
- 不把旧样机四 Tab 写成当前需求

## 明确不做 / 依赖

- 不改 Swift、不建空模块
- 不实现可发布导航壳（那是 M4）

### Blocks

- #${slice_viewport}
- #${epic_m0}
EOF
)" >/dev/null

gh issue edit "$slice_agent" --repo "$REPO" --body "$(cat <<EOF
## 循环

每日预算循环 · 底部常驻 Agent。唤起后使用底部任务面板；简单操作原地完成，复杂或高风险任务再全屏确认。

## 文档先行

- 只改 \`docs/design/DESIGN.md\`
- 风险门禁字段要能被 M2 的 \`ConfirmationGate\` 使用，但不在本 issue 实现 Agent

## 验收

- 面板状态、反馈、全屏升级条件已写入 DESIGN
- 低风险单笔、不确定归属、高影响金额三类路径可区分

## 明确不做 / 依赖

- 不接真实 AI、不申请麦克风/照片权限、不改 Swift

### Blocks

- #${slice_viewport}
- #${epic_m0}
EOF
)" >/dev/null

gh issue edit "$slice_confirm" --repo "$REPO" --body "$(cat <<EOF
## 循环

周期结算循环与心愿循环：结算前必须看见支出、结余或越线、待确认、数据覆盖；心愿兑现必须确认真实购买和实际成交金额。

## 文档先行

- 改 \`docs/design/DESIGN.md\`（确认页必须出现的字段，不是可发布 UI）
- 金额含义以 \`PRODUCT.md\` 与 \`docs/product/GLOSSARY.md\` 为准，本 issue 不改金额公式

## 验收

- 结算检查页与心愿兑现确认页要展示的金额影响已写成契约
- 能支持后续 \`ConfirmationGate\`，但不实现结算引擎

## 明确不做 / 依赖

- 不改 Swift、不实现钱包账本、不在旧结算 Sheet 上继续加功能

### Blocks

- #${slice_viewport}
- #${epic_m0}
EOF
)" >/dev/null

gh issue edit "$slice_fx" --repo "$REPO" --body "$(cat <<EOF
## 循环

结算与心愿循环：多币种预算进入唯一心愿钱包。这是 **M1 钱包账本硬门禁**。

## 文档先行

- 必须写入 \`PRODUCT.md\` 与 \`docs/engineering/ARCHITECTURE.md\`
- 确认前只能保存来源金额，不能生成 \`walletSignedAmount\`、合并不同币种余额或判断跨币种心愿是否可兑现

## 验收

- 钱包基准币、换算时点、汇率来源已由产品确认并写入宪法和架构
- M1 足以生成或明确拒绝 \`walletSignedAmount\`

## 明确不做 / 依赖

- 不实现 \`CurrencyEngine\` / \`WalletLedger\` 代码
- 不在规则未定时预拆 M1 子 issue

### Blocks

- #${epic_m1}
- #${epic_m0}
EOF
)" >/dev/null

gh issue edit "$slice_viewport" --repo "$REPO" --body "$(cat <<EOF
## 循环

用真实内容走一遍首页处理区、预算卡、Agent 面板、结算确认、心愿确认，核对应在目标视口上可读。

## 文档先行

- 只更新 \`docs/design/DESIGN.md\` 已确认框架
- 产出是契约可验收，不是改旧样机，也不是可发布 UI

## 验收

- 关键状态（待确认、未纳入、覆盖缺口、可能/确定风险、结余/越线、待恢复差额）在目标视口有真实内容核对记录
- 发现的信息层级问题回写 DESIGN，而不是直接改 \`Features/Prototype\`

## 明确不做 / 依赖

- 不改 Swift、不把旧 8 页样机当新 V1 实现

### Blocked by

- #${slice_home}
- #${slice_nav}
- #${slice_agent}
- #${slice_confirm}

### Blocks

- #${epic_m0}
EOF
)" >/dev/null

gh issue edit "$slice_archive" --repo "$REPO" --body "$(cat <<EOF
## 循环

文档治理：历史原型不能覆盖 2026-08-10 之后的产品定义。可与其他 M0 切片并行。

## 文档先行

- 核对 \`docs/design/DESIGN.md\`、\`docs/README.md\`、\`docs/engineering/SETUP.md\` 的当前需求入口
- 历史材料只留在 \`docs/archive/\` 或明确标成历史样机

## 验收

- 旧四 Tab、多预算重复扣减、悬浮文本/语音入口不再出现在当前需求入口
- 不在 \`Features/Prototype\` 的多预算模型上继续加新 V1 功能
- 启动页仍可暂时指向旧样机，直到 M4 替换；文档必须写明这一点

## 明确不做 / 依赖

- 不删除样机代码（M4 之前仍作历史视觉/工程参考）
- 不创建空的 Home / AgentPanel 模块目录

### Blocks

- #${epic_m0}
EOF
)" >/dev/null

cat <<EOF

Board created.

Epics
  M0  https://github.com/${REPO}/issues/${epic_m0}
  M1  https://github.com/${REPO}/issues/${epic_m1}
  M2  https://github.com/${REPO}/issues/${epic_m2}
  M3  https://github.com/${REPO}/issues/${epic_m3}
  M4  https://github.com/${REPO}/issues/${epic_m4}
  M5  https://github.com/${REPO}/issues/${epic_m5}

M0 slices
  首页信息层级     https://github.com/${REPO}/issues/${slice_home}
  主导航           https://github.com/${REPO}/issues/${slice_nav}
  Agent 面板       https://github.com/${REPO}/issues/${slice_agent}
  确认页金额影响   https://github.com/${REPO}/issues/${slice_confirm}
  钱包基准币       https://github.com/${REPO}/issues/${slice_fx}
  视口核对         https://github.com/${REPO}/issues/${slice_viewport}
  旧样机降级       https://github.com/${REPO}/issues/${slice_archive}
EOF
