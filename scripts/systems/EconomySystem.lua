-- ============================================================================
-- EconomySystem: 统一数值计算中枢
-- ============================================================================
-- 所有系统对"鱼值多少钱"只问这一个地方。
-- 内部 lazy require CodexSystem/ResearchSystem 以避免循环依赖。
-- ============================================================================
local GameConfig   = require("config.GameConfig")
local EconomyConfig = require("config.EconomyConfig")
local AffixSystem  = require("systems.AffixSystem")

local EconomySystem = {}

-- ========== Lazy require ==========
---@type table
local ResearchSystem_
---@type table
local CodexSystem_

local function getResearch()
    if not ResearchSystem_ then
        ResearchSystem_ = require("systems.ResearchSystem")
    end
    return ResearchSystem_
end

local function getCodex()
    if not CodexSystem_ then
        CodexSystem_ = require("systems.CodexSystem")
    end
    return CodexSystem_
end

-- ============================================================================
-- 核心: 鱼价值计算
-- ============================================================================

--- 计算鱼的标准价值
---@param fishId number
---@param qualityId number
---@param sizeTier string "small"|"medium"|"large"|"huge"
---@param affixes table|nil
---@return number fishValue
function EconomySystem.calcFishValue(fishId, qualityId, sizeTier, affixes)
    local fishCfg = GameConfig.FISH_BY_ID[fishId]
    if not fishCfg then return 0 end

    -- 区域基础价值
    local zoneBase = EconomyConfig.ZONE_BASE_VALUE[fishCfg.zone] or 10

    -- 鱼种稀有度乘数
    local rarity = fishCfg.rarity or "common"
    local rarityMult = EconomyConfig.FISH_RARITY_MULTI[rarity] or 1.0

    -- 品质乘数
    local qualityMult = EconomyConfig.QUALITY_VALUE_MULTI[qualityId] or 1.0

    -- 体型乘数
    local sizeMult = EconomyConfig.SIZE_VALUE_MULTI[sizeTier] or 1.0

    -- 词缀乘数
    local affixMult = 1.0
    if affixes and #affixes > 0 then
        affixMult = AffixSystem.calcValueMultiplier(affixes)
    end

    local value = zoneBase * rarityMult * qualityMult * sizeMult * affixMult
    return math.floor(value)
end

-- ============================================================================
-- 捕获硬币
-- ============================================================================

--- 计算捕获时的即时硬币
---@param fishValue number
---@return number
function EconomySystem.calcCatchCoin(fishValue)
    return math.max(1, math.floor(fishValue * EconomyConfig.CATCH_COIN_RATIO))
end

-- ============================================================================
-- 寿司定价 (加法桶模型)
-- ============================================================================

--- 计算寿司售价
---@param recipeId number
---@param overrideLevel number|nil
---@return number
function EconomySystem.calcSushiPrice(recipeId, overrideLevel)
    local GameState = require("state.GameState")
    local recipe = GameConfig.SUSHI_BY_ID[recipeId]
    if not recipe then return 0 end

    local level = overrideLevel or GameState:getRecipeLevel(recipeId)
    local levelMult = 1 + (level - 1) * EconomyConfig.RECIPE_PRICE_PER_LEVEL

    -- 收集加法桶中的所有加成
    local additiveBuff = 0

    -- 水族馆 Buff (寿司售价)
    additiveBuff = additiveBuff + (GameState.cachedBuffs.sushiPrice or 0)

    -- 水族馆 Buff (金币倍率, 也作用于寿司)
    additiveBuff = additiveBuff + (GameState.cachedBuffs.coinMultiplier or 0)

    -- 研发: 寿司溢价
    additiveBuff = additiveBuff + getResearch().getSushiPriceBonus()

    -- 图鉴: 寿司售价 Buff
    local codexBuffs = getCodex().getActiveBuffs()
    additiveBuff = additiveBuff + (codexBuffs.sushiPrice or 0)
    additiveBuff = additiveBuff + (codexBuffs.allBonus or 0)

    local price = recipe.basePrice * levelMult * (1 + additiveBuff)
    return math.floor(price)
end

-- ============================================================================
-- 水族馆收入 (加法桶模型)
-- ============================================================================

