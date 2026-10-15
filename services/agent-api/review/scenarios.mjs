import { loadCases, makeFixtureProvider, requestFor } from "./fixtures.mjs";
import { interpret } from "../src/workflow.mjs";

const deviceTime = { timestamp: "2026-10-14T00:30:00Z", timeZoneIdentifier: "Asia/Shanghai" };
const period = (id, startDay, endDay, status = "active") => ({ id, startDay, endDay, status });
const food = () => ({ id: "food", name: "餐饮", currencyCode: "CNY", cycleType: "repeating",
  periods: [period("food-oct", "2026-10-01", "2026-10-31")] });
const travel = () => ({ id: "travel", name: "旅行", currencyCode: "CNY", cycleType: "oneShot",
  periods: [period("travel-oct", "2026-10-01", "2026-10-20")] });
const sampleQuote = { sourceAmount: "3.50", sourceCurrency: "USD", targetCurrency: "CNY",
  convertedAmount: "25.06", budgetID: "food", periodID: "food-oct",
  asOf: "2026-10-14T00:25:00Z", expiresAt: "2026-10-14T00:45:00Z", source: "固定虚构报价" };
const attributionIDs = ["relative-date", "expense", "card-entry", "guessed-budget", "unassigned", "multiple-cards",
  "duplicate-name", "entry-conflict", "outside-period", "past-period", "settled-period", "queued-period",
  "foreign-currency", "rate-unavailable", "relative-la"];

export function localStateFor(item) {
  const taskID = `review-${item.id}`;
  const local = { taskID, userMessage: item.input, deviceTime: structuredClone(item.context?.deviceTime ?? deviceTime), cards: [food()] };
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
  return local;
}

export async function makeReviewCases() {
  const cases = await loadCases(), provider = await makeFixtureProvider();
  const output = [];
  for (const item of cases) {
    let candidate, error, status;
    try { candidate = await interpret(requestFor(item), provider); status = 200; }
    catch (failure) { status = failure.status ?? 500; error = failure.code ?? "internal_error"; }
    const captureFlow = candidate?.intentType === "capture" || (item.modelCandidate?.intentType === "capture"
      && candidate?.intentType === "needsClarification" && candidate.clarificationField === "budgetName");
    output.push({ id: item.id, label: item.label, input: item.input, candidate, status, error,
      action: item.action, captureFlow, group: attributionIDs.includes(item.id) ? "预算归属与周期" : "其他任务与异常",
      local: localStateFor(item), ...(item.id === "rate-unavailable" ? { quoteOnRetry: structuredClone(sampleQuote) } : {}) });
  }
  return output.sort((a, b) => {
    const order = (item) => attributionIDs.includes(item.id) ? attributionIDs.indexOf(item.id) : 100;
    return order(a) - order(b);
  });
}
