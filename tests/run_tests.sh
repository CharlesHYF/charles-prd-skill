#!/usr/bin/env bash
# check.sh 回归测试，用固定 fixture 断言七项检查该报的都报、不该报的不报
# 创建日期：2026-09-21
# 修改日期：2026-09-21

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

	echo "# 产品定义" > "${dir}/product.md"

	cat > "${dir}/versions/1.0/prd.md" <<'INNER'
# Product 1.0

## 背景
为什么现在做这一版。

## 目标用户与核心问题
服务谁。

## 这一版的目标
最重要的结果。

## Non-goals
不做什么。

## 核心用户流程
主路径。

## 主要功能与行为
- REQ-1.0-001 需求一
- REQ-1.0-002 需求二

## 成功标准 / Release Criteria
核心流程能走通。

## 未解决问题
暂无。
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

echo "=== 场景三：章节与版本状态 ==="
SECTION_DIR="$(mktemp -d)/docs/prd"
make_prd "${SECTION_DIR}"
grep -v '^## Non-goals$' "${SECTION_DIR}/versions/1.0/prd.md" > "${SECTION_DIR}/versions/1.0/prd.tmp"
mv "${SECTION_DIR}/versions/1.0/prd.tmp" "${SECTION_DIR}/versions/1.0/prd.md"
grep -v '^Next:' "${SECTION_DIR}/README.md" > "${SECTION_DIR}/README.tmp"
mv "${SECTION_DIR}/README.tmp" "${SECTION_DIR}/README.md"

run_check "${SECTION_DIR}"
expect_contains "${CHECK_OUTPUT}" "缺少章节：## Non-goals" "检查四:缺章节被拦"
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

echo "=== 场景六：仓库自带模板必须自洽 ==="
run_check "${REPO_ROOT}/templates/prd-template"
expect_not_contains "${CHECK_OUTPUT}" "[FAIL]" "模板通过自身校验"

echo "==============================="
echo "通过 ${PASS_COUNT} 项，失败 ${FAIL_COUNT} 项"

if [ "${FAIL_COUNT}" -gt 0 ]; then
	exit 1
fi

exit 0
