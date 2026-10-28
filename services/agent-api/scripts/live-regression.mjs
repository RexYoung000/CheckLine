import { writeFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";
import { setTimeout as delay } from "node:timers/promises";
import { validateCandidate, validateRequest } from "../src/contract.mjs";

const DEVICE_TIME = { timestamp: "2026-10-28T04:00:00Z", timeZoneIdentifier: "Asia/Shanghai" };
const CARDS = [{ name: "餐饮", cycleType: "repeating", currencyCode: "CNY" },
  { name: "旅行", cycleType: "oneShot", currencyCode: "CNY" }];
const check = (id, expected, test) => ({ id, expected, test });
const absent = value => value === undefined || value === null;
const decimal = value => typeof value === "string" && /^\d+(?:\.\d+)?$/.test(value)
  ? value.replace(/^0+(?=\d)/, "").replace(/(\.\d*?)0+$/, "$1").replace(/\.$/, "") : null;
const amount = expected => check("amount", expected, c => decimal(c.amount) === decimal(expected));
const currency = check("currency", "CNY", c => c.currencyCode === "CNY");
const budget = expected => check("budget", expected, c => expected === null ? absent(c.budgetName) : c.budgetName === expected);
const capture = check("intent", "capture", c => c.intentType === "capture");
const clarify = field => check("clarification", field, c => c.intentType === "needsClarification" && c.clarificationField === field);
const safeNonExpense = check("not_a_new_expense", "needsClarification(input/action), no capture continuation", c =>
  c.intentType === "needsClarification" && ["input", "action"].includes(c.clarificationField) && c.requestedIntent !== "capture");
const noDate = check("no_asserted_date", null, c => absent(c.occurredAt));
const merchant = check("merchant_fact", "contains 合成咖啡馆", c => typeof c.merchant === "string" && c.merchant.includes("合成咖啡馆"));
const instant = expected => check("date_instant", expected, c => typeof c.occurredAt === "string" && c.occurredAt.includes("T")
  && Date.parse(c.occurredAt) === Date.parse(expected));
const civilDate = expected => check("date_civil_day", expected, c => {
  if (typeof c.occurredAt !== "string") return false;
  if (/^\d{4}-\d{2}-\d{2}$/.test(c.occurredAt)) return c.occurredAt === expected;
  const parts = Object.fromEntries(new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Shanghai", calendar: "gregory",
    numberingSystem: "latn", year: "numeric", month: "2-digit", day: "2-digit" }).formatToParts(new Date(c.occurredAt)).map(p => [p.type, p.value]));
  return `${parts.year}-${parts.month}-${parts.day}` === expected;
});
const review = key => check(key, true, c => c[key] === true);
function example(id, userMessage, assertions, deviceTime = DEVICE_TIME) {
  return { id, request: { system: "Synthetic candidate regression; server policy remains authoritative.", userMessage,
    context: { budgetCards: structuredClone(CARDS), recentMerchants: [], tagNames: [],
      ...(deviceTime ? { deviceTime: structuredClone(deviceTime) } : {}) } }, assertions };
}

