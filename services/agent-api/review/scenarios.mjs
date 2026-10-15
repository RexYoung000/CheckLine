import { loadCases, makeFixtureProvider, requestFor } from "./fixtures.mjs";
import { interpret } from "../src/workflow.mjs";

const deviceTime = { timestamp: "2026-10-14T00:30:00Z", timeZoneIdentifier: "Asia/Shanghai" };
const period = (id, startDay, endDay, status = "active") => ({ id, startDay, endDay, status,
  budgetAmount: "1000", spent: status === "settled" || status === "pendingSettlement" ? "700" : "300", pendingCount: 0 });
const food = () => ({ id: "food", name: "餐饮", currencyCode: "CNY", cycleType: "repeating",
  periods: [period("food-oct", "2026-10-01", "2026-10-31")] });
const travel = () => ({ id: "travel", name: "旅行", currencyCode: "CNY", cycleType: "oneShot",
  periods: [period("travel-oct", "2026-10-01", "2026-10-20")] });
const sampleQuote = { sourceAmount: "3.50", sourceCurrency: "USD", targetCurrency: "CNY",
  convertedAmount: "25.06", rate: "7.16", budgetID: "food", periodID: "food-oct",
  asOf: "2026-10-14T00:25:00Z", expiresAt: "2026-10-14T00:45:00Z", source: "固定虚构报价" };
const attributionIDs = ["relative-date", "expense", "card-entry", "guessed-budget", "unassigned", "multiple-cards",
  "duplicate-name", "entry-conflict", "outside-period", "past-period", "settled-period", "queued-period",
  "foreign-currency", "rate-unavailable", "relative-la"];

export function localStateFor(item) {
  const taskID = `review-${item.id}`;
  const local = { taskID, userMessage: item.input, deviceTime: structuredClone(item.context?.deviceTime ?? deviceTime), cards: [food()] };
  local.wallet = { currencyCode: "CNY", balance: "1280", recoveryGap: "0" };
  local.expenses = [{ id: "lunch-yesterday", merchant: "午餐", amount: item.id.startsWith("refund") ? "50" : "35",
    currencyCode: "CNY", day: "2026-10-13", budgetID: "food", periodID: "food-oct", refunded: "0", kind: "purchase" }];
  local.wishes = [{ id: "headphones", name: "耳机", amount: "399", currencyCode: "CNY" }];
  if (item.id === "correction") local.activeDraft = { amount: "35", currencyCode: "CNY", merchant: "午餐", occurredAt: "2026-10-13" };
  if (["multiple-cards", "entry-conflict"].includes(item.id)) local.cards.push(travel());
  if (["card-entry", "entry-conflict"].includes(item.id)) local.entry = { taskID, origin: "card", budgetID: "food" };
  if (item.id === "duplicate-name") local.cards.push({ ...travel(), name: "餐饮" });
  if (item.id === "outside-period") local.cards.unshift({ id: "workday", name: "工作日", currencyCode: "CNY", cycleType: "repeating",
    periods: [period("work-oct", "2026-10-05", "2026-10-20")] });
  if (item.id === "settled-period") local.cards[0].periods.unshift(period("food-sep", "2026-09-01", "2026-09-30", "settled"));
  if (["past-period", "queued-period"].includes(item.id)) {
    local.cards[0].periods[0].status = "queued";
    local.cards[0].periods.unshift(period("food-sep", "2026-09-01", "2026-09-30", "pendingSettlement"));
  }
  if (item.id === "foreign-currency") local.quote = structuredClone(sampleQuote);
  if (item.id === "late-expense") {
    local.cards[0].periods.unshift(period("food-sep", "2026-09-01", "2026-09-30", "settled"));
    local.expenses = [{ id: "late-lunch", merchant: "午餐", amount: "35", currencyCode: "CNY", day: "2026-09-29", kind: "purchase", refunded: "0" }];
  }
  return local;
}

function taskKind(item, candidate) {
  if (item.id.startsWith("refund")) return "refund";
  if (item.id === "correction") return "amendment";
  if (item.id === "wish") return "plannedWish";
  if (item.id === "multiple") return "split";
  return candidate?.requestedIntent ?? candidate?.intentType ?? "capture";
}

