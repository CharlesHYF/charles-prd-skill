<div align="center">

# charles-prd-skill

![Version](https://img.shields.io/badge/version-1.0.0-blue) ![Scope](https://img.shields.io/badge/scope-PRD%20%7C%20Prototype%20%7C%20Diagrams-informational) ![AI Tools](https://img.shields.io/badge/AI%20tools-Claude%20Code%20%7C%20Codex%20%7C%20Cursor%20%7C%20Gemini-brightgreen) ![Docs](https://img.shields.io/badge/docs-%E4%B8%AD%E6%96%87-red)

</div>

Charles 的产品文档与原型规范，面向独立开发者的单人流程。

目标是几个月后还能回答三个问题：**为什么做、这一版做什么、界面和交互是什么**。核心取舍是能用一个文件解决就不拆成三个，目录随产品复杂度增长，而不是一开始就模拟一个二十人产品团队。

**本仓不依赖任何其它 skill。** 涉及编码规范、测试与交付闸门的部分一律写成通用表述，由使用者的项目决定具体是什么。

## 组成

| skill | 用途 |
| --- | --- |
| `charles-prd-standards` | 规范本体：目录结构、版本管理、原型定位、图、信息落点边界 |
| `charles-new-product` | 从零定义新产品：产品定义、PRD、原型、发布、进入下一版的短循环 |
| `charles-prd-review` | PRD 评审：找需求矛盾、范围与目标脱节、无法判定的 Release Criteria |

## 安装

```bash
git clone https://github.com/CharlesHYF/charles-prd-skill.git ~/charles-prd-skill
```

```bash
# Claude Code（缺省目标 ~/.claude/skills）
bash ~/charles-prd-skill/tools/install-skills.sh

# 其它工具把目标 skills 目录作为参数传进去
bash ~/charles-prd-skill/tools/install-skills.sh ~/.agents/skills    # Codex / Qoder / Trae
bash ~/charles-prd-skill/tools/install-skills.sh ~/.trae/skills      # Trae 专属路径
bash ~/charles-prd-skill/tools/install-skills.sh ~/.rovodev/skills   # Rovo Dev
```

装完是三个软链，改完开发仓立即生效，不需要重新安装。

### Claude Code plugin 方式（可选）
```
/plugin marketplace add ~/charles-prd-skill
/plugin install charles-prd@charles-prd
```

### Gemini CLI
```bash
git clone https://github.com/CharlesHYF/charles-prd-skill.git ~/.gemini/extensions/charles-prd
```

## 更新

```bash
cd ~/charles-prd-skill && git pull origin main
```

软链方式下 pull 完即生效。

## 最小目录

```
project/docs/prd/
├── README.md              版本导航与状态
├── product.md             长期稳定的产品定义
├── decisions.md           跨版本的不可逆决策
└── versions/
    ├── 1.0/
    │   ├── prd.md         八个固定章节，需求带编号
    │   ├── scope.md       In Scope / Later / Out of Scope
    │   ├── notes.md       临时想法与待验证问题
    │   ├── prototype/     可点击的 HTML 原型
    │   └── diagrams/      PNG 加同名生成说明
    ├── 2.0/
    └── 3.0/
```

模板在 [`templates/prd-template/`](templates/prd-template/)，直接复制为起点。

## 结构校验器

`tools/check.sh` 把确定性规则变成会 fail 的检查，共七项：

```bash
bash tools/check.sh docs/prd
```

| 检查 | 内容 |
| --- | --- |
| 一 | 必需文件（`README.md`、`product.md`、`versions/`） |
| 二 | 版本目录命名（必须是明确版本号，禁止 current / latest / new） |
| 三 | 版本内必需文档（major 要 `prd.md` 与 `scope.md`，minor 至少要 `changes.md`） |
| 四 | `prd.md` 八个章节不增不减 |
| 五 | 需求编号存在且不重复 |
| 六 | 每张图有同名生成说明 |
| 七 | `README.md` 声明三个版本状态 |

内容级的矛盾（需求打架、范围与目标脱节、判据无法判定）脚本查不了，由 `charles-prd-review` 的七类清单人工过。

## 核心约定

| 项目 | 规范 |
| --- | --- |
| 产品定义 | `product.md` 只写一次，版本相关内容一律进 `versions/<版本>/prd.md` |
| 版本目录 | 直接写明确版本号，发布后冻结，只允许修正笔误 |
| 版本与 Git | 发布时打 tag，tag 名与目录名对应 |
| 需求编号 | `REQ-<版本>-<三位序号>`，不复用，作废时标注失效 |
| 原型定位 | 开发期间是交互事实来源，发布后转历史存档，实现代码成为唯一事实来源 |
| 原型规范 | 不受编码规范约束，但不许被复制进 `src/` |
| 图 | 每张 PNG 配同名 `.md` 记录提示词要点与生成日期 |
| Release Criteria | 只写产品维度判据，工程标准由项目自己的交付体系管 |
| 决策落点 | 跨版本不可逆的进 `decisions.md`，模块级进实现文档，单次改动进 commit message |
| 文档语言 | 中文，`Non-goals` / `Release Criteria` / `In Scope` 这类术语保留英文 |

## 仓库自测

```bash
bash tests/run_tests.sh          # check.sh 回归测试，15 项断言
bash tests/check_structure.sh    # skill 完整性、六处版本号、Markdown 死链
```