// Followups explicitly restate facts. The service receives no draft, chat history,
// local object IDs or ledger, so these are candidate checks, never App merge tests.
export const REGRESSION_CASES = [
  example("capture_named", "今天在合成咖啡馆买咖啡35元，记到餐饮预算", [capture, amount("35"), currency, merchant, budget("餐饮"), instant("2026-10-27T16:00:00Z")]),
  example("missing_amount", "今天在合成咖啡馆买了咖啡，记到餐饮预算，金额还没填", [clarify("amount"), check("amount_missing", null, c => absent(c.amount)), merchant, budget("餐饮")]),
  example("denied_expense", "我今天没有买咖啡，看到报价35元", [safeNonExpense]),
  example("planned_expense", "我打算明天买合成耳机，预计399元", [safeNonExpense]),
  example("refund_not_capture", "午餐退款35元", [safeNonExpense, amount("35")]),
  example("negated_budget", "今天在合成咖啡馆买咖啡35元，不计入餐饮预算", [clarify("budgetName"), amount("35"), currency, budget(null)]),
  example("alternative_budget", "今天买咖啡35元，记到餐饮预算或旅行预算", [clarify("budgetName"), amount("35"), currency, budget(null)]),
  example("replacement_budget", "今天买咖啡35元，不计入餐饮而记到旅行预算", [capture, amount("35"), currency, budget("旅行"), instant("2026-10-27T16:00:00Z")]),
  example("not_today_zh", "午餐35元，不是今天的，记到餐饮预算", [clarify("occurredAt"), amount("35"), currency, budget("餐饮"), noDate]),
  example("not_today_en", "Lunch 35 CNY, not today, record it in the 餐饮 budget", [clarify("occurredAt"), amount("35"), currency, budget("餐饮"), noDate]),
  example("yesterday_shanghai", "昨天在合成咖啡馆买咖啡35元，记到餐饮预算", [capture, amount("35"), currency, budget("餐饮"), instant("2026-10-26T16:00:00Z")]),
  example("yesterday_los_angeles", "昨天在合成咖啡馆买咖啡35元，记到餐饮预算", [capture, amount("35"), currency, budget("餐饮"), instant("2026-10-26T07:00:00Z")], { ...DEVICE_TIME, timeZoneIdentifier: "America/Los_Angeles" }),
  example("absolute_future", "2026-10-29午餐35元，记到餐饮预算", [clarify("occurredAt"), amount("35"), currency, noDate]),
  example("absolute_offset_valid", "2026-10-27T13:30:00.125+08:00在合成咖啡馆买咖啡35元，记到餐饮预算", [capture, amount("35"), currency, budget("餐饮"), instant("2026-10-27T13:30:00.125+08:00")]),
  example("relative_missing_clock", "昨天午餐35元，记到餐饮预算", [clarify("occurredAt"), amount("35"), currency, noDate], null),
  example("amount_amendment", "改成38元", [clarify("action"), amount("38"), currency, check("no_assumed_operation", null, c => absent(c.requestedIntent))]),
  example("compound_amendment", "这笔日期改一下，不是今天的，不计入餐饮预算，金额35元", [clarify("action"), amount("35"), currency, budget(null), noDate, review("requiresDateReview"), review("requiresBudgetReview")]),
  example("followup_amount_restatement", "这笔是今天在合成咖啡馆买的咖啡，金额38元，记到餐饮预算", [capture, amount("38"), currency, merchant, budget("餐饮"), instant("2026-10-27T16:00:00Z")]),
  example("followup_date_budget_restatement", "这笔是2026-10-27在合成咖啡馆买的咖啡35元，记到旅行预算", [capture, amount("35"), currency, merchant, budget("旅行"), civilDate("2026-10-27")]),
  example("amendment_named_target", "金额改成38元，记到旅行预算", [clarify("action"), amount("38"), currency, budget("旅行"), check("no_assumed_operation", null, c => absent(c.requestedIntent))]),
];

const SAFE_FIELDS = ["intentType", "amount", "currencyCode", "merchant", "budgetName", "occurredAt", "clarificationField",
  "requestedIntent", "requiresDateReview", "requiresBudgetReview"];
const ERROR_CODES = new Set(["invalid_request", "request_too_large", "unsupported_content_type", "unauthorized", "rate_limited",
  "busy", "model_unavailable", "model_timeout", "invalid_model_output", "internal_error", "not_found", "method_not_allowed"]);
