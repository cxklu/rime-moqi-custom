
基于 [墨奇音形](https://github.com/gaboolic/rime-shuangpin-fuzhuma)（作者 gaboolic）。

原版功能很全：固定词频、大量简拼、长句直接补辅码。这一版在原版基础上补的是**选词控制**：
让"哪个词占哪个码、谁排前面"由你写死，而不是由算法猜。

新增的两张词表：

- `custom_phrase/custom_short.txt` —— **自定义编码**，配套 `moqi.yaml:82` 的 `table_translator@custom_short`；
- `custom_phrase/custom_extend.txt` —— **加词与调词频**，配套 `moqi_wan.extended.dict.yaml:33` 的一行导入。

另外沿用原版就有的 `custom_phrase/custom_phrase.txt` 作最高一档固定表。

> 引导前缀、同文手势、Move 区等其他改动见第九节。

---

## 一、要解决什么

双拼有两处绕不开：

**1）重码。** 音码通病：同一个读音下几十个字，同一个码下一堆词。学习型词频在多数情况下确实好用——
越常用的越靠前，刚开始用不用配词表也很友好。它解决不了的是两件事：常用的词没问题，
**不常用的重码词得翻页**；动态排序还会把顺序改来改去，**破坏肌肉记忆**。

**2）首字母简拼弱。** 全拼下 `zhrmghg` 几乎必出「中华人民共和国」；双拼把 `z` 换成 `v` 之后，
基本没有商业输入法打得出来。所以普通双拼的 `bkxl` 其实**打不出「本科学历」**，只会出 `bing xiang` 对应的词。

原版能自己动手的有两处：

| 入口                        | 局限                                |
| :------------------------ | :-------------------------------- |
| `ac`（自造词，本版改成 `Zcy`）      | 学习型：权重在系统词之后，靠多打往上浮；也改不了系统词       |
| `custom_phrase.txt`（原版已有） | 只能整条固定"这个码出这个词"，档位虽高但**不参与辅码和长句** |

这一版的回答是两张新表：**自定义编码**（`custom_short.txt`）把简拼弱的短板补上，
**加词与调词频**（`custom_extend.txt`）把重码的排序补上；两张表都不学习、不上浮，写第几行就排第几。
重码兜底再借原版已有的 `custom_phrase.txt`（最高一档）。

---

## 二、能力与代价

**能力：想用什么码打出，就用什么码打出；想让谁排前面，谁就排前面。**

- 加词、改码、调频都是写一行 txt，不用动方案；
- **固定词频**：同一串输入永远同一顺序，不用赌它这次猜谁；
- 简码、辅码、长句三条路互不干扰，按每个词的实际用法自己挑一条。

**代价：纯手动。**

- 没有智能：不猜下一个词、不联想、不学你的习惯（上完屏就干净）；
- 没有纠错：打错了它不会记住，也不会自动上浮；
- 没有自动学习：想固定谁，就得自己写进去。

也就是说：**选词权从算法手里交到你手上，代价是这份权要自己维护。**

---

## 三、三张表，各管一段（两张新增 + 一张原版已有）

| 文件 | 来源 | 档位 | 干什么 | 参与辅码/长句 |
| :-- | :-- | :-- | :-- | :-- |
| `custom_phrase/custom_short.txt` | **新增** | `50000` | **自定义编码**：以三、四简码为主，相当于更自由的首字母简拼 | ✗ |
| `custom_phrase/custom_extend.txt` | **新增** | 主表 `10000` + 词条 `500000` | **加词与调词频**：正常参与双拼、辅码、长句 | ✓ |
| `custom_phrase/custom_phrase.txt` | 原版已有 | `100000` | **最高一档**：固定"这个码就出这个词"，专收被简码抢走的词 | ✗ |

挂进方案的位置：`custom_short` 在 `moqi.yaml:82` 与 `:194-200`（`initial_quality: 50000`）；
`custom_extend` 由 `moqi_wan.extended.dict.yaml:33` 导入，跟着主词表走。

三张表都**不学习、不上浮**：同一串输入永远同一顺序（方案里已经关掉语言模型）。

### `custom_short.txt`：自定义编码，位置最省

- 一行一条：`词<Tab>你指定的码`（可选第三列权重），`#` 开头是注释；
- 公开版里只放了几条示例，**需要自己在长期使用中积累**；这个文件能承担很多用法：调整单字词频，二三四简码、一简码的扩展、缩写打全称、各种自定义编码都可以塞进来；
- **不参与辅码和长句**，只按你写的码出词，所以干净、便宜（`50000`，排在系统词前面）；
- **参与反查**：用全码打出这个词，反查会告诉你能用哪个代码打。

一个实际用法（`vhrm` 同时给两个词）：

```
中华人民	vhrm
中华人民共和国	vhrm
```

`vhrm` + 空格 → 「中华人民」；`vhrm` + `；`（次选）→「中华人民共和国」。

适合：简码（`本科学历<Tab>bkxl`）、缩写打全称、扩展一简码）。

### `custom_extend.txt`：能加词、能调频，代价是会影响长句

- 一行一条，字段用 **Tab** 分隔：

  ```
  词                                自动生成辅助码，权重 500000
  词<Tab>600000                     自动生成辅助码，指定权重（数字越大越靠前）
  码长<Tab>ma;um; chang;pn;<Tab>500000   手动指定读音（多音字读错时用）
  ```

- **只管写词**，辅码由脚本按墨奇码表生成，不用自己算；**脚本目前只生成墨奇辅助码**，换别的辅助码方案要改脚本；
- 改完跑一次脚本生成 `cn_dicts_common/custom_extend.dict.yaml`，再重新部署；
- **别往里放单字**：一条 500000 会把那个字顶到同音字第一位并锁死顺序，整句选字都会受影响。

### `custom_phrase.txt`：最高一档

写进去就是第一位，**不用加权重**。适合"这个码就该出这个词"的固定，以及整组一简码的定序。
本版除个人信息外，还用它承担**让二字词压过四简码**这件事（`custom_short.txt` 那一档压不住四简码）。

它的代价是档位太高：同一个码上的条目靠第三列的权重排先后，加一条就得动一整组。
原版 `custom_phrase.txt` 里一简码 `u` 是这样定序的：

```
是	u	3
什么	u	2
是不是	u	1
```

想往 `u` 上加一个新短语，可能需要把这三条的权重一起重排。
同样的词放进 `custom_short.txt` 就不用动它们：那里天然低一档，只要在这个文件里调相对顺序。

---

## 四、三个真实场景，看清边界

### 1）简码抢了全码的位置

```
本科学历	bkxl        ← 在 custom_short.txt 里（三、四简码）
```

「冰箱」的码也是 `bkxl`，全码跟简码重码时**全码应该优先**。这时换一档更省事：

```
冰箱	bkxl            ← 在 custom_phrase.txt 里，不带第三列
```

`custom_phrase.txt` 的档位比 `custom_short.txt` 高，同一串码它直接赢，不用写任何权重。

代价：这个简码被"具体化"了——`bk` 和 `xl` 之间没有间隔，方案不再把它当两个音节，
所以停在这个候选上时不能按音移动、系统没有的词加不了辅码，也不能参与长句。**这是简码的天生代价。**

### 2）四码以上会直接上屏

```
链接	lmjpf       ← 在 custom_short.txt 里
```

写了一堆四码以上的自定义编码之后，打「连接符」`lm jp fu` 时 `lmjpf` 会直接把「链接」上屏，
只留个 `u`。所以：**多字短语用四码就够，别往四码以上堆。**

### 3）长句被加词影响

`custom_extend.txt` 用得越多，长句排序越受它影响。例子：想让「歧视」在 `qi ui` 里排第一，
写进 extend 可以做到，但 `hd xk qi ui` 的候选会变成「还行歧视」；给那个音节补个辅码就回来了：
`hd xk qi uib` → 「还行其实」。

**结论：能不影响长句的表达优先放 `custom_short.txt`；真要影响排序，才放 `custom_extend.txt`。**

---

## 五、学习成本：不需要一次掌握

它不是"先背一套码才能打字"的方案，而是想加就加、越用越顺：

| 阶段      | 你会做的事                            | 不会的时候                   |
| :------ | :------------------------------- | :---------------------- |
| 只用双拼    | 跟普通双拼一样打，只是词频固定、顺序稳定             | 完全可用，原版词库照打             |
| 开始加简码   | 常打的词写成三、四简码放进 `custom_short.txt` | 不加也能全码打，且有反查            |
| 学辅码     | 重码时补一个部首的首字母，候选立刻收敛              | 忘了就纯音打，多按一下候选而已         |
| 遇到不会打的字 | 拆字 / 笔画 / 反查（都有前缀）               | 反查是在"已经打出来"之后告诉你码，不学也能查 |

**重码是打着打着就会的**：同一个码反复出现的那几个词，会自然记住谁在前、要不要补辅码，
而不是先背一张表再用。反查的存在意味着：**可以从"我只会全码"开始，慢慢把常用词变成更短的码。**

---

## 六、候选顺序（照着做就对）

| 顺序 | 来源 | 基础分 |
| :-: | :-- | :-- |
| 1 | `custom_phrase.txt` | `100000` |
| 2 | `custom_short.txt` | `50000` |
| 3 | `custom_extend.txt`（并入主词表） | 主表 `10000`，词条 `500000` |
| 4 | 系统词 | `0` + 各词自带词频 |
| 5 | 简码/快符/字根等让位表 | `-1` |

两条实用规则：

- **跨词库抢第一靠"换档"，不是把权重写大。** 同一个码在两个文件里都有时，上面那档赢。
- **同一档内部，才靠自己那一列的权重。** 写 `假期<Tab>500001` 就比同文件默认的 `500000` 靠前。

> 为什么 extend 写到 50 万却仍排在 short 之后：各词库的基础分与词条权重的换算方式不一致，
> 不是简单比大小。这张表只给"照着做就对"的结论。

---

## 七、改完怎么生效（Windows / 安卓）

分两档：词表 txt 只要重启引擎，改 yaml / lua 才要重新部署——重建 `build/` 是慢的那一步。

| 改了什么 | 怎么生效 |
| :-- | :-- |
| 词表 txt：`custom_short.txt`、`custom_phrase.txt`、`custom_phrase_kf.txt` | 同文：工具栏 ⟳「同步」；小狼毫：重启算法服务 |
| `custom_extend.txt` | 先跑脚本生成 `custom_extend.dict.yaml`，再走下面「重新部署」 |
| 方案 yaml（`moqi.yaml` 等）、`symbols_caps_v.yaml`、`ms.trime.yaml`、`lua/` | 两端都要「重新部署」 |

### 只改了词表 txt

词表是运行时读的，不重建 `build/` 也能生效：

| 平台 | 操作 |
| :-- | :-- |
| 安卓（同文） | 键盘工具栏的 ⟳（同步） |
| Windows（小狼毫） | 重启算法服务（重开 `WeaselServer.exe`），**不用** `WeaselDeployer /deploy` |

同文的「同步」会把外部存储 `/storage/emulated/0/rime` 的改动搬进同文实际读写的私有目录，
再合并 `sync/<设备id>/` 下的词库快照（词频、输入习惯），然后重启引擎——PC 经 Syncthing 同步过来的改动就是靠它。

### `custom_extend.txt`：先跑脚本

它要先生成 `cn_dicts_common/custom_extend.dict.yaml`，否则改了不生效。

```powershell
cd $env:APPDATA\Rime
python Rime词库管理.py
```

不想开终端就建个 bat 放桌面双击（**把 python 路径换成自己的**）：

```bat
@echo off
chcp 65001 >nul

"C:\scoop\apps\python\current\python.exe" "%APPDATA%\Rime\Rime词库管理.py"

echo.
echo 请按任意键继续. . .
pause >nul
```

脚本依赖 `pypinyin`（`pip install pypinyin`）。没装不会报错，而是把每个字本身当读音，生成的词典不可用；txt 不会被改坏，装上再跑一遍即可。

生成出新的 `.dict.yaml` 属于「增改词库文件」，要重建 `build/`，所以跑完还得走下面的重新部署。

### 重新部署（改了 yaml / lua 才用）

| 平台 | 操作 |
| :-- | :-- |
| 安卓（同文） | 设置页 → **↺ 重新部署**（工具栏 ⟳ 不够，它不重建 `build/`） |
| Windows（小狼毫） | `WeaselDeployer.exe /deploy`，等 `build\weasel.yaml` 的 mtime 变了再重启 `WeaselServer.exe` |

同文这边：`⋯ → 更新配置` 也是一次部署，但它**不搬文件**；只改了外部目录时它看不到，得先同步。

## 八、适合谁

- 被纯音码的重码折磨，愿意为**确定性**花一点手工成本；
- 常用词里有大量系统词库收不到的专业词、人名、口语；
- 想要"固定词频 + 简码 + 辅码"这套组合，但不接受学习型词频的不可控。

---

## 九、其他改动

### 1）引导前缀：`a*` → `Z*`

原版用 `a` 开头的组合做引导，会和小写简码抢位置；这一版统一改成大写 `Z`，小写全部留给双拼和简拼。

| 功能 | 原版 | 本版 |
| :-- | :-- | :-- |
| 墨奇码反查 | `amq` | `Zmq` |
| 仓颉反查 | `arj` | `Zcj` |
| 笔画反查 | `ab` | `Zb` |
| 自然两分 | `alf` | `Zlf` |
| 拆字组字 | `az` | `Zz` |
| Emoji | `ae` | `Ze` |
| 英文 | `aw` | `Zw` |
| 日语 | `aj` | `Zj` |
| 自造词 | `ac` | `Zcy` |

自造词用三位 `Zcy`：两位的 `Zc` 会把 `Zcj`（仓颉）吃掉。

改的时候两处要一起动：`moqi.yaml` 里各翻译器的 `prefix:`，以及 `recognizer.patterns` 对应的正则。

### 2）补回 `cangjie5.schema.yaml`

上游只有 `cangjie5.dict.yaml`，没有配套的 `cangjie5.schema.yaml`，缺了它编译不出仓颉词典。
电脑端可能因为 `build/` 里有旧产物而看不出问题，手机重新部署后 `Zcj` 就直接打不出。本版把这个 schema 补回。

### 3）建议自定义的位置

| 文件                                   | 用途                                        |
| :----------------------------------- | :---------------------------------------- |
| `custom_phrase/custom_short.txt`     | 用指定的 ASCII 编码打出指定的任意字符或词                  |
| `custom_phrase/custom_extend.txt`    | 加词与调词频，正常参与双拼、辅码、长句                       |
| `custom_phrase/custom_phrase.txt`    | 个人信息等固定条目，让二字词压过四简码                       |
| `symbols_caps_v.yaml`                | 斜杠引导的符号与个人信息，缓解 `custom_phrase.txt` 的重码压力 |
| `custom_phrase/custom_phrase_kf.txt` | `o` 引导的符号与表情，少移手指（权重 -1，排在系统词之后）          |

前三个文件的用法见前面几节；后两个是"引导型"的表，按 `码<Tab>内容` 往里加即可。

### 4）Lua 与其他功能

| 文件 / 功能                            | 作用                                                                                                                                                 |
| :--------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lua/aux_shift.lua`                | 让同文支持 **▲ + 字母** 给第一个音节补辅码（Windows 端原本就有 Shift 辅码，安卓端靠它）                                                                                           |
| `lua/commit_comment.lua`           | Ctrl+J 把候选的注释直接上屏（反查结果上屏）                                                                                                                          |
| `lua/charset_filter.lua`           | 大小字集开关（工具栏/开关里的「小」字集过滤）                                                                                                                            |
| `lua/moqi/jianma_show.lua`         | 反查一二三简码、超级简拼和 `custom_short.txt`；改词表不用再手动动 `jian.dict.yaml`                                                                                        |
| `lua/shift_enter.lua`              | **▲ + Enter** 输出 `<br>`，在 Obsidian 表格里换行                                                                                                           |
| `super4.dict.yaml` + `生成super4.py` | 四简码反查。原版四简码与 e 简码有交叉，反查也混乱，这里不用 e 简码、统一给四简码做反查；四简码条目太多，塞进 `jianma_show.lua` 会拖慢，所以单独一张表。一般建议直接加进 `custom_short.txt` 即可，若要修改可以使用 `生成super4.py` 重新生成 |
| 单引号三选                              | 单引号键上屏候选第三                                                                                                                                         |
| 逗号上屏超级简拼                           | 逗号键上屏超级简拼                                                                                                                                          |
| 关掉语言模型                             | 实现完全固定的词频                                                                                                                                          |

### 5）同文手势（`ms.trime.yaml`）

键面上那两行小字就是触发提示：**上面一行是长按/上滑**（`label_symbol`），**下面一行是注解**（`hint`）。
下表括号里是实际预设名，在 `ms.trime.yaml` 里搜得到。

**Q–P：下滑**

| 键 | 动作 | 预设 |
| :-- | :-- | :-- |
| Q | 打开 QQ | `AppQQ`（`command: run`） |
| W | 打开微信 | `AppWeChat` |
| E | Ctrl+E 翻译 | `CtrlE`（`send: Control+e`） |
| R | 重复上屏刚打出的内容 | `RepeatCommit`（`command: commit`） |
| T | 插入当前日期时间（不含秒） | `Timestamp`（`command: date`） |
| O | 打开 Obsidian | `AppObsidian` |
| P | Ctrl+P 墨奇拆字 | `CtrlP`（`send: Control+p`） |

**A–L**

| 键 | 手势 | 动作 | 预设 |
| :-- | :-- | :-- | :-- |
| A | 长按/上滑 | 全选 | `select_all` |
| S | 下滑 | 保存（Ctrl+S） | `CtrlS`（`send: Control+s`） |
| D | 下滑 | 打开抖音 | `AppDouyin` |
| F | 长按/上滑 | 查找（Ctrl+F） | `CtrlF` |
| F | 下滑 | 用必应搜索光标前的内容 | `Bing`（`option` 里 `%4$s` 是光标前文本） |
| H | 长按/上滑 | 替换（Ctrl+H） | `CtrlH` |
| H | 左滑 | 收起/展开符号小字 | `HideSymbols` |
| H | 下滑 | 收起/展开注解小字 | `HideHints` |
| J | 长按/上滑 | 成对括号（中文态 `（）`、英文态 `()`），光标居中 | ASCII 字面量 `(){Left}` |
| J | 下滑 | 上屏反查（Ctrl+J） | `CtrlJ` |
| L | 长按/上滑 | 分号 `;` | — |
| L | 下滑 | 拆字（Ctrl+L） | `CtrlL` |

**Z–M**

| 键 | 手势 | 动作 | 预设 |
| :-- | :-- | :-- | :-- |
| X | 长按/上滑 | 剪切 | `cut` |
| C | 长按/上滑 | 复制 | `copy` |
| V | 长按/上滑 | 同文剪贴板直贴（不依赖 App） | `paste_clip` |
| V | 下滑 | 系统剪贴板粘贴（等同 Ctrl+V） | `paste` |
| B | 下滑 | 加粗（Ctrl+B） | `CtrlB` |
| N | 下滑 | 新建（Ctrl+N） | `CtrlN` |
| M | 下滑 | 打开 MT 管理器 | `MT_manager`（`command: run`，`option: bin.mt.plus`） |

**其他**

| 键 | 手势 | 动作 |
| :-- | :-- | :-- |
| ▲ | 单击 | 一次性大写（`Shift_L`） |
| ▲ | 双击 / 上滑 | 锁定大写（`Shift_L3`） |
| ▲ | 按住 + Enter | 输出 `<br>`（`lua/shift_enter.lua`） |
| ⌫ | 上滑 | Esc（`Escape`） |
| ⌫ | 下滑 | 撤销（`undo`） |
| ⌫ | 按住左右滑 | 逐字删（`slide_delete`，预设自带） |
| 空格 | 按住左右滑 | 移动光标（`slide_cursor`） |
| 空格 | 长按 / 上滑 | 切换中英文（`Mode_switch`） |
| 123 | 上滑 | 符号区（`Symbols_panel`） |
| Enter | 上滑 | 同文设置（`Settings`） |

**长按弹条**（`popup`）

| 键 | 弹条 |
| :-- | :-- |
| 123 | 符号（`Symbols_panel`）→ 换皮肤（`Color_switch`）→ 主题（`Theme_settings`） |
| Enter | 同文设置（`Settings`）→ 系统设置（`SysSettings`）→ 开发者选项（`DevSettings`） |

> 弹条是"离手指最近的那项排第一，其余往另一侧排"：Enter 在右边缘，所以往左依次是系统设置、开发者选项。

### 6）工具栏按钮

工具行右侧按钮，从右往左：

| 按钮 | 图标 | 动作 |
| :-- | :-- | :-- |
| 收起 | `ic@keyboard_hide` 一类 | 收起键盘 |
| 表情 | `emoji_button` | 打开表情/符号面板 |
| 剪贴板 | `clipboard_button`（`ic@clipboard`） | 打开同文剪贴板 |
| 光标 | `move_button`（`ic@cursor_text`） | 切到 Move 区（光标键盘，`Keyboard_move`） |
| 中/En | `ascii_mode_button`（显示「中」/「En」） | 切换中英文（`Mode_switch`） |
| 同步 | `sync_button`（`ic@refresh`） | 搬外部存储改动 + 合并词库快照 + 重启引擎（`Sync`） |

这些在 `ms.trime.yaml` 的 `style.buttons` 列表里，顺序就是显示顺序（从右往左）。

### 7）Move 区（光标区）

| 全选 | 文首 | ↑ | 文末 | 粘贴 |
| :-: | :-: | :-: | :-: | :-: |
| 复制 | ⇐<br>← | 选择 | ⇒<br>→ | 删词<br>删除 |
| Ctrl | Home | ↓ | End | 删词<br>⌫ |
| 返回 | 撤销 | Tab<br>␣ | 重做 | Enter |

- 选择：按住 Shift（`Shift_L2`）
- ⇐ / ⇒：Ctrl+← / Ctrl+→ 跳词（`Left1` / `Right1`）
- 删词：⌫ 是 Ctrl+Backspace（`CtrlBackspace`），删除键是 Ctrl+Delete（`DeleteCandidate`）
- 重做：Ctrl+Shift+Z（`redo`）
- 空格：点按出空格，长按/上滑出 Tab（`space_tab`）
- 键面上的小字同样是长按/上滑提示，例如 `Tab` 在空格上方、`删词` 在删除键上方

### 8）Enter 文案

Enter 的标签由 `style.enter_labels` 决定，按 App 上报的输入动作取：

| 动作 | 文案 | 场景 |
| :-- | :-- | :-- |
| `go` | 前往 | 浏览器地址栏 |
| `search` | 搜索 | 应用内搜索框 |
| `send` | 发送 | 短信 / 邮件 |
| `next` | 下个 | 表单下一项 |
| `pre` | 上个 | 表单上一项 |
| `done` | 完成 | 单行输入结尾 |
| `default` | 换行 | 多行文本、正文编辑器 |

`enter_label_mode: 0`（只用自己的表）。有候选时 Enter 显示「确定」（`composing: Return1`）。

### 9）鸣谢

- [墨奇音形](https://github.com/gaboolic/rime-shuangpin-fuzhuma) 作者 gaboolic —— 本配置全部基于它修改
- [薄荷输入法](https://github.com/Mintimate/oh-my-rime) —— 小狼毫「蓝水鸭」皮肤
- [魔裁 ms-trime](https://github.com/lost-42/ms-trime) —— 安卓端布局
- [白霜词库](https://github.com/gaboolic/rime-frost) / [雾凇拼音](https://github.com/iDvel/rime-ice) —— 词库与词频来源
- [同文 Trime](https://github.com/osfans/trime) —— 安卓端输入法平台
- [小狼毫 Weasel](https://github.com/rime/weasel) —— Windows 端输入法平台
