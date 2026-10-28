import test from "node:test";
import assert from "node:assert/strict";
import { explicitBudgetNames } from "../src/budget-reference.mjs";
import { interpret } from "../src/workflow.mjs";
import { requestFor } from "../review/fixtures.mjs";

const cards = [{ name: "餐饮" }, { name: "旅行" }];
for (const text of ["午餐35元，记到餐饮预算", "记到「餐饮」", "餐饮卡花了35元", "午餐35元归入餐饮"]) {
  test(`a clear budget reference is reusable: ${text}`, () => assert.deepEqual(explicitBudgetNames(text, cards), ["餐饮"]));
}
for (const text of ["午餐35元", "昨天午餐35元", "咖啡18元", "需要午餐券", "不要记到餐饮卡", "别记到餐饮预算",
  "午餐35元，小票上写着餐饮卡", "午餐35元，朋友有餐饮预算"]) {
  test(`a description or negation is not selection: ${text}`, () => assert.deepEqual(explicitBudgetNames(text, cards), []));
}
test("escaped names and overlapping names do not select a shorter card", () => {
  assert.deepEqual(explicitBudgetNames("记到A+B(旅行)预算", [{ name: "A+B(旅行)" }]), ["A+B(旅行)"]);
  assert.deepEqual(explicitBudgetNames("记到旅行餐饮卡", [{ name: "餐饮" }, { name: "旅行餐饮" }]), ["旅行餐饮"]);
});
test("multiple explicit targets remain ambiguous instead of picking one", async () => {
  const request = requestFor({ input: "午餐35元，记到餐饮预算，或者记到旅行预算" });
  request.context.budgetCards.push({ name: "旅行", cycleType: "oneShot", currencyCode: "CNY" });
  const result = await interpret(request, { complete: async () => ({ intentType: "capture", amount: "35", budgetName: "餐饮" }) });
  assert.equal(result.clarificationField, "budgetName"); assert.equal(result.budgetName, null);
});
test("guessed attribution is removed even when amount or device date still needs asking", async () => {
  for (const input of ["午餐", "昨天午餐35元"]) {
    const result = await interpret(requestFor({ input }), {
      complete: async () => ({ intentType: "capture", ...(input.includes("35") ? { amount: "35" } : {}), budgetName: "餐饮" }),
    });
    assert.equal(result.intentType, "needsClarification"); assert.equal(result.budgetName, null);
  }
});
test("refund is not deletion regardless of model intent", async () => {
  for (const intentType of ["capture", "deleteExpense"]) {
    const result = await interpret(requestFor({ input: "午餐退款35元" }), { complete: async () => ({ intentType, amount: "35", currencyCode: "CNY" }) });
    assert.equal(result.intentType, "needsClarification"); assert.equal(result.clarificationField, "action");
    assert.equal(result.amount, "35");
  }
});

for (const input of [
  "午餐35元，不计入餐饮预算", "午餐35元，不放到餐饮预算", "午餐35元，并非记到餐饮预算",
  "午餐35元，并非餐饮预算", "午餐35元，不属于餐饮预算", "午餐35元，不要记到餐饮预算",
  "Lunch 35 CNY, not in 餐饮 budget",
]) {
  test(`a negated budget invalidates an earlier selection and asks: ${input}`, async () => {
    for (const budgetName of [null, "餐饮"]) {
      const result = await interpret(requestFor({ input }), {
        complete: async () => ({ intentType: "capture", amount: "35", currencyCode: "CNY", merchant: "午餐", budgetName }),
      });
      assert.equal(result.intentType, "needsClarification");
      assert.equal(result.clarificationField, "budgetName");
      assert.equal(result.requestedIntent, "capture");
      assert.equal(result.requiresBudgetReview, true);
      assert.equal(result.budgetName, null);
      assert.equal(result.amount, "35");
    }
  });
}

for (const input of [
  "午餐35元，不计入餐饮而记到旅行", "午餐35元，不放到餐饮预算，但记到旅行预算",
  "午餐35元，并非记到餐饮预算，而是记到旅行预算", "午餐35元，不是餐饮预算而是旅行预算",
  "Lunch 35 CNY, not in 餐饮 budget but in 旅行 budget",
]) {
  test(`negation stays within its target when another budget is explicitly selected: ${input}`, async () => {
    const request = requestFor({ input });
    request.context.budgetCards.push({ name: "旅行", cycleType: "oneShot", currencyCode: "CNY" });
    const result = await interpret(request, {
      complete: async () => ({ intentType: "capture", amount: "35", currencyCode: "CNY", budgetName: "餐饮" }),
    });
    assert.equal(result.intentType, "capture");
    assert.equal(result.budgetName, "旅行");
  });
}

for (const input of ["午餐35元，记到餐饮预算或旅行预算", "午餐35元，记到餐饮或旅行", "午餐35元，记到餐饮预算或未知预算",
  "午餐35元，记到餐饮预算，不是记到餐饮预算", "午餐35元，不计入不存在的预算"]) {
  test(`alternative, conflicting or unresolved negative targets require a fresh selection: ${input}`, async () => {
    const request = requestFor({ input });
    request.context.budgetCards.push({ name: "旅行", cycleType: "oneShot", currencyCode: "CNY" });
    const result = await interpret(request, { complete: async () => ({ intentType: "capture", amount: "35", budgetName: "餐饮" }) });
    assert.equal(result.clarificationField, "budgetName");
    assert.equal(result.requestedIntent, "capture");
    assert.equal(result.budgetName, null);
  });
}

test("a negation unrelated to the selected budget does not invalidate it", async () => {
  const result = await interpret(requestFor({ input: "不太饿，午餐35元，记到餐饮预算" }), {
    complete: async () => ({ intentType: "capture", amount: "35", budgetName: null }),
  });
  assert.equal(result.intentType, "capture"); assert.equal(result.budgetName, "餐饮");
});
