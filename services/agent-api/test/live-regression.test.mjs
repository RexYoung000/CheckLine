import test from "node:test";
import assert from "node:assert/strict";
import { createServer } from "node:http";
import { execFile } from "node:child_process";
import { mkdtemp, readFile, rm, symlink } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";
import { fileURLToPath, pathToFileURL } from "node:url";
import { REGRESSION_CASES, runRegression, runCLI, evaluateCandidate } from "../scripts/live-regression.mjs";

const TOKEN = "synthetic-runner-test-token";
const endpoint = "https://example.invalid/v1/agent/interpret";
const execFileAsync = promisify(execFile);
const good = id => ({ intentType: "capture", amount: "35", currencyCode: "CNY", merchant: "合成咖啡馆", budgetName: "餐饮", occurredAt: "2026-10-27T16:00:00Z", ...({
  missing_amount: { intentType: "needsClarification", amount: null, clarificationField: "amount", requestedIntent: "capture" },
  denied_expense: { intentType: "needsClarification", clarificationField: "input", budgetName: null, occurredAt: null },
  planned_expense: { intentType: "needsClarification", amount: "399", clarificationField: "action", budgetName: null, occurredAt: null },
  refund_not_capture: { intentType: "needsClarification", clarificationField: "action", budgetName: null, occurredAt: null },
  negated_budget: { intentType: "needsClarification", clarificationField: "budgetName", budgetName: null, requiresBudgetReview: true },
  alternative_budget: { intentType: "needsClarification", clarificationField: "budgetName", budgetName: null, requiresBudgetReview: true },
  replacement_budget: { budgetName: "旅行" },
  not_today_zh: { intentType: "needsClarification", clarificationField: "occurredAt", occurredAt: null, requiresDateReview: true },
  not_today_en: { intentType: "needsClarification", clarificationField: "occurredAt", occurredAt: null, requiresDateReview: true },
  yesterday_shanghai: { occurredAt: "2026-10-26T16:00:00Z" },
  yesterday_los_angeles: { occurredAt: "2026-10-26T07:00:00Z" },
  absolute_future: { intentType: "needsClarification", clarificationField: "occurredAt", occurredAt: null, requiresDateReview: true },
  absolute_offset_valid: { occurredAt: "2026-10-27T13:30:00.125+08:00" },
  relative_missing_clock: { intentType: "needsClarification", clarificationField: "occurredAt", occurredAt: null, requiresDateReview: true },
  amount_amendment: { intentType: "needsClarification", amount: "38", clarificationField: "action", budgetName: null, occurredAt: null },
  compound_amendment: { intentType: "needsClarification", clarificationField: "action", budgetName: null, occurredAt: null, requiresDateReview: true, requiresBudgetReview: true },
  followup_amount_restatement: { amount: "38" },
  followup_date_budget_restatement: { budgetName: "旅行", occurredAt: "2026-10-27" },
  amendment_named_target: { intentType: "needsClarification", amount: "38", clarificationField: "action", budgetName: "旅行", occurredAt: null },
})[id] });
const item = id => REGRESSION_CASES.find(c => c.id === id);
const live = candidate => Response.json(candidate, { headers: { "X-CheckLine-Mode": "live" } });

test("default CLI never reads credentials or issues requests, and labels all cases not run", async () => {
  const output = [];
  const exit = await runCLI([], { env: new Proxy({}, { get() { throw Error("must not read"); } }),
    fetcher: async () => { throw Error("must not fetch"); }, stdout: line => output.push(line) });
  assert.equal(exit, 0);
  const summary = JSON.parse(output.at(-1));
  assert.equal(summary.status, "not_run"); assert.equal(summary.counts.notRun, 20); assert.equal(summary.counts.attempted, 0);
});

test("twenty stateless cases run sequentially once, keeping only the permitted request envelope", async () => {
  let calls = 0, active = 0, maxActive = 0;
  const gaps = [];
  const summary = await runRegression({ run: true, endpoint, token: TOKEN, sleep: async ms => gaps.push(ms), fetcher: async (_url, init) => {
    maxActive = Math.max(maxActive, ++active);
    assert.equal(init.headers.Authorization, `Bearer ${TOKEN}`); assert.equal(init.redirect, "error");
    const request = JSON.parse(init.body);
    assert.deepEqual(Object.keys(request).sort(), ["context", "system", "userMessage"]);
    assert(!JSON.stringify(request).includes(TOKEN));
    const id = REGRESSION_CASES[calls++].id;
    await Promise.resolve(); --active; return live(good(id));
  } });
  assert.equal(summary.status, "passed"); assert.equal(summary.counts.passed, 20); assert.equal(calls, 20); assert.equal(maxActive, 1);
  assert.equal(gaps.length, 19); assert(gaps.every(ms => ms === 3500));
  assert(!JSON.stringify(summary).includes(TOKEN));
});

