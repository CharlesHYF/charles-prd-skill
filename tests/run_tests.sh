#!/usr/bin/env bash
# check.sh 与禁用字符扫描的回归测试，用固定 fixture 断言该报的都报、不该报的不报
# 创建日期：2026-09-21
# 修改日期：2026-09-23

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECK_SH="${REPO_ROOT}/tools/check.sh"

if [ ! -f "${CHECK_SH}" ]; then
	echo "[FATAL] 找不到被测脚本: ${CHECK_SH}"
	exit 1
fi

PASS_COUNT=0
FAIL_COUNT=0

pass() {
	echo "  [PASS] $1"
	PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
	echo "  [FAIL] $1"
	FAIL_COUNT=$((FAIL_COUNT + 1))
}

expect_contains() {
	local output="$1"
	local needle="$2"
	local label="$3"

	if printf '%s' "${output}" | grep -qF -- "${needle}"; then
		pass "${label}"
	else
		fail "${label} -- 未找到: ${needle}"
	fi
}

expect_not_contains() {
	local output="$1"
	local needle="$2"
	local label="$3"

	if printf '%s' "${output}" | grep -qF -- "${needle}"; then
		fail "${label} -- 不应出现: ${needle}"
	else
		pass "${label}"
	fi
}

# 搭建一个结构合规的最小 PRD 目录
make_prd() {
	local dir="$1"

	mkdir -p "${dir}/versions/1.0/diagrams" "${dir}/versions/1.0/prototype"

	cat > "${dir}/README.md" <<'INNER'
# PRD

Production: 1.0
Development: -
Next: -
INNER

	printf '%s\n' "# 产品定义" "" "## 产品形态" "- 形态：后台管理系统" "- 移动端适配：否" > "${dir}/product.md"

	cat > "${dir}/versions/1.0/prd.md" <<'INNER'
# Product 1.0

## 版本历史

| 版本 | 日期 | 变更内容 | 修订人 |
| --- | --- | --- | --- |
| 1.0 | 2026-09-22 | 初版 | Charles |

## 1. 需求概述

### 产品背景
背景。

### 本版目标
目标。

### 价值点
价值。

### 涉及系统
无外部依赖。

### 风险说明
暂无。

## 2. 产品描述

### 名词解释

| 名词 | 定义 | 取值范围 | 定义来源 |
| --- | --- | --- | --- |
| 术语 | 定义 | 枚举 | 本文档 |

### 整体流程

```mermaid
flowchart LR
	A[入口] --> B[结果]
```

### 功能清单

| 模块 | 功能 | 优先级 | 说明 |
| --- | --- | --- | --- |
| 模块 | 功能 | P0 | 说明 |

## 3. 功能需求

### 3.1 模块

#### 场景描述
场景。

#### 需求条目

- REQ-1.0-001 需求一
- REQ-1.0-002 需求二

#### 字段定义

| 字段 | 类型 | 必填 | 约束 | 默认值 | 说明 |
| --- | --- | --- | --- | --- | --- |
| itemId | BIGINT | 是 | 主键 | 无 | 标识 |
| itemName | VARCHAR(60) | 是 | 非空 | 无 | 名称 |
| status | TINYINT | 是 | 1 生效 / 2 停用 | 1 | 状态 |

#### 流程

```mermaid
flowchart TD
	A[触发] --> B[结果]
```

## 4. 非功能需求

### 权限与可见性
单人使用。

### 数据留存
永久保留。

### 统计与埋点
不埋点。

### 安全底线
不存凭证。

## 5. Non-goals
不做什么。

## 6. 成功标准 / Release Criteria

- 判据一

## 7. 未解决问题

1. 问题一
INNER

	echo "# Scope" > "${dir}/versions/1.0/scope.md"

	cat > "${dir}/versions/1.0/tasks.md" <<'INNER'
# Tasks 1.0

## Task-001：任务一

**关联需求**：REQ-1.0-001

### 任务内容
实现内容。

### 流程

```mermaid
flowchart TD
	A[点击按钮] --> B{已勾选}
	B -- 否 --> C[提示请先选择]
	B -- 是 --> D[执行并刷新]
```

### 交互规格

| 字段 | 内容 |
| --- | --- |
| 触发 | 点击按钮 |
| 前置条件 | 已勾选对象 |
| 正常路径 | 执行并刷新列表 |
| 边界情况 | 未勾选时提示"请先选择" |
| 错误处理 | 失败提示"操作失败，请重试" |
| 兜底行为 | 部分失败时列出失败项 |
| 显示规则 | 执行中按钮置灰 |

### 验收
- 点击后列表刷新
INNER
}

