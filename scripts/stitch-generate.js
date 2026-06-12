/**
 * CheckLine Stitch 原型生成器
 *
 * 通过 Stitch MCP API 批量生成 14 页高保真 iOS UI 原型。
 * 走本地代理端口 7897 访问 Google Stitch 服务。
 *
 * 用法：node stitch-generate.js
 *
 * 输出：../docs/prototype/stitch-output/
 */

import { readFileSync, writeFile } from "node:fs";
import { mkdir } from "node:fs/promises";
import { resolve, join } from "node:path";
import { fileURLToPath } from "node:url";
import { setTimeout } from "node:timers/promises";

import { ProxyAgent, setGlobalDispatcher } from "undici";
setGlobalDispatcher(new ProxyAgent("http://127.0.0.1:7897"));

import { StitchToolClient } from "@google/stitch-sdk";

// =========================================================
// 配置
// =========================================================

const __dirname = fileURLToPath(new URL(".", import.meta.url));
const OUTPUT_DIR = resolve(__dirname, "..", "docs", "prototype", "stitch-output");

const env = readFileSync(resolve(__dirname, ".env"), "utf8");
const API_KEY = env.match(/STITCH_API_KEY=(.+)/)?.[1]?.trim();
if (!API_KEY) {
  console.error("❌ 未找到 STITCH_API_KEY，请检查 scripts/.env 文件");
  process.exit(1);
}
process.env.STITCH_API_KEY = API_KEY;

// =========================================================
// 14 页 Prompt（从 brief 第七节提炼）
// =========================================================

