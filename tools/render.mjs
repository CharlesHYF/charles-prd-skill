/**
 * 把 Markdown 渲染成带打印样式的单页 HTML
 * 创建日期：2026-09-21
 * 修改日期：2026-09-21
 */

import { readFileSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import MarkdownIt from "markdown-it";

const require = createRequire(import.meta.url);
const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const STYLE_PATH = resolve(SCRIPT_DIR, "../templates/export/style.css");
const MERMAID_THEME_PATH = resolve(SCRIPT_DIR, "../templates/export/mermaid-theme.json");

// Mermaid 与图标包都从本地依赖读取，导出过程不联网
const MERMAID_SOURCE = readFileSync(require.resolve("mermaid/dist/mermaid.min.js"), "utf8");
const ICON_PACK = readFileSync(require.resolve("@iconify-json/lucide/icons.json"), "utf8");

const REQ_ID_PATTERN = /\b(REQ-\d+\.\d+-\d{3})\b/g;
const TASK_ID_PATTERN = /\b(Task-\d{3})\b/g;

// 内联 SVG 里的空行会截断 Markdown 的 HTML 块，导致后半段被当成代码块输出
// 渲染前先把整块 SVG 换成注释占位符，渲染后再放回去
const SVG_BLOCK_PATTERN = /<svg[\s\S]*?<\/svg>/g;
const SVG_PLACEHOLDER_PATTERN = /<!--CHARLES-SVG-(\d+)-->/g;

// 标题数达到这个量才生成目录页，短文档加目录只是浪费一页
const TOC_MIN_HEADINGS = 8;
const HEADING_PATTERN = /<(h[123])>([\s\S]*?)<\/\1>/g;

const protectSvgBlocks = (markdownText, blocks) =>
	markdownText.replace(SVG_BLOCK_PATTERN, (match) => {
		blocks.push(match);
		return `<!--CHARLES-SVG-${blocks.length - 1}-->`;
	});

const restoreSvgBlocks = (htmlText, blocks) =>
	htmlText.replace(SVG_PLACEHOLDER_PATTERN, (match, index) => blocks[Number(index)] ?? match);

const parseArgs = (argv) => {
	const options = {
		inputs: [],
		output: "",
		title: "",
		subtitle: "",
		version: "",
		note: "",
	};

	for (let index = 0; index < argv.length; index += 1) {
		const token = argv[index];

		if (token === "--output" || token === "--title" || token === "--subtitle" || token === "--version" || token === "--note") {
			options[token.slice(2)] = argv[index + 1] ?? "";
			index += 1;
			continue;
		}

		options.inputs.push(token);
	}

	return options;
};

const escapeHtml = (text) =>
	text
		.replace(/&/g, "&amp;")
		.replace(/</g, "&lt;")
		.replace(/>/g, "&gt;");

// 目录只列层级不带页码，页内跳转靠 PDF 书签
const buildToc = (htmlBody) => {
	const headings = [];
	let match = HEADING_PATTERN.exec(htmlBody);

	while (match !== null) {
		headings.push({
			level: Number(match[1].slice(1)),
			text: match[2].replace(/<[^>]+>/g, "").trim(),
		});
		match = HEADING_PATTERN.exec(htmlBody);
	}

	HEADING_PATTERN.lastIndex = 0;

	if (headings.length < TOC_MIN_HEADINGS) {
		return "";
	}

	const items = headings
		.map((heading) => `<li class="toc__item toc__item--${heading.level}">${heading.text}</li>`)
		.join("\n");

	return `<nav class="toc">\n<h2 class="toc__title">目录</h2>\n<ol class="toc__list">\n${items}\n</ol>\n</nav>`;
};

const buildCover = (options) => {
	if (!options.title) {
		return "";
	}

	const parts = [`<div class="cover">`, `<div class="cover__eyebrow">${escapeHtml(options.subtitle || "产品需求文档")}</div>`, `<h1 class="cover__title">${escapeHtml(options.title)}</h1>`];

	if (options.version) {
		parts.push(`<div class="cover__meta">版本：${escapeHtml(options.version)} &nbsp;&middot;&nbsp; ${new Date().toISOString().slice(0, 10)}</div>`);
	}

	if (options.note) {
		parts.push(`<div class="cover__note">${escapeHtml(options.note)}</div>`);
	}

	parts.push("</div>");
	return parts.join("\n");
};

const markdown = new MarkdownIt({
	html: true,
	linkify: false,
	typographer: false,
});

// mermaid 代码块交给浏览器端渲染成矢量 SVG，其余代码块走默认高亮
const defaultFence = markdown.renderer.rules.fence;

markdown.renderer.rules.fence = (tokens, index, options, env, self) => {
	const token = tokens[index];

	if (token.info.trim().toLowerCase() === "mermaid") {
		return `<div class="mermaid-wrap"><pre class="mermaid">${escapeHtml(token.content)}</pre></div>\n`;
	}

	return defaultFence(tokens, index, options, env, self);
};

const options = parseArgs(process.argv.slice(2));

if (options.inputs.length === 0 || !options.output) {
	console.error("用法: render.mjs <输入.md...> --output <输出.html> [--title 标题] [--subtitle 副标题] [--version 版本] [--note 首页说明]");
	process.exit(2);
}

const svgBlocks = [];

const sections = options.inputs.map((inputPath) => {
	const source = protectSvgBlocks(readFileSync(inputPath, "utf8"), svgBlocks);
	return markdown.render(source);
});

// 需求与任务编号加等宽高亮，便于对方在 PDF 上按编号反馈
const body = restoreSvgBlocks(
	sections
		.join("\n<hr>\n")
		.replace(REQ_ID_PATTERN, '<span class="req-id">$1</span>')
		.replace(TASK_ID_PATTERN, '<span class="req-id">$1</span>'),
	svgBlocks,
);

const style = readFileSync(STYLE_PATH, "utf8");
const mermaidConfig = readFileSync(MERMAID_THEME_PATH, "utf8");

const html = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<title>${escapeHtml(options.title || "PRD")}</title>
<style>
${style}
</style>
</head>
<body>
${buildCover(options)}
${buildToc(body)}
<div class="content">
${body}
</div>
<script>${MERMAID_SOURCE}</script>
<script>
	mermaid.registerIconPacks([{ name: "lucide", icons: ${ICON_PACK} }]);
	mermaid.initialize(Object.assign({ startOnLoad: false }, ${mermaidConfig}));
	window.__mermaidDone = mermaid
		.run()
		.then(function () { return true; })
		.catch(function (error) { return String(error); });
</script>
</body>
</html>
`;

writeFileSync(options.output, html, "utf8");
console.log(`[OK] 已渲染 HTML: ${options.output}`);
