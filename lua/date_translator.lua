-- 日期时间

-- 提高权重的原因：因为在方案中设置了大于 1 的 initial_quality，导致 rq sj xq dt ts 产出的候选项在所有词语的最后。
local function yield_cand(seg, text)
    local cand = Candidate('', seg.start, seg._end, text, '')
    cand.quality = 1000000
    yield(cand)
end

local M = {}

function M.init(env)
    local config = env.engine.schema.config
    env.name_space = env.name_space:gsub('^*', '')
    M.date = config:get_string(env.name_space .. '/date') or 'rq'
    M.time = config:get_string(env.name_space .. '/time') or 'sj'
    M.week = config:get_string(env.name_space .. '/week') or 'xq'
    M.datetime = config:get_string(env.name_space .. '/datetime') or 'dt'
    M.timestamp = config:get_string(env.name_space .. '/timestamp') or 'ts'
end

-- 完整日期时间（含秒）
local function is_datetime(input)
    return input == M.datetime or input == 'DT'
end

-- 日期时间（不含秒）
local function is_datetime_short(input)
    return input == 'Dt'
end

local function is_timestamp(input)
    return input == M.timestamp or input == 'Ts' or input == 'TS'
end

function M.func(input, seg, env)
    -- 日期 rq / Da
    if (input == M.date or input == 'Da') then
        local current_time = os.time()
        yield_cand(seg, os.date('%Y-%m-%d', current_time))
        yield_cand(seg, os.date('%Y/%m/%d', current_time))
        yield_cand(seg, os.date('%Y.%m.%d', current_time))
        yield_cand(seg, os.date('%Y%m%d', current_time))
        yield_cand(seg, os.date('%Y年%m月%d日', current_time):gsub('年0', '年'):gsub('月0','月'))

    -- 时间 sj / Uj
    elseif (input == M.time or input == 'Uj') then
        local current_time = os.time()
        yield_cand(seg, os.date('%H:%M', current_time))
        yield_cand(seg, os.date('%H:%M:%S', current_time))

    -- 星期 xq / Wk
    elseif (input == M.week or input == 'Wk') then
        local current_time = os.time()
        local week_tab = {'日', '一', '二', '三', '四', '五', '六'}
        local text = week_tab[tonumber(os.date('%w', current_time) + 1)]
        yield_cand(seg, '周' .. text)
        yield_cand(seg, '星期' .. text)
        yield_cand(seg, '礼拜' .. text)

    -- 不带秒日期时间 Dt
    elseif is_datetime_short(input) then
        local current_time = os.time()
        yield_cand(seg, os.date('%Y-%m-%d %H:%M', current_time))
        yield_cand(seg, os.date('%Y-%m-%dT%H:%M+08:00', current_time))
        yield_cand(seg, os.date('%Y%m%d%H%M', current_time))
        yield_cand(seg, os.date('%Y年%m月%d日%H:%M', current_time):gsub('年0', '年'):gsub('月0','月'))

    -- ISO 8601/RFC 3339 完整时间 DT
    elseif is_datetime(input) then
        local current_time = os.time()
        yield_cand(seg, os.date('%Y-%m-%d %H:%M:%S', current_time))
        yield_cand(seg, os.date('%Y-%m-%dT%H:%M:%S+08:00', current_time))
        yield_cand(seg, os.date('%Y%m%d%H%M%S', current_time))
        yield_cand(seg, os.date('%Y年%m月%d日%H:%M:%S', current_time):gsub('年0', '年'):gsub('月0','月'))

    -- 时间戳 ts / Ts / TS
    elseif is_timestamp(input) then
        local current_time = os.time()
        yield_cand(seg, string.format('%d', current_time))
    end
end

return M