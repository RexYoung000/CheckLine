import test from "node:test";
import assert from "node:assert/strict";
import { Script } from "node:vm";
import { makeReviewCases } from "../review/scenarios.mjs";
import { planCapture, calendarDay, attributionBasis } from "../review/capture-flow.mjs";
import { renderReview } from "../review/render.mjs";

const scenarios = await makeReviewCases();
const scenario = (id) => structuredClone(scenarios.find((item) => item.id === id));
const select = (draft, local, id) => ({ attribution: { basis: attributionBasis(draft, local), kind: "budget", id } });
const planFor = (item, answers) => planCapture(item.candidate, item.local, answers);

for (const [id, stage] of Object.entries({ "relative-date": "chooseBudget", expense: "ready", "card-entry": "ready",
  "guessed-budget": "chooseBudget", unassigned: "chooseBudget", "multiple-cards": "chooseBudget",
  "duplicate-name": "chooseBudget", "entry-conflict": "conflict", "outside-period": "outsidePeriod",
  "past-period": "ready", "settled-period": "retrospective", "queued-period": "ready",
  "foreign-currency": "chooseBudget", "rate-unavailable": "needsRate", "relative-la": "chooseBudget" })) {
  test(`review contract has a concrete gate for ${id}`, () => {
    const item = scenario(id), result = planFor(item);
    assert(item.captureFlow);
    assert.equal(result.stage, stage);
    assert.equal(result.ready, stage === "ready");
  });
}

test("one card is a question; a model guess cannot make it consent", () => {
  const item = scenario("guessed-budget"), before = planFor(item);
  assert.equal(item.candidate.budgetName, null);
  assert.match(before.prompt, /记到「餐饮」吗/);
  assert.equal(before.card, undefined);
  const after = planFor(item, select(item.candidate, item.local, "food"));
  assert.equal(after.ready, true);
  assert.equal(after.card.id, "food");
  assert.equal(after.period.id, "food-oct");
});

test("same-name options keep distinct local IDs and actual dates", () => {
  const item = scenario("duplicate-name"), before = planFor(item);
  assert.deepEqual(before.options.filter((option) => option.kind === "budget").map((option) => option.id), ["food", "travel"]);
  assert.notEqual(before.options[0].detail, before.options[1].detail);
  const after = planFor(item, select(item.candidate, item.local, "travel"));
  assert.equal(after.card.id, "travel"); assert.equal(after.period.id, "travel-oct");
});

test("an entry conflict requires a choice and then follows that card", () => {
  const item = scenario("entry-conflict");
  assert.equal(planFor(item).ready, false);
  assert.equal(planFor(item, select(item.candidate, item.local, "travel")).card.id, "travel");
  assert.equal(planFor(item, select(item.candidate, item.local, "food")).card.id, "food");
});

test("global focus and a different task's card entry do not supply attribution", () => {
  const item = scenario("card-entry");
  item.local.entry.origin = "globalFocus";
  assert.equal(planFor(item).stage, "chooseBudget");
  item.local.entry.origin = "card"; item.local.entry.taskID = "old-task";
  assert.equal(planFor(item).stage, "chooseBudget");
});

test("confirmed unbudgeted is explicit and has no target period", () => {
  const item = scenario("unassigned");
  const result = planFor(item, { attribution: { kind: "unbudgeted", basis: attributionBasis(item.candidate, item.local) } });
  assert.equal(result.ready, true); assert.equal(result.attribution, "unbudgeted");
  assert.equal(result.period, undefined); assert.equal(result.card, undefined);
});

test("no applicable budget offers unbudgeted without fabricating a period", () => {
  const item = scenario("unassigned"); item.local.cards = [];
  const result = planFor(item);
  assert.equal(result.ready, false); assert.equal(result.options.length, 1);
  assert.equal(result.options[0].kind, "unbudgeted");
});

test("a monthly gap rejects the named card but preserves the expense day", () => {
  const item = scenario("outside-period"), result = planFor(item);
  assert.equal(result.day, "2026-10-03"); assert.equal(result.ready, false);
  assert.equal(result.options.some((option) => option.id === "workday"), false);
  const after = planFor(item, select(item.candidate, item.local, "food"));
  assert.equal(after.ready, true); assert.equal(after.day, result.day);
});

test("yesterday at a month boundary resolves the old pending period, never today's queue", () => {
  const result = planFor(scenario("past-period"));
  assert.equal(result.day, "2026-09-30"); assert.equal(result.period.id, "food-sep");
  assert.equal(result.period.status, "pendingSettlement"); assert.equal(result.attribution, "confirmed");
});

test("queued expense explicitly targets the next period and not the unsettled one", () => {
  const result = planFor(scenario("queued-period"));
  assert.equal(result.period.id, "food-oct"); assert.equal(result.attribution, "queued");
  assert.match(result.prompt, /不计入.*旧期/);
});

test("a settled period is a hard stop for ordinary capture", () => {
  const result = planFor(scenario("settled-period"));
  assert.equal(result.period.id, "food-sep"); assert.equal(result.ready, false);
  assert.equal(result.stage, "retrospective"); assert.deepEqual(result.options, []);
});

