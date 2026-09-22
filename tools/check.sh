#!/usr/bin/env bash
# PRD 结构校验器，把产品文档的确定性规则变成会 fail 的检查
# 创建日期：2026-09-21
# 修改日期：2026-09-21

# 说明：故意不用 set -e。grep 无匹配时返回非 0 属正常，需手动累计错误而非中断。
set -uo pipefail

# 校验范围，与 README 同源，改这里要同步改那一处
LINT_SCOPE='必需文件/版本目录命名/版本内必需文档/章节完整性/需求编号/图的位置与来源/版本状态/任务规格'

# 违规计数：任意一项 > 0 则退出码非 0
VIOLATIONS=0

# PRD 根目录：缺省按约定放在 docs/prd
PRD_ROOT="${1:-docs/prd}"

# 版本目录命名：只允许数字.数字
VERSION_DIR_REGEX='^[0-9]+\.[0-9]+$'

# 需求编号：REQ-<版本>-<三位序号>
REQ_ID_REGEX='REQ-[0-9]+\.[0-9]+-[0-9]{3}'

# 任务编号：Task-<三位序号>，在单个版本内唯一
TASK_ID_REGEX='Task-[0-9]{3}'

# 每个任务必须齐全的小节
REQUIRED_TASK_SECTIONS=(
	"### 任务内容"
	"### 流程"
	"### 交互规格"
	"### 验收"
)

# 交互规格必填的七个字段
REQUIRED_SPEC_FIELDS=(
	"触发"
	"前置条件"
	"正常路径"
	"边界情况"
	"错误处理"
	"兜底行为"
	"显示规则"
)

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
	echo "[1/8] 检查必需文件..."

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
	echo "[2/8] 检查版本目录命名..."

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
	echo "[3/8] 检查版本内必需文档..."

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
	echo "[4/8] 检查 prd.md 章节完整性..."

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
	echo "[5/8] 检查需求编号..."

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

# 检查六：图的位置与来源
# Mermaid 图写进 diagrams/ 独立文件的话，正文与导出的 PDF 里都没有图，等于白画
# 位图无法从文本复现，必须配同名说明记录来源
check_diagram_notes() {
	echo "[6/8] 检查图的位置与来源..."

	local diagram_file
	while IFS= read -r diagram_file; do

		if grep -q '^```mermaid' "${diagram_file}"; then
			report "${diagram_file} 把 Mermaid 图写进了 diagrams/ 独立文件(图要写在 prd.md 与 tasks.md 正文里,否则正文与 PDF 里都看不到)"
		fi

	done < <(find "${PRD_ROOT}" -type f -path '*/diagrams/*' -name '*.md' 2>/dev/null)

	local image_file note_file
	while IFS= read -r image_file; do
		note_file="${image_file%.*}.md"

		if [ ! -f "${note_file}" ]; then
			report "${image_file} 缺少同名来源说明 $(basename "${note_file}")(位图无法从文本复现,要记录来源与日期)"
		fi

	done < <(find "${PRD_ROOT}" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.webp' \) 2>/dev/null)
}

# 检查七：README 必须声明三个版本状态
check_version_states() {
	echo "[7/8] 检查版本状态声明..."

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

# 检查八：任务编号、必需小节与交互规格字段
# 图上的标注不能代替规格表，字段缺一项就意味着开发要回头问
check_tasks() {
	echo "[8/8] 检查任务与交互规格..."

	local task_file
	while IFS= read -r task_file; do
		local ids duplicated
		ids=$(grep -oE "^## ${TASK_ID_REGEX}" "${task_file}" | grep -oE "${TASK_ID_REGEX}" || true)

		if [ -z "${ids}" ]; then
			report "${task_file} 没有任何任务编号(格式 ## Task-<三位序号>：标题)"
			continue
		fi

		duplicated=$(printf '%s\n' "${ids}" | sort | uniq -d)

		if [ -n "${duplicated}" ]; then
			report "${task_file} 任务编号重复：$(printf '%s' "${duplicated}" | tr '\n' ' ')"
		fi

		local task_count section field
		task_count=$(printf '%s\n' "${ids}" | grep -c . | tr -d ' ')

		# 小节与字段按出现次数核对，数量对不上说明某个任务漏写
		for section in "${REQUIRED_TASK_SECTIONS[@]}"; do
			local section_count
			section_count=$(grep -cF -- "${section}" "${task_file}" || true)

			if [ "${section_count}" -lt "${task_count}" ]; then
				report "${task_file} 有 ${task_count} 个任务，但只有 ${section_count} 处 ${section}"
			fi
		done

		for field in "${REQUIRED_SPEC_FIELDS[@]}"; do
			local field_count
			field_count=$(grep -cE "^\| *${field} *\|" "${task_file}" || true)

			if [ "${field_count}" -lt "${task_count}" ]; then
				report "${task_file} 有 ${task_count} 个任务，但交互规格里只有 ${field_count} 处「${field}」字段"
			fi
		done

		# 流程小节要么画了图，要么写明单一路径无分支
		local flow_diagrams flow_declared
		flow_diagrams=$(grep -c '^```mermaid' "${task_file}" || true)
		flow_declared=$(grep -c '单一路径，无分支' "${task_file}" || true)

		if [ "$((flow_diagrams + flow_declared))" -lt "${task_count}" ]; then
			report "${task_file} 有 ${task_count} 个任务，但流程小节只有 ${flow_diagrams} 张图与 ${flow_declared} 处无分支声明(有分支的操作必须画流程图)"
		fi

		# 关联需求必须存在，且引用的需求编号要能在同版本 prd.md 里找到
		local version_dir prd_file referenced missing
		version_dir="$(dirname "${task_file}")"
		prd_file="${version_dir}/prd.md"
		referenced=$(grep -oE "${REQ_ID_REGEX}" "${task_file}" | sort -u || true)

		if [ -z "${referenced}" ]; then
			report "${task_file} 没有任何关联需求编号(每个任务必须关联至少一个 REQ)"
			continue
		fi

		if [ ! -f "${prd_file}" ]; then
			continue
		fi

		missing=""
		local req_id
		while IFS= read -r req_id; do

			if [ -z "${req_id}" ]; then
				continue
			fi

			if ! grep -qF -- "${req_id}" "${prd_file}"; then
				missing="${missing} ${req_id}"
			fi

		done <<< "${referenced}"

		if [ -n "${missing}" ]; then
			report "${task_file} 引用了 prd.md 里不存在的需求编号：${missing}"
		fi

	done < <(find "${PRD_ROOT}" -type f -name 'tasks.md' 2>/dev/null)
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
check_tasks

echo "==============================="

if [ "${VIOLATIONS}" -gt 0 ]; then
	echo "[NG] 发现 ${VIOLATIONS} 处结构问题，请修正后再交付。"
	exit 1
fi

echo "[OK] 结构校验通过。"
exit 0
