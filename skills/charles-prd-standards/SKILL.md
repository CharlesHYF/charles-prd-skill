---
name: charles-prd-standards
description: Use when writing or organizing product documentation for Charles's projects - PRD, product definition, scope, version planning, clickable HTML prototypes, and flow or architecture diagrams. Covers the minimal docs/prd structure, version freezing rules, prototype boundaries, the four working modes, and how product docs hand off to the coding standards.
metadata:
  version: "1.1.0"
  author: Charles <w1400214654@outlook.com>
---

# Charles PRD

> Charles 的产品文档与原型规范。面向独立开发者的单人流程，目标是几个月后还能回答三个问题：**为什么做、这一版做什么、界面和交互是什么**。

## 何时使用
- 从零定义一个新产品，需要写产品定义与第一版 PRD
- 给已经在跑的项目补 PRD，原型要与线上一模一样
- 规划下一个版本，或往开发中的版本追加需求
- 做可点击的产品原型，或画流程图与架构图
- 需要判断某个信息该写进 PRD、模块文档还是 commit message

## 核心原则
> **能用一个文件解决就不要拆成三个；只有当内容明显变大时再拆目录。**

不要提前设计未来的复杂度。目录随产品复杂度增长，而不是一开始就模拟一个二十人产品团队。

## 四种模式
| 模式 | 判据 | 工作流 |
| --- | --- | --- |
| 1 第一份 PRD，从 0 生成 | 代码不存在，PRD 不存在 | [charles-new-product](../charles-new-product/SKILL.md) |
| 2 项目写完了，PRD 没做 | 代码在跑，PRD 不存在或与代码不符 | [charles-legacy-prd](../charles-legacy-prd/SKILL.md) |
| 3 第二版 PRD | PRD 已有，目标版本已发布或已冻结，要规划下一个版本 | [charles-next-version](../charles-next-version/SKILL.md) |
| 4 在原有基础上加 PRD | PRD 已有，目标版本还在 Development，要往里面加内容 | [charles-add-feature](../charles-add-feature/SKILL.md) |

四种模式都支持**一键出全部**：先按必问项问完，确认后一次产出全部文档、原型、标注图与 PDF，流程见 [one-shot](rules/one-shot.md)。判定不了模式时先读 `docs/prd/README.md` 的版本状态。

其它场景：

| 场景 | 去处 |
| --- | --- |
| 评审 PRD、找出内容矛盾 | [charles-prd-review](../charles-prd-review/SKILL.md) |
| 判断信息该写在哪 | [boundaries](rules/boundaries.md) |

## 规则模块
| 模块 | 内容 |
| --- | --- |
| [one-shot](rules/one-shot.md) | 一键出全部的统一流程：先问后写、状态自检、一次产出、自检与交付说明 |
| [structure](rules/structure.md) | 目录结构、每个文件存什么、什么时候更新 |
| [versioning](rules/versioning.md) | 版本目录、major 与 minor、发布后冻结规则 |
| [prototype](rules/prototype.md) | 原型定位、按形态的覆盖表、从真实前端复刻、编码规范豁免边界、时效性 |
| [diagrams](rules/diagrams.md) | 图的用途边界、视觉约束、等宽标注图的生成与覆盖要求 |
| [boundaries](rules/boundaries.md) | 产品文档与实现文档的职责边界，信息该落在哪里 |
| [tasks](rules/tasks.md) | 任务编号、固定结构、交互规格的七个必填字段 |
| [writing](rules/writing.md) | 需求描述句式、可判定性、禁用表达与产品黑话 |
| [export](rules/export.md) | 导出 PDF 的单向关系、交付记录与产物归属 |
| [collaboration](rules/collaboration.md) | 工作节奏、分析输出格式、产品取舍的处理 |

