# Charles PRD -- 导出交付
<!--
PRD 导出为 PDF 的流程、单向关系与交付记录要求
创建日期：2026-09-21
修改日期：2026-09-21
-->
> 对外评审、客户签字、正式存档时需要一份 PDF。**Markdown 是唯一源头，PDF 只是导出产物。**

## 单向关系
- 任何修改都回到 Markdown 再重新导出，**不在 PDF 上改内容**
- 收到别人批注过的 PDF 时，把改动手工搬回 Markdown，**不接受 PDF 作为输入源**
- 导出的 PDF 首页固定带一句说明：本文件由 Markdown 源文件导出，反馈请引用需求编号
- 双向维护的后果是两份各自演进，而 PDF 的 diff 在 Git 里不可读，几轮之后没人知道哪份是对的

## 导出方式
Markdown 渲染成带打印样式的 HTML，再用本机 Chrome 打印为 PDF。这条路径的样式完全可控，不依赖第三方转换服务。

```bash
bash tools/export-pdf.sh \
	docs/prd/product.md \
	docs/prd/versions/1.0/prd.md \
	docs/prd/versions/1.0/scope.md \
	--title "产品名称" \
	--version 1.0 \
	--note "本文件由 Markdown 源文件导出，反馈请引用需求编号，勿直接修改本 PDF。" \
	--output docs/prd/versions/1.0/export/prd-1.0.pdf
```

- 多个输入文件按顺序合并成一份 PDF，文件之间自动分隔
- 样式在 [`templates/export/style.css`](../../../templates/export/style.css)，改它就能改全局排版
- 需求编号会自动渲染成等宽高亮，方便对方在 PDF 上按编号反馈
- 首次运行会安装渲染依赖，之后离线可用

## 导出产物的归属
- 导出目录固定为 `docs/prd/versions/<版本>/export/`
- **该目录默认进 `.gitignore`**，日常导出不污染仓库，也不产生无法阅读的二进制 diff
- **只有实际对外交付过的那一份才提交**，文件名带日期与接收方：`prd-1.0-20260921-客户名.pdf`
- 提交的同时在该版本的 `notes.md` 里记一行交付记录：日期、接收方、对应的 git commit

```markdown
## 交付记录
- 2026-09-21 交付给客户名，对应 commit a1b2c3d，导出自 versions/1.0/
```

这样仓库里只留真正发出去的版本，出问题时能复现当时对方拿到的内容。

## 原型与图的处理
- **HTML 原型无法进 PDF**：导出时原型一节替换为一句说明，指向 `prototype/` 目录或在线地址，不用截图冒充交互
- **图按原尺寸插入**，图注保留生成日期
- 截图不作为交互的替代说明，对方要理解交互就打开原型

## 什么时候才导出
- 对外评审、客户签字、正式存档时导出
- 内部自己看不需要导出，直接读 Markdown 更快也更新
- 版本还在开发中时不导出，避免发出去的是中间状态
