import test from "node:test";
import assert from "node:assert/strict";
import { once } from "node:events";
import { setTimeout as pause } from "node:timers/promises";
import { makeServer, loadConfig } from "../src/server.mjs";
import { makeFixtureProvider, loadCases, requestFor } from "../review/fixtures.mjs";

const token = "synthetic-very-long-private-review-token";
const base = { host: "127.0.0.1", token, demo: false, maxRequests: 999, maxConcurrent: 2 };
async function withServer(options, run) {
  const logs = [];
  const server = makeServer({ config: { ...base, ...options.config }, provider: options.provider,
    logger: (event) => logs.push(event), ...(options.clock ? { clock: options.clock } : {}) });
  server.listen(0, "127.0.0.1"); await once(server, "listening");
  const url = "http://127.0.0.1:" + server.address().port;
  const send = (body = requestFor({ input: "午餐 35 元，记到餐饮预算" }), extra = {}) => fetch(url + "/v1/agent/interpret", {
    method: "POST", headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}`, ...extra.headers },
    body: JSON.stringify(body), ...Object.fromEntries(Object.entries(extra).filter(([key]) => key !== "headers")),
  });
  try { await run({ url, send, logs, server }); }
  finally { server.closeAllConnections(); await new Promise((resolve) => server.close(resolve)); }
}

test("real local HTTP covers all fixed scenarios and marks candidates as demo", async () => {
  await withServer({ config: { demo: true }, provider: await makeFixtureProvider() }, async ({ send }) => {
    for (const item of await loadCases()) {
      const response = await send(requestFor(item));
      assert.equal(response.status, item.status, item.id);
      assert.equal(response.headers.get("X-CheckLine-Mode"), "demonstration");
      assert.equal(response.headers.get("X-CheckLine-Contract"), "1");
      assert.equal(response.headers.get("Cache-Control"), "no-store");
      const body = await response.json();
      if (item.expectedError) assert.equal(body.error.code, item.expectedError);
      else assert.deepEqual(body, item.expected);
    }
  });
});

test("auth, invalid fields and media types fail before any model call", async () => {
  let calls = 0;
  const provider = { complete: async () => { ++calls; return { intentType: "capture", amount: "35" }; } };
  await withServer({ provider }, async ({ send }) => {
    assert.equal((await send(undefined, { headers: { Authorization: "Bearer wrong" } })).status, 401);
    const raw = requestFor({ input: "text" }); raw.context.wallet = "100";
    assert.equal((await send(raw)).status, 400);
    assert.equal((await send(undefined, { headers: { "Content-Type": "text/plain" } })).status, 415);
    assert.equal((await send(undefined, { body: "not-json" })).status, 400);
    assert.equal(calls, 0);
  });
});

test("health is readiness only, live review stays unavailable, logs contain metadata only", async () => {
  await withServer({ provider: { complete: async () => ({ intentType: "capture", amount: "135.79", merchant: "PrivateCafe" }) } },
    async ({ url, send, logs }) => {
      assert.equal((await fetch(url + "/health")).status, 200);
      assert.equal((await fetch(url + "/review")).status, 404);
      const response = await send(requestFor({ input: "PrivateCafe 135.79" }), { headers: { "X-Request-ID": "private-input" } });
      assert.match(response.headers.get("X-Request-ID"), /^[0-9a-f-]{36}$/);
      await response.json();
      assert(logs.every((event) => Object.keys(event).sort().join() === "durationMs,requestID,status"));
      const serialized = JSON.stringify(logs);
      for (const privateValue of [token, "PrivateCafe", "135.79", "private-input"]) assert(!serialized.includes(privateValue));
    });
});

test("request body ceiling rejects known and chunked oversized bodies", async () => {
  let calls = 0;
  await withServer({ provider: { complete: async () => { ++calls; return { intentType: "outOfScope" }; } } }, async ({ send, url }) => {
    assert.equal((await send(undefined, { body: "x".repeat(17_000) })).status, 413);
    const stream = new ReadableStream({ start(controller) { controller.enqueue(new TextEncoder().encode("x".repeat(17_000))); controller.close(); } });
    const response = await fetch(url + "/v1/agent/interpret", { method: "POST", duplex: "half",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` }, body: stream });
    assert.equal(response.status, 413);
    assert.equal(calls, 0);
  });
});

test("rate window returns retry-after and resets without another credential", async () => {
  let now = 1_000;
  await withServer({ config: { maxRequests: 1 }, clock: () => now,
    provider: { complete: async () => ({ intentType: "outOfScope" }) } }, async ({ send }) => {
    assert.equal((await send()).status, 200);
    const limited = await send(); assert.equal(limited.status, 429);
    assert.equal(limited.headers.get("Retry-After"), "60");
    now += 60_000;
    assert.equal((await send()).status, 200);
  });
});

test("concurrent calls are bounded and the slot recovers after completion", async () => {
  let release, started;
  const reached = new Promise((resolve) => { started = resolve; });
  let calls = 0;
  const provider = { complete: async () => {
    if (++calls === 1) { started(); await new Promise((resolve) => { release = resolve; }); }
    return { intentType: "outOfScope" };
  } };
  await withServer({ provider, config: { maxConcurrent: 1 } }, async ({ send }) => {
    const first = send(); await reached;
    assert.equal((await send()).status, 503);
    release(); assert.equal((await first).status, 200);
    assert.equal((await send()).status, 200);
  });
});

test("client cancellation stops the task and releases the concurrent slot", async () => {
  let started, aborted;
  const reached = new Promise((resolve) => { started = resolve; });
  const stopped = new Promise((resolve) => { aborted = resolve; });
  let calls = 0;
  const provider = { complete: async (_input, signal) => {
    if (++calls === 1) {
      started(); await new Promise((resolve) => signal.addEventListener("abort", () => { aborted(); resolve(); }, { once: true }));
    }
    return { intentType: "outOfScope" };
  } };
  await withServer({ provider, config: { maxConcurrent: 1 } }, async ({ send }) => {
    const controller = new AbortController();
    const first = send(undefined, { signal: controller.signal });
    const failed = assert.rejects(first);
    await reached; controller.abort(); await failed; await stopped; await pause(5);
    assert.equal((await send()).status, 200);
  });
});

test("demo cannot bind publicly and live mode requires server credentials", () => {
  assert.throws(() => loadConfig({ AGENT_DEMO_MODE: "1", AGENT_API_TOKEN: token, BIND_ADDRESS: "0.0.0.0" }), { code: "server_configuration_error" });
  assert.throws(() => loadConfig({ AGENT_API_TOKEN: token }), { code: "server_configuration_error" });
  assert.throws(() => loadConfig({ AGENT_API_TOKEN: "short", DEEPSEEK_API_KEY: "synthetic" }), { code: "server_configuration_error" });
  assert.equal(loadConfig({ AGENT_API_TOKEN: token, DEEPSEEK_API_KEY: "synthetic" }).demo, false);
});
