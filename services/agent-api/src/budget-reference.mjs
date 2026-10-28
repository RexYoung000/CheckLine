// Deliberately conservative evidence of a named budget, never a category classifier.
// The local gate must still resolve the stable object and the expense's actual period.
const escaped = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const assignment = "记到|记入|记在|计入|算到|算入|归入|归到|属于|放到|录入到|纳入";
const scopeBoundary = /[，,。.!！?？;；\n]|而(?:是)?|但(?:是)?|不过|\b(?:but|instead)\b/iu;
const negatedPrefix = /(?:并非|并不|不是|不|别|勿|不要|不应|不能|不必|无需)(?:\s|把|将|给|这笔|该笔|此次|它|要|应该|应当)*$/u;
const englishNegation = /\b(?:not|don['’]?t|never|except|without)\b[^，,。.!！?？;；\n]*$/iu;
const negativeAssignment = new RegExp(`(?:并非|并不|不是|不|别|勿|不要|不应|不能)(?:\\s|把|将|给|这笔|该笔|它|要)*(${assignment})`, "u");
const boundary = "(?=$|[\\s，,。.!！?？;；：:、]|预算|卡|或|和|与|而|但|还是|\\s+budget)";

export function inspectBudgetReferences(message, cards) {
  const names = [...new Set(cards.map((card) => card.name))].sort((a, b) => b.length - a.length);
  const matches = [];
  const mentions = [];
  for (const name of names) {
    const target = `[「『“\"']?${escaped(name)}[」』”\"']?`;
    const expression = new RegExp(
      `(?:${assignment}|而是|\\b(?:in|to|under)\\s+(?:the\\s+)?)${target}${boundary}` +
      `|(?:^|[，,；;。])\\s*${target}\\s*(?:预算卡|预算|卡|\\s+budget\\b)\\s*` +
      `(?:花|消费|支出|用了|用掉|[：:]|(?=[0-9]))` +
      `|(?:并非|不是|不属于|排除|除外|\\b(?:not|except|without)\\s+)${target}${boundary}`, "giu");
    for (const match of message.matchAll(expression)) {
      const prefix = message.slice(0, match.index).split(scopeBoundary).at(-1);
      const negated = /^(?:并非|不是|不属于|排除|除外|not\b|except\b|without\b)/iu.test(match[0])
        || negatedPrefix.test(prefix) || englishNegation.test(prefix);
      const start = match.index, end = start + match[0].length;
      if (!matches.some((other) => start < other.end && end > other.start)) matches.push({ name, start, end, negated });
    }
    for (const match of message.matchAll(new RegExp(`${target}${boundary}`, "giu"))) {
      const start = match.index, end = start + match[0].length;
      if (!mentions.some((other) => start < other.end && end > other.start)) mentions.push({ start, end });
    }
  }
  mentions.sort((a, b) => a.start - b.start);
  const alternatives = matches.some((match) => !match.negated
    && /^(?:预算卡|预算|卡|\s+budget)?\s*(?:或(?:者)?|还是|和|与|\bor\b|\band\b)\s*\S/iu.test(message.slice(match.end)))
    || mentions.some((mention, index) => index > 0
    && /^(?:预算卡|预算|卡|\s+budget)?\s*(?:或(?:者)?|还是|和|与|、|\/|\bor\b|\band\b)\s*$/iu
      .test(message.slice(mentions[index - 1].end, mention.start)));
  const selected = [...new Set(matches.filter((match) => !match.negated).map((match) => match.name))];
  const denied = new Set(matches.filter((match) => match.negated).map((match) => match.name));
  const negative = denied.size > 0 || negativeAssignment.test(message);
  const needsSelection = alternatives || selected.length > 1 || selected.some((name) => denied.has(name))
    || (negative && selected.length === 0);
  return { names: selected, needsSelection };
}

export function explicitBudgetNames(message, cards) {
  return inspectBudgetReferences(message, cards).names;
}
