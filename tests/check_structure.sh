#!/usr/bin/env bash
# 结构自检
# 创建日期：2026-09-21
# 修改日期：2026-09-23

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_ROOT}" || exit 1

# 主 skill：版本号以它的 metadata 为准，其余配置向它对齐
MAIN_SKILL="skills/charles-prd-standards/SKILL.md"

# 必须存在的顶层目录
REQUIRED_DIRS=(
	"skills"
	"templates"
	"tools"
	"tests"
)

# 声明了版本号、必须与主 skill 一致的配置文件
VERSION_FILES=(
	".claude-plugin/plugin.json"
	".claude-plugin/marketplace.json"
	".cursor-plugin/plugin.json"
	".codex-plugin/plugin.json"
	"gemini-extension.json"
)

# 链接检查跳过的占位目标（文档里用于举例，不指向真实文件）
LINK_PLACEHOLDERS='(^(url|path|link|#).*|xxx|<|\\{)'

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

echo "=== 结构自检 ==="

# 一、顶层目录齐全
for required_dir in "${REQUIRED_DIRS[@]}"; do

	if [ -d "${required_dir}" ]; then
		pass "顶层目录存在: ${required_dir}"
	else
		fail "缺少顶层目录: ${required_dir}"
	fi
done

# 二、每个 skill 目录都要有 SKILL.md，且 name 与目录名一致、description 非空
for skill_dir in skills/*/; do
	skill_name=$(basename "${skill_dir}")
	skill_file="${skill_dir}SKILL.md"

	if [ ! -f "${skill_file}" ]; then
		fail "${skill_dir} 缺少 SKILL.md"
		continue
	fi

	declared_name=$(grep -m1 '^name:' "${skill_file}" | sed 's/^name:[[:space:]]*//')

	if [ "${declared_name}" = "${skill_name}" ]; then
		pass "skill 名与目录一致: ${skill_name}"
	else
		fail "skill 名与目录不一致: 目录 ${skill_name}，声明 ${declared_name}"
	fi

	if grep -q '^description:[[:space:]]*.' "${skill_file}"; then
		pass "skill 有 description: ${skill_name}"
	else
		fail "skill 缺少 description: ${skill_name}"
	fi
done

# 二之二、每个 skill 目录必须自足：软链安装后仍能取到 tools 与 templates
# 没有这两个软链时，skill 文档里的工具与模板路径在安装点会全部失效
for skill_dir in skills/*/; do
	skill_name=$(basename "${skill_dir}")

	for linked in "tools" "templates"; do

		if [ -L "${skill_dir}${linked}" ] && [ -e "${skill_dir}${linked}" ]; then
			pass "skill 自足 ${linked}: ${skill_name}"
		else
			fail "${skill_name} 缺少可用的 ${linked} 软链(软链安装后将取不到工具与模板)"
		fi
	done
done

# 三、版本号：其余 skill 的 metadata 与各处配置都必须与主 skill 一致
MAIN_VERSION=$(grep -m1 '^[[:space:]]*version:' "${MAIN_SKILL}" | awk '{print $2}' | tr -d '"')

if [ -z "${MAIN_VERSION}" ]; then
	fail "${MAIN_SKILL} 未声明版本号"
else

	for skill_file in skills/*/SKILL.md; do

		if [ "${skill_file}" = "${MAIN_SKILL}" ]; then
			continue
		fi

		skill_version=$(grep -m1 '^[[:space:]]*version:' "${skill_file}" | awk '{print $2}' | tr -d '"')

		if [ "${skill_version}" = "${MAIN_VERSION}" ]; then
			pass "版本号一致 ${MAIN_VERSION}: ${skill_file}"
		else
			fail "版本号漂移: ${skill_file}=${skill_version:-未声明}，应为 ${MAIN_VERSION}"
		fi
	done

	for version_file in "${VERSION_FILES[@]}"; do

		if [ ! -f "${version_file}" ]; then
			fail "缺少配置文件: ${version_file}"
			continue
		fi

		file_version=$(grep -m1 '"version"' "${version_file}" | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')

		if [ "${file_version}" = "${MAIN_VERSION}" ]; then
			pass "版本号一致 ${MAIN_VERSION}: ${version_file}"
		else
			fail "版本号漂移: ${version_file}=${file_version}，应为 ${MAIN_VERSION}"
		fi
	done
fi

# 四、Markdown 内部链接可达
BROKEN_LINKS=""
LINK_COUNT=0

while IFS= read -r md_file; do
	md_dir=$(dirname "${md_file}")

	while IFS= read -r link; do

		if [ -z "${link}" ]; then
			continue
		fi

		case "${link}" in
			http*|mailto:*|'#'*)
				continue
				;;
		esac

		if printf '%s' "${link}" | grep -qE "${LINK_PLACEHOLDERS}"; then
			continue
		fi

		# 去掉锚点后判断目标是否存在
		target="${link%%#*}"

		if [ -z "${target}" ]; then
			continue
		fi

		LINK_COUNT=$((LINK_COUNT + 1))

		if [ ! -e "${md_dir}/${target}" ]; then
			BROKEN_LINKS="${BROKEN_LINKS}
	${md_file} -> ${link}"
		fi

	done < <(awk '/^```/ { infence = !infence; next } !infence { print }' "${md_file}" \
		| grep -oE '\]\([^)]+\)' | sed -E 's/^\]\(//; s/\)$//')

done < <(git ls-files '*.md' 2>/dev/null || find . -name '*.md' -not -path './.git/*')

if [ -z "${BROKEN_LINKS}" ]; then
	pass "Markdown 内部链接全部可达(共检查 ${LINK_COUNT} 条)"
else
	fail "存在死链:${BROKEN_LINKS}"
fi

echo "==============================="
echo "通过 ${PASS_COUNT} 项，失败 ${FAIL_COUNT} 项"

if [ "${FAIL_COUNT}" -gt 0 ]; then
	exit 1
fi

exit 0
