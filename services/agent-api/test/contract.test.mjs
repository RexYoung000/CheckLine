import test from "node:test";
import assert from "node:assert/strict";
import { requestFor } from "../review/fixtures.mjs";
import { validateRequest, validateCandidate, modelCandidateSchema, matches } from "../src/contract.mjs";

const request = () => requestFor({ input: "  午餐35元\n" });

test("advertised clarification field choices agree with actual model validation", () => {
  for (const clarificationField of ["input", "action", "amount", "occurredAt", null]) {
    const candidate = { intentType: "needsClarification", clarificationField };
    assert.equal(matches(modelCandidateSchema, candidate), true);
    assert.doesNotThrow(() => validateCandidate(candidate, true));
  }
  for (const clarificationField of ["input/action", "transaction", "requestedIntent", "requiresDateReview"]) {
    const candidate = { intentType: "needsClarification", clarificationField };
    assert.equal(matches(modelCandidateSchema, candidate), false);
    assert.throws(() => validateCandidate(candidate, true), { code: "invalid_model_output" });
  }
});
test("request preserves exact original text and contains no exported ledger values", () => {
  const raw = request();
  assert.equal(validateRequest(raw).userMessage, "  午餐35元\n");
  assert.deepEqual(Object.keys(raw.context).sort(), ["budgetCards", "recentMerchants", "tagNames"]);
});

test("device time adds only a timestamp and time zone; legacy requests remain valid", () => {
  validateRequest(request());
  const raw = request();
  raw.context.deviceTime = { timestamp: "2026-10-14T00:30:00Z", timeZoneIdentifier: "Asia/Shanghai" };
  assert.equal(validateRequest(raw).context.deviceTime.timeZoneIdentifier, "Asia/Shanghai");
});

for (const deviceTime of [
  null, { timestamp: "2026-10-14" },
  { timestamp: "2026-02-31T00:30:00Z", timeZoneIdentifier: "Asia/Shanghai" },
  { timestamp: "2026-10-14T25:00:00Z", timeZoneIdentifier: "Asia/Shanghai" },
  { timestamp: "2026-10-14T00:30:00", timeZoneIdentifier: "Asia/Shanghai" },
  { timestamp: "2026-10-14T00:30:00Z", timeZoneIdentifier: "made/up" },
  { timestamp: "2026-10-14T00:30:00Z", timeZoneIdentifier: "Asia/Shanghai", deviceID: "not-allowed" },
]) {
  test(`invalid device clock is rejected before model use: ${JSON.stringify(deviceTime)}`, () => {
    const raw = request(); raw.context.deviceTime = deviceTime;
    assert.throws(() => validateRequest(raw), { code: "invalid_request", status: 400 });
  });
}

for (const mutate of [
  (r) => { r.ledger = {}; }, (r) => { r.context.walletBalance = "100"; },
  (r) => { r.context.budgetCards[0].amount = "1000"; }, (r) => { r.tools = []; },
  (r) => { r.context.recentMerchants = Array(11).fill("Cafe"); },
  (r) => { r.userMessage = "   "; }, (r) => { r.context = null; },
  (r) => { r.model = "client-selected-model"; }, (r) => { r.upstream = "https://example.invalid"; },
]) {
  test(`reject unsafe request ${mutate.toString().slice(0, 65)}`, () => {
    const raw = request(); mutate(raw);
    assert.throws(() => validateRequest(raw), { code: "invalid_request" });
  });
}

test("amount remains a string with original decimal digits", () => {
  const candidate = { intentType: "capture", amount: "3.50", currencyCode: "USD" };
  assert.deepEqual(validateCandidate(candidate), candidate);
});

for (const candidate of [
  { intentType: "capture", amount: 35 }, { intentType: "capture", amount: "1e3" },
  { intentType: "capture", remaining: "500" }, { intentType: "unknownAction" },
  { intentType: "capture", periodID: "ca844d7b-e3a6-478a-877f-e07e86f02afc" },
  { intentType: "capture", currencyCode: "元" },
  { intentType: "capture", occurredAt: "2026-02-31" },
  { intentType: "capture", occurredAt: "2026-13-03" },
  { intentType: "createBudget", monthlySchedule: { kind: "window", startDay: 0, endDay: 20 } },
  { intentType: "createBudget", monthlySchedule: { kind: "window", startDay: 5.5, endDay: 20 } },
  { intentType: "needsClarification", clarificationField: "runShell" },
]) {
  test(`reject invalid or fabricated candidate ${JSON.stringify(candidate)}`, () => {
    assert.throws(() => validateCandidate(candidate), { code: "invalid_model_output" });
  });
}

test("valid leap date, ISO timestamp and monthly dates survive validation", () => {
  validateCandidate({ intentType: "capture", occurredAt: "2024-02-29T13:30:00+08:00" });
  validateCandidate({ intentType: "createBudget", monthlySchedule: { kind: "cycle", startDay: 31, endDay: 31 } });
});

test("optional review metadata remains compatible and typed", () => {
  validateCandidate({ intentType: "capture" });
  for (const key of ["requiresDateReview", "requiresBudgetReview"]) {
    for (const value of [true, false, null]) validateCandidate({ intentType: "needsClarification", [key]: value });
    for (const value of ["true", 1]) {
      assert.throws(() => validateCandidate({ intentType: "capture", [key]: value }), { code: "invalid_model_output" });
    }
  }
});
