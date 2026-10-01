
基于 [墨奇音形](https://github.com/gaboolic/rime-shuangpin-fuzhuma) 的个人配置。
本仓库只记录**个人修改项**，基础功能、按键用法、拆字规则等见 [原版墨奇](https://github.com/gaboolic/rime-shuangpin-fuzhuma)。

新增自定义编码词库与自定义扩展词库，绕过 `ac` 自造词权重低于系统词的问题，实现手动加入自造词和调整词频

## 自造词库

### 自定义编码词库 `custom_short.txt`
以自定义大小写编码打出指定字符，调整指定编码的词频。靠 `Rime词库管理.py` 同步成 yaml 实现反查，权重高于系统词、低于 `custom_phrase.txt`。

### 自定义扩展词库 `custom_extend.txt`
添加系统没有的词，调整系统词的词频。靠 `Rime词库管理.py` 同步成 yaml 生效，权重低于 `custom_short.txt`。

### 出简让全
若两者出现重码导致系统词词频落后，如打出 `bkxl` 时系统词「冰箱」排在「本科学历」后面，推荐在 `custom_phrase.txt` 加入：
```
冰箱	bkxl
```

注：除非明确无重码，否则不建议在自定义编码里加入四码以上的编码，会触发自动上屏，影响打长句。

### 推荐的自定义

| 需求                                      | 文件                    |
| :-------------------------------------- | :-------------------- |
| 自定义编码打出指定字符、扩展简码、将词频靠后的简码提前，没有反查的简词也可加入 | `custom_short.txt`    |
| 正常双拼辅码打出、可加入长句的词                        | `custom_extend.txt`   |
| 常用语、个人填表信息                              | `custom_phrase.txt`   |
| 自定义斜杠引导符号和信息，邮箱等可加在 `/yx`，不影响正常打字       | `symbols_caps_v.yaml` |

注：`custom_extend.txt` 不要加入单字。Python 脚本只加了墨奇辅助码，且依赖 pypinyin，若需其他辅码可自行修改。

## 其他改动
- 加入单引号三选，超级简拼加入逗号候选，现超级简拼可由Tab或，或。或/打出
- 一些简词的调整
- 日期时间别名
	- `DT` datetime
	- `Ts` / `TS` timestamp
	- `Dt` 不带秒的 datetime
	- `Da` date
	- `Uj` time
	- `Wk` week
- lunar.lua 增加公历候选
- 固定词频修正：原版墨奇未关闭语言模型，正常打出 `kc` 时候选第一「靠」第二「考」，但有上一个字是「不」时第一会变成「考」的情况。已关掉语言模型以实现固定词频
- 小狼毫默认皮肤使用 [薄荷输入法](https://github.com/Mintimate/oh-my-rime)的蓝水鸭
- 同文布局改自 [魔裁 ms-trime](https://github.com/lost-42/ms-trime)

## ms.trime.yaml
安卓端同文特有
### 长按 / 上滑
- A 全选
- Z 拆字（Ctrl+P），可在 Obsidian 打开命令面板
- X 剪切
- C 复制
- V 粘贴
- F 查找，可在 Obsidian、MT 管理器、浏览器、Acode 等使用
- H 查找并替换，可在 Obsidian 使用，浏览器可打开历史记录
- 空格：切换中英文
- Enter：翻译（Ctrl+E）
- 数字区 123：换皮肤

- 下滑 O：Ctrl+O，可在 Obsidian 打开快速切换
- 上滑 ⌫：Esc
- 下滑 ⌫：撤销（Ctrl+Z）
- 按住左右滑动 ⌫：光标处滑动删除 / 撤销

### Move

| 全选 | Home | ↑ | End | 粘贴 |
| :-: | :----: | :----------: | :----: | :----------: |
| 剪切 | ⇐<br>← | 选择 | ⇒<br>→ | 删词<br>Delete |
| 复制 | 行首 | ↓ | 行尾 | 删词<br>⌫ |
| 返回 | 撤销 | Tab<br>Space | 重做 | Enter |

- Home / End：Ctrl+Home / End，跳到文首 / 文尾
- 选择：按住 Shift
- ⇐ / ⇒：Ctrl+← / → 跳词
- 删词：Ctrl+Backspace / Delete
- 重做：Ctrl+Shift+Z 取消撤销的内容

各种成对的括号和引号放在了数字区左侧。由于大部分常用符号可由引导打出或自定义引导，为了腾出空间直接砍掉了符号键，若需要可从工具栏的表情进入或自行修改。

## 鸣谢
- [墨奇音形](https://github.com/gaboolic/rime-shuangpin-fuzhuma) 作者 gaboolic，本配置全部基于它修改
- [薄荷输入法](https://github.com/Mintimate/oh-my-rime)，小狼毫默认皮肤「蓝水鸭」来自这里
- [魔裁 ms-trime](https://github.com/lost-42/ms-trime)，同文布局改自这里
- [白霜词库](https://github.com/gaboolic/rime-frost)，墨奇使用的词库和词频来源
- [雾凇拼音](https://github.com/iDvel/rime-ice)，白霜词库的上游
