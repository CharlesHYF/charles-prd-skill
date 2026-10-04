/**
 * 用 capture.mjs 量好的坐标生成界面标注图，并写回 tasks.md 的界面小节
 * 标注清单只写元素文案与说明，坐标来自 _coords.json，不手写也不重跑浏览器
 * 创建日期：2026-09-22
 * 修改日期：2026-10-04
 */

import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { dirname, resolve, relative, join } from "node:path";
import { prototypeFingerprint, prototypeRootOf } from "./fingerprint.mjs";

const COORDS_NAME = "_coords.json";

// 截图四周留一圈边，并描一道浅灰框把截图与白底分开
const PAD = 18;

// 图区按截图视口定宽，裁剪过的小截图等比放大填满，否则角标相对截图太大
const SHOT_WIDTHS = {
	desktop: 1440,
	mobile: 750,
};
const DEFAULT_VIEWPORT = "desktop";
const MAX_ZOOM = 2.6;

// 标注图在 PDF 里占满 174mm 正文宽度，截图高度超过宽度这个倍数就放不进一页，必须按区块裁剪分张
const MAX_ASPECT = 1.25;

// 序号角标的尺寸按缩到 174mm 后仍能读出编号来定
const NUM_RADIUS = 22;
const NUM_TEXT_SIZE = 26;

// 元素小于这个尺寸时编号角标放到框外，否则角标会把元素本身盖住
const SMALL_BOX = 42;

// 这几类元素每个都必须有标注，漏标就拒绝出图；导航、表头、指标卡与区块不强制
const REQUIRED_KINDS = ["btn", "field", "link"];

const usage = `用法: annotate.mjs <标注清单.json...>

标注清单与截图清单同目录，按元素文案挑要标的东西，不写坐标也不写选择器：

{
  "shot": "list",
  "inject": "../tasks.md",
  "mark": "list",
  "marks": [
    { "el": "筛选条", "note": "订单号支持前缀匹配。" },
    { "el": "批量作废", "kind": "btn", "steps": ["未勾选时置灰", "点击后弹二次确认"] },
    { "el": "checkbox", "kind": "field", "label": "全选", "note": "只选中当前页" }
  ],
  "skip": [
    { "el": "全选", "kind": "field", "reason": "行为与表头勾选一致，已在表头标注" }
  ]
}

先跑 capture.mjs 量坐标，本脚本只读 _coords.json，不再打开浏览器。
按钮、输入控件与链接每个都要有标注，确实不标的写进 skip 并给出 reason。
生成的 SVG 与编号说明写进 inject 指向文档里 <!--annotation:mark--> 与 <!--/annotation--> 之间。`;

const args = process.argv.slice(2);

if (args.length === 0 || args.includes("--help")) {
	console.log(usage);
	process.exit(args.length === 0 ? 2 : 0);
}

const escape = (text) => text
	.replace(/&/g, "&amp;")
	.replace(/</g, "&lt;")
	.replace(/>/g, "&gt;");

const matches = (el, target) => {

	if (target.kind && el.kind !== target.kind) {
		return false;
	}

	return el.txt === target.el || el.txt.includes(target.el);
};

// 按文案挑元素：kind 可选，同名多个时用 index 指定第几个
const pick = (els, mark, shot) => {
	const candidates = els.filter((el) => matches(el, mark));

	if (candidates.length === 0) {
		const hint = els.map((el) => `${el.kind}:${el.txt}`).slice(0, 40).join("  ");
		throw new Error(`${shot} 里找不到元素"${mark.el}"${mark.kind ? `(kind=${mark.kind})` : ""}\n     可选元素：${hint}`);
	}

	const index = mark.index ?? 0;

	if (index >= candidates.length) {
		throw new Error(`${shot} 的"${mark.el}"只有 ${candidates.length} 个，取不到第 ${index + 1} 个`);
	}

	return candidates[index];
};

// 同类同文案的元素算一组，十行表格的十个"详情"链接标一条即覆盖整组
const groupKey = (el) => `${el.kind}|${el.txt}`;

const findUncovered = (els, picked, skips, shot) => {
	const covered = new Set(picked.map(groupKey));

	for (const skip of skips) {

		if (!skip.el || !skip.reason) {
			throw new Error(`${shot} 的 skip 每项都要有 el 与 reason，不说明理由的跳过等于漏标`);
		}
	}

	const uncovered = new Map();

	for (const el of els) {

		if (!REQUIRED_KINDS.includes(el.kind) || covered.has(groupKey(el))) {
			continue;
		}

		if (skips.some((skip) => matches(el, skip))) {
			continue;
		}

		uncovered.set(groupKey(el), `${el.kind}:${el.txt}`);
	}

	return [...uncovered.values()];
};

