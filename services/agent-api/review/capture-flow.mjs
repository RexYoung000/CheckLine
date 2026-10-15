import { explicitBudgetNames } from "../src/budget-reference.mjs";

// Executable review contract for the future LOCAL App gate. Never called by the live API.
// All money values are supplied decimal strings; this module does no monetary arithmetic.
export function calendarDay(value, timeZone) {
  if (!value) return null;
  const date = new Date(value);
  if (!Number.isFinite(date.valueOf())) return null;
  if (/^\d{4}-\d{2}-\d{2}$/.test(value)) return date.toISOString().slice(0, 10) === value ? value : null;
  if (!timeZone) return null;
  try {
    const parts = new Intl.DateTimeFormat("en", { timeZone, year: "numeric", month: "2-digit", day: "2-digit" })
      .formatToParts(date);
    const part = (type) => parts.find((item) => item.type === type).value;
    return `${part("year")}-${part("month")}-${part("day")}`;
  } catch { return null; }
}

export function moneyLabel(amount, currency) {
  const unit = { CNY: "元", USD: "美元", HKD: "港元", JPY: "日元", EUR: "欧元", GBP: "英镑" }[currency];
  return unit ? `${amount ?? "—"}${unit}` : `${amount ?? "—"} ${currency ?? "（待选币种）"}`;
}

export function attributionBasis(draft, local) {
  // Any edit, task switch, or card/period mutation invalidates a previous answer.
  return JSON.stringify({ taskID: local.taskID, draft, cards: local.cards, entry: local.entry,
    deviceTime: local.deviceTime });
}

function periodsOn(card, day) {
  return card.periods.filter((period) => calendarDay(period.startDay) === period.startDay
    && calendarDay(period.endDay) === period.endDay && period.startDay <= day && day <= period.endDay);
}

function cardOption(card, day) {
  const periods = periodsOn(card, day);
  return { kind: "budget", id: card.id, label: card.name,
    detail: `${card.cycleType === "oneShot" ? "一次性" : "循环"} · ${card.currencyCode} · ` +
      (periods.length === 1 ? `${periods[0].startDay} — ${periods[0].endDay}` : "需核对周期") };
}

const unbudgetedOption = { kind: "unbudgeted", label: "未纳入预算", detail: "保留消费，不扣任何预算卡" };

