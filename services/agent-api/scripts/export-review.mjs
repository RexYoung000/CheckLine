import { writeFile, mkdir } from "node:fs/promises";
import { resolve, dirname } from "node:path";
import { renderReview } from "../review/render.mjs";

const destination = resolve(process.argv[2] ?? "../../tmp/checkline-workflow-review.html");
await mkdir(dirname(destination), { recursive: true });
await writeFile(destination, await renderReview());
console.info(`Standalone workflow review: ${destination}`);