const SCREENS = [
  {
    id: "01-home",
    name: "首页",
    prompt: `A personal budget management iOS app home screen with dark theme (#000814 background, cards #0D1B2A with 16pt radius). Chinese app name "预算线" at top.

Layout:
- Top bar: date "6月12日" on left, gear settings icon on right
- App brand name "预算线" in heading2, white
- A horizontal swipeable wallet card with pagination dots underneath. Active card shows:
  * Title "6月生活" in heading3
  * Label "还能花" in bodySmall
  * Large "¥1,520" in SF Mono bold display 56pt
  * Horizontal progress bar (6pt tall, pill shape, brand blue #1A73E8, 70% filled)
  * Category summary in caption: "伙食 ¥320 · 聚会 ¥200"
- Section "当前钱包列表" with category rows
- Wish hint in bodySmall: "心愿：京都樱花季 65%"
- Floating circular "+" button at bottom-right corner with brand blue fill

Clean, professional, minimal. No clutter, no multiple large buttons side by side. Chinese text in PingFang SC. `,
  },
  {
    id: "02-budget-list",
    name: "预算列表",
    prompt: `Personal budget iOS app, budget list screen with dark theme (#000814).

Layout:
- Nav: back arrow "<", title "预算", right: "+ 新建" text button
- Summary card (#0D1B2A): "全部预算总览 · 3 个进行中 · 2 个待结算 · 本月已用 ¥3,200"
- "进行中" section header with wallet cards:
  "6月生活 剩 ¥1,520" with 70% brand blue progress bar
  "京都旅行 剩 ¥3,200" with 36% progress bar
  "Q3 学习 剩 ¥800" with 60% progress bar
- "待结算" section with golden-highlighted cards (celebration gold #FFB300):
  "5月生活 省 ¥600" with sparkle emoji on right
  "周末出行 省 ¥120"
- "已归档" section (collapsed, gray text)

Clean grouped list, rounded 16pt cards, Chinese PingFang SC.`,
  },
  {
    id: "03-budget-detail",
    name: "预算详情",
    prompt: `Personal budget iOS app, budget detail screen with dark theme (#000814).

Layout:
- Nav: back "<", title "6月生活", right: "⋯ 编辑"
- Hero card (#0D1B2A, 16pt radius):
  Large "¥1,520" in SF Mono display, " / ¥5,000" underneath
  70% progress bar (brand blue), dates "6.1 - 6.30 · 重复型"
- "分类" section with category rows and mini progress bars:
  "伙食 ¥1,200/¥2,000 60%" (brand blue bar)
  "聚会 ¥600/¥1,000 60%"
  "交通 ¥300/¥800 38%"
  "其他 ¥380/¥1,200 32%"
- "最近记录" section: expense list
  "6/12 ¥38 打车", "6/11 ¥150 晚餐", "6/11 ¥25 咖啡"
- Warning note "⚠ 关联账（2 笔）"
- Floating "+" bottom-right

Clean, professional. No clutter. Chinese PingFang SC.`,
  },
  {
    id: "04-create-budget",
    name: "新建预算",
    prompt: `Personal budget iOS app, create budget form screen with dark theme (#000814).

Layout:
- Nav: close "✕", title "新建预算"
- Template chips (2x3 grid): "月度生活" "旅游" "约会" "学习" "自定义"
  "月度生活" selected with brand blue border
- Text field: "预算名称" placeholder "6月生活"
- Radio: "◉ 重复型（如月度生活）" / "○ 单次型（如旅行）"
- Date picker row: "[2026/6/1] - [2026/6/30]"
- Amount input: "总额 ¥ [5000.00]" with SF Mono
- Editable category list: "伙食 ¥2,000 ✏️" "聚会 ¥1,000 ✏️" "交通 ¥800 ✏️" "其他 ¥1,200 ✏️"
  "+ 添加分类" at bottom
- Overrun strategy section:
  "◉ 仅提醒（推荐）" subtext "预算用完温柔提示，不阻断"
  "○ 抵扣心愿" subtext "超支金额从默认心愿扣回"
- Dropdown: "默认转入心愿 ▼ 京都樱花季"
- Large brand blue primary button "创建预算"

Clean form layout, dark cards, Chinese.`,
  },
  {
    id: "05-expense-sheet",
    name: "记一笔弹窗",
    prompt: `Personal budget iOS app, expense entry bottom sheet with dark theme (#0D1B2A sheet background, #000814 app background).

Layout (bottom sheet with drag handle at top):
- Title "记一笔" with close ✕ button
- Large amount "¥ [38.00]" in SF Mono, editable
- "归到哪些预算（平等多选）" label, BudgetTagChip buttons (pill shape, 36pt):
  "✓京都旅行" (filled brand blue, white text, checkmark)
  "✓6月生活" (filled brand blue)
  "+ 添加" (outlined brand blue border)
- "分类" section, CategoryPill buttons (32pt pill):
  "✓交通" (selected, colored), "伙食" "娱乐" (unselected, dark bg)
- "备注（选填）" text field
- Large brand blue button "记下这笔" at bottom

Clean, minimal, fast-looking. Pills are compact and touch-friendly.`,
  },
  {
    id: "06-wish-list",
    name: "心愿列表",
    prompt: `Personal budget iOS app, wish list screen with dark theme (#000814).

Layout:
- Nav: back "<", title "心愿", right: "+ 新建"
- Summary card: "全部心愿 · 2 进行中 · 1 已达成 · 累积 ¥3,200"
- "进行中" section:
  Card 1: "🌸 京都樱花季", "¥3,250 / ¥5,000", horizontal progress bar 65% (brand blue to celebration gold gradient), "预计 6 月还累积 ¥600" note
  Card 2: "📷 富士相机", "¥0 / ¥3,000", progress bar at 0% (empty, bgElevated)
- "已达成 ✨" section:
  Card: "🎮 Switch", "已达成 5/15" in gray, completed style

Warm gold accents (#FFB300) on active progress. Clean list, dark cards.`,
  },
  {
    id: "07-wish-detail",
    name: "心愿详情",
    prompt: `Personal budget iOS app, wish detail screen with dark theme (#000814).

Layout:
- Nav: back "<", title "京都樱花季", right: "⋯ 编辑"
- Centered large cherry blossom 🌸 icon (80pt)
- Circular progress ring (160pt diameter, brand blue to celebration gold gradient, 6pt stroke):
  Center: "65%" large text, "¥3,250" below, "/ ¥5,000" smaller
- Prediction: "预计 6 月生活结算后再 +¥600" in bodySmall
- "来源记录" section:
  "5/30 5月生活结算 +¥800"
  "4/30 4月生活结算 +¥650"
  "3/30 3月生活结算 +¥720"
  "2/14 手动加入 +¥1,000"
  "2/01 手动加入 +¥80"
- Secondary button "手动加入金额 +"

Warm, inspiring, celebration gold accents. Clean.`,
  },
  {
    id: "08-stats-overview",
    name: "统计概览",
    prompt: `Personal budget iOS app, statistics overview screen with dark theme (#000814). Reference clean minimalist dashboard style.

Layout:
- Nav: title "统计", right: "日历 →" link
- Hero metric: label "本月离心愿近了", large "#00C853 ¥1,200" in display size, surplus green color
- "预算 vs 实际" section: simple bar chart (months Jan-May), brand blue bars, clean minimal axis
- "分类分析" section: horizontal bars with percentages
  "伙食 ¥3,200 40%" widest bar
  "聚会 ¥1,800 22%"
  "交通 ¥1,200 15%"
  "娱乐 ¥800 10%"
  "其他 ¥1,000 13%"
- "本月预算钱包" section: "6月生活 ¥3,480/¥5,000" "京都旅行 ¥1,800/¥5,000"

Clean data visualization, no complex financial charts, calm and readable.`,
  },
  {
    id: "09-calendar",
    name: "消费记录日历",
    prompt: `Personal budget iOS app, expense calendar screen with dark theme (#000814).

Layout:
- Nav: back "<", title "消费记录日历"
- Month nav: "◀ 2026年6月 ▶" with filter dropdown "全部预算 ▼"
- Full calendar grid (Sun-Sat), June 12 highlighted with brand blue circle
- Dates with records have small dots below
- Below: "6月12日 · 3 笔"
- Expense rows with tags:
  "¥38 交通 打车" tags "[京都旅行] [6月生活]" (small brand blue pills)
  "¥150 伙食 晚餐" tag "[6月生活]"
  "¥25 伙食 咖啡" tag "[6月生活]"

Clean calendar UI, readable grid, expense tags in minimal pill style.`,
  },
  {
    id: "10-settlement",
    name: "结算清单",
    prompt: `Personal budget iOS app, budget settlement screen with dark theme (#000814).

Layout:
- Nav: back "<", title "结算 6月生活"
- Summary card: "总支出 ¥4,400", "预算总额 ¥5,000", progress bar 88%
- "⚠ 关联账确认（3 笔）" section:
  Row: "¥80 打车 6/15 14:30", "归属：京都旅行 / 6月生活"
  Segmented control: "[都算] [仅京都] [仅生活]" with "都算" highlighted blue
- Highlight card: "#00C853 省下了 ¥600" in large display, surplus green
- "转到心愿" section:
  "▣ 京都樱花季 ¥600 ✏️" (preselected checkbox)
  "□ 富士相机 ¥0 ✏️"
  "□ 不转入"
- Validation: "💡 总和必须 = ¥600"
- Large "#FFB300 ✨ 结算" celebration gold primary button

Important, ceremonial feel. Green surplus prominent. Trustworthy and calm.`,
  },
  {
    id: "11-settlement-celebration",
    name: "结算高光",
    prompt: `Full-screen celebration overlay for a personal budget iOS app, dark space theme.

Design:
- Background: deep space #000814 with warm gold #FFB300 gradient at 30% opacity
- Golden confetti particles scattered (light, elegant, not overwhelming)
- Centered vertically:
  * "省下了" label in bodySmall, muted
  * "¥600" huge 88pt SF Mono bold in celebration gold
  * "离樱花季更近了" in heading2, white
  * Minimal line-buddy character (simple line art: a boundary line with a checkmark node) at bottom center
  * "65% → 77%" progress indicator
- Bottom buttons: "[分享卡片]" ghost button, "[完成]" brand blue primary

Magical, rewarding, professional. Not childish. Grown-up celebration moment.`,
  },
  {
    id: "12-wish-achieved",
    name: "心愿达成",
    prompt: `Full-screen wish achievement celebration for a personal budget iOS app.

Design:
- Background: deep space #000814 with cherry blossom pink warm gradient
- Pink and gold elegant confetti particles
- Large centered cherry blossom icon 🌸 (200pt)
- "樱花季解锁了" in display size, warm pink-white tone
- "¥5,000 / ¥5,000" amount
- "攒了4个月" subtitle in bodySmall
- Three stacked buttons:
  "[分享给朋友]" (secondary ghost), "[开新心愿]" (brand blue primary), "[查看心愿]" (secondary)

This is THE emotional peak. Grander than settlement. Warm, inspiring, share-worthy.`,
  },
  {
    id: "13-settings",
    name: "我的/设置",
    prompt: `Personal budget iOS app, settings screen with dark theme (#000814). Clean grouped list style.

Layout:
- Title: "我的"
- Status card: "本月达标 89%", "心愿累积 ¥3,200", "连续使用 23 天"
- "财务管理" section: rows with ">" chevron: "预算设置", "记录管理", "数据导出", "货币：¥ CNY"
- "通用设置" section: "通知 >", "外观：跟随系统 >", "iCloud 同步：✓ 已开启", "权限管理 >"
- "教程" section: "重新查看教程 >", "概念帮助 >"
- "订阅与关于" section: "订阅 / 买断 >", "隐私说明 >", "意见反馈 >", "版本 1.0.0"

Clean grouped list, dark card base, section headers in overline style. Quiet, professional.`,
  },
  {
    id: "14-tutorial",
    name: "教程卡片",
    prompt: `iOS tutorial card screen for a personal budget app, dark space theme.

Single card from a 6-card swipeable deck:
- Full-width card with 20pt horizontal margins, 16pt radius, #0D1B2A background
- Top illustration area (40% height): simple elegant line artwork showing a boundary line with checkmark nodes, in brand blue #1A73E8 and celebration gold #FFB300 accents. Minimal, not cartoonish.
- Below illustration:
  * Title "什么是预算线？" in heading2, white
  * Body "给自己划一条消费边界，线内自由，线外克制。" in body, secondary gray
- Bottom center: pagination dots "● ○ ○ ○ ○ ○", current page brand blue
- Buttons: "[跳过]" left (textSecondary), "[下一页]" right (brand blue)

Educational, elegant, adult. Line art only - no heavy character illustration.`,
  },
];

