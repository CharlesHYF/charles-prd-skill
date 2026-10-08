<div align="center">

<img src="assets/banner.png" alt="charles-prd" width="880">

![Version](https://img.shields.io/badge/version-1.2.0-blue) ![License](https://img.shields.io/badge/license-MIT-green) ![AI Tools](https://img.shields.io/badge/AI%20tools-Claude%20Code%20%7C%20Codex%20%7C%20Cursor%20%7C%20Gemini-brightgreen) ![Node](https://img.shields.io/badge/node-%3E%3D18-339933) ![Docs](https://img.shields.io/badge/docs-%E4%B8%AD%E6%96%87-red)

**让 AI Agent 按同一套规范产出 PRD、可点击原型、界面标注图与 PDF 的 Skill 集合**

</div>

charles-prd 是一组给 AI 编程助手用的产品文档 Skill，面向独立开发者与小团队。装上之后对 Agent 说"一键出全部"，它会先把需求问清楚，再一次产出完整的 PRD 包：产品定义、版本 PRD、范围、任务与交互规格、可点击 HTML 原型、从原型截图生成的界面标注图，以及两份排好版的 PDF。

目标是几个月后还能回答三个问题：**为什么做、这一版做什么、界面和交互是什么**。目录随产品复杂度增长，能用一个文件解决就不拆成三个。

## 目录
- [特性](#特性)
- [四种工作模式](#四种工作模式)
- [快速开始](#快速开始)
- [产出物](#产出物)
- [工具命令](#工具命令)
- [结构校验器](#结构校验器)
- [导出 PDF](#导出-pdf)
- [核心约定](#核心约定)
- [仓库结构](#仓库结构)
- [参与贡献](#参与贡献)
- [许可证](#许可证)

## 特性
- **先问后写**：两轮提问，第一轮七类产品级必答项，第二轮逐模块功能明细；有"未回答"的问题不开写，问出的每条结论都要记进需求确认记录并写明落点
- **四种模式**：从零生成、给已有项目补文档、规划下一版、往开发中的版本追加，各有独立工作流，都支持一键出全部
- **原型即事实来源**：静态 HTML 原型按产品形态覆盖必要界面与四种状态；给已有项目补文档时从真实前端源码复刻，并维护源码对照表
- **标注图从原型生成**：`capture.mjs` 截原型并量元素坐标，标注清单按元素文案挑选，导出时现场生成左图右文的标注图；按钮、输入控件与链接漏标会被拦下
- **规则可机器校验**：`check.sh` 有 16 项结构检查，覆盖章节、编号、字段类型、标注覆盖、截图高宽比、表格分点等；部分问题可用 `--fix` 自动修复
- **一条命令出 PDF**：产品需求与任务规格分开导出，带封面、可点击并标注页码的目录、书签、页码；Mermaid 图渲染为矢量，截图自动压缩，全程离线
- **跨工具**：Claude Code、Codex、Cursor、OpenCode、Trae、Qoder、Gemini CLI 都能装，不依赖任何其它 Skill

## 四种工作模式
| 模式 | 判据 | Skill |
| --- | --- | --- |
| 1 第一份 PRD，从 0 生成 | 代码不存在，PRD 不存在 | `charles-prd-new-product` |
| 2 项目写完了，PRD 没做 | 代码在跑，PRD 不存在或与代码不符 | `charles-prd-legacy` |
| 3 第二版 PRD | PRD 已有，上一版已发布，要规划 1.1 或 2.0 | `charles-prd-next-version` |
| 4 在原有基础上加 PRD | PRD 已有，目标版本还在开发中，要往里加内容 | `charles-prd-add-feature` |

另有两个 Skill：

| Skill | 用途 |
| --- | --- |
| `charles-prd-standards` | 规范本体：目录结构、版本管理、任务与交互规格、原型、图、文字表达、导出、协作格式与一键出全部的统一流程 |
| `charles-prd-review` | PRD 评审：找脚本查不了的内容矛盾，如需求打架、范围与目标脱节、判据无法判定、确认记录对不上 |

## 快速开始
### 前置依赖
| 依赖 | 用途 |
| --- | --- |
| Bash | 运行 `check.sh` 与导出脚本 |
| Python 3 | `check.sh` 的部分检查，缺失时对应项跳过并提示 |
| Node.js 18 及以上 | 截图、标注与 PDF 渲染，首次导出时自动安装 npm 依赖 |
| Chrome、Chromium 或 Edge | 截图与打印 PDF，路径可用 `CHROME_PATH` 指定 |

### 安装
```bash
git clone https://github.com/CharlesHYF/charles-prd-skill.git ~/charles-prd-skill
```

按你用的工具，把 Skill 软链到对应目录：

```bash
bash ~/charles-prd-skill/tools/install-skills.sh
```

上面这条装到 Claude Code 的 `~/.claude/skills`。其它工具把目标目录作为参数传进去：

| 工具 | 目标目录 |
| --- | --- |
| Codex、Cursor、OpenCode、Trae | `~/.agents/skills` |
| Qoder | `~/.qoder/skills` |
| Qoder CN | `~/.qoder-cn/skills` |
| Trae 专属路径 | `~/.trae/skills` |
| Rovo Dev | `~/.rovodev/skills` |

```bash
bash ~/charles-prd-skill/tools/install-skills.sh ~/.agents/skills
```

装的是软链，`git pull` 后立即生效。Cursor 与 OpenCode 也会读 `~/.claude/skills`，已装在那里就不必重复装。

也可以用插件方式安装。Claude Code：

```text
/plugin marketplace add ~/charles-prd-skill
/plugin install charles-prd@charles-prd
```

Gemini CLI 直接克隆到扩展目录：

```bash
git clone https://github.com/CharlesHYF/charles-prd-skill.git ~/.gemini/extensions/charles-prd
```

### 第一次使用
在产品仓库里打开你的 AI 工具，直接描述场景即可，Agent 会按判据选模式：

```text
我要做一个订单审批的后台系统，帮我一键出全部 PRD。
```

```text
这个项目已经上线了，没有 PRD，帮我补一份，原型要和现在的页面一模一样。
```

```text
1.0 已经发布了，帮我规划下一个版本。
```

产出前 Agent 会分批提问，每批最多四个问题并给出推荐选项。全部问题有答案后才开始写，写完自己跑 `check.sh` 与评审清单再交付。

### 更新
```bash
git -C ~/charles-prd-skill pull origin main
```

## 产出物
```
project/docs/prd/
├── README.md              版本导航与状态
├── product.md             长期稳定的产品定义
├── decisions.md           跨版本的不可逆决策
└── versions/
    └── 1.0/
        ├── prd.md         版本历史加七章，需求带编号
        ├── scope.md       In Scope / Later / Out of Scope
        ├── tasks.md       任务与交互规格，界面小节放标注标记块
        ├── notes.md       需求确认记录、待验证问题
        ├── prototype/     可点击的 HTML 原型
        ├── diagrams/      截图清单、标注清单、截图与坐标
        └── export/        导出的两份 PDF，默认不进 Git
```

骨架在 [`templates/prd-template/`](templates/prd-template/)，复制为起点并逐项替换 `[待填]`。完整写法参照 [`templates/prd-example/`](templates/prd-example/) 的订单系统样例，导出效果见 [`templates/export/`](templates/export/) 下的两份样张。

## 工具命令
命令都在产品仓根目录执行，`<skill>` 指克隆下来的仓库目录。

| 命令 | 作用 |
| --- | --- |
| `bash <skill>/tools/check.sh docs/prd` | 结构校验，有问题时退出码非 0 |
| `bash <skill>/tools/check.sh --fix docs/prd` | 先把表格里没换行的分点自动改写，再执行全部检查 |
| `node <skill>/tools/capture.mjs <截图清单.json...>` | 截原型页面，同时量元素坐标写进 `_coords.json` |
| `node <skill>/tools/annotate.mjs <标注清单.json...>` | 校验标注清单：坐标时效、高宽比、标注覆盖、文档里的标记块 |
| `bash <skill>/tools/export-prd.sh 1.0 --title "产品名"` | 导出该版本的产品需求与任务规格两份 PDF |
| `bash <skill>/tools/export-pdf.sh <md...> --title 标题` | 自定义组合导出一份 PDF |

截图清单与标注清单的字段说明见 [diagrams 规则](skills/charles-prd-standards/rules/diagrams.md)。

## 结构校验器
`tools/check.sh` 把确定性规则变成会失败的检查，每项结束打印耗时，完整清单以脚本输出为准。

| 检查 | 内容 |
| --- | --- |
| 必需文件 | `README.md`、`product.md`、`versions/` |
| 版本目录命名 | 必须是明确版本号，禁止 current、latest、new |
| 版本内必需文档 | major 要 `prd.md` 与 `scope.md`，minor 至少要 `changes.md` |
| `prd.md` 章节与字段类型 | 固定章节齐全；字段表类型列写 SQL 类型，禁止语言层类型与 ENUM |
| 需求编号 | 存在且不重复分配 |
| 图的位置与来源 | Mermaid 不进 `diagrams/`，位图配同名来源说明 |
| 界面标注图 | 清单、坐标、截图齐全且未过期；截图高宽比不超过 1.25；按钮、输入控件与链接每个都有标注，不标的要写 `skip` 原因；标记块必须为空 |
| 版本状态 | `README.md` 声明三个版本状态 |
| 任务与交互规格 | 编号唯一、六个小节齐全、流程图或无分支声明、七字段齐全、关联需求存在；界面小节有标记块，标记块外不许手画 SVG |
| 未实现占位 | 已写进 `tasks.md` 的任务，原型里不能还挂着占位 |
| 角色交叉引用 | 正文里的角色都能在 `product.md` 角色表里找到 |
| `[待填]` 残留 | 骨架复制后没替换的占位，Markdown 与原型 HTML 都查 |
| 产品形态 | `product.md` 声明形态与移动端适配，取值合法 |
| 截图视口 | 纯移动形态只用手机视口；适配移动端时桌面截图都配手机截图与标注 |
| 需求确认记录 | major 版本的 `notes.md` 有需求确认记录且至少一行 |
| 原型来源对照 | 复刻原型的 `prototype/sources.md` 覆盖每个页面，源码路径存在 |
| 表格分点换行 | 多个分点要编号并用 `<br>` 换行，单元格最多 6 个分点；引号与括号里的内容不计 |

内容级的矛盾脚本查不了，由 `charles-prd-review` 的评审清单人工过。

## 导出 PDF
```bash
bash ~/charles-prd-skill/tools/export-prd.sh 1.0 --title "订阅管理工具"
```

| 产物 | 内容 | 读者 | 对外 |
| --- | --- | --- | --- |
| `prd-1.0.pdf` | 产品定义、PRD、Scope | 合作方、需要签字的客户 | 是 |
| `tasks-1.0.pdf` | 任务与交互规格，含界面标注图 | 实现者，含 AI Agent | 否，仅内部 |

两份分开导出，因为读者不同、生命周期不同，错误文案与兜底策略也不该作为承诺发给客户。

导出流程是 Markdown 渲染成带打印样式的 HTML，再用本机 Chrome 打印：

- 界面标注图按标注清单现场生成，文档里只存空标记块，换布局只需升级工具
- Mermaid 图渲染为矢量 SVG，手绘风格
- 目录可点击跳转并标注页码，页码由两遍打印回填
- 截图按显示尺寸重采样为 JPEG，原始 PNG 不动
- 打印按步骤输出耗时，失败时报出是哪一步；中间 HTML 无论成败都清理

**Markdown 是唯一源头，PDF 只是产物。** 收到批注过的 PDF 时把改动搬回 Markdown。导出目录默认不进 Git，只提交实际对外交付过的那一份。

## 核心约定
| 项目 | 规范 |
| --- | --- |
| 产品定义 | `product.md` 只写一次，版本相关内容一律进 `versions/<版本>/prd.md` |
| 版本目录 | 直接写明确版本号，发布后冻结，只允许修正笔误；发布时打 tag，tag 名与目录名对应 |
| PRD 结构 | 版本历史加七章；功能需求按模块分组，每个功能含场景描述、需求条目、字段定义、流程 |
| 字段定义 | 涉及数据的功能必须有六列字段表，类型列写 SQL 类型，枚举用 TINYINT 并列出全部取值 |
| 编号 | 需求 `REQ-<版本>-<三位序号>`，任务 `Task-<三位序号>`；不复用，作废时标注失效 |
| 交互规格 | 七个必填字段：触发、前置条件、正常路径、边界情况、错误处理、兜底行为、显示规则；提示文案写完整原文 |
| 需求表达 | 必须能写成测试用例，禁止"优化"、"提升体验"、"合理"这类无法判定的说法 |
| 原型 | 开发期间是交互事实来源，发布后转历史存档；不受编码规范约束，但不许复制进 `src/` |
| 图 | Mermaid 写在正文里；界面标注图由原型截图与标注清单在导出时生成，左图右文 |
| 范围 | 1.0 不等于 MVP，功能清单以确认过的全量为准，分期由需求方决定 |
| Release Criteria | 只写产品维度判据，工程标准由项目自己的交付体系管 |
| 文档语言 | 中文，`Non-goals`、`Release Criteria`、`In Scope` 这类术语保留英文 |

## 仓库结构
```
charles-prd-skill/
├── skills/                  六个 Skill，各自带 tools 与 templates 软链
│   └── charles-prd-standards/rules/   规则模块
├── tools/                   校验、截图、标注、渲染与打印脚本
├── templates/
│   ├── prd-template/        复制起点的骨架
│   ├── prd-example/         订单系统完整样例
│   └── export/              PDF 样式、Mermaid 主题与两份样张
├── tests/                   回归测试与仓库自检
├── docs/modules/            本仓自己的设计文档
├── .claude-plugin/ .codex-plugin/ .cursor-plugin/ .agents/   各工具的插件配置
└── gemini-extension.json
```

## 参与贡献
欢迎提 Issue 和 Pull Request。动手前请先读 [AGENTS.md](AGENTS.md)，里面写明了本仓的编码与提交规范、交付红线和修改边界。

提交前请跑通三项验证：

```bash
bash tests/run_tests.sh
```

```bash
bash tests/check_structure.sh
```

```bash
find tools tests -name '*.sh' -not -path '*/node_modules/*' -print0 | xargs -0 shellcheck --severity=warning
```

- 新增或修改规则时，优先考虑能否做成 `check.sh` 的检查，并在 `tests/run_tests.sh` 补回归场景
- 改了规则文本，确认 `templates/prd-example/` 仍能通过 `check.sh`，并重新导出 `templates/export/` 下的样张
- 版本号要在每个 `SKILL.md` 与各插件配置里同步，`check_structure.sh` 会比对

## 许可证
[MIT](LICENSE) © 2026 Charles
