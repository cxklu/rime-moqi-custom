"""
生成super4.py

从 custom_phrase/custom_phrase_super_4jian_no_conflict.txt 生成 super4.dict.yaml。

为什么要两个文件：
  输入用 txt（table_translator 的 user_dict，改完重启算法服务即生效），
  反查用 yaml（dictionary: super4，部署时编译成 build/super4.reverse.bin，
  四字词才能被 reverse_lookup_filter@fourjian 反查出来）。
  两边必须一一对应，所以改了 txt 就跑一次本脚本。

用法：python 生成super4.py
"""
import os
import re
from datetime import date

RIME = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(RIME, "custom_phrase", "custom_phrase_super_4jian_no_conflict.txt")
DST = os.path.join(RIME, "super4.dict.yaml")

HEADER_MARKS = ("---", "...", "name:", "version:", "sort:", "use_")


def read_old_version() -> str | None:
    """读出现有 super4.dict.yaml 里的 version 日期，没有就返回 None"""
    if not os.path.isfile(DST):
        return None
    try:
        with open(DST, "r", encoding="utf-8") as f:
            for line in f:
                m = re.match(r'^version:\s*"?([0-9]{4}-[0-9]{2}-[0-9]{2})"?', line)
                if m:
                    return m.group(1)
    except OSError:
        pass
    return None


def main():
    if not os.path.isfile(SRC):
        print(f"[X] 未找到源文件：{SRC}")
        return

    entries = []
    with open(SRC, "r", encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            if any(line.startswith(m) for m in HEADER_MARKS):
                continue
            if "\t" not in line:          # 只有词、没有码的行没法做反查
                continue
            word, code = line.split("\t")[:2]
            word, code = word.strip(), code.strip()
            if word and code:
                entries.append(f"{word}\t{code}")

    if not entries:
        print("[!] 没有解析到任何词条，未写出文件。")
        return

    # 词条没变就沿用旧日期，避免「重新跑一次脚本」也产生 git 改动
    old_version = read_old_version()
    old_entries = []
    if old_version and os.path.isfile(DST):
        with open(DST, "r", encoding="utf-8") as f:
            for line in f:
                line = line.rstrip("\n")
                if not line.strip() or line.lstrip().startswith("#"):
                    continue
                if any(line.startswith(m) for m in HEADER_MARKS):
                    continue
                if "\t" in line:
                    old_entries.append(line.rstrip())

    version = old_version if old_entries == entries else date.today().isoformat()

    lines = [
        "# 四字词 4 码（反查专用）",
        "# 由 custom_phrase/custom_phrase_super_4jian_no_conflict.txt 生成，两边保持一一对应",
        "# 只给 moqi.yaml 的 reverse_lookup_filter@fourjian 做反查用，不参与输入",
        "# （输入仍由 table_translator@custom_phrase_super_4jian_no_conflict 读那个 txt）",
        "# 改过 txt 之后重新生成：python 生成super4.py → 重新部署",
        "---",
        "name: super4",
        f'version: "{version}"',
        "sort: by_weight",
        "...",
        "",
    ]
    lines.extend(entries)
    lines.append("")

    with open(DST, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))

    note = "（词条未变，沿用原日期）" if version == old_version and old_entries == entries else ""
    print(f"[OK] 已写出 {len(entries)} 条 -> {DST} {note}")


if __name__ == "__main__":
    main()
