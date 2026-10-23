--======================================================================
-- lua/super_tail.lua   链尾兜底：保证「超级简拼」一定显示出来
--
-- 为什么需要它：
--   jianma_show 站在过滤器链的前半段，它只给「它看到的第一个候选」写注释。
--   可那个候选常常是小字集之外的生僻字，会在链尾被 charset_filter 丢掉。
--   结果就是：明明有超级简拼，屏幕上却什么都没有（如 hyl = 行业里）。
--
-- 本模块挂在 charset_filter 之后、uniquifier 之前，看到的第一个候选
-- 已经是「真的会显示出来的那个」：
--   * 有候选          → 把超级简拼写进第一个候选的注释（覆盖单字辅码，先看简拼）
--   * 一个候选都没有  → 自己造一个候选，注释放 ⚡
--
-- ⚠️ 只认「第一候选」这一行：超级简拼只该出现在第一候选右侧。
--    早先的写法是「遇到第一个 text 不等于简拼词的候选就写、然后 break」，
--    结果第一候选恰好就是那个词时被跳过，标记落到了第二候选身上
--    （vyk 的「啍」右侧显示「专业课」、zzm 的「驺」右侧显示「再怎么」）。
--    现在改成：只看第一条，写完就锁。
--
-- 超级简拼表由 jianma_show 在 init 时放进全局 _G.moqi_super，这里只读不建表。
-- 参数：super_tail/super_max_code（默认 3）
--======================================================================

local M = {}

local MAX_CODE = 3

function M.init(env)
   pcall(function()
      local config = env.engine.schema.config
      local ns = (env.name_space or "super_tail"):gsub("^%*", "")
      local s = config:get_string(ns .. "/super_max_code")
      if s and tonumber(s) then MAX_CODE = tonumber(s) end
   end)
end

function M.func(input, env)
   local has_pass = false
   local tbl = rawget(_G, "moqi_super")

   -- 表还没建好（比如 jianma_show 没启用）：原样放行
   if not tbl then
      for cand in input:iter() do yield(cand) end
      return
   end

   -- 当前输入码
   local raw = ""
   local ok, cur = pcall(function() return env.engine.context.input end)
   if ok and cur then raw = cur end

   -- 超级简拼只在 1~3 码纯字母时生效
   local word = nil
   if #raw >= 1 and #raw <= MAX_CODE and raw:match("^%a+$") then
      word = tbl[raw]
   end

   local first = true
   for cand in input:iter() do
      has_pass = true
      if first then
         first = false
         -- 第一候选本身就是简拼词时不必再写；否则覆盖它的单字辅码
         if word and cand.text ~= word then
            local g = cand:get_genuine()
            g.comment = word
         end
      end
      yield(cand)
   end

   -- 一个都没剩下：把超级简拼自己变成候选，注释用 ⚡ 标记
   if not has_pass and word then
      yield(Candidate("word", 0, #word, word, "⚡"))
   end
end

return M
