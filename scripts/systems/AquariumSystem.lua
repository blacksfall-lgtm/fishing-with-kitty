-- ============================================================================
-- AquariumSystem: 鱼缸系统 - 放入鱼获得全局Buff
-- ============================================================================
local GameConfig     = require("config.GameConfig")
local GameState      = require("state.GameState")
local AffixSystem    = require("systems.AffixSystem")
local ResearchSystem = require("systems.ResearchSystem")
local EconomySystem  = require("systems.EconomySystem")

local AquariumSystem = {}

AquariumSystem.onIncome = nil  -- function(totalGold) 收入回调

--- 每帧更新：定期产出金币
function AquariumSystem:update(dt)
    -- 检查是否有鱼在鱼缸中
    local hasFish = false
    for i = 1, GameState.unlockedAquariumSlots do
        if GameState.aquariumSlots[i] then
            hasFish = true
            break
        end
    end
    if not hasFish then
        GameState.aquariumIncomeTimer = 0
        return
    end

    local interval = GameConfig.AQUARIUM.INCOME.INTERVAL
    GameState.aquariumIncomeTimer = (GameState.aquariumIncomeTimer or 0) + dt

    if GameState.aquariumIncomeTimer >= interval then
        GameState.aquariumIncomeTimer = GameState.aquariumIncomeTimer - interval

        -- 统一计算总收入 (加法桶模型, 含研发+图鉴加成)
        local totalGold = EconomySystem.calcAquariumTotalIncome()

        if totalGold > 0 then
            GameState:addCoins(totalGold)
            print(string.format("[AquariumSystem] 鱼缸收入: +%d 金币", totalGold))
            if self.onIncome then
                self.onIncome(totalGold)
            end
        end
    end
end

--- 获取当前每周期预估收入 (含加法桶加成)
function AquariumSystem:getEstimatedIncome()
    return EconomySystem.calcAquariumTotalIncome()
end

--- 放入鱼到鱼缸（普通鱼，无词条）
function AquariumSystem:placeFish(slotIndex, fishId, qualityId)
    if slotIndex < 1 or slotIndex > GameState.unlockedAquariumSlots then
        return false, "槽位未解锁"
    end
    if GameState.aquariumSlots[slotIndex] then
        return false, "槽位已被占用"
    end

    -- 消耗一条鱼
    if not GameState:removeFish(fishId, qualityId) then
        return false, "没有这条鱼"
    end

    GameState.aquariumSlots[slotIndex] = {
        fishId = fishId,
        qualityId = qualityId,
    }

    local fishCfg = GameConfig.FISH_BY_ID[fishId]
    print(string.format("[AquariumSystem] 鱼缸槽位%d: 放入 %s (品质%d)",
        slotIndex, fishCfg.displayName, qualityId))

    -- 重算Buff
    self:recalculateBuffs()
    return true
end

--- 放入词条鱼到鱼缸
function AquariumSystem:placeFishWithAffix(slotIndex, fishId, qualityId, uid)
    if slotIndex < 1 or slotIndex > GameState.unlockedAquariumSlots then
        return false, "槽位未解锁"
    end
    if GameState.aquariumSlots[slotIndex] then
        return false, "槽位已被占用"
    end

    -- 先读取词条数据，再删除个体记录
    local indiv = GameState:getIndividualFish(uid)
    local affixes = indiv and indiv.affixes or nil

    -- 消耗个体鱼（内部也会 removeFish）
    if not GameState:removeIndividualFish(uid) then
        return false, "没有这条鱼"
    end

    GameState.aquariumSlots[slotIndex] = {
        fishId = fishId,
        qualityId = qualityId,
        affixes = affixes,
        uid = uid,  -- 保留原uid用于追溯
    }

    local fishCfg = GameConfig.FISH_BY_ID[fishId]
    local summary = affixes and AffixSystem.getAffixSummary(affixes) or ""
    print(string.format("[AquariumSystem] 鱼缸槽位%d: 放入词条鱼 %s (品质%d) [%s]",
        slotIndex, fishCfg.displayName, qualityId, summary))

    self:recalculateBuffs()
    return true
end

--- 取出鱼（归还到背包）
function AquariumSystem:removeFish(slotIndex)
    local slot = GameState.aquariumSlots[slotIndex]
    if not slot then return false end

    -- 归还鱼到背包
    GameState:addFish(slot.fishId, slot.qualityId)

    -- 如果有词条，重建个体记录
    if slot.affixes and #slot.affixes > 0 then
        local newUid = GameState:addIndividualFish(slot.fishId, slot.qualityId, slot.affixes)
        print(string.format("[AquariumSystem] 取出词条鱼 uid=%d 从鱼缸槽位%d", newUid, slotIndex))
    else
        print("[AquariumSystem] 取出鱼从鱼缸槽位" .. slotIndex)
    end

    GameState.aquariumSlots[slotIndex] = nil
    self:recalculateBuffs()
    return true
end

--- 重新计算所有Buff (委托 EconomySystem 统一公式)
function AquariumSystem:recalculateBuffs()
    -- 清零
    GameState.cachedBuffs.sushiPrice = 0
    GameState.cachedBuffs.processSpeed = 0
    GameState.cachedBuffs.coinMultiplier = 0
    GameState.cachedBuffs.comboBonus = 0

    for i = 1, GameState.unlockedAquariumSlots do
        local slot = GameState.aquariumSlots[i]
        if slot then
            local fishCfg = GameConfig.FISH_BY_ID[slot.fishId]
            if fishCfg then
                local buffType, buffValue = EconomySystem.calcAquariumBuff(
                    fishCfg.fishType, slot.qualityId, slot.affixes)
                if GameState.cachedBuffs[buffType] then
                    GameState.cachedBuffs[buffType] = GameState.cachedBuffs[buffType] + buffValue
                end
            end
        end
    end

    print(string.format("[AquariumSystem] Buff重算: 售价+%.0f%%, 速度+%.0f%%, 金币+%.0f%%, 组合+%.0f%%",
        GameState.cachedBuffs.sushiPrice * 100,
        GameState.cachedBuffs.processSpeed * 100,
        GameState.cachedBuffs.coinMultiplier * 100,
        GameState.cachedBuffs.comboBonus * 100))
end

--- 解锁新槽位
function AquariumSystem:unlockSlot()
    local next = GameState.unlockedAquariumSlots + 1
    -- 研发: 鱼缸扩建增加槽位上限
    local maxSlots = GameConfig.AQUARIUM.MAX_SLOTS + ResearchSystem.getAquariumSlotsBonus()
    if next > maxSlots then
        return false, "已达最大槽位"
    end
    local cost = GameConfig.AQUARIUM.SLOT_UNLOCK_COST[next] or 0
    if cost > 0 and not GameState:spendCoins(cost) then
        return false, "金币不足 (需要" .. cost .. ")"
    end
    GameState.unlockedAquariumSlots = next
    print("[AquariumSystem] 解锁鱼缸槽位" .. next)
    return true
end

--- 获取当前Buff汇总（用于UI展示）
function AquariumSystem:getBuffSummary()
    return {
        { name = "寿司售价", icon = "🍣", value = GameState.cachedBuffs.sushiPrice },
        { name = "加工速度", icon = "⚡", value = GameState.cachedBuffs.processSpeed },
        { name = "金币倍率", icon = "💰", value = GameState.cachedBuffs.coinMultiplier },
        { name = "组合加成", icon = "🎯", value = GameState.cachedBuffs.comboBonus },
    }
end

return AquariumSystem