run_check() {
	CHECK_OUTPUT="$(bash "${CHECK_SH}" "$1" 2>&1)"
	CHECK_EXIT=$?
}

echo "=== 场景一：合规 PRD 应全绿 ==="
GOOD_DIR="$(mktemp -d)/docs/prd"
make_prd "${GOOD_DIR}"
run_check "${GOOD_DIR}"
expect_not_contains "${CHECK_OUTPUT}" "[FAIL]" "合规 PRD 无任何 FAIL"

if [ "${CHECK_EXIT}" -eq 0 ]; then
	pass "合规 PRD 退出码为 0"
else
	fail "合规 PRD 退出码应为 0，实际 ${CHECK_EXIT}"
fi

echo "=== 场景二：结构违规逐项命中 ==="
BAD_DIR="$(mktemp -d)/docs/prd"
make_prd "${BAD_DIR}"

rm -f "${BAD_DIR}/product.md"
mkdir -p "${BAD_DIR}/versions/current"
mkdir -p "${BAD_DIR}/versions/2.0"
rm -f "${BAD_DIR}/versions/1.0/scope.md"
printf '%s\n' "- REQ-1.0-001 重复编号" >> "${BAD_DIR}/versions/1.0/prd.md"
printf 'x' > "${BAD_DIR}/versions/1.0/diagrams/core-flow.png"
printf '# 流程图\n\n```mermaid\nflowchart LR\n\tA --> B\n```\n' > "${BAD_DIR}/versions/1.0/diagrams/user-flow.md"

run_check "${BAD_DIR}"
expect_contains "${CHECK_OUTPUT}" "缺少必需文件：${BAD_DIR}/product.md" "检查一:缺 product.md"
expect_contains "${CHECK_OUTPUT}" "版本目录名不是明确版本号：versions/current" "检查二:current 目录被拦"
expect_contains "${CHECK_OUTPUT}" "versions/1.0/ 缺少 scope.md" "检查三:major 缺 scope.md"
expect_contains "${CHECK_OUTPUT}" "versions/2.0/ 缺少 prd.md" "检查三:空版本目录缺 prd.md"
expect_contains "${CHECK_OUTPUT}" "需求编号重复" "检查五:需求编号重复被拦"

expect_contains "${CHECK_OUTPUT}" "缺少同名来源说明" "检查六:位图缺来源说明被拦"
expect_contains "${CHECK_OUTPUT}" "把 Mermaid 图写进了 diagrams/ 独立文件" "检查六:Mermaid 写错位置被拦"

if [ "${CHECK_EXIT}" -ne 0 ]; then
	pass "违规 PRD 退出码非 0"
else
	fail "违规 PRD 退出码应非 0，实际 0"
fi

echo "=== 场景二之二：字段类型必须是 SQL 类型 ==="
TYPE_DIR="$(mktemp -d)/docs/prd"
make_prd "${TYPE_DIR}"
sed -i '' 's@| itemName | VARCHAR(60) |@| itemName | String |@' "${TYPE_DIR}/versions/1.0/prd.md"
run_check "${TYPE_DIR}"
expect_contains "${CHECK_OUTPUT}" "字段表用了语言层类型" "检查四:语言层类型被拦"

ENUM_DIR="$(mktemp -d)/docs/prd"
make_prd "${ENUM_DIR}"
sed -i '' 's@| status | TINYINT |@| status | Enum |@' "${ENUM_DIR}/versions/1.0/prd.md"
run_check "${ENUM_DIR}"
expect_contains "${CHECK_OUTPUT}" "字段表用了语言层类型" "检查四:Enum 被拦"

echo "=== 场景三：章节与版本状态 ==="
SECTION_DIR="$(mktemp -d)/docs/prd"
make_prd "${SECTION_DIR}"
grep -v '^## 5. Non-goals$' "${SECTION_DIR}/versions/1.0/prd.md" > "${SECTION_DIR}/versions/1.0/prd.tmp"
mv "${SECTION_DIR}/versions/1.0/prd.tmp" "${SECTION_DIR}/versions/1.0/prd.md"
grep -v '^Next:' "${SECTION_DIR}/README.md" > "${SECTION_DIR}/README.tmp"
mv "${SECTION_DIR}/README.tmp" "${SECTION_DIR}/README.md"