export function planCapture(draft, local, answers = {}) {
  const basis = attributionBasis(draft, local);
  const today = calendarDay(local.deviceTime?.timestamp, local.deviceTime?.timeZoneIdentifier);
  const day = calendarDay(draft.occurredAt ?? local.deviceTime?.timestamp, local.deviceTime?.timeZoneIdentifier);
  const base = { basis, day, amount: draft.amount, currencyCode: draft.currencyCode,
    merchant: draft.merchant, ready: false, options: [] };
  const result = (stage, prompt, extra = {}) => ({ ...base, stage, prompt, ...extra });
  const input = (field, prompt) => result("input", prompt, { field });
  if (!/^\d+(?:\.\d+)?$/.test(draft.amount ?? "") || !/[1-9]/.test(draft.amount)) return input("amount", "这笔花了多少？");
  if (draft.isMultiItem) return input("input", "这里有多笔消费，我们先核对其中一笔。金额和描述分别是什么？");
  if (!day || !today || day > today) return input("occurredAt", "这笔是哪一天的消费？");

  const cards = local.cards.filter((card) => !card.deleted);
  const eligible = cards.filter((card) => {
    const periods = periodsOn(card, day);
    return periods.length === 1 && ["active", "pendingSettlement", "queued"].includes(periods[0].status);
  });
  const options = eligible.map((card) => cardOption(card, day)).concat([unbudgetedOption]);
  const choice = answers.attribution?.basis === basis ? answers.attribution : null;
  const explicitNames = explicitBudgetNames(local.userMessage, cards);
  const named = cards.filter((card) => explicitNames.includes(card.name));
  // Only a current task's real card entry can supply default attribution; root focus cannot.
  const entry = local.entry?.taskID === local.taskID && local.entry.origin === "card"
    ? cards.find((card) => card.id === local.entry.budgetID) : null;
  let card, origin;
  if (choice?.kind === "unbudgeted") {
    if (!draft.currencyCode) return input("currencyCode", "这笔用的是什么币种？");
    return result("ready", "这笔不纳入预算，保留消费记录。", { ready: true, attribution: "unbudgeted", origin: "用户选择" });
  }
  if (choice?.kind === "budget") {
    card = cards.find((item) => item.id === choice.id);
    if (!card) return result("chooseBudget", "这张卡已不可用，请重新选择。", { options });
    origin = "用户选择";
  } else if (named.length > 0 && entry && !named.some((item) => item.id === entry.id)) {
    return result("conflict", `你从「${entry.name}」进入，但这次点名了其他预算。这笔记到哪里？`,
      { options: [entry, ...named].map((item) => cardOption(item, day)).concat([unbudgetedOption]) });
  } else if (named.length === 1) {
    card = named[0]; origin = "原文明确点名";
  } else if (named.length > 1) {
    return result("chooseBudget", "有多张符合的预算卡，这笔记到哪一张？",
      { options: named.map((item) => cardOption(item, day)).concat([unbudgetedOption]) });
  } else if (entry) {
    card = entry; origin = "卡内入口";
  } else {
    const prompt = eligible.length === 1 ? `这笔 ${moneyLabel(draft.amount, draft.currencyCode)} 记到「${eligible[0].name}」吗？`
      : eligible.length > 1 ? "这笔消费记到哪张预算卡？" : `${day} 没有适用的预算周期，要先保留为未纳入预算吗？`;
    return result("chooseBudget", prompt, { options });
  }

  const periods = periodsOn(card, day);
  const target = { card: { id: card.id, name: card.name, currencyCode: card.currencyCode }, origin };
  if (periods.length !== 1) {
    return result(periods.length > 1 ? "periodConflict" : "outsidePeriod",
      periods.length > 1 ? `「${card.name}」的周期有重叠，暂时不能录入。请选择其他预算或稍后处理。`
        : `${day} 不在「${card.name}」的有效区间内。这笔改记到哪里？`,
      { ...target, options: options.filter((option) => option.id !== card.id) });
  }
  const period = periods[0];
  if (period.status === "settled") return result("retrospective", `${day} 属于已结算周期，需先核对追溯影响。`,
    { ...target, period, options: [], note: "不能改记当前期，也不能在这里作为普通消费保存。" });
  if (!["active", "pendingSettlement", "queued"].includes(period.status)) {
    return result("unavailable", "这期预算已不可用，请重新选择。", { ...target, period, options });
  }
  const bound = { ...target, period, attribution: period.status === "queued" ? "queued" : "confirmed" };
  if (!draft.currencyCode) return result("input", "这笔用的是什么币种？", { ...bound, field: "currencyCode" });

  if (draft.currencyCode !== card.currencyCode) {
    const quote = local.quote;
    const valid = quote && quote.sourceAmount === draft.amount && quote.sourceCurrency === draft.currencyCode
      && quote.targetCurrency === card.currencyCode && quote.budgetID === card.id && quote.periodID === period.id
      && /^\d+(?:\.\d+)?$/.test(quote.convertedAmount) && /[1-9]/.test(quote.convertedAmount)
      && Date.parse(quote.asOf) <= Date.parse(local.deviceTime.timestamp)
      && Date.parse(local.deviceTime.timestamp) < Date.parse(quote.expiresAt);
    if (!valid) return result("needsRate", `原币 ${moneyLabel(draft.amount, draft.currencyCode)} 已保留，暂时没有可用的 ${card.currencyCode} 换算依据。`,
      { ...bound, note: "尚未计入预算。可以重试换算，或继续修改这笔。" });
    const quoteToken = JSON.stringify({ basis, quote });
    if (answers.quoteToken !== quoteToken) return result("confirmRate", `按 ${moneyLabel(quote.convertedAmount, card.currencyCode)} 记到「${card.name}」吗？`,
      { ...bound, quote, quoteToken, note: "固定虚构报价，仅演示确认顺序；原币仍保留。" });
    return result("ready", "换算与归属已核对。", { ...bound, quote, ready: true });
  }
  return result("ready", period.status === "queued" ? "这笔进入下周期队列，不计入待结算的旧期。" : "归属明确，可以记录并立即提供撤销。",
    { ...bound, ready: true });
}
