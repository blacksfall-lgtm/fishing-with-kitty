-- ============================================================================
-- DropSystem: 鱼掉落生成系统
-- ============================================================================
-- 从 main.lua 的捕获回调中提取鱼种选择、品质 roll、词条 roll 等逻辑。
-- 纯数据生成，不修改 GameState，不发放奖励。
-- ============================================================================
local GameConfig    = require("config.GameConfig")
local EconomyConfig = require("config.EconomyConfig")
local EconomySystem = require("systems.EconomySystem")
local AffixSystem   = require("systems.AffixSystem")

local DropSystem = {}

-- ========== 内部: 加权随机 ==========

--- 按权重数组随机选索引 (1-based)
---@param weights number[]
---@return number
local function weightedRandom(weights)
    local total = 0
    for _, w in ipairs(weights) do total = total + w end
    if total <= 0 then return 1 end
    local roll = math.random() * total
    local acc = 0
    for i, w in ipairs(weights) do
        acc = acc + w
        if roll <= acc then return i end
    end
    return #weights
end

-- ========== 核心: 普通捕获掉落 ==========

--- 生成一次普通捕获结果
---@param opts table { zone:string, sizeTier:string, qualityBoost:number, comboMult:number }
---@return table catchResult { fishId, fishName, displayName, icon, zone, fishType, qualityId, sizeTier, affixes, summary, valueMult, fishValue, coinValue }
function DropSystem.generateCatchResult(opts)
    local zone       = opts.zone or "nearshore"
    local sizeTier   = opts.sizeTier or "small"
    local qualityBoost = opts.qualityBoost or 0
    local comboMult  = opts.comboMult or 1.0

    -- 1. 按海域权重随机鱼种
    local zoneFish = GameConfig.FISH_BY_ZONE[zone] or GameConfig.FISH_BY_ZONE["nearshore"]
    local fishWeights = {}
    for i, f in ipairs(zoneFish) do
        fishWeights[i] = f.catchWeight
    end
    local chosenIdx = weightedRandom(fishWeights)
    local chosenFish = zoneFish[chosenIdx]

    -- 2. 品质 roll (含研发品质提升)
    local qWeights = {}
    local baseWeights = chosenFish.qualityWeights or GameConfig.DEFAULT_QUALITY_WEIGHTS
    for i, w in ipairs(baseWeights) do
        qWeights[i] = w
    end

    -- 品质提升: 每级将1点权重从品质1转移到更高品质
    if qualityBoost > 0 and #qWeights >= 3 then
        local shift = qualityBoost
        local available = math.max(0, qWeights[1] - 1)
        shift = math.min(shift, available)
        qWeights[1] = qWeights[1] - shift
        local highTiers = math.max(1, #qWeights - 2)
        for i = 3, #qWeights do
            qWeights[i] = qWeights[i] + shift / highTiers
        end
    end

    local qualityId = weightedRandom(qWeights)

    -- 3. 词条 roll (10% 基础概率)
    local affixes = AffixSystem.rollAffixes(chosenFish.id, qualityId)
    local summary = ""
    local valueMult = 1.0
    if affixes then
        summary = AffixSystem.getAffixSummary(affixes)
        valueMult = AffixSystem.calcValueMultiplier(affixes)
    end

    -- 4. 鱼价值 (通过 EconomySystem)
    local fishValue = EconomySystem.calcFishValue(chosenFish.id, qualityId, sizeTier, affixes)

    -- 5. 即时硬币 (含连击倍率)
    local coinValue = EconomySystem.calcCatchCoin(fishValue)
    if comboMult > 1.0 then
        coinValue = math.floor(coinValue * comboMult)
    end

    return {
        fishId      = chosenFish.id,
        fishName    = chosenFish.name,
        displayName = chosenFish.displayName,
        icon        = chosenFish.icon or "fish_sardine",
        zone        = chosenFish.zone,
        fishType    = chosenFish.fishType,
        qualityId   = qualityId,
        sizeTier    = sizeTier,
        affixes     = affixes,       -- nil 表示无词条
        summary     = summary,
        valueMult   = valueMult,
        fishValue   = fishValue,
        coinValue   = coinValue,
    }
end

-- ========== Boss 击败掉落 ==========

--- 生成 Boss 击败掉落 (必掉词条鱼, 2~4 词条)
---@param opts table { zone:string, bossVariant:number }
---@return table catchResult
function DropSystem.generateBossDrop(opts)
    local zone = opts.zone or "nearshore"
    local bossVariant = opts.bossVariant or 1

    -- 按当前海域随机鱼种（Boss掉落当前海域的鱼）
    local zoneFish = GameConfig.FISH_BY_ZONE[zone] or GameConfig.FISH_BY_ZONE["nearshore"]
    local chosenFish = zoneFish[math.random(1, #zoneFish)]

    -- 品质 roll (使用鱼种自身权重)
    local qWeights = chosenFish.qualityWeights or GameConfig.DEFAULT_QUALITY_WEIGHTS
    local qualityId = weightedRandom(qWeights)

    -- 必定 2~4 词条
    local affixes = AffixSystem.rollGuaranteedAffixes(2, 4)
    local summary = AffixSystem.getAffixSummary(affixes)
    local valueMult = AffixSystem.calcValueMultiplier(affixes)

    -- Boss 击败金币 (不含 fishValue, 是固定额)
    local coinValue = EconomyConfig.BOSS_DEFEAT_COIN_BASE

    return {
        fishId      = chosenFish.id,
        fishName    = chosenFish.name,
        displayName = chosenFish.displayName,
        icon        = chosenFish.icon or "fish_sardine",
        zone        = chosenFish.zone,
        fishType    = chosenFish.fishType,
        qualityId   = qualityId,
        sizeTier    = "large",
        affixes     = affixes,
        summary     = summary,
        valueMult   = valueMult,
        fishValue   = 0,          -- Boss 金币独立计算
        coinValue   = coinValue,
        isBossDrop  = true,
    }
end

-- ========== 稀有鱼捕获掉落 ==========

--- 生成稀有鱼捕获掉落 (必掉词条, 1~2 词条, 品质偏高)
---@param opts table { zone:string }
---@return table catchResult
function DropSystem.generateRareFishDrop(opts)
    local zone = opts.zone or "nearshore"

    -- 当前海域随机鱼种
    local zoneFish = GameConfig.FISH_BY_ZONE[zone] or GameConfig.FISH_BY_ZONE["nearshore"]
    local chosenFish = zoneFish[math.random(1, #zoneFish)]

    -- 品质偏高: 高品质权重 ×1.5
    local baseWeights = chosenFish.qualityWeights or GameConfig.DEFAULT_QUALITY_WEIGHTS
    local boosted = {}
    for i, w in ipairs(baseWeights) do
        boosted[i] = (i >= 3) and (w * 1.5) or w
    end
    local qualityId = weightedRandom(boosted)

    -- 必定 1~2 词条
    local affixes = AffixSystem.rollGuaranteedAffixes(1, 2)
    local summary = AffixSystem.getAffixSummary(affixes)
    local valueMult = AffixSystem.calcValueMultiplier(affixes)

    -- 稀有鱼金币
    local coinValue = EconomyConfig.RARE_FISH_COIN_BASE

    return {
        fishId      = chosenFish.id,
        fishName    = chosenFish.name,
        displayName = chosenFish.displayName,
        icon        = chosenFish.icon or "fish_sardine",
        zone        = chosenFish.zone,
        fishType    = chosenFish.fishType,
        qualityId   = qualityId,
        sizeTier    = "medium",
        affixes     = affixes,
        summary     = summary,
        valueMult   = valueMult,
        fishValue   = 0,          -- 稀有鱼金币独立计算
        coinValue   = coinValue,
        isRareFish  = true,
    }
end

return DropSystem
