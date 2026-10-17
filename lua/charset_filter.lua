-- 小字集 / 大字集：过滤「扩展区汉字」候选
--
-- 开关 extended_charset（moqi.yaml 的 switches 里定义）关闭时，把含扩展区汉字的
-- 候选整条丢掉；打开时全部放行。词条本身不删，切换后立刻回来。
--
-- 为什么要它：本方案的主词表 moqi_wan.extended 里导入了 cn_dicts/GB18030-2022
-- （5.6 万条，其中 5.2 万条是扩展区汉字），这些字在手机端大多没有字体，
-- 候选栏里显示成方块（豆腐块），既看着乱又占位置。
--
-- 为什么不用 librime 内置的 charset_filter：内置那个只在 table_translator 上生效
-- （script_translator 不支持 enable_charset_filter），而本方案主翻译器是
-- script_translator；直接往 engine/filters 里放 `charset_filter` 在本机 librime 上
-- 不生效，部署日志会报 `charset parameter is unsupported by basic charset_filter`。
--
-- 判定的字符范围与 librime charset_filter.cc 的 is_extended_cjk() 一致。

local M = {}

local function is_extended_cjk(cp)
  -- 常用区（U+4E00–9FFF 汉字、标点、假名等）直接排除，走最快的路径
  if cp < 0x3400 then return false end
  if cp <= 0x4DBF then return true end  -- CJK 扩展 A
  if cp < 0xF900 then return false end  -- 基本区汉字等
  if cp <= 0xFAFF then return true end  -- CJK 兼容汉字
  if cp < 0x20000 then return false end
  -- 以下是需要 4 字节编码的补充平面
  return (cp >= 0x20000 and cp <= 0x2A6DF)  -- 扩展 B
      or (cp >= 0x2A700 and cp <= 0x2B73F)  -- 扩展 C
      or (cp >= 0x2B740 and cp <= 0x2B81F)  -- 扩展 D
      or (cp >= 0x2B820 and cp <= 0x2CEAF)  -- 扩展 E
      or (cp >= 0x2CEB0 and cp <= 0x2EBEF)  -- 扩展 F
      or (cp >= 0x2EBF0 and cp <= 0x2EE5F)  -- 扩展 I
      or (cp >= 0x2F800 and cp <= 0x2FA1F)  -- 兼容汉字补充
      or (cp >= 0x30000 and cp <= 0x3134F)  -- 扩展 G
      or (cp >= 0x31350 and cp <= 0x323AF)  -- 扩展 H
      or (cp >= 0x323B0 and cp <= 0x3347F)  -- 扩展 J
end

-- 手写 UTF-8 解码，不依赖 utf8 库（librime-lua 可能跑在 LuaJIT 上，没有 utf8）
local function contains_extended(text)
  local i, n = 1, #text
  while i <= n do
    local b = text:byte(i)
    local cp, len
    if b < 0x80 then
      cp, len = b, 1
    elseif b < 0xE0 then
      cp, len = b - 0xC0, 2
    elseif b < 0xF0 then
      cp, len = b - 0xE0, 3
    else
      cp, len = b - 0xF0, 4
    end
    for k = 1, len - 1 do
      local c = text:byte(i + k)
      if not c then break end
      cp = cp * 64 + (c - 0x80)
    end
    if is_extended_cjk(cp) then return true end
    i = i + len
  end
  return false
end

function M.func(input, env)
  -- 打开 extended_charset = 大字集：不过滤，原样放行
  if env.engine.context:get_option("extended_charset") then
    for cand in input:iter() do
      yield(cand)
    end
    return
  end
  for cand in input:iter() do
    if not contains_extended(cand.text) then
      yield(cand)
    end
  end
end

return M
