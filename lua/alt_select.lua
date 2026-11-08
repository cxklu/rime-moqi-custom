-- 分号/单引号次选三选（给 R / U / C / N / V 这类「数字要并进输入端」的码用）
--
-- key_binder 里的 `; → 2`、`' → 3` 是发一个数字键事件，而 recognizer 会把
-- 「R/V/… + 数字」重新匹配成输入（key_binder 转发时 redirecting，转入整条
-- 处理器链，recognizer 又吃掉了那个数字）。所以在 key_binder 之前自己接管：
-- 直接调用 Context:Select()，走的是和 selector 选中候选完全一样的路径。
local M = {}

local function page_size(env)
  local n = env.engine.schema.config:get_int("menu/page_size")
  if not n or n <= 0 then
    n = 6
  end
  return n
end

function M.func(key, env)
  local ch = key.keycode
  local index
  if ch == 0x3B then        -- ;
    index = 1               -- 0-based：第二个候选
  elseif ch == 0x27 then    -- '
    index = 2               -- 0-based：第三个候选
  else
    return 2                -- kNoop
  end

  local ctx = env.engine.context
  if not ctx:is_composing() or not ctx:has_menu() then
    return 2
  end

  -- 只接管这几个前缀：其他地方 key_binder 的默认映射照常生效
  local input = ctx.input
  if not (input:match("^[RUCVN]")) then
    return 2
  end

  local seg = ctx.composition:back()
  local ps = page_size(env)
  local page_start = math.floor(seg.selected_index / ps) * ps
  -- 和 selector 一致：选不中（页内没有第 n 个候选）也算吃掉这个键，
  -- 否则会落到 key_binder → 合成数字 → 被 recognizer 并进输入
  ctx:select(page_start + index)
  return 1                  -- kAccepted
end

return M