test("overlapping periods never select the first one", () => {
  const item = scenario("expense");
  item.local.cards[0].periods.push({ id: "overlap", startDay: "2026-10-10", endDay: "2026-10-20", status: "active" });
  const result = planFor(item);
  assert.equal(result.stage, "periodConflict"); assert.equal(result.ready, false); assert.equal(result.period, undefined);
});

for (const change of ["date", "amount", "task", "settled", "deleted"]) {
  test(`a previous choice is invalid after ${change} changes`, () => {
    const item = scenario("unassigned"), answers = select(item.candidate, item.local, "food");
    assert.equal(planFor(item, answers).ready, true);
    if (change === "date") item.candidate.occurredAt = "2026-10-13";
    if (change === "amount") item.candidate.amount = "19";
    if (change === "task") item.local.taskID = "another-task";
    if (change === "settled") item.local.cards[0].periods[0].status = "settled";
    if (change === "deleted") item.local.cards[0].deleted = true;
    const after = planFor(item, answers);
    assert.equal(after.ready, false); assert.equal(after.card, undefined);
  });
}

test("FX cannot run before attribution; confirming quote binds both source and target", () => {
  const item = scenario("foreign-currency");
  assert.equal(planFor(item).quote, undefined);
  const answers = select(item.candidate, item.local, "food");
  const pending = planFor(item, answers);
  assert.equal(pending.stage, "confirmRate"); assert.equal(pending.ready, false);
  assert.equal(pending.amount, "3.50"); assert.equal(pending.currencyCode, "USD");
  assert.equal(pending.quote.convertedAmount, "25.06");
  answers.quoteToken = pending.quoteToken;
  assert.equal(planFor(item, answers).ready, true);
  item.local.quote.convertedAmount = "25.07";
  assert.equal(planFor(item, answers).stage, "confirmRate");
});

for (const change of ["sourceAmount", "sourceCurrency", "targetCurrency", "budgetID", "periodID", "expired", "future", "invalidDate", "zero"]) {
  test(`unusable FX (${change}) keeps original values and blocks saving`, () => {
    const item = scenario("foreign-currency"), answers = select(item.candidate, item.local, "food");
    if (change === "expired") item.local.quote.expiresAt = item.local.deviceTime.timestamp;
    else if (change === "future") item.local.quote.asOf = "2026-10-15T00:00:00Z";
    else if (change === "invalidDate") item.local.quote.asOf = "not-a-date";
    else if (change === "zero") item.local.quote.convertedAmount = "0.00";
    else item.local.quote[change] = "mismatch";
    const result = planFor(item, answers);
    assert.equal(result.stage, "needsRate"); assert.equal(result.ready, false);
    assert.equal(result.amount, "3.50"); assert.equal(result.currencyCode, "USD");
  });
}

test("retry needs a quote and confirmation; it never treats a missing quote as zero", () => {
  const item = scenario("rate-unavailable");
  assert.equal(planFor(item).stage, "needsRate");
  item.local.quote = item.quoteOnRetry;
  const quote = planFor(item);
  assert.equal(quote.stage, "confirmRate"); assert.equal(quote.ready, false);
  assert.equal(planFor(item, { quoteToken: quote.quoteToken }).ready, true);
});

test("missing currency and future dates ask, not silently default", () => {
  const item = scenario("expense"); delete item.candidate.currencyCode;
  assert.equal(planFor(item).field, "currencyCode");
  item.candidate.occurredAt = "2026-11-01";
  assert.equal(planFor(item).field, "occurredAt");
});

test("calendar routing follows device time zone and validates date-only input", () => {
  assert.equal(calendarDay("2026-10-14T00:30:00Z", "America/Los_Angeles"), "2026-10-13");
  assert.equal(calendarDay("2026-10-14T00:30:00Z", "Asia/Shanghai"), "2026-10-14");
  assert.equal(calendarDay("2026-02-31"), null);
  assert.equal(calendarDay("2026-10-14T00:30:00Z"), null);
});

test("standalone HTML embeds actual computed candidates and the shared executable gate", async () => {
  const html = await renderReview();
  assert(!html.includes("<!--REVIEW_"));
  const data = JSON.parse(html.match(/<script type="application\/json" id="review-data">([\s\S]*?)<\/script>/)[1]);
  assert.equal(data.length, 27);
  assert.equal(data.find((item) => item.id === "guessed-budget").candidate.budgetName, null);
  assert(!data.some((item) => Object.hasOwn(item, "expected") || Object.hasOwn(item, "modelCandidate")));
  assert(!/<script[^>]+src=|<link[^>]+href=|\bfetch\(/i.test(html));
  const script = html.match(/<script type="module">([\s\S]*?)<\/script>/)[1];
  assert(!/^\s*(?:import|export) /m.test(script));
  assert.doesNotThrow(() => new Script(script));
  assert(html.includes("function planCapture("));
});
