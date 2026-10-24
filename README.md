# Rime 墨奇音形 · 个人定制（公开分享版）

基于 [墨奇音形](https://github.com/gaboolic/rime-shuangpin-fuzhuma)（作者 gaboolic）的个人定制配置，
这里是它的**可分享版本**：只放方案文件与词库，不含个人设备配置、个人笔记和私人词条。

> 桌面端用**小狼毫**，安卓端用**同文 Trime**，两端共用同一套方案与词库。
> 安卓端多一个 `ms.trime.yaml`（主题与手势表），它只管键盘长什么样，与词库无关，桌面端不受影响。

## 一、这个仓库里有什么

| 内容 | 说明 |
| :--- | :--- |
| 方案与配置 | 与上游墨奇音形保持一致（`*.schema.yaml`、`default.custom.yaml`、`opencc\` 等） |
| 词库 | `cn_dicts_common\`、`cn_dicts_cell\` 等，与上游一致；`program\` 另收 `moran.chars.dict.yaml`、`flypydz.yaml` |
| 自定义词表 | `custom_phrase\` 下的简拼/短码/扩展词表，以及 `super4.dict.yaml` |
| 示例数据 | 含个人信息的那几个词表已替换为**示例版**（见第二节），可直接改成你自己的 |
| 脚本 | `Rime词库管理.py`、`生成super4.py`、`Rime词库排序.py`，用于重新生成派生词库 |

**不含**：`user.yaml`、`installation.yaml`、`*.userdb`、个人笔记——这些要么与设备绑定，要么是私人的。

## 二、示例词表（可以放心改成自己的）

| 文件 | 作用 |
| :--- | :--- |
| `custom_phrase/custom_extend.txt` | 加词 / 调词频：正常参与双拼、辅码与长句 |
| `custom_phrase/custom_short.txt` | 自定义短码：按你写的码出词，不参与辅码和长句 |
| `custom_phrase/custom_phrase.txt` | 置顶短语 |
| `symbols_caps_v.yaml` | 符号表 |

这四个文件在公开版里只有格式与示例内容，替换成你自己的以后重新部署即可生效。

## 三、三个脚本

| 脚本 | 做什么 | 依赖 |
| :--- | :--- | :--- |
| `Rime词库管理.py` | 把 `custom_phrase/custom_extend.txt` 生成为 `cn_dicts_common/custom_extend.dict.yaml`（自动取小鹤辅码） | `pypinyin`、`program/moran.chars.dict.yaml`、`program/flypydz.yaml` |
| `生成super4.py` | 把 `custom_phrase/custom_phrase_super_4jian_no_conflict.txt` 生成为 `super4.dict.yaml` | 无 |
| `Rime词库排序.py` | 给 `custom_phrase/custom_short.txt` 排序（会留 `.bak`） | 无 |

```bash
pip install pypinyin
python Rime词库管理.py
python 生成super4.py
python Rime词库排序.py
```

脚本会自动识别自己所在的 Rime 目录（放在用户目录里直接跑即可），也可以设 `RIME_DIR` 环境变量。

## 四、怎么用

1. 先按上游 README 装好墨奇音形（小狼毫 / 同文）。
2. 把本仓库的文件放到 Rime 用户目录：
   - 小狼毫：`%APPDATA%\Rime`
   - 同文：`/storage/emulated/0/rime`（或你在 Trime 里设置的目录）
3. 可选：装好 `pypinyin` 后跑一遍上面三个脚本，重新生成派生词库。
4. 重新部署（小狼毫「重新部署」；同文在设置里「部署」）。

## 五、与上游的差异

- `custom_phrase\` 收录了上游没有的 `custom_extend.txt`、`custom_short.txt`，以及对应的生成物；
- `program\` 补了 `moran.chars.dict.yaml` 与 `flypydz.yaml`，让辅码生成开箱可用；
- 其余方案文件与词库与上游保持一致，方便随时跟上上游更新。

## 鸣谢

方案与绝大部分词库来自 [gaboolic/rime-shuangpin-fuzhuma](https://github.com/gaboolic/rime-shuangpin-fuzhuma)，
以及雾凇拼音等开源词库的作者们。本仓库只做了个人向的调整。
