
基于 [墨奇音形](https://github.com/gaboolic/rime-shuangpin-fuzhuma)（作者 gaboolic）的个人配置。
本文只说**相对原版改了什么、这些改动怎么用**；如何安装、辅码怎么加，见原版仓库。

> 桌面端用**小狼毫**，安卓端用**同文 Trime**，两端共用同一套方案与词库。
> 安卓端多一个 `ms.trime.yaml`（主题与手势表），它只管键盘长什么样，与词库无关，桌面端不受影响。

## 一、改动的核心：两个 txt 词库

对双拼来说最缺的是**首字母简拼**：双拼由于编码利用率高、简码重码更多，商业输入法的双拼首字母简拼弱
（如全拼还能打 `zhrmghg`，双拼换成 `vhrmghg` 就基本打不出）。墨奇自带的 `custom_phrase/`
自带很多简拼，但**它没收录的词，你只能全码打**，也没法让它稳定排在前面。

所以本版补两张手写的表：

| 文件                                | 档位                     | 干什么                           |
| :-------------------------------- | :--------------------- | :---------------------------- |
| `custom_phrase/custom_extend.txt` | 主表 `10000`，词条 `500000` | **加词 / 调词频**：正常参与双拼、辅码与长句     |
| `custom_phrase/custom_short.txt`  | `50000`                | **自定义编码**：用自己定的短码打出词，不参与辅码和长句 |

两张表都**不学习、不上浮**：排第几、能不能打出，全由你自己写的那几行决定。效果是**简拼变得可控**——
不用再猜"这个词双拼能不能简拼出来、打不出是不是又得全码"。

例：

- `vhrm` + 空格 → 中华人民；`vhrm` + `；` → 中华人民共和国。
  全拼要打 `zhrmghg`，双拼基本打不出；现在它比全拼还短，而且没有过多重码，不用去按上排数字。
- 这类词放 `custom_short.txt`（不参与长句，只按你给的码出词）；
  真需要影响长句排序的才放 `custom_extend.txt`，代价见第四节。

## 二、两张表怎么写

### `custom_extend.txt`：加词与词频

一行一条，`#` 开头是注释，字段用 **Tab** 分隔：

```
词                              自动生成辅助码，权重 500000
词<Tab>600000                   自动生成辅助码，指定权重（数字越大越靠前）
码长<Tab>ma;um; chang;pn;<Tab>500000   手动指定读音（多音字）
```

- **只管写词**：辅助码由脚本按墨奇码表自动生成，不用自己算。
- **想调顺序**：`假期<Tab>500001` 就比默认的 500000 更靠前；也可以把系统词写进来专门压它。
- **多音字读错了**：先写好词、跑一次脚本，从生成的 yaml 里把那串码复制回 txt 改读音。
  每段是 `读音;辅码;`，例：`码长<Tab>ma;um; chang;pn;<Tab>500000`——
  `长` 默认会取成 `zhang`，这里显式写 `chang` 把它钉回来（`ma`=码、`chang`=长）。
- **别放单字**：见下。

改完三步缺一不可：

1. 编辑 `custom_phrase/custom_extend.txt`；
2. 运行 `Rime词库管理.py`（生成 `cn_dicts_common/custom_extend.dict.yaml`）；
3. **重新部署**。

```powershell
cd $env:APPDATA\Rime
python Rime词库管理.py
```

脚本会自己找位置，换电脑、换用户名都不用改路径。想双击运行就自己放个 bat（路径按环境改）：

```bat
@echo off
chcp 65001 >nul
"C:\scoop\apps\python\current\python.exe" "%APPDATA%\Rime\Rime词库管理.py"
pause >nul
```

> **`pypinyin` 必须先装**：`pip install pypinyin`。没有它脚本不会报错，而是退化成「把每个字本身当读音」
> （生成 `码;…; 长;…;` 这种），词库直接不可用——错的只是生成的 yaml，txt 不会被改动，装上再跑一遍就好。

#### 为什么不要放单字

`custom_extend.txt` 每条默认权重 500000，而单字系统本来就有：几万个同音字挤在同一个读音下，
一条 500000 会把这个字**硬顶到同音字第一位并锁死顺序**，既盖掉系统按词频排好的序列，
也影响整句输入时的选字。

想固定某个单字的显示或编码，用简码；或者在整句里给那个音节补辅码。

### `custom_short.txt`：自定义编码

- 一行一条，`词<Tab>你指定的码`；
- 只靠指定编码打出，**不参与辅码和长句**；
- **参与反查**：正常打出这个词，反查就会告诉你可以用什么码打。
  例：打 `vs hx rf mb` 得到「中华人民」，反查提示 `vhrm`，下次直接 `vhrm` 就够了；
  反过来 `还行其实<Tab>hxqu` 这种词，打 `hd xk qi uib` 上屏后反查同样给出 `hxqu`。
- 常见写法（固定短码、一简的扩展、大小写纠正、缩写打全称……）见该文件顶部的示例段。

> 四码以上的自定义编码会触发**自动上屏**，打长句时会很难受；多字短语用四码就够。
> 反查由 `lua/moqi/jianma_show.lua` 直接读这张表，所以改完**重启引擎**即可，不用跑脚本、也不用重新部署。

### `custom_phrase.txt`：置顶

档位最高，适合常用语、个人填词，以及「必须排第一」的词。

> 实际排到第一的只有 `custom_phrase.txt`；同目录另外几张 `custom_phrase_*`（`_3_code`、`_kf`、`_mqzg`、
> `_super_1/2/3jian`）档位都是 `-1`，和系统词重码时居后。想把其中常用的那些提到前面，
> 可以把那几行整段搬进 `custom_short.txt`——它是 `50000`，比系统词靠前，同样只要重启引擎。

## 三、候选顺序

同一串输入下，实际观察到的优先级（含配置文件里的 `initial_quality`）：

| 顺序 | 来源 | `initial_quality` |
| :-: | :-- | :-- |
| 1 | `custom_phrase.txt` | `100000` |
| 2 | `custom_short.txt` | `50000` |
| 3 | `custom_extend.txt`（经脚本并入主词表） | 主表 `10000`，词条自带 `500000` |
| 4 | 系统词（主词表 `moqi_wan.extended`） | `0` + 各词自带词频 |
| 5 | 简码、快符、字根等「让位」表 | `-1` |

> 为什么 `custom_extend.txt` 词条权重写到 50 万却排在 `custom_short.txt` 后面：候选排序的**权重不是简单比大小就能推断**，
> 各词库的基础分（`initial_quality`）与词条权重在不同词库里的换算方式并不一致。这张表只写「照着做就对」的结论。

两条实用规则：

- **跨词库抢第一靠「换词库」，不是把权重写大。** 同一个码在两个文件里都有时，上面那档赢。
  最典型的是 `冰箱`：它要压的 `本科学历` 在 `custom_short.txt` 里，所以 `冰箱` 得写进 `custom_phrase.txt`。
- **同一个词库内部，才靠自己那一列的权重。** 写 `假期<Tab>500001` 就比同文件默认的 `500000` 更靠前。

**固定词频**：`moqi.yaml` 里有 `__include: moqi:/octagram/disable`，语言模型被关掉。原版相邻字会影响候选顺序
（例：打 `kc` 本该「靠」在前，但上一个字是「不」时会变成「考」在前）；关掉后同一串输入永远同一顺序。

## 四、代价与边界

- **码长**：双拼本身是两键一个音节、上屏再一键，所以正常打字码长不会低于 2；**能低于 2 的是简码这条路**
  （`w`+空格＝我、`hx`+`，`＝好像这种）。简码的代价是你得自己往表里加、自己养。
- **长句**：墨奇本身的长句不弱，真正会削弱它的是 `custom_extend.txt` 用得越多。
  例子：`qi ui` 想让「歧视」排第一，写进 `custom_extend.txt` 可以做到，但 `hd xk qi ui` 的候选会变成「还行歧视」；
  给那个音节补个辅码就回来了：`hd xk qi uib` → 「还行其实」。所以长句不是没有，是要多花一点代价。
- **没有智能**：它不会猜你下一个词，也就不会被乱七八糟的联想干扰——上完屏就干净，顺带没有联想带来的隐私问题。
  这也是它和「模型加持的智能长句」两条路线的区别：一条是低码长、确定性、靠肌肉记忆，一条是让算法顺着上下文猜。

## 五、改完怎么生效

### 先分清两个目录（同文独有的坑）

| 目录 | 谁在用 | 内容 |
| :-- | :-- | :-- |
| `/storage/emulated/0/rime` | 外部存储那一份（**PC 的改动经 Syncthing 只到这里**） | `.stfolder` 在这 |
| `Android/data/com.osfans.trime/files/rime` | **同文自己真正读写的私有目录** | 多出 `build/`、`*.userdb`、`sync/<设备id>/` |

同文只读私有目录，所以 PC 改完要先「搬」过去——这个搬运是同文自己做的。
小狼毫没有这层：它只有一个 `%APPDATA%\Rime`，改哪个文件都直接是它在读的那个。

### 三个动作

| 动作（同文） | 干什么 |
| :-- | :-- |
| 工具栏 **同步** ↻ | 外部存储 → 私有目录搬运 + 合并词频快照；不重建 `build/`、不刷新 Lua 与方案 |
| ⋯ 菜单 **更新配置** | **不搬文件**，但文件已在私有目录时等价一次部署（所以日常用不上） |
| 设置页 **↺ 重新部署** | 搬文件 + 重建 `build/` + 刷新 Lua / 方案，对任何改动都生效，也最慢 |

「重新部署」不在工具栏上：**Enter 上滑 → 同文设置**，按设置页右上角的 ↺。

### 按改动类型选动作

| 改的东西 | 同文 | 小狼毫 |
| :-- | :-- | :-- |
| 任意 txt 词库（`custom_short` / `custom_phrase` / `custom_phrase_super_*`） | **同步** | **重启算法服务** |
| 主题 yaml（`ms.trime.yaml`） | **同步** | 重新部署 |
| lua 脚本（`aux_shift` / `super_tail` / `jianma_show` …） | **重新部署** | 重新部署 |
| 方案 yaml（`moqi.yaml`、`*.schema.yaml`）、`symbols_caps_v.yaml` | **重新部署** | 重新部署 |
| 新增 / 删除词库文件、改 `.dict.yaml` | **重新部署**（重建 `build/`） | 重新部署 |

两条补充：

- `custom_extend.txt` 是 txt，但它先生成 `cn_dicts_common/custom_extend.dict.yaml` 才生效：
  改完先跑 `Rime词库管理.py`，再按「重新部署」。
- 拿不准就「重新部署」——它对所有改动都成立，只是慢几秒。

如需多端同步可复用仓库里留的 `.stignore`。

### 反查

一二三简码与自定义编码（`custom_short` / `custom_phrase` / `custom_phrase_super_1~3jian`）的反查走 **Lua**
（`lua/moqi/jianma_show.lua`）：它在**启动时把 txt 读进内存**，所以改这些 txt 跟改普通词库一样——
同文按「同步」、小狼毫重启算法服务就生效，**不用重新部署**。

四字词是例外：走 `super4.dict.yaml`，部署时编译成二进制表（不占 Lua 内存、不拖慢启动）。
要改四字词：改 `custom_phrase/custom_phrase_super_4jian_no_conflict.txt`（`词<Tab>四码`）→
跑 `python 生成super4.py` → `super4.dict.yaml` → **重新部署**，两边必须一一对应。

> 全走 Lua 的代价是词一多就可能成为卡顿源——试过把四简码并进 Lua，明显变卡，所以四简码单独走 yaml。

### 工具栏

`ms.trime.yaml` 的 `tool_bar.buttons`（列表从右向左排），从左到右是：

| 按钮 | 图标 | 干什么 |
| :-- | :-- | :-- |
| ⋯ | `ic@dots_horizontal` | 打开菜单页（键盘样式 / 方案 / 更新配置 / 虚拟键盘 …） |
| **同步** | `ic@refresh` | 外部存储 → 私有目录搬运 + 合并词频快照（改 txt 词库或主题 yaml 时按这一下） |
| 中/En | 文本 | 中英切换 |
| I | `ic@cursor_text` | 移动光标 |
| 剪贴板 | `ic@clipboard` | 剪贴板 |
| 😊 | `ic@emoticon` | 表情 |
| ⌨ | `ic@keyboard_close` | 收起键盘 |

按钮只认 `action:` 一个字段（写 `preset_keys` 里的键名），换图标改 `foreground.style` 的 `ic@xxx`
（MDI 命名，映射成 `cmd_xxx`；不认识的名字会显示空白）。

## 六、其他改动

- 加「单引号三选」；超级简拼加入逗号上屏
- 关掉语言模型以固定词频（见第三节）
- 安卓端工具栏加一个 **「同步」** 键：外部存储 → 私有目录的搬运（含合并词频快照），用法见第五节
- 小狼毫用[薄荷输入法](https://github.com/Mintimate/oh-my-rime)的「蓝水鸭」皮肤
- 安卓端布局改自[魔裁 ms-trime](https://github.com/lost-42/ms-trime)

### 引导前缀改成大写 `Z` 开头（原本是小写 `a`）

方案里原本有一批 `a` 开头的引导：`aj` 日语、`aw` 英文、`ae` Emoji、`az` 部件组字、`ab` 笔画、
`ac` 自造词、`arj` 仓颉、`alf` 自然两分、`amq` 墨奇反查。它们是**整串吃掉**的——
正则一匹配，这串输入就交给对应模块，拼音翻译器看不到，于是 `a` 开头的简码全废：
`abaq`（安不安全）打不出、`acj` 被自造词吞掉、`ajs` 只能出日语的 さ。

现在统一挪到大写 `Z` 开头，小写 `a*` 简码完全恢复：

| 前缀 | 功能 | 例子 |
| :-- | :-- | :-- |
| `Zz` | 部件组字（部件拼音拼字） | `Zzhoho` → 炏 / 炎 |
| `Zlf` | 自然两分（自然码双拼的两码表） | `Zlfhoho` → 炎 / 炏 |
| `Zj` | 日语 | `Zjs` → さ |
| `Zw` | 英文 | `Zwhello` → hello |
| `Ze` | Emoji（按中文含义打） | `Zehaha` → 😄 |
| `Zcj` | 仓颉 | `Zcjfff` → 焱 |
| `Zb` | 笔画 | `Zb` + 笔画码 |
| `Zcy` | 自造词 | |
| `Zmq` | 墨奇反查 | |

- 前缀本身够独特，不需要再加分隔符。
- **短前缀会吃长前缀**：同一批 pattern 里 `Zc` 与 `Zcj` 并存时，输入 `Zc` 就先匹配 `Zc` 并一路吞，
  所以自造词用三位 `Zcy`。以后加新前缀也要避开前缀包含关系。
- 电脑 `Shift+Z`、手机 `▲+Z`，之后照常打小写。
- 大写开头有个通用代价（选候选的方式变少），见下一小节。

#### 「部件组字」和「自然两分」是两套表

两个都是“用字形拼字”，结果经常撞在一起（都能出 炎、炏），但**来源和编码方式不同**：

| | `Zz` 部件组字 | `Zlf` 自然两分 |
| :-- | :-- | :-- |
| 词表 | `radical_flypy.dict.yaml`（来自 mirtlecn/rime-radical-pinyin） | `zrlf.dict.yaml`（一份「两分」码表转成自然码双拼，版本 `20230830+5.0`） |
| 码怎么来 | 把每个**部件的读音**顺着打（词表里的码就是双拼形式，火 = `ho`）：火 + 火 → `hoho` | 取字的**首部件 + 末部件**，各按自然码双拼写：火 + 火 → `ho` + `ho` |
| 覆盖面 | 只收「能拆成部件表里有的部件」的字 | 只收「两分表里有」的字，表是从词库转的，缺字不少 |

所以会出现「组字能打、两分打不出」或反过来——不是谁坏了，是两张表的收字范围不一样。
日常就是**哪个打得出来用哪个**，不用记哪个“正统”。

### 大写开头的编码有什么代价

为了让「大写字母 + 数字」的写法能用（比如 `N2026` 输日期、`R100` 输金额大写），
输入法在组字缓冲里**一出现大写字母，就把数字键和 `;` `'` 从“选择候选”里摘掉**。

后果对大写开头的码一视同仁（`Z` 引导、`Zcy` 自造词、`N` 日期……）：

- 只能**空格**上屏第一个候选；
- 选第 2、第 3 个候选：**方向下键**挪到目标再空格，或者直接手指/鼠标点；
- `;`（次选）、`'`（三选）、上排数字选候选，统统失效。

能做的只有“少制造重码”：

- `custom_short.txt` 里同一个词可以多写几条码，常用那条给个不撞车的（`Weasel` 就用 `We`），就不用按方向键。
- 单字母的码（如 `W`）留着当“发现入口”：打一个 `W`，候选里就是 `Weasel`，右侧反查提示写着 `W We`——
  于是知道「Weasel 还能用 `We` 打」。**只打一个大写字母，就能看出这个词有哪些短码可能把它顶到候选第一。**
- `Z` 引导本身没法这么变通（它必须一个大写字母开头），只能接受「空格选第一个 / 方向键选后面的」。

## 七、安卓端布局：需要知道的几件事

主题 `ms.trime.yaml` 与词库无关，换布局不影响前面讲的加词流程。

**键面左上/右下那些小字是什么**：它们只是**提示文字**，不是自动生成的，来源有三种：

| 小字位置 | 由谁写 | 典型例子 | 对应哪个手势 |
| :-- | :-- | :-- | :-- |
| 数字（`Q`…`P` 上） | 预设键的 `label`（`1`…`0`） | `E` 上的 `3` | **长按 / 上滑** |
| 功能名（如「删段」「必应」「加粗」） | 键定义里的 `hint` | `D` 下的「删段」 | 通常是**下滑** |
| 符号（如 `Esc`、`（）`） | 键定义里的 `label_symbol`（符号槽） | `⌫` 上的 `Esc` | **上滑** |

所以"小字"不等于"下滑"：同一个键的小字可能对应长按、上滑或下滑，**以本表为准**。

| 键       | 手势              | 键名（`preset_keys` 里可改）                                  | 实际发出的键 / 效果                           |
| :------ | :-------------- | :----------------------------------------------------- | :------------------------------------ |
| `Q`…`P` | 长按 / 上滑         | `1`…`0`                                                | 数字                                    |
| `A`     | 长按 / 上滑         | `select_all`                                           | `Ctrl+A` 全选                           |
| `B`     | 下滑              | `CtrlB`                                                | `Ctrl+B`（Obsidian/Markdown 加粗）          |
| `C`     | 长按 / 上滑         | `copy`                                                 | `Ctrl+C` 复制                           |
| `D`     | 下滑              | `CtrlD`                                                | `Ctrl+D`（Obsidian 删除段落、浏览器加收藏夹，效果看应用） |
| `E`     | 下滑              | `CtrlE`                                                | `Ctrl+E` 翻译                           |
| `F`     | 下滑 / 长按·上滑      | `Bing` / `CtrlF`                                       | 用必应搜光标前的内容 / `Ctrl+F` 查找              |
| `H`     | 左滑 / 下滑 / 长按·上滑 | `HideSymbols` / `HideHints` / `CtrlH`                  | 收起·展开符号页 / 收起·展开注解 / `Ctrl+H` 替换      |
| `J`     | 下滑              | `CtrlJ`                                                | `Ctrl+J` 上屏反查                         |
| `L`     | 下滑              | `CtrlL`                                                | `Ctrl+L` 拆字                           |
| `O`     | 下滑              | `CtrlO`                                                | `Ctrl+O`（Obsidian 快速切换）               |
| `P`     | 下滑              | `CtrlP`                                                | `Ctrl+P` 拆字                           |
| `R`     | 下滑              | `RepeatCommit`                                         | 重复上屏刚打出的内容                            |
| `T`     | 下滑              | `Timestamp`                                            | 插入当前日期时间                              |
| `V`     | 长按·上滑 / 下滑      | `paste_clip` / `paste`                                 | 同文剪贴板直贴 / `Ctrl+V` 粘贴                 |
| `X`     | 长按 / 上滑         | `cut`                                                  | `Ctrl+X` 剪切                           |
| `N`     | 下滑              | `CtrlN`                                                | `Ctrl+N` 新建                           |
| `123`   | 上滑 / 长按         | `Symbols_panel` / 弹条 `[Symbols_panel, Color_switch]`   | 符号「常用」页 / 弹条「符号 · 换人」                 |
| 空格      | 长按·上滑 / 按住左右滑   | `Mode_switch` / `slide_cursor`                         | 中英切换 / 移动光标                           |
| `,` `/` | 长按              | `.` / `?`                                              | 句号 / 问号                               |
| `⌫`     | 上滑 / 下滑 / 长按    | `Escape` / `undo` / `BackSpace2`（`slide_delete`）       | Esc / 撤销 / 持续删，按住再左右滑是滑动删除            |
| 回车      | 上滑 / 长按         | `Settings` / 弹条 `[Settings, SysSettings, DevSettings]` | 同文设置 / 弹条三选项（松手＝同文设置，往左依次是系统设置、开发者选项） |

> 这张表要说清的是**键盘只是把那个快捷键发给当前应用**：写 `Ctrl+D` 就是发 `Ctrl+D`，
> 至于它删段落、加收藏夹还是什么都不做，全看应用自己怎么定义——输入法本身并不会"删段"。

**Move 区（光标控制）**：

| 键 | 键名 | 实际发出的键 / 效果 |
| :-- | :-- | :-- |
| `Home` / `End` | `Home` / `End` | 到行首 / 行尾 |
| `文首` / `文末` | `Doc_Home` / `Doc_End` | `Ctrl+Home` / `Ctrl+End`，到文档最前 / 最后 |
| `⇐` / `⇨`（`←` `→` 长按或上滑） | `Left1` / `Right1` | `Ctrl+←` / `Ctrl+→`，按词左右移动 |
| `⌫` 长按或上滑 | `CtrlBackspace` | `Ctrl+Backspace`，删一个词 |
| `Delete` 长按或上滑 | `DeleteCandidate` | `Ctrl+Delete`，也是删词 |
| `选择` | `Shift_L2` | 按住 Shift，配方向键就是选中文字 |

> 同理：删词就是给应用发 `Ctrl+Backspace` / `Ctrl+Delete`，应用认不认、删掉的是什么，由应用决定

### 几种 Shift 的区别

| 用法 | 效果 |
| :-- | :-- |
| ▲ 单击 | 只让下一个字母大写（临时） |
| ▲ 双击 / 上滑 | 大写锁定（再点一下取消）；两种状态同色，只能靠手势区分 |
| Move 区的「选择」键 | 等于按住 Shift，配方向键选中文字 |
| Shift + 辅码字母 | 给**第一个音节**补辅码：`vi ui` 时按住 Shift 再按 `c` → `vic ui` → 芝士 |

> **同文上 Shift+字母为什么一度用不了**：它的 Shift 是键盘层的「粘滞修饰键」，字母键在键盘层就被合成成了大写字母（修饰位是空的），librime 的 `Shift+C` 绑定匹配不到，按下只会得到 `vi uiC`。
> 本版用 `lua/aux_shift.lua` 在引擎侧补上了这条绑定，现在两端行为一致；改这个脚本后要**重新部署**。

### 同文的 Shift+Enter：在 Obsidian 表格里换行

- **桌面端的规矩**：Obsidian 表格里 `Enter` 是「跳下一行 / 往下新建一行」，`Shift+Enter` 才是**单元格内换行**。
- **同文为什么做不到**：这条软换行由应用自己处理，输入法只能发键。本版试过让引擎发 `Shift+Return`，
  Obsidian 安卓版仍然当普通回车处理——跳行。
- **本版的做法**：既然 markdown 表格的软换行写成 `<br>` 就等价，那就直接上屏它。
  `lua/shift_enter.lua` 收到 `Shift+Return` → `commit_text('<br>')`；手机上 **▲ + Enter** 即可，
  在阅读 / 实时预览里就是单元格内换行。
- **边界**：
  - 只对**手机上的同文**生效；小狼毫里按发行版名挡掉了，照旧是普通换行（否则电脑上打字也会冒出 `<br>`）。
  - 这是**全局**行为：任何输入框里 ▲+Enter 都会打出字面的 `<br>`（写在文件名里会被 Obsidian 拦下来）。
    不想要就去掉 `moqi.yaml` 的 `engine.processors` 里那行 `lua_processor@*shift_enter`，再**重新部署**。
  - 源码视图里看到的是 `<br>` 原文，这是 markdown 的固有表现，不是没生效。

## 鸣谢

- [墨奇音形](https://github.com/gaboolic/rime-shuangpin-fuzhuma) 作者 gaboolic —— 本配置全部基于它修改
- [薄荷输入法](https://github.com/Mintimate/oh-my-rime) —— 小狼毫「蓝水鸭」皮肤
- [魔裁 ms-trime](https://github.com/lost-42/ms-trime) —— 安卓端布局
- [白霜词库](https://github.com/gaboolic/rime-frost) / [雾凇拼音](https://github.com/iDvel/rime-ice) —— 词库与词频来源
- [同文 Trime](https://github.com/osfans/trime) —— 安卓端输入法平台
- [小狼毫 Weasel](https://github.com/rime/weasel) —— Windows 端输入法平台

---

## 关于本仓库（公开分享版）

本仓库是一份个人自用配置的公开镜像，由本地脚本从私人仓库生成：

- 涉及个人用词习惯的几个文件被替换成 **示例版**，只保留格式与用法；
- 个人笔记不随仓库发布；
- 其余方案文件与上游 [gaboolic/rime-moqi](https://github.com/gaboolic/rime-moqi) 保持一致。

被替换成示例版的 4 个文件：

| 文件 | 用途 |
| --- | --- |
| `custom_phrase/custom_phrase.txt` | 主自定义词表（`table_translator@custom_phrase`） |
| `custom_phrase/custom_short.txt` | 手写短码词表 |
| `custom_phrase/custom_extend.txt` | 扩展词源文件（脚本生成 `cn_dicts_common/custom_extend.dict.yaml`） |
| `symbols_caps_v.yaml` | 大写键符号表 |

### 三个本地脚本

| 脚本 | 作用 | 什么时候跑 |
| --- | --- | --- |
| `Rime词库管理.py` | `custom_phrase/custom_extend.txt` → `cn_dicts_common/custom_extend.dict.yaml`，自动补小鹤辅码 | 改过 `custom_extend.txt` 之后 |
| `生成super4.py` | `custom_phrase/custom_phrase_super_4jian_no_conflict.txt` → `super4.dict.yaml`（四字词反查表） | 改过那个 txt 之后 |
| `Rime词库排序.py` | 给 `custom_phrase/custom_short.txt` 重新排序（自动生成 `.bak` 备份） | 改过 `custom_short.txt` 之后 |

运行需要 Python 3.9+ 和 `pypinyin`：

```powershell
pip install pypinyin
python Rime词库管理.py
```

> `custom_extend.dict.yaml` 上游没有提供，所以本仓库附带的是按示例词表生成的一份结果。
> 你自己改完 `custom_extend.txt` 之后，**跑一遍 `Rime词库管理.py`**，再「重新部署」即可；
> 辅码表取自仓库自带的 `program/moran.chars.dict.yaml` 与 `program/flypydz.yaml`，不用另外下载。

### 部署

把本仓库内容放进 Rime 的用户目录（Windows 是 `%APPDATA%\Rime`），然后「重新部署」。
`squirrel` / `weasel` / `小狼毫` / `同文输入法` 的部署入口见方案正文。
