-- lua/recent_commits.lua
-- 输入大写 Z 时，候选给出最近上屏过的文字：最近一次排第一，依次往下，最多 36 个。
--
-- 历史放在全局表 _G.moqi_recent 里；每次上屏还会追加到
-- custom_phrase/recent_commits_<windows|android>.log（两个平台各写各的文件，
-- 免得 Syncthing 同步出冲突），方便文字被吞时翻日志找回。
-- 日志只由这个文件写，不读回，所以重启后 Z 列表照旧是空的。
--
-- 注意：上屏事件必须在「会话的 context」上订阅。init 会被调用两次
-- （引擎预载的 context 与会话的 context 各一次），在 init 里订阅可能订到
-- 预载 context 上——那个 context 永远不会有上屏，于是 Z 列表和日志全空。
-- 所以改成在过滤器真正跑起来时（一定是会话 context）按需订阅。

local M = {}
local MAX = 36

local history = rawget(_G, "moqi_recent")
if not history then
  history = {}
  rawset(_G, "moqi_recent", history)
end

local log_path = nil
local log_limit = 512 * 1024
local log_written = 0

local function rotate_log(f, size)
  f:seek("set", math.floor(size / 2))
  local tail = f:read("*a") or ""
  f:close()
  local cut = tail:find("\n", 1, true)
  if cut then tail = tail:sub(cut + 1) end
  local w = io.open(log_path, "w")
  if not w then return end
  w:write(tail)
  w:close()
  log_written = #tail
end

-- 平台标签：Windows 和安卓各写各的日志（同一个文件会被 Syncthing 同步出冲突）
local function platform_tag()
  local o = (jit and jit.os) or ""
  if o == "Windows" then return "windows" end
  if o == "OSX" then return "macos" end
  if o == "Linux" or o == "Android" then return "android" end
  return (package.config:sub(1, 1) == "\\") and "windows" or "android"
end

local function getenv(k)
  local ok, v = pcall(function() return os.getenv(k) end)
  if ok then return v end
  return nil
end

