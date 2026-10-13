import test from "node:test";
import assert from "node:assert/strict";
import { makeDeepSeekProvider, DEEPSEEK_ENDPOINT } from "../src/deepseek.mjs";
import { SYSTEM_PROMPT } from "../src/workflow.mjs";

const envelope = (content = '{"intentType":"capture","amount":"35"}', extra = {}) => ({
  choices: [{ finish_reason: "stop", message: { content, reasoning_content: "private reasoning", ...extra } }],
});
const input = { userMessage: "synthetic text", context: { budgetCards: [], recentMerchants: [], tagNames: [] } };

test("fixed official model, normal thinking, JSON output, no tools or key in body", async () => {
  let observed;
  const provider = makeDeepSeekProvider({ apiKey: "synthetic-private-key", fetcher: async (url, init) => {
    observed = { url, init, body: JSON.parse(init.body) }; return Response.json(envelope());
  } });
  const result = await provider.complete(input);
  assert.equal(observed.url, DEEPSEEK_ENDPOINT);
  assert.equal(observed.init.headers.Authorization, "Bearer synthetic-private-key");
  assert.equal(observed.init.redirect, "error");
  assert.equal(observed.body.model, "deepseek-flash");
  assert.equal(observed.body.reasoning_effort, "high");
  assert.deepEqual(observed.body.thinking, { type: "enabled" });
  assert.deepEqual(observed.body.response_format, { type: "json_object" });
  assert.equal(observed.body.messages[0].content, SYSTEM_PROMPT);
  assert.deepEqual(JSON.parse(observed.body.messages[1].content), input);
  assert(!Object.hasOwn(observed.body, "tools"));
  assert(!Object.hasOwn(observed.body, "temperature"));
  assert(!observed.init.body.includes("synthetic-private-key"));
  assert.deepEqual(result, { intentType: "capture", amount: "35" });
});

for (const [label, value] of [
  ["empty", envelope("")], ["prose", envelope("Here is the result")],
  ["tool", envelope("{}", { tool_calls: [{ id: "tool" }] })],
  ["truncated", { choices: [{ finish_reason: "length", message: { content: "{}" } }] }],
  ["missing choice", {}],
]) {
  test(`invalid model envelope: ${label}`, async () => {
    const provider = makeDeepSeekProvider({ apiKey: "synthetic", fetcher: async () => Response.json(value) });
    await assert.rejects(() => provider.complete(input), { code: "invalid_model_output" });
  });
}

test("upstream error never exposes third party body", async () => {
  const provider = makeDeepSeekProvider({ apiKey: "synthetic", fetcher: async () =>
    new Response("private raw text and credentials", { status: 429 }) });
  await assert.rejects(() => provider.complete(input), (error) =>
    error.code === "model_unavailable" && !error.message.includes("private"));
});

test("bounded timeout cancels upstream; no automatic retry", async () => {
  let calls = 0;
  const provider = makeDeepSeekProvider({ apiKey: "synthetic", timeoutMs: 10, fetcher: async (_url, init) => {
    ++calls;
    return new Promise((_resolve, reject) => init.signal.addEventListener("abort", () => reject(init.signal.reason), { once: true }));
  } });
  // Keep the event loop alive while AbortSignal's unref timer is pending.
  const alive = setTimeout(() => {}, 1000);
  try { await assert.rejects(() => provider.complete(input), { code: "model_timeout", status: 504 }); }
  finally { clearTimeout(alive); }
  assert.equal(calls, 1);
});

test("caller cancellation reaches upstream and remains recoverable", async () => {
  const controller = new AbortController();
  const provider = makeDeepSeekProvider({ apiKey: "synthetic", fetcher: async (_url, init) => {
    controller.abort();
    assert(init.signal.aborted);
    throw init.signal.reason;
  } });
  await assert.rejects(() => provider.complete(input, controller.signal), { code: "model_unavailable" });
});

test("oversized upstream output is rejected without returning body", async () => {
  const provider = makeDeepSeekProvider({ apiKey: "synthetic", fetcher: async () => new Response("x".repeat(70_000)) });
  await assert.rejects(() => provider.complete(input), { code: "invalid_model_output" });
});
