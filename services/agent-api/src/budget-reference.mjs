// Deliberately conservative evidence of a named budget, never a category classifier.
// The local gate must still resolve the stable object and the expense's actual period.
const escaped = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

export function explicitBudgetNames(message, cards) {
  const names = [...new Set(cards.map((card) => card.name))].sort((a, b) => b.length - a.length);
  const matches = [];
  for (const name of names) {
    const namePattern = escaped(name);
    const expression = new RegExp(
      `(?:记到|记入|记在|计入|算到|算入|归入|归到|属于|放到|录入到|` +
      `\\b(?:in|to|under)\\s+(?:the\\s+)?)[「『“\"']?${namePattern}[」』”\"']?` +
      `(?=$|[\\s，,。.!！?？;；：:、]|预算|卡|\\s+budget)` +
      `|(?:^|[，,；;。])\\s*${namePattern}\\s*(?:预算卡|预算|卡|\\s+budget\\b)\\s*` +
      `(?:花|消费|支出|用了|用掉|[：:]|(?=[0-9]))`, "giu");
    for (const match of message.matchAll(expression)) {
      const prefix = message.slice(Math.max(0, match.index - 18), match.index).split(/[，,。.!！?？;；]/).at(-1);
      if (/(?:别|不要|不记|不算|不是|除外|排除)|\b(?:not|don['’]?t|except|without)\b/iu.test(prefix)) continue;
      const start = match.index, end = start + match[0].length;
      if (!matches.some((other) => start < other.end && end > other.start)) matches.push({ name, start, end });
    }
  }
  return [...new Set(matches.map((match) => match.name))];
}
