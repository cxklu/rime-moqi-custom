-- lua/commit_current.lua
-- Ctrl+J：把「当前这一页」的候选按顺序一次上屏，默认 6 条、换行分隔。
--
-- 典型用法：打 `hc` → Ctrl+J → 一次得到
--   好
--   号
--   薅
--   ...
-- 挑词、整理字表时不用一个个点。翻到第 2 页再按 Ctrl+J，就是第 2 页的那几条。
--
-- 候选直接从当前 segment 的 Menu 里取（和屏幕上显示的完全一致），
-- 不依赖过滤器缓存，所以不会出现「上屏上一次输入的内容」。
-- 条数可用 schema 里的 commit_current/limit 调（默认 6，等于一页）。

local M = {}

local TRIGGER = 'Control+j'
local DEFAULT_LIMIT = 6
local SEPARATOR = '\n'
local MAX_SCAN = 200

local function read_limit(env)
  local n = DEFAULT_LIMIT
  pcall(function()
    local v = env.engine.schema.config:get_int("commit_current/limit")
    if v and v > 0 then n = v end
  end)
  return n
end

local function read_page_size(env)
  local ps = DEFAULT_LIMIT
  pcall(function()
    local v = env.engine.schema.config:get_int("menu/page_size")
    if v and v > 0 then ps = v end
  end)
  return ps
end

local function back_segment(context)
  local seg
  pcall(function() seg = context.composition:back() end)
  return seg
end

-- 从 start 开始取，最多 limit 条、且不超过 start+page_size
local function texts_from(menu, start, limit, page_size)
  local texts = {}
  local last = start + math.min(limit, page_size)
  local i = start
  while i < last and i < start + MAX_SCAN do
    local cand
    local ok = pcall(function() cand = menu:get_candidate_at(i) end)
    if not ok or not cand then break end
    local text
    pcall(function() text = cand.text end)
    if text and text ~= "" then texts[#texts + 1] = text end
    i = i + 1
  end
  return texts
end

function M.func(key, env)
  if key:repr() ~= TRIGGER then return 2 end
  if key:release() then return 2 end

  local context = env.engine.context
  if not context:is_composing() then return 2 end
  if not context:has_menu() then return 2 end

  local limit = read_limit(env)
  local page_size = read_page_size(env)

  local texts = {}
  local seg = back_segment(context)
  local menu
  if seg then pcall(function() menu = seg.menu end) end

  if menu then
    local selected = 0
    pcall(function() selected = seg.selected_index or 0 end)
    local start = math.floor(selected / page_size) * page_size
    texts = texts_from(menu, start, limit, page_size)
    -- 当前页是空的（比如光标还在上一页边界）就退回第一页
    if #texts == 0 and start ~= 0 then
      texts = texts_from(menu, 0, limit, page_size)
    end
  end

  -- 菜单读不到时退回「只上屏当前高亮那条」
  if #texts == 0 then
    local cand = context:get_selected_candidate()
    if not cand or not cand.text or cand.text == "" then return 2 end
    texts[1] = cand.text
  end

  local text = table.concat(texts, SEPARATOR)
  context:clear()

  -- 先自己记账（按行写进 Z 历史与 recent_commits.log），再上屏：
  -- commit_text 不一定触发 commit_notifier，光靠订阅会漏记；
  -- 记账期间让 notifier 跳过，避免重复。
  rawset(_G, "moqi_recent_recording", true)
  local record = rawget(_G, "moqi_recent_record")
  if record then pcall(record, text) end
  env.engine:commit_text(text)
  rawset(_G, "moqi_recent_recording", false)
  return 1
end

return M