#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""从 ms.trime.yaml 生成 my.trime.yaml。

my.trime.yaml = ms.trime.yaml + 最上面一排修饰键（Ctrl / Win / Alt），
专供需要 Alt/Win 快捷键的场景（比如 Obsidian 移动版的 Alt 快捷键）。
日常只改 ms.trime.yaml，改完跑一次本脚本，再在「键盘样式」里切到「全键」。

用法：
    python 生成my布局.py
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SRC = ROOT / "ms.trime.yaml"
DST = ROOT / "my.trime.yaml"

EXTRA_ROW = """      # ↓↓↓ 仅 my 版：额外一排修饰键，三等分占满整行（改 ms.trime.yaml 请勿改这里）
      - { click: Ctrl_L2, label: "Ctrl", width: 34 }
      - { click: Tab_L, label: "Tab", width: 33 }
      - { click: Alt_L2, label: "Alt", width: 33 }
"""

TAB_PRESET = '  Tab_L: { label: Tab, preview: "⇥", functional: false, send: Tab }\n'
ALT_ANCHOR = '  Alt_L2: { label: Alt, preview: "⌥", functional: false, send: Alt_L }\n'
ROW1_ANCHOR = "- { click: q, "
NAME_OLD = "name: 魔裁 "
NAME_NEW = "name: 全键 "


def die(msg: str) -> None:
    print(f"错误：{msg}")
    sys.exit(1)


def main() -> None:
    if not SRC.exists():
        die(f"找不到 {SRC.name}")

    text = SRC.read_text(encoding="utf-8")

    # 1. 主题名（「键盘样式」列表里显示的名字）
    if NAME_OLD in text:
        text = text.replace(NAME_OLD, NAME_NEW, 1)
    elif NAME_NEW not in text:
        die("没找到主题名那一行（name: 魔裁）")

    # 2. Tab 键预设（原来这里是 Win_L2，同文把 Meta 送成 229，WebView 认不出来，改成 Tab）
    if "Tab_L:" not in text:
        if ALT_ANCHOR not in text:
            die("没找到 Alt_L2 预设，无法插入 Tab_L")
        text = text.replace(ALT_ANCHOR, ALT_ANCHOR + TAB_PRESET, 1)

    # 3. 一排变五行：每行高度 40 -> 32，键盘总高度不变，底排才不会被切掉
    hdr_old = "    width: 10\n    height: 40\n"
    hdr_new = "    width: 10\n    height: 32\n"
    if hdr_old not in text:
        die("没找到 default 键盘的 width: 10 / height: 40")
    text = text.replace(hdr_old, hdr_new, 1)

    # 4. 键盘整体高度要跟着加（锁定值 230 -> 290），否则五排会被切掉
    if "keyboard_height: 230" not in text:
        die("没找到 keyboard_height: 230")
    text = text.replace("keyboard_height: 230", "keyboard_height: 290", 1)

    # 5. 在第一行 QWERTY 之前插入修饰键那一排
    lines = text.split("\n")
    if EXTRA_ROW.split("\n")[1] in text:
        die("源文件里已经有额外那一排了（ms.trime.yaml 不该带它）")
    for i, line in enumerate(lines):
        if ROW1_ANCHOR in line:
            lines.insert(i, EXTRA_ROW.rstrip("\n"))
            break
    else:
        die("没找到第一行 q 键，无法插入额外一排")

    out = "\n".join(lines)
    if not out.endswith("\n"):
        out += "\n"

    for _ in range(60):
        try:
            DST.write_text(out, encoding="utf-8", newline="\n")
            break
        except OSError:
            import time

            time.sleep(0.5)
    else:
        die(f"写不进 {DST.name}（文件被占用？）")

    rows = sum(1 for ln in out.split("\n") if ln.strip().startswith("- { click:") or ln.strip().startswith("- { width:"))
    print(f"已生成 {DST.name}：{len(out.encode('utf-8'))} 字节，比源文件多一排 Ctrl/Tab/Alt")
    print("在「键盘样式」里切到「全键」即可；日常仍用「魔裁」。")


if __name__ == "__main__":
    main()
