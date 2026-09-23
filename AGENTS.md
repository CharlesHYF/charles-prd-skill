# charles-prd-skill -- AI 工作指令
本仓是 Charles 的产品文档与原型规范。**改这个仓库时，同样遵守它自己定义的规范。**

本文件内联了本仓自己的编码与提交规范原文，不是指针。改代码、文档、脚本之前先读完本文件，不以"稍后去查别处"代替。

## 这是什么
一个跨工具的产品文档规范 plugin，包含下列 skill：

| skill | 作用 |
| --- | --- |
| `skills/charles-prd-standards/` | 规范本体：目录结构、版本管理、任务与交互规格、原型、图、文字表达、导出交付、协作格式 |
| `skills/charles-new-product/` | 从零定义新产品的工作流 |
| `skills/charles-legacy-prd/` | 给已有项目补 PRD，从实现反向整理 |
| `skills/charles-prd-review/` | PRD 评审，找内容矛盾 |

## 交付红线
1. **改完必须跑通三项验证**，未实跑不得声称通过：
   ```bash
   bash tests/run_tests.sh
   bash tests/check_structure.sh
   find tools tests -name '*.sh' -not -path '*/node_modules/*' -print0 | xargs -0 shellcheck --severity=warning
   ```
2. 改了规则文本，检查 `templates/prd-template/` 是否仍然通过 `tools/check.sh`
3. 新增规则时优先考虑能否被 `tools/check.sh` 机器验证，不能验证的放进 `charles-prd-review` 的内容评审清单
4. 版本号必须同步：每个 SKILL.md 的 metadata、各 plugin 配置与 `gemini-extension.json`，以主 skill 为准，`tests/check_structure.sh` 会比对

## 变更类型闸门
动手前先判定本次属于哪一类，判定不了按更严格的一档执行。

| 变更类型 | 模块文档 | 测试要求 | 动手前 |
| --- | --- | --- | --- |
| 新功能：新规则、新检查项、新工具能力 | 先写或改 `docs/modules/skill/` 下的模块文档，评审通过后再编码 | `tests/` 补回归场景，实跑全绿 | 边界、输入输出、异常场景逐个问清 |
| 需求变更：改已有规则或检查的行为 | 改模块文档对应小节，失效行为标注作废 | 改回归场景，全量回归 | 确认受影响的 skill、模板与已在用的产品仓 |
| Bug 修复 | 不写；文档与实现不符时回改文档 | 先在 `tests/run_tests.sh` 加复现场景并确认它失败，再改实现 | 定位根因，不只治症状 |
| 重构 | 不动 | 现有测试全绿，禁止改断言、删场景 | 证明改动前后行为等价 |
| 依赖升级 | 不写 | 导出一次样张 PDF，确认渲染正常 | 记录版本变化与已知风险 |

## Git 规范
- 作者 `Charles <w1400214654@outlook.com>`；提交信息用 Conventional Commits 前缀（`feat` / `fix` / `docs` / `refactor` / `test` / `chore`），正文写清做了什么、为什么，不写"修复 bug"这类无信息内容
- **禁止任何 AI 署名**：不加 `Co-Authored-By` 之类的 AI trailer，不加 `Generated with ...` 之类的声明；author 与 committer 必须是 Charles，提交前确认 `git config user.name` 与 `user.email`
- **分支**：AI 的改动只提交到 `agents/feature/<描述>`，禁止直接提交或推送 `main`，禁止发起 PR；由 Charles 审查后合入
- **提交粒度**：一个任务、一个需求、一个问题对应一个 commit
  - 重构与功能修改分开提交
  - 纯格式化的批量改动单独一个提交，信息里注明"仅格式化，无行为变更"，并把该提交哈希登记进 `.git-blame-ignore-revs`
  - 提交信息需要用"同时还"、"顺便"连接，说明应该拆开
- **交付整洁**：不留临时脚本、调试文件、备份文件、注释掉的大段代码与空目录；spec、plan、调研笔记等过程产物不提交
- **导出产物不进 Git**：导出目录与中间 HTML 由 `.gitignore` 忽略，只有 `templates/export/` 下的样张 PDF 例外
- `.gitignore` 覆盖编辑器、操作系统、依赖、运行时与 AI 工具残留目录；`.agents/` 例外不忽略，本仓要提交 `.agents/plugins/marketplace.json`

## 格式
以下规则适用于新写和修改的内容。存量不符合的，改到哪处按哪处调整；批量调整按"仅格式化"单独提交。

- 缩进 Tab；JSON 与 YAML 2 空格；行尾 LF，编码 UTF-8，以 `.editorconfig` 与 `.gitattributes` 为准
- **禁用字符**，规则文本里只写码点：
  - 弯引号 U+2018、U+2019、U+201C、U+201D，CJK 角引号 U+300C 到 U+300F，全角引号 U+FF02、U+FF07，统一用半角 `"` 或 `'`
  - 破折号与横线 U+2010 到 U+2015、U+2212、U+FF0D、U+2E3A、U+2E3B，统一用半角双连字符 `--`
  - Emoji 不出现在代码、注释、文档与提交信息中
  - 书名号与目录树制表符不禁
  - 代码里需要判断这些字符时用 `\u` 转义，不写字面字符
