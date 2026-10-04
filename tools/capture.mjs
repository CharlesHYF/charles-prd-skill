/**
 * 截原型页面并同时量取元素坐标
 * 截图与坐标在同一时刻产出，严格对应，之后生成标注图不需要再跑浏览器
 * 创建日期：2026-09-22
 * 修改日期：2026-10-04
 */

import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { dirname, resolve, join } from "node:path";
import puppeteer from "puppeteer-core";
import { prototypeFingerprint, prototypeRootOf } from "./fingerprint.mjs";

const CHROME_CANDIDATES = [
	"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
	"/Applications/Chromium.app/Contents/MacOS/Chromium",
	"/usr/bin/google-chrome",
	"/usr/bin/chromium",
];

// 截图清单的 viewport 字段取值：桌面按 1440 宽截，手机按 375 宽截
const VIEWPORTS = {
	desktop: {
		width: 1440,
		height: 900,
		deviceScaleFactor: 2,
	},
	mobile: {
		width: 375,
		height: 812,
		deviceScaleFactor: 3,
		isMobile: true,
		hasTouch: true,
	},
};
const DEFAULT_VIEWPORT = "desktop";
const COORDS_NAME = "_coords.json";
const JSON_INDENT = 2;

// 标注图在 PDF 里占满正文宽度，截图高度超过宽度这个倍数就放不进一页；与 annotate.mjs 保持一致
const MAX_ASPECT = 1.25;

const usage = `用法: capture.mjs <截图清单.json...>

截图清单放在 diagrams/ 下，一份对应一张截图：

{
  "shot": "list",
  "page": "../prototype/pages/list.html",
  "title": "订单列表页",
  "role": "manager",
  "state": "success",
  "viewport": "desktop",
  "setup": ["[data-open-modal=deleteModal]"],
  "crop": ".modal",
  "cropPad": 60
}

viewport 取 desktop（缺省）或 mobile。
产出同目录下的 <shot>.png、<shot>.md 来源说明，以及 _coords.json 里的一个条目。`;

const args = process.argv.slice(2);

if (args.length === 0 || args.includes("--help")) {
	console.log(usage);
	process.exit(args.length === 0 ? 2 : 0);
}

const chrome = CHROME_CANDIDATES.find((path) => existsSync(path));

if (!chrome) {
	console.error("[NG] 没找到可用的 Chrome，请安装 Google Chrome 或 Chromium");
	process.exit(2);
}

// 页面上值得标注的元素，按类型归类，标注清单按文案挑选
// 侧边栏与顶部导航里的链接归为 menu，不然每页都要把整列导航逐个标一遍
const COLLECT = `() => {
	const kindOf = (el) => {
		if (el.matches("button")) return "btn";
		if (el.matches("a") && el.closest("nav, aside, .sidebar, .topbar__nav")) return "menu";
		if (el.matches("a")) return "link";
		if (el.matches("input, select, textarea")) return "field";
		if (el.matches("th")) return "th";
		if (el.matches(".kpi")) return "kpi";
		if (el.matches(".filters, .pager, .modal, .chart-grid > .card, .state-block")) return "box";
		return "";
	};

	const label = (el) => {
		if (el.matches("input, textarea")) {
			const wrap = el.closest(".field");
			const own = wrap?.querySelector("label")?.textContent?.trim();
			return own || el.getAttribute("placeholder") || el.getAttribute("type") || "输入框";
		}

		if (el.matches("select")) {
			const wrap = el.closest(".field");
			const own = wrap?.querySelector("label")?.textContent?.trim();
			return own || el.options[el.selectedIndex]?.text?.trim() || "下拉";
		}

		if (el.matches(".kpi")) {
			return el.querySelector(".kpi__label")?.textContent?.trim() || "指标卡";
		}

		if (el.matches(".modal")) {
			return el.querySelector("h3")?.textContent?.trim() || "弹窗";
		}

		if (el.matches(".chart-grid > .card")) {
			return el.querySelector("h2")?.textContent?.trim() || "图表";
		}

		if (el.matches(".filters")) return "筛选条";
		if (el.matches(".pager")) return "分页";
		if (el.matches(".state-block")) return el.textContent.trim().slice(0, 20) || "状态块";

		return el.textContent.replace(/\\s+/g, " ").trim().slice(0, 24);
	};

	const seen = new Set();
	const els = [];

	for (const el of document.querySelectorAll("button, a, input, select, textarea, th, .kpi, .filters, .pager, .modal, .chart-grid > .card, .state-block")) {
		const kind = kindOf(el);

		if (!kind || el.hidden || el.closest("[hidden]")) {
			continue;
		}

		// 角色下拉是原型的切换 hook 不是产品界面；分页里的页码按钮按整条分页标注，不逐个量
		if (el.matches("#roleSelect") || (el.closest(".pager") && !el.matches(".pager"))) {
			continue;
		}

		const rect = el.getBoundingClientRect();

		if (rect.width < 4 || rect.height < 4) {
			continue;
		}

		const txt = label(el);
		const key = kind + "|" + txt + "|" + Math.round(rect.x) + "," + Math.round(rect.y);

		if (seen.has(key)) {
			continue;
		}

		seen.add(key);
		els.push({
			kind,
			txt,
			x: Math.round(rect.x),
			y: Math.round(rect.y + window.scrollY),
			w: Math.round(rect.width),
			h: Math.round(rect.height),
		});
	}

	return {
		w: document.documentElement.scrollWidth,
		h: document.documentElement.scrollHeight,
		els,
	};
}`;

