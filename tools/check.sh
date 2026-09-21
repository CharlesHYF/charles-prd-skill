#!/usr/bin/env bash
# PRD 结构校验器，把产品文档的确定性规则变成会 fail 的检查
# 创建日期：2026-09-21
# 修改日期：2026-09-21

# 说明：故意不用 set -e。grep 无匹配时返回非 0 属正常，需手动累计错误而非中断。
set -uo pipefail

# 校验范围，与 README 同源，改这里要同步改那一处
LINT_SCOPE='必需文件/版本目录命名/版本内必需文档/章节完整性/需求编号/图的生成说明/版本状态'

# 违规计数：任意一项 > 0 则退出码非 0
VIOLATIONS=0

# PRD 根目录：缺省按约定放在 docs/prd
PRD_ROOT="${1:-docs/prd}"

# 版本目录命名：只允许数字.数字
VERSION_DIR_REGEX='^[0-9]+\.[0-9]+$'

# 需求编号：REQ-<版本>-<三位序号>
REQ_ID_REGEX='REQ-[0-9]+\.[0-9]+-[0-9]{3}'

# prd.md 必须齐全的八个章节
REQUIRED_SECTIONS=(
	"## 背景"
	"## 目标用户与核心问题"
	"## 这一版的目标"
	"## Non-goals"
	"## 核心用户流程"
	"## 主要功能与行为"
	"## 成功标准 / Release Criteria"
	"## 未解决问题"
)

# README 必须声明的三个版本状态
REQUIRED_STATES=(
	"Production:"
	"Development:"
	"Next:"
)

report() {
	local message="$1"

	echo "  [FAIL] ${message}"
	VIOLATIONS=$((VIOLATIONS + 1))
}

# 检查一：PRD 根目录下的必需文件
check_required_files() {
	echo "[1/7] 检查必需文件..."

	local required
	for required in "README.md" "product.md"; do

		if [ ! -f "${PRD_ROOT}/${required}" ]; then
			report "缺少必需文件：${PRD_ROOT}/${required}"
		fi
	done

	if [ ! -d "${PRD_ROOT}/versions" ]; then
		report "缺少版本目录：${PRD_ROOT}/versions/"
	fi
}

# 检查二：版本目录命名，禁止 current / latest / new 这类会过期的名字
check_version_dirs() {
	echo "[2/7] 检查版本目录命名..."

	if [ ! -d "${PRD_ROOT}/versions" ]; then
		return
	fi

	local version_dir version_name found=0
	for version_dir in "${PRD_ROOT}"/versions/*/; do

		if [ ! -d "${version_dir}" ]; then
			continue
		fi

		version_name="$(basename "${version_dir%/}")"
		found=1

		if [[ ! "${version_name}" =~ ${VERSION_DIR_REGEX} ]]; then
			report "版本目录名不是明确版本号：versions/${version_name}(应形如 1.0、2.1，禁止 current/latest/new)"
		fi
	done

	if [ "${found}" -eq 0 ]; then
		report "versions/ 下没有任何版本目录"
	fi
}

# 检查三：major 版本必须有 prd.md 与 scope.md，minor 版本至少有 changes.md
check_version_docs() {
	echo "[3/7] 检查版本内必需文档..."

	if [ ! -d "${PRD_ROOT}/versions" ]; then
		return
	fi

	local version_dir version_name minor
	for version_dir in "${PRD_ROOT}"/versions/*/; do

		if [ ! -d "${version_dir}" ]; then
			continue
		fi

		version_name="$(basename "${version_dir%/}")"

		if [[ ! "${version_name}" =~ ${VERSION_DIR_REGEX} ]]; then
			continue
		fi

		minor="${version_name#*.}"

		if [ "${minor}" = "0" ]; then

			if [ ! -f "${version_dir}prd.md" ]; then
				report "versions/${version_name}/ 缺少 prd.md(major 版本必须有完整 PRD)"
			fi

			if [ ! -f "${version_dir}scope.md" ]; then
				report "versions/${version_name}/ 缺少 scope.md(major 版本必须声明范围)"
			fi
		else

			if [ ! -f "${version_dir}changes.md" ] && [ ! -f "${version_dir}prd.md" ]; then
				report "versions/${version_name}/ 缺少 changes.md(minor 版本至少要说明改了什么)"
			fi
		fi
	done
}

# 检查四：prd.md 的八个章节不增不减
check_prd_sections() {
	echo "[4/7] 检查 prd.md 章节完整性..."

	local prd_file section
	while IFS= read -r prd_file; do

		for section in "${REQUIRED_SECTIONS[@]}"; do

			if ! grep -qF -- "${section}" "${prd_file}"; then
				report "${prd_file} 缺少章节：${section}"
			fi
		done

	done < <(find "${PRD_ROOT}" -type f -name 'prd.md' 2>/dev/null)
}

# 检查五：需求条目必须带编号，且同一版本内不重复
check_requirement_ids() {
	echo "[5/7] 检查需求编号..."

	local prd_file ids duplicated
	while IFS= read -r prd_file; do
		ids=$(grep -oE "${REQ_ID_REGEX}" "${prd_file}" || true)

		if [ -z "${ids}" ]; then
			report "${prd_file} 的主要功能与行为没有任何需求编号(格式 REQ-<版本>-<三位序号>)"
			continue
		fi

		duplicated=$(printf '%s\n' "${ids}" | sort | uniq -d)

		if [ -n "${duplicated}" ]; then
			report "${prd_file} 需求编号重复：$(printf '%s' "${duplicated}" | tr '\n' ' ')"
		fi

	done < <(find "${PRD_ROOT}" -type f -name 'prd.md' 2>/dev/null)
}

# 检查六：每张图必须有同名生成说明，否则改图时无从复现提示词
check_diagram_notes() {
	echo "[6/7] 检查图的生成说明..."

	local image_file note_file
	while IFS= read -r image_file; do
		note_file="${image_file%.*}.md"

		if [ ! -f "${note_file}" ]; then
			report "${image_file} 缺少同名生成说明 $(basename "${note_file}")"
		fi

	done < <(find "${PRD_ROOT}" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.webp' \) 2>/dev/null)
}

# 检查七：README 必须声明三个版本状态
check_version_states() {
	echo "[7/7] 检查版本状态声明..."

	local readme="${PRD_ROOT}/README.md"

	if [ ! -f "${readme}" ]; then
		return
	fi

	local state
	for state in "${REQUIRED_STATES[@]}"; do

		if ! grep -qF -- "${state}" "${readme}"; then
			report "${readme} 缺少版本状态声明：${state}"
		fi
	done
}

if [ ! -d "${PRD_ROOT}" ]; then
	echo "[NG] 找不到 PRD 目录：${PRD_ROOT}"
	echo "用法: check.sh [PRD 根目录]  缺省为 docs/prd"
	exit 2
fi

echo "=== charles-prd 结构校验 ==="
echo "校验目录：${PRD_ROOT}"
echo "校验范围：${LINT_SCOPE}"

check_required_files
check_version_dirs
check_version_docs
check_prd_sections
check_requirement_ids
check_diagram_notes
check_version_states

echo "==============================="

if [ "${VIOLATIONS}" -gt 0 ]; then
	echo "[NG] 发现 ${VIOLATIONS} 处结构问题，请修正后再交付。"
	exit 1
fi

echo "[OK] 结构校验通过。"
exit 0
