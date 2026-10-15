import { calendarDay, planCapture, moneyLabel } from "./capture-flow.mjs";

const cases = JSON.parse(document.getElementById("review-data").textContent);
const $ = (id) => document.getElementById(id);
let state;
const node = (tag, text, className) => {
  const element = document.createElement(tag);
  if (text !== undefined) element.textContent = text;
  if (className) element.className = className;
  return element;
};
function button(label, run, primary = false) {
  const element = node("button", label, "action-button" + (primary ? " primary" : ""));
  element.type = "button"; element.addEventListener("click", run); $("actions").append(element);
}
function choose(item) {
  state = { item, draft: structuredClone(item.candidate ?? {}), local: structuredClone(item.local), answers: {}, cancelled: false };
  document.querySelectorAll(".case-button").forEach((element) => element.setAttribute("aria-pressed", String(element.dataset.case === item.id)));
  $("mobile-cases").value = item.id;
  history.replaceState(null, "", "#" + item.id);
  $("edit").open = false;
  render();
}
function simulateSave() {
  const plan = planCapture(state.draft, state.local, state.answers);
  if (!plan.ready) return render();
  state.saved = { basis: plan.basis, quoteToken: state.answers.quoteToken };
  state.undoNotice = false;
  render();
}
function generalPrompt(item) {
  if (item.status !== 200) return item.error === "model_timeout" ? "这次理解超时了，输入还在。可以重试或手动填写。" : "这次结果无法使用，输入已保留。";
  if (item.id.startsWith("refund")) return "这是退款，需要核对原消费。退款操作尚未接通，这里先保留输入。";
  const field = item.candidate?.clarificationField;
  const prompts = { amount: "这笔花了多少？", occurredAt: "这笔是哪一天的消费？", budgetName: "你指的是哪张预算卡？",
    action: item.id === "correction" ? "你想把哪一项改成38元？" : "你想记录已发生的消费，还是添加一个心愿？",
    input: item.id === "multiple" ? "这里有多笔消费，请分别核对，不能合成一笔。" : "再补充一下你想做什么？",
    periodID: "你想处理哪张预算卡的哪一期？", wishID: "你想兑现哪一个心愿？" };
  return prompts[field] ?? (item.candidate?.intentType === "createBudget" ? "预算信息已整理，先核对实际生效日期。"
    : item.candidate?.intentType === "outOfScope" ? "我可以协助预算和心愿相关的操作。" : "还需要核对这次操作。" );
}
function addCheck(label, value, status = "waiting") {
  const row = node("div", undefined, "check");
  const mark = node("span", status === "done" ? "✓" : status === "blocked" ? "!" : "○", "mark" + (status === "blocked" ? " blocked" : ""));
  mark.setAttribute("aria-label", status === "done" ? "已核对" : status === "blocked" ? "需处理" : "待核对");
  const content = node("div"); content.append(node("strong", label), node("p", value)); row.append(mark, content); $("checks").append(row);
}
function renderReceipt(plan) {
  $("receipt").replaceChildren();
  $("receipt").hidden = !(plan?.card || plan?.attribution === "unbudgeted");
  if ($("receipt").hidden) return;
  $("receipt").append(node("div", plan.quote ? moneyLabel(plan.quote.convertedAmount, plan.card.currencyCode)
    : moneyLabel(state.draft.amount, state.draft.currencyCode), "amount"));
  if (plan.quote) $("receipt").append(node("div", `原币 ${moneyLabel(state.draft.amount, state.draft.currencyCode)} · 固定虚构报价`, "original"));
  const dl = node("dl");
  const rows = [["消费日期", plan.day ?? "待核对"], ["预算卡", plan.card?.name ?? "未纳入预算"],
    ["所属周期", plan.period ? `${plan.period.startDay} — ${plan.period.endDay}` : plan.attribution === "unbudgeted" ? "不计入预算" : "尚未匹配"]];
  if (plan.origin) rows.push(["归属依据", plan.origin]);
  if (plan.period?.status === "queued") rows.push(["处理方式", "下周期队列"]);
  if (plan.period?.status === "settled") rows.push(["周期状态", "已结算，需追溯确认"]);
  for (const [label, value] of rows) dl.append(node("dt", label), node("dd", value));
  $("receipt").append(dl);
}
function render() {
  const { item } = state;
  const plan = item.captureFlow ? planCapture(state.draft, state.local, state.answers) : null;
  if (state.saved && (!plan?.ready || state.saved.basis !== plan.basis || state.saved.quoteToken !== state.answers.quoteToken)) state.saved = null;
  $("scenario").textContent = item.label;
  $("entry").textContent = state.local.entry ? "从餐饮卡进入" : "全局小朵入口";
  $("input").textContent = item.input;
  $("prompt").textContent = state.cancelled ? "输入已保留，随时可以继续。" : state.saved ? "模拟记录完成。" : plan?.prompt ?? generalPrompt(item);
  $("support").hidden = !plan?.note || state.cancelled || !!state.saved;
  $("support").textContent = plan?.note ?? "";
  $("choices").replaceChildren(); $("actions").replaceChildren(); $("checks").replaceChildren();
  $("status").textContent = state.cancelled ? "尚未执行 · 字段保留" : state.saved ? "仅完成演示，真实账本没有变化" : state.undoNotice ? "已撤销本次模拟 · 输入保留"
    : plan?.ready ? "归属与日期已核对 · 可模拟保存" : plan?.stage === "retrospective" ? "已停止普通录入" : "等待核对 · 尚未执行";
  if (!state.cancelled && !state.saved) {
    for (const option of plan?.options ?? []) {
      const element = node("button", undefined, "choice" + (option.kind === "unbudgeted" ? " unbudgeted" : ""));
      element.type = "button";
      element.append(node("strong", option.kind === "budget" ? `记到${option.label}` : option.label), node("small", option.detail));
      element.addEventListener("click", () => {
        state.answers = { attribution: { basis: plan.basis, kind: option.kind, id: option.id } };
        state.undoNotice = false; render();
      });
      $("choices").append(element);
    }
    if (plan?.ready) button("模拟保存", simulateSave, true);
    if (plan?.stage === "confirmRate") button("确认此换算（演示）", () => {
      state.answers.quoteToken = plan.quoteToken; simulateSave();
    }, true);
    if (plan?.stage === "needsRate" && item.quoteOnRetry) button("重试换算（演示）", () => {
      state.local.quote = structuredClone(item.quoteOnRetry); render();
    }, true);
    if (item.status !== 200) button("重试本例", () => choose(item));
    button("暂不记录", () => { state.cancelled = true; render(); });
  } else if (state.cancelled) {
    button("继续核对", () => { state.cancelled = false; render(); }, true);
  } else {
    button("撤销这次模拟", () => { state.saved = null; state.undoNotice = true; render(); }, true);
  }
  renderReceipt(plan);
  if (plan) {
    addCheck("消费事实", moneyLabel(state.draft.amount, state.draft.currencyCode), state.draft.amount ? "done" : "waiting");
    const deviceDay = calendarDay(state.local.deviceTime?.timestamp, state.local.deviceTime?.timeZoneIdentifier);
    addCheck("日期核对", plan.day ? `设备日 ${deviceDay} / 消费日 ${plan.day}（${state.local.deviceTime.timeZoneIdentifier}）` : "需要补充消费日期", plan.day && plan.field !== "occurredAt" ? "done" : "waiting");
    addCheck("预算归属", plan.card?.name ?? (plan.attribution === "unbudgeted" ? "明确未纳入预算" : "需要选择或确认"), plan.card || plan.attribution ? "done" : "waiting");
    addCheck("所属周期", plan.period ? `${plan.period.startDay} — ${plan.period.endDay}` : plan.attribution === "unbudgeted" ? "不计入预算" : "按消费日期查找",
      ["outsidePeriod", "periodConflict", "retrospective", "unavailable"].includes(plan.stage) ? "blocked" : plan.period || plan.attribution ? "done" : "waiting");
    addCheck("币种与换算", plan.stage === "needsRate" ? "缺少可用报价，不能保存" : plan.stage === "confirmRate" ? "固定虚构报价，等待确认" : plan.ready ? "已核对" : "归属明确后再检查", plan.ready ? "done" : plan.stage === "needsRate" ? "blocked" : "waiting");
    addCheck("本地记录", state.saved ? "仅模拟完成，可撤销" : "未执行", state.saved ? "done" : "waiting");
  } else {
    addCheck("服务端候选", item.status === 200 ? "已校验字段" : "读取失败，保留输入", item.status === 200 ? "done" : "blocked");
    addCheck("本地门禁", "仍需本机选对象与确认");
  }
  document.querySelectorAll(".flow li").forEach((li) => li.removeAttribute("aria-current"));
  $(state.saved || plan?.ready ? "flow-save" : ["confirmRate", "needsRate"].includes(plan?.stage) ? "flow-rate"
    : plan?.field === "occurredAt" ? "flow-date" : "flow-card").setAttribute("aria-current", "step");
  $("explanation").textContent = item.action;
  $("json").textContent = JSON.stringify({ 服务端实际候选: item.candidate ?? { error: item.error },
    本机隔离门禁: plan ? { stage: plan.stage, cardID: plan.card?.id, periodID: plan.period?.id, ready: plan.ready, attribution: plan.attribution } : "本例不进入普通消费录入" }, null, 2);
  $("edit").hidden = !item.captureFlow || state.cancelled || !!state.saved;
  $("edit-date").value = plan?.day ?? "";
  $("edit-amount").value = state.draft.amount ?? "";
}