run_check "${SECTION_DIR}"
expect_contains "${CHECK_OUTPUT}" "缺少章节：## 5. Non-goals" "检查四:缺章节被拦"
expect_contains "${CHECK_OUTPUT}" "缺少版本状态声明：Next:" "检查七:缺版本状态被拦"

echo "=== 场景四：需求编号缺失 ==="
NOREQ_DIR="$(mktemp -d)/docs/prd"
make_prd "${NOREQ_DIR}"
grep -v '^- REQ-' "${NOREQ_DIR}/versions/1.0/prd.md" > "${NOREQ_DIR}/versions/1.0/prd.tmp"
mv "${NOREQ_DIR}/versions/1.0/prd.tmp" "${NOREQ_DIR}/versions/1.0/prd.md"

run_check "${NOREQ_DIR}"
expect_contains "${CHECK_OUTPUT}" "没有任何需求编号" "检查五:无需求编号被拦"

echo "=== 场景五：minor 版本 ==="
MINOR_DIR="$(mktemp -d)/docs/prd"
make_prd "${MINOR_DIR}"
mkdir -p "${MINOR_DIR}/versions/1.1"
run_check "${MINOR_DIR}"
expect_contains "${CHECK_OUTPUT}" "versions/1.1/ 缺少 changes.md" "检查三:minor 缺 changes.md"

echo "# 1.1 变更" > "${MINOR_DIR}/versions/1.1/changes.md"
run_check "${MINOR_DIR}"
expect_not_contains "${CHECK_OUTPUT}" "versions/1.1/ 缺少" "检查三:minor 有 changes.md 即放行"

echo "=== 场景七：任务与交互规格 ==="
TASK_DIR="$(mktemp -d)/docs/prd"
make_prd "${TASK_DIR}"

# 编号重复、缺字段、引用不存在的需求
cat >> "${TASK_DIR}/versions/1.0/tasks.md" <<'INNER'

## Task-001：编号重复的任务

**关联需求**：REQ-1.0-999

### 任务内容
实现内容。

### 流程

单一路径，无分支。

### 交互规格

| 字段 | 内容 |
| --- | --- |
| 触发 | 点击按钮 |
| 前置条件 | 无 |
| 正常路径 | 执行 |

### 验收
- 能执行
INNER

run_check "${TASK_DIR}"
expect_contains "${CHECK_OUTPUT}" "任务编号重复" "检查八:任务编号重复被拦"
expect_contains "${CHECK_OUTPUT}" "边界情况" "检查八:缺交互规格字段被拦"
expect_contains "${CHECK_OUTPUT}" "不存在的需求编号" "检查八:引用不存在的需求被拦"

NOREQ_TASK_DIR="$(mktemp -d)/docs/prd"
make_prd "${NOREQ_TASK_DIR}"
grep -v '关联需求' "${NOREQ_TASK_DIR}/versions/1.0/tasks.md" > "${NOREQ_TASK_DIR}/versions/1.0/tasks.tmp"
mv "${NOREQ_TASK_DIR}/versions/1.0/tasks.tmp" "${NOREQ_TASK_DIR}/versions/1.0/tasks.md"
run_check "${NOREQ_TASK_DIR}"
expect_contains "${CHECK_OUTPUT}" "没有任何关联需求编号" "检查八:任务缺关联需求被拦"

NOFLOW_DIR="$(mktemp -d)/docs/prd"
make_prd "${NOFLOW_DIR}"
python3 - "${NOFLOW_DIR}/versions/1.0/tasks.md" <<'PYINNER'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1])
t = p.read_text(encoding="utf-8")
t = re.sub(r"### 流程\n\n```mermaid[\s\S]*?```\n\n", "", t)
p.write_text(t, encoding="utf-8")
PYINNER
run_check "${NOFLOW_DIR}"
expect_contains "${CHECK_OUTPUT}" "流程小节只有" "检查八:任务缺流程图被拦"

echo "=== 场景八：内联 SVG 不被 Markdown 截断 ==="
SVG_DIR="$(mktemp -d)"
cat > "${SVG_DIR}/doc.md" <<'INNER'
# 界面

