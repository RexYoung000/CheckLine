// Relative consumption days use the request clock, never the server clock or model's arithmetic.
const definiteDay = /前天|昨天|今天|\b(?:the\s+)?day before yesterday\b|\byesterday\b|\btoday\b/gi;
const unclearDay = /明天|后天|上周|上星期|上个月|下周|下个月|最近|前几天|几天前|昨晚|昨夜|今晚|今早|昨天晚上|昨天早上|\b(?:tomorrow|last week|last month|next week|next month|recently|last night|tonight|this morning|yesterday (?:morning|evening))\b/i;
const absoluteDay = /\d{4}-\d{1,2}-\d{1,2}|\d{1,2}\s*月\s*\d{1,2}|\d{1,2}\s*(?:日|号)/;
const explicitTime = /\d{1,2}:\d{2}|(?:\d{1,2}|[一二三四五六七八九十两]+)\s*点|上午|下午|晚上|早上|凌晨|\b(?:am|pm|morning|evening|afternoon|noon|midnight)\b/i;
const dayOffset = (word) => /前天|day before yesterday/i.test(word) ? -2 : /昨天|yesterday/i.test(word) ? -1 : 0;
const dateNegation = /(?:并非|并不|不是|不在|不一定|不|别|非)(?:\s|发生在|在|那天|是)*$|\b(?:not|never|isn['’]?t|wasn['’]?t)(?:\s+(?:on|from))?\s*$/iu;

function isNegatedDay(text, match) {
  const prefix = text.slice(0, match.index).split(/[，,。.!！?？;；\n]/u).at(-1);
  const suffix = text.slice(match.index + match[0].length);
  return dateNegation.test(prefix)
    || /^\s*(?:不对|有误|错了|不正确|不是(?:消费|交易|购买)?日期)|^\s+(?:(?:is|was)\s+(?:not|wrong)|isn['’]?t|wasn['’]?t)\b/iu.test(suffix);
}

function dayFormatter(deviceTime) {
  return new Intl.DateTimeFormat("en-CA", { timeZone: deviceTime.timeZoneIdentifier,
    calendar: "gregory", numberingSystem: "latn", year: "numeric", month: "2-digit", day: "2-digit" });
}

function civilDay(formatter, instant) {
  const parts = Object.fromEntries(formatter.formatToParts(instant).map(({ type, value }) => [type, value]));
  return `${parts.year.padStart(4, "0")}-${parts.month}-${parts.day}`;
}

// First instant in the target local calendar day. Searching calendar labels also handles DST
// changes at midnight; subtracting 24 hours from the reference instant would not.
function beginningOfDay(day, formatter) {
  const nominal = Date.parse(day + "T00:00:00Z");
  let low = nominal - 26 * 3600000;
  let high = nominal + 26 * 3600000;
  while (low < high) {
    const middle = Math.floor((low + high) / 2);
    if (civilDay(formatter, new Date(middle)) < day) low = middle + 1;
    else high = middle;
  }
  const start = new Date(low);
  // Some historical zone changes skipped an entire date. Ask instead of inventing that day.
  return civilDay(formatter, start) === day ? start.toISOString().replace(".000Z", "Z") : null;
}

export function resolveConsumptionDay(text, deviceTime, extractedOccurredAt) {
  const relative = [...text.matchAll(definiteDay)];
  const absolute = [...text.matchAll(new RegExp(absoluteDay.source, "g"))];
  if ([...relative, ...absolute].some((match) => isNegatedDay(text, match))
      || new Set(absolute.map((match) => match[0])).size > 1) return { kind: "clarify" };
  const words = relative.map((match) => match[0]);
  if (!words.length && !unclearDay.test(text)) {
    // Date-only values are already civil days. An ISO instant is viewed in the
    // request's time zone; neither form is compared with the server's clock.
    if (extractedOccurredAt) {
      if (!deviceTime) return { kind: "clarify" };
      const formatter = dayFormatter(deviceTime);
      const candidateDay = /^\d{4}-\d{2}-\d{2}$/.test(extractedOccurredAt)
        ? extractedOccurredAt : civilDay(formatter, new Date(extractedOccurredAt));
      if (candidateDay > civilDay(formatter, new Date(deviceTime.timestamp))) return { kind: "clarify" };
    } else if (absolute.length && extractedOccurredAt === null) return { kind: "clarify" };
    return { kind: "absent" };
  }
  const offsets = [...new Set(words.map(dayOffset))];
  if (!deviceTime || unclearDay.test(text) || offsets.length !== 1 || absoluteDay.test(text) || explicitTime.test(text)
    || /(?:昨天|今天|前天)\s*(?:到|至|和|或|跟|、|[-~～])/i.test(text)) return { kind: "clarify" };
  const formatter = dayFormatter(deviceTime);
  const currentDay = civilDay(formatter, new Date(deviceTime.timestamp));
  const target = new Date(currentDay + "T00:00:00Z");
  target.setUTCDate(target.getUTCDate() + offsets[0]);
  const occurredAt = beginningOfDay(target.toISOString().slice(0, 10), formatter);
  return occurredAt ? { kind: "resolved", occurredAt } : { kind: "clarify" };
}
