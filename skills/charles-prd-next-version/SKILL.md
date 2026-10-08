---
name: charles-prd-next-version
description: Use when a product already has a PRD and the user wants to plan its next version, whether a major like 2.0 or a minor like 1.1, including producing the whole version package in one go. Not for a brand-new product, not for adding content to a version still in development, and not for documenting code that has no PRD.
metadata:
  version: "1.2.0"
  author: Charles <w1400214654@outlook.com>
---

# 第二版 PRD

> PRD 已有、上一版已发布或已冻结，要规划下一个版本时使用。判据是 **`docs/prd/README.md` 存在，且要写的内容不属于 Development 状态的版本**。往开发中的版本里加内容走 [charles-prd-add-feature](../charles-prd-add-feature/SKILL.md)；没有 PRD 的项目走 [charles-prd-legacy](../charles-prd-legacy/SKILL.md)。

## 前置阅读
- [一键出全部](../charles-prd-standards/rules/one-shot.md)
- [版本管理](../charles-prd-standards/rules/versioning.md)
- [目录结构](../charles-prd-standards/rules/structure.md)
- 命令里的 `<skill 目录>` 见 [主规范](../charles-prd-standards/SKILL.md) 的工具与模板路径

## 五步

### 1. 读现状
先读 `docs/prd/README.md` 的三个版本状态与 `product.md`，再读上一版的 `prd.md`、`scope.md` 与 `notes.md`：

- `scope.md` 的 Later 是这一版最直接的候选范围
- `prd.md` 第 7 章未解决问题里悬着的，这一版要么解决要么继续挂
- `notes.md` 的技术债与待验证项，哪些到了该处理的时候

`product.md` 不重写。产品方向真变了才改它，并在 `decisions.md` 记一条。

### 2. 必问版本号
> 版本号定不下来就不建目录。目录名一旦写错，git tag、冻结规则与发布历史全部对不上。

按 [versioning](../charles-prd-standards/rules/versioning.md) 的 major 与 minor 规则给出候选，让使用者选：

| 候选 | 适用 | 目录内容 |
| --- | --- | --- |
| minor（线上 1.0 则为 1.1） | 小功能、体验修正、不改产品阶段 | `changes.md` 写改了哪些需求编号，必要时附 `tasks.md`、`prototype/`、`diagrams/` |
| major（线上 1.0 则为 2.0） | 产品阶段发生明显变化 | 完整的 `prd.md`、`scope.md`、`tasks.md`、`notes.md`、`prototype/`、`diagrams/` |

使用者也可以给别的号（0.1 这类预发布号同样接受），只要符合 `数字.数字` 且不与已有目录重复。版本号是"已确认"状态才进入第 3 步。

### 3. 两轮提问
与 [charles-prd-new-product](../charles-prd-new-product/SKILL.md) 第 0 步相同，差别只在底本：

- 第一轮七类产品级必答项里，上一版已经定下且没变的（产品形态、运行环境、外部对接）只需确认"没变"，变了的重新问
- 第二轮逐模块功能明细确认以 Later 清单与使用者新提的需求为底本，每个模块需要他定的点不超过四个
- 范围不许自砍：这一版做哪些、砍哪些是使用者的决定，砍掉的继续留在 Later
- 三种状态与开写前自检同样适用，有"未回答"不开写

### 4. 从骨架建新版本目录
从 `templates/prd-template/versions/1.0/` 复制骨架建 `versions/<新版本>/`，**不要复制上一版的内容再删改**，那样会带进上一版的遗留表述。

- 需求编号用新版本号：`REQ-2.0-001`，不延续上一版的序号
- 上一版需求在这一版作废的，在新版 `prd.md` 里标注失效并指向替代，上一版目录不动
- 上一版已上线但 PRD 与实现不符的，不改旧目录，在新版 `changes.md` 或 `prd.md` 的版本历史里记录差异
- 原型从骨架重做或从上一版原型复制后修改都可以，但新版目录保存自己的原型，不覆盖上一版
- 更新 `README.md`：新版本进 Development，上一版保持 Production

### 5. 一次产出
确认完毕后一次产出：

| 产物 | major | minor |
| --- | --- | --- |
| `versions/<版本>/prd.md` | 版本历史加七章，需求带编号 | 不要求 |
| `versions/<版本>/changes.md` | 不要求 | 改了哪些需求编号、新增哪些、作废哪些 |
| `versions/<版本>/scope.md` | In Scope / Later / Out of Scope | 不要求 |
| `versions/<版本>/tasks.md` | 全部任务，界面小节带标注图 | 涉及界面变化的任务 |
| `versions/<版本>/notes.md` | 需求确认记录、待验证、未决 | 需求确认记录 |
| `versions/<版本>/prototype/` 与 `diagrams/` | 按覆盖表做全 | 涉及变化的页面 |
| `decisions.md` | 本版定下的不可逆取舍追加进去 | 同左 |
| `README.md` | 版本状态更新 | 同左 |
| 两份 PDF | 用 `<skill 目录>/tools/export-prd.sh <版本>` 产出 | 同左 |

产出后按 [一键出全部](../charles-prd-standards/rules/one-shot.md) 的第 4、5 步自检并写交付说明。

## 交付闸门
- 版本号经使用者确认，目录名符合 `数字.数字` 且不与已有目录重复
- 新目录从骨架建起，没有上一版遗留表述
- 上一版目录未被改动，作废需求已标注失效并指向替代
- 两轮必问项全部有答案，功能清单经使用者确认
- 需求确认记录每条都有落点
- `README.md` 的三个状态已更新
- `bash <skill 目录>/tools/check.sh docs/prd` 全绿
- 按 [charles-prd-review](../charles-prd-review/SKILL.md) 的清单自评审完毕