## 最小目录
```
project/docs/prd/
├── README.md              版本导航
├── product.md             长期稳定的产品定义
├── decisions.md           跨版本的不可逆决策
└── versions/
    ├── 1.0/
    │   ├── prd.md         版本历史、需求概述、产品描述、功能需求、非功能需求
    │   ├── scope.md       In Scope / Later / Out of Scope
    │   ├── tasks.md       任务与交互规格，带界面图
    │   ├── notes.md       需求确认记录、临时想法与待验证问题
    │   ├── prototype/     可点击的 HTML 原型
    │   └── diagrams/      原型截图与坐标、标注清单，外部导入的位图与来源说明
    ├── 2.0/
    └── 3.0/
```

骨架在 [`templates/prd-template/`](templates/prd-template/)，复制为起点，逐项替换 `[待填]`；完整写法参照 [`templates/prd-example/`](templates/prd-example/) 的订单系统样例，不要复制样例再删改。

## 工具与模板路径
- 文中的 `tools/`、`templates/` 指 `<skill 目录>` 下的同名目录，不在产品仓里
- `<skill 目录>` 是当前加载的 SKILL.md 所在目录；每个 skill 各自带 `tools` 与 `templates` 软链，加载哪个就用哪个的目录
- 命令一律在产品仓根目录执行，如 `bash <skill 目录>/tools/check.sh docs/prd`

## 工具选择
| 内容 | 用什么 |
| --- | --- |
| 产品定义、需求、边界 | Markdown |
| 页面布局、按钮、弹窗、状态、完整操作流程 | HTML Prototype |
| 复杂流程的解释、系统模块关系与数据流 | Mermaid 手绘风格图，写在 Markdown 里 |
| 界面元素位置与标注 | `capture.mjs` 截原型并量坐标，`annotate.mjs` 生成标注图 |
| 视觉风格探索、组件细节、Design Tokens | Penpot（可选，需要设计画布时才引入） |

工具能力与价格会变，长期稳定的事实来源放在 Git 里。

## 交付红线
1. **产品定义只写一次**：`product.md` 是长期稳定的，版本相关的内容一律写进 `versions/<版本>/prd.md`
2. **版本目录发布后冻结**，行为变更一律开新的 minor 目录，见 [versioning](rules/versioning.md)
3. **需求条目必须编号**（`REQ-<版本>-<序号>`），测试用例引用该编号建立追溯
4. **功能需求按模块分组**，每个功能含场景描述、需求条目、字段定义、流程，不平铺成一长串条目
5. **名词解释与字段定义是必需的**，第一次出现的非通用术语必须进表，涉及数据的功能必须有六列字段表
6. **原型不受编码规范约束，但也不许被复制进 `src/`**，见 [prototype](rules/prototype.md)
7. **Release Criteria 只写产品维度判据**，工程交付标准由项目自己的编码规范与交付闸门管，PRD 不重复定义
8. **图用 Mermaid 写在 Markdown 里**，是文本不是位图；**界面标注图必须由 `annotate.mjs` 从原型截图生成**，不手画界面示意，每个任务的界面小节都要有，见 [diagrams](rules/diagrams.md)
9. 文档用中文，`Non-goals`、`Release Criteria`、`In Scope` 这类没有稳定中文对应的正式术语保留英文
10. **Markdown 是唯一源头**，PDF 是导出产物，不在 PDF 上改内容，见 [export](rules/export.md)
11. **需求描述必须能写成测试用例**，出现"优化"、"提升体验"、"合理"这类无法判定的表述一律改写，见 [writing](rules/writing.md)
12. **每个任务必须写全交互规格七个字段**（触发、前置条件、正常路径、边界情况、错误处理、兜底行为、显示规则），提示文案写完整原文，见 [tasks](rules/tasks.md)
13. **先问后写，答案落进文档**：产出前两轮必问项全部有答案，每条结论记进 `notes.md` 的需求确认记录并写明落点，见 [one-shot](rules/one-shot.md)
14. **范围不许自砍**：1.0 不等于 MVP，功能清单以 Charles 确认的全量为准，分期是他的决定
