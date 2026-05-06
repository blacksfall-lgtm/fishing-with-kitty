-- ============================================================================
-- AffixSystem: 鱼类词条核心逻辑 (生成/继承/价值计算)
-- ============================================================================
local AffixConfig = require("config.AffixConfig")

local AffixSystem = {}

-- ========== 工具函数 ==========

--- 按权重随机选择索引
local function weightedRandom(weights)
    local total = 0
    for _, w in ipairs(weights) do total = total + w end
    local roll = math.random() * total
    local acc = 0
    for i, w in ipairs(weights) do
        acc = acc + w
        if roll <= acc then return i end
    end
    return #weights
end

--- 随机从表中选一个元素
local function randomPick(t)
    if #t == 0 then return nil end
    return t[math.random(1, #t)]
end

--- 检查词条列表中是否已包含某词条id
local function hasAffix(affixes, affixId)
    for _, id in ipairs(affixes) do
        if id == affixId then return true end
    end
    return false
end

-- ========== 核心API ==========

--- 捕鱼时掷骰：10%概率生成1~2个初始词条
--- @param fishId number 鱼种ID
--- @param qualityId number 品质ID
--- @return number[]|nil 词条ID列表，nil表示未触发
function AffixSystem.rollAffixes(fishId, qualityId)
    -- 10%概率触发
    if math.random() > AffixConfig.ROLL_CHANCE then
        return nil
    end

    local minCount = AffixConfig.INITIAL_COUNT[1]
    local maxCount = AffixConfig.INITIAL_COUNT[2]
    local count = math.random(minCount, maxCount)

    local affixes = {}
    for _ = 1, count do
        -- 按权重选稀有度
        local rarityIdx = weightedRandom(AffixConfig.RARITY_WEIGHTS)
        -- 从该稀有度池中随机选一个不重复的词条
        local pool = AffixConfig.AFFIXES_BY_RARITY[rarityIdx]
        if pool and #pool > 0 then
            -- 过滤已有词条
            local candidates = {}
            for _, affix in ipairs(pool) do
                if not hasAffix(affixes, affix.id) then
                    table.insert(candidates, affix)
                end
            end
            local chosen = randomPick(candidates)
            if chosen then
                table.insert(affixes, chosen.id)
            end
        end
    end

    if #affixes > 0 then
        return affixes
    end
    return nil
end

--- 必定生成指定数量的词条（鱼王掉落专用，跳过概率检查）
--- @param minCount number 最少词条数
--- @param maxCount number 最多词条数
--- @return number[] 词条ID列表（保证非空）
function AffixSystem.rollGuaranteedAffixes(minCount, maxCount)
    local count = math.random(minCount, maxCount)
    local affixes = {}
    for _ = 1, count do
        local rarityIdx = weightedRandom(AffixConfig.RARITY_WEIGHTS)
        local pool = AffixConfig.AFFIXES_BY_RARITY[rarityIdx]
        if pool and #pool > 0 then
            local candidates = {}
            for _, affix in ipairs(pool) do
                if not hasAffix(affixes, affix.id) then
                    table.insert(candidates, affix)
                end
            end
            local chosen = randomPick(candidates)
            if chosen then
                table.insert(affixes, chosen.id)
            end
        end
    end
    -- 保底: 如果因去重导致不足，从全池补充
    if #affixes < minCount then
        for _, affix in ipairs(AffixConfig.AFFIXES) do
            if not hasAffix(affixes, affix.id) then
                table.insert(affixes, affix.id)
                if #affixes >= minCount then break end
            end
        end
    end
    return affixes
end

--- 帕鲁式词条继承：合并双亲词条池，逐条概率继承，可能变异
--- @param parent1Affixes number[] 父本词条ID列表
--- @param parent2Affixes number[] 母本词条ID列表
--- @return number[] 子代词条ID列表
function AffixSystem.inheritAffixes(parent1Affixes, parent2Affixes)
    parent1Affixes = parent1Affixes or {}
    parent2Affixes = parent2Affixes or {}

    -- 1. 合并候选池 (去重)
    local candidateSet = {}
    local candidateList = {}
    for _, id in ipairs(parent1Affixes) do
        if not candidateSet[id] then
            candidateSet[id] = true
            table.insert(candidateList, id)
        end
    end
    for _, id in ipairs(parent2Affixes) do
        if not candidateSet[id] then
            candidateSet[id] = true
            table.insert(candidateList, id)
        end
    end

    -- 2. 双亲共有词条优先继承 (更高概率)
    local sharedSet = {}
    for _, id in ipairs(parent1Affixes) do
        for _, id2 in ipairs(parent2Affixes) do
            if id == id2 then sharedSet[id] = true end
        end
    end

    -- 3. 逐条按概率继承
    local childAffixes = {}
    for _, affixId in ipairs(candidateList) do
        if #childAffixes >= AffixConfig.MAX_AFFIXES then break end

        local affix = AffixConfig.AFFIX_BY_ID[affixId]
        if affix then
            local chance = AffixConfig.INHERIT.BASE_CHANCE
                + (AffixConfig.INHERIT.RARITY_BONUS[affix.rarity] or 0)
            -- 双亲共有词条+20%继承概率
            if sharedSet[affixId] then
                chance = chance + 0.20
            end
            if math.random() < chance then
                table.insert(childAffixes, affixId)
            end
        end
    end

    -- 4. 变异: 5%概率额外获得一个新词条
    if #childAffixes < AffixConfig.MAX_AFFIXES then
        if math.random() < AffixConfig.INHERIT.MUTATION_CHANCE then
            local rarityIdx = weightedRandom(AffixConfig.RARITY_WEIGHTS)
            local pool = AffixConfig.AFFIXES_BY_RARITY[rarityIdx]
            if pool and #pool > 0 then
                local candidates = {}
                for _, affix in ipairs(pool) do
                    if not hasAffix(childAffixes, affix.id) then
                        table.insert(candidates, affix)
                    end
                end
                local chosen = randomPick(candidates)
                if chosen then
                    table.insert(childAffixes, chosen.id)
                    print(string.format("[AffixSystem] 变异! 获得新词条: %s", chosen.displayName))
                end
            end
        end
    end

    return childAffixes
end

--- 计算词条带来的价值倍率
--- @param affixes number[] 词条ID列表
--- @return number 价值倍率 (1.0 = 无加成)
function AffixSystem.calcValueMultiplier(affixes)
    if not affixes or #affixes == 0 then return 1.0 end
    local bonus = 0
    for _, affixId in ipairs(affixes) do
        local affix = AffixConfig.AFFIX_BY_ID[affixId]
        if affix then
            bonus = bonus + affix.valueBonus
        end
    end
    return 1.0 + bonus
end

--- 计算词条带来的体型缩放
--- @param affixes number[] 词条ID列表
--- @return number 体型缩放 (1.0 = 无变化)
function AffixSystem.calcSizeScale(affixes)
    if not affixes or #affixes == 0 then return 1.0 end
    local scale = 1.0
    for _, affixId in ipairs(affixes) do
        local affix = AffixConfig.AFFIX_BY_ID[affixId]
        if affix then
            scale = scale * affix.sizeScale
        end
    end
    return scale
end

--- 计算词条带来的颜色偏移 (叠加所有colorTint)
--- @param affixes number[] 词条ID列表
--- @return number r, number g, number b, number a 颜色偏移值
function AffixSystem.calcColorTint(affixes)
    if not affixes or #affixes == 0 then return 0, 0, 0, 0 end
    local r, g, b, a = 0, 0, 0, 0
    for _, affixId in ipairs(affixes) do
        local affix = AffixConfig.AFFIX_BY_ID[affixId]
        if affix and affix.colorTint then
            r = r + affix.colorTint[1]
            g = g + affix.colorTint[2]
            b = b + affix.colorTint[3]
            a = a + affix.colorTint[4]
        end
    end
    return r, g, b, a
end

--- 是否满词条 (8个)
--- @param affixes number[] 词条ID列表
--- @return boolean
function AffixSystem.isFullAffix(affixes)
    return affixes ~= nil and #affixes >= AffixConfig.MAX_AFFIXES
end

--- 获取词条列表中最高稀有度
--- @param affixes number[] 词条ID列表
--- @return number 最高稀有度 (1-4), 0表示无词条
function AffixSystem.getHighestRarity(affixes)
    if not affixes or #affixes == 0 then return 0 end
    local maxRarity = 0
    for _, affixId in ipairs(affixes) do
        local affix = AffixConfig.AFFIX_BY_ID[affixId]
        if affix and affix.rarity > maxRarity then
            maxRarity = affix.rarity
        end
    end
    return maxRarity
end

--- 获取词条简短描述 (用于UI徽章)
--- @param affixes number[] 词条ID列表
--- @return string 如 "2绿1蓝" 
function AffixSystem.getAffixSummary(affixes)
    if not affixes or #affixes == 0 then return "" end
    local counts = {0, 0, 0, 0}
    for _, affixId in ipairs(affixes) do
        local affix = AffixConfig.AFFIX_BY_ID[affixId]
        if affix then
            counts[affix.rarity] = counts[affix.rarity] + 1
        end
    end
    local parts = {}
    local rarityNames = {"绿", "蓝", "紫", "金"}
    for i = 4, 1, -1 do  -- 从高到低
        if counts[i] > 0 then
            table.insert(parts, counts[i] .. rarityNames[i])
        end
    end
    return table.concat(parts, "")
end

return AffixSystem
