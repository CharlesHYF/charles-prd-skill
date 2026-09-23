#!/usr/bin/env bash
# 扫描 git 跟踪的文本文件里的禁用字符
# 创建日期：2026-09-23
# 修改日期：2026-09-23

set -uo pipefail

# 退出码：0 未发现，1 发现禁用字符，2 缺少 python3 未扫描
EXIT_CLEAN=0
EXIT_FOUND=1
EXIT_SKIPPED=2

SCAN_ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"

if ! command -v python3 > /dev/null 2>&1; then
	echo "  [SKIP] 未找到 python3，跳过禁用字符扫描"
	exit "${EXIT_SKIPPED}"
fi

SCAN_ROOT="${SCAN_ROOT}" EXIT_CLEAN="${EXIT_CLEAN}" EXIT_FOUND="${EXIT_FOUND}" python3 <<'PYSCAN'
import os, re, subprocess, sys

root = os.environ['SCAN_ROOT']

# 按码点区间列出禁用字符，脚本自身不含字面字符
FORBIDDEN_RANGES = [
    (0x2018, 0x2019),
    (0x201C, 0x201D),
    (0x300C, 0x300F),
    (0xFF02, 0xFF02),
    (0xFF07, 0xFF07),
    (0x2010, 0x2015),
    (0x2212, 0x2212),
    (0xFF0D, 0xFF0D),
    (0x2E3A, 0x2E3B),
    (0x2600, 0x27BF),
    (0x2B50, 0x2B50),
    (0x2B55, 0x2B55),
    (0xFE0F, 0xFE0F),
    (0x1F000, 0x1FAFF),
]
FORBIDDEN = re.compile('[' + ''.join(f'{re.escape(chr(low))}-{re.escape(chr(high))}' for low, high in FORBIDDEN_RANGES) + ']')
BINARY_SUFFIXES = ('.png', '.jpg', '.jpeg', '.gif', '.ico', '.pdf', '.woff', '.woff2')

listed = subprocess.run(['git', '-C', root, 'ls-files', '-z'], capture_output=True, check=True).stdout
hits = 0

for relative in filter(None, listed.decode('utf-8').split('\0')):
    path = os.path.join(root, relative)

    # 软链指向的目录与文件由其本体负责扫描
    if os.path.islink(path) or not os.path.isfile(path) or relative.lower().endswith(BINARY_SUFFIXES):
        continue

    try:
        text = open(path, encoding='utf-8').read()
    except UnicodeDecodeError:
        print(f'  [SKIP] 不是 UTF-8 文本，未扫描：{relative}')
        continue

    for number, line in enumerate(text.split('\n'), 1):
        for match in FORBIDDEN.finditer(line):
            print(f'  [FAIL] 禁用字符 U+{ord(match.group()):04X}：{relative}:{number}')
            hits += 1

sys.exit(int(os.environ['EXIT_FOUND']) if hits else int(os.environ['EXIT_CLEAN']))
PYSCAN
