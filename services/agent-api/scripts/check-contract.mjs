import { readFile } from "node:fs/promises";
import assert from "node:assert/strict";
import { candidateSchema, INTENTS } from "../src/contract.mjs";

const swift = await readFile(new URL("../../../Check_Line/Application/AgentIntentCandidate.swift", import.meta.url), "utf8");
const keys = [...swift.matchAll(/\bvar\s+(\w+)\s*:/g)].map((match) => match[1]).sort();
assert.deepEqual(Object.keys(candidateSchema.properties).sort(), keys);
const validator = await readFile(new URL("../../../Check_Line/Application/IntentValidator.swift", import.meta.url), "utf8");
const switchCases = new Set([...validator.matchAll(/case "(\w+)":/g)].map((match) => match[1]));
for (const intent of INTENTS.filter((value) => value !== "needsClarification")) assert(switchCases.has(intent));
console.info("Swift candidate fields and existing intent routes match the service contract.");