<svg class="annotation" viewBox="0 0 100 50">
	<rect x="1" y="1" width="20" height="10"/>

	<text x="5" y="20">空行后仍属于同一个 SVG</text>

	<circle cx="50" cy="25" r="5"/>
</svg>

图注：上面的 SVG 内部有空行。
INNER

# 渲染结果内联了体积很大的 mermaid 运行时，直接 grep 文件而不是读进变量
if node "${REPO_ROOT}/tools/render.mjs" "${SVG_DIR}/doc.md" --output "${SVG_DIR}/doc.html" >/dev/null 2>&1; then

	if grep -qF -- '<circle cx="50"' "${SVG_DIR}/doc.html"; then
		pass "内联 SVG 的空行之后仍被完整保留"
	else
		fail "内联 SVG 的空行之后被截断"
	fi

	if grep -qF -- "&lt;circle" "${SVG_DIR}/doc.html"; then
		fail "内联 SVG 被转义成源码输出"
	else
		pass "内联 SVG 未被转义成源码输出"
	fi

	if grep -qF -- "CHARLES-SVG" "${SVG_DIR}/doc.html"; then
		fail "SVG 占位符未被还原"
	else
		pass "SVG 占位符已全部还原"
	fi
else
	fail "render.mjs 执行失败，无法验证 SVG 保护"
fi

rm -rf "${SVG_DIR}"

echo "=== 场景九：角色必须能在 product.md 角色表里找到 ==="
ROLE_DIR="$(mktemp -d)/docs/prd"
make_prd "${ROLE_DIR}"
cat > "${ROLE_DIR}/product.md" <<'INNER'
# 产品定义

## 角色

| 角色 | 职责 | 可操作范围 |
| --- | --- | --- |
| 采购岗 | 创建与提交订单 | 自己创建的订单 |
INNER
printf '%s\n' "订单金额超过阈值时需要运营总监复核。" >> "${ROLE_DIR}/versions/1.0/prd.md"
run_check "${ROLE_DIR}"
expect_contains "${CHECK_OUTPUT}" "角色表未定义的角色称谓" "检查九:表外角色被拦"
expect_contains "${CHECK_OUTPUT}" "运营总监" "检查九:报出具体角色名"

printf '%s\n' "| 运营总监 | 大额订单复核 | 全部订单 |" >> "${ROLE_DIR}/product.md"
run_check "${ROLE_DIR}"
expect_not_contains "${CHECK_OUTPUT}" "角色表未定义的角色称谓" "检查九:补全角色表后放行"

IGNORE_DIR="$(mktemp -d)/docs/prd"
make_prd "${IGNORE_DIR}"
cat > "${IGNORE_DIR}/product.md" <<'INNER'
# 产品定义

## 角色

| 角色 | 职责 | 可操作范围 |
| --- | --- | --- |
| 采购岗 | 创建与提交订单 | 自己创建的订单 |
INNER
printf '%s\n' "对接方填对方团队的负责人。<!-- check-ignore -->" >> "${IGNORE_DIR}/versions/1.0/prd.md"
run_check "${IGNORE_DIR}"
expect_not_contains "${CHECK_OUTPUT}" "角色表未定义的角色称谓" "检查九:check-ignore 行被豁免"

echo "=== 场景十：界面标注图必须由截图与坐标生成 ==="
ANN_DIR="$(mktemp -d)/docs/prd"
make_prd "${ANN_DIR}"
mkdir -p "${ANN_DIR}/versions/1.0/diagrams"
cat > "${ANN_DIR}/versions/1.0/diagrams/list.marks.json" <<'INNER'
{ "shot": "list", "inject": "../tasks.md", "mark": "list", "marks": [] }
INNER
run_check "${ANN_DIR}"
expect_contains "${CHECK_OUTPUT}" "没有 _coords.json" "检查七:没截图就写标注被拦"

printf '{ "other": { "w": 1, "h": 1, "els": [] } }\n' > "${ANN_DIR}/versions/1.0/diagrams/_coords.json"
run_check "${ANN_DIR}"
expect_contains "${CHECK_OUTPUT}" "在 _coords.json 里没有坐标" "检查七:坐标缺该截图被拦"
expect_contains "${CHECK_OUTPUT}" "缺少同名来源说明 _coords.md" "检查七:坐标缺来源说明被拦"

