--======================================================================
-- lua/moqi/jianma_show.lua   候选注释回显模块
--
-- 一个注释位置只显示一类内容，优先级从高到低：
--   1. 超级简拼   输入 1~3 码且命中 custom_phrase_super_*jian.txt
--                 时，把该词显示到首选候选注释里（按 / 上屏）。
--                 命中时这一个候选不再叠加任何其它提示。
--   2. custom_short 短码反查   候选词（≥2 字，单字不提示）在
--                 custom_short.txt 里登记过短码时回显短码。
--   3. 超级简拼反查   输入≥4 码（全码）时，回显该词在
--                 custom_phrase_super_*jian.txt 里的超级简拼码，
--                 带尾部斜杠（hx/ 、zyr/），单字不回显。
--   4. 词典简码回显（可选，默认开）   从 moqi_single 反查简码，
--                 优先级最低，前面命中就不显示。
--
-- 2~4 级数据全部来自用户目录下的文本文件（超级简拼反查直接从
-- custom_phrase_super_*jian.txt 建表，无需改 jian.dict.yaml、无需重建
-- reverse.bin）；1 级与 3 级共用一次文件扫描。
-- Weasel / Trime 行为一致；解析时统一去掉行尾空白，兼容 CRLF / LF。
-- 主循环里不做任何日志输出，只有纯表查找，保证不卡。
--
-- 工作流：编辑 custom_phrase/custom_short.txt
--          → 运行 Rime词库管理.py（同步到 cn_dicts_common/custom_short.dict.yaml）
--          → 重新部署
--======================================================================

local M = {}

-- 默认参数，可在方案文件里用 jianma_show/xxx 覆盖
local DEFAULTS = {
   super_max_code  = 3,      -- 超级简拼回显的最大输入码长
   min_word_length = 2,      -- 短码反查的最小词长（单字不回显）
   max_hint        = 4,      -- 单个候选最多回显几个码
   hint_separator  = " ",    -- 多个码之间的分隔符
   super_reverse   = true,   -- 第 3 级：超级简拼反查（纯内存查表，开销极小）
   dict_reverse    = true,   -- 第 4 级：moqi_single 词典简码回显（查库，可关）
   dict_name       = "moqi_single",
   min_code_length = 4,      -- 第 3、4 级要求的最小输入码长
   cache_max       = 30000,  -- 第 4 级反查结果缓存条数上限，超出即清空
}

-- 超级简拼（词 <tab> 码/），按优先级排列，先出现的优先
local SUPER_FILES = {
   "custom_phrase/custom_phrase_super_1jian.txt",
   "custom_phrase/custom_phrase_super_2jian.txt",
   "custom_phrase/custom_phrase_super_3jian.txt",
}

-- custom_short 短码源，用第一个存在的文件（yaml 由 py 脚本生成，txt 作为兜底）
local SHORT_FILES = {
   "cn_dicts_common/custom_short.dict.yaml",
   "custom_phrase/custom_short.txt",
}

----------------------------------------------------------------------
-- 基础工具
----------------------------------------------------------------------

local function ulen(s)
   if utf8 and utf8.len then
      local n = utf8.len(s)
      if n then return n end
   end
   return #s
end

