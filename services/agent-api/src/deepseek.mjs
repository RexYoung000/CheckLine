import { WorkflowError } from "./contract.mjs";
import { SYSTEM_PROMPT } from "./workflow.mjs";

export const DEEPSEEK_ENDPOINT = "https://api.deepseek.com/chat/completions";
export const MODEL = "deepseek-flash";

async function readLimited(response) {
  const reader = response.body?.getReader();
  if (!reader) throw new WorkflowError("invalid_model_output", 502, true);
  const chunks = [];
  let bytes = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      bytes += value.byteLength;
      if (bytes > 65_536) throw new WorkflowError("invalid_model_output", 502, true);
      chunks.push(value);
    }
    return JSON.parse(Buffer.concat(chunks).toString("utf8"));
  } catch (error) {
    await reader.cancel().catch(() => {});
    if (error instanceof WorkflowError) throw error;
    throw new WorkflowError("invalid_model_output", 502, true);
  } finally {
    reader.releaseLock();
  }
}

export function makeDeepSeekProvider({ apiKey, timeoutMs = 12_000, fetcher = fetch }) {
  if (!apiKey?.trim()) throw new WorkflowError("server_configuration_error", 500);
  return {
    async complete(input, signal = new AbortController().signal) {
      const timeout = AbortSignal.timeout(timeoutMs);
      try {
        const response = await fetcher(DEEPSEEK_ENDPOINT, {
          method: "POST",
          headers: { "Content-Type": "application/json", Authorization: `Bearer ${apiKey}` },
          body: JSON.stringify({
            model: MODEL,
            messages: [{ role: "system", content: SYSTEM_PROMPT },
              { role: "user", content: JSON.stringify(input) }],
            thinking: { type: "enabled" },
            reasoning_effort: "high",
            response_format: { type: "json_object" },
            max_tokens: 4096,
            stream: false,
          }),
          signal: AbortSignal.any([signal, timeout]),
          redirect: "error", // Never forward a provider credential to a redirected host.
        });
        if (!response.ok) {
          await response.body?.cancel().catch(() => {});
          throw new WorkflowError("model_unavailable", 503, true);
        }
        const envelope = await readLimited(response);
        const choice = envelope.choices?.[0];
        if (choice?.finish_reason !== "stop" || choice.message?.tool_calls?.length
            || typeof choice.message?.content !== "string" || !choice.message.content.trim()) {
          throw new WorkflowError("invalid_model_output", 502, true);
        }
        // Only content is parsed; reasoning_content and upstream metadata are never returned/logged.
        return JSON.parse(choice.message.content);
      } catch (error) {
        if (timeout.aborted) throw new WorkflowError("model_timeout", 504, true);
        if (signal.aborted) throw new WorkflowError("model_unavailable", 503, true);
        if (error instanceof WorkflowError) throw error;
        if (error instanceof SyntaxError) throw new WorkflowError("invalid_model_output", 502, true);
        throw new WorkflowError("model_unavailable", 503, true);
      }
    },
  };
}