printf '{ "list": { "w": 1, "h": 1, "els": [] } }\n' > "${ANN_DIR}/versions/1.0/diagrams/_coords.json"
printf '# 坐标\n' > "${ANN_DIR}/versions/1.0/diagrams/_coords.md"
run_check "${ANN_DIR}"
expect_contains "${CHECK_OUTPUT}" "没有对应截图 list.png" "检查七:缺截图被拦"

printf 'x' > "${ANN_DIR}/versions/1.0/diagrams/list.png"
printf '# list 截图\n' > "${ANN_DIR}/versions/1.0/diagrams/list.md"
printf '\n<!--annotation:list-->\n<!--/annotation-->\n' >> "${ANN_DIR}/versions/1.0/tasks.md"
run_check "${ANN_DIR}"
expect_contains "${CHECK_OUTPUT}" "标记块是空的" "检查七:标记块留空被拦"

python3 - "${ANN_DIR}/versions/1.0/tasks.md" <<'PYINNER'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
p.write_text(p.read_text(encoding="utf-8").replace(
	"<!--annotation:list-->\n<!--/annotation-->",
	"<!--annotation:list-->\n<svg class=\"annotation\"></svg>\n<!--/annotation-->"), encoding="utf-8")
PYINNER
run_check "${ANN_DIR}"
expect_not_contains "${CHECK_OUTPUT}" "标记块是空的" "检查七:标注齐备后放行"

echo "=== 场景十一：已定义任务不能还挂占位 ==="
TODO_DIR="$(mktemp -d)/docs/prd"
make_prd "${TODO_DIR}"
mkdir -p "${TODO_DIR}/versions/1.0/prototype"
printf '<button data-todo="Task-001">新建</button>\n' > "${TODO_DIR}/versions/1.0/prototype/index.html"
run_check "${TODO_DIR}"
expect_contains "${CHECK_OUTPUT}" "原型里却还挂着 data-todo 占位" "检查八:已定义任务留占位被拦"

printf '<button data-todo="Task-099">新建</button>\n' > "${TODO_DIR}/versions/1.0/prototype/index.html"
run_check "${TODO_DIR}"
expect_not_contains "${CHECK_OUTPUT}" "原型里却还挂着 data-todo 占位" "检查八:未定义任务的占位放行"

echo "=== 场景十二：原型改过而没重新截图要拦住 ==="
FRESH_DIR="$(mktemp -d)/docs/prd"
mkdir -p "${FRESH_DIR}"
cp -R "${REPO_ROOT}/templates/prd-example/." "${FRESH_DIR}/"
run_check "${FRESH_DIR}"
expect_not_contains "${CHECK_OUTPUT}" "原型之后改过" "检查七:未改动时不误报"

printf '\n<!-- 动一行 -->\n' >> "${FRESH_DIR}/versions/1.0/prototype/pages/list.html"
run_check "${FRESH_DIR}"
expect_contains "${CHECK_OUTPUT}" "原型之后改过" "检查七:坐标过期被拦"
expect_contains "${CHECK_OUTPUT}" "先重跑 tools/capture.mjs" "检查七:给出修复办法"

echo "=== 场景十三：禁用字符扫描 ==="
SCAN_SH="${REPO_ROOT}/tests/scan_forbidden_chars.sh"
SCAN_DIR="$(mktemp -d)"
OUTSIDE_DIR="$(mktemp -d)"
git -C "${SCAN_DIR}" init -q

# 书名号、目录树制表符与箭头不禁，放进干净文件确认不误报
printf '%s\n' "合规文本《规范》" "├── docs" "审批 → 通过" > "${SCAN_DIR}/clean.md"
git -C "${SCAN_DIR}" add clean.md
SCAN_OUTPUT="$(bash "${SCAN_SH}" "${SCAN_DIR}" 2>&1)"
SCAN_EXIT=$?

if [ "${SCAN_EXIT}" -eq 0 ]; then
	pass "扫描:合规文件退出码为 0"
else
	fail "扫描:合规文件退出码应为 0，实际 ${SCAN_EXIT}"
fi

expect_not_contains "${SCAN_OUTPUT}" "[FAIL]" "扫描:书名号、制表符与箭头不误报"

