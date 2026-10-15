import { createServer } from "node:http";
import { createHash, randomUUID, timingSafeEqual } from "node:crypto";
import { pathToFileURL } from "node:url";
import { VERSION, WorkflowError } from "./contract.mjs";
import { interpret } from "./workflow.mjs";
import { makeDeepSeekProvider } from "./deepseek.mjs";

const hash = (value) => createHash("sha256").update(value).digest();
const loopback = (host) => ["127.0.0.1", "::1", "localhost"].includes(host);

export function loadConfig(env = process.env) {
  const config = {
    host: env.BIND_ADDRESS ?? "127.0.0.1",
    port: Number(env.PORT ?? 8787),
    token: env.AGENT_API_TOKEN,
    demo: env.AGENT_DEMO_MODE === "1",
    maxRequests: 20,
    maxConcurrent: 2,
    timeoutMs: 12_000,
  };
  if (!Number.isInteger(config.port) || config.port < 1 || config.port > 65535
      || typeof config.token !== "string" || config.token.length < 32
      || /\s/.test(config.token) || (config.demo && !loopback(config.host))) {
    throw new WorkflowError("server_configuration_error", 500);
  }
  if (!config.demo && !env.DEEPSEEK_API_KEY?.trim()) throw new WorkflowError("server_configuration_error", 500);
  return config;
}

async function readJSON(request) {
  if (!/^application\/json(?:\s*;|$)/i.test(request.headers["content-type"] ?? "")) {
    throw new WorkflowError("unsupported_content_type", 415);
  }
  if (Number(request.headers["content-length"] ?? 0) > 16_384) {
    request.resume();
    throw new WorkflowError("request_too_large", 413);
  }
  return new Promise((resolve, reject) => {
    const chunks = [];
    let bytes = 0;
    const cleanup = () => {
      clearTimeout(timer);
      request.off("data", data); request.off("end", end);
      request.off("error", failed); request.off("aborted", failed);
    };
    const failed = () => { cleanup(); reject(new WorkflowError("invalid_request", 400)); };
    const data = (chunk) => {
      bytes += chunk.length;
      if (bytes > 16_384) {
        cleanup(); request.resume(); reject(new WorkflowError("request_too_large", 413));
      } else chunks.push(chunk);
    };
    const end = () => {
      cleanup();
      try { resolve(JSON.parse(Buffer.concat(chunks).toString("utf8"))); }
      catch { reject(new WorkflowError("invalid_request", 400)); }
    };
    const timer = setTimeout(() => { failed(); request.resume(); }, 3000);
    request.on("data", data); request.once("end", end);
    request.once("error", failed); request.once("aborted", failed);
  });
}

function respond(response, status, body, requestID, demo, extra = {}) {
  if (response.destroyed) return;
  response.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
    "X-Request-ID": requestID,
    "X-CheckLine-Contract": VERSION,
    "X-CheckLine-Mode": demo ? "demonstration" : "live",
    ...extra,
  });
  response.end(JSON.stringify(body));
}

export function makeServer({ config, provider, logger = (event) => console.info(JSON.stringify(event)), clock = Date.now }) {
  if (config.demo && !loopback(config.host)) throw new WorkflowError("server_configuration_error", 500);
  const expected = hash(config.token);
  let count = 0;
  let windowStart = clock();
  let concurrent = 0;
  const server = createServer(async (request, response) => {
    const requestID = randomUUID();
    const started = clock();
    const controller = new AbortController();
    response.on("close", () => { if (!response.writableEnded) controller.abort(); });
    response.on("finish", () => logger({ requestID, status: response.statusCode,
      durationMs: Math.max(0, clock() - started) }));
    let admitted = false;
    try {
      if (request.url === "/health" && request.method === "GET") {
        return respond(response, 200, { status: "ready", mode: config.demo ? "demonstration" : "live" }, requestID, config.demo);
      }
      if (config.demo && request.method === "GET" && ["/review", "/review/cases.json", "/review/download.html"].includes(request.url)) {
        const isPage = request.url === "/review";
        const isHTML = isPage || request.url === "/review/download.html";
        const { renderReview } = await import("../review/render.mjs");
        const { makeReviewCases } = await import("../review/scenarios.mjs");
        const data = isHTML ? await renderReview() : JSON.stringify(await makeReviewCases());
        response.writeHead(200, { "Content-Type": isHTML ? "text/html; charset=utf-8" : "application/json; charset=utf-8",
          "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff",
          ...(!isPage && isHTML ? { "Content-Disposition": 'attachment; filename="checkline-workflow-review.html"' } : {}),
          "Content-Security-Policy": "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'" });
        response.end(data);
        return;
      }
      if (request.url !== "/v1/agent/interpret") throw new WorkflowError("not_found", 404);
      if (request.method !== "POST") throw new WorkflowError("method_not_allowed", 405);
      const auth = request.headers.authorization ?? "";
      if (!auth.startsWith("Bearer ") || !timingSafeEqual(hash(auth.slice(7)), expected)) {
        throw new WorkflowError("unauthorized", 401);
      }
      const now = clock();
      if (now - windowStart >= 60_000) { count = 0; windowStart = now; }
      if (++count > config.maxRequests) throw new WorkflowError("rate_limited", 429, true);
      if (concurrent >= config.maxConcurrent) throw new WorkflowError("busy", 503, true);
      ++concurrent;
      admitted = true;
      const body = await readJSON(request);
      const result = await interpret(body, provider, controller.signal);
      if (!controller.signal.aborted) respond(response, 200, result, requestID, config.demo);
    } catch (error) {
      const safe = error instanceof WorkflowError ? error : new WorkflowError("internal_error", 500, true);
      respond(response, safe.status, { error: { code: safe.code, retryable: safe.retryable } }, requestID, config.demo,
        safe.status === 429 ? { "Retry-After": String(Math.max(1, Math.ceil((60_000 - (clock() - windowStart)) / 1000))) }
          : [400, 401, 413, 415].includes(safe.status) ? { Connection: "close" } : {});
    } finally {
      if (admitted) --concurrent;
    }
  });
  server.headersTimeout = 5000;
  server.requestTimeout = 10_000;
  server.keepAliveTimeout = 5000;
  return server;
}

export async function start(env = process.env) {
  const config = loadConfig(env);
  let provider;
  if (config.demo) {
    const { makeFixtureProvider } = await import("../review/fixtures.mjs");
    provider = await makeFixtureProvider();
  } else {
    provider = makeDeepSeekProvider({ apiKey: env.DEEPSEEK_API_KEY, timeoutMs: config.timeoutMs });
  }
  const server = makeServer({ config, provider });
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(config.port, config.host, resolve);
  });
  return server;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  start().then((server) => {
    console.info(JSON.stringify({ event: "agent_api_ready", mode: process.env.AGENT_DEMO_MODE === "1" ? "demonstration" : "live" }));
    for (const signal of ["SIGINT", "SIGTERM"]) process.once(signal, () => {
      server.close(() => process.exit(0));
      setTimeout(() => { server.closeAllConnections(); process.exit(0); }, 5000).unref();
    });
  }).catch(() => { console.error("agent_api_start_failed"); process.exitCode = 1; });
}
