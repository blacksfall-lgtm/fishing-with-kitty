-- ============================================================================
-- FormatUtils: 格式化工具函数
-- ============================================================================
local FormatUtils = {}

--- 去掉末尾 0 和多余小数点
---@param s string
---@return string
local function trimTrailingZeros(s)
    if s:find("%.") then
        s = s:gsub("0+$", ""):gsub("%.$", "")
    end
    return s
end

---@param n number
---@return string
function FormatUtils.formatNumber(n)
    -- K=1e3, M=1e6, B=1e9, T=1e12, Qa=1e15, Qi=1e18, Sx=1e21, Sp=1e24, Oc=1e27, No=1e30, Dc=1e33
    local tiers = {
        { 1e33, "Dc" },
        { 1e30, "No" },
        { 1e27, "Oc" },
        { 1e24, "Sp" },
        { 1e21, "Sx" },
        { 1e18, "Qi" },
        { 1e15, "Qa" },
        { 1e12, "T"  },
        { 1e9,  "B"  },
        { 1e6,  "M"  },
        { 1e3,  "K"  },
    }
    for _, tier in ipairs(tiers) do
        if n >= tier[1] then
            return trimTrailingZeros(string.format("%.2f", n / tier[1])) .. tier[2]
        end
    end
    return tostring(math.floor(n))
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
