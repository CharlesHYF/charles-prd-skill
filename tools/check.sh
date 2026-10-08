#!/usr/bin/env bash
# PRD 结构校验器，把产品文档的确定性规则变成会 fail 的检查
# 创建日期：2026-09-21
# 修改日期：2026-10-08

# 说明：故意不用 set -e。grep 无匹配时返回非 0 属正常，需手动累计错误而非中断。
set -uo pipefail

# 校验范围，与 README 同源，改这里要同步改那一处
LINT_SCOPE='必需文件/版本目录命名/版本内必需文档/章节完整性/需求编号/图的位置与来源/界面标注图/版本状态/任务规格/字段类型/占位残留/角色引用/待填残留/产品形态/截图视口/需求确认记录/原型来源对照/表格分点换行'

# 检查步骤总数，新增检查时同步加一
TOTAL_STEPS=16

# 骨架里要填的位置统一用这个前缀，交付前必须全部替换
FILL_MARK='[待填]'

# 产品形态的合法取值，用于报错提示
ALLOWED_FORMS='后台管理系统、Web 应用、App、小程序'

# 形态检查的结论，供截图视口检查使用
HAS_WEB_FORM=0
ONLY_MOBILE_FORMS=0
MOBILE_ADAPT=""

# 手机端截图清单的命名：桌面截图名加这个后缀，校验靠命名配对
MOBILE_SHOT_SUFFIX='-mobile'

# 标注图在 PDF 里占满正文宽度，截图高宽比超过它就放不进一页；与 tools/annotate.mjs 保持一致
MAX_ASPECT='1.25'

# 这几类元素每个都必须有标注；导航、表头、指标卡与区块不强制
REQUIRED_MARK_KINDS='btn field link'

# notes.md 里记录提问结论与落点的小节
CONFIRM_SECTION='## 需求确认记录'

# 复刻原型时记录每个页面对应真实源码的对照表
SOURCES_NAME='sources.md'

# 违规计数：任意一项 > 0 则退出码非 0
VIOLATIONS=0

# 表格单元格里的分点上限，超过就该改成表格下方的列表
MAX_TABLE_POINTS=6

# --fix：把表格里没换行的分点自动改写成编号加 <br>，清空标记块里旧版存下的标注图，其余检查照常执行
SHOULD_FIX=0

# PRD 根目录：缺省按约定放在 docs/prd
PRD_ROOT="docs/prd"

for argument in "$@"; do

	case "${argument}" in
		--fix)
			SHOULD_FIX=1
			;;
		*)
			PRD_ROOT="${argument}"
			;;
	esac
