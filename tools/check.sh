#!/usr/bin/env bash
# PRD 结构校验器，把产品文档的确定性规则变成会 fail 的检查
# 创建日期：2026-09-21
# 修改日期：2026-09-21

# 说明：故意不用 set -e。grep 无匹配时返回非 0 属正常，需手动累计错误而非中断。
set -uo pipefail

# 校验范围，与 README 同源，改这里要同步改那一处
LINT_SCOPE='必需文件/版本目录命名/版本内必需文档/章节完整性/需求编号/图的位置与来源/版本状态/任务规格/字段类型/角色引用'

# 违规计数：任意一项 > 0 则退出码非 0
VIOLATIONS=0

# PRD 根目录：缺省按约定放在 docs/prd
PRD_ROOT="${1:-docs/prd}"

# 版本目录命名：只允许数字.数字
VERSION_DIR_REGEX='^[0-9]+\.[0-9]+$'

# 需求编号：REQ-<版本>-<三位序号>
REQ_ID_REGEX='REQ-[0-9]+\.[0-9]+-[0-9]{3}'

# 行级豁免标记：正文里写上它，该行跳过角色引用检查
# 泛指的"负责人"这类词会误报，用它放行
LINE_IGNORE_MARK='check-ignore'
# ENUM 单列：它虽然是 SQL 类型，但改值要 ALTER TABLE，跨库迁移也麻烦
FORBIDDEN_FIELD_TYPES='String|Integer|Number|Boolean|Array|Object|Date|Float|Double|Long|Enum|ENUM'

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

# prd.md 必须齐全的章节，编号固定不可改
REQUIRED_SECTIONS=(
	"## 版本历史"
	"## 1. 需求概述"
	"## 2. 产品描述"
	"### 名词解释"
	"### 整体流程"
	"### 功能清单"
	"## 3. 功能需求"
	"## 4. 非功能需求"
	"## 5. Non-goals"
	"## 6. 成功标准 / Release Criteria"
	"## 7. 未解决问题"
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
	echo "[1/9] 检查必需文件..."

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
	echo "[2/9] 检查版本目录命名..."

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
	echo "[3/9] 检查版本内必需文档..."

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
	echo "[4/9] 检查 prd.md 章节完整性..."

	local prd_file section
	while IFS= read -r prd_file; do

		for section in "${REQUIRED_SECTIONS[@]}"; do

			if ! grep -qF -- "${section}" "${prd_file}"; then
				report "${prd_file} 缺少章节：${section}"
			fi
		done

		check_field_types "${prd_file}"

	done < <(find "${PRD_ROOT}" -type f -name 'prd.md' 2>/dev/null)
}

# 检查五：需求条目必须带编号，且同一版本内不重复分配
# 重复检测只看定义行（形如「- REQ-1.0-001 ...」），不看正文引用。
# 规范本身要求交叉引用：失效需求指向替代编号、未解决问题标注影响的需求、
# Later 指向后续版本需求，这些都会让同一编号在文中出现多次，但不构成重复分配。
check_requirement_ids() {
	echo "[5/9] 检查需求编号..."

	local prd_file ids defined duplicated
	while IFS= read -r prd_file; do
		ids=$(grep -oE "${REQ_ID_REGEX}" "${prd_file}" || true)

		if [ -z "${ids}" ]; then
			report "${prd_file} 的主要功能与行为没有任何需求编号(格式 REQ-<版本>-<三位序号>)"
			continue
		fi

		# 定义行：行首为列表符号后紧跟编号
		defined=$(grep -oE "^[-*] ${REQ_ID_REGEX}" "${prd_file}" | grep -oE "${REQ_ID_REGEX}" || true)
		duplicated=$(printf '%s\n' "${defined}" | grep -v '^$' | sort | uniq -d)

		if [ -n "${duplicated}" ]; then
			report "${prd_file} 需求编号重复分配：$(printf '%s' "${duplicated}" | tr '\n' ' ')"
		fi

	done < <(find "${PRD_ROOT}" -type f -name 'prd.md' 2>/dev/null)
}

