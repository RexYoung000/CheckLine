import { readFile } from "node:fs/promises";
import assert from "node:assert/strict";
import { candidateSchema, requestSchema, INTENTS } from "../src/contract.mjs";

const swift = await readFile(new URL("../../../Check_Line/Application/AgentIntentCandidate.swift", import.meta.url), "utf8");
const keys = [...swift.matchAll(/\bvar\s+(\w+)\s*:/g)].map((match) => match[1]).sort();
assert.deepEqual(Object.keys(candidateSchema.properties).sort(), keys);
const validator = await readFile(new URL("../../../Check_Line/Application/IntentValidator.swift", import.meta.url), "utf8");
const switchCases = new Set([...validator.matchAll(/case "(\w+)":/g)].map((match) => match[1]));
for (const intent of INTENTS.filter((value) => value !== "needsClarification")) assert(switchCases.has(intent));
const contextSwift = await readFile(new URL("../../../Check_Line/Application/AgentContext.swift", import.meta.url), "utf8");
for (const [name, properties] of [["AgentContext", requestSchema.properties.context.properties],
  ["AgentDeviceTimeContext", requestSchema.properties.context.properties.deviceTime.properties]]) {
  const body = contextSwift.match(new RegExp(`struct ${name}\\b[\\s\\S]*?\\n}`))?.[0];
  assert(body, name);
  const fields = [...body.matchAll(/\bvar\s+(\w+)\s*:[^\n{]+(?=\n)/g)].map((match) => match[1]).sort();
  assert.deepEqual(fields, Object.keys(properties).sort(), name);
}
console.info("Swift candidate, device-time request fields and existing intent routes match the service contract.");