# 角引号、破折号与 Emoji 用字节写入，测试脚本自身不含这些字符
printf '\xe3\x80\x8c引语\xe3\x80\x8d\n' > "${SCAN_DIR}/quote.md"
printf '前半句\xe2\x80\x94\xe2\x80\x94后半句\n' > "${SCAN_DIR}/dash.md"
printf '完成 \xf0\x9f\x98\x80\n' > "${SCAN_DIR}/emoji.md"
printf '\xe3\x80\x8c\n' > "${SCAN_DIR}/shot.png"
printf '\xe3\x80\x8c\n' > "${OUTSIDE_DIR}/linked.md"
ln -s "${OUTSIDE_DIR}/linked.md" "${SCAN_DIR}/linked.md"
git -C "${SCAN_DIR}" add quote.md dash.md emoji.md shot.png linked.md
SCAN_OUTPUT="$(bash "${SCAN_SH}" "${SCAN_DIR}" 2>&1)"
SCAN_EXIT=$?

if [ "${SCAN_EXIT}" -eq 1 ]; then
	pass "扫描:发现违规时退出码为 1"
else
	fail "扫描:发现违规时退出码应为 1，实际 ${SCAN_EXIT}"
fi

expect_contains "${SCAN_OUTPUT}" "U+300C：quote.md:1" "扫描:角引号被拦并报出位置"
expect_contains "${SCAN_OUTPUT}" "U+2014：dash.md:1" "扫描:破折号被拦"
expect_contains "${SCAN_OUTPUT}" "U+1F600：emoji.md:1" "扫描:Emoji 被拦"
expect_not_contains "${SCAN_OUTPUT}" "shot.png" "扫描:二进制文件跳过"
expect_not_contains "${SCAN_OUTPUT}" "linked.md" "扫描:软链跳过"

echo "=== 场景十四：骨架里的 [待填] 必须替换 ==="
FILL_DIR="$(mktemp -d)/docs/prd"
make_prd "${FILL_DIR}"
run_check "${FILL_DIR}"
expect_not_contains "${CHECK_OUTPUT}" "还留着 [待填] 占位" "检查十一:没有待填时不误报"

printf '%s\n' "- [待填] 这一版明确不做什么" >> "${FILL_DIR}/versions/1.0/prd.md"
printf '%s\n' "<div>[待填] 页面内容</div>" > "${FILL_DIR}/versions/1.0/prototype/index.html"
FILL_LINE=$(grep -nF "[待填]" "${FILL_DIR}/versions/1.0/prd.md" | cut -d: -f1)
run_check "${FILL_DIR}"
expect_contains "${CHECK_OUTPUT}" "versions/1.0/prd.md:${FILL_LINE} 还留着 [待填] 占位" "检查十一:文档里的待填被拦并报出行号"
expect_contains "${CHECK_OUTPUT}" "prototype/index.html:1 还留着 [待填] 占位" "检查十一:原型里的待填被拦"

echo "=== 场景十五：product.md 必须声明产品形态 ==="
FORM_DIR="$(mktemp -d)/docs/prd"
make_prd "${FORM_DIR}"
run_check "${FORM_DIR}"
expect_not_contains "${CHECK_OUTPUT}" "[FAIL]" "检查十二:合规声明不误报"

write_form() {
	printf '%s\n' "# 产品定义" "" "## 产品形态" "- 形态：$1" "- 移动端适配：$2" > "${FORM_DIR}/product.md"
	run_check "${FORM_DIR}"
}

echo "# 产品定义" > "${FORM_DIR}/product.md"
run_check "${FORM_DIR}"
expect_contains "${CHECK_OUTPUT}" "缺少\"产品形态\"一节" "检查十二:缺少形态一节被拦"

write_form "后台管理系统、桌面客户端" "否"
expect_contains "${CHECK_OUTPUT}" "形态取值不合法：桌面客户端" "检查十二:非法形态被拦并报出取值"

write_form "Web 应用" "不适用"
expect_contains "${CHECK_OUTPUT}" "移动端适配要写是或否" "检查十二:Web 形态必须写是否适配"

write_form "App、小程序" "是"
expect_contains "${CHECK_OUTPUT}" "移动端适配写不适用" "检查十二:纯移动形态写不适用"

write_form "后台管理系统、小程序" "是"
expect_not_contains "${CHECK_OUTPUT}" "[FAIL]" "检查十二:多形态合规声明放行"

