---
name: charles-new-product
description: Use when starting a brand-new product from zero for Charles - defining the product, writing the first PRD and scope, building a clickable HTML prototype, and driving the short loop from definition through release to the next version. Not for adding a feature to an existing product.
metadata:
  version: "1.0.0"
  author: Charles <w1400214654@outlook.com>
---

# 新产品定义

> 从零定义一个产品时使用。判据是**这个产品的 `product.md` 是否已经存在**：不存在走本工作流，存在就直接开新的版本目录。

## 前置阅读
- [目录结构](../charles-prd-standards/rules/structure.md)
- [与编码规范的边界](../charles-prd-standards/rules/boundaries.md)

## 短循环
不要把 PRD、设计、原型、开发拆成很多正式阶段，保持一个短循环。

### 1. 写 product.md
长期稳定的产品定义：产品是什么、目标用户是谁、他们的核心问题、为什么这个产品值得使用、三条产品原则。

**这一步只做一次**，后续版本不重写它。写不出目标用户与核心问题就先别往下走，后面每一步都要靠它做取舍。

> **写的过程中随时数未解决问题。累计超过三条阻塞性问题就停下来集中确认，不要先写完再列清单。**
> 阻塞性指的是：这个问题的答案会改变已经写下的需求。比如「接哪个业务系统」决定 Release Criteria 能不能验证，「某个概念的确切含义」可能推翻一整组需求。带着这些未知继续写，写出来的比例越大，返工的比例就越大。

### 2. 写 versions/1.0/prd.md 与 scope.md
按固定八章节写 `prd.md`，需求条目带编号（`REQ-1.0-001`）。

`scope.md` 三段式：In Scope / Later / Out of Scope。**Out of Scope 比 In Scope 更重要**，它是后面拒绝范围蔓延的依据。

### 3. 先做核心 HTML Prototype
先做核心 Journey 那一条路径，不要一上来做完整页面集。原型只需要能点、能表达 Empty / Loading / Success / Error 四种状态。

这一步经常反过来改第 2 步：画出来才发现流程不通。改 PRD 再改原型，不要只改原型。

### 4. 补必要的流程图与架构图
只画 PRD 里已定义的节点。**每张图配一个同名 `.md` 记录提示词要点与生成日期**，细则见 [diagrams](../charles-prd-standards/rules/diagrams.md)。

### 5. 边开发边修 PRD 与 Prototype
进入编码阶段，这一步起同时受项目编码规范约束。产品侧要做到三件事：

- 实现文档在功能描述里引用需求编号，建立双向追溯
- 实现过程中发现 PRD 描述有误，**先改 PRD 再改代码**，不要让代码悄悄偏离文档
- 原型此时仍是交互事实来源，改了交互要同步原型

编码规范、测试要求与交付闸门由项目自己的规范体系管，本工作流不重复定义。

### 6. 发布 1.0
发布动作包含三件事，缺一不可：

1. 打 git tag，**tag 名与版本目录名对应**（`1.0` 目录对应 `v1.0`）
2. **冻结 `versions/1.0/`**，此后只允许修正笔误
3. 更新 `README.md` 的版本状态：1.0 转为 Production，原型转为历史存档，实现代码成为唯一事实来源

### 7. 复制最小骨架开始 2.0
从 `templates/prd-template/versions/1.0/` 复制骨架建 `versions/2.0/`，**不要复制 1.0 的内容再删改**，那样会带进上一版的遗留表述。

## 交付闸门
- `product.md`、`versions/1.0/prd.md`、`scope.md` 三个文件齐全
- 需求条目全部带编号
- 原型能走通核心 Journey，四种状态齐全
- 每张图有同名生成说明
- `docs/prd/**/prototype/` 已加进项目的规范校验排除清单
- 发布时 tag 已打、版本目录已冻结、README 状态已更新