test("call budget marks remaining cases not run rather than hiding a partial run", async () => {
  let calls = 0;
  const summary = await runRegression({ run: true, endpoint, token: TOKEN, cases: REGRESSION_CASES.slice(0, 3), maxCalls: 1,
    fetcher: async () => { ++calls; return live(good("capture_named")); } });
  assert.equal(calls, 1); assert.equal(summary.status, "incomplete"); assert.equal(summary.counts.notRun, 2);
});

for (const [id, patch, assertion] of [
  ["capture_named", { amount: "35.01" }, "amount"],
  ["negated_budget", { budgetName: "餐饮" }, "budget"],
  ["not_today_zh", { occurredAt: "2026-10-28" }, "no_asserted_date"],
  ["amount_amendment", { intentType: "capture" }, "clarification"],
  ["amendment_named_target", { budgetName: null }, "budget"],
  ["compound_amendment", { requiresBudgetReview: null }, "requiresBudgetReview"],
]) {
  test(`business assertion is strict for ${id}/${assertion}`, () => {
    const result = evaluateCandidate(item(id), { ...good(id), ...patch });
    assert.equal(result.status, "assertion_failed");
    assert(result.assertions.some(a => a.id === assertion && !a.passed));
    assert(Object.hasOwn(result, "actual"));
  });
}

test("failure summary whitelists candidate facts and never dumps credentials or nested invalid values", () => {
  const candidate = { ...good("capture_named"), amount: "36", merchant: TOKEN, note: TOKEN };
  const result = evaluateCandidate(item("capture_named"), candidate, TOKEN);
  assert(!JSON.stringify(result).includes(TOKEN)); assert(!Object.hasOwn(result.actual, "note"));
  const invalid = evaluateCandidate(item("capture_named"), { ...candidate, merchant: { private: TOKEN } }, TOKEN);
  assert.equal(invalid.status, "invalid_candidate"); assert(!JSON.stringify(invalid).includes(TOKEN));
});

test("invalid response fields admit only strings, null and review booleans in failure summaries", () => {
  const invalid = evaluateCandidate(item("capture_named"), { ...good("capture_named"),
    merchant: [TOKEN], amount: { private: TOKEN }, currencyCode: true, requestedIntent: false,
    requiresDateReview: { private: TOKEN }, requiresBudgetReview: TOKEN,
  }, TOKEN);
  assert.equal(invalid.status, "invalid_candidate");
  for (const key of ["merchant", "amount", "currencyCode", "requestedIntent", "requiresDateReview", "requiresBudgetReview"]) assert.equal(invalid.actual[key], "[invalid_type]");
  assert(!JSON.stringify(invalid).includes(TOKEN));
});

for (const [label, response, status] of [
  ["malformed JSON", () => new Response("private raw body"), "invalid_json"],
  ["oversized body", () => new Response("x".repeat(66_000)), "response_too_large"],
  ["invalid candidate", () => live({ ...good("capture_named"), tools: ["private"] }), "invalid_candidate"],
  ["demo mode", () => Response.json(good("capture_named"), { headers: { "X-CheckLine-Mode": "demonstration" } }), "non_live_response"],
]) {
  test(`runner classifies ${label} without logging its body`, async () => {
    const summary = await runRegression({ run: true, endpoint, token: TOKEN, cases: [item("capture_named")], fetcher: async () => response() });
    assert.equal(summary.results[0].status, status); assert.equal(summary.counts.failed, 1);
    assert(!JSON.stringify(summary).includes("private"));
  });
}

for (const status of [401, 429]) {
  test(`HTTP ${status} stops further calls without retrying`, async () => {
    let calls = 0;
    const summary = await runRegression({ run: true, endpoint, token: TOKEN, fetcher: async () => {
      ++calls; return Response.json({ error: { code: "private upstream body" } }, { status });
    } });
    assert.equal(calls, 1); assert.equal(summary.counts.failed, 1); assert.equal(summary.counts.notRun, 19);
    assert(!JSON.stringify(summary).includes("private"));
  });
}

test("CLI opt-in reads only the named synthetic token and writes a safe failed summary", async () => {
  const output = []; let saved;
  const exit = await runCLI(["--run", "--endpoint", endpoint, "--case", "capture_named", "--min-interval-ms", "0", "--output", "/synthetic/summary.json"], {
    env: { CHECKLINE_AGENT_TOKEN: TOKEN }, stdout: line => output.push(line),
    fetcher: async () => live({ ...good("capture_named"), amount: "36", merchant: TOKEN }),
    writeSummary: async (_path, data, options) => { saved = data; assert.equal(options.mode, 0o600); },
  });
  assert.equal(exit, 1); assert(saved.includes('"expected"')); assert(saved.includes('"actual"'));
  assert(![...output, saved].join("").includes(TOKEN));
});

