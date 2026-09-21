---
name: charles-prd-standards
description: Use when writing or organizing product documentation for Charles's projects - PRD, product definition, scope, version planning, clickable HTML prototypes, and flow or architecture diagrams. Covers the minimal docs/prd structure, version freezing rules, prototype boundaries, and how product docs hand off to the coding standards.
metadata:
  version: "1.0.0"
  author: Charles <w1400214654@outlook.com>
---

# Charles PRD

> Charles 的产品文档与原型规范。面向独立开发者的单人流程，目标是几个月后还能回答三个问题：**为什么做、这一版做什么、界面和交互是什么**。

## 何时使用
- 从零定义一个新产品，需要写产品定义与第一版 PRD
- 规划新版本，需要写 `prd.md` 与 `scope.md`
- 做可点击的产品原型，或画流程图与架构图
- 需要判断某个信息该写进 PRD、模块文档还是 commit message

## 核心原则
> **能用一个文件解决就不要拆成三个；只有当内容明显变大时再拆目录。**

不要提前设计未来的复杂度。目录随产品复杂度增长，而不是一开始就模拟一个二十人产品团队。

## 场景路由
| 场景 | 工作流 |
| --- | --- |
| 从零定义新产品 | [charles-new-product](../charles-new-product/SKILL.md) |
| 评审 PRD、找出内容矛盾 | [charles-prd-review](../charles-prd-review/SKILL.md) |
| 规划新版本 | 复制模板建 `versions/<版本>/`，按 [structure](rules/structure.md) 写 |
| 判断信息该写在哪 | [boundaries](rules/boundaries.md) |

## 规则模块
| 模块 | 内容 |
| --- | --- |
| [structure](rules/structure.md) | 目录结构、每个文件存什么、什么时候更新 |
| [versioning](rules/versioning.md) | 版本目录、major 与 minor、发布后冻结规则 |
| [prototype](rules/prototype.md) | 原型定位、编码规范豁免边界、时效性 |
| [diagrams](rules/diagrams.md) | 图的用途边界、视觉约束、生成说明 |
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
    │   ├── prd.md         这一版为什么做、做什么
    │   ├── scope.md       In Scope / Later / Out of Scope
    │   ├── tasks.md       任务与交互规格，带界面图
    │   ├── notes.md       临时想法与待验证问题
    │   ├── prototype/     可点击的 HTML 原型
    │   └── diagrams/      流程图与架构图
    ├── 2.0/
    └── 3.0/
```

模板在 [`templates/prd-template/`](templates/prd-template/)，直接复制为起点。

## 工具选择
| 内容 | 用什么 |
| --- | --- |
| 产品定义、需求、边界 | Markdown |
| 页面布局、按钮、弹窗、状态、完整操作流程 | HTML Prototype |
| 复杂流程的解释、系统模块关系与数据流 | Mermaid 手绘风格图，写在 Markdown 里 |
| 界面元素位置与标注 | 内联 SVG |
| 视觉风格探索、组件细节、Design Tokens | Penpot（可选，需要设计画布时才引入） |

工具能力与价格会变，长期稳定的事实来源放在 Git 里。

## 交付红线
1. **产品定义只写一次**：`product.md` 是长期稳定的，版本相关的内容一律写进 `versions/<版本>/prd.md`
2. **版本目录发布后冻结**，行为变更一律开新的 minor 目录，见 [versioning](rules/versioning.md)
3. **需求条目必须编号**（`REQ-<版本>-<序号>`），测试用例引用该编号建立追溯
4. **原型不受编码规范约束，但也不许被复制进 `src/`**，见 [prototype](rules/prototype.md)
5. **Release Criteria 只写产品维度判据**，工程交付标准由项目自己的编码规范与交付闸门管，PRD 不重复定义
6. **图用 Mermaid 或内联 SVG 写在 Markdown 里**，是文本不是位图；只有外部导入的截图才需要来源说明
7. 文档用中文，`Non-goals`、`Release Criteria`、`In Scope` 这类没有稳定中文对应的正式术语保留英文
8. **Markdown 是唯一源头**，PDF 是导出产物，不在 PDF 上改内容，见 [export](rules/export.md)
9. **需求描述必须能写成测试用例**，出现"优化"、"提升体验"、"合理"这类无法判定的表述一律改写，见 [writing](rules/writing.md)
10. **每个任务必须写全交互规格七个字段**（触发、前置条件、正常路径、边界情况、错误处理、兜底行为、显示规则），提示文案写完整原文，见 [tasks](rules/tasks.md)
