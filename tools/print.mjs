/**
 * 用本机 Chrome 把 HTML 打印成带页眉页脚的 PDF
 * 创建日期：2026-09-21
 * 修改日期：2026-09-21
 */

import { resolve } from "node:path";
import { existsSync } from "node:fs";
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

	await page.pdf({
		path: options.output,
		format: "A4",
		printBackground: true,
		margin: PAGE_MARGIN,
		displayHeaderFooter: true,
		headerTemplate: "<div></div>",
		footerTemplate,
	});
	console.log(`[OK] 已生成 PDF: ${options.output}`);
} finally {
	await browser.close();
}
