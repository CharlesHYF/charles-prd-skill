/**
 * 用 capture.mjs 量好的坐标生成界面标注图，并写回 tasks.md 的界面小节
 * 标注清单只写元素文案与说明，坐标来自 _coords.json，不手写也不重跑浏览器
 * 创建日期：2026-09-22
 * 修改日期：2026-09-22
 */

import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { dirname, resolve, relative, join } from "node:path";

const COORDS_NAME = "_coords.json";

// 图在 PDF 里被缩到正文版心宽度，所以说明区要宽、字号要大，缩完才看得清
const GUTTER = 1000;
const TEXT_SIZE = 27;
const LINE_HEIGHT = 38;
const STEP_INDENT = 40;
const LABEL_GAP = 34;
const LABEL_TOP = 52;

// 截图四周留一圈边，并描一道浅灰框把截图与白底分开
const PAD = 18;

// 图区固定这么宽，裁剪过的小截图等比放大填满，否则它在画布里占比太低反而更小
const SHOT_WIDTH = 1440;
const MAX_ZOOM = 2.6;

// 序号圆点的半径与它到正文左边的距离
const NUM_RADIUS = 15;
const NUM_TEXT_SIZE = 18;
const NUM_OFFSET = 44;

// 元素小于这个尺寸时编号角标放到框外，否则角标会把元素本身盖住
const SMALL_BOX = 42;

// 末行只剩这么少的字就并回上一行，避免一两个字孤零零占一行
const ORPHAN_LIMIT = 2;

// 这些标点不能出现在行首，超宽也要跟着上一行走
const NO_LINE_START = "。，、；：？！）》」』%”’.,;:?!)]}";

const usage = `用法: annotate.mjs <标注清单.json...>

标注清单与截图清单同目录，按元素文案挑要标的东西，不写坐标也不写选择器：

{
  "shot": "list",
  "inject": "../tasks.md",
  "mark": "list",
  "marks": [
    { "el": "筛选条", "note": "订单号支持前缀匹配。" },
    { "el": "批量作废", "kind": "btn", "steps": ["未勾选时置灰", "点击后弹二次确认"] }
  ]
}

先跑 capture.mjs 量坐标，本脚本只读 _coords.json，不再打开浏览器。
生成的 SVG 写进 inject 指向文档里 <!--annotation:mark--> 与 <!--/annotation--> 之间。`;

const args = process.argv.slice(2);

if (args.length === 0 || args.includes("--help")) {
	console.log(usage);
	process.exit(args.length === 0 ? 2 : 0);
}

// 中文与全角标点按一个字宽计，ASCII 按 0.62 字宽计，宁可估宽也不要估窄撑出画布
const textWidth = (text) => {
	let width = 0;

	for (const char of text) {
		width += char.charCodeAt(0) > 0x2e80 ? TEXT_SIZE : TEXT_SIZE * 0.62;
	}

	return width;
};

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

	if (lines.length > 1 && [...lines[lines.length - 1]].length <= ORPHAN_LIMIT) {
		lines[lines.length - 2] += lines.pop();
	}

	return lines;
};

const escape = (text) => text
	.replace(/&/g, "&amp;")
	.replace(/</g, "&lt;")
	.replace(/>/g, "&gt;");

// 按文案挑元素：kind 可选，同名多个时用 index 指定第几个
const pick = (els, mark, shot) => {
	const candidates = els.filter((el) => {

		if (mark.kind && el.kind !== mark.kind) {
			return false;
		}

		return el.txt === mark.el || el.txt.includes(mark.el);
	});

	if (candidates.length === 0) {
		const hint = els.map((el) => `${el.kind}:${el.txt}`).slice(0, 40).join("  ");
		throw new Error(`${shot} 里找不到元素「${mark.el}」${mark.kind ? `(kind=${mark.kind})` : ""}\n     可选元素：${hint}`);
	}

	const index = mark.index ?? 0;

	if (index >= candidates.length) {
		throw new Error(`${shot} 的「${mark.el}」只有 ${candidates.length} 个，取不到第 ${index + 1} 个`);
	}

	return candidates[index];
};