const browser = await puppeteer.launch({ executablePath: chrome, headless: "new", args: ["--no-sandbox"] });
let failed = 0;

for (const arg of args) {
	const specFile = resolve(arg);

	if (!existsSync(specFile)) {
		console.error(`[NG] 找不到截图清单：${specFile}`);
		failed += 1;
		continue;
	}

	const spec = JSON.parse(readFileSync(specFile, "utf8"));
	const dir = dirname(specFile);
	const shot = spec.shot ?? specFile.replace(/.*\//, "").replace(/\.json$/, "");
	const pageFile = resolve(dir, spec.page);

	if (!existsSync(pageFile)) {
		console.error(`[NG] ${shot}: 原型页面不存在 ${pageFile}`);
		failed += 1;
		continue;
	}

	const viewportName = spec.viewport ?? DEFAULT_VIEWPORT;
	const viewport = VIEWPORTS[viewportName];

	if (!viewport) {
		console.error(`[NG] ${shot}: viewport 取值不合法 ${viewportName}，可选 ${Object.keys(VIEWPORTS).join(" / ")}`);
		failed += 1;
		continue;
	}

	const protoRoot = prototypeRootOf(pageFile);

	const page = await browser.newPage();
	await page.setViewport(viewport);
	await page.goto(`file://${pageFile}`, { waitUntil: "networkidle0" });

	if (spec.state) {
		await page.evaluate((state) => document.querySelector(`[data-state-btn="${state}"]`)?.click(), spec.state);
	}

	if (spec.role) {
		await page.evaluate((role) => {
			const select = document.querySelector("#roleSelect");

			if (select) {
				select.value = role;
				select.dispatchEvent(new Event("change"));
			}
		}, spec.role);
	}

	let setupOk = true;

	for (const selector of spec.setup ?? []) {
		const clicked = await page.evaluate((target) => {
			const el = document.querySelector(target);

			if (!el) {
				return false;
			}

			el.click();
			return true;
		}, selector);

		if (!clicked) {
			console.error(`[NG] ${shot}: setup 选择器找不到元素 ${selector}`);
			setupOk = false;
			break;
		}

		await new Promise((done) => setTimeout(done, 200));
	}

	if (!setupOk) {
		await page.close();
		failed += 1;
		continue;
	}

	// 状态切换条是原型自带的调试工具，不属于产品界面，截图前移除
	await page.evaluate(() => document.querySelector(".statebar")?.remove());
	await new Promise((done) => setTimeout(done, 300));

	const measured = await page.evaluate(`(${COLLECT})()`);

	// 弹窗这类只占页面中间一小块的界面，整页截完在 A4 上小到读不出文案，裁到它周边
	let clip = null;

	if (spec.crop) {
		clip = await page.evaluate((selector, pad) => {
			const el = document.querySelector(selector);

			if (!el) {
				return null;
			}

			const rect = el.getBoundingClientRect();
			const left = Math.max(0, rect.x - pad);
			const top = Math.max(0, rect.y + window.scrollY - pad);
			return {
				x: Math.round(left),
				y: Math.round(top),
				width: Math.round(Math.min(document.documentElement.scrollWidth - left, rect.width + pad * 2)),
				height: Math.round(Math.min(document.documentElement.scrollHeight - top, rect.height + pad * 2)),
			};
		}, spec.crop, spec.cropPad ?? 60);

		if (!clip) {
			console.error(`[NG] ${shot}: crop 选择器找不到元素 ${spec.crop}`);
			await page.close();
			failed += 1;
			continue;
		}
	}

	await page.screenshot(clip
		? { path: join(dir, `${shot}.png`), clip }
		: { path: join(dir, `${shot}.png`), fullPage: true });
	await page.close();

	// 裁剪后坐标要跟着平移，落在裁剪区外的元素标不到，直接剔掉
	if (clip) {
		measured.w = clip.width;
		measured.h = clip.height;
		measured.els = measured.els
			.map((el) => ({ ...el, x: el.x - clip.x, y: el.y - clip.y }))
			.filter((el) => el.x + el.w > 0 && el.y + el.h > 0 && el.x < clip.width && el.y < clip.height);
	}

	const coordsFile = join(dir, COORDS_NAME);
	const coords = existsSync(coordsFile) ? JSON.parse(readFileSync(coordsFile, "utf8")) : {};
	measured.viewport = viewportName;
	measured.fingerprint = prototypeFingerprint(protoRoot);
	measured.capturedAt = new Date().toISOString().slice(0, 19).replace("T", " ");
	coords[shot] = measured;
	writeFileSync(coordsFile, `${JSON.stringify(coords, null, JSON_INDENT)}\n`, "utf8");

	const today = new Date().toISOString().slice(0, 10);
	writeFileSync(join(dir, `${shot}.md`), `# ${shot} 原型截图

**来源**：本版原型 \`${spec.page}\`，由 \`tools/capture.mjs\` 自动截取。
**获取日期**：${today}
**视口**：${viewportName}，${viewport.width} 宽，deviceScaleFactor ${viewport.deviceScaleFactor}，截图前移除原型状态切换条。${spec.crop ? `\n**裁剪**：裁到 \`${spec.crop}\` 周边 ${spec.cropPad ?? 60}px。` : ""}
**用途**：\`tasks.md\` 界面小节的标注底图。

截图时同步量取元素坐标写入 \`${COORDS_NAME}\`，标注框位置由该文件生成，不手写坐标。
原型改动后重跑 \`node tools/capture.mjs ${shot}.json\` 即可，截图与坐标不会脱节。
`, "utf8");

	console.log(`[OK] ${shot}.png  ${measured.w}x${measured.h}  量到 ${measured.els.length} 个元素`);

	if (measured.h / measured.w > MAX_ASPECT) {
		console.log(`[WARN] ${shot}: 高宽比 ${(measured.h / measured.w).toFixed(2)} 超过 ${MAX_ASPECT}，annotate.mjs 会拒绝出图；用 crop 按区块分成多张截`);
	}
}

// 坐标文件是位图之外的另一份产物，同样要有来源说明
const coordsNote = args
	.map((arg) => join(dirname(resolve(arg)), "_coords.md"))
	.find(Boolean);

if (coordsNote) {
	const today = new Date().toISOString().slice(0, 10);
	writeFileSync(coordsNote, `# ${COORDS_NAME} 元素坐标

**来源**：\`tools/capture.mjs\` 在截图同一时刻用 \`getBoundingClientRect()\` 量取，与同名 PNG 严格对应。
**获取日期**：${today}
**用途**：生成 \`tasks.md\` 界面标注的框选位置，避免手写坐标与原型脱节。

结构：\`{ "<截图名>": { w, h, viewport, els: [{ kind, txt, x, y, w, h }] } }\`，
\`kind\` 取值为 btn / link / menu / field / th / kpi / box。

标注清单按 \`txt\` 挑元素，同名多个时用 \`index\` 指定第几个，不写坐标。
`, "utf8");
}

await browser.close();

if (failed > 0) {
	console.error(`[NG] ${failed} 份清单未完成`);
	process.exit(1);
}
