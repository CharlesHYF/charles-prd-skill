/**
 * 把 Markdown 渲染成带打印样式的单页 HTML
 * 创建日期：2026-09-21
 * 修改日期：2026-10-08
 */

import { readFileSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, resolve, isAbsolute } from "node:path";
import { pathToFileURL } from "node:url";
import { fileURLToPath } from "node:url";
import MarkdownIt from "markdown-it";

import { buildAnnotation, indexMarksFiles } from "./annotation.mjs";

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
const HEADING_PATTERN = /<(h[123])(?: id="[^"]*")?>([\s\S]*?)<\/\1>/g;
const HEADING_ID_PREFIX = "sec-";

const protectSvgBlocks = (markdownText, blocks) =>
	markdownText.replace(SVG_BLOCK_PATTERN, (match) => {
		blocks.push(match);
		return `<!--CHARLES-SVG-${blocks.length - 1}-->`;
	});

const restoreSvgBlocks = (htmlText, blocks) =>
	htmlText.replace(SVG_PLACEHOLDER_PATTERN, (match, index) => blocks[Number(index)] ?? match);

// 图片相对路径按 Markdown 文件自身解析，转成绝对 file:// URL。
// 导出的 HTML 落在 export/ 子目录，与源 Markdown 不同级，不转换会全部破图。
// 覆盖 Markdown 的 ![](path) 与内联 SVG 的 <image href="path">。
const IMG_SRC_PATTERN = /(<image\b[^>]*?\s(?:xlink:href|href)\s*=\s*")([^"]+)(")/gi;
const MD_IMG_PATTERN = /(!\[[^\]]*\]\()([^)\s]+)(\s*(?:"[^"]*")?\))/g;

const isExternal = (url) =>
	/^(https?:|data:|file:|#|\/\/)/i.test(url) || isAbsolute(url);

const toFileUrl = (baseDir, url) => {
	if (isExternal(url)) {
		return url;
	}

	const decoded = decodeURI(url);
	return pathToFileURL(resolve(baseDir, decoded)).href;
};

const resolveAssetPaths = (markdownText, inputPath) => {
	const baseDir = dirname(resolve(inputPath));

	return markdownText
		.replace(IMG_SRC_PATTERN, (match, head, url, tail) => `${head}${toFileUrl(baseDir, url)}${tail}`)
		.replace(MD_IMG_PATTERN, (match, head, url, tail) => `${head}${toFileUrl(baseDir, url)}${tail}`);
};

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
// 给标题编号加 id，目录项靠它跳转，print.mjs 也靠它回填页码
const addHeadingIds = (htmlBody) => {
	let index = 0;

	return htmlBody.replace(HEADING_PATTERN, (match, tag, inner) => {
		const id = `${HEADING_ID_PREFIX}${index}`;
		index += 1;
		return `<${tag} id="${id}">${inner}</${tag}>`;
	});
};

const buildToc = (htmlBody) => {
	const headings = [];
	let match = HEADING_PATTERN.exec(htmlBody);

	while (match !== null) {
		headings.push({
			level: Number(match[1].slice(1)),
			text: match[2].replace(/<[^>]+>/g, "").trim(),
			id: `${HEADING_ID_PREFIX}${headings.length}`,
		});
		match = HEADING_PATTERN.exec(htmlBody);
	}

	HEADING_PATTERN.lastIndex = 0;

	if (headings.length < TOC_MIN_HEADINGS) {
		return "";
	}

	const items = headings
		.map((heading) => `<li class="toc__item toc__item--${heading.level}"><a class="toc__link" href="#${heading.id}"><span class="toc__text">${heading.text}</span><span class="toc__page" data-toc-target="${heading.id}"></span></a></li>`)
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

// markdown-it 默认把 file: 当不安全协议直接拒掉，图片会退化成字面文本。
// resolveAssetPaths 正是要把相对路径转成 file:// 绝对路径，这里必须放行。
const defaultValidateLink = markdown.validateLink.bind(markdown);
markdown.validateLink = (url) => defaultValidateLink(url) || /^file:\/\//i.test(url);

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

// 界面标注图不存进 Markdown，导出时按同版本 diagrams/ 下的标注清单现场生成，换布局只需升级工具
const ANNOTATION_BLOCK_PATTERN = /<!--annotation:([^>]+?)-->[\s\S]*?<!--\/annotation-->/g;

const injectAnnotations = (markdownText, inputPath) => {
	const marksIndex = indexMarksFiles(resolve(dirname(resolve(inputPath)), "diagrams"));
	const errors = [];

	const text = markdownText.replace(ANNOTATION_BLOCK_PATTERN, (match, mark) => {
		const specFile = marksIndex.get(mark);

		if (!specFile) {
			errors.push(`${inputPath} 的标记块 ${mark} 在 diagrams/ 下找不到 mark 或 shot 为 ${mark} 的标注清单`);
			return match;
		}

		try {
			const { svg } = buildAnnotation(specFile);
			return `<!--annotation:${mark}-->\n${svg}\n<!--/annotation-->`;
		} catch (error) {
			errors.push(error.message);
			return match;
		}
	});

	return { text, errors };
};

const svgBlocks = [];
const annotationErrors = [];

const sections = options.inputs.map((inputPath) => {
	const injected = injectAnnotations(readFileSync(inputPath, "utf8"), inputPath);
	annotationErrors.push(...injected.errors);
	const raw = resolveAssetPaths(injected.text, inputPath);
	const source = protectSvgBlocks(raw, svgBlocks);
	return markdown.render(source);
});

if (annotationErrors.length > 0) {

	for (const message of annotationErrors) {
		console.error(`[NG] ${message}`);
	}

	console.error(`[NG] ${annotationErrors.length} 张标注图生成失败，先用 annotate.mjs 校验标注清单`);
	process.exit(1);
}

// 需求与任务编号加等宽高亮，便于对方在 PDF 上按编号反馈
const body = addHeadingIds(restoreSvgBlocks(
	sections
		.join("\n<hr>\n")
		.replace(REQ_ID_PATTERN, '<span class="req-id">$1</span>')
		.replace(TASK_ID_PATTERN, '<span class="req-id">$1</span>'),
	svgBlocks,
));

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
