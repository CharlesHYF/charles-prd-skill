---
name: charles-prd-add-feature
description: Use when a product already has a PRD whose target version is still in development and the user wants to add requirements, tasks or prototype pages into that same version, including producing all the additions in one go. Not for a frozen or released version, not for a brand-new product, and not for documenting code that has no PRD.
metadata:
  version: "1.2.0"
  author: Charles <w1400214654@outlook.com>
---

# 在原有基础上加 PRD

> PRD 已有、目标版本还在 Development、要往里面加内容时使用。判据是 **`docs/prd/README.md` 里要加的版本处于 Development 状态**。目标版本已经是 Production 的不许改，走 [charles-prd-next-version](../charles-prd-next-version/SKILL.md) 开新版本。

## 前置阅读
- [一键出全部](../charles-prd-standards/rules/one-shot.md)
- [版本管理](../charles-prd-standards/rules/versioning.md) 的发布后冻结
- [目录结构](../charles-prd-standards/rules/structure.md) 的需求编号
- 命令里的 `<skill 目录>` 见 [主规范](../charles-prd-standards/SKILL.md) 的工具与模板路径

## 五步

### 1. 判定目标版本能不能加
读 `docs/prd/README.md`：

| 目标版本状态 | 处理 |
| --- | --- |
| Development | 继续，往该版本目录追加 |
| Production | **拒绝**。告诉使用者该版本已冻结，要加内容走 [charles-prd-next-version](../charles-prd-next-version/SKILL.md) 开 minor 或 major |
| Next | 可以加，但先确认是不是该直接把它转为 Development 开工 |

使用者没说版本时，默认取 Development 状态的那个；没有 Development 版本就按 Production 处理，引导走模式 3。

### 2. 读现有内容
通读目标版本的 `prd.md`、`scope.md`、`tasks.md`、`notes.md` 与 `product.md`、`decisions.md`，弄清三件事：

- 现有的模块划分与命名，新内容要归进已有模块还是新开一个
- 已分配到哪个 REQ 与 Task 编号，新编号接在后面
- 要加的内容是不是已经在 `scope.md` 的 Later 或 Out of Scope 里。在 Out of Scope 里的要先问使用者是否推翻当时的决定，推翻了记进 `decisions.md`

### 3. 两轮提问
与 [charles-prd-new-product](../charles-prd-new-product/SKILL.md) 第 0 步相同，范围只限新增内容：

- 第一轮七类必答项里，只问新增内容触及的类别（新接外部系统、新角色、新的关键数值），其余已在 `product.md` 与现有 `prd.md` 里定下
- 第二轮逐模块明细确认按新增的模块或功能走，字段、状态、边界、异常、关键数值逐项列草案
- 新增内容与现有需求冲突的，先摆出来让使用者定，再写
- 三种状态与开写前自检同样适用，有"未回答"不开写

### 4. 追加，不重排
> 追加进现有文件，不新建版本目录，也不重排已有编号。

| 文件 | 怎么加 |
| --- | --- |
| `prd.md` | 功能需求章节里归进对应模块或新开小节，需求编号接在现有最大序号之后；版本历史表加一行写明本次追加；名词解释与字段定义补新术语与新表；涉及的整体流程图、功能清单同步更新 |
| `scope.md` | 新内容写进 In Scope；从 Later 挪过来的从 Later 删掉 |
| `tasks.md` | 新任务编号接在现有最大序号之后，六个小节齐全，界面小节带标注图 |
| `prototype/` | 新页面按覆盖表做出来；现有页面要改的直接改，改完**重跑受影响页面的 `capture.mjs`，再用 `annotate.mjs` 校验清单** |
| `diagrams/` | 新页面的截图清单与标注清单 |
| `notes.md` | 需求确认记录追加本次问出来的结论与落点 |
| `decisions.md` | 推翻过往范围决定的记一条 |

现有需求被新内容改变行为的，不改原条目文字，原条目标注失效并指向新条目，见 [writing](../charles-prd-standards/rules/writing.md) 的失效需求写法。

### 5. 一次产出
追加的内容一次写全：新增的 REQ、Task、原型页面、截图与标注图、同步更新的 `scope.md`、`notes.md`、`decisions.md`，以及重新导出的两份 PDF。

产出后按 [一键出全部](../charles-prd-standards/rules/one-shot.md) 的第 4、5 步自检并写交付说明，交付说明里单独列出本次新增与作废的编号。

## 交付闸门
- 目标版本是 Development，没有改动任何 Production 版本目录
- 新 REQ 与 Task 编号接在现有编号之后，没有复用或重排
- 被改变行为的旧需求已标注失效并指向新条目
- 新页面有标注图，改过的页面已重新截图与标注，`check.sh` 的坐标时效检查通过
- 两轮必问项全部有答案，需求确认记录每条都有落点
- `bash <skill 目录>/tools/check.sh docs/prd` 全绿
- 按 [charles-prd-review](../charles-prd-review/SKILL.md) 的清单自评审完毕
