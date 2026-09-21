# Charles PRD -- 流程图与架构图
<!--
图的用途边界、视觉约束与生成说明要求
创建日期：2026-09-21
修改日期：2026-09-21
-->
> 图的任务是解释，不是成为可执行资产。不维护 Excalidraw 源文件，直接用 GPT Image 生成 Excalidraw 风格的 PNG。

## 存放方式
```
versions/1.0/diagrams/
├── core-user-flow.png
├── core-user-flow.md
├── system-overview.png
└── system-overview.md
```

## 生成说明是必需的
> 每张图配一个同名 `.md`，**不是可选项**。

- 内容只要一行到三行：提示词要点、生成日期、这张图要解释什么
- 不写的代价是改一个节点就要从零重画，而且无从复现原来的提示词
- 不需要为每张图建 spec、prompt、metadata 三件套，一个 `.md` 足够

```markdown
core-user-flow.png
提示词要点：登录到下单的五步主流程，Excalidraw 手绘风格，白底，圆角卡片，手绘箭头
生成日期：2026-09-21
用途：解释首次使用者从注册到完成第一单的路径
```

## 视觉约束
统一以下几条，保证多张图放在一起不违和：

- Excalidraw 手绘风格
- 中文标注，技术名词保留英文
- 白底、黑灰主色、少量浅色分组底
- 圆角卡片配手绘箭头
- 不使用 Emoji
- **只画 PRD 中已定义的节点**，不自动补模块
- 尽量一张图只表达一个问题

## 图与 HTML 的边界

| 内容 | 用什么 |
| --- | --- |
| 用户完整操作流程 | HTML Prototype |
| 某个复杂流程的解释 | Excalidraw 风格图 |
| 系统模块关系与数据流 | Excalidraw 风格图 |
| 页面布局、按钮、弹窗、状态 | HTML Prototype |
| 视觉风格探索 | Penpot（可选） |

判据：**需要点击才能理解的用 HTML，需要一眼看清关系的用图。**
