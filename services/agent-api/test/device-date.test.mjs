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