const BOOLEAN_FIELDS = new Set(["requiresDateReview", "requiresBudgetReview"]);
const safeActual = (candidate, token) => Object.fromEntries(SAFE_FIELDS.filter(key => Object.hasOwn(candidate ?? {}, key)).map(key => {
  const value = candidate[key];
  if (value === null) return [key, null];
  if (BOOLEAN_FIELDS.has(key)) return [key, typeof value === "boolean" ? value : "[invalid_type]"];
  return [key, typeof value === "string" ? value.split(token).join("[redacted]").slice(0, 180) : "[invalid_type]"];
}));
export function evaluateCandidate(item, candidate, token = "") {
  try { validateCandidate(candidate); }
  catch { return { status: "invalid_candidate", assertions: [{ id: "contract", passed: false }], actual: safeActual(candidate, token || "\0") }; }
  const assertions = item.assertions.map(assertion => ({ id: assertion.id, passed: assertion.test(candidate), expected: assertion.expected }));
  const passed = assertions.every(assertion => assertion.passed);
  return { status: passed ? "pass" : "assertion_failed", assertions,
    ...(!passed ? { actual: safeActual(candidate, token || "\0") } : {}) };
}

function endpointURL(value) {
  let url;
  try { url = new URL(value); } catch { throw new Error("invalid_endpoint"); }
  const local = ["127.0.0.1", "localhost", "[::1]"].includes(url.hostname);
  if ((url.protocol !== "https:" && !(url.protocol === "http:" && local)) || url.username || url.password || url.search || url.hash) throw new Error("invalid_endpoint");
  return url.href;
}
async function readBody(response) {
  if (!response.body) throw new Error("invalid_json");
  const reader = response.body.getReader();
  const chunks = []; let bytes = 0;
  try {
    while (true) {
      const { done, value } = await reader.read(); if (done) break;
      bytes += value.byteLength;
      if (bytes > 65_536) throw new Error("response_too_large");
      chunks.push(value);
    }
    try { return JSON.parse(Buffer.concat(chunks).toString("utf8")); } catch { throw new Error("invalid_json"); }
  } catch (error) { await reader.cancel().catch(() => {}); throw error; }
  finally { reader.releaseLock(); }
}
function summarize(results) {
  const counts = { total: results.length, attempted: results.filter(r => r.status !== "not_run").length,
    passed: results.filter(r => r.status === "pass").length, failed: results.filter(r => !["not_run", "pass"].includes(r.status)).length,
    notRun: results.filter(r => r.status === "not_run").length };
  return { scope: "stateless_synthetic_candidates", status: counts.notRun === counts.total ? "not_run"
    : counts.notRun ? "incomplete" : counts.failed ? "failed" : "passed", counts, results };
}

export async function runRegression({ run = false, endpoint, token, cases = REGRESSION_CASES,
  minIntervalMs = 3500, maxCalls = 20, timeoutMs = 20_000, fetcher = fetch, sleep = delay, now = performance.now.bind(performance) } = {}) {
  if (!run) return summarize(cases.map(item => ({ id: item.id, status: "not_run", reason: "opt_in_required" })));
  const url = endpointURL(endpoint);
  if (typeof token !== "string" || !token.trim() || /\s/.test(token)) throw new Error("missing_or_invalid_token");
  if (!Number.isInteger(maxCalls) || maxCalls < 1 || maxCalls > 20 || !Number.isInteger(minIntervalMs) || minIntervalMs < 0 || minIntervalMs > 60_000
    || !Number.isInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > 120_000) throw new Error("invalid_limits");
  for (const item of cases) validateRequest(item.request);
  const results = []; let stopped;
  for (let index = 0; index < cases.length; index++) {
    const item = cases[index];
    if (index >= maxCalls || stopped) { results.push({ id: item.id, status: "not_run", reason: stopped ?? "call_limit" }); continue; }
    if (index > 0) await sleep(minIntervalMs);
    const signal = AbortSignal.timeout(timeoutMs); const started = now(); let result;
    try {
      const response = await fetcher(url, { method: "POST", headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
        body: JSON.stringify(item.request), signal, redirect: "error" });
      let body;
      try { body = await readBody(response); }
      catch (error) { if (response.ok) throw error; }
      if (!response.ok) {
        const code = ERROR_CODES.has(body?.error?.code) ? body.error.code : "http_error";
        result = { status: "http_error", httpStatus: response.status, error: code };
        if ([401, 429].includes(response.status)) stopped = response.status === 401 ? "authorization_failed" : "rate_limited";
      } else if (response.headers.get("x-checkline-mode") !== "live") result = { status: "non_live_response", error: "live_mode_required" };
      else result = evaluateCandidate(item, body, token);
    } catch (error) {
      const known = ["invalid_json", "response_too_large"].includes(error?.message) ? error.message : "network_error";
      result = { status: signal.aborted ? "request_timeout" : known, error: signal.aborted ? "request_timeout" : known };
    }
    results.push({ id: item.id, ...result, durationMs: Math.max(0, Math.round(now() - started)) });
  }
  return summarize(results);
}

