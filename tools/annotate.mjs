/**
 * 在原型页面上自动生成界面标注图
 * 框选位置由 CSS 选择器查 DOM 得到，原型改了重跑即可，不用手写坐标
 * 创建日期：2026-09-22
 * 修改日期：2026-09-22
 */

import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { dirname, resolve, basename } from "node:path";
import puppeteer from "puppeteer-core";

const CHROME_CANDIDATES = [
	"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
	"/Applications/Chromium.app/Contents/MacOS/Chromium",
	"/usr/bin/google-chrome",
	"/usr/bin/chromium",
];

const VIEWPORT_WIDTH = 1440;
const VIEWPORT_HEIGHT = 900;
const SCALE = 2;

// 图在 PDF 里被缩到正文版心宽度，所以说明区要宽、字号要大，缩完才看得清
const GUTTER = 1000;
const TEXT_SIZE = 27;
const LINE_HEIGHT = 38;
const STEP_INDENT = 40;
const LABEL_GAP = 34;
const LABEL_TOP = 52;

// 截图四周留一圈边，并描一道浅灰框把截图与白底分开
const PAD = 18;

// 序号圆点的半径与它到正文左边的距离
const NUM_RADIUS = 15;
const NUM_TEXT_SIZE = 18;
const NUM_OFFSET = 44;

// 元素小于这个尺寸时编号角标放到框外，否则角标会把元素本身盖住
const SMALL_BOX = 34;

// 末行只剩这么少的字就并回上一行，避免一两个字孤零零占一行
const ORPHAN_LIMIT = 2;

const usage = `用法: annotate.mjs <标注清单.json> [--output <输出.svg>]

标注清单格式：
{
  "page": "prototype/pages/list.html",
  "title": "订单列表页",
  "setup": ["[data-open-modal=deleteModal]"],
  "marks": [
    { "selector": ".filters", "note": "筛选条，订单号支持前缀匹配" },
    { "selector": ".btn--danger", "steps": ["勾选至少一行", "点击后弹二次确认", "确认后逐条作废"] }
  ]
}

selector 找不到元素时直接报错退出，避免生成一张框错位置的图。`;

const args = process.argv.slice(2);

if (args.length === 0 || args.includes("--help")) {
	console.log(usage);
	process.exit(args.length === 0 ? 2 : 0);
}

const listFile = resolve(args[0]);
const outIndex = args.indexOf("--output");
const outFile = outIndex >= 0 ? resolve(args[outIndex + 1]) : listFile.replace(/\.json$/, ".svg");

if (!existsSync(listFile)) {
	console.error(`[NG] 找不到标注清单：${listFile}`);
	process.exit(2);
}

const spec = JSON.parse(readFileSync(listFile, "utf8"));
const pageFile = resolve(dirname(listFile), spec.page);

if (!existsSync(pageFile)) {
	console.error(`[NG] 标注清单里的 page 不存在：${pageFile}`);
	process.exit(2);
}

const chrome = CHROME_CANDIDATES.find((path) => existsSync(path));

if (!chrome) {
	console.error("[NG] 没找到可用的 Chrome，请安装 Google Chrome 或 Chromium");
	process.exit(2);
}

// 中文与全角标点按一个字宽计，ASCII 按 0.62 字宽计，宁可估宽也不要估窄撑出画布
const textWidth = (text) => {
	let width = 0;

	for (const char of text) {
		width += char.charCodeAt(0) > 0x2e80 ? TEXT_SIZE : TEXT_SIZE * 0.62;
	}

	return width;
};

// 这些标点不能出现在行首，超宽也要跟着上一行走
const NO_LINE_START = "。，、；：？！）》」』%”’.,;:?!)]}";