// =========================================================
// 工具函数
// =========================================================

async function retry(fn, retries = 3, delay = 5000) {
  for (let i = 0; i <= retries; i++) {
    try {
      return await fn();
    } catch (err) {
      if (i === retries) throw err;
      const code = err.code || "";
      if (code === "NOT_FOUND" || code === "PERMISSION_DENIED" || code === "VALIDATION_ERROR") throw err;
      console.log(`   ⚠️ 重试 ${i + 1}/${retries} (${err.message.slice(0, 80)})...`);
      await setTimeout(delay);
    }
  }
}

async function download(url, dest) {
  const resp = await fetch(url);
  if (!resp.ok) throw new Error(`下载失败 HTTP ${resp.status}`);
  const buf = Buffer.from(await resp.arrayBuffer());
  return new Promise((ok, fail) =>
    writeFile(dest, buf, (e) => (e ? fail(e) : ok()))
  );
}

// =========================================================
// 主流程
// =========================================================

async function main() {
  console.log("🚀 CheckLine Stitch 原型生成器");
  console.log(`📄 ${SCREENS.length} 页待生成`);
  console.log(`📂 输出: ${OUTPUT_DIR}\n`);

  await mkdir(OUTPUT_DIR, { recursive: true });

  const client = new StitchToolClient({ apiKey: API_KEY });

  // 1. 创建项目
  console.log("📁 创建 Stitch 项目...");
  const proj = await retry(() => client.callTool("create_project", { title: "CheckLine" }));
  const projectId = proj.name;
  console.log(`✅ 项目: ${projectId}\n`);

  // 2. 逐页生成
  for (let i = 0; i < SCREENS.length; i++) {
    const s = SCREENS[i];
    const n = String(i + 1).padStart(2, "0");
    console.log(`[${n}/${SCREENS.length}] ⏳ ${s.name}...`);

    try {
      const screen = await retry(() =>
        client.callTool("generate_screen_from_text", {
          project_id: projectId,
          prompt: s.prompt,
        })
      );
      const screenId = screen.name;
      console.log(`   ✅ ${screenId}`);

      // 获取详情（含 HTML 和截图 URL）
      const detail = await retry(() =>
        client.callTool("get_screen", { screen_id: screenId })
      );

      // 下载截图
      if (detail.image_url) {
        await download(detail.image_url, join(OUTPUT_DIR, `${s.id}.png`));
        console.log(`   🖼  ${s.id}.png`);
      } else {
        console.log(`   ⚠️  无截图`);
      }

      // 下载 HTML
      if (detail.html_url) {
        await download(detail.html_url, join(OUTPUT_DIR, `${s.id}.html`));
        console.log(`   📝 ${s.id}.html`);
      }

      console.log(`[${n}/${SCREENS.length}] ✅ ${s.name} 完成\n`);
    } catch (err) {
      console.error(`[${n}/${SCREENS.length}] ❌ ${s.name} 失败: ${err.message}\n`);
    }
  }

  await client.close();
  console.log("🎉 全部完成！");
  console.log(`📂 ${OUTPUT_DIR}`);
}

main().catch((err) => {
  console.error("💥 脚本失败:", err.message);
  process.exit(1);
});
