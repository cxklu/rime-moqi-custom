#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""从 ms.trime.yaml 生成 my.trime.yaml。

my.trime.yaml = ms.trime.yaml + 底部一排修饰键（Ctrl / Tab / Alt，33/34/33 三等分、压矮），
专供需要 Alt/Tab 的场景（比如 Obsidian 移动版的 Alt 快捷键）。
第二格原本是 Win：实测只在英文状态生效（中文态要先出候选、拿不到 Meta 组合），
作用有限，2026-10-24 换成更常用的 Tab。
这一排 2026-10-25 从「字母区最上面」挪到「键盘最下面」（和光标区的长条返回同一个位置）。
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

# 底部修饰键那一排：33/34/33 占满整行，height 16 让它比字母行（32）矮一大截。
# 行高是相对权重，压矮这一排，剩下的空间会自动分给上面几行，键盘总高（keyboard_height）不变。
MOD_ROW = """      # ↓↓↓ 仅 my 版：底部一排修饰键（Ctrl / Tab / Alt），33/34/33 三等分、压矮（改 ms.trime.yaml 请勿改这里）
      - { click: Ctrl_L2, label: "Ctrl", width: 33, height: 16 }
      - { click: Tab_L, label: "Tab", width: 34, height: 16 }
      - { click: Alt_L2, label: "Alt", width: 33, height: 16 }
"""

# default 键盘最后一排 Enter 键的收尾，用来定位「键盘最下面」
ENTER_TAIL = """          label_symbol: "设置",
          width: 14,
          key_back_color: bc4,
          key_text_color: tc4,
        }
"""

TAB_PRESET = '  Tab_L: { label: Tab, preview: "⇥", functional: false, send: Tab }\n'
ALT_ANCHOR = '  Alt_L2: { label: Alt, preview: "⌥", functional: false, send: Alt_L }\n'
NAME_OLD = "name: 魔裁 "
NAME_NEW = "name: 全键 "
MOD_ROW_MARK = "- { click: Ctrl_L2, label: \"Ctrl\", width: 33"


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

    # 2. Tab 键预设（原来这里是 Win_L2；Win 只在英文态能用、价值不大，换成 Tab）
    if "Tab_L:" not in text:
        if ALT_ANCHOR not in text:
            die("没找到 Alt_L2 预设，无法插入 Tab_L")
        text = text.replace(ALT_ANCHOR, ALT_ANCHOR + TAB_PRESET, 1)

    # 3. 五行变六行：每行高度 40 -> 32，键盘总高度跟着加，底排才不会被切掉
    hdr_old = "    width: 10\n    height: 40\n"
    hdr_new = "    width: 10\n    height: 32\n"
    if hdr_old not in text:
        die("没找到 default 键盘的 width: 10 / height: 40")
    text = text.replace(hdr_old, hdr_new, 1)

    # 4. 键盘整体高度要跟着加（锁定值 230 -> 290），否则多出来的一排会被切掉
    if "keyboard_height: 230" not in text:
        die("没找到 keyboard_height: 230")
    text = text.replace("keyboard_height: 230", "keyboard_height: 290", 1)

    # 5. 在 default 键盘最后（Enter 键之后、下一个键盘之前）追加底部修饰键那一排
    if MOD_ROW_MARK in text:
        die("源文件里已经有底部修饰键那一排了（ms.trime.yaml 不该带它）")
    if ENTER_TAIL not in text:
        die("没找到 default 键盘最后那个 Enter 键，无法定位底部")
    text = text.replace(ENTER_TAIL, ENTER_TAIL + "\n" + MOD_ROW.rstrip("\n") + "\n", 1)

    if not text.endswith("\n"):
        text += "\n"

    for _ in range(60):
        try:
            DST.write_text(text, encoding="utf-8", newline="\n")
            break
        except OSError:
            import time

            time.sleep(0.5)
    else:
        die(f"写不进 {DST.name}（文件被占用？）")

    print(f"已生成 {DST.name}：{len(text.encode('utf-8'))} 字节，底部多一排 Ctrl/Tab/Alt（33/34/33，height 16）")
    print("在「键盘样式」里切到「全键」即可；日常仍用「魔裁」。")


if __name__ == "__main__":
    main()