// firstWidth 给首行单独的可用宽度，步骤的 "1. " 前缀要占掉一截
const wrap = (text, maxWidth, firstWidth = maxWidth) => {
	const lines = [];
	let current = "";

	for (const char of text) {
		const limit = lines.length === 0 ? firstWidth : maxWidth;

		if (textWidth(current + char) > limit && current && !NO_LINE_START.includes(char)) {
			lines.push(current);
			current = char;
			continue;
		}

		current += char;
	}

	if (current) {
		lines.push(current);
	}

	// 末行是孤字时并回上一行，宁可稍微超宽也不留一个字单独一行
	if (lines.length > 1 && [...lines[lines.length - 1]].length <= ORPHAN_LIMIT) {
		const orphan = lines.pop();
		lines[lines.length - 1] += orphan;
	}

	return lines;
};

const escape = (text) => text
	.replace(/&/g, "&amp;")
	.replace(/</g, "&lt;")
	.replace(/>/g, "&gt;");

const browser = await puppeteer.launch({ executablePath: chrome, headless: "new", args: ["--no-sandbox"] });
const page = await browser.newPage();
await page.setViewport({ width: VIEWPORT_WIDTH, height: VIEWPORT_HEIGHT, deviceScaleFactor: SCALE });
await page.goto(`file://${pageFile}`, { waitUntil: "networkidle0" });