-- 候选目录：安卓上 rime_api.get_user_data_dir() 有时指向 App 私有目录（文件管理器
-- 看不到、Syncthing 也同步不到）；Trime 也可能用 Android/data 下的目录。这里不靠
-- "读得到 custom_short.txt" 判断（判断失败就会退到私有目录、日志就消失了），而是
-- 对每个候选直接试着打开日志文件，谁能写就用谁。
local function log_dirs(tag)
  local out, seen = {}, {}
  local function add(p)
    if p and p ~= "" and not seen[p] then
      seen[p] = true
      out[#out + 1] = p
    end
  end
  if tag == "android" then
    add("/storage/emulated/0/rime")
    local ext = getenv("EXTERNAL_STORAGE")
    if ext and ext ~= "" then add(ext .. "/rime") end
    add("/sdcard/rime")
    add("/storage/emulated/0/Android/data/com.osfans.trime/files/rime")
  end
  local ok, d = pcall(function() return rime_api.get_user_data_dir() end)
  if ok and d and d ~= "" then add(d) end
  local appdata = getenv("APPDATA")
  if appdata and appdata ~= "" then add(appdata .. "\\Rime") end
  add(".")
  return out
end

local function try_open(path)
  if not io or not io.open then return nil end
  local ok, f = pcall(io.open, path, "a+")
  if ok then return f end
  return nil
end

local function log_append(text)
  if not log_path or text == nil or text == "" then return end
  local f = io.open(log_path, "a+")
  if not f then return end
  local size = f:seek("end") or 0
  if size + #text + 1 > log_limit then
    rotate_log(f, size)
    f = io.open(log_path, "a+")
    if not f then return end
  end
  f:write(text, "\n")
  f:close()
  log_written = log_written + #text + 1
end

local function ensure_log_path(env)
  if log_path then return end
  pcall(function()
    local cfg = env.engine.schema.config
    local dir_name = cfg:get_string("recent_commits/log_dir")
    if not dir_name or dir_name == "" then dir_name = "custom_phrase" end
    local file = cfg:get_string("recent_commits/log_file")
    local device = cfg:get_string("recent_commits/device")
    local kb = cfg:get_int("recent_commits/log_max_kb") or 0
    if kb > 0 then log_limit = kb * 1024 end

    local tag = platform_tag()
    if device and device ~= "" then tag = device end

    local name
    if file and file:find("%.log$") then
      name = file -- 旧配置直接写文件名：原样用，不加平台后缀
    else
      local base = file
      if not base or base == "" then base = "recent_commits" end
      name = base .. "_" .. tag .. ".log"
    end

    -- 显式路径优先：想在手机上抽查时可以把它写死在 schema 里
    local explicit = cfg:get_string("recent_commits/log_path")
    local targets = {}
    if explicit and explicit ~= "" then
      targets[#targets + 1] = explicit
    else
      for _, root in ipairs(log_dirs(tag)) do
        targets[#targets + 1] = root .. "/" .. dir_name .. "/" .. name
        targets[#targets + 1] = root .. "/" .. name
      end
    end

    for _, target in ipairs(targets) do
      local f = try_open(target)
      if f then
        log_written = f:seek("end") or 0
        f:close()
        log_path = target
        return
      end
    end
  end)
end

local function remember_one(text)
  if not text or text == "" then return end
  for i = #history, 1, -1 do
    if history[i] == text then table.remove(history, i) end
  end
  table.insert(history, 1, text)
  while #history > MAX do table.remove(history) end
end

-- 一次上屏多行（Ctrl+J 批量）时，按行拆开记：Z 列表里不会出现一整块，
-- 日志也是一条一行（方便对着日志逐条找回被吞掉的字）
local last_text, last_clock = nil, -1

local function remember(text)
  if not text or text == "" then return end
  text = text:gsub("\r", "")
  -- 同一次上屏可能被多个回调看到（或引擎连发），0.05 秒内的同文本只记一次；
  -- 手打重复同样的字不可能这么快，不会误伤。
  local now = os.clock()
  if text == last_text and (now - last_clock) < 0.05 then return end
  last_text, last_clock = text, now
  local lines = {}
  for line in text:gmatch("[^\n]+") do lines[#lines + 1] = line end
  if #lines == 0 then return end
  for i = #lines, 1, -1 do remember_one(lines[i]) end
  for _, line in ipairs(lines) do log_append(line) end
end

-- 供 lua/commit_current.lua 在批量上屏后直接记账（那条路 commit_text 不一定
-- 触发 commit_notifier，光靠订阅会漏记）
rawset(_G, "moqi_recent_record", remember)

-- 在会话 context 上订阅上屏事件（整个 Lua 状态只订一次）
-- 注意：不能用 context 做去重键——每次取 env.engine.context 拿到的是新的
-- userdata 包装，比较永远不相等，于是每次按键都再连一个回调，一次上屏就被
-- 记成十几条。这里用布尔标记，只连一次。
local function ensure_hook(env)
  if rawget(_G, "moqi_recent_hooked") then return end
  local ctx = env and env.engine and env.engine.context
  if not ctx then return end
  local ok = pcall(function()
    ctx.commit_notifier:connect(function(c)
      if rawget(_G, "moqi_recent_recording") then return end
      local ok2, text = pcall(function() return c:get_commit_text() end)
      if ok2 then remember(text) end
    end)
  end)
  if ok then rawset(_G, "moqi_recent_hooked", true) end
end

function M.init(env)
  pcall(function() ensure_log_path(env) end)
end

function M.func(input, env)
  ensure_log_path(env)
  ensure_hook(env)
  if env.engine.context.input == "Z" then
    local seg = env.engine.context.composition:back()
    if seg and #history > 0 then
      for _, text in ipairs(history) do
        yield(Candidate("recent_commit", seg.start, seg._end, text, ""))
      end
    end
  end
  for cand in input:iter() do
    yield(cand)
  end
end

return M