--- 计算单条鱼在鱼缸中的收入
---@param fishId number
---@param qualityId number
---@param affixes table|nil
---@return number
function EconomySystem.calcAquariumFishIncome(fishId, qualityId, affixes)
    local fishCfg = GameConfig.FISH_BY_ID[fishId]
    if not fishCfg then return 0 end

    -- 基础鱼价值 (不含体型, 鱼缸里的鱼不区分体型)
    local zoneBase = EconomyConfig.ZONE_BASE_VALUE[fishCfg.zone] or 10
    local rarity = fishCfg.rarity or "common"
    local rarityMult = EconomyConfig.FISH_RARITY_MULTI[rarity] or 1.0
    local qualityMult = EconomyConfig.QUALITY_VALUE_MULTI[qualityId] or 1.0
    local affixMult = 1.0
    if affixes and #affixes > 0 then
        affixMult = AffixSystem.calcValueMultiplier(affixes)
    end

    local cfg = EconomyConfig.AQUARIUM_INCOME
    local income = cfg.BASE_PER_FISH + zoneBase * rarityMult * qualityMult * affixMult * cfg.VALUE_RATIO
    return math.floor(income)
end

--- 计算鱼缸总收入 (一个周期)
---@return number
function EconomySystem.calcAquariumTotalIncome()
    local GameState = require("state.GameState")
    local total = 0
    for i = 1, GameState.unlockedAquariumSlots do
        local slot = GameState.aquariumSlots[i]
        if slot then
            total = total + EconomySystem.calcAquariumFishIncome(
                slot.fishId, slot.qualityId, slot.affixes)
        end
    end

    -- 加法桶: 研发 + 图鉴
    local additiveBuff = 0
    additiveBuff = additiveBuff + getResearch().getAquariumIncomeBonus()
    local codexBuffs = getCodex().getActiveBuffs()
    additiveBuff = additiveBuff + (codexBuffs.coinBonus or 0)
    additiveBuff = additiveBuff + (codexBuffs.allBonus or 0)

    return math.floor(total * (1 + additiveBuff))
end

-- ============================================================================
-- 装备升级费用
-- ============================================================================

--- 计算装备升级费用
---@param equipId string "rod"|"net"|"bait"|"lamp"
---@param currentLevel number
---@return number
function EconomySystem.calcEquipUpgradeCost(equipId, currentLevel)
    local ecfg = EconomyConfig.EQUIPMENT[equipId]
    if not ecfg then return 999999 end
    return math.floor(ecfg.baseCost * (currentLevel + 1) ^ ecfg.costScale)
end

-- ============================================================================
-- 研发升级费用
-- ============================================================================

--- 计算研发项升级费用
---@param key string 研发项 key
---@return number
function EconomySystem.calcResearchUpgradeCost(key)
    local cfg = GameConfig.RESEARCH_BY_KEY[key]
    if not cfg then return 999999 end
    local level = getResearch().getLevel(key)
    return math.floor(cfg.baseCost * (level + 1) ^ cfg.costScale)
end

-- ============================================================================
-- 船员升级费用
-- ============================================================================

--- 计算船员升级费用
---@param crewId number 船员配置 id
---@param currentLevel number 当前等级
---@return number
function EconomySystem.calcCrewUpgradeCost(crewId, currentLevel)
    local crewCfg = GameConfig.CREW_BY_ID[crewId]
    if not crewCfg then return 999999 end
    return math.floor(crewCfg.upgradeCostBase * (crewCfg.upgradeCostScale ^ (currentLevel - 1)))
end

-- ============================================================================
-- 海域解锁费用
-- ============================================================================

--- 获取海域解锁费用
---@param zoneKey string
---@return number
function EconomySystem.getZoneUnlockCost(zoneKey)
    return EconomyConfig.ZONE_UNLOCK_COST[zoneKey] or 0
end

-- ============================================================================
-- 水族馆 Buff 计算
-- ============================================================================

--- 计算单条鱼在鱼缸中提供的 Buff 值
---@param fishType string "producer"|"accelerator"|"amplifier"|"combo"
---@param qualityId number
---@param affixes table|nil
---@return string buffType, number buffValue
function EconomySystem.calcAquariumBuff(fishType, qualityId, affixes)
    local buffDef = EconomyConfig.AQUARIUM_BUFF_BASE[fishType]
    if not buffDef then return "unknown", 0 end

    local qualityMult = EconomyConfig.AQUARIUM_QUALITY_BUFF_MULTI[qualityId] or 1.0
    local affixMult = 1.0
    if affixes and #affixes > 0 then
        affixMult = AffixSystem.calcValueMultiplier(affixes)
    end

    return buffDef.type, buffDef.base * qualityMult * affixMult
end

return EconomySystem