local function trim(s)
   return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function data_dirs()
   local dirs = {}
   if rime_api then
      pcall(function()
         local d = rime_api.get_user_data_dir()
         if d and d ~= "" then dirs[#dirs + 1] = d end
         d = rime_api.get_shared_data_dir()
         if d and d ~= "" then dirs[#dirs + 1] = d end
      end)
   end
   return dirs
end

-- 依次尝试 用户目录 / 共享目录，返回第一个能打开的文件
local function open_first(rel, dirs)
   for i = 1, #dirs do
      local f = io.open(dirs[i] .. "/" .. rel, "r")
      if f then return f end
   end
   return nil
end

----------------------------------------------------------------------
-- 载入词库：只取前两个 tab 字段，天然跳过 yaml 头部与注释行
----------------------------------------------------------------------

-- 每个词只存一个「已拼好的提示字符串」，不建子表：
-- 一万多个词各建一张表会带来明显的 GC 压力，扁平化成字符串后内存和扫描都轻很多。
local function append_code(tbl, key, code)
   if not tbl or not key or key == "" then return false end
   local old = tbl[key]
   if old == nil then
      tbl[key] = code
      return true
   end
   -- 去重：整段匹配，避免把 "hx" 当成 "hxx" 的子串
   if not ((" " .. old .. " "):find(" " .. code .. " ", 1, true)) then
      tbl[key] = old .. " " .. code
   end
   return false
end

-- 超级简拼，一次遍历建两张表：
--   tbl[码] = 词   码去掉尾部 /，用于输入 1~3 码时回显词（如 vi -> 正常）
--   rev[词] = 码   码保留尾部 /，用于全码输入时反查回显（如 好像 -> hx/、总有人 -> zyr/）
local function load_super(dirs, tbl, rev, min_word_length)
   local count = 0
   for i = 1, #SUPER_FILES do
      local f = open_first(SUPER_FILES[i], dirs)
      if f then
         for line in f:lines() do
            local l = trim(line)
            if l ~= "" and l:sub(1, 1) ~= "#" then
               local word, raw = l:match("^([^\t]+)\t+([^\t]+)")
               if word and raw then
                  word = trim(word)
                  raw = trim(raw)
                  local code = (raw:gsub("/+$", ""))  -- 查表用：去掉尾部 /
                  if word ~= "" and code ~= "" then
                     if tbl[code] == nil then
                        tbl[code] = word
                        count = count + 1
                     end
                     -- 反查用：原样保留尾部 /（单字不回显，避免盖掉单字的辅码提示）
                     if rev and ulen(word) >= min_word_length then
                        append_code(rev, word, raw)
                     end
                  end
               end
            end
         end
         f:close()
      end
   end
   return count
end

-- custom_short：词 -> 提示串（保持文件顺序）
local function load_short(dirs, tbl, min_word_length)
   local count = 0
   for i = 1, #SHORT_FILES do
      local f = open_first(SHORT_FILES[i], dirs)
      if f then
         for line in f:lines() do
            local l = trim(line)
            if l ~= "" and l:sub(1, 1) ~= "#" then
               local word, code = l:match("^([^\t]+)\t+([^\t]+)")
               if word and code then
                  word = trim(word)
                  code = trim(code)
                  if word ~= "" and code ~= "" and ulen(word) >= min_word_length then
                     if append_code(tbl, word, code) then count = count + 1 end
                  end
               end
            end
         end
         f:close()
         break -- 只用第一个存在的源
      end
   end
   return count
end

----------------------------------------------------------------------
-- 注释拼装
----------------------------------------------------------------------

-- codes 已是拼好的提示串；注释里已经有全部码时返回 nil，避免重复
local function make_hint(codes, comment, sep)
   if not codes or codes == "" then return nil end
   if comment and comment ~= "" then
      local dup = true
      for c in codes:gmatch("%S+") do
         if not comment:find(c, 1, true) then dup = false break end
      end
      if dup then return nil end
      return comment .. sep .. codes
   end
   return codes
end

-- 第 3 级：moqi_single 词典简码
local function dict_hint(text, comment, env, cand)
   local rev = env.reverse
   if not rev then return nil end
   local wlen = ulen(text)
   if wlen < 2 then return nil end

   -- 反查要读库，是整套里唯一有实际开销的地方，按词缓存：
   -- 同一个词每次击键都会重复查，缓存后只有首次命中才走一次库。
   local cache = env.lookup_cache
   local res = cache[text]
   if res == nil then
      local ok, r = pcall(function() return rev:lookup(text) end)
      res = (ok and r and r ~= "") and r or false
      cache[text] = res
      env.lookup_cache_n = env.lookup_cache_n + 1
      if env.lookup_cache_n > env.settings.cache_max then
         env.lookup_cache = {}
         env.lookup_cache_n = 0
      end
   end
   if not res then return nil end

   local preedit = cand.preedit or ""
   local max = env.settings.max_hint
   local short, three, four = {}, {}, {}
   -- 按去掉 / 后的长度归类，但显示时保留原始写法（超级简拼的 hx/ 要带斜杠）
   for raw_code in res:gmatch("%S+") do
      local c = (raw_code:gsub("/+$", ""))
      local clen = #c
      if clen > 0 then
         if clen <= 2 then
            if #short < max then short[#short + 1] = raw_code end
         elseif clen == 3 and c ~= preedit then
            if #three < max then three[#three + 1] = raw_code end
         elseif clen == 4 and wlen == 4 then
            if #four < max then four[#four + 1] = raw_code end
         end
      end
   end

   local parts
   if #short > 0 then parts = short
   elseif #four > 0 then parts = four
   elseif #three > 0 then parts = three
   else return nil end

   return make_hint(table.concat(parts, " "), comment, env.settings.hint_separator)
end

----------------------------------------------------------------------
-- 生命周期
----------------------------------------------------------------------

function M.init(env)
   -- 读方案里的可选项
   env.settings = {}
   for k, v in pairs(DEFAULTS) do env.settings[k] = v end

   pcall(function()
      local config = env.engine.schema.config
      local ns = (env.name_space or "jianma_show"):gsub("^%*", "")
      local s
      s = config:get_string(ns .. "/super_max_code")
      if s and tonumber(s) then env.settings.super_max_code = tonumber(s) end
      s = config:get_string(ns .. "/min_word_length")
      if s and tonumber(s) then env.settings.min_word_length = tonumber(s) end
      s = config:get_string(ns .. "/max_hint")
      if s and tonumber(s) then env.settings.max_hint = tonumber(s) end
      s = config:get_string(ns .. "/min_code_length")
      if s and tonumber(s) then env.settings.min_code_length = tonumber(s) end
      s = config:get_string(ns .. "/hint_separator")
      if s then env.settings.hint_separator = s end
      s = config:get_string(ns .. "/dict_name")
      if s and s ~= "" then env.settings.dict_name = s end
      s = config:get_string(ns .. "/cache_max")
      if s and tonumber(s) then env.settings.cache_max = tonumber(s) end
      s = config:get_string(ns .. "/super_reverse")
      if s == "true" then env.settings.super_reverse = true end
      if s == "false" then env.settings.super_reverse = false end
      s = config:get_string(ns .. "/dict_reverse")
      if s == "true" then env.settings.dict_reverse = true end
      if s == "false" then env.settings.dict_reverse = false end
   end)

   env.super = {}
   env.super_rev = {}
   env.short = {}
   local dirs = data_dirs()
   env.super_count = load_super(dirs, env.super, env.super_rev, env.settings.min_word_length)
   env.short_count = load_short(dirs, env.short, env.settings.min_word_length)

   env.lookup_cache = {}
   env.lookup_cache_n = 0
   env.reverse = nil
   if env.settings.dict_reverse then
      local ok, rev = pcall(function() return ReverseLookup(env.settings.dict_name) end)
      if ok and rev then env.reverse = rev end
   end

   log.info(string.format(
      "[jianma_show] 超级简拼 %d 条 / custom_short %d 词 / 超级简拼反查 %s / 词典反查 %s",
      env.super_count, env.short_count,
      env.settings.super_reverse and "开" or "关",
      env.reverse and "开" or "关"))
end

function M.fini(env)
   env.super = nil
   env.super_rev = nil
   env.short = nil
   env.reverse = nil
   env.lookup_cache = nil
end

----------------------------------------------------------------------
-- 主过滤
----------------------------------------------------------------------

function M.func(input, env)
   local settings = env.settings
   local super = env.super
   local super_rev = env.super_rev
   local short = env.short
   local sep = settings.hint_separator
   local min_code = settings.min_code_length
   local use_super_rev = settings.super_reverse
   local long_input = false

   -- 当前输入码：整个 func 只取一次（pcall 不再放进候选循环里）
   local raw = ""
   local ok, cur = pcall(function() return env.engine.context.input end)
   if ok and cur then raw = cur end
   if #raw >= min_code then long_input = true end

   -- 超级简拼只在 1~3 码纯字母时提示
   local super_word = nil
   if super and #raw <= settings.super_max_code and raw:match("^%a+$") then
      super_word = super[raw]
   end

   local is_first = true
   local has_cand = false

   for cand in input:iter() do
      has_cand = true
      local text = cand.text
      local comment = cand.comment
      local hint = nil

      -- 1) 首选候选：有超级简拼就只显示超级简拼
      if is_first then
         is_first = false
         if super_word and super_word ~= text then
            comment = super_word
            hint = super_word
         end
      end

      if not hint then
         -- 2) custom_short 短码反查
         hint = make_hint(short[text], comment, sep)
         -- 3) 超级简拼反查：全码输入时回显超级简拼码（带 /，如 hx/ zyr/）
         if not hint and long_input and use_super_rev then
            hint = make_hint(super_rev[text], comment, sep)
         end
         -- 4) 词典简码回显（查库，优先级最低，结果按词缓存）
         if not hint and long_input then
            hint = dict_hint(text, comment, env, cand)
         end
      end

      -- 只有真要改注释时才取 genuine（get_genuine 每次都会过一次 C++ 边界）
      if hint then
         local g = cand:get_genuine()
         if g.comment ~= hint then g.comment = hint end
      end

      yield(cand)
   end

   -- 一个候选都没有时，把超级简拼直接作为候选给出
   if not has_cand and super_word then
      yield(Candidate("word", 0, #super_word, super_word, "⚡"))
   end
end

return M
