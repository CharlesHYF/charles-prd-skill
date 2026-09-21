---
name: charles-legacy-prd
description: Use when an existing codebase needs product documentation written after the fact for Charles - scanning the implementation to inventory what the product actually does, marking which requirements came from code versus business confirmation, and producing a full PRD package for a project that is already running. Not for defining a brand-new product.
metadata:
  version: "1.0.0"
  author: Charles <w1400214654@outlook.com>
---

# 给已有项目补 PRD

> 项目已经在跑、产品其实已经定义了（只是隐含在实现里），需要的是**从现状反向整理**，不是从零设计。从零定义走 [charles-new-product](../charles-new-product/SKILL.md)。

## 和从零定义的关键差别

| | 从零定义 | 补文档 |
| --- | --- | --- |
| 第一步 | 集中提问 | **先读代码，盘点现状** |
| 需求来源 | 全部来自业务确认 | 一部分从实现提取，一部分来自业务确认 |
| 提问内容 | 做什么、怎么做 | **为什么这么做、哪些是有意为之、哪些是遗留妥协** |
| 最大风险 | 在未定前提上写太多 | **把 bug 和临时妥协写成产品需求** |

最后一行最要命。代码里的行为不等于产品意图，不区分的话会把赶工留下的坑固化成"设计如此"，以后想改反而要先推翻文档。

## 前置阅读
- [目录结构](../charles-prd-standards/rules/structure.md)
- [任务与交互规格](../charles-prd-standards/rules/tasks.md)

## 五步

### 1. 全量扫描，产出功能清单
> 这一步只盘点不写细节。很多旧项目自己都不知道有哪些功能，盘点本身就有价值。

按下面六个入口系统性扫描，每一类都要过，漏一类就会漏掉一整块功能：

| 扫描入口 | 能盘出什么 | 典型位置 |
| --- | --- | --- |
| 路由与接口定义 | 用户可触发的操作 | `routers/`、`controller/`、`api/`、路由表 |
| 前端页面与组件 | 用户可见的界面与交互 | `views/`、`pages/`、`app/` |
| 数据模型 | 实体、字段、关系、状态枚举 | `entity/`、`models/`、迁移脚本 |
| 定时任务与消息消费 | 用户看不见的后台流程 | cron 配置、队列消费者、`job/` |
| 权限与角色配置 | 谁能做什么 | 权限表、角色定义、中间件 |
| 配置与开关 | 可变行为与灰度策略 | `.env.example`、配置中心、feature flag |

产出一份清单，每行记：模块、功能名、入口位置、当前行为一句话。**先把清单交给 Charles 确认完整性与优先级**，不要直接往下写。

**规模预警**：清单超过 80 个功能时，明确告诉 Charles 全量整理的工作量，并建议按模块分期，先补正在改的和最核心的。

### 2. 确认清单与版本号
- 清单有没有漏、有没有已废弃但代码还在的
- **版本号对应当前线上版本**（线上是 2.3 就写 `versions/2.3/`），不要从 1.0 重新开始，那样和实际发布历史对不上
- 确认补文档的范围：全量、只补正在改的模块、还是只补核心流程

### 3. 按模块整理需求条目，标注来源
每条需求必须带来源标记：

```markdown
- REQ-2.3-001 [已实现] 用户连续登录失败五次后锁定十分钟
- REQ-2.3-002 [已实现·待确认] 锁定期间管理员可强制解锁，不确定是否有意设计
- REQ-2.3-003 [新增] 锁定时向用户邮箱发送提醒
```

| 标记 | 含义 | 后续处理 |
| --- | --- | --- |
| `[已实现]` | 行为与代码一致，且确认是有意设计 | 直接留在 PRD 里 |
| `[已实现·待确认]` | 代码这么做，但不确定是不是有意为之 | 第 4 步集中问，问完必须转成别的标记 |
| `[新增]` | 这次要补的功能，代码里还没有 | 按正常需求走 |
| `[遗留]` | 确认是临时妥协或历史包袱 | 移出需求主体，记进 `notes.md` 的技术债清单 |

**行为描述以代码为准**，不以已有 README 或注释为准——它们可能早就过期了。两者不一致时按代码写，并把不一致记进 `notes.md`。

### 4. 集中提问所有待确认项
把全部 `[已实现·待确认]` 一次性列出来问，每条附上代码位置，问三件事：

1. 这个行为是有意设计还是遗留？
2. 如果是设计，背后的约束是什么（合规要求、业务规则、外部系统限制）？
3. 如果是遗留，要不要记进技术债、什么时候处理？

同时按 [charles-new-product](../charles-new-product/SKILL.md) 的七类必答项检查缺口——代码能告诉你"做了什么"，告诉不了你"为什么做、边界在哪、关键数值的依据"。这些一并问。

### 5. 产出完整 PRD 包
确认完毕后一次产出：

| 产物 | 补文档场景下的差别 |
| --- | --- |
| `product.md` | 产品定义从现状反推，目标用户与核心问题要问 Charles 确认 |
| `versions/<线上版本>/prd.md` | 八章节，需求带来源标记，**流程图与状态图用 Mermaid 写在正文里** |
| `versions/<线上版本>/scope.md` | In Scope 写已实现范围，Later 写清单里确认要做的，Out of Scope 写明确不做的 |
| `versions/<线上版本>/tasks.md` | **只为 `[新增]` 与需要改的功能写任务**，已实现且不动的不写交互规格 |
| `versions/<线上版本>/notes.md` | 技术债清单、文档与代码不一致处、问不出来的项 |
| `decisions.md` | 第 4 步问出来的设计约束与理由 |
| 两份 PDF | 用 `tools/export-prd.sh` 产出 |

**不要为已实现且不打算改的功能写界面标注图与交互规格**，那是纯消耗。任务文档只覆盖接下来要动的部分。

## 交付闸门
- 六个扫描入口全部过完，功能清单经 Charles 确认
- 所有 `[已实现·待确认]` 已转成 `[已实现]` 或 `[遗留]`
- 行为描述与代码一致，不一致处已记进 `notes.md`
- 版本号对应当前线上版本
- `bash tools/check.sh docs/prd` 全绿
- 按 [charles-prd-review](../charles-prd-review/SKILL.md) 的八类清单自评审完毕