const HELP = "Usage: node scripts/live-regression.mjs --endpoint <authorized-api-url> --run [--min-interval-ms 3500] [--max-calls 20] [--case id,id] [--output path] [--token-env CHECKLINE_AGENT_TOKEN]\nWithout --run: no token access and no requests. Followups restate facts; no App/ledger validation.\n";
export async function runCLI(argv, { env = process.env, fetcher = fetch, sleep = delay, stdout = line => process.stdout.write(line), writeSummary = writeFile } = {}) {
  const options = {}; let output; let tokenEnv = "CHECKLINE_AGENT_TOKEN"; let selected = REGRESSION_CASES;
  try {
    for (let index = 0; index < argv.length; index++) {
      const flag = argv[index];
      if (flag === "--help") { stdout(HELP); return 0; }
      if (flag === "--run") { options.run = true; continue; }
      const value = argv[++index]; if (value === undefined || value.startsWith("--")) throw new Error("invalid_arguments");
      if (flag === "--endpoint") options.endpoint = value;
      else if (flag === "--output") output = value;
      else if (flag === "--token-env" && /^[A-Za-z_][A-Za-z0-9_]{0,79}$/.test(value)) tokenEnv = value;
      else if (["--min-interval-ms", "--max-calls", "--timeout-ms"].includes(flag) && /^\d+$/.test(value)) {
        options[{ "--min-interval-ms": "minIntervalMs", "--max-calls": "maxCalls", "--timeout-ms": "timeoutMs" }[flag]] = Number(value);
      } else if (flag === "--case") {
        const ids = value.split(",");
        if (new Set(ids).size !== ids.length || ids.some(id => !REGRESSION_CASES.some(item => item.id === id))) throw new Error("unknown_case");
        selected = ids.map(id => REGRESSION_CASES.find(item => item.id === id));
      } else throw new Error("invalid_arguments");
    }
    if (options.run) options.token = env[tokenEnv];
    const summary = await runRegression({ ...options, cases: selected, fetcher, sleep });
    for (const result of summary.results) stdout(JSON.stringify({ id: result.id, status: result.status, durationMs: result.durationMs,
      failedAssertions: result.assertions?.filter(a => !a.passed).map(a => a.id), error: result.error, reason: result.reason }) + "\n");
    stdout(JSON.stringify({ status: summary.status, counts: summary.counts, scope: summary.scope }) + "\n");
    if (output) {
      try { await writeSummary(output, JSON.stringify(summary, null, 2) + "\n", { mode: 0o600 }); }
      catch {
        stdout(JSON.stringify({ status: "output_write_failed", error: "output_write_failed", counts: summary.counts, scope: summary.scope }) + "\n");
        return 2;
      }
    }
    return summary.counts.failed || (options.run && summary.counts.notRun) ? 1 : 0;
  } catch (error) {
    const code = ["invalid_endpoint", "missing_or_invalid_token", "invalid_limits", "invalid_arguments", "unknown_case"].includes(error?.message) ? error.message : "runner_error";
    stdout(JSON.stringify({ status: code === "runner_error" ? "runner_error" : "not_run", error: code }) + "\n"); return 2;
  }
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) process.exitCode = await runCLI(process.argv.slice(2));
