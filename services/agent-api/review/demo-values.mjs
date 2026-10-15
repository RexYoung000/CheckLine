// Exact decimal projections for isolated, fictional review data. Not a production ledger.
function decimalParts(value) {
  if (!/^-?\d+(?:\.\d+)?$/.test(String(value)) || String(value).length > 64) throw Error("invalid_decimal");
  const [whole, fraction = ""] = String(value).replace(/^-/, "").split(".");
  return { units: BigInt(whole + fraction) * (String(value).startsWith("-") ? -1n : 1n), digits: fraction.length };
}
function decimalString(units, digits) {
  const negative = units < 0n;
  let text = (negative ? -units : units).toString().padStart(digits + 1, "0");
  if (digits) text = `${text.slice(0, -digits)}.${text.slice(-digits)}`.replace(/\.?0+$/, "");
  return (negative && units !== 0n ? "-" : "") + text;
}
export function decimalAdd(left, right) {
  const a = decimalParts(left), b = decimalParts(right), digits = Math.max(a.digits, b.digits);
  return decimalString(a.units * 10n ** BigInt(digits - a.digits) + b.units * 10n ** BigInt(digits - b.digits), digits);
}
export function decimalNegate(value) { return String(value).startsWith("-") ? String(value).slice(1) : `-${value}`; }
export function decimalSubtract(left, right) { return decimalAdd(left, decimalNegate(right)); }
export function decimalCompare(left, right) {
  const difference = decimalParts(decimalSubtract(left, right)).units;
  return difference < 0n ? -1 : difference > 0n ? 1 : 0;
}
export function positiveMoney(value) {
  try { return /^\d+(?:\.\d+)?$/.test(String(value)) && decimalCompare(value, "0") > 0; } catch { return false; }
}
export function demoConvert(amount, rate) {
  const a = decimalParts(amount), b = decimalParts(rate);
  let units = a.units * b.units, digits = a.digits + b.digits;
  // Review quotes use currencies with two minor digits and positive half-up rounding.
  if (digits > 2) { const scale = 10n ** BigInt(digits - 2); units = (units + scale / 2n) / scale; digits = 2; }
  return decimalString(units, digits);
}

function shiftedMonth(day, offset) {
  const [year, month] = day.split("-").map(Number);
  return new Date(Date.UTC(year, month - 1 + offset, 1)).toISOString().slice(0, 7);
}
function dayInMonth(month, wanted) {
  const [year, number] = month.split("-").map(Number);
  const last = new Date(Date.UTC(year, number, 0)).getUTCDate();
  return `${month}-${String(Math.min(wanted, last)).padStart(2, "0")}`;
}
function previousDay(day) { return new Date(Date.parse(day) - 86_400_000).toISOString().slice(0, 10); }
export function demoMonthlyWindow(schedule, referenceDay) {
  if (!schedule || !["cycle", "window"].includes(schedule.kind)
    || ![schedule.startDay, schedule.endDay].every((value) => Number.isInteger(value) && value >= 1 && value <= 31)) return null;
  const windows = [-1, 0, 1, 2].map((offset) => {
    const month = shiftedMonth(referenceDay, offset), startDay = dayInMonth(month, schedule.startDay);
    const nextMonth = shiftedMonth(`${month}-01`, 1);
    const endDay = schedule.kind === "cycle" ? previousDay(dayInMonth(nextMonth, schedule.startDay))
      : dayInMonth(schedule.endDay < schedule.startDay ? nextMonth : month, schedule.endDay);
    return { startDay, endDay };
  });
  // Short-month clamping cannot attribute the same calendar day twice.
  for (let i = 0; i < windows.length - 1; i++) {
    if (windows[i].endDay >= windows[i + 1].startDay) windows[i].endDay = previousDay(windows[i + 1].startDay);
  }
  return windows.find((range) => range.startDay <= referenceDay && referenceDay <= range.endDay)
    ?? windows.find((range) => range.startDay > referenceDay) ?? null;
}
