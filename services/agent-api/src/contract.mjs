export const VERSION = "1";
export const INTENTS = ["capture", "queryBudgetStatus", "createBudget", "adjustPeriodAmount",
  "deleteExpense", "settlePeriod", "redeemWish", "lateExpense", "recommendPurchase",
  "outOfScope", "needsClarification"];

const text = (maxLength) => ({ type: "string", maxLength });
const nullable = (schema) => ({ ...schema, type: [schema.type, "null"] });
const money = nullable({ ...text(48), pattern: "^[0-9]+(?:\\.[0-9]+)?$" });
const date = nullable({ ...text(40), pattern: "^\\d{4}-\\d{2}-\\d{2}(?:T\\d{2}:\\d{2}:\\d{2}(?:\\.\\d+)?(?:Z|[+-]\\d{2}:\\d{2}))?$" });
const list = (maxItems, maxLength) => ({ type: "array", maxItems, items: text(maxLength) });
const object = (properties, required = Object.keys(properties)) => ({
  type: "object", properties, required, additionalProperties: false,
});

const deviceTimeSchema = object({
  timestamp: { ...text(40), pattern: "^\\d{4}-\\d{2}-\\d{2}T(?:[01]\\d|2[0-3]):[0-5]\\d:[0-5]\\d(?:\\.\\d+)?(?:Z|[+-](?:[01]\\d|2[0-3]):[0-5]\\d)$" },
  timeZoneIdentifier: { ...text(80), minLength: 1 },
});

export const candidateSchema = object({
  intentType: { type: "string", enum: INTENTS },
  amount: money,
  currencyCode: nullable({ type: "string", pattern: "^[A-Z]{3}$" }),
  merchant: nullable(text(160)),
  note: nullable(text(2000)),
  occurredAt: date,
  periodID: { type: "null" },
  budgetID: { type: "null" },
  budgetName: nullable(text(160)),
  tagNames: nullable(list(50, 100)),
  isMultiItem: { type: ["boolean", "null"] },
  name: nullable(text(160)),
  cycleType: nullable({ type: "string", enum: ["repeating", "oneShot"] }),
  startDate: date,
  endDate: date,
  monthlySchedule: nullable(object({
    kind: { type: "string", enum: ["cycle", "window"] },
    startDay: { type: "integer", minimum: 1, maximum: 31 },
    endDay: { type: "integer", minimum: 1, maximum: 31 },
  })),
  newAmount: money,
  expenseID: { type: "null" },
  wishID: { type: "null" },
  actualAmount: money,
  clarificationField: nullable(text(40)),
  clarificationOptions: nullable(list(50, 160)),
  requestedIntent: nullable({ type: "string", enum: INTENTS.filter((intent) => !["needsClarification", "outOfScope", "recommendPurchase"].includes(intent)) }),
}, ["intentType"]);

// Server-owned continuation hint is never part of the upstream model schema.
export const modelCandidateSchema = object(Object.fromEntries(Object.entries(candidateSchema.properties)
  .filter(([key]) => key !== "requestedIntent")), ["intentType"]);

export const requestSchema = object({
  // Legacy client compatibility only. Never used as the server system prompt.
  system: text(8000),
  userMessage: { ...text(4000), minLength: 1 },
  context: object({
    budgetCards: { type: "array", maxItems: 50, items: object({
      name: { ...text(160), minLength: 1 },
      cycleType: { type: "string", enum: ["repeating", "oneShot"] },
      currencyCode: { type: "string", pattern: "^[A-Z]{3}$" },
    }) },
    recentMerchants: list(10, 160),
    tagNames: list(50, 100),
    deviceTime: deviceTimeSchema,
  }, ["budgetCards", "recentMerchants", "tagNames"]),
});

// Validate only the schema vocabulary above. This is deliberately not a general JSON Schema engine.
export function matches(schema, value) {
  const types = Array.isArray(schema.type) ? schema.type : [schema.type];
  const kind = value === null ? "null" : Array.isArray(value) ? "array" : typeof value;
  if (!types.includes(kind) && !(types.includes("integer") && Number.isInteger(value))) return false;
  if (value === null) return true;
  if (schema.enum && !schema.enum.includes(value)) return false;
  if (kind === "string") {
    if (schema.minLength !== undefined && value.length < schema.minLength) return false;
    if (schema.maxLength !== undefined && value.length > schema.maxLength) return false;
    if (schema.pattern && !new RegExp(schema.pattern).test(value)) return false;
  }
  if (kind === "number") {
    if (!Number.isFinite(value)) return false;
    if (schema.minimum !== undefined && value < schema.minimum) return false;
    if (schema.maximum !== undefined && value > schema.maximum) return false;
  }
  if (kind === "array") {
    if (value.length > schema.maxItems) return false;
    if (!value.every((item) => matches(schema.items, item))) return false;
  }
  if (kind === "object") {
    if (Object.getPrototypeOf(value) !== Object.prototype) return false;
    if ((schema.required ?? []).some((key) => !Object.hasOwn(value, key))) return false;
    if (Object.keys(value).some((key) => !Object.hasOwn(schema.properties, key))) return false;
    if (!Object.entries(value).every(([key, item]) => matches(schema.properties[key], item))) return false;
  }
  return true;
}

export class WorkflowError extends Error {
  constructor(code, status, retryable = false) {
    super(code);
    this.code = code;
    this.status = status;
    this.retryable = retryable;
  }
}

export function validateRequest(value) {
  if (!matches(requestSchema, value) || !value.userMessage.trim()) {
    throw new WorkflowError("invalid_request", 400);
  }
  if (value.context.deviceTime) {
    const { timestamp, timeZoneIdentifier } = value.context.deviceTime;
    const [year, month, day] = timestamp.slice(0, 10).split("-").map(Number);
    const check = new Date(Date.UTC(year, month - 1, day));
    try {
      if (!Number.isFinite(Date.parse(timestamp)) || check.getUTCFullYear() !== year
        || check.getUTCMonth() !== month - 1 || check.getUTCDate() !== day) throw Error();
      new Intl.DateTimeFormat("en", { timeZone: timeZoneIdentifier });
    } catch { throw new WorkflowError("invalid_request", 400); }
  }
  return value;
}

export function validateCandidate(value, fromModel = false) {
  if (!matches(fromModel ? modelCandidateSchema : candidateSchema, value)) throw new WorkflowError("invalid_model_output", 502, true);
  for (const field of ["occurredAt", "startDate", "endDate"]) {
    if (!value[field]) continue;
    const [year, month, day] = value[field].slice(0, 10).split("-").map(Number);
    const check = new Date(Date.UTC(year, month - 1, day));
    if (year < 100 || check.getUTCFullYear() !== year || check.getUTCMonth() !== month - 1
        || check.getUTCDate() !== day || !Number.isFinite(Date.parse(value[field]))) {
      throw new WorkflowError("invalid_model_output", 502, true);
    }
  }
  const fields = [...Object.keys(modelCandidateSchema.properties), "input", "action"];
  if (value.clarificationField && !fields.includes(value.clarificationField)) {
    throw new WorkflowError("invalid_model_output", 502, true);
  }
  return value;
}