if (spec.state) {
	await page.evaluate((state) => {
		document.querySelector(`[data-state-btn="${state}"]`)?.click();
	}, spec.state);
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

// setup 按顺序点击，用来标注弹窗这类需要先触发才出现的界面
for (const selector of spec.setup ?? []) {
	const clicked = await page.evaluate((target) => {
		const element = document.querySelector(target);

		if (!element) {
			return false;
		}

		element.click();
		return true;
	}, selector);

	if (!clicked) {
		await browser.close();
		console.error(`[NG] setup 里的选择器找不到元素：${selector}`);
		process.exit(1);
	}

	await new Promise((done) => setTimeout(done, 200));
}

await new Promise((done) => setTimeout(done, 300));

const boxes = await page.evaluate((selectors) => selectors.map((selector) => {
	const element = document.querySelector(selector);

	if (!element) {
		return null;
	}

	const rect = element.getBoundingClientRect();
	return { x: rect.x, y: rect.y + window.scrollY, w: rect.width, h: rect.height };
}), spec.marks.map((mark) => mark.selector));

const missing = spec.marks.filter((mark, index) => boxes[index] === null);

if (missing.length > 0) {
	await browser.close();
	console.error("[NG] 以下选择器在原型页里找不到元素，标注图未生成：");
	missing.forEach((mark) => console.error(`     ${mark.selector}`));
	process.exit(1);
}

const pageSize = await page.evaluate(() => ({
	w: document.documentElement.scrollWidth,
	h: document.documentElement.scrollHeight,
}));
const shot = await page.screenshot({ encoding: "base64", fullPage: true });
await browser.close();

const textX = PAD + pageSize.w + NUM_OFFSET + 44;
const maxTextWidth = GUTTER - (textX - PAD - pageSize.w) - 36;

// 先算每条说明占多高，再按元素位置从上到下排，避免标签重叠与引线交叉
const labels = spec.marks.map((mark, index) => {
	const box = boxes[index];
	const lines = [];

	if (mark.note) {
		wrap(mark.note, maxTextWidth).forEach((line) => lines.push({ text: line, indent: 0 }));
	}

	if (Array.isArray(mark.steps)) {
		mark.steps.forEach((step, stepIndex) => {
			const prefix = `${stepIndex + 1}. `;
			const wrapped = wrap(step, maxTextWidth - STEP_INDENT, maxTextWidth - textWidth(prefix));
			wrapped.forEach((line, lineIndex) => lines.push({
				text: lineIndex === 0 ? `${prefix}${line}` : line,
				indent: lineIndex === 0 ? 0 : STEP_INDENT,
			}));
		});
	}

	return {
		index,
		box: { x: box.x + PAD, y: box.y + PAD, w: box.w, h: box.h },
		lines,
		height: lines.length * LINE_HEIGHT,
		anchorY: box.y + PAD + box.h / 2,
	};
});

labels.sort((a, b) => a.anchorY - b.anchorY);

let cursor = LABEL_TOP;

for (const label of labels) {
	label.top = Math.max(cursor, label.anchorY - label.height / 2);
	cursor = label.top + label.height + LABEL_GAP;
}

const canvasWidth = PAD + pageSize.w + GUTTER;
const canvasHeight = Math.max(pageSize.h + PAD * 2, cursor + LABEL_TOP);

const layer = labels.map((label, order) => {
	const number = order + 1;
	const box = label.box;
	const labelY = label.top + LINE_HEIGHT * 0.75;
	const numX = textX - NUM_OFFSET;
	const text = label.lines
		.map((line, lineIndex) => `<tspan x="${(textX + line.indent).toFixed(1)}" dy="${lineIndex === 0 ? 0 : LINE_HEIGHT}">${escape(line.text)}</tspan>`)
		.join("");

	// 引线横穿界面会把内容盖住，多条还会交叉，改成两处相同编号对应
	const small = box.w < SMALL_BOX || box.h < SMALL_BOX;
	const badgeX = small ? box.x - NUM_RADIUS - 2 : box.x;
	const badgeY = small ? box.y - NUM_RADIUS - 2 : box.y;

	return `	<g>
		<rect class="box-mark" x="${(box.x - 3).toFixed(1)}" y="${(box.y - 3).toFixed(1)}" width="${(box.w + 6).toFixed(1)}" height="${(box.h + 6).toFixed(1)}" rx="4"/>
		<circle class="num-bg" cx="${badgeX.toFixed(1)}" cy="${badgeY.toFixed(1)}" r="${NUM_RADIUS}"/>
		<text class="num-text" x="${badgeX.toFixed(1)}" y="${(badgeY + NUM_TEXT_SIZE * 0.35).toFixed(1)}">${number}</text>
		<circle class="num-bg" cx="${numX.toFixed(1)}" cy="${(labelY - TEXT_SIZE * 0.32).toFixed(1)}" r="${NUM_RADIUS}"/>
		<text class="num-text" x="${numX.toFixed(1)}" y="${(labelY - TEXT_SIZE * 0.32 + NUM_TEXT_SIZE * 0.35).toFixed(1)}">${number}</text>
		<text class="mark" x="${textX.toFixed(1)}" y="${labelY.toFixed(1)}">${text}</text>
	</g>`;
}).join("\n");

const label = spec.title ? `${spec.title}界面标注` : `${basename(pageFile)} 界面标注`;

const svg = `<svg class="annotation" viewBox="0 0 ${canvasWidth} ${canvasHeight.toFixed(0)}" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="${escape(label)}">
	<style>
		.annotation .box-mark { fill: none; stroke: #d93025; stroke-width: 3; }
		.annotation .shot-edge { fill: none; stroke: #dfe3ea; stroke-width: 1; }
		.annotation .mark { font-size: ${TEXT_SIZE}px; fill: #d93025; font-family: -apple-system, "PingFang SC", sans-serif; }
		.annotation .num-bg { fill: #d93025; stroke: #ffffff; stroke-width: 1.5; }
		.annotation .num-text { font-size: ${NUM_TEXT_SIZE}px; font-weight: 700; fill: #ffffff; text-anchor: middle; font-family: -apple-system, "PingFang SC", sans-serif; }
	</style>
	<rect x="0" y="0" width="${canvasWidth}" height="${canvasHeight.toFixed(0)}" fill="#ffffff"/>
	<image x="${PAD}" y="${PAD}" width="${pageSize.w}" height="${pageSize.h}" href="data:image/png;base64,${shot}"/>
	<rect class="shot-edge" x="${PAD}" y="${PAD}" width="${pageSize.w}" height="${pageSize.h}"/>
${layer}
</svg>
`;

writeFileSync(outFile, svg, "utf8");
console.log(`[OK] ${outFile}`);
console.log(`     标注 ${spec.marks.length} 处，画布 ${canvasWidth}x${canvasHeight.toFixed(0)}，体积 ${(svg.length / 1024).toFixed(0)} KB`);
