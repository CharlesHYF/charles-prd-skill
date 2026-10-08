/**
 * 用本机 Chrome 把 HTML 打印成带页眉页脚的 PDF，目录页码靠先打印一遍读出跳转目标再回填
 * 创建日期：2026-09-21
 * 修改日期：2026-10-08
 */

import { resolve } from "node:path";
import { existsSync, writeFileSync } from "node:fs";
import puppeteer from "puppeteer-core";

const CHROME_CANDIDATES = [
	"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
	"/Applications/Chromium.app/Contents/MacOS/Chromium",
	"/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
];

const PAGE_MARGIN = {
	top: "20mm",
	right: "18mm",
	bottom: "18mm",
	left: "18mm",
};

// render.mjs 给目录页码留的位置，属性值是目标标题的 id
const TOC_PAGE_SELECTOR = "[data-toc-target]";

const PDF_OPTIONS = {
	format: "A4",
	printBackground: true,
	// 侧边栏书签，按标题层级自动生成，长文档里比翻目录快
	outline: true,
	tagged: true,
	margin: PAGE_MARGIN,
	displayHeaderFooter: true,
	headerTemplate: "<div></div>",
};

const parseArgs = (argv) => {
	const options = {
		input: "",
		output: "",
		footer: "",
	};

	for (let index = 0; index < argv.length; index += 1) {
		const token = argv[index];

		if (token === "--output" || token === "--footer") {
			options[token.slice(2)] = argv[index + 1] ?? "";
			index += 1;
			continue;
		}

		options.input = token;
	}

	return options;
};

const findChrome = () => {
	const fromEnv = process.env.CHROME_PATH;

	if (fromEnv && existsSync(fromEnv)) {
		return fromEnv;
	}

	return CHROME_CANDIDATES.find((candidate) => existsSync(candidate)) ?? "";
};

const escapeHtml = (text) =>
	text
		.replace(/&/g, "&amp;")
		.replace(/</g, "&lt;")
		.replace(/>/g, "&gt;");

// Chrome 把标题 id 写成 PDF 的命名目标，/Dests 字典里记着每个名字落在哪个页面对象
// 页面对象按页面树顺序展开就是页码，与页脚的页码同一套计数（封面算第 1 页）
const readDestinationPages = (pdfBuffer) => {
	const text = pdfBuffer.toString("latin1");

	const objectBody = (number) => {
		const match = new RegExp(`(?:^|\\s)${number} 0 obj\\s*([\\s\\S]*?)endobj`).exec(text);
		return match ? match[1] : "";
	};

	const catalog = /\/Type \/Catalog([\s\S]*?)>>/.exec(text)?.[1] ?? "";
	const pagesRoot = /\/Pages (\d+) 0 R/.exec(catalog)?.[1];
	const destsRef = /\/Dests (\d+) 0 R/.exec(catalog)?.[1];

	if (!pagesRoot || !destsRef) {
		return new Map();
	}

	const pageOrder = [];

	const walk = (number) => {
		const body = objectBody(number);
		const kids = /\/Kids \[([^\]]*)\]/.exec(body);

		if (/\/Type \/Pages\b/.test(body) && kids) {

			for (const kid of kids[1].matchAll(/(\d+) 0 R/g)) {
				walk(kid[1]);
			}

			return;
		}

		pageOrder.push(number);
	};

	walk(pagesRoot);

	const pages = new Map();

	for (const dest of objectBody(destsRef).matchAll(/\/([^\s\/\[]+)\s*\[(\d+) 0 R/g)) {
		const index = pageOrder.indexOf(dest[2]);

		if (index >= 0) {
			pages.set(dest[1], index + 1);
		}
	}

	return pages;
};

const options = parseArgs(process.argv.slice(2));

if (!options.input || !options.output) {
	console.error("用法: print.mjs <输入.html> --output <输出.pdf> [--footer 页脚文案]");
	process.exit(2);
}

const chromePath = findChrome();

if (!chromePath) {
	console.error("[NG] 找不到 Chrome。安装 Google Chrome，或用 CHROME_PATH 指定可执行文件路径。");
	process.exit(1);
}

const footerText = escapeHtml(options.footer || "");

const footerTemplate = `
<div style="width:100%;font-size:8pt;color:#6b7280;font-family:'PingFang SC',sans-serif;padding:0 18mm;display:flex;justify-content:space-between;">
	<span>${footerText}</span>
	<span><span class="pageNumber"></span> / <span class="totalPages"></span></span>
</div>`;

const browser = await puppeteer.launch({
	executablePath: chromePath,
	headless: "new",
	args: ["--no-sandbox", "--disable-gpu"],
});

try {
	const page = await browser.newPage();
	await page.goto(`file://${resolve(options.input)}`, { waitUntil: "networkidle0" });

	// 图是浏览器端渲染的，不等它画完就打印会得到空白块
	const mermaidResult = await page.evaluate(() => window.__mermaidDone ?? "no-diagram");

	if (mermaidResult !== true && mermaidResult !== "no-diagram") {
		console.error(`[NG] 图渲染失败：${mermaidResult}`);
		await browser.close();
		process.exit(1);
	}

	const pdfOptions = {
		...PDF_OPTIONS,
		footerTemplate,
	};
	const firstPass = Buffer.from(await page.pdf(pdfOptions));
	const tocSlots = await page.evaluate((selector) => document.querySelectorAll(selector).length, TOC_PAGE_SELECTOR);

	if (tocSlots === 0) {
		writeFileSync(options.output, firstPass);
		console.log(`[OK] 已生成 PDF: ${options.output}`);
	} else {
		// 页码只填进目录行尾的固定位置，不改变目录占的行数，第二遍打印的分页与第一遍一致
		const pages = Object.fromEntries(readDestinationPages(firstPass));
		const missing = await page.evaluate((selector, pageMap) => {
			const unresolved = [];

			for (const slot of document.querySelectorAll(selector)) {
				const target = slot.getAttribute("data-toc-target");

				if (pageMap[target]) {
					slot.textContent = String(pageMap[target]);
				} else {
					unresolved.push(target);
				}
			}

			return unresolved;
		}, TOC_PAGE_SELECTOR, pages);

		if (missing.length > 0) {
			console.error(`[WARN] ${missing.length} 个目录项没有读到页码，留空：${missing.slice(0, 5).join(" ")}`);
		}

		await page.pdf({
			...pdfOptions,
			path: options.output,
		});
		console.log(`[OK] 已生成 PDF: ${options.output}，目录 ${tocSlots - missing.length} 项已填页码`);
	}
} finally {
	await browser.close();
}
