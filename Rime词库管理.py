"""
Rime词库管理.py

管理两个自定义词库：
  1. custom_short  — 自定义短码（词\t编码\t权重）
  2. custom_extend — 自定义扩展词（词 或 词\t权重），自动生成小鹤辅码

使用方法：
  1. 编辑 custom_phrase/custom_short.txt 或 custom_phrase/custom_extend.txt
  2. 运行此脚本
  3. 重新部署 Rime

可在 Windows 和 Android (QPython) 双端使用。
"""
import os
import platform
import re
from datetime import date

try:
    from pypinyin import pinyin, Style as PyStyle
except ImportError:
    pinyin = None
    PyStyle = None

SYSTEM = platform.system()


def detect_rime_dir() -> str:
    """定位 Rime 配置目录

    优先级：环境变量 RIME_DIR > 本脚本所在目录 > 各平台默认路径。
    脚本本来就放在 Rime 目录里，所以绝大多数情况不需要任何配置；
    换电脑、换用户名、同文(Trime) 都不用改这里。
    """
    env = os.environ.get("RIME_DIR")
    if env and os.path.isdir(env):
        return env

    here = os.path.dirname(os.path.abspath(__file__))
    if os.path.isfile(os.path.join(here, "default.yaml")):
        return here

    if SYSTEM == "Windows":
        return os.path.join(os.environ.get("APPDATA", ""), "Rime")
    return "/storage/emulated/0/rime"  # Android (Trime / QPython)


RIME = detect_rime_dir()

# ============================================================
# 路径配置
# ============================================================
SHORT_SRC = f"{RIME}/custom_phrase/custom_short.txt"
SHORT_DST = f"{RIME}/cn_dicts_common/custom_short.dict.yaml"

EXTEND_SRC = f"{RIME}/custom_phrase/custom_extend.txt"
EXTEND_DST = f"{RIME}/cn_dicts_common/custom_extend.dict.yaml"

MORAN_CHARS = f"{RIME}/tools/moran.chars.dict.yaml"
FLYPYDZ = f"{RIME}/tools/flypydz.yaml"

EXTEND_DEFAULT_WEIGHT = 500000
HEADER_MARKS = {"---", "...", "name:", "version:", "sort:", "use_"}

# ============================================================
# 共享工具
# ============================================================

def read_file(path: str) -> str | None:
    """安全读取文件，不存在则返回 None"""
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    except FileNotFoundError:
        return None


def write_file(path: str, content: str) -> None:
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)


def build_yaml(name: str, entries: list[str]) -> str:
    lines = [
        "---",
        f"name: {name}",
        f"version: \"{date.today().isoformat()}\"",
        "sort: by_weight",
        "...",
        "",
    ]
    lines.extend(entries)
    lines.append("")
    return "\n".join(lines)


# ============================================================
# custom_short — 自定义短码
# ============================================================

def sync_short() -> int:
    """同步 custom_short.txt → custom_short.dict.yaml，返回词条数"""
    raw = read_file(SHORT_SRC)
    if raw is None:
        print(f"❌ 未找到源文件：{SHORT_SRC}")
        return 0

    entries = []
    for line in raw.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if "\t" not in stripped:
            continue
        entries.append(stripped)

    if not entries:
        print("⚠️  custom_short.txt 中没有有效词条，已跳过。")
        return 0

    content = build_yaml("custom_short", entries)
    write_file(SHORT_DST, content)
    return len(entries)


# ============================================================
# custom_extend — 自定义扩展词（自动辅码）
# ============================================================

def load_moran_shuangpin() -> dict[str, str]:
    """读取 moran.chars.dict.yaml，返回 {字: 双拼} 映射"""
    lookup = {}
    raw = read_file(MORAN_CHARS)
    if raw is None:
        print(f"⚠️  未找到墨奇码表：{MORAN_CHARS}")
        return lookup

    for line in raw.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if any(line.startswith(m) for m in HEADER_MARKS):
            continue
        m = re.match(r"^(\S+)\t([^;]+);", line)
        if m:
            char = m.group(1)
            sp = m.group(2)
            if char not in lookup:
                lookup[char] = sp
    return lookup