const buildSvg = (spec, coords, shot, imageHref) => {
	const { els } = coords;
	const zoom = Math.min(MAX_ZOOM, Math.max(1, SHOT_WIDTH / coords.w));
	const pageW = Math.round(coords.w * zoom);
	const pageH = Math.round(coords.h * zoom);
	const textX = PAD + pageW + NUM_OFFSET + 44;
	const maxTextWidth = GUTTER - (textX - PAD - pageW) - 36;

	const labels = spec.marks.map((mark, index) => {
		const box = pick(els, mark, shot);
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

		const scaled = {
			x: box.x * zoom + PAD,
			y: box.y * zoom + PAD,
			w: box.w * zoom,
			h: box.h * zoom,
		};

		return {
			index,
			box: scaled,
			lines,
			height: lines.length * LINE_HEIGHT,
			anchorY: scaled.y + scaled.h / 2,
		};
	});

	labels.sort((a, b) => a.anchorY - b.anchorY);

	let cursor = LABEL_TOP;

	for (const label of labels) {
		label.top = Math.max(cursor, label.anchorY - label.height / 2);
		cursor = label.top + label.height + LABEL_GAP;
	}

	const canvasWidth = PAD + pageW + GUTTER;
	const canvasHeight = Math.round(Math.max(pageH + PAD * 2, cursor + LABEL_TOP));

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
		const numY = labelY - TEXT_SIZE * 0.32;

		return `	<rect class="mk-box" x="${(box.x - 3).toFixed(1)}" y="${(box.y - 3).toFixed(1)}" width="${(box.w + 6).toFixed(1)}" height="${(box.h + 6).toFixed(1)}" rx="3"/>
	<circle class="mk-bg" cx="${badgeX.toFixed(1)}" cy="${badgeY.toFixed(1)}" r="${NUM_RADIUS}"/>
	<text class="mk-no" x="${badgeX.toFixed(1)}" y="${(badgeY + NUM_TEXT_SIZE * 0.35).toFixed(1)}">${number}</text>
	<circle class="mk-bg" cx="${numX.toFixed(1)}" cy="${numY.toFixed(1)}" r="${NUM_RADIUS}"/>
	<text class="mk-no" x="${numX.toFixed(1)}" y="${(numY + NUM_TEXT_SIZE * 0.35).toFixed(1)}">${number}</text>
	<text class="mk-t" x="${textX.toFixed(1)}" y="${labelY.toFixed(1)}">${text}</text>`;
	}).join("\n");

	const title = spec.title ?? shot;

	return `<svg class="annotation" viewBox="0 0 ${canvasWidth} ${canvasHeight}" role="img" aria-label="${escape(title)}界面标注">
	<style>
		.annotation .mk-box { fill: none; stroke: #d93025; stroke-width: 3; }
		.annotation .mk-bg { fill: #d93025; stroke: #ffffff; stroke-width: 1.5; }
		.annotation .mk-no { font-size: ${NUM_TEXT_SIZE}px; font-weight: 700; fill: #ffffff; text-anchor: middle; }
		.annotation .mk-t { font-size: ${TEXT_SIZE}px; fill: #d93025; }
		.annotation .shot-b { fill: none; stroke: #dfe3ea; stroke-width: 1; }
	</style>
	<image href="${imageHref}" x="${PAD}" y="${PAD}" width="${pageW}" height="${pageH}"/>
	<rect class="shot-b" x="${PAD}" y="${PAD}" width="${pageW}" height="${pageH}"/>
${layer}
</svg>`;
};

let failed = 0;

for (const arg of args) {
	const specFile = resolve(arg);

	if (!existsSync(specFile)) {
		console.error(`[NG] 找不到标注清单：${specFile}`);
		failed += 1;
		continue;
	}

	const spec = JSON.parse(readFileSync(specFile, "utf8"));
	const dir = dirname(specFile);
	const shot = spec.shot;
	const coordsFile = join(dir, COORDS_NAME);

	if (!existsSync(coordsFile)) {
		console.error(`[NG] ${shot}: 还没有 ${COORDS_NAME}，先跑 capture.mjs`);
		failed += 1;
		continue;
	}

	const all = JSON.parse(readFileSync(coordsFile, "utf8"));

	if (!all[shot]) {
		console.error(`[NG] ${COORDS_NAME} 里没有 ${shot} 的坐标，先跑 capture.mjs ${shot}.json`);
		failed += 1;
		continue;
	}

	if (!spec.inject) {
		console.error(`[NG] ${shot}: 清单缺 inject，不知道要写进哪个文档`);
		failed += 1;
		continue;
	}

	const docFile = resolve(dir, spec.inject);

	if (!existsSync(docFile)) {
		console.error(`[NG] ${shot}: inject 指向的文档不存在 ${docFile}`);
		failed += 1;
		continue;
	}

	const mark = spec.mark ?? shot;
	const imageHref = relative(dirname(docFile), join(dir, `${shot}.png`));

	let svg;

	try {
		svg = buildSvg(spec, all[shot], shot, imageHref);
	} catch (error) {
		console.error(`[NG] ${error.message}`);
		failed += 1;
		continue;
	}

	const doc = readFileSync(docFile, "utf8");
	const open = `<!--annotation:${mark}-->`;
	const close = "<!--/annotation-->";
	const start = doc.indexOf(open);
	const end = doc.indexOf(close, start);

	if (start < 0 || end < 0) {
		console.error(`[NG] ${shot}: ${spec.inject} 里找不到 ${open} 与 ${close} 这对标记`);
		failed += 1;
		continue;
	}

	const updated = `${doc.slice(0, start + open.length)}\n${svg}\n${doc.slice(end)}`;
	writeFileSync(docFile, updated, "utf8");
	console.log(`[OK] ${shot} 标注 ${spec.marks.length} 处，已写进 ${spec.inject} 的 ${mark} 标记块`);
}

if (failed > 0) {
	console.error(`[NG] ${failed} 份清单未完成`);
	process.exit(1);
}