done

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
	"### 界面"
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
	echo "[1/${TOTAL_STEPS}] 检查必需文件..."

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
	echo "[2/${TOTAL_STEPS}] 检查版本目录命名..."

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
	echo "[3/${TOTAL_STEPS}] 检查版本内必需文档..."

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
	echo "[4/${TOTAL_STEPS}] 检查 prd.md 章节完整性..."

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
# 重复检测只看定义行（形如"- REQ-1.0-001 ..."），不看正文引用。
# 规范本身要求交叉引用：失效需求指向替代编号、未解决问题标注影响的需求、
# Later 指向后续版本需求，这些都会让同一编号在文中出现多次，但不构成重复分配。
check_requirement_ids() {
	echo "[5/${TOTAL_STEPS}] 检查需求编号..."

	local prd_file ids defined duplicated
	while IFS= read -r prd_file; do
		ids=$(grep -oE "${REQ_ID_REGEX}" "${prd_file}" || true)

		if [ -z "${ids}" ]; then
			report "${prd_file} 的功能需求没有任何需求编号(格式 REQ-<版本>-<三位序号>)"
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
	echo "[6/${TOTAL_STEPS}] 检查图的位置与来源..."

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

# 原型改过而没重新截图的话，标注框会整体错位，而且从文档上看不出来
# 指纹算法与 tools/fingerprint.mjs 一致：路径与文件内容各自 sha256 后再整体 sha256
check_coords_freshness() {
	local coords_file="$1"

	if ! command -v python3 > /dev/null 2>&1; then
		echo "  [SKIP] 未找到 python3，跳过坐标时效检查：${coords_file}"
		return
	fi

	local stale
	stale=$(COORDS="${coords_file}" python3 <<'PYFRESH'
import hashlib, json, os, sys

coords_file = os.environ['COORDS']
base = os.path.dirname(coords_file)

try:
    coords = json.load(open(coords_file, encoding='utf-8'))
except Exception:
    print('_coords.json 不是合法 JSON')
    sys.exit(0)


def fingerprint(root):
    parts = []
    for cur, dirs, files in os.walk(root):
        dirs[:] = sorted(d for d in dirs if not d.startswith('.'))
        for name in sorted(f for f in files if not f.startswith('.')):
            full = os.path.join(cur, name)
            with open(full, 'rb') as fh:
                digest = hashlib.sha256(fh.read()).hexdigest()
            parts.append(f"{os.path.relpath(full, root)}\0{digest}")
    parts.sort()
    return hashlib.sha256('\n'.join(parts).encode()).hexdigest()


cache = {}

for shot, data in coords.items():
    want = data.get('fingerprint')

    if not want:
        continue

    spec_file = os.path.join(base, f'{shot}.json')

    if not os.path.isfile(spec_file):
        continue

    page = json.load(open(spec_file, encoding='utf-8')).get('page', '')
    page_path = os.path.normpath(os.path.join(base, page))
    root = os.path.dirname(page_path)

    if '/pages/' in page_path.replace(os.sep, '/'):
        root = os.path.dirname(root)

    if not os.path.isdir(root):
        continue

    if root not in cache:
        cache[root] = fingerprint(root)

    if cache[root] != want:
        print(f"{shot} 的坐标是 {data.get('capturedAt', '早前')} 量的，原型之后改过")
PYFRESH
)

	if [ -z "${stale}" ]; then
		return
	fi

	local line
	while IFS= read -r line; do

		if [ -n "${line}" ]; then
			report "${line}(标注框会整体错位,先重跑 tools/capture.mjs 再重跑 tools/annotate.mjs)"
		fi

	done <<< "${stale}"
}

# 检查六之二：界面标注图的清单、坐标、截图与标记块
# 标注图导出时才由 render.mjs 生成，文档里只留空标记块；清单与坐标对不上、截图过高、漏标都在这里拦
# 全部文件一次读进 python 处理：逐标记 grep、逐清单起进程的写法在几百张图的文档上要跑几分钟
check_annotations() {
	echo "[7/${TOTAL_STEPS}] 检查界面标注图..."

	local coords note

	while IFS= read -r coords; do
		note="$(dirname "${coords}")/_coords.md"

		if [ ! -f "${note}" ]; then
			report "${coords} 缺少同名来源说明 _coords.md(坐标是量出来的,要记录来源与日期)"
		fi

		check_coords_freshness "${coords}"

	done < <(find "${PRD_ROOT}" -type f -name '_coords.json' 2>/dev/null)

	if ! command -v python3 > /dev/null 2>&1; then
		echo "  [SKIP] 未找到 python3，跳过标注清单、高宽比、标注覆盖与界面标记块检查"
		return
	fi

	# 旧版工具把生成的 SVG 存进了标记块，现在导出时现场生成，--fix 把块内内容清空，标记本身保留
	if [ "${SHOULD_FIX}" -eq 1 ]; then
		PRD_ROOT="${PRD_ROOT}" python3 <<'PYCLEAR'
import os, re

root = os.environ['PRD_ROOT']
BLOCK = re.compile(r'(<!--annotation:([^>]+?)-->)[\s\S]*?(<!--/annotation-->)')

for cur, dirs, files in os.walk(root):
    dirs[:] = [d for d in dirs if d not in ('export', 'node_modules') and not d.startswith('.')]

    for name in sorted(files):
        if not name.endswith('.md'):
            continue

        path = os.path.join(cur, name)
        text = open(path, encoding='utf-8').read()
        cleared = []

        def empty(match):
            if match.group(0) != f"{match.group(1)}\n{match.group(3)}":
                cleared.append(match.group(2))
            return f"{match.group(1)}\n{match.group(3)}"

        updated = BLOCK.sub(empty, text)

        if cleared:
            open(path, 'w', encoding='utf-8').write(updated)
            print(f"  [OK] 已清空 {path} 里 {len(cleared)} 个标记块的旧内容")
PYCLEAR
	fi

	local findings line
	findings=$(PRD_ROOT="${PRD_ROOT}" MAX_ASPECT="${MAX_ASPECT}" REQUIRED_KINDS="${REQUIRED_MARK_KINDS}" FILL_MARK="${FILL_MARK}" python3 <<'PYANN'
import json, os, re

root = os.environ['PRD_ROOT']
max_aspect = float(os.environ['MAX_ASPECT'])
required_kinds = os.environ['REQUIRED_KINDS'].split()
fill_mark = os.environ['FILL_MARK']

OPEN = re.compile(r'<!--annotation:([^>]+?)-->')
CLOSE = '<!--/annotation-->'


def load(path):
    try:
        return json.load(open(path, encoding='utf-8'))
    except Exception:
        return None


def matches(el, target):
    if target.get('kind') and el.get('kind') != target.get('kind'):
        return False
    name = target.get('el') or ''
    txt = el.get('txt') or ''
    return bool(name) and (txt == name or name in txt)


marks_by_dir = {}
coords_by_dir = {}

for cur, dirs, files in os.walk(root):
    dirs[:] = [d for d in dirs if d not in ('export', 'node_modules') and not d.startswith('.')]

    for name in sorted(files):
        if not name.endswith('.marks.json'):
            continue

        path = os.path.join(cur, name)
        spec = load(path)

        if not isinstance(spec, dict):
            print(f"{path} 不是合法 JSON")
            continue

        shot = spec.get('shot') or ''
        mark = spec.get('mark') or shot
        marks_by_dir.setdefault(cur, {})[mark] = (path, spec)

        if cur not in coords_by_dir:
            coords_by_dir[cur] = load(os.path.join(cur, '_coords.json')) if os.path.isfile(os.path.join(cur, '_coords.json')) else None

        coords = coords_by_dir[cur]

        if coords is None:
            print(f"{path} 所在目录没有 _coords.json(先跑 tools/capture.mjs 截图并量坐标)")
            continue

        data = coords.get(shot)

        if not isinstance(data, dict):
            print(f"{path} 的 shot={shot} 在 _coords.json 里没有坐标(先跑 tools/capture.mjs {shot}.json)")
        elif not os.path.isfile(os.path.join(cur, f'{shot}.png')):
            print(f"{path} 的 shot={shot} 没有对应截图 {shot}.png(先跑 tools/capture.mjs)")

        inject = spec.get('inject')

        if inject:
            doc = os.path.normpath(os.path.join(cur, inject))

            if not os.path.isfile(doc):
                print(f"{path} 的 inject 指向的文档不存在：{inject}")
            elif f'<!--annotation:{mark}-->' not in open(doc, encoding='utf-8').read():
                print(f"{path} 的 inject 文档里没有 <!--annotation:{mark}--> 标记")

        if not isinstance(data, dict):
            continue

        width = data.get('w') or 0
        height = data.get('h') or 0

        if width and height / width > max_aspect:
            print(f"{path} 的截图 {width}x{height} 高宽比 {height / width:.2f} 超过 {max_aspect}(缩进正文后放不进一页,在截图清单里用 crop 按区块分成多张截)")

        els = data.get('els') or []
        picked = set()

        for item in spec.get('marks') or []:
            candidates = [el for el in els if matches(el, item)]

            if candidates:
                chosen = candidates[min(item.get('index', 0), len(candidates) - 1)]
                picked.add((chosen.get('kind'), chosen.get('txt')))

        skips = spec.get('skip') or []

        if any(not skip.get('el') or not skip.get('reason') for skip in skips):
            print(f"{path} 的 skip 每项都要有 el 与 reason(不说明理由的跳过等于漏标)")

        uncovered = {}

        for el in els:
            key = (el.get('kind'), el.get('txt'))

            if el.get('kind') not in required_kinds or key in picked or any(matches(el, skip) for skip in skips):
                continue

            uncovered[key] = f"{el.get('kind')}:{el.get('txt')}"

        if uncovered:
            print(f"{path} 有 {len(uncovered)} 个元素没有标注：" + " ".join(uncovered.values()) + "(每个按钮、输入控件与链接都要有一条,确实不标的写进 skip 并给出 reason)")

# 任务文档：每个任务的界面小节要有标记块；标记块必须为空，能找到清单与截图；块外不许手画 SVG
for cur, dirs, files in os.walk(root):
    dirs[:] = [d for d in dirs if d not in ('export', 'node_modules') and not d.startswith('.')]

    if 'tasks.md' not in files:
        continue

    path = os.path.join(cur, 'tasks.md')
    diagrams = os.path.join(cur, 'diagrams')
    index = marks_by_dir.get(diagrams, {})
    task = ''
    count = 0
    pending = False
    inside = None
    inside_reported = False

    def flush():
        if task and count == 0 and not pending:
            print(f"{path} 的 {task} 的界面小节没有标注标记块(在界面小节写 <!--annotation:xxx--> 与 <!--/annotation--> 空标记块,导出时由 tools/render.mjs 生成标注图)")

    for number, line in enumerate(open(path, encoding='utf-8'), 1):
        heading = re.match(r'^## (Task-\d+)', line)

        if heading:
            flush()
            task, count, pending = heading.group(1), 0, False
            continue

        if fill_mark in line:
            pending = True

        opened = OPEN.search(line)

        if opened:
            count += 1
            mark = opened.group(1)
            inside = (mark, number)
            inside_reported = False

            if CLOSE in line[opened.end():]:
                inside = None

            if mark in index:
                spec_path, spec = index[mark]
                shot = spec.get('shot') or mark
            else:
                shot = mark
                print(f"{path} 的标记块 {mark} 在 diagrams/ 下找不到 mark 或 shot 为 {mark} 的标注清单(导出时无法生成标注图)")

            if not os.path.isfile(os.path.join(diagrams, f'{shot}.png')):
                print(f"{path} 的标记块 {mark} 没有对应截图 diagrams/{shot}.png(先跑 tools/capture.mjs 截图)")
            continue

        if CLOSE in line:
            inside = None
            continue

        # 每个标记块只报一次，旧文档里几百个块各有几十行 SVG
        if inside is not None:
            if line.strip() and not inside_reported:
                print(f"{path}:{number} 的标记块 {inside[0]} 里有内容(标注图改为导出时由 tools/render.mjs 生成,标记块内不再存 SVG 与说明,删掉块内内容)")
                inside_reported = True
            continue

        if '<svg' in line:
            print(f"{path}:{number} 标记块之外出现 <svg(界面图不许手画,只能由原型截图加标注清单在导出时生成)")

    flush()
PYANN
)

	while IFS= read -r line; do

		if [ -n "${line}" ]; then
			report "${line}"
		fi

	done < <(printf '%s\n' "${findings}" | awk '!seen[$0]++')
}

# 检查十四：需求确认记录
# 问出来的答案要落进文档才算数；记录写明每条结论落到哪条 REQ、哪个 Task，评审时逐条对账
check_confirmation_records() {
	echo "[14/${TOTAL_STEPS}] 检查需求确认记录..."

	if [ ! -d "${PRD_ROOT}/versions" ]; then
		return
	fi

	local version_dir version_name notes_file rows
	for version_dir in "${PRD_ROOT}"/versions/*/; do

		if [ ! -d "${version_dir}" ]; then
			continue
		fi

		version_name="$(basename "${version_dir%/}")"

		if [[ ! "${version_name}" =~ ${VERSION_DIR_REGEX} ]] || [ ! -f "${version_dir}prd.md" ]; then
			continue
		fi

		notes_file="${version_dir}notes.md"

		if [ ! -f "${notes_file}" ]; then
			report "versions/${version_name}/ 缺少 notes.md(需求确认记录写在这里,每条结论注明落到哪条 REQ 或 Task)"
			continue
		fi

		if ! grep -qF "${CONFIRM_SECTION}" "${notes_file}"; then
			report "${notes_file} 缺少\"需求确认记录\"一节(四列表：轮次、问题、结论、落点)"
			continue
		fi

		# 只数该节里的表格行，去掉表头与分隔行
		rows=$(awk -v section="${CONFIRM_SECTION}" '
			index($0, section) == 1 { inside = 1; next }
			/^## / { inside = 0 }
			inside && /^\|/ { count++ }
			END { print (count > 2 ? count - 2 : 0) }
		' "${notes_file}")

		if [ "${rows}" -lt 1 ]; then
			report "${notes_file} 的需求确认记录没有任何记录(产出前问过的每一项都要有一行,写明结论与落点)"
		fi
	done
}

# 检查十五：原型来源对照表
# 给已有项目补 PRD 时原型从真实前端复刻，对照表记每个页面抄的是哪份源码，缺一页就是没复刻全
check_prototype_sources() {
	echo "[15/${TOTAL_STEPS}] 检查原型来源对照表..."

	local sources_file proto_dir html_file relative source_path
	while IFS= read -r sources_file; do
		proto_dir="$(dirname "${sources_file}")"

		while IFS= read -r html_file; do
			relative="${html_file#"${proto_dir}"/}"

			if ! grep -qF -- "${relative}" "${sources_file}"; then
				report "${html_file} 不在 ${SOURCES_NAME} 里(复刻的每个页面都要写明对应的真实源码与路由)"
			fi

		done < <(find "${proto_dir}" -type f -name '*.html' 2>/dev/null | sort)

		# 第二列是真实源码路径，相对产品仓根目录
		while IFS= read -r source_path; do

			if [ -z "${source_path}" ] || [ "${source_path}" = "---" ] || [ "${source_path}" = "真实源码" ]; then
				continue
			fi

			if [ ! -e "${source_path}" ]; then
				report "${sources_file} 源码路径不存在：${source_path}(对照表第二列写相对产品仓根目录的源码路径,命令在产品仓根目录执行)"
			fi

		done < <(awk -F'|' '/^\|/ { gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3 }' "${sources_file}")

	done < <(find "${PRD_ROOT}" -type f -path '*/prototype/*' -name "${SOURCES_NAME}" 2>/dev/null | sort)
}

# 检查十六：表格单元格里的分点必须换行，且不超过上限
# Markdown 表格单元格不能直接换行，几个编号点挤成一行在 PDF 里读不出层次，要用 <br> 分开
# 引号、反引号与括号里的内容是提示原文或补充说明，里面的分号与编号不算分点
check_table_points() {
	echo "[16/${TOTAL_STEPS}] 检查表格单元格分点换行..."

	if ! command -v python3 > /dev/null 2>&1; then
		echo "  [SKIP] 未找到 python3，跳过表格分点检查"
		return
	fi

	local findings
	findings=$(PRD_ROOT="${PRD_ROOT}" SHOULD_FIX="${SHOULD_FIX}" MAX_POINTS="${MAX_TABLE_POINTS}" python3 <<'PYCELL'
import os, re

root = os.environ['PRD_ROOT']
should_fix = os.environ['SHOULD_FIX'] == '1'
max_points = int(os.environ['MAX_POINTS'])

PAIRS = {'"': '"', '`': '`', '（': '）', '(': ')', '\u300c': '\u300d', '《': '》'}
BREAK = re.compile(r'<br\s*/?>', re.I)
CIRCLED = '①②③④⑤⑥⑦⑧⑨⑩⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳'
SEPARATORS = ' \t；;，,。'


def mask(text):
    # 成对符号里的内容换成占位符，长度不变，下标仍能对回原文；只含数字的括号是 (1) 这类编号，保留
    chars = list(text)
    index = 0

    while index < len(text):
        opener = text[index]
        closer = PAIRS.get(opener)

        if closer is None:
            index += 1
            continue

        end = text.find(closer, index + 1)

        if end < 0:
            index += 1
            continue

        inner = text[index + 1:end]

        if opener in '（(' and inner.isdigit():
            index = end + 1
            continue

        for position in range(index + 1, end):
            chars[position] = '\0'

        index = end + 1

    return ''.join(chars)


def sequential(matches, number_of):
    # 编号要从 1 起连续递增，才认作分点，避免把正文里的"2."、"3、"误当成编号
    picked = []
    expect = 1

    for match in matches:
        if number_of(match) == expect:
            picked.append(match)
            expect += 1

    return picked if len(picked) >= 2 else []


def split_points(cell):
    masked = mask(cell)
    cuts = []

    numbered = sequential(
        re.finditer(r'(?:(?<=^)|(?<=[\s；;，,。]))(\d{1,2})[.、](?!\d)', masked),
        lambda match: int(match.group(1)),
    )

    if numbered:
        cuts = [(match.start(), match.end()) for match in numbered]
    else:
        parens = sequential(re.finditer(r'[(（](\d{1,2})[)）]', masked), lambda match: int(match.group(1)))

        if parens:
            cuts = [(match.start(), match.end()) for match in parens]
        else:
            circled = sequential(re.finditer(f'[{CIRCLED}]', masked), lambda match: CIRCLED.index(match.group(0)) + 1)

            if circled:
                cuts = [(match.start(), match.end()) for match in circled]

    if cuts:
        head = cell[:cuts[0][0]].strip(SEPARATORS)
        points = []

        for order, (start, end) in enumerate(cuts):
            stop = cuts[order + 1][0] if order + 1 < len(cuts) else len(cell)
            points.append(cell[end:stop].strip(SEPARATORS))

        return head, [point for point in points if point]

    semicolons = [match.start() for match in re.finditer('；', masked)]

    # 两个分句用一个分号连接是正常句式，三段以上才算挤在一行的分点
    if len(semicolons) < 2 or not masked[semicolons[-1] + 1:].strip():
        return '', []

    bounds = [-1] + semicolons + [len(cell)]
    points = [cell[bounds[order] + 1:bounds[order + 1]].strip(SEPARATORS) for order in range(len(bounds) - 1)]
    return '', [point for point in points if point]


def rewrite(head, points):
    body = '<br>'.join(f'{order}. {point}' for order, point in enumerate(points, 1))
    return f'{head}<br>{body}' if head else body


for cur, dirs, files in os.walk(root):
    dirs[:] = [d for d in dirs if d not in ('export', 'prototype', 'node_modules') and not d.startswith('.')]

    for name in sorted(files):
        if not name.endswith('.md'):
            continue

        path = os.path.join(cur, name)
        lines = open(path, encoding='utf-8').read().split('\n')
        changed = False
        in_fence = False

        for number, line in enumerate(lines, 1):
            if line.startswith('```'):
                in_fence = not in_fence
                continue

            if in_fence or not line.lstrip().startswith('|') or re.match(r'^\s*\|[\s:|-]+\|\s*$', line):
                continue

            cells = line.split('|')

            for position in range(1, len(cells) - 1):
                cell = cells[position].strip()

                if BREAK.search(cell):
                    count = len([part for part in BREAK.split(cell) if part.strip()])

                    if count > max_points:
                        print(f"{path}:{number}\t{count}\tLIMIT\t{cell[:40]}")
                    continue

                head, points = split_points(cell)

                if not points:
                    continue

                if len(points) > max_points:
                    print(f"{path}:{number}\t{len(points)}\tLIMIT\t{cell[:40]}")
                    continue

                if should_fix:
                    cells[position] = f' {rewrite(head, points)} '
                    changed = True
                    print(f"{path}:{number}\t{len(points)}\tFIXED\t{cell[:40]}")
                else:
                    print(f"{path}:{number}\t{len(points)}\tINLINE\t{cell[:40]}")

            if changed:
                lines[number - 1] = '|'.join(cells)

        if changed:
            open(path, 'w', encoding='utf-8').write('\n'.join(lines))
PYCELL
)

	local location count kind sample
	while IFS=$'\t' read -r location count kind sample; do

		if [ -z "${location}" ]; then
			continue
		fi

		case "${kind}" in
			INLINE)
				report "${location} 表格单元格里有多个分点没有换行：${sample}(每个分点编号并用 <br> 换行,如 1. 弹确认框<br>2. 确认后删除;check.sh --fix 可自动改写)"
				;;
			LIMIT)
				report "${location} 表格单元格有 ${count} 个分点，超过 ${MAX_TABLE_POINTS} 个：${sample}(改成表格下方的编号列表,表格里只留一句概括)"
				;;
			FIXED)
				echo "  [OK] 已改写 ${location} 的 ${count} 个分点"
				;;
		esac

	done <<< "${findings}"
}

