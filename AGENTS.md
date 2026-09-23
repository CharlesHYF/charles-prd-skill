# charles-prd-skill -- AI 工作指令

本仓是 Charles 的产品文档与原型规范。**改这个仓库时，同样遵守它自己定义的规范。**

## 这是什么

一个跨工具的产品文档规范 plugin，包含下列 skill：

| skill | 作用 |
| --- | --- |
| `skills/charles-prd-standards/` | 规范本体：目录结构、版本管理、任务与交互规格、原型、图、文字表达、导出交付、协作格式 |
| `skills/charles-new-product/` | 从零定义新产品的短循环工作流 |
| `skills/charles-legacy-prd/` | 给已有项目补 PRD，从实现反向整理 |
| `skills/charles-prd-review/` | PRD 评审，找内容矛盾 |

## 交付红线

1. **改完必须跑通两项验证**：
   ```bash
   bash tests/run_tests.sh
   bash tests/check_structure.sh
   ```
2. 改了规则文本，检查 `templates/prd-template/` 是否仍然通过 `tools/check.sh`
3. 新增规则时优先考虑能否被 `tools/check.sh` 机器验证，不能验证的放进 `charles-prd-review` 的内容评审清单
4. 版本号必须同步：每个 SKILL.md 的 metadata、各 plugin 配置与 `gemini-extension.json`，以主 skill 为准，`tests/check_structure.sh` 会比对

## 修改边界

- `tools/render.mjs` 里的 SVG 占位符保护逻辑不要移除：Markdown 的 HTML 块遇空行结束，没有它内联 SVG 会被截断成源码
- `templates/export/mermaid-theme.json` 里各图类型的 `useMaxWidth: false` 不要改回：开着会让图在 A4 页宽里被压到看不清
- 样式表里图的尺寸用 `max-width` 加 `max-height` 双限，不要改成 `width: 100%`，纵向图会被撑到超过一页

## 独立性

**本仓不依赖任何其它 skill，也不点名引用。** 涉及编码规范、测试要求、交付闸门的部分，一律写成"项目自己的规范体系"这类通用表述，由使用者的项目决定具体是什么。

产品文档与实现文档的边界写在 `rules/boundaries.md`，只定产品侧的规则。

## 硬约束（本仓自身适用）

- 文档用中文，`Non-goals`、`Release Criteria`、`In Scope` 这类没有稳定中文对应的正式术语保留英文
- 分析、提方案、报告问题时用编号列表，每条按问题描述、存在的隐患、解决方案三段写
- 导出分两份：产品需求对外、任务规格仅内部；导出产物不进 Git，`tools/node_modules/` 与 `/export/` 已在 `.gitignore`
- Shell 缩进用 Tab，行尾 LF
- 禁用 Unicode 弯引号、破折号、Emoji，统一半角与 `--`
- 文件头描述只写核心职责，不用 `--` 追加功能罗列
- 提交到 `agents/feature/*` 分支，**禁止任何 AI 联合署名**，author 与 committer 必须是 `Charles <w1400214654@outlook.com>`
- 一个任务、一个需求、一个问题对应一个 commit

## 常用命令

```bash
bash tools/check.sh docs/prd          # 校验某个项目的 PRD 结构
bash tools/check.sh templates/prd-template   # 校验本仓自带模板
bash tests/run_tests.sh               # check.sh 回归测试
bash tests/check_structure.sh         # skill 完整性、版本号与链接
find tools tests -name '*.sh' -not -path '*/node_modules/*' -print0 | xargs -0 shellcheck --severity=warning
bash tools/install-skills.sh          # 软链安装到 ~/.claude/skills
bash tools/export-prd.sh 1.0 --title 标题   # 导出该版本的两份 PDF
bash tools/export-pdf.sh <md...> --title 标题 --version 1.0   # 自定义组合导出
```
