--======================================================================
-- lua/moqi/jianma_show.lua   候选注释回显模块（纯文本驱动）
--
-- 两类回显，两条路：
--   A. 超级简拼回显（输入 1~3 码命中）→ 首选候选注释显示该词，按 / 上屏
--      数据：custom_phrase_super_{1jian,2jian,3jian}.txt   码(去 /) -> 词
--   B. 简码反查（候选词回显它的简码）→ "w" / "hx/" / "uyvc uyvb u"
--      数据分两组，规则不同：
--        「简码表」custom_phrase.txt / super_2jian.txt / super_3jian.txt
--            一个词登记了多个码时，只回显**最短的那一组**（简码优先）
--            例：问题 {w, wt, wt/} -> "w"
--        「自定义短码」custom_short.txt
--            非单字词**查全**，按文件里出现的顺序全部回显
--            例：事已至此，先吃饭吧 {uyvc, uyvb, u} -> "uyvc uyvb u"
--      两组拼接，简码表在前；去掉尾部 / 后形式相同的码只留先出现的。
-- 单字（如 我 w、去 q）不回显简码，把注释位置留给辅码提示。
--
-- 本模块只读用户目录下的这几个 txt，init 时一次读进来建表：
--   * 不读任何 .dict.yaml、不用 ReverseLookup、不依赖 build/*.reverse.bin
--   * 改 txt 后重启算法服务即可生效，不需要重新部署
--   （能不能「打出来」是 table_translator 那边的事，跟回显无关）
-- 主循环里零日志、只有纯表查找。
--
-- 四字词的 4 码（super_4jian_no_conflict.txt，10.9 万条）**故意不在这里**：
-- 它太大（init +0.4s、Lua 堆 +12MB），改由 cn_dicts_common/super4.dict.yaml
-- 的反查在 C++ 侧完成，见 moqi.yaml 的 reverse_lookup_filter@fourjian。
--
-- 工作流：直接编辑 custom_phrase/*.txt
--======================================================================

local M = {}

-- 默认参数，可在方案文件里用 jianma_show/xxx 覆盖
local DEFAULTS = {
   super_max_code  = 3,      -- 超级简拼回显的最大输入码长
   min_word_length = 2,      -- 简码反查的最小词长（单字不回显，留给辅码）
   max_hint        = 4,      -- 一个候选最多回显几个码
   hint_separator  = " ",    -- 多个码之间的分隔符
   min_code_length = 1,      -- 简码反查要求的最小输入码长，设 4 则只在全码时回显
}

-- A. 超级简拼回显：码(去掉尾部 /) -> 词，按优先级排列，先出现的优先
local SUPER_FILES = {
   "custom_phrase/custom_phrase_super_1jian.txt",
   "custom_phrase/custom_phrase_super_2jian.txt",
   "custom_phrase/custom_phrase_super_3jian.txt",
}

-- B. 简码反查。
--    简码表：一个词只保留最短的一组（简码优先）
--    注意不包含 custom_phrase_3_code.txt（单字三码）
local HINT_FILES = {
   "custom_phrase/custom_phrase.txt",
   "custom_phrase/custom_phrase_super_2jian.txt",
   "custom_phrase/custom_phrase_super_3jian.txt",
}

-- 自定义短码：非单字词全部保留（查全），排在简码表后面
local SHORT_FILE = "custom_phrase/custom_short.txt"

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

-- 遍历一个「词 <tab> 码」文件的每一行。
-- 只认带 tab 的行，所以 yaml 头部、注释行天然被跳过；
-- 字段里用 [^\t\r] 直接排除 CRLF 的 \r（Windows 下 io.lines 会吃掉 \r，
-- Android 下会保留），不必再对整行做两次 trim。
local function each_entry(rel, dirs, fn)
   local f = open_first(rel, dirs)
   if not f then return end
   for line in f:lines() do
      if line:sub(1, 1) ~= "#" and line ~= "" then
         local word, code = line:match("^([^\t\r]+)\t+([^\t\r]+)")
         if word and code then
            word = (word:gsub("%s+$", ""))
            code = (code:gsub("%s+$", ""))
            if word ~= "" and code ~= "" then fn(word, code) end
         end
      end
   end
   f:close()
end

----------------------------------------------------------------------
-- 建表
----------------------------------------------------------------------

-- A. 码(去 /) -> 词，用于输入 1~3 码时回显
local function load_super(dirs, tbl)
   local count = 0
   for i = 1, #SUPER_FILES do
      each_entry(SUPER_FILES[i], dirs, function(word, raww)
         local code = (raww:gsub("/+$", ""))
         if word ~= "" and code ~= "" and tbl[code] == nil then
            tbl[code] = word
            count = count + 1
         end
      end)
   end
   return count
end

-- B. 词 -> 提示串
--    每个词只维护「已拼好的字符串」(+最短长度)，不建子表，省内存也省 GC
--    keep = "best" 只留最短的一组    keep = "all" 全部保留
local function add_code(tbl, lens, word, code, keep, min_word_length, max_hint)
   if word == "" or code == "" or ulen(word) < min_word_length then return end
   local stripped = (code:gsub("/+$", ""))
   local l = #stripped
   if l == 0 then return end

   local old = tbl[word]
   if old == nil then
      tbl[word] = code
      if keep == "best" then lens[word] = l end
      return
   end

   if keep == "best" then
      local cur = lens[word]
      if l < cur then          -- 更短就整组替换
         tbl[word] = code
         lens[word] = l
         return
      elseif l > cur then
         return
      end
   end

   -- 同长度（或 keep = "all"）：按去掉 / 后的形式去重后追加
   local n, dup = 0, false
   for c in old:gmatch("%S+") do
      n = n + 1
      if (c:gsub("/+$", "")) == stripped then dup = true break end
   end
   if not dup and n < max_hint then
      tbl[word] = old .. " " .. code
   end
end

local function load_hint(dirs, hint, min_word_length, max_hint)
   local best, bestlen, short = {}, {}, {}
   local function add_best(w, c)
      add_code(best, bestlen, w, c, "best", min_word_length, max_hint)
   end
   local function add_all(w, c)
      add_code(short, nil, w, c, "all", min_word_length, max_hint)
   end

   for i = 1, #HINT_FILES do
      each_entry(HINT_FILES[i], dirs, add_best)
   end
   each_entry(SHORT_FILE, dirs, add_all)

   -- 合并：简码表的最短一组在前，custom_short 的全部码接在后面
   local count = 0
   for word, b in pairs(best) do
      local a = short[word]
      local out = b
      if a then
         local n = 0
         for _ in b:gmatch("%S+") do n = n + 1 end
         for c in a:gmatch("%S+") do
            if n >= max_hint then break end
            local s = (c:gsub("/+$", ""))
            local dup = false
            for x in out:gmatch("%S+") do
               if (x:gsub("/+$", "")) == s then dup = true break end
            end
            if not dup then
               out = out .. " " .. c
               n = n + 1
            end
         end
      end
      hint[word] = out
      count = count + 1
   end
   for word, a in pairs(short) do
      if hint[word] == nil then
         hint[word] = a
         count = count + 1
      end
   end
   return count
end

----------------------------------------------------------------------
-- 注释拼装
----------------------------------------------------------------------

-- codes 已是拼好的提示串。注释里已经有的码**逐个**剔掉再拼，避免重复：
-- 四字词 4 码由 C++ 的 reverse_lookup_filter@fourjian 先写进注释
-- （见 moqi.yaml），而那个码可能同时也在 custom_short.txt 里。
-- 全部码都已存在时返回 nil，表示不用改注释。
local function make_hint(codes, comment, sep)
   if not codes or codes == "" then return nil end
   if not comment or comment == "" then return codes end
   local add = nil
   for c in codes:gmatch("%S+") do
      if not comment:find(c, 1, true) then
         add = add and (add .. sep .. c) or c
      end
   end
   if not add then return nil end
   return comment .. sep .. add
end

----------------------------------------------------------------------
-- 生命周期
----------------------------------------------------------------------

function M.init(env)
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
   end)

   local dirs = data_dirs()
   env.super = {}
   env.hint = {}
   env.super_count = load_super(dirs, env.super)
   env.hint_count = load_hint(dirs, env.hint,
                              env.settings.min_word_length, env.settings.max_hint)

   log.info(string.format("[jianma_show] 超级简拼 %d 条 / 简码反查 %d 词",
                          env.super_count, env.hint_count))
end

function M.fini(env)
   env.super = nil
   env.hint = nil
end

----------------------------------------------------------------------
-- 主过滤
----------------------------------------------------------------------

function M.func(input, env)
   local settings = env.settings
   local super = env.super
   local hint_tbl = env.hint
   local sep = settings.hint_separator
   local min_code = settings.min_code_length
   local long_enough = true

   -- 当前输入码：整个 func 只取一次
   local raw = ""
   local ok, cur = pcall(function() return env.engine.context.input end)
   if ok and cur then raw = cur end
   if #raw < min_code then long_enough = false end

   -- 超级简拼回显只在 1~3 码纯字母时生效
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

      -- A. 首选候选：命中超级简拼就只显示超级简拼
      if is_first then
         is_first = false
         if super_word and super_word ~= text then
            hint = super_word
         end
      end

      -- B. 简码反查
      if not hint and long_enough then
         hint = make_hint(hint_tbl[text], comment, sep)
      end

      -- 只有真要改注释时才取 genuine（每次都要过一次 C++ 边界）
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
