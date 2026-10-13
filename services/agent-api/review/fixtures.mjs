import { readFile } from "node:fs/promises";
import { WorkflowError } from "../src/contract.mjs";

export const DEFAULT_CONTEXT = {
  budgetCards: [{ name: "餐饮", cycleType: "repeating", currencyCode: "CNY" }],
  recentMerchants: [], tagNames: [],
};

export const loadCases = () => readFile(new URL("./cases.json", import.meta.url), "utf8").then(JSON.parse);
export const requestFor = (item) => ({ system: "client compatibility prompt",
  userMessage: item.input, context: structuredClone(item.context ?? DEFAULT_CONTEXT) });

export async function makeFixtureProvider() {
  const cases = await loadCases();
  return {
    async complete(input) {
      const item = cases.find((entry) => entry.input === input.userMessage);
      if (item?.modelError) throw new WorkflowError(item.modelError.code, item.modelError.status, item.modelError.retryable);
      return structuredClone(item?.modelCandidate ?? { intentType: "needsClarification", clarificationField: "input" });
    },
  };
}
