#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Rime词库排序.py  —— 给 custom_phrase/custom_short.txt 重新排序
================================================================

区块顺序（自上而下）：
  1. 英文区块    —— 以拉丁字母开头的条目，按 A-Z 排在一起
  2. 希腊区块    —— 以希腊字母开头的条目，排在一起（按希腊字母表顺序）
  3. 汉字区块    —— 以汉字开头的条目，按「首字母拼音 a-z」排在一起
  4. 单编码区块  —— 汉字开头、且编码只有 1 个字符的条目，按编码聚合排在一起
  5. 其他区块    —— 其余（数字、符号、假名等）

汉字区块内部排序键（保证「前两个汉字相同」的条目一定相邻）：
    ① 前两个汉字的拼音 → ② 词条长度（短在前）→ ③ 整词拼音 → ④ 编码 → ⑤ 原顺序
  例：沉没成本 / 沉没成本不参与重大决策 / …

「编码牵引」（可选，默认开）：
  若英文条目与某个汉字条目使用了完全相同的编码，则把该英文条目牵引到汉字
  条目的位置 —— 优先级高于「英文排在开头」。例：
      树莓派          ump
      Raspberry Pi    ump      ← 被牵引到「树莓派」旁边
      自造词          zzc
      custom_short.txt zzc     ← 被牵引到「自造词」旁边
  仅作用于编码长度 >= 2 的条目；单字母编码不参与，希腊字母不参与。

用法：
  python Rime词库排序.py                # 排序并写回（自动生成 .bak 备份）
  python Rime词库排序.py --dry-run      # 只预览统计，不写文件
  python Rime词库排序.py --check        # 检查当前是否已排好序
  python Rime词库排序.py -f 路径.txt    # 指定文件

