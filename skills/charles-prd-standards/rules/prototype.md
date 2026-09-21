# Charles PRD -- 产品原型
<!--
原型的定位、编码规范豁免边界与时效性
创建日期：2026-09-21
修改日期：2026-09-21
-->
> 原型默认直接做静态 HTML。它能点击、能表达状态、能进 Git，也最容易让 Coding Agent 继续修改。

## 默认形态
```
prototype/
├── index.html
├── style.css
├── app.js
└── assets/
```

产品有多个主要页面时升级为：

```
prototype/
├── index.html
├── pages/
│   ├── home.html
│   ├── search.html
│   └── settings.html
├── style.css
├── app.js
└── assets/
```

## 原型只需要做到这些
- 能走通核心 Journey，**不实现真实后端**
- 能表达关键状态：Empty、Loading、Success、Error
- 允许 Mock Data、`setTimeout`、假按钮、静态跳转
- 视觉达到"能判断产品体验"的程度即可，不追求 production code
- 每个 major 版本保存自己的原型，2.0 不覆盖 1.0 的历史

## 不受编码规范约束
> **`docs/prd/**/prototype/` 下的代码不受项目编码规范约束。**

- 原型是抛弃型产物，不进生产构建，套完整规范会把"快速表达交互"的价值抵消掉
- 接入方式：把 `docs/prd/**/prototype/` 加进项目的 lint 与规范校验排除清单（如 `.checkignore`、`.eslintignore`、`.prettierignore`）
- **但原型代码不许被复制进 `src/`**。要用里面的实现就重写一遍，按编码规范写。复制过去的代码带着 Mock 数据与假逻辑，后面没人分得清哪些是真的

## Source of Truth 的时效性
> 原型的权威身份**只在该版本开发期间有效**。

- **开发期间**：交互以 HTML Prototype 为准，PRD 描述规则与边界。两者冲突时先更新 PRD，再同步 HTML
- **版本发布后**：原型随版本目录一起冻结，转为历史存档，**实现代码成为唯一事实来源**
- 这一条必须写进 `README.md` 的版本状态说明里。不写明的话，几个版本之后会有人照着过期原型做实现，而它看起来仍然像权威文档

## 什么时候才需要外部设计工具
只有开始反复处理视觉系统、组件细节、响应式布局，或需要在画布上快速探索多个方案时，才值得引入 Penpot 或 Figma。否则静态 HTML 更快。

| 方案 | 角色 | 说明 |
| --- | --- | --- |
| 静态 HTML | 主原型与交互事实来源 | 默认使用，零外部依赖，直接进 Git |
| Penpot | 视觉探索、组件与 Design Tokens | 需要设计画布时可选，官方提供 MCP |
| Figma | 已有 Figma 习惯时使用 | 官方有 MCP，但调用与写入能力取决于 plan |