for (const group of [...new Set(cases.map((item) => item.group))]) {
  const details = node("details"), summary = node("summary", group), list = node("div", undefined, "case-list");
  details.open = group === "预算归属与周期";
  for (const item of cases.filter((entry) => entry.group === group)) {
    const element = node("button", item.label, "case-button"); element.type = "button"; element.dataset.case = item.id;
    element.addEventListener("click", () => choose(item)); list.append(element);
  }
  const optionGroup = node("optgroup"); optionGroup.label = group;
  for (const item of cases.filter((entry) => entry.group === group)) {
    const option = node("option", item.label); option.value = item.id; optionGroup.append(option);
  }
  $("mobile-cases").append(optionGroup);
  details.append(summary, list); $("case-groups").append(details);
}
$("mobile-cases").addEventListener("change", (event) => choose(cases.find((item) => item.id === event.target.value)));
$("reset").addEventListener("click", () => choose(state.item));
$("edit-form").addEventListener("submit", (event) => {
  event.preventDefault();
  state.draft = { ...state.draft, amount: $("edit-amount").value, occurredAt: $("edit-date").value };
  state.undoNotice = false; render();
});
if (location.protocol === "file:") {
  $("download").textContent = "独立 HTML · 可离线查看";
  $("download").removeAttribute("href"); $("download").removeAttribute("download");
}
choose(cases.find((item) => item.id === location.hash.slice(1)) ?? cases[0]);
