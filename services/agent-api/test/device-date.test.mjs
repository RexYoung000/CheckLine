import test from "node:test";
import assert from "node:assert/strict";
import { interpret } from "../src/workflow.mjs";
import { resolveConsumptionDay } from "../src/device-date.mjs";
import { requestFor } from "../review/fixtures.mjs";

const clock = (timestamp, timeZoneIdentifier) => ({ timestamp, timeZoneIdentifier });
for (const [label, input, timestamp, zone, expected] of [
  ["Shanghai after midnight", "昨天午餐35元", "2026-10-14T00:30:00Z", "Asia/Shanghai", "2026-10-12T16:00:00Z"],
  ["Los Angeles same instant", "yesterday lunch", "2026-10-14T00:30:00Z", "America/Los_Angeles", "2026-10-12T07:00:00Z"],
  ["UTC plus fourteen", "昨天午餐", "2026-10-14T00:30:00Z", "Pacific/Kiritimati", "2026-10-12T10:00:00Z"],
  ["quarter hour zone", "昨天午餐", "2026-10-14T00:30:00Z", "Asia/Kathmandu", "2026-10-12T18:15:00Z"],
  ["fixed offset", "昨天午餐", "2026-10-14T00:30:00Z", "+05:30", "2026-10-12T18:30:00Z"],
  ["new year", "昨天午餐", "2027-01-01T00:30:00Z", "UTC", "2026-12-31T00:00:00Z"],
  ["leap day", "昨天午餐", "2024-03-01T00:30:00Z", "Asia/Shanghai", "2024-02-28T16:00:00Z"],
  ["23 hour previous day", "昨天午餐", "2026-03-09T04:30:00Z", "America/New_York", "2026-03-08T05:00:00Z"],
  ["25 hour previous day", "昨天午餐", "2026-11-02T05:30:00Z", "America/New_York", "2026-11-01T04:00:00Z"],
  ["DST starts at midnight", "昨天午餐", "2026-09-07T03:30:00Z", "America/Santiago", "2026-09-06T04:00:00Z"],
  ["today", "今天午餐", "2026-10-14T00:30:00Z", "Asia/Shanghai", "2026-10-13T16:00:00Z"],
  ["two days ago", "前天午餐", "2026-10-14T00:30:00Z", "Asia/Shanghai", "2026-10-11T16:00:00Z"],
  ["English two days ago", "the day before yesterday lunch", "2026-10-14T00:30:00Z", "Asia/Shanghai", "2026-10-11T16:00:00Z"],
]) {
  test(`request calendar day: ${label}`, () => {
    assert.deepEqual(resolveConsumptionDay(input, clock(timestamp, zone)), { kind: "resolved", occurredAt: expected });
  });
}

for (const input of ["上周午餐35元", "昨天和今天午餐35元", "昨天到今天午餐35元", "明天午餐35元",
  "昨天2026-10-12午餐35元", "昨天18:00午餐35元", "昨天晚上午餐35元", "last week lunch", "last night lunch"]) {
  test(`unclear or more precise time still asks: ${input}`, () => {
    assert.deepEqual(resolveConsumptionDay(input, clock("2026-10-14T00:30:00Z", "Asia/Shanghai")), { kind: "clarify" });
  });
}

test("an absolute-only input does not invent a relative day", () => {
  assert.deepEqual(resolveConsumptionDay("2026-10-12午餐35元", undefined), { kind: "absent" });
});

test("a missing device clock never falls back to the server day", () => {
  assert.deepEqual(resolveConsumptionDay("昨天午餐35元", undefined), { kind: "clarify" });
});

test("a date skipped by a historical time zone change asks instead of inventing it", () => {
  assert.deepEqual(resolveConsumptionDay("昨天午餐", clock("2011-12-31T00:30:00Z", "Pacific/Apia")), { kind: "clarify" });
});

test("a delayed model response uses the clock captured when the user sent the message", async () => {
  const raw = requestFor({ input: "昨天午餐35元" });
  raw.context.deviceTime = clock("2026-10-13T15:59:59Z", "Asia/Shanghai");
  const result = await interpret(raw, { complete: async () => {
    // Simulate an unrelated date returned after the reference day; actual wall clock is irrelevant.
    return { intentType: "capture", amount: "35", currencyCode: "CNY", occurredAt: "2026-10-14" };
  } });
  assert.equal(result.occurredAt, "2026-10-11T16:00:00Z");
  assert.equal(result.amount, "35");
});

test("a known day can be retained while missing amount is asked separately", async () => {
  const raw = requestFor({ input: "昨天午餐" });
  raw.context.deviceTime = clock("2026-10-14T00:30:00Z", "Asia/Shanghai");
  const result = await interpret(raw, { complete: async () => ({ intentType: "capture", merchant: "午餐" }) });
  assert.equal(result.clarificationField, "amount");
  assert.equal(result.occurredAt, "2026-10-12T16:00:00Z");
});

test("the device clock is used by the workflow but never forwarded to the model", async () => {
  const raw = requestFor({ input: "昨天午餐35元" });
  raw.context.deviceTime = clock("2026-10-14T00:30:00Z", "Asia/Shanghai");
  const result = await interpret(raw, { complete: async (input) => {
    assert.equal(input.context.deviceTime, undefined);
    assert(!JSON.stringify(input).includes("2026-10-14T00:30:00Z"));
    assert(!JSON.stringify(input).includes("Asia/Shanghai"));
    return { intentType: "capture", amount: "35", currencyCode: "CNY" };
  } });
  assert.equal(result.occurredAt, "2026-10-12T16:00:00Z");
  assert.equal(raw.context.deviceTime.timeZoneIdentifier, "Asia/Shanghai");
});

