---
name: charles-new-product
description: Use when starting a brand-new product from zero for Charles, including requests to produce the whole PRD package in one go. Not for adding a feature to an existing product, and not for documenting a product whose code is already running.
metadata:
  version: "1.0.0"
  author: Charles <w1400214654@outlook.com>
---

# 新产品定义

> 从零定义一个产品时使用。判据是**代码是否已经存在**：从零设计走本工作流；项目已经在跑、要把现状整理成文档，走 [charles-legacy-prd](../charles-legacy-prd/SKILL.md)。

## 前置阅读
- [目录结构](../charles-prd-standards/rules/structure.md)
- [与编码规范的边界](../charles-prd-standards/rules/boundaries.md)
- 命令里的 `<skill 目录>` 见 [主规范](../charles-prd-standards/SKILL.md) 的工具与模板路径

## 短循环
不要把 PRD、设计、原型、开发拆成很多正式阶段，保持一个短循环。

### 0. 集中提问，问到没有阻塞问题为止
> Charles 说「一键出全部」时，**不是立刻开写**，而是先把该问的一次问完，确认后再一次产出全部内容。
> 带着未定前提写出来的内容，写得越多返工越多。问清的成本远低于返工。

按下面七类逐项检查，**每一类都要有明确答案**才能进入产出：

| 类别 | 要问清什么 | 不问清的后果 |
| --- | --- | --- |
| 产品形态与边界 | 这一版做成什么、明确不做什么 | 范围蔓延，Non-goals 写不出来 |
| 目标用户优先级 | 先服务谁，核心流程先做哪条 | 主路径定不了，原型无从下手 |
| 运行环境与依赖 | 跑在哪、用什么登录、团队现在用什么 | 身份、权限、集成方式全部悬空 |
| 内容与数据来源 | 内容从哪来、数据谁提供、是否自建 | 影响一整组功能的存在与否 |
| 外部系统对接 | 接哪个系统、受控操作有哪些、对接人是谁 | Release Criteria 无法验证 |
| 关键数值 | 有效期、阈值、频率、容量、超时、重试次数 | 只能推算，上线后大面积返工 |
| 合规与硬约束 | 哪些是不能降级的、失败时能不能放行 | 降级策略可能违反合规要求 |

#### 提问方式

- **交互卡片一次最多四个问题，超过四个就分批问**。按阻塞程度排序，先问最阻塞的四个
- **每批必须等到回答，才问下一批**。不允许把剩下的问题写成文本列表然后当作"已经问过"
- 每个问题给出两到四个具体选项与推荐项，降低回答成本；Charles 可以直接选，也可以给别的答案
- 回答后如果引出新的必问项，再问一轮，并说明为什么需要第二轮

#### 三种状态要分清
> 这是最容易出错的地方：**"对方没回答"不等于"对方不知道"**。

| 状态 | 含义 | 处理 |
| --- | --- | --- |
| 已确认 | Charles 给了明确答案 | 写进 PRD，不加待确认标记 |
| 明确不知道 | Charles 说了"这个我也不清楚"或"你按默认写" | 按默认值写并就地标注待确认，记入 `notes.md` |
| **未回答** | 这个问题 Charles 根本没有回应过 | **必须重新问，不能开写** |

把"未回答"当成"不知道"处理，等于自己替 Charles 做了决定，然后在交付说明里写"这些我问了但你没回答"——问题是他可能压根没看到那条问题。

#### 开写前的状态自检
产出任何文件之前，先把全部必问项列一遍，逐项标注状态。**只要还有一项是"未回答"，就不能开写**，要明确告诉 Charles：

> 还有 N 个问题没有答案，需要你回答后我才开始产出。要么回答它们，要么明确说「按你的默认值写，标注待确认」。

后半句是给 Charles 的逃生口——他可以主动授权按默认值写，但这是**他给的明确授权**，不是 Agent 自己决定的。

关键数值一律问，拿到"按默认写"的授权后才在需求条目里就地标注待确认，见 [writing](../charles-prd-standards/rules/writing.md)。

判据：**每一项必问都有状态吗？状态里还有"未回答"吗？** 有就继续问，全部落到"已确认"或"明确不知道"才开写。

### 1. 写 product.md
长期稳定的产品定义：产品是什么、目标用户是谁、他们的核心问题、为什么这个产品值得使用、三条产品原则。

**这一步只做一次**，后续版本不重写它。写不出目标用户与核心问题就先别往下走，后面每一步都要靠它做取舍。

### 2. 写 versions/1.0/prd.md 与 scope.md
按固定结构（版本历史加七章）写 `prd.md`，需求条目带编号（`REQ-1.0-001`）。

`scope.md` 三段式：In Scope / Later / Out of Scope。**Out of Scope 比 In Scope 更重要**，它是后面拒绝范围蔓延的依据。

### 3. 先做核心 HTML Prototype
先做核心 Journey 那一条路径，不要一上来做完整页面集。原型只需要能点、能表达 Empty / Loading / Success / Error 四种状态。

这一步经常反过来改第 2 步：画出来才发现流程不通。改 PRD 再改原型，不要只改原型。

### 4. 补必要的流程图与架构图
**图用 Mermaid 直接写在 `prd.md` 与 `tasks.md` 正文里**，不要单独建文件放进 `diagrams/`——写进独立文件的话正文没有图、导出的 PDF 也没有图，等于白画。

只画 PRD 里已定义的节点。横向图控制在 6 个节点以内，细则见 [diagrams](../charles-prd-standards/rules/diagrams.md)。

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

## 一次产出的完整清单
确认完毕后一次产出下面全部内容，不分批交付：

| 产物 | 内容 |
| --- | --- |
| `docs/prd/README.md` | 版本导航与三个状态 |
| `docs/prd/product.md` | 产品定义、目标用户、核心问题、产品原则 |
| `docs/prd/decisions.md` | 本次确认中定下的不可逆取舍 |
| `versions/1.0/prd.md` | 版本历史加七章，需求带编号，**流程图与状态图用 Mermaid 写在正文里** |
| `versions/1.0/scope.md` | In Scope / Later / Out of Scope |
| `versions/1.0/tasks.md` | 任务与交互规格，**界面标注图内联 SVG** |
| `versions/1.0/notes.md` | 问不出来的待验证问题与影响范围 |
| `versions/1.0/prototype/` | 核心 Journey 的可点击原型，含四种状态 |
| 两份 PDF | 用 `<skill 目录>/tools/export-prd.sh` 产出，产品需求对外、任务规格内部 |

产出后自己跑一遍校验与评审再交付：

```bash
bash <skill 目录>/tools/check.sh docs/prd
```

再按 [charles-prd-review](../charles-prd-review/SKILL.md) 的八类清单自评审，发现的矛盾直接改掉，改不了的列进交付说明。

## 交付闸门
- `product.md`、`versions/1.0/prd.md`、`scope.md` 三个文件齐全
- 需求条目全部带编号
- 原型能走通核心 Journey，四种状态齐全
- 外部导入的位图有同名来源说明
- `docs/prd/**/prototype/` 已加进项目的规范校验排除清单
- 发布时 tag 已打、版本目录已冻结、README 状态已更新
- **七类必问项全部有答案**，问不出来的已记入 `notes.md` 并写明影响范围
- 推算出来的数值已在需求条目里就地标注
