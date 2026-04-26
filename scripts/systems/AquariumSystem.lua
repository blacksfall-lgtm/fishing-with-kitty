-- ============================================================================
-- AquariumSystem: 鱼缸系统 - 放入鱼获得全局Buff
-- ============================================================================
local GameConfig = require("config.GameConfig")
local GameState  = require("state.GameState")

local AquariumSystem = {}

--- 放入鱼到鱼缸
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

--- 取出鱼（归还到背包）
function AquariumSystem:removeFish(slotIndex)
    local slot = GameState.aquariumSlots[slotIndex]
    if not slot then return false end

    GameState:addFish(slot.fishId, slot.qualityId)
    GameState.aquariumSlots[slotIndex] = nil

    print("[AquariumSystem] 取出鱼从鱼缸槽位" .. slotIndex)
    self:recalculateBuffs()
    return true
end

--- 重新计算所有Buff
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
            local buffDef = GameConfig.AQUARIUM.BUFF_PER_TYPE[fishCfg.fishType]
            if buffDef then
                local qualityMulti = GameConfig.AQUARIUM.QUALITY_BUFF_MULTI[slot.qualityId] or 1
                local buffValue = buffDef.base * qualityMulti
                GameState.cachedBuffs[buffDef.type] = GameState.cachedBuffs[buffDef.type] + buffValue
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
    if next > GameConfig.AQUARIUM.MAX_SLOTS then
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