for (const input of ["午餐35元，不是今天的，记到餐饮预算", "Lunch 35 CNY, not today",
  "午餐35元，并非昨天", "午餐35元，今天不对", "Lunch 35 CNY, today isn't right", "午餐35元，不是昨天而是今天",
  "午餐35元，不是2026-10-27", "午餐35元，2026-10-26或2026-10-27"]) {
  test(`a denied or contradictory day is not materialized: ${input}`, async () => {
    const raw = requestFor({ input });
    raw.context.deviceTime = clock("2026-10-28T04:00:00Z", "Asia/Shanghai");
    const result = await interpret(raw, { complete: async () => ({
      intentType: "capture", amount: "35", currencyCode: "CNY", merchant: "午餐", occurredAt: null,
    }) });
    assert.equal(result.intentType, "needsClarification");
    assert.equal(result.clarificationField, "occurredAt");
    assert.equal(result.requestedIntent, "capture");
    assert.equal(result.requiresDateReview, true);
    assert.equal(result.occurredAt, null);
    assert.equal(result.amount, "35");
  });
}

for (const [label, timestamp, zone, occurredAt, future] of [
  ["future absolute instant", "2026-10-28T04:00:00Z", "Asia/Shanghai", "2026-10-29T04:00:00Z", true],
  ["future civil day", "2026-10-28T04:00:00Z", "Asia/Shanghai", "2026-10-29", true],
  ["past ISO with fractional seconds", "2026-10-28T04:00:00Z", "Asia/Shanghai", "2026-10-27T04:00:00.123Z", false],
  ["past ISO with an offset", "2026-10-28T04:00:00Z", "Asia/Shanghai", "2026-10-27T13:30:00.125+08:00", false],
  ["same civil day", "2026-10-28T04:00:00Z", "Asia/Shanghai", "2026-10-28", false],
  ["same local day after midnight is still allowed", "2026-10-28T04:00:00Z", "Asia/Shanghai", "2026-10-28T23:30:00+08:00", false],
  ["date-only remains a civil day in Los Angeles", "2026-10-28T00:30:00Z", "America/Los_Angeles", "2026-10-28", true],
  ["instant is on next Shanghai day", "2026-10-28T15:00:00Z", "Asia/Shanghai", "2026-10-28T16:30:00.001Z", true],
  ["same instant is on current Los Angeles day", "2026-10-28T15:00:00Z", "America/Los_Angeles", "2026-10-28T16:30:00.001Z", false],
  ["DST short day compares civil dates", "2026-03-08T06:30:00Z", "America/New_York", "2026-03-09T04:00:00Z", true],
]) {
  test(`absolute date checks the request calendar: ${label}`, async () => {
    const raw = requestFor({ input: `${occurredAt}午餐35元，记到餐饮预算` });
    raw.context.deviceTime = clock(timestamp, zone);
    const result = await interpret(raw, { complete: async () => ({
      intentType: "capture", amount: "35", currencyCode: "CNY", budgetName: "餐饮", occurredAt,
    }) });
    if (future) {
      assert.equal(result.intentType, "needsClarification");
      assert.equal(result.clarificationField, "occurredAt");
      assert.equal(result.requestedIntent, "capture");
      assert.equal(result.requiresDateReview, true);
      assert.equal(result.occurredAt, null);
    } else {
      assert.equal(result.intentType, "capture");
      assert.equal(result.occurredAt, occurredAt);
      assert(!Object.hasOwn(result, "requiresDateReview"));
    }
  });
}

test("an absolute date without device reference asks instead of using the server clock", async () => {
  const result = await interpret(requestFor({ input: "2026-10-27午餐35元" }), {
    complete: async () => ({ intentType: "capture", amount: "35", occurredAt: "2026-10-27" }),
  });
  assert.equal(result.clarificationField, "occurredAt");
  assert.equal(result.occurredAt, null);
});

test("a date stated but not extracted cannot silently become today's expense", async () => {
  const raw = requestFor({ input: "2026-10-27午餐35元" });
  raw.context.deviceTime = clock("2026-10-28T04:00:00Z", "Asia/Shanghai");
  const result = await interpret(raw, { complete: async () => ({ intentType: "capture", amount: "35", occurredAt: null }) });
  assert.equal(result.clarificationField, "occurredAt");
  assert.equal(result.occurredAt, null);
});

test("a completely date-free expense keeps the existing date-free path", async () => {
  const result = await interpret(requestFor({ input: "午餐35元，记到餐饮预算" }), {
    complete: async () => ({ intentType: "capture", amount: "35", budgetName: "餐饮", occurredAt: null }),
  });
  assert.equal(result.intentType, "capture"); assert.equal(result.occurredAt, null);
  assert(!Object.hasOwn(result, "requiresDateReview"));
});

for (const input of ["午餐35元，不是今天的，不计入餐饮预算", "2026-10-29午餐35元，不放到餐饮预算"]) {
  test(`a budget question retains the unresolved date state: ${input}`, async () => {
    const raw = requestFor({ input });
    raw.context.deviceTime = clock("2026-10-28T04:00:00Z", "Asia/Shanghai");
    const result = await interpret(raw, { complete: async () => ({
      intentType: "capture", amount: "35", currencyCode: "CNY", merchant: "午餐", budgetName: "餐饮",
      occurredAt: input.startsWith("2026") ? "2026-10-29" : null,
    }) });
    assert.equal(result.intentType, "needsClarification");
    assert.equal(result.clarificationField, "budgetName");
    assert.equal(result.requestedIntent, "capture");
    assert.equal(result.budgetName, null); assert.equal(result.occurredAt, null);
    assert.equal(result.requiresDateReview, true);
    assert.equal(result.requiresBudgetReview, true);
    assert.equal(result.amount, "35"); assert.equal(result.merchant, "午餐");
  });
}
