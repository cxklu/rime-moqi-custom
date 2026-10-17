-- 让同文（Trime）也能用「Shift+字母 给第一个音加辅码」
--
-- 背景（桌面能用、同文不能用的原因）：
--   方案在 moqi_wan_flypymo.schema.yaml 里用 key_binder 绑定了 Shift+A..Z，
--   动作为 send_sequence "{Shift+Right}<小写字母>{Shift+Right}"；而 librime 的
--   key_binder 是**精确匹配**（keycode + modifier 一起比），没有 Shift 修饰位
--   就绝不会命中。桌面小狼毫、以及 Scrcpy 注入的硬件键盘事件都带修饰位，所以能用。
--   同文的 Shift 是键盘层的粘滞修饰键：按 Shift 再按 C，送到引擎的是
--   「大写 C、modifier 0」，匹配不到 Shift+C → C 被原样上屏（现象 vi uiC）。
--
-- 做法：
--   本处理器排在 key_binder **之前**，看到「没带修饰位的大写字母」时，
--   补一个带 Shift 的同名键事件扔回引擎，交回内置 key_binder 处理。
--   于是两端共用同一份 send_sequence，补码行为完全一致。
--
-- 只处理 A–Z；带 Shift 修饰位的（桌面 / Scrcpy）与 release 事件一律返回 2（kNoop）放行。

local M = {}

-- 防御性读取按键信息：不同 librime-lua 版本上 keycode 可能是方法、也可能是字段
-- （本机 Trime 上 key:keycode() 会报 "attempt to call a number value"）
local function read_key(key)
  local shift, release = false, false
  pcall(function() shift = key:shift() and true or false end)
  pcall(function() release = key:release() and true or false end)

  local code
  local ok, v = pcall(function() return key:keycode() end)
  if ok and type(v) == 'number' then code = v end
  if not code then
    ok, v = pcall(function() return key.keycode end)
    if ok and type(v) == 'number' then code = v end
  end
  if not code then
    -- 退路：从 repr 里认大写字母
    local ok2, repr = pcall(function() return key:repr() end)
    if ok2 and type(repr) == 'string' then
      local ch = repr:match('^([A-Z])$')
      if ch then code = string.byte(ch) end
    end
  end

  return code, shift, release
end

-- 防止重入死循环：自己合成的 Shift+字母 再次经过本处理器时必须直接放行
local busy = false

-- 构造按键事件：librime-lua 把构造器注册成**全局函数** KeyEvent(repr)，
-- 脚本里没有 rime 这个全局；sbxlm/lib.lua 里的 rime.KeyEvent 也只是包了一层全局 KeyEvent。
local function make_shift_event(ch)
  local ok, ev = pcall(function() return KeyEvent('Shift+' .. ch) end)
  if ok and ev then return ev end
  local ok2, lib = pcall(require, 'sbxlm.lib')
  if ok2 and lib and lib.KeyEvent then return lib.KeyEvent('Shift+' .. ch) end
  return nil
end

function M.func(key, env)
  if busy then return 2 end

  local code, shift, release = read_key(key)
  if not code or shift or release then return 2 end
  if code < 0x41 or code > 0x5a then return 2 end -- 只认 A–Z

  local context = env.engine.context
  if not context:is_composing() then return 2 end

  local ch = string.char(code)
  local ev = make_shift_event(ch)
  if not ev then
    log.error('[aux_shift] 无法构造 Shift+' .. ch .. ' 事件')
    return 2
  end

  local accepted
  busy = true
  local ok, err = pcall(function()
    accepted = env.engine:process_key(ev)
  end)
  busy = false
  if not ok then
    log.error('[aux_shift] 合成 Shift+' .. ch .. ' 失败: ' .. tostring(err))
    return 2
  end
  log.info('[aux_shift] 同文大写 ' .. ch .. ' → 合成 Shift+' .. ch
    .. '，被接受=' .. tostring(accepted))
  return 1 -- kAccepted
end

return M
