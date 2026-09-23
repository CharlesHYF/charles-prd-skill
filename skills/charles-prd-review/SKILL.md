---
name: charles-prd-review
description: Use when reviewing a PRD or product document for Charles - finding internal contradictions between requirements, scope and goals, unverifiable release criteria, broken requirement references, and gaps the structure checker cannot detect. Also use to pressure-test a draft before it goes into development.
metadata:
  version: "1.0.0"
  author: Charles <w1400214654@outlook.com>
---

# PRD 评审

> 评审一份 PRD 时使用。结构问题由 `tools/check.sh` 拦，本工作流只管**脚本查不了的内容矛盾**：需求之间打架、范围与目标对不上、判据无法判定。

## 前置阅读
- [目录结构](../charles-prd-standards/rules/structure.md)
- [信息落点边界](../charles-prd-standards/rules/boundaries.md)
- 命令里的 `<skill 目录>` 见 [主规范](../charles-prd-standards/SKILL.md) 的工具与模板路径

## 先跑结构校验
```bash
bash <skill 目录>/tools/check.sh docs/prd
```
结构问题以脚本结论为准，不逐条肉眼找。脚本红的先改完再进入内容评审，否则意见会被格式问题淹没。

## 内容评审清单
> 按顺序过一遍，每条都要给出具体位置（文件加需求编号），不给"建议优化一下"这类无法执行的意见。

### 一、需求之间的矛盾
- 两条需求对同一对象规定了相反行为（`REQ-1.0-003` 要求必须登录，`REQ-1.0-007` 允许游客下单）
- 需求描述的边界条件互相覆盖不全或重叠（一条说超过 100 触发，另一条说 100 以上触发，边界值归属不明）
- 状态机缺环：定义了进入某状态的条件，没定义退出条件

### 二、范围与目标对不上
- **目标说要提升某个指标，In Scope 里没有任何一条需求直接影响它**。这是最常见也最致命的一类
- Out of Scope 里的条目其实是达成目标的必要前提
- Later 里堆了太多东西，说明这一版的目标切得不够小

### 三、Non-goals 与需求冲突
- Non-goals 声明不做某件事，但某条需求实际做了它的一部分
- Non-goals 写得太泛（"不做复杂功能"），起不到拒绝范围蔓延的作用

### 四、Release Criteria 无法判定
- 判据里出现"体验好"、"足够快"、"稳定"这类无法判定真假的表述
- 判据没有对应的验证方式：说了要达到某个指标，但没说在哪测、怎么测
- 判据实际是工程标准（测试覆盖率、编译通过），应该移出 PRD，由项目的交付标准管

### 五、需求编号的引用完整性
- 需求描述里引用了不存在的编号
- 标注失效的需求，没说被哪条替代
- 实现文档或测试用例引用的编号在 PRD 里找不到

### 六、原型与 PRD 不一致
- 原型里有 PRD 没写的交互
- PRD 写了但原型没表达的关键状态（尤其 Empty 与 Error）
- 原型的流程顺序与"整体流程"一节描述的不同
- **交互规格表的边界情况与原型实际行为对不上**。逐个 Task 打开原型点一遍，重点验边界：按钮的置灰条件、数量统计是否把不该算的算进去了、全部不可操作时是否还弹确认框。原型与规格表是两份独立文档，改了一边另一边不会自动跟着改
- 原型里还挂着已定义任务的 `data-todo` 占位，见 [prototype](../charles-prd-standards/rules/prototype.md)

### 七、文字表达无法判定
- 需求描述里出现"优化"、"提升体验"、"合理"、"一般情况下"这类写不成测试用例的表述
- 主语缺失（"系统会自动处理"）或条件缺失（没说什么时候触发）
- 出现产品黑话（赋能、抓手、闭环、打通、心智），掩盖了真正要说的事
- 一条需求描述了多件事，出现"同时"、"并且"却没有拆开
- 完整词表与改写方式见 [writing](../charles-prd-standards/rules/writing.md)

### 八、未解决问题的阻塞性
- 未解决问题里有会影响需求定义的，却已经进入开发
- 问题列了很久没有推进，也没说决定它需要什么信息
- **阻塞性问题超过三条**，说明当时该停下来确认而不是继续写，评审时要指出受影响的需求范围
- 推算出来的数值没有在需求条目里就地标注，读的人分不清哪些是确认过的

## 提供思路时的做法
评审不只是挑错。发现问题后按这个顺序给建议：

1. **先说清矛盾是什么**，引用两处具体位置
2. **说明不解决会怎样**，落到具体后果而不是"不规范"
3. **给出两到三个可选解法并推荐一个**，说明推荐理由
4. 涉及产品取舍时**不替 Charles 决定**，把取舍摆清楚让他选

## 输出格式
按 [collaboration](../charles-prd-standards/rules/collaboration.md) 的三段式输出：问题描述、存在的隐患、解决方案。评审场景下"问题描述"要点出矛盾的两处具体位置。

## 评审闸门
- 结构校验全绿
- 八类内容问题逐条过完
- 每条意见都附具体位置
- 需要 Charles 决定的取舍单独列出，不混在问题清单里