write_form "[待填] 后台管理系统" "[待填] 否"
expect_not_contains "${CHECK_OUTPUT}" "取值不合法" "检查十二:待填占位不重复报取值"
expect_contains "${CHECK_OUTPUT}" "还留着 [待填] 占位" "检查十二:待填占位由待填检查报"

echo "=== 场景十六：截图视口与产品形态一致 ==="
VIEW_DIR="$(mktemp -d)/docs/prd"
make_prd "${VIEW_DIR}"
VIEW_DIAGRAMS="${VIEW_DIR}/versions/1.0/diagrams"

write_view_form() {
	printf '%s\n' "# 产品定义" "" "## 产品形态" "- 形态：$1" "- 移动端适配：$2" > "${VIEW_DIR}/product.md"
}

write_shot() {
	printf '{\n  "shot": "%s",\n  "page": "%s",\n  "viewport": "%s"\n}\n' "$1" "$2" "$3" > "${VIEW_DIAGRAMS}/$1.json"
}

write_view_form "Web 应用" "否"
write_shot "home" "../prototype/index.html" "desktop"
run_check "${VIEW_DIR}"
expect_not_contains "${CHECK_OUTPUT}" "缺少手机端截图清单" "检查十三:不适配移动端时不要求手机截图"

write_view_form "Web 应用" "是"
run_check "${VIEW_DIR}"
expect_contains "${CHECK_OUTPUT}" "home.json 缺少手机端截图清单 home-mobile.json" "检查十三:适配移动端时缺手机截图被拦"

write_shot "home-mobile" "../prototype/other.html" "mobile"
run_check "${VIEW_DIR}"
expect_contains "${CHECK_OUTPUT}" "home-mobile.json 的 page 与桌面截图不同" "检查十三:手机截图页面不一致被拦"

write_shot "home-mobile" "../prototype/index.html" "mobile"
printf '{ "shot": "home", "inject": "../tasks.md", "marks": [] }\n' > "${VIEW_DIAGRAMS}/home.marks.json"
run_check "${VIEW_DIR}"
expect_not_contains "${CHECK_OUTPUT}" "page 与桌面截图不同" "检查十三:手机截图配对正确放行"
expect_contains "${CHECK_OUTPUT}" "缺少手机端标注清单 home-mobile.marks.json" "检查十三:桌面有标注而手机端没有被拦"

write_shot "home" "../prototype/index.html" "tablet"
run_check "${VIEW_DIR}"
expect_contains "${CHECK_OUTPUT}" "viewport 取值不合法：tablet" "检查十三:非法视口被拦"

rm -f "${VIEW_DIAGRAMS}/home.marks.json"
write_view_form "App" "不适用"
write_shot "home" "../prototype/index.html" "desktop"
run_check "${VIEW_DIR}"
expect_contains "${CHECK_OUTPUT}" "但产品形态只含 App 或小程序" "检查十三:纯移动形态用桌面视口被拦"
expect_not_contains "${CHECK_OUTPUT}" "home-mobile.json 用了" "检查十三:纯移动形态的手机截图放行"

echo "=== 场景六：仓库自带样例与骨架必须自洽 ==="
run_check "${REPO_ROOT}/templates/prd-example"
expect_not_contains "${CHECK_OUTPUT}" "[FAIL]" "样例通过自身校验"

run_check "${REPO_ROOT}/templates/prd-template"
SKELETON_FAILS=$(printf '%s\n' "${CHECK_OUTPUT}" | grep -cF "[FAIL]")
SKELETON_FILL_FAILS=$(printf '%s\n' "${CHECK_OUTPUT}" | grep -F "[FAIL]" | grep -cF "还留着 [待填] 占位")

if [ "${SKELETON_FAILS}" -gt 0 ] && [ "${SKELETON_FAILS}" -eq "${SKELETON_FILL_FAILS}" ]; then
	pass "骨架只报 [待填] 残留，共 ${SKELETON_FAILS} 处"
else
	fail "骨架应只报 [待填] 残留：FAIL ${SKELETON_FAILS} 处，其中待填 ${SKELETON_FILL_FAILS} 处"
fi

echo "==============================="
echo "通过 ${PASS_COUNT} 项，失败 ${FAIL_COUNT} 项"

if [ "${FAIL_COUNT}" -gt 0 ]; then
	exit 1
fi

exit 0