- **禁止魔法数字**：有语义的数字提为文件顶部的具名常量，全大写下划线命名，如 `VIEWPORT_WIDTH`
- **命名见名知义**：禁止 `tmp`、`obj`、`data1` 这类占位名、编号名与拼音；布尔用 `is` / `has` / `can` / `should` 前缀，集合用复数；函数名为动词加名词，同一动作全仓只用一个动词
- JS 的 `if` / `else` / `for` / `while` 与函数体一律带大括号；完整代码块与相邻同级语句之间空一行
- 对象与数组字面量每个元素独占一行，并带行尾逗号

## 注释与文件头
- 注释用中文，写在被说明对象的上一行；正文默认一到两行，上限三行；一条注释一行写完，不把一句话折断换行
- 只写"为什么"（为何降级、为何限制数量），删掉复述代码的零信息注释；背景推演、方案权衡写进模块文档或 commit message
- 措辞用"动作 + 对象 + 必要条件"，禁止隐喻黑话（信封、胶水、守门员、搬运、塞进、吐出之类）
- 多行注释语法：JS 用 `/** ... */` 三段式，`/**` 与 `*/` 各独占一行；Shell 用连续 `#`；HTML 与 Markdown 用 `<!-- -->`
- **每个源码文件带文件头三行**：职责描述、`创建日期：YYYY-MM-DD`、`修改日期：YYYY-MM-DD`，日期行的冒号用全角
  - 描述一到两句话，只写核心职责；不加"作用："一类前缀，句尾不加句号，不用 `--` 追加功能罗列
  - 创建日期只在新建时写入，此后不改；修改日期在本次真改了文件时更新为当天
  - `rules/*.md` 用 `<!-- -->` 包裹同样的三行
  - CSS 文件不写文件头
  - `templates/` 下的产品文档是给使用者复制或参照的内容，不加文件头

## Shell
- 首行 `#!/usr/bin/env bash`，文件头紧跟其后，再 `set -uo pipefail`
- 变量引用一律 `"${var}"`，函数内变量用 `local`
- 检查类脚本的输出统一用 `[PASS]` / `[FAIL]` / `[SKIP]` / `[OK]` 前缀，有失败时退出码非 0
- 依赖的外部命令缺失时打印 `[SKIP]` 并说明跳过了什么，不静默放行
- `shellcheck --severity=warning` 无告警

## JavaScript（`tools/*.mjs`）
- ESM（`import` / `export`），不混用 CommonJS；无构建步骤的脚本直接写 `.mjs`，不引入 TypeScript
- 语句结尾加分号；字符串用双引号，插值用模板字符串；`const` 优先，确需重新赋值才用 `let`，禁止 `var`；比较用 `===` 与 `!==`
- 统一 `async` / `await`，不混用 `.then()` 链；每个 `await` 都要有错误处理路径
- import 分组：Node 内置与第三方包在前，本仓模块在后，组间空一行
- 失败时错误信息写 stderr，退出码非 0
- 依赖用 npm 管理，`tools/package-lock.json` 必须提交；不引入 Prettier、ESLint 等新工具，以上规则靠自查

## CSS（`templates/export/style.css`）
- 每条声明独占一行；选择器分组时每个选择器一行；`{` 跟在选择器后；规则块之间空一行
- **不写任何注释**，含文件头；样式意图靠 class 名与自定义属性命名表达，设计决策写进模块文档
- class 用 `kebab-case`；颜色、间距、字号定义为 `:root` 自定义属性；禁止 `!important` 与 ID 选择器

## Markdown
- 不用 `---`、`***`、`___` 分割线，SKILL.md 的 frontmatter 除外
- 标题与其正文之间不留空行
- 文档用中文，`Non-goals`、`Release Criteria`、`In Scope` 这类没有稳定中文对应的正式术语保留英文
- 分析、提方案、报告问题时用编号列表，每条按问题描述、存在的隐患、解决方案三段写
- README 顶部居中放横幅与徽章；徽章用 Markdown 图片语法、写在同一行、不超过六个；功能、目录、命令变化时同步更新 README

## 豁免范围
- `templates/**/prototype/` 下的原型代码不受本文件的编码规范约束，与产品仓里的原型豁免一致；禁用字符规则仍然适用
- 工具生成的内容不手改：`_coords.json`、文档里 `<!--annotation:xxx-->` 与 `<!--/annotation-->` 之间的标注 SVG、`package-lock.json`
- `tools/node_modules/` 不进 Git

## 修改边界
- `tools/render.mjs` 里的 SVG 占位符保护逻辑不要移除：Markdown 的 HTML 块遇空行结束，没有它内联 SVG 会被截断成源码
- `templates/export/mermaid-theme.json` 里各图类型的 `useMaxWidth: false` 不要改回：开着会让图在 A4 页宽里被压到看不清
- 样式表里图的尺寸用 `max-width` 加 `max-height` 双限，不要改成 `width: 100%`，纵向图会被撑到超过一页

## 独立性
**本仓不依赖任何其它 skill，也不点名引用。** 涉及编码规范、测试要求、交付闸门的部分，一律写成"项目自己的规范体系"这类通用表述，由使用者的项目决定具体是什么。本仓自己的编码与提交规范就是本文件，不引用外部来源。

产品文档与实现文档的边界写在 `rules/boundaries.md`，只定产品侧的规则。

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
