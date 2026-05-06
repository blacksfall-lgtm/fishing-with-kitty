-- ============================================================================
-- ResearchSystem: 研发系统 - 永久科技树升级
-- ============================================================================
local GameConfig = require("config.GameConfig")
local GameState  = require("state.GameState")

local ResearchSystem = {}

-- ============================================================================
-- 核心 API
-- ============================================================================

--- 获取研发等级 (0 = 未研发)
---@param key string
---@return number
function ResearchSystem.getLevel(key)
    return GameState.researchLevels[key] or 0
end

--- 获取当前效果值
---@param key string
---@return number
function ResearchSystem.getEffect(key)
    local cfg = GameConfig.RESEARCH_BY_KEY[key]
    if not cfg then return 0 end
    local level = ResearchSystem.getLevel(key)
    if level == 0 then
        -- 未研发: 乘法型返回1.0(无倍率), 加法型返回0
        if cfg.effectType == "multiply" then return 1.0 end
        return 0
    end
    local value = cfg.baseEffect + cfg.effectPerLevel * level
    -- 减少类效果限制下限
    if cfg.floorPercent and value < cfg.floorPercent then
        value = cfg.floorPercent
    end
    return value
end

--- 获取升级费用
---@param key string
---@return number
function ResearchSystem.getUpgradeCost(key)
    local cfg = GameConfig.RESEARCH_BY_KEY[key]
    if not cfg then return 999999 end
    local level = ResearchSystem.getLevel(key)
    return math.floor(cfg.baseCost * (level + 1) ^ cfg.costScale)
end

--- 是否可以升级
---@param key string
---@return boolean
function ResearchSystem.canUpgrade(key)
    local cfg = GameConfig.RESEARCH_BY_KEY[key]
    if not cfg then return false end
    local level = ResearchSystem.getLevel(key)
    if level >= cfg.maxLevel then return false end
    local cost = ResearchSystem.getUpgradeCost(key)
    return GameState.coins >= cost
end

--- 是否已满级
---@param key string
---@return boolean
function ResearchSystem.isMaxLevel(key)
    local cfg = GameConfig.RESEARCH_BY_KEY[key]
    if not cfg then return true end
    return ResearchSystem.getLevel(key) >= cfg.maxLevel
end

--- 执行升级
---@param key string
---@return boolean success
---@return string|nil errMsg
function ResearchSystem.upgrade(key)
    local cfg = GameConfig.RESEARCH_BY_KEY[key]
    if not cfg then return false, "研发项不存在" end
    local level = ResearchSystem.getLevel(key)
    if level >= cfg.maxLevel then return false, "已达最高等级" end
    local cost = ResearchSystem.getUpgradeCost(key)
    if not GameState:spendCoins(cost) then return false, "金币不足" end
    GameState.researchLevels[key] = level + 1
    print(string.format("[ResearchSystem] 升级 %s: Lv%d → Lv%d (花费%d)",
        cfg.displayName, level, level + 1, cost))
    return true
end

-- ============================================================================
-- 便利查询方法 (各系统直接调用)
-- ============================================================================

--- 捕鱼: 鱼群密度倍率 (>= 1.0)
function ResearchSystem.getDensityBonus()
    return ResearchSystem.getEffect("fish_density")
end

--- 捕鱼: 波次间隔倍率 (<= 1.0, 越小越快)
function ResearchSystem.getWaveIntervalMultiplier()
    return ResearchSystem.getEffect("wave_interval")
end

--- 捕鱼: 鱼仓额外容量
function ResearchSystem.getHoldCapacityBonus()
    return ResearchSystem.getEffect("hold_capacity")
end

--- 产业: 寿司售价倍率 (>= 1.0)
function ResearchSystem.getSushiPriceBonus()
    local eff = ResearchSystem.getEffect("sushi_price")
    -- multiply 类型, 返回额外倍率部分 (effect - 1.0)
    return eff - 1.0
end

--- 产业: 合成速度倍率 (>= 1.0, 越大越快)
function ResearchSystem.getSynthesisSpeedMultiplier()
    return ResearchSystem.getEffect("synthesis_speed")
end

--- 产业: NPC到来间隔倍率 (<= 1.0, 越小越快)
function ResearchSystem.getNpcFrequencyMultiplier()
    return ResearchSystem.getEffect("npc_frequency")
end

--- 鱼缸: 收入额外倍率部分
function ResearchSystem.getAquariumIncomeBonus()
    local eff = ResearchSystem.getEffect("aquarium_income")
    return eff - 1.0
end

--- 鱼缸: 额外槽位数
function ResearchSystem.getAquariumSlotsBonus()
    return math.floor(ResearchSystem.getEffect("aquarium_slots"))
end

--- 养殖: 繁殖速度倍率 (>= 1.0, 越大越快)
function ResearchSystem.getBreedSpeedMultiplier()
    return ResearchSystem.getEffect("breed_speed")
end

--- 养殖: 额外槽位数
function ResearchSystem.getBreedSlotsBonus()
    return math.floor(ResearchSystem.getEffect("breed_slots"))
end

--- 养殖: 品质提升权重偏移值
function ResearchSystem.getQualityBoost()
    return math.floor(ResearchSystem.getEffect("quality_boost"))
end

return ResearchSystem