拼音来源：cn_dicts/8105.dict.yaml（字 → 全拼，覆盖率 100%），
缺失字回退到 pypinyin（若已安装），再缺失则按字符码位排。
"""

import argparse
import os
import platform
import sys
from collections import defaultdict

# ==================================================================
# 配置区（想改行为就改这里）
# ==================================================================
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

DEFAULT_SRC = os.path.join(RIME, "custom_phrase", "custom_short.txt")
PY_DICT = os.path.join(RIME, "cn_dicts", "8105.dict.yaml")
BACKUP_SUFFIX = ".bak"

SINGLE_CODE_BLOCK = "back"     # 单编码区块位置："back"=汉字之后 / "front"=汉字之前 / "off"=不单独成块
PULL_ENGLISH_BY_CODE = True    # 同编码的英文条目牵引到汉字条目旁边
ADD_SECTION_HEADERS = True     # 在每个区块前插入 "## ===== 标题 ====="
MAKE_BACKUP = True             # 写回前生成 .bak

# ==================================================================
CAT_EN, CAT_GREEK, CAT_HAN, CAT_SINGLE, CAT_OTHER = 0, 1, 2, 3, 4

SECTION_TITLE = {
    CAT_EN: "英文（A-Z）",
    CAT_GREEK: "希腊字母",
    CAT_HAN: "汉字（首字母拼音 a-z）",
    CAT_SINGLE: "汉字·单编码（按编码聚合）",
    CAT_OTHER: "其他",
}

HDR_PREFIX = "## ===== "


def is_han(c: str) -> bool:
    o = ord(c)
    return (0x3400 <= o <= 0x9FFF) or (0xF900 <= o <= 0xFAFF) or (0x20000 <= o <= 0x2EBEF)


def is_greek(c: str) -> bool:
    o = ord(c)
    return (0x370 <= o <= 0x3FF) or (0x1F00 <= o <= 0x1FFF) or o == 0x2126


def is_latin(c: str) -> bool:
    return c.isascii() and c.isalpha()


# ==================================================================
# 拼音表
# ==================================================================
def load_pinyin(path: str) -> dict:
    """8105.dict.yaml 格式：字\\t拼音;辅码;辅码;...\\t权重

    多音字取「字频权重最高」的读音（表中权重已按主音/次音调过比）；
    权重相同时取拼音字母序靠后的（如 重 zhong > chong、行 xing > hang）。
    """
    cand = defaultdict(list)
    try:
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                if not line.strip() or line.startswith("#"):
                    continue
                parts = line.rstrip("\n").split("\t")
                if len(parts) < 2 or len(parts[0]) != 1:
                    continue
                ch, py = parts[0], parts[1].split(";")[0].strip()
                if not py:
                    continue
                try:
                    w = int(parts[2]) if len(parts) > 2 else 0
                except ValueError:
                    w = 0
                cand[ch].append((py, w))
    except FileNotFoundError:
        print(f"⚠️  未找到拼音表：{path}")

    return {ch: max(v, key=lambda t: (t[1], t[0]))[0] for ch, v in cand.items()}


def pypinyin_fallback(chars) -> dict:
    try:
        from pypinyin import lazy_pinyin
    except ImportError:
        return {}
    return {c: lazy_pinyin(c)[0] for c in chars if c}


# ==================================================================
# 条目
# ==================================================================
class Entry:
    __slots__ = ("raw", "word", "code", "prefix", "idx", "tokens", "cat", "key", "pulled")

    def __init__(self, raw, word, code, prefix, idx):
        self.raw = raw
        self.word = word
        self.code = code
        self.prefix = prefix
        self.idx = idx
        self.tokens = ()
        self.cat = CAT_OTHER
        self.key = ()
        self.pulled = False


def parse(text: str):
    """拆成 头部注释 / 条目 / 无效行"""
    header, entries, invalid = [], [], []
    pending = []

    for raw in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        s = raw.strip()
        if not s:
            continue
        if s.startswith("#"):
            if s.startswith(HDR_PREFIX):      # 上次生成的区块标题，丢弃重建
                continue
            if not entries and not invalid:
                header.append(s)
            else:
                pending.append(s)             # 文中注释跟着下一条词条走
            continue
        if "\t" not in s:
            invalid.append((s, pending))
            pending = []
            continue
        parts = s.split("\t")
        entries.append(Entry(s, parts[0], parts[1] if len(parts) > 1 else "", pending, len(entries)))
        pending = []

    if pending:
        invalid.append(("", pending))
    return header, entries, invalid


def build_keys(entries, table):
    """计算每条的排序键"""
    unknown = set()
    for e in entries:
        toks = []
        word = e.word
        for c in word:
            if is_han(c):
                py = table.get(c)
                if py is None:
                    unknown.add(c)
                    py = c
                toks.append(py)
            elif is_latin(c):
                toks.append(c.lower())
            else:
                toks.append(c)
        e.tokens = tuple(toks)

        head2 = e.tokens[:2]
        length = len(word)
        first = word[0] if word else ""

        if is_latin(first):
            e.cat = CAT_EN
        elif is_greek(first):
            e.cat = CAT_GREEK
        elif is_han(first):
            if SINGLE_CODE_BLOCK != "off" and len(e.code) == 1:
                e.cat = CAT_SINGLE
                e.key = (e.code.lower(), head2, length, e.tokens, e.code, e.idx)
            else:
                e.cat = CAT_HAN
        else:
            e.cat = CAT_OTHER

        if e.cat == CAT_HAN:
            e.key = (head2, length, e.tokens, 0, e.code, e.idx)
        elif e.cat == CAT_EN:
            e.key = (e.tokens, e.code, e.idx)
        elif e.cat == CAT_GREEK:
            e.key = (word, e.code, e.idx)
        elif e.cat == CAT_OTHER:
            e.key = (e.tokens, e.code, e.idx)
        # CAT_SINGLE 的键已在上面按「编码聚合」设好，不要覆盖

    return unknown


def pull_english_by_code(entries) -> int:
    """同编码的英文条目牵引到汉字条目位置，返回牵引条数"""
    if not PULL_ENGLISH_BY_CODE:
        return 0
    by_code = defaultdict(list)
    for e in entries:
        by_code[e.code].append(e)

    n = 0
    for code, group in by_code.items():
        if len(code) < 2:
            continue
        han = [e for e in group if e.cat == CAT_HAN]
        if not han:
            continue
        anchor = min(han, key=lambda e: e.key)
        for e in group:
            if e.cat != CAT_EN:
                continue
            e.cat, e.pulled = CAT_HAN, True
            e.key = anchor.key[:3] + (1, e.tokens, e.code, e.idx)
            n += 1
    return n


def block_order() -> list:
    order = [CAT_EN, CAT_GREEK]
    if SINGLE_CODE_BLOCK == "front":
        order += [CAT_SINGLE, CAT_HAN]
    else:
        order += [CAT_HAN, CAT_SINGLE]
    order.append(CAT_OTHER)
    return order


def render(header, entries, invalid) -> str:
    out = list(header)
    if out:
        out.append("")
    buckets = defaultdict(list)
    for e in entries:
        buckets[e.cat].append(e)

    for cat in block_order():
        block = sorted(buckets.get(cat, []), key=lambda e: e.key)
        if not block:
            continue
        if ADD_SECTION_HEADERS:
            out.append(f"{HDR_PREFIX}{SECTION_TITLE[cat]} =====")
        for e in block:
            out.extend(e.prefix)
            out.append(e.raw)
        out.append("")

    for s, pre in invalid:
        out.extend(pre)
        if s:
            out.append(s)

    while out and out[-1] == "":
        out.pop()
    return "\n".join(out) + "\n"


# ==================================================================
def sort_text(text: str):
    table = load_pinyin(PY_DICT)
    header, entries, invalid = parse(text)
    if not entries:
        return text, None

    unknown = build_keys(entries, table)
    if unknown:
        fb = pypinyin_fallback(unknown)
        if fb:
            table.update(fb)
            build_keys(entries, table)
            unknown = {c for c in unknown if c not in fb}

    n_pull = pull_english_by_code(entries)
    result = render(header, entries, invalid)

    seen = defaultdict(int)
    for e in entries:
        seen[(e.word, e.code)] += 1

    stat = {
        "total": len(entries),
        "blocks": {cat: sum(1 for e in entries if e.cat == cat) for cat in block_order()},
        "pulled": n_pull,
        "invalid": len(invalid),
        "unknown": sorted(unknown),
        "dup": sum(v - 1 for v in seen.values() if v > 1),
    }
    return result, stat


def main():
    ap = argparse.ArgumentParser(description="给 Rime custom_short.txt 排序")
    ap.add_argument("-f", "--file", default=DEFAULT_SRC, help="要排序的文件")
    ap.add_argument("--dry-run", action="store_true", help="只预览，不写文件")
    ap.add_argument("--check", action="store_true", help="检查是否已排好序")
    ap.add_argument("--no-backup", action="store_true", help="不生成 .bak 备份")
    args = ap.parse_args()

    src = args.file
    try:
        with open(src, "r", encoding="utf-8-sig", newline="") as f:
            original = f.read()
    except FileNotFoundError:
        print(f"❌ 未找到文件：{src}")
        sys.exit(1)

    with open(src, "rb") as f:
        crlf = b"\r\n" in f.read()

    result, stat = sort_text(original)
    if stat is None:
        print("⚠️  文件中没有有效词条，未做改动。")
        sys.exit(0)

    print("=" * 46)
    print("  Rime 词库排序")
    print("=" * 46)
    print(f"  文件：{src}")
    print(f"  词条：{stat['total']} 条")
    for cat in block_order():
        print(f"    · {SECTION_TITLE[cat]:<22} {stat['blocks'].get(cat, 0)}")
    print(f"  编码牵引：{stat['pulled']} 条")
    if stat["invalid"]:
        print(f"  ⚠️  无效行：{stat['invalid']} 行（已原样保留在末尾）")
    if stat["unknown"]:
        print(f"  ⚠️  缺拼音的汉字：{''.join(stat['unknown'])}")
    if stat["dup"]:
        print(f"  ⚠️  重复词条（词+编码相同）：{stat['dup']} 条")

    def norm(t):
        return [l for l in t.replace("\r\n", "\n").split("\n") if l.strip()]

    same = norm(original) == norm(result)

    if args.check:
        print(f"\n  {'✅ 已经是排好序的' if same else '❌ 尚未排序'}")
        sys.exit(0 if same else 1)

    if same:
        print("\n  ✅ 顺序无变化，无需写入。")
        return

    if args.dry_run:
        print("\n  --dry-run：未写入文件。")
        return

    if MAKE_BACKUP and not args.no_backup:
        bak = src + BACKUP_SUFFIX
        with open(bak, "w", encoding="utf-8", newline="") as f:
            f.write(original)
        print(f"\n  📦 已备份 → {bak}")

    with open(src, "w", encoding="utf-8", newline="\r\n" if crlf else "\n") as f:
        f.write(result)
    print(f"  ✅ 已写回 {src}")
    print("\n  提示：再运行 Rime词库管理.py 同步到 cn_dicts_common，然后重新部署。")


if __name__ == "__main__":
    main()