const buildNotes = (spec) => spec.marks.map((mark, index) => {
	const number = index + 1;
	const lines = [];
	const note = mark.note ? `：${mark.note}` : "";

	// 列表里显示的名字缺省就是元素文案，文案不可读（如 checkbox）时用 label 另起一个
	lines.push(`${number}. **${mark.label ?? mark.el}**${note}`);

	if (Array.isArray(mark.steps)) {
		mark.steps.forEach((step, stepIndex) => {
			lines.push(`   ${stepIndex + 1}. ${step}`);
		});
	}

	return lines.join("\n");
}).join("\n");

const buildSvg = (spec, coords, shot, imageHref) => {
	const { els } = coords;
	const aspect = coords.h / coords.w;

	if (aspect > MAX_ASPECT) {
		throw new Error(`${shot} 截图 ${coords.w}x${coords.h} 高宽比 ${aspect.toFixed(2)} 超过 ${MAX_ASPECT}，缩到正文宽度后放不进一页\n     在截图清单里用 crop 按区块分成多张截，每张单独标注`);
	}

	const shotWidth = SHOT_WIDTHS[coords.viewport ?? DEFAULT_VIEWPORT] ?? SHOT_WIDTHS[DEFAULT_VIEWPORT];
	const zoom = Math.min(MAX_ZOOM, Math.max(1, shotWidth / coords.w));
	const pageW = Math.round(coords.w * zoom);
	const pageH = Math.round(coords.h * zoom);

	const picked = spec.marks.map((mark) => pick(els, mark, shot));
	const uncovered = findUncovered(els, picked, spec.skip ?? [], shot);

	if (uncovered.length > 0) {
		throw new Error(`${shot} 有 ${uncovered.length} 个元素没有标注：${uncovered.join("  ")}\n     每个按钮、输入控件与链接都要有一条，确实不标的写进 skip 并给出 reason`);
	}

	// 编号按清单顺序，说明列表与角标一一对应；清单本身按界面从上到下、从左到右写
	const layer = picked.map((box, index) => {
		const number = index + 1;
		const scaled = {
			x: box.x * zoom + PAD,
			y: box.y * zoom + PAD,
			w: box.w * zoom,
			h: box.h * zoom,
		};
		const small = scaled.w < SMALL_BOX || scaled.h < SMALL_BOX;
		const badgeX = small ? scaled.x - NUM_RADIUS - 2 : scaled.x;
		const badgeY = small ? scaled.y - NUM_RADIUS - 2 : scaled.y;

		return `	<rect class="mk-box" x="${(scaled.x - 3).toFixed(1)}" y="${(scaled.y - 3).toFixed(1)}" width="${(scaled.w + 6).toFixed(1)}" height="${(scaled.h + 6).toFixed(1)}" rx="3"/>
	<circle class="mk-bg" cx="${badgeX.toFixed(1)}" cy="${badgeY.toFixed(1)}" r="${NUM_RADIUS}"/>
	<text class="mk-no" x="${badgeX.toFixed(1)}" y="${(badgeY + NUM_TEXT_SIZE * 0.35).toFixed(1)}">${number}</text>`;
	}).join("\n");

	const title = spec.title ?? shot;
	const canvasWidth = pageW + PAD * 2;
	const canvasHeight = pageH + PAD * 2;

	return `<svg class="annotation" viewBox="0 0 ${canvasWidth} ${canvasHeight}" role="img" aria-label="${escape(title)}界面标注">
	<style>
		.annotation .mk-box { fill: none; stroke: #d93025; stroke-width: 3; }
		.annotation .mk-bg { fill: #d93025; stroke: #ffffff; stroke-width: 2; }
		.annotation .mk-no { font-size: ${NUM_TEXT_SIZE}px; font-weight: 700; fill: #ffffff; text-anchor: middle; }
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

	// 原型改过而没重跑 capture 的话，坐标是旧的，画出来整体错位且看不出来
	const shotSpec = join(dir, `${shot}.json`);

	if (existsSync(shotSpec)) {
		const page = resolve(dir, JSON.parse(readFileSync(shotSpec, "utf8")).page ?? "");
		const protoRoot = prototypeRootOf(page);

		if (existsSync(protoRoot) && all[shot].fingerprint && prototypeFingerprint(protoRoot) !== all[shot].fingerprint) {
			console.error(`[NG] ${shot}: 原型自 ${all[shot].capturedAt ?? "上次截图"} 之后改过，坐标已过期`);
			console.error(`     先重跑 node tools/capture.mjs ${shot}.json 再生成标注`);
			failed += 1;
			continue;
		}
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

	// 说明写成 SVG 下方的 Markdown 编号列表，PDF 里按正文字号排，截图因此能占满正文宽度
	const block = `${svg}\n\n${buildNotes(spec)}\n`;
	const updated = `${doc.slice(0, start + open.length)}\n${block}${doc.slice(end)}`;
	writeFileSync(docFile, updated, "utf8");
	console.log(`[OK] ${shot} 标注 ${spec.marks.length} 处，已写进 ${spec.inject} 的 ${mark} 标记块`);
}

if (failed > 0) {
	console.error(`[NG] ${failed} 份清单未完成`);
	process.exit(1);
}
