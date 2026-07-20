/**
 * CheckLine Stitch 原型生成器
 *
 * 目标：把完整 14 页原型写入正式 Stitch 项目，不新建临时项目。
 *
 * 用法：
 *   node stitch-generate.js           # 生成 / 更新正式项目
 *   node stitch-generate.js --dry-run # 只检查配置和页面清单，不生成
 *   node stitch-generate.js --help    # 查看命令说明
 *
 * 输出：../docs/prototype/stitch-output/
 */

import { existsSync, readFileSync } from "node:fs";
import { mkdir, writeFile } from "node:fs/promises";
import { resolve, join } from "node:path";
import { fileURLToPath } from "node:url";
import { setTimeout } from "node:timers/promises";

import { ProxyAgent, setGlobalDispatcher } from "undici";
setGlobalDispatcher(new ProxyAgent("http://127.0.0.1:7897"));

import { StitchToolClient } from "@google/stitch-sdk";

const __dirname = fileURLToPath(new URL(".", import.meta.url));
const ROOT_DIR = resolve(__dirname, "..");
const OUTPUT_DIR = resolve(ROOT_DIR, "docs", "prototype", "stitch-output");
const BRIEF_PATH = resolve(ROOT_DIR, "docs", "prototype", "stitch-brief", "checkline-full-app-brief.md");
const EXPECTED_PROJECT_ID = "3997330998345861813";
const HOME_SCREEN_ID = "76acdb2c1fe04401bac4ab811e6a35b0";
const MODEL_ID = "GEMINI_3_1_PRO";

const args = new Set(process.argv.slice(2));
const isDryRun = args.has("--dry-run");
const wantsHelp = args.has("--help") || args.has("-h");

if (wantsHelp) {
  console.log(`CheckLine Stitch 原型生成器

用法：
  npm run stitch:generate  生成 / 更新正式 Stitch 项目
  npm run stitch:check     只检查配置和页面清单，不生成

安全规则：
  - 只允许写入正式项目 ${EXPECTED_PROJECT_ID}
  - 不支持自动新建项目
  - 首页使用 edit_screens 更新现有 screen，其余 13 页追加生成`);
  process.exit(0);
}

if (args.has("--create-project")) {
  console.error("❌ 本脚本已禁用 --create-project，避免再次污染 Stitch 最近项目列表。");
  process.exit(1);
}

const envPath = resolve(__dirname, ".env");
const env = existsSync(envPath) ? readFileSync(envPath, "utf8") : "";
const API_KEY = env.match(/^STITCH_API_KEY=(.+)$/m)?.[1]?.trim();
const STITCH_PROJECT_ID = env.match(/^STITCH_PROJECT_ID=(.+)$/m)?.[1]?.trim();

if (!API_KEY) {
  console.error("❌ 未找到 STITCH_API_KEY，请检查 scripts/.env。");
  process.exit(1);
}

if (STITCH_PROJECT_ID !== EXPECTED_PROJECT_ID) {
  console.error(`❌ STITCH_PROJECT_ID 必须是正式项目 ${EXPECTED_PROJECT_ID}。`);
  console.error(`   当前值：${STITCH_PROJECT_ID || "(未设置)"}`);
  process.exit(1);
}

process.env.STITCH_API_KEY = API_KEY;

const brief = readFileSync(BRIEF_PATH, "utf8");

const SCREENS = [
  { number: 1, id: "01-home", name: "首页", action: "edit", screenId: HOME_SCREEN_ID },
  { number: 2, id: "02-budget-list", name: "预算列表", action: "generate" },
  { number: 3, id: "03-budget-detail", name: "预算详情", action: "generate" },
  { number: 4, id: "04-create-budget", name: "新建/编辑预算", action: "generate" },
  { number: 5, id: "05-expense-sheet", name: "记一笔弹窗", action: "generate" },
  { number: 6, id: "06-wish-list", name: "心愿列表", action: "generate" },
  { number: 7, id: "07-wish-detail", name: "心愿详情", action: "generate" },
  { number: 8, id: "08-stats-overview", name: "统计概览", action: "generate" },
  { number: 9, id: "09-calendar", name: "消费记录日历", action: "generate" },
  { number: 10, id: "10-settlement", name: "结算清单", action: "generate" },
  { number: 11, id: "11-settlement-celebration", name: "结算高光", action: "generate" },
  { number: 12, id: "12-wish-achieved", name: "心愿达成反馈", action: "generate" },
  { number: 13, id: "13-settings", name: "我的/设置", action: "generate" },
  { number: 14, id: "14-tutorial", name: "教程卡片", action: "generate" },
];

