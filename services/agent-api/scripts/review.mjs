import { randomBytes } from "node:crypto";
import { start } from "../src/server.mjs";

const server = await start({ AGENT_DEMO_MODE: "1", AGENT_API_TOKEN: randomBytes(32).toString("hex"),
  BIND_ADDRESS: "127.0.0.1", PORT: process.env.PORT ?? "8787" });
console.info("Workflow review: http://127.0.0.1:" + server.address().port + "/review (fixed examples; no model calls)");
for (const signal of ["SIGINT", "SIGTERM"]) process.once(signal, () => {
  server.closeAllConnections();
  server.close(() => process.exit(0));
});
