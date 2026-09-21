#!/usr/bin/env bash
# 一次产出某个版本的两份 PDF，产品需求对外交付，任务规格内部使用
# 创建日期：2026-09-21
# 修改日期：2026-09-21

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
	cat <<'USAGE'
用法: export-prd.sh <版本> [选项]

选项:
  -r, --root <目录>    PRD 根目录，缺省 docs/prd
  -t, --title <标题>   产品名称，缺省取 PRD 根目录下 README.md 的一级标题
      --prd-only       只导出产品需求，不导出任务规格
      --tasks-only     只导出任务规格

产出:
  <根目录>/versions/<版本>/export/prd-<版本>.pdf      产品需求，对外交付用
  <根目录>/versions/<版本>/export/tasks-<版本>.pdf    任务与交互规格，内部使用

示例:
  bash tools/export-prd.sh 1.0 --title "订阅管理工具"
USAGE
}

VERSION=""
PRD_ROOT="docs/prd"
TITLE=""
EXPORT_PRD=1
EXPORT_TASKS=1

while [ $# -gt 0 ]; do

	case "$1" in
		-r | --root)
			PRD_ROOT="${2:-}"
			shift 2
			;;
		-t | --title)
			TITLE="${2:-}"
			shift 2
			;;
		--prd-only)
			EXPORT_TASKS=0
			shift
			;;
		--tasks-only)
			EXPORT_PRD=0
			shift
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			VERSION="$1"
			shift
			;;
	esac
done

if [ -z "${VERSION}" ]; then
	usage
	exit 2
fi

VERSION_DIR="${PRD_ROOT}/versions/${VERSION}"

if [ ! -d "${VERSION_DIR}" ]; then
	echo "[NG] 找不到版本目录：${VERSION_DIR}"
	exit 1
fi

# 标题缺省从 README 的一级标题取，取不到就用目录名兜底
if [ -z "${TITLE}" ]; then
	TITLE=$(grep -m1 '^# ' "${PRD_ROOT}/README.md" 2>/dev/null | sed 's/^# //' || true)
fi

if [ -z "${TITLE}" ]; then
	TITLE="$(basename "$(pwd)")"
fi

EXPORT_DIR="${VERSION_DIR}/export"
mkdir -p "${EXPORT_DIR}"

FAILED=0

if [ "${EXPORT_PRD}" -eq 1 ]; then
	echo "=== 导出产品需求（对外） ==="

	PRD_INPUTS=()

	if [ -f "${PRD_ROOT}/product.md" ]; then
		PRD_INPUTS+=("${PRD_ROOT}/product.md")
	fi

	if [ -f "${VERSION_DIR}/prd.md" ]; then
		PRD_INPUTS+=("${VERSION_DIR}/prd.md")
	fi

	if [ -f "${VERSION_DIR}/scope.md" ]; then
		PRD_INPUTS+=("${VERSION_DIR}/scope.md")
	fi

	if [ "${#PRD_INPUTS[@]}" -eq 0 ]; then
		echo "[NG] 没有可导出的产品需求文件（product.md / prd.md / scope.md 都不存在）"
		FAILED=1
	elif ! bash "${SCRIPT_DIR}/export-pdf.sh" "${PRD_INPUTS[@]}" \
		--title "${TITLE}" \
		--subtitle "产品需求文档" \
		--version "${VERSION}" \
		--output "${EXPORT_DIR}/prd-${VERSION}.pdf"; then
		FAILED=1
	fi
fi

if [ "${EXPORT_TASKS}" -eq 1 ]; then
	echo "=== 导出任务与交互规格（内部） ==="

	if [ ! -f "${VERSION_DIR}/tasks.md" ] && [ ! -d "${VERSION_DIR}/tasks" ]; then
		echo "  [SKIP] 该版本没有 tasks.md，跳过任务导出。"
	else
		TASK_INPUTS=()

		if [ -f "${VERSION_DIR}/tasks.md" ]; then
			TASK_INPUTS+=("${VERSION_DIR}/tasks.md")
		fi

		if [ -d "${VERSION_DIR}/tasks" ]; then
			while IFS= read -r task_file; do
				TASK_INPUTS+=("${task_file}")
			done < <(find "${VERSION_DIR}/tasks" -type f -name '*.md' | sort)
		fi

		if ! bash "${SCRIPT_DIR}/export-pdf.sh" "${TASK_INPUTS[@]}" \
			--title "${TITLE}" \
			--subtitle "任务与交互规格（内部）" \
			--version "${VERSION}" \
			--output "${EXPORT_DIR}/tasks-${VERSION}.pdf"; then
			FAILED=1
		fi
	fi
fi

echo "==============================="

if [ "${FAILED}" -ne 0 ]; then
	echo "[NG] 导出过程中有失败项。"
	exit 1
fi

echo "[OK] 导出完成，产物在 ${EXPORT_DIR}/"
echo "     对外交付只发 prd-${VERSION}.pdf，任务规格仅内部使用。"