# 检查六：图的位置与来源
# Mermaid 图写进 diagrams/ 独立文件的话，正文与导出的 PDF 里都没有图，等于白画
# 位图无法从文本复现，必须配同名说明记录来源
check_diagram_notes() {
	echo "[6/9] 检查图的位置与来源..."

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

# 字段定义表的类型列必须写 SQL 类型
# 表格行形如 | 字段名 | 类型 | 必填 | ...，取第二列判断
check_field_types() {
	local doc_file="$1"
	local hits

	hits=$(grep -nE "^\|[^|]+\| *(${FORBIDDEN_FIELD_TYPES}) *\|" "${doc_file}" || true)

	if [ -n "${hits}" ]; then
		report "${doc_file} 字段表用了语言层类型(改用 VARCHAR/TINYINT/DECIMAL 等 SQL 类型,枚举用 TINYINT 并在约束列列出取值):"
		echo "${hits}" | sed 's/^/         /'
	fi
}

# 检查七：README 必须声明三个版本状态
check_version_states() {
	echo "[7/9] 检查版本状态声明..."

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
	echo "[8/9] 检查任务与交互规格..."

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

# 检查九：角色与术语的交叉引用
# prd.md 与 tasks.md 里出现的角色称谓，必须在 product.md 的角色表里存在。
# 角色表与正文相隔几百行，这类不一致靠人工评审很难发现，交给脚本。
# 用 python3 做中文分词判定：grep -E 没有中文词边界，会把「一人一岗」切成「一岗」误报。
check_cross_reference() {
	echo "[9/9] 检查角色与术语交叉引用..."

	local product_file="${PRD_ROOT}/product.md"

	if [ ! -f "${product_file}" ]; then
		return
	fi

	if ! command -v python3 > /dev/null 2>&1; then
		echo "  [SKIP] 未找到 python3，跳过交叉引用检查"
		return
	fi

	local result
	result=$(PRD_ROOT="${PRD_ROOT}" IGNORE_MARK="${LINE_IGNORE_MARK}" python3 <<'PYCHECK'
import os, re, glob

root = os.environ['PRD_ROOT']
text_product = open(os.path.join(root, 'product.md'), encoding='utf-8').read()

# 只查高区分度的职位后缀。
# 「岗」不在其列：岗位名在 product.md 角色表中本就全量列出，且「一人一岗」「按岗配置」
# 这类普通表述会大量误报，信噪比过低。
SUFFIX = ('负责人', '管理员', '总监', '经理')
HAN = re.compile(r'[一-龥]')
MASK = '　'

def candidates(text):
    """从每个后缀出现位置向前取最长连续汉字片段（上限 8 字）"""
    found = set()
    for suf in SUFFIX:
        for m in re.finditer(re.escape(suf), text):
            end = m.end()
            i = m.start()
            while i > 0 and HAN.match(text[i - 1]) and text[i - 1] != MASK and end - i < 8:
                i -= 1
            found.add(text[i:end])
    return found

def declared(text):
    """product.md 中声明的角色：表格第二列 + 全文出现的后缀词"""
    d = set()
    for row in re.findall(r'^\|[^|]*\|([^|]+)\|', text, re.M):
        v = row.strip()
        if v and HAN.search(v):
            d.add(v)
    d |= candidates(text)
    return d

defined = declared(text_product)

def is_known(word):
    """候选词的任一后缀子串命中已声明角色即视为合法引用。
    这样「请联系数据与系统管理员」与其简称「管理员」都能通过，
    前提是该简称已在 product.md 角色表中声明。"""
    return any(word[i:] in defined for i in range(len(word)))

problems = []
docs = sorted(set(glob.glob(os.path.join(root, '**', 'prd.md'), recursive=True) +
                  glob.glob(os.path.join(root, '**', 'tasks.md'), recursive=True)))
ignore_mark = os.environ.get('IGNORE_MARK', '')

for doc in docs:
    lines = open(doc, encoding='utf-8').read().splitlines()
    # 写了豁免标记的行跳过，用于放行泛指的「负责人」这类词
    kept = [ln for ln in lines if not (ignore_mark and ignore_mark in ln)]
    missing = sorted({w for w in candidates('\n'.join(kept)) if not is_known(w)})
    if missing:
        problems.append(f"{os.path.relpath(doc)}|{' '.join(missing)}")

print('\n'.join(problems))
PYCHECK
)

	if [ -z "${result}" ]; then
		return
	fi

	local line doc roles
	while IFS= read -r line; do

		if [ -z "${line}" ]; then
			continue
		fi

		doc="${line%%|*}"
		roles="${line#*|}"
		report "${doc} 使用了 product.md 角色表未定义的角色称谓：${roles}(片段含前文,以后缀词为准;在角色表中补充定义,或改用已定义的角色名,泛指词在该行加 check-ignore 豁免)"

	done <<< "${result}"
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
check_cross_reference

echo "==============================="

if [ "${VIOLATIONS}" -gt 0 ]; then
	echo "[NG] 发现 ${VIOLATIONS} 处结构问题，请修正后再交付。"
	exit 1
fi

echo "[OK] 结构校验通过。"
exit 0
