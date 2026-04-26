-- ============================================================================
-- BreedingSystem: 养殖系统 - 放入鱼后定时产出同种鱼
-- ============================================================================
local GameConfig = require("config.GameConfig")
local GameState  = require("state.GameState")

local BreedingSystem = {}

BreedingSystem.onProduce = nil  -- function(slotIndex, fishId, qualityId)

--- 放入鱼到养殖槽
function BreedingSystem:placeFish(slotIndex, fishId, qualityId)
    if slotIndex < 1 or slotIndex > GameState.unlockedBreedingSlots then
        return false, "槽位未解锁"
    end
    if GameState.breedingSlots[slotIndex] then
        return false, "槽位已被占用"
    end

    -- 消耗一条鱼
    if not GameState:removeFish(fishId, qualityId) then
        return false, "没有这条鱼"
    end

    local fishCfg = GameConfig.FISH_BY_ID[fishId]
    local qualityMulti = GameConfig.BREEDING.QUALITY_TIME_MULTI[qualityId] or 1
    local produceTime = GameConfig.BREEDING.BASE_PRODUCE_TIME * qualityMulti

    GameState.breedingSlots[slotIndex] = {
        fishId = fishId,
        qualityId = qualityId,
        timer = 0,
        produceTime = produceTime,
    }

    print(string.format("[BreedingSystem] 槽位%d: 放入 %s (品质%d), 产出周期 %.0f秒",
        slotIndex, fishCfg.displayName, qualityId, produceTime))
    return true
end

--- 取出鱼（归还到背包）
function BreedingSystem:removeFish(slotIndex)
    local slot = GameState.breedingSlots[slotIndex]
    if not slot then return false end

    GameState:addFish(slot.fishId, slot.qualityId)
    GameState.breedingSlots[slotIndex] = nil
    print("[BreedingSystem] 取出鱼从槽位" .. slotIndex)
    return true
end

--- 每帧更新：检查产出
function BreedingSystem:update(dt)
    for i = 1, GameState.unlockedBreedingSlots do
        local slot = GameState.breedingSlots[i]
        if slot then
            slot.timer = slot.timer + dt
            if slot.timer >= slot.produceTime then
                slot.timer = slot.timer - slot.produceTime

                -- 产出同品质的鱼
                GameState:addFish(slot.fishId, slot.qualityId)

                local fishCfg = GameConfig.FISH_BY_ID[slot.fishId]
                print(string.format("[BreedingSystem] 槽位%d产出: %s (品质%d)",
                    i, fishCfg.displayName, slot.qualityId))

                if self.onProduce then
                    self.onProduce(i, slot.fishId, slot.qualityId)
                end
            end
        end
    end
end

--- 解锁新槽位
function BreedingSystem:unlockSlot()
    local next = GameState.unlockedBreedingSlots + 1
    if next > GameConfig.BREEDING.MAX_SLOTS then
        return false, "已达最大槽位"
    end
    local cost = GameConfig.BREEDING.SLOT_UNLOCK_COST[next] or 0
    if cost > 0 and not GameState:spendCoins(cost) then
        return false, "金币不足 (需要" .. cost .. ")"
    end
    GameState.unlockedBreedingSlots = next
    print("[BreedingSystem] 解锁养殖槽位" .. next)
    return true
end

--- 获取槽位进度 (0~1)
function BreedingSystem:getSlotProgress(slotIndex)
    local slot = GameState.breedingSlots[slotIndex]
    if not slot then return 0 end
    return math.min(1, slot.timer / slot.produceTime)
end

--- 获取槽位剩余时间
function BreedingSystem:getSlotRemainingTime(slotIndex)
    local slot = GameState.breedingSlots[slotIndex]
    if not slot then return 0 end
    return math.max(0, slot.produceTime - slot.timer)
end

return BreedingSystem
