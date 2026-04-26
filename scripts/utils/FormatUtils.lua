-- ============================================================================
-- FormatUtils: 格式化工具函数
-- ============================================================================
local FormatUtils = {}

--- 数字格式化（1000->1K, 1000000->1M）
---@param n number
---@return string
function FormatUtils.formatNumber(n)
    if n >= 1e12 then
        return string.format("%.2fT", n / 1e12)
    elseif n >= 1e9 then
        return string.format("%.2fB", n / 1e9)
    elseif n >= 1e6 then
        return string.format("%.2fM", n / 1e6)
    elseif n >= 1e4 then
        return string.format("%.2fK", n / 1e3)
    else
        return tostring(math.floor(n))
    end
end

--- 时间格式化（秒->分:秒）
---@param seconds number
---@return string
function FormatUtils.formatTime(seconds)
    seconds = math.max(0, math.floor(seconds))
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    return string.format("%d:%02d", m, s)
end

--- 百分比格式化
---@param value number 0-1
---@return string
function FormatUtils.formatPercent(value)
    return string.format("%d%%", math.floor(value * 100))
end

return FormatUtils
