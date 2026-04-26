-- ============================================================================
-- MathUtils: 数学工具函数
-- ============================================================================
local MathUtils = {}

--- 加权随机选择
---@param items table 选项列表
---@param weights table 对应权重列表
---@return number 选中的索引
function MathUtils.weightedRandom(items, weights)
    local totalWeight = 0
    for i = 1, #weights do
        totalWeight = totalWeight + weights[i]
    end
    local roll = math.random() * totalWeight
    local cumulative = 0
    for i = 1, #weights do
        cumulative = cumulative + weights[i]
        if roll <= cumulative then
            return i
        end
    end
    return #items
end

--- 线性插值
function MathUtils.lerp(a, b, t)
    return a + (b - a) * t
end

--- 限制范围
function MathUtils.clamp(v, minVal, maxVal)
    if v < minVal then return minVal end
    if v > maxVal then return maxVal end
    return v
end

--- 角度转弧度
function MathUtils.deg2rad(deg)
    return deg * math.pi / 180
end

--- 简单缓动（ease out cubic）
function MathUtils.easeOutCubic(t)
    return 1 - (1 - t) ^ 3
end

--- 简单缓动（ease in out sine）
function MathUtils.easeInOutSine(t)
    return -(math.cos(math.pi * t) - 1) / 2
end

return MathUtils
