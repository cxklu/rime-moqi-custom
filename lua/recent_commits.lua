-- lua/recent_commits.lua
-- 输入大写 Z 时，候选给出最近上屏过的文字：最近一次排第一，依次往下，最多 6 个。
-- 上屏历史记在模块级表里，跨会话保留；每个会话各自订阅 commit_notifier。

local M = {}
local MAX = 36
local history = {}

local function remember(text)
  if not text or text == "" then return end
  for i = #history, 1, -1 do
    if history[i] == text then table.remove(history, i) end
  end
  table.insert(history, 1, text)
  while #history > MAX do table.remove(history) end
end

function M.init(env)
  pcall(function()
    env.engine.context.commit_notifier:connect(function(ctx)
      local ok, text = pcall(function() return ctx:get_commit_text() end)
      if ok then remember(text) end
    end)
  end)
end

function M.func(input, env)
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
