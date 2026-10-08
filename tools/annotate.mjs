/**
 * 校验界面标注清单：坐标时效、截图高宽比、按钮与控件的标注覆盖，以及文档里有没有对应标记
 * 标注图本身由 render.mjs 导出时现场生成，文档里只留空标记块，换布局只需升级工具
 * 创建日期：2026-09-22
 * 修改日期：2026-10-08
 */

import { readFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";
import { buildAnnotation } from "./annotation.mjs";

const usage = `用法: annotate.mjs <标注清单.json...>

标注清单与截图清单同目录，按元素文案挑要标的东西，不写坐标也不写选择器：

{
  "shot": "list",
  "inject": "../tasks.md",
  "mark": "list",
  "marks": [
    { "el": "订单号", "kind": "field", "note": "支持前缀匹配。" },
    { "el": "批量作废", "kind": "btn", "steps": ["未勾选时置灰", "点击后弹二次确认"] },
    { "el": "checkbox", "kind": "field", "label": "全选", "note": "只选中当前页。" }
  ],
  "skip": [
    { "el": "详情", "kind": "link", "reason": "跳转到详情页，详情页自己是一张图" }
  ]
}

先跑 capture.mjs 量坐标。本脚本只校验，不改文档：
inject 指向的文档里要有 <!--annotation:mark--> 与 <!--/annotation--> 空标记块，
导出 PDF 时 render.mjs 按清单现场生成标注图。说明栏每条以 label（缺省 el）开头。`;

const args = process.argv.slice(2);

if (args.length === 0 || args.includes("--help")) {
	console.log(usage);
	process.exit(args.length === 0 ? 2 : 0);
}

let failed = 0;

for (const arg of args) {
	const specFile = resolve(arg);

	if (!existsSync(specFile)) {
		console.error(`[NG] 找不到标注清单：${specFile}`);
		failed += 1;
		continue;
	}

	let spec;

	try {
		({ spec } = buildAnnotation(specFile));
	} catch (error) {
		console.error(`[NG] ${error.message}`);
		failed += 1;
		continue;
	}

	const mark = spec.mark ?? spec.shot;

	if (spec.inject) {
		const docFile = resolve(specFile, "..", spec.inject);

		if (!existsSync(docFile) || !readFileSync(docFile, "utf8").includes(`<!--annotation:${mark}-->`)) {
			console.error(`[NG] ${spec.shot}: ${spec.inject} 里没有 <!--annotation:${mark}--> 标记块，导出时这张图无处可放`);
			failed += 1;
			continue;
		}
	}

	console.log(`[OK] ${spec.shot} 标注 ${spec.marks.length} 处，导出时生成到 ${mark} 标记块`);
}

if (failed > 0) {
	console.error(`[NG] ${failed} 份清单未通过`);
	process.exit(1);
}
