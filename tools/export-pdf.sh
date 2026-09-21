#!/usr/bin/env bash
# 把 PRD 的 Markdown 源文件渲染成带样式的 HTML 再打印为 PDF
# 创建日期：2026-09-21
# 修改日期：2026-09-21

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 中间产物 HTML 与最终 PDF 的默认落点
DEFAULT_OUTPUT_DIR="export"

usage() {
	cat <<'USAGE'
用法: export-pdf.sh <输入.md...> [选项]

选项:
  -o, --output <文件>     输出 PDF 路径，缺省为 export/<第一个输入文件名>.pdf
  -t, --title <标题>      封面主标题，不给则不生成封面页
  -s, --subtitle <副标题> 封面上方的小标题，缺省为"产品需求文档"
  -v, --version <版本>    封面版本号，如 1.0
  -n, --note <说明>       封面下方的提示框文案
  -f, --footer <页脚>     每页页脚左侧文案，缺省用标题
      --keep-html         保留中间产物 HTML

示例:
  bash tools/export-pdf.sh docs/prd/product.md docs/prd/versions/1.0/prd.md \
    --title "订单系统" --version 1.0 --output export/prd-1.0.pdf
USAGE
}

INPUTS=()
OUTPUT=""
TITLE=""
SUBTITLE=""
VERSION=""
NOTE=""
FOOTER=""
KEEP_HTML=0

while [ $# -gt 0 ]; do

	case "$1" in
		-o | --output)
			OUTPUT="${2:-}"
			shift 2
			;;
		-t | --title)
			TITLE="${2:-}"
			shift 2
			;;
		-s | --subtitle)
			SUBTITLE="${2:-}"
			shift 2
			;;
		-v | --version)
			VERSION="${2:-}"
			shift 2
			;;
		-n | --note)
			NOTE="${2:-}"
			shift 2
			;;
		-f | --footer)
			FOOTER="${2:-}"
			shift 2
			;;
		--keep-html)
			KEEP_HTML=1
			shift
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			INPUTS+=("$1")
			shift
			;;
	esac
done

if [ "${#INPUTS[@]}" -eq 0 ]; then
	usage
	exit 2
fi

for input in "${INPUTS[@]}"; do

	if [ ! -f "${input}" ]; then
		echo "[NG] 找不到输入文件：${input}"
		exit 1
	fi
done

if [ ! -d "${SCRIPT_DIR}/node_modules" ]; then
	echo "首次运行，安装渲染依赖..."

	if ! (cd "${SCRIPT_DIR}" && npm install --silent); then
		echo "[NG] 依赖安装失败，需要 Node.js 环境。"
		exit 1
	fi
fi

if [ -z "${OUTPUT}" ]; then
	base_name="$(basename "${INPUTS[0]}" .md)"
	mkdir -p "${DEFAULT_OUTPUT_DIR}"
	OUTPUT="${DEFAULT_OUTPUT_DIR}/${base_name}.pdf"
fi

mkdir -p "$(dirname "${OUTPUT}")"
HTML_PATH="${OUTPUT%.pdf}.html"

RENDER_ARGS=("${INPUTS[@]}" "--output" "${HTML_PATH}")

if [ -n "${TITLE}" ]; then
	RENDER_ARGS+=("--title" "${TITLE}")
fi

if [ -n "${SUBTITLE}" ]; then
	RENDER_ARGS+=("--subtitle" "${SUBTITLE}")
fi

if [ -n "${VERSION}" ]; then
	RENDER_ARGS+=("--version" "${VERSION}")
fi

if [ -n "${NOTE}" ]; then
	RENDER_ARGS+=("--note" "${NOTE}")
fi

if ! node "${SCRIPT_DIR}/render.mjs" "${RENDER_ARGS[@]}"; then
	echo "[NG] Markdown 渲染失败。"
	exit 1
fi

if [ -z "${FOOTER}" ]; then
	FOOTER="${TITLE}"
fi

if [ -n "${VERSION}" ] && [ -n "${FOOTER}" ]; then
	FOOTER="${FOOTER}  ·  ${VERSION}"
fi

if ! node "${SCRIPT_DIR}/print.mjs" "${HTML_PATH}" --output "${OUTPUT}" --footer "${FOOTER}"; then
	echo "[NG] PDF 打印失败。"
	exit 1
fi

if [ "${KEEP_HTML}" -eq 0 ]; then
	rm -f "${HTML_PATH}"
fi

echo "==============================="
echo "[OK] 导出完成：${OUTPUT}"
