import { readFile } from "node:fs/promises";
import { makeReviewCases } from "./scenarios.mjs";

// Fixed first-party modules only; keep the exported HTML entirely self-contained.
function inlineModule(source) {
  return source.replace(/^import .*;\n/gm, "").replace(/^export (?=(?:function|const) )/gm, "");
}

export async function renderReview() {
  const [template, reference, dates, flow, values, tasks, ui, cases] = await Promise.all([
    readFile(new URL("index.html", import.meta.url), "utf8"),
    readFile(new URL("../src/budget-reference.mjs", import.meta.url), "utf8"),
    readFile(new URL("../src/device-date.mjs", import.meta.url), "utf8"),
    readFile(new URL("capture-flow.mjs", import.meta.url), "utf8"),
    readFile(new URL("demo-values.mjs", import.meta.url), "utf8"),
    readFile(new URL("task-flow.mjs", import.meta.url), "utf8"),
    readFile(new URL("ui.mjs", import.meta.url), "utf8"),
    makeReviewCases(),
  ]);
  const json = JSON.stringify(cases).replace(/</g, "\\u003c").replace(/\u2028/g, "\\u2028").replace(/\u2029/g, "\\u2029");
  const runtime = [reference, dates, flow, values, tasks, ui].map(inlineModule).join("\n");
  if (/^\s*(?:import|export) /m.test(runtime) || /<\/script/i.test(runtime)) throw new Error("review_bundle_invalid");
  return template.replace("<!--REVIEW_DATA-->", () => `<script type="application/json" id="review-data">${json}</script>`)
    .replace("<!--REVIEW_RUNTIME-->", () => `<script type="module">${runtime}</script>`);
}