function sectionBetween(startPattern, endPattern) {
  const start = brief.search(startPattern);
  if (start < 0) return "";
  const rest = brief.slice(start);
  const end = rest.slice(1).search(endPattern);
  return end < 0 ? rest.trim() : rest.slice(0, end + 1).trim();
}

function pageSection(pageNumber) {
  return sectionBetween(
    new RegExp(`^### 页 ${pageNumber} ·`, "m"),
    /^### 页 \d+ ·|^## 八、组件规范/m
  );
}

const sharedContext = [
  sectionBetween(/^## 一、生成目标/m, /^## 二、参考项目说明/m),
  sectionBetween(/^## 三、产品心智/m, /^## 四、设计 Token/m),
  sectionBetween(/^## 四、设计 Token/m, /^## 五、底部导航与全局结构/m),
  sectionBetween(/^## 十一、文案规则/m, /^## 十二、线条小助手出场点/m),
  sectionBetween(/^## 十三、无障碍底线/m, /^## 十四、平台差异/m),
].filter(Boolean).join("\n\n");

function buildPrompt(screen) {
  const page = pageSection(screen.number);
  return `You are generating a high-fidelity iOS mobile prototype screen for CheckLine / 预算线 in Google Stitch.

Hard rules:
- Generate exactly one MOBILE screen.
- Screen title must be "${screen.name}".
- Use the "深空暖金" visual direction: #000814 canvas, #0D1B2A cards, #1A73E8 brand blue, #FFB300 celebration gold.
- Keep the UI native iOS, mature, clean, and product-like.
- Use Chinese user-facing copy.
- Do not show these user-facing terms: 扣血, 记账, 主预算, 副预算, AI 智能记账.
- Do not invent banking/account-sync/social/AA-split features.
- Money allocation decisions must remain user-controlled.
- Use fictional sample data only.
- Do not create shader-only, canvas-only, or WebGL-only screens. Celebration pages must still include visible UI text, amounts, progress, and buttons.

Shared product and design context:
${sharedContext}

Target page specification:
${page}

Return a polished, complete, inspectable mobile screen.`;
}

function outputComponents(result) {
  return result?.outputComponents || result?.output_components || [];
}

function screensFromResult(result) {
  const screens = [];
  for (const comp of outputComponents(result)) {
    if (comp.design?.screens) screens.push(...comp.design.screens);
    if (comp.design?.screen) screens.push(comp.design.screen);
  }
  if (result?.screen) screens.push(result.screen);
  if (result?.screens) screens.push(...result.screens);
  return screens.filter(Boolean);
}

function screenIdFromName(name = "") {
  return name.split("/screens/")[1] || name;
}

function slimScreen(screen) {
  return {
    name: screen.name || "",
    screenId: screen.screenId || screen.id || screenIdFromName(screen.name || ""),
    title: screen.title || screen.name || "",
    width: screen.width || "",
    height: screen.height || "",
  };
}

async function listScreens(client, projectId) {
  const result = await client.callTool("list_screens", { projectId });
  return Array.isArray(result?.screens) ? result.screens : [];
}

async function download(url, dest) {
  const r = await fetch(url);
  if (!r.ok) throw new Error(`HTTP ${r.status}`);
  await writeFile(dest, Buffer.from(await r.arrayBuffer()));
}

async function downloadAssets(screen, screenKey) {
  const saved = { html: false, png: false };
  if (screen?.htmlCode?.downloadUrl) {
    await download(screen.htmlCode.downloadUrl, join(OUTPUT_DIR, `${screenKey}.html`));
    saved.html = true;
  }
  if (screen?.screenshot?.downloadUrl) {
    await download(screen.screenshot.downloadUrl, join(OUTPUT_DIR, `${screenKey}.png`));
    saved.png = true;
  }
  return saved;
}

async function writeManifest(manifest) {
  await writeFile(join(OUTPUT_DIR, "manifest.json"), JSON.stringify(manifest, null, 2));
}

async function main() {
  console.log("🚀 CheckLine Stitch 完整原型生成器");
  console.log(`📁 正式项目: ${EXPECTED_PROJECT_ID}`);
  console.log(`📄 ${SCREENS.length} 页`);
  console.log(`🤖 模型: ${MODEL_ID}\n`);

  if (isDryRun) {
    console.log("🧪 dry-run：只检查配置和页面清单，不创建项目、不生成页面。\n");
    for (const screen of SCREENS) {
      const n = String(screen.number).padStart(2, "0");
      const action = screen.action === "edit" ? "编辑现有首页" : "追加生成";
      console.log(`[${n}/14] ${screen.id} · ${screen.name} · ${action}`);
    }
    return;
  }

  await mkdir(OUTPUT_DIR, { recursive: true });

  const client = new StitchToolClient({ apiKey: API_KEY, timeout: 300_000 });
  const manifest = {
    generatedAt: new Date().toISOString(),
    projectId: EXPECTED_PROJECT_ID,
    modelId: MODEL_ID,
    reusedExistingProject: true,
    homeScreenId: HOME_SCREEN_ID,
    before: {},
    after: {},
    screens: [],
  };

  try {
    const beforeScreens = await listScreens(client, EXPECTED_PROJECT_ID);
    manifest.before = {
      count: beforeScreens.length,
      screens: beforeScreens.map(slimScreen),
    };
    console.log(`🔎 生成前线上页面数: ${beforeScreens.length}\n`);

    for (const screen of SCREENS) {
      const n = String(screen.number).padStart(2, "0");
      const prompt = buildPrompt(screen);
      const startedAt = new Date().toISOString();
      console.log(`[${n}/14] ⏳ ${screen.name} (${screen.action === "edit" ? "编辑" : "生成"})...`);

      const record = {
        id: screen.id,
        number: screen.number,
        name: screen.name,
        action: screen.action,
        status: "pending",
        startedAt,
        finishedAt: null,
        screen: null,
        assets: { html: false, png: false },
        error: null,
      };

      try {
        const result = screen.action === "edit"
          ? await client.callTool("edit_screens", {
              projectId: EXPECTED_PROJECT_ID,
              selectedScreenIds: [screen.screenId],
              prompt,
              deviceType: "MOBILE",
              modelId: MODEL_ID,
            })
          : await client.callTool("generate_screen_from_text", {
              projectId: EXPECTED_PROJECT_ID,
              prompt,
              deviceType: "MOBILE",
              modelId: MODEL_ID,
            });

        const returnedScreens = screensFromResult(result);
        const generated = returnedScreens[0];

        if (!generated) {
          record.status = "failed";
          record.error = "Stitch did not return a screen in the tool response.";
          console.log(`   ⚠️ 未返回页面，已记录失败`);
        } else {
          record.status = "success";
          record.screen = slimScreen(generated);
          record.assets = await downloadAssets(generated, screen.id);
          console.log(`   ✅ ${record.screen.title || record.screen.screenId}`);
          console.log(`   📦 HTML=${record.assets.html ? "yes" : "no"} PNG=${record.assets.png ? "yes" : "no"}`);
        }
      } catch (err) {
        record.status = "failed";
        record.error = err.message?.slice(0, 500) || String(err);
        console.log(`   ❌ ${record.error.slice(0, 160)}`);
      }

      record.finishedAt = new Date().toISOString();
      manifest.screens.push(record);
      await writeManifest(manifest);

      if (screen.number < SCREENS.length) {
        await setTimeout(3000);
      }
      console.log("");
    }

    const afterScreens = await listScreens(client, EXPECTED_PROJECT_ID);
    manifest.after = {
      count: afterScreens.length,
      screens: afterScreens.map(slimScreen),
    };
    await writeManifest(manifest);

    console.log(`🎉 生成流程结束`);
    console.log(`🔎 生成后线上页面数: ${afterScreens.length}`);
    console.log(`📂 本地输出: ${OUTPUT_DIR}`);
    console.log(`🧾 Manifest: ${join(OUTPUT_DIR, "manifest.json")}`);
  } finally {
    await client.close();
  }
}

main().catch(err => {
  console.error("💥", err.message);
  process.exit(1);
});