# 检查七：README 必须声明三个版本状态
check_version_states() {
	echo "[8/${TOTAL_STEPS}] 检查版本状态声明..."

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
	echo "[9/${TOTAL_STEPS}] 检查任务与交互规格..."

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
				report "${task_file} 有 ${task_count} 个任务，但交互规格里只有 ${field_count} 处 \"${field}\" 字段"
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

# 检查八之二：已定义任务的页面不能还挂着未实现占位
# data-todo 是原型分批做时的中间态提示，任务都写进 tasks.md 了页面就该真做出来
check_todo_leftovers() {
	local doc defined leftover value

	while IFS= read -r doc; do
		defined=$(grep -oE '^##[[:space:]]+Task-[0-9]+' "${doc}" | grep -oE 'Task-[0-9]+' | sort -u)

		if [ -z "${defined}" ]; then
			continue
		fi

		while IFS= read -r value; do

			if [ -z "${value}" ]; then
				continue
			fi

			if printf '%s\n' "${defined}" | grep -qx "${value}"; then
				leftover=$(grep -rl "data-todo=\"${value}\"" "$(dirname "${doc}")/prototype" 2>/dev/null | head -3 | tr '\n' ' ')
				report "${value} 已经写进 tasks.md，原型里却还挂着 data-todo 占位：${leftover}(交付前把页面真做出来并配 Mock 数据,PDF 里写尚未实现对开发没有价值)"
			fi

		done < <(grep -rhoE 'data-todo="Task-[0-9]+"' "$(dirname "${doc}")/prototype" 2>/dev/null | grep -oE 'Task-[0-9]+' | sort -u)

	done < <(find "${PRD_ROOT}" -type f -name 'tasks.md' 2>/dev/null)
}

# 检查九：角色与术语的交叉引用
# prd.md 与 tasks.md 里出现的角色称谓，必须在 product.md 的角色表里存在。
# 角色表与正文相隔几百行，这类不一致靠人工评审很难发现，交给脚本。
# 用 python3 做中文分词判定：grep -E 没有中文词边界，会把"一人一岗"切成"一岗"误报。
check_cross_reference() {
	echo "[10/${TOTAL_STEPS}] 检查角色与术语交叉引用..."

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
# "岗"不在其列：岗位名在 product.md 角色表中本就全量列出，且"一人一岗"、"按岗配置"
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
    这样"请联系数据与系统管理员"与其简称"管理员"都能通过，
    前提是该简称已在 product.md 角色表中声明。"""
    return any(word[i:] in defined for i in range(len(word)))

problems = []
docs = sorted(set(glob.glob(os.path.join(root, '**', 'prd.md'), recursive=True) +
                  glob.glob(os.path.join(root, '**', 'tasks.md'), recursive=True)))
ignore_mark = os.environ.get('IGNORE_MARK', '')

for doc in docs:
    lines = open(doc, encoding='utf-8').read().splitlines()
    # 写了豁免标记的行跳过，用于放行泛指的"负责人"这类词
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

# 检查十一：骨架复制后没替换的 [待填]
# 结构检查全绿不代表内容已经写了，骨架的每个待填位置都带固定前缀，靠它拦住没写完就交付
check_fill_placeholders() {
	echo "[11/${TOTAL_STEPS}] 检查 [待填] 残留..."

	local hit
	while IFS= read -r hit; do
		report "${hit} 还留着 ${FILL_MARK} 占位(骨架复制后要逐项替换成真实内容,不适用的整节删掉或写暂无)"
	done < <(grep -rnF --include='*.md' --include='*.html' --exclude-dir=export --exclude-dir=node_modules -- "${FILL_MARK}" "${PRD_ROOT}" 2>/dev/null | cut -d: -f1,2)
}

# 检查十二：product.md 声明产品形态与移动端适配
# 原型覆盖表与截图视口都按形态区分，形态不写清，后面的截图校验无从判断
check_product_form() {
	echo "[12/${TOTAL_STEPS}] 检查产品形态声明..."

	local product="${PRD_ROOT}/product.md"

	if [ ! -f "${product}" ]; then
		return
	fi

	if ! grep -qx '## 产品形态' "${product}"; then
		report "${product} 缺少\"产品形态\"一节(固定两行：- 形态：${ALLOWED_FORMS} 之一或多个，- 移动端适配：是 / 否 / 不适用)"
		return
	fi

	local form_line adapt_line
	form_line=$(grep -m1 '^- 形态：' "${product}" || true)
	adapt_line=$(grep -m1 '^- 移动端适配：' "${product}" || true)

	if [ -z "${form_line}" ]; then
		report "${product} 的产品形态一节缺少\"- 形态：\"一行"
	fi

	if [ -z "${adapt_line}" ]; then
		report "${product} 的产品形态一节缺少\"- 移动端适配：\"一行"
	fi

	if [ -z "${form_line}" ] || [ -z "${adapt_line}" ]; then
		return
	fi

	# 还是骨架占位时只由待填检查报，不重复报取值非法
	if printf '%s\n%s\n' "${form_line}" "${adapt_line}" | grep -qF -- "${FILL_MARK}"; then
		return
	fi

	local form has_mobile_app=0
	while IFS= read -r form; do

		case "${form}" in
			"后台管理系统" | "Web 应用")
				HAS_WEB_FORM=1
				;;
			"App" | "小程序")
				has_mobile_app=1
				;;
			*)
				report "${product} 的形态取值不合法：${form}(可选 ${ALLOWED_FORMS}，多种形态用顿号分隔)"
				;;
		esac
	done < <(printf '%s\n' "${form_line#- 形态：}" | awk -F'、' '{ for (i = 1; i <= NF; i++) { gsub(/^ +| +$/, "", $i); print $i } }')

	MOBILE_ADAPT="${adapt_line#- 移动端适配：}"

	case "${MOBILE_ADAPT}" in
		"是" | "否" | "不适用")
			;;
		*)
			report "${product} 的移动端适配取值不合法：${MOBILE_ADAPT}(可选 是 / 否 / 不适用)"
			return
			;;
	esac

	if [ "${HAS_WEB_FORM}" -eq 1 ] && [ "${MOBILE_ADAPT}" = "不适用" ]; then
		report "${product} 的形态含后台管理系统或 Web 应用，移动端适配要写是或否"
	fi

	if [ "${HAS_WEB_FORM}" -eq 0 ] && [ "${has_mobile_app}" -eq 1 ]; then
		ONLY_MOBILE_FORMS=1

		if [ "${MOBILE_ADAPT}" != "不适用" ]; then
			report "${product} 的形态只含 App 或小程序，移动端适配写不适用"
		fi
	fi
}

# 从单层 JSON 清单里取一个字符串字段，没有时输出空串
json_string_field() {
	local file="$1"
	local field="$2"

	grep -oE "\"${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "${file}" | head -1 | sed -E 's/.*"([^"]*)"$/\1/'
}

# 检查十三：截图视口与产品形态一致，适配移动端时每张桌面截图都有手机截图
# 手机端布局与桌面不同，只截桌面等于移动端没有设计，开发只能自己猜
check_viewports() {
	echo "[13/${TOTAL_STEPS}] 检查截图视口与移动端配对..."

	local spec name viewport page mobile_spec mobile_viewport mobile_page
	while IFS= read -r spec; do
		name=$(basename "${spec}" .json)
		viewport=$(json_string_field "${spec}" "viewport")
		viewport="${viewport:-desktop}"

		case "${viewport}" in
			"desktop" | "mobile")
				;;
			*)
				report "${spec} 的 viewport 取值不合法：${viewport}(可选 desktop / mobile)"
				continue
				;;
		esac

		if [ "${ONLY_MOBILE_FORMS}" -eq 1 ] && [ "${viewport}" != "mobile" ]; then
			report "${spec} 用了 ${viewport} 视口，但产品形态只含 App 或小程序(截图清单写 \"viewport\": \"mobile\")"
		fi

		# 只有 Web 类形态且适配移动端时，桌面截图才需要配手机截图
		if [ "${viewport}" != "desktop" ] || [ "${HAS_WEB_FORM}" -ne 1 ] || [ "${MOBILE_ADAPT}" != "是" ]; then
			continue
		fi

		mobile_spec="$(dirname "${spec}")/${name}${MOBILE_SHOT_SUFFIX}.json"

		if [ ! -f "${mobile_spec}" ]; then
			report "${spec} 缺少手机端截图清单 $(basename "${mobile_spec}")(产品声明了适配移动端，两端都要截图并逐元素标注)"
			continue
		fi

		mobile_viewport=$(json_string_field "${mobile_spec}" "viewport")

		if [ "${mobile_viewport}" != "mobile" ]; then
			report "${mobile_spec} 要写 \"viewport\": \"mobile\""
		fi

		page=$(json_string_field "${spec}" "page")
		mobile_page=$(json_string_field "${mobile_spec}" "page")

		if [ "${page}" != "${mobile_page}" ]; then
			report "${mobile_spec} 的 page 与桌面截图不同：${mobile_page:-未写}，应为 ${page}"
		fi

		if [ -f "$(dirname "${spec}")/${name}.marks.json" ] && [ ! -f "$(dirname "${spec}")/${name}${MOBILE_SHOT_SUFFIX}.marks.json" ]; then
			report "$(dirname "${spec}")/${name}.marks.json 缺少手机端标注清单 ${name}${MOBILE_SHOT_SUFFIX}.marks.json"
		fi

	done < <(find "${PRD_ROOT}" -type f -path '*/diagrams/*' -name '*.json' ! -name '*.marks.json' ! -name '_coords.json' 2>/dev/null | sort)
}

if [ ! -d "${PRD_ROOT}" ]; then
	echo "[NG] 找不到 PRD 目录：${PRD_ROOT}"
	echo "用法: check.sh [--fix] [PRD 根目录]  缺省为 docs/prd，--fix 自动改写表格里没换行的分点并清空标记块里的旧标注图"
	exit 2
fi

echo "=== charles-prd 结构校验 ==="
echo "校验目录：${PRD_ROOT}"
echo "校验范围：${LINT_SCOPE}"

# 每项检查结束打印耗时，大文档跑几十秒时能看出在哪一步，不会像卡死
run_step() {
	local started_at="${SECONDS}"

	"$1"
	echo "  耗时 $((SECONDS - started_at)) 秒"
}

for step in \
	check_required_files \
	check_version_dirs \
	check_version_docs \
	check_prd_sections \
	check_requirement_ids \
	check_diagram_notes \
	check_annotations \
	check_version_states \
	check_tasks \
	check_todo_leftovers \
	check_cross_reference \
	check_fill_placeholders \
	check_product_form \
	check_viewports \
	check_confirmation_records \
	check_prototype_sources \
	check_table_points; do
	run_step "${step}"
done

echo "==============================="

if [ "${VIOLATIONS}" -gt 0 ]; then
	echo "[NG] 发现 ${VIOLATIONS} 处结构问题，请修正后再交付。"
	exit 1
fi

echo "[OK] 结构校验通过。"
exit 0
