-- ============================================================================
-- CodexSystem: 图鉴/收集系统
-- 记录已收集的鱼种×品质、已发现的词条，提供永久Buff奖励
-- ============================================================================
local GameConfig = require("config.GameConfig")
local GameState  = require("state.GameState")
local AffixConfig = require("config.AffixConfig")

local CodexSystem = {}

-- ========== 记录 API ==========

--- 记录一次捕获/获得（鱼种+品质+词条）
--- @param fishId number
--- @param qualityId number
--- @param affixes number[]|nil 词条ID列表
function CodexSystem.recordCatch(fishId, qualityId, affixes)
    -- 记录鱼种×品质
    local fKey = fishId .. "_" .. qualityId
    if not GameState.codexFishQualities[fKey] then
        GameState.codexFishQualities[fKey] = true
        print(string.format("[Codex] 新品质发现: fish=%d quality=%d", fishId, qualityId))
    end

    -- 记录词条
    if affixes then
        for _, affixId in ipairs(affixes) do
            if not GameState.codexAffixes[affixId] then
                GameState.codexAffixes[affixId] = true
                local affix = AffixConfig.AFFIX_BY_ID[affixId]
                if affix then
                    print(string.format("[Codex] 新词条发现: %s (%s)", affix.displayName, affix.name))
                end
            end
        end
    end
end

-- ========== 查询 API ==========

--- 获取某鱼种已收集的品质数
--- @param fishId number
--- @return number collected, number total
function CodexSystem.getFishProgress(fishId)
    local total = #GameConfig.QUALITY
    local collected = 0
    for q = 1, total do
        local key = fishId .. "_" .. q
        if GameState.codexFishQualities[key] then
            collected = collected + 1
        end
    end
    return collected, total
end

--- 检查某鱼种的某品质是否已收集
--- @param fishId number
--- @param qualityId number
--- @return boolean
function CodexSystem.hasFishQuality(fishId, qualityId)
    return GameState.codexFishQualities[fishId .. "_" .. qualityId] == true
end

--- 获取某稀有度词条的收集进度
--- @param rarityId number
--- @return number collected, number total
function CodexSystem.getAffixProgress(rarityId)
    local affixes = AffixConfig.AFFIXES_BY_RARITY[rarityId]
    if not affixes then return 0, 0 end
    local total = #affixes
    local collected = 0
    for _, affix in ipairs(affixes) do
        if GameState.codexAffixes[affix.id] then
            collected = collected + 1
        end
    end
    return collected, total
end

--- 检查某词条是否已发现
--- @param affixId number
--- @return boolean
function CodexSystem.hasAffix(affixId)
    return GameState.codexAffixes[affixId] == true
end

--- 鱼图鉴是否已完成（全品质收集）
--- @param fishId number
--- @return boolean
function CodexSystem.isFishComplete(fishId)
    local c, t = CodexSystem.getFishProgress(fishId)
    return c >= t
end

--- 词条稀有度是否已完成（该稀有度全词条收集）
--- @param rarityId number
--- @return boolean
function CodexSystem.isAffixRarityComplete(rarityId)
    local c, t = CodexSystem.getAffixProgress(rarityId)
    return c >= t
end

-- ========== 奖励 API ==========

--- 领取鱼图鉴奖励
--- @param fishId number
--- @return boolean success
function CodexSystem.claimFishReward(fishId)
    local rewardKey = "fish_" .. fishId
    if GameState.codexRewards[rewardKey] then return false end  -- 已领取
    if not CodexSystem.isFishComplete(fishId) then return false end  -- 未完成
    GameState.codexRewards[rewardKey] = true
    local reward = GameConfig.CODEX_FISH_REWARD_BY_ID[fishId]
    if reward then
        print(string.format("[Codex] 领取鱼图鉴奖励: fish=%d %s +%.0f%%",
            fishId, reward.rewardType, reward.value * 100))
    end
    return true
end

--- 领取词条图鉴奖励
--- @param rarityId number
--- @return boolean success
function CodexSystem.claimAffixReward(rarityId)
    local rewardKey = "affix_" .. rarityId
    if GameState.codexRewards[rewardKey] then return false end
    if not CodexSystem.isAffixRarityComplete(rarityId) then return false end
    GameState.codexRewards[rewardKey] = true
    local reward = GameConfig.CODEX_AFFIX_REWARD_BY_RARITY[rarityId]
    if reward then
        print(string.format("[Codex] 领取词条图鉴奖励: rarity=%d %s +%.0f%%",
            rarityId, reward.rewardType, reward.value * 100))
    end
    return true
end

--- 鱼图鉴奖励是否已领取
--- @param fishId number
--- @return boolean
function CodexSystem.isFishRewardClaimed(fishId)
    return GameState.codexRewards["fish_" .. fishId] == true
end

--- 词条图鉴奖励是否已领取
--- @param rarityId number
--- @return boolean
function CodexSystem.isAffixRewardClaimed(rarityId)
    return GameState.codexRewards["affix_" .. rarityId] == true
end

-- ========== Buff 汇总 ==========

--- 获取所有已激活的图鉴Buff
--- @return table { coinBonus=N, sushiPrice=N, processSpeed=N, comboBonus=N, catchValue=N, affixChance=N, breedMutation=N, allBonus=N }
function CodexSystem.getActiveBuffs()
    local buffs = {
        coinBonus = 0,
        sushiPrice = 0,
        processSpeed = 0,
        comboBonus = 0,
        catchValue = 0,
        affixChance = 0,
        breedMutation = 0,
        allBonus = 0,
    }

    -- 鱼图鉴奖励
    for _, r in ipairs(GameConfig.CODEX_FISH_REWARDS) do
        if GameState.codexRewards["fish_" .. r.fishId] then
            buffs[r.rewardType] = (buffs[r.rewardType] or 0) + r.value
        end
    end

    -- 词条图鉴奖励
    for _, r in ipairs(GameConfig.CODEX_AFFIX_REWARDS) do
        if GameState.codexRewards["affix_" .. r.rarityId] then
            buffs[r.rewardType] = (buffs[r.rewardType] or 0) + r.value
        end
    end

    return buffs
end

--- 获取总体收集进度
--- @return number fishCollected, number fishTotal, number affixCollected, number affixTotal
function CodexSystem.getOverallProgress()
    local fishCollected = 0
    local fishTotal = #GameConfig.FISH * #GameConfig.QUALITY
    for _ in pairs(GameState.codexFishQualities) do
        fishCollected = fishCollected + 1
    end

    local affixCollected = 0
    local affixTotal = #AffixConfig.AFFIXES
    for _ in pairs(GameState.codexAffixes) do
        affixCollected = affixCollected + 1
    end

    return fishCollected, fishTotal, affixCollected, affixTotal
end

return CodexSystem
