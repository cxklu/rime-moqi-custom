-- 注释上屏：把「当前选中候选的注释」直接打到光标处
--
-- 用途：
--   a → 候选「啊」→ Ctrl+P 拆字，注释变成「kk 口可」→ 按本键 → 上屏「kk 口可」
--   Ctrl+L 让注释变成「口⻖可」→ 按本键 → 上屏「口⻖可」（整字拆开、不带墨奇码）
--   词也一样：ykgd → 「应该」，注释是反查码「yg」→ 按本键 → 上屏「yg」
--
-- 为什么不用 key_binder 的 `send: commit_comment`：
--   这个动作名在 librime 里是**合法**的（key_binding_processor_impl.h 的动作表里有它，
--   小狼毫实测也能用）。但 Trime 自带的 librime 1.17.0 上同样写法不生效——
--   怀疑是 Trime 软键盘注入的合成 Ctrl+J 与物理键盘事件在引擎里走了不同路径。
--   为了两端行为一致、只维护一处，统一用 Lua 处理器（rime-lua 公开 API）。

local M = {}

-- 触发键：和主题里 I 下滑（CtrlJ → send: Control+j）对应
local TRIGGER = 'Control+j'

function M.func(key, env)
  -- 只认这一个键；只在按下时处理（release 事件放过）
  if key:repr() ~= TRIGGER then return 2 end
  if key:release() then return 2 end

  local context = env.engine.context
  if not context:is_composing() then return 2 end

  local cand = context:get_selected_candidate()
  if not cand then return 2 end

  local comment = cand.comment
  if not comment or comment == '' then return 2 end

  -- 去掉首尾空白（注释里偶尔会带前后空格）
  comment = comment:gsub('^%s+', ''):gsub('%s+$', '')
  if comment == '' then return 2 end

  env.engine:commit_text(comment)
  context:clear()
  return 1 -- kAccepted
end

return M
