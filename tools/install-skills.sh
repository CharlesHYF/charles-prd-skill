#!/usr/bin/env bash
# 把 skill 软链到指定工具的 skills 目录，改完开发仓即刻生效，不再需要逐处拷贝同步
# 创建日期：2026-09-21
# 修改日期：2026-09-21

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# 目标 skills 目录：缺省装到 Claude Code
TARGET="${1:-${HOME}/.claude/skills}"

# v3.x 的单 skill 形态目录名，重装前需要先清掉

if [ ! -d "${REPO_ROOT}/skills" ]; then
	echo "[NG] 找不到 skills 目录：${REPO_ROOT}/skills"
	exit 1
fi

mkdir -p "${TARGET}"
echo "=== 安装 charles-prd skills -> ${TARGET} ==="


LINKED=0

for skill_path in "${REPO_ROOT}"/skills/*/; do
	skill_name="$(basename "${skill_path%/}")"
	link_path="${TARGET}/${skill_name}"

	# 已有同名实体目录（非软链）时不覆盖，避免删掉别处装的同名 skill
	if [ -e "${link_path}" ] && [ ! -L "${link_path}" ]; then
		echo "  [SKIP] ${skill_name} 已存在同名实体目录，未覆盖"
		continue
	fi

	ln -sfn "${skill_path%/}" "${link_path}"
	echo "  [OK] ${skill_name}"
	LINKED=$((LINKED + 1))
done

echo "==============================="
echo "[OK] 已软链 ${LINKED} 个 skill。开发仓路径变动会导致软链失效，届时重跑本脚本即可。"
