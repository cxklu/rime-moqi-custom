-- Shift+Enter：只在手机上给 Obsidian 的表格单元格插入换行
--
-- 背景：同文的 ▲ 是键盘层的粘滞修饰键，按 ▲ 再按 Enter 时，引擎收到的键是
--   "Shift+Return"（已实测：lua 里 key:repr() 能看到这个修饰位）。
--   但即便把它原样交给应用（甚至用 send: Shift+Return 直发），Obsidian 的
--   表格编辑器仍然按普通回车处理 —— 直接跳到下一行，而不是在单元格内换行。
--
-- 表格单元格里真实的「软换行」在 markdown 里就是 <br>，所以这里直接上屏
--   <br>，效果等同于桌面端 Shift+Enter：单元格内再起一行，行高不会拉开。
--
-- ⚠️ 只在手机（同文）上生效：小狼毫和同文共用这一份配置，而 Windows 的
--   shift+enter 本来就是应用自己处理的（Obsidian 桌面端按 Shift+Enter 就是
--   软换行），再插一个 <br> 反而多打一段字。所以按发行版名字把 Weasel 挡掉。
--   判别不到发行版名时，退一步看数据目录里有没有 "AppData"（Windows 路径）。
--
-- 只在「Shift+Return」时生效；普通 Enter 完全不受影响。

local M = {}

-- 是否运行在小狼毫（Windows）上
local function running_on_weasel()
  if rime_api then
     if rime_api.get_distribution_name then
        local ok, name = pcall(function() return rime_api.get_distribution_name() end)
        if ok and type(name) == 'string' and name:lower():find('weasel', 1, true) then
           return true
        end
     end
     if rime_api.get_user_data_dir then
        local ok, dir = pcall(function() return rime_api.get_user_data_dir() end)
        if ok and type(dir) == 'string' and dir:find('AppData', 1, true) then
           return true
        end
     end
  end
  return false
end

function M.func(key, env)
  local repr = ''
  local ok, v = pcall(function() return key:repr() end)
  if ok and type(v) == 'string' then repr = v end

  if repr ~= 'Shift+Return' then return 2 end -- kNoop：其余键一律放行

  local release = false
  local ok2, v2 = pcall(function() return key:release() end)
  if ok2 then release = v2 and true or false end
  if release then return 2 end

  -- 电脑上交给应用自己处理
  if running_on_weasel() then return 2 end

  env.engine:commit_text('<br>')
  return 1 -- kAccepted
end

return M
