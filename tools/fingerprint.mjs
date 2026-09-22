/**
 * 原型目录的内容指纹
 * 截图时记进 _coords.json，生成标注时比对，原型改过而没重新截图就拒绝出图
 * 创建日期：2026-09-22
 * 修改日期：2026-09-22
 */

import { readFileSync, readdirSync, statSync } from "node:fs";
import { createHash } from "node:crypto";
import { join, relative, resolve, dirname } from "node:path";

// 用内容不用修改时间：git checkout 与 cp 都会改 mtime，内容却没变
export const prototypeFingerprint = (root) => {
	const parts = [];

	const walk = (dir) => {

		for (const name of readdirSync(dir).sort()) {

			if (name.startsWith(".")) {
				continue;
			}

			const full = join(dir, name);

			if (statSync(full).isDirectory()) {
				walk(full);
				continue;
			}

			const digest = createHash("sha256").update(readFileSync(full)).digest("hex");
			parts.push(`${relative(root, full)}\0${digest}`);
		}
	};

	walk(root);
	// 按路径排序后再拼，指纹就与目录遍历顺序无关，其它语言也能算出同一个值
	parts.sort();
	return createHash("sha256").update(parts.join("\n")).digest("hex");
};

// page 指向 prototype/ 里的某个文件，pages/ 子目录要多退一层才是原型根
export const prototypeRootOf = (pageFile) =>
	resolve(dirname(pageFile), pageFile.includes("/pages/") ? ".." : ".");