function caseGroup(kind) {
  if (["createBudget", "queryBudgetStatus", "adjustPeriodAmount", "settlePeriod", "plannedWish", "createWish", "redeemWish"].includes(kind)) return "预算与心愿";
  if (["refund", "amendment", "deleteExpense", "lateExpense"].includes(kind)) return "修改与退款";
  if (["outOfScope", "recommendPurchase"].includes(kind)) return "边界与恢复";
  return "记录与归属";
}

export async function makeReviewCases() {
  const cases = await loadCases(), provider = await makeFixtureProvider();
  const output = [];
  for (const item of cases) {
    let candidate, error, status;
    try { candidate = await interpret(requestFor(item), provider); status = 200; }
    catch (failure) { status = failure.status ?? 500; error = failure.code ?? "internal_error"; }
    const kind = taskKind(item, candidate);
    const captureFlow = kind === "capture";
    output.push({ id: item.id, label: item.label, input: item.input, candidate, status, error,
      kind, action: item.action, captureFlow, group: status === 200 ? caseGroup(kind) : "边界与恢复",
      local: localStateFor(item), ...(item.id === "rate-unavailable" ? { quoteOnRetry: structuredClone(sampleQuote) } : {}) });
  }
  for (const [id, label, baseID, setup] of [
    ["refund-multiple", "退款匹配多条", "refund", (c) => c.local.expenses.push({ ...c.local.expenses[0], id: "lunch-today", day: "2026-10-14", amount: "35" })],
    ["refund-none", "退款没有匹配", "refund", (c) => c.local.expenses[0].merchant = "晚餐"],
    ["refund-settled", "已结算消费退款", "refund", (c) => { c.local.cards[0].periods.unshift(period("food-sep", "2026-09-01", "2026-09-30", "settled")); c.local.expenses[0].periodID = "food-sep"; c.local.expenses[0].day = "2026-09-29"; }],
    ["settlement-due", "到期结算确认", "settlement", (c) => c.local.cards[0].periods.unshift(period("food-sep", "2026-09-01", "2026-09-30", "pendingSettlement"))],
    ["settlement-pending", "结算内处理待确认", "settlement", (c) => { c.local.cards[0].periods.unshift(period("food-sep", "2026-09-01", "2026-09-30", "pendingSettlement")); c.local.cards[0].periods[0].pendingCount = 1; Object.assign(c.local.expenses[0],{periodID:'food-sep',day:'2026-09-29',pending:true}); }],
    ["wish-insufficient", "心愿余额不足", "redeem-wish", (c) => c.local.wallet.balance = "100"],
    ["quote-expired", "报价失效后恢复", "foreign-currency", (c) => c.local.quote.expiresAt = "2026-10-13T00:00:00Z"],
    ["save-failure", "保存失败后重试", "expense", (c) => c.fault = "saveBefore"],
    ["saved-interruption", "保存后响应中断", "expense", (c) => c.fault = "saveAfter"],
    ["attachment-partial", "附件部分失败", "expense", (c) => c.fault = "attachments"],
    ["auth-expired", "认证失效后恢复", "timeout", (c) => { c.status = 401; c.error = "unauthorized"; c.fault = "authentication"; }],
    ["rate-limited", "限流后恢复", "timeout", (c) => { c.status = 429; c.error = "rate_limited"; c.fault = "rateLimit"; }],
    ["offline", "断网时手动接管", "timeout", (c) => { c.status = 503; c.error = "model_unavailable"; }],
    ["cancel-request", "取消处理中请求", "timeout", (c) => c.delay = 1200],
  ]) {
    const item = structuredClone(output.find((entry) => entry.id === baseID));
    Object.assign(item, { id, label, injected: true });
    item.local.taskID = `review-${id}`;
    if (item.local.entry) item.local.entry.taskID = item.local.taskID;
    setup(item); output.push(item);
  }
  for (const item of output) {
    if (item.fault) item.group = "边界与恢复";
    if (item.status !== 200) item.recoveryCandidate = { intentType: "capture", amount: item.id === "bad-output" ? "12" : "42",
      currencyCode: "CNY", merchant: item.id === "bad-output" ? "早餐" : "晚餐", budgetName: "餐饮" };
    item.designOnly = ["refund", "amendment", "split", "lateExpense"].includes(item.kind);
  }
  return output.sort((a, b) => {
    const order = (item) => attributionIDs.includes(item.id) ? attributionIDs.indexOf(item.id) : 100;
    return order(a) - order(b);
  });
}