test("invalid configuration never sends a request and never echoes a credential URL", async () => {
  const output = []; let calls = 0;
  const exit = await runCLI(["--run", "--endpoint", `https://user:${TOKEN}@example.invalid/`], {
    env: { CHECKLINE_AGENT_TOKEN: TOKEN }, stdout: line => output.push(line), fetcher: async () => { ++calls; },
  });
  assert.equal(exit, 2); assert.equal(calls, 0); assert(!output.join("").includes(TOKEN));
  assert.equal(JSON.parse(output.at(-1)).status, "not_run");
});

test("a summary write failure preserves completed request counts instead of claiming not run", async () => {
  const output = []; let calls = 0;
  const exit = await runCLI(["--run", "--endpoint", endpoint, "--case", "capture_named", "--output", "/synthetic/unwritable"], {
    env: { CHECKLINE_AGENT_TOKEN: TOKEN }, stdout: line => output.push(line),
    fetcher: async () => { ++calls; return live(good("capture_named")); },
    writeSummary: async () => { throw Error(TOKEN); },
  });
  const last = JSON.parse(output.at(-1));
  assert.equal(exit, 2); assert.equal(calls, 1); assert.equal(last.status, "output_write_failed");
  assert.equal(last.counts.attempted, 1); assert.equal(last.counts.passed, 1); assert.equal(last.counts.notRun, 0);
  assert(!output.join("").includes(TOKEN));
});

test("runner uses actual local HTTP, bounds timeout and never retries it", async () => {
  let calls = 0;
  const server = createServer(() => { ++calls; });
  await new Promise(resolve => server.listen(0, "127.0.0.1", resolve));
  try {
    const summary = await runRegression({ run: true, endpoint: `http://127.0.0.1:${server.address().port}/v1/agent/interpret`,
      token: TOKEN, cases: [item("capture_named")], timeoutMs: 100 });
    assert.equal(summary.results[0].status, "request_timeout"); assert.equal(calls, 1);
  } finally { server.closeAllConnections(); await new Promise(resolve => server.close(resolve)); }
});

for (const mode of ["entry", "import"]) {
  test(`a directory-symlink ${mode} stays opt-in in a real child process`, async () => {
    const root = await mkdtemp(join(tmpdir(), "CheckLineLiveSymlink-"));
    const current = join(root, "current");
    const summaryPath = join(root, "summary.json");
    await symlink(fileURLToPath(new URL("../", import.meta.url)), current, "dir");
    const entry = join(current, "scripts", "live-regression.mjs");
    let requests = 0;
    const server = createServer((_request, response) => { ++requests; response.writeHead(500); response.end(); });
    await new Promise(resolve => server.listen(0, "127.0.0.1", resolve));
    try {
      const endpoint = `http://127.0.0.1:${server.address().port}/v1/agent/interpret`;
      const args = mode === "entry" ? [entry, "--endpoint", endpoint, "--output", summaryPath]
        : ["--input-type=module", "--eval", `await import(${JSON.stringify(pathToFileURL(entry).href)}); console.log('imported');`];
      const result = await execFileAsync(process.execPath, args, { env: { CHECKLINE_AGENT_TOKEN: TOKEN }, timeout: 5_000 });
      assert.equal(result.stderr, "");
      if (mode === "entry") {
        assert.notEqual(result.stdout.trim(), "", "CLI entry must produce a not-run report");
        const lines = result.stdout.trim().split("\n").map(line => JSON.parse(line));
        assert.equal(lines.length, 21);
        assert.equal(lines.at(-1).status, "not_run");
        assert.equal(lines.at(-1).counts.attempted, 0); assert.equal(lines.at(-1).counts.notRun, 20);
        const summary = JSON.parse(await readFile(summaryPath, "utf8"));
        assert.equal(summary.results.length, 20); assert(summary.results.every(item => item.status === "not_run"));
      } else {
        assert.equal(result.stdout.trim(), "imported");
        await assert.rejects(readFile(summaryPath), { code: "ENOENT" });
      }
      assert.equal(requests, 0); assert(!result.stdout.includes(TOKEN));
    } finally {
      server.closeAllConnections(); await new Promise(resolve => server.close(resolve));
      await rm(root, { recursive: true, force: true });
    }
  });
}