def load_flypy_fuzhuma() -> dict[str, str]:
    """读取 flypydz.yaml，返回 {字: 辅码} 映射"""
    sp_lookup = load_moran_shuangpin()
    lookup = {}
    raw = read_file(FLYPYDZ)
    if raw is None:
        print(f"⚠️  未找到小鹤码表：{FLYPYDZ}")
        return lookup

    for line in raw.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if any(line.startswith(m) for m in HEADER_MARKS):
            continue
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        char = parts[0]
        code = parts[1]
        if char in lookup:
            continue
        sp = sp_lookup.get(char)
        if sp and code.startswith(sp) and len(code) > len(sp):
            fz = code[len(sp):]
            lookup[char] = fz
        else:
            if len(code) >= 3:
                lookup[char] = code[-2:]
            elif len(code) >= 2:
                lookup[char] = code[-1:]
    return lookup


def get_pinyin_list(word: str) -> list[str]:
    if pinyin is None:
        return list(word)
    return [item[0] for item in pinyin(word, style=PyStyle.NORMAL)]


def build_extend_entry(word: str, weight: int,
                       fuzhu_lookup: dict[str, str],
                       raw_codes: str | None = None) -> str:
    if raw_codes:
        return f"{word}\t{raw_codes}\t{weight}"

    pinyins = get_pinyin_list(word)
    codes_parts = []
    for i, char in enumerate(word):
        py = pinyins[i] if i < len(pinyins) else ""
        fz = fuzhu_lookup.get(char, "")
        codes_parts.append(f"{py};{fz};" if fz else f"{py};;")
    codes = " ".join(codes_parts)
    return f"{word}\t{codes}\t{weight}"


def sync_extend() -> int:
    """同步 custom_extend.txt → custom_extend.dict.yaml，返回词条数"""
    raw = read_file(EXTEND_SRC)
    if raw is None:
        print(f"❌ 未找到源文件：{EXTEND_SRC}")
        return 0

    print("📖 加载小鹤辅码表...")
    fuzhu_lookup = load_flypy_fuzhuma()
    print(f"   ✅ 已加载 {len(fuzhu_lookup)} 个字符的辅码")

    entries = []
    for line in raw.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue

        parts = stripped.split("\t")

        if len(parts) >= 3:
            word, codes, weight_str = parts[0], parts[1], parts[2]
            try:
                weight = int(weight_str)
            except ValueError:
                weight = EXTEND_DEFAULT_WEIGHT
            entries.append(build_extend_entry(word, weight, fuzhu_lookup, raw_codes=codes))

        elif len(parts) == 2:
            word, weight_str = parts[0], parts[1]
            try:
                weight = int(weight_str)
            except ValueError:
                weight = EXTEND_DEFAULT_WEIGHT
            entries.append(build_extend_entry(word, weight, fuzhu_lookup))

        elif len(parts) == 1:
            word = parts[0]
            entries.append(build_extend_entry(word, EXTEND_DEFAULT_WEIGHT, fuzhu_lookup))

    if not entries:
        print("⚠️  custom_extend.txt 中没有有效词条，已跳过。")
        return 0

    content = build_yaml("custom_extend", entries)
    write_file(EXTEND_DST, content)
    return len(entries)


# ============================================================
# 主入口
# ============================================================

def main():
    print("=" * 40)
    print("  Rime 词库管理")
    print("=" * 40)

    print("\n--- custom_short（自定义短码）---")
    n_short = sync_short()
    if n_short > 0:
        print(f"  ✅ 已同步 {n_short} 条 → {SHORT_DST}")

    print("\n--- custom_extend（自定义扩展词）---")
    n_extend = sync_extend()
    if n_extend > 0:
        print(f"  ✅ 已同步 {n_extend} 条 → {EXTEND_DST}")

    total = n_short + n_extend
    print(f"\n{'=' * 40}")
    print(f"  共同步 {total} 条词库，请重新部署 Rime 生效")
    print(f"{'=' * 40}")


if __name__ == "__main__":
    main()