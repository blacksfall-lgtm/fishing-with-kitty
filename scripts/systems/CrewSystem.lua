-- ============================================================================
-- CrewSystem: 船员分配、升级、加成计算
-- ============================================================================
local GameConfig = require("config.GameConfig")
local GameState  = require("state.GameState")

local CrewSystem = {}

--- 招募船员到空闲槽位
function CrewSystem:hireCrew(crewId)
    local crewCfg = GameConfig.CREW_BY_ID[crewId]
    if not crewCfg then return false, "船员不存在" end

    -- 找空闲槽位
    local slotIndex = nil
    for i = 1, GameState.unlockedCrewSlots do
        if not GameState.crewSlots[i] then
            slotIndex = i
            break
        end
    end
    if not slotIndex then return false, "无空闲槽位" end

    -- 初始招募免费
    GameState.crewSlots[slotIndex] = {
        crewId = crewId,
        level = 1,
    }
    print(string.format("[CrewSystem] 招募 %s 到槽位 %d", crewCfg.displayName, slotIndex))
    return true
end

--- 升级船员
function CrewSystem:upgradeCrew(slotIndex)
    local slot = GameState.crewSlots[slotIndex]
    if not slot then return false, "该槽位无船员" end

    local crewCfg = GameConfig.CREW_BY_ID[slot.crewId]
    local cost = math.floor(crewCfg.upgradeCostBase * (crewCfg.upgradeCostScale ^ (slot.level - 1)))

    if not GameState:spendCoins(cost) then
        return false, "金币不足 (需要" .. cost .. ")"
    end

    slot.level = slot.level + 1
    print(string.format("[CrewSystem] %s 升级到 Lv.%d, 花费 %d",
        crewCfg.displayName, slot.level, cost))
    return true
end

--- 解雇船员
function CrewSystem:fireCrew(slotIndex)
    local slot = GameState.crewSlots[slotIndex]
    if not slot then return false end
    local crewCfg = GameConfig.CREW_BY_ID[slot.crewId]
    GameState.crewSlots[slotIndex] = nil
    print(string.format("[CrewSystem] 解雇 %s", crewCfg.displayName))
    return true
end

--- 获取某种类型船员的总加成
function CrewSystem:getCrewBonus(crewType)
    local total = 0
    for _, slot in pairs(GameState.crewSlots) do
        if slot then
            local crewCfg = GameConfig.CREW_BY_ID[slot.crewId]
            if crewCfg.type == crewType then
                total = total + crewCfg.baseBonus + crewCfg.bonusPerLevel * (slot.level - 1)
            end
        end
    end
    return total
end

--- 获取升级费用
function CrewSystem:getUpgradeCost(slotIndex)
    local slot = GameState.crewSlots[slotIndex]
    if not slot then return 0 end
    local crewCfg = GameConfig.CREW_BY_ID[slot.crewId]
    return math.floor(crewCfg.upgradeCostBase * (crewCfg.upgradeCostScale ^ (slot.level - 1)))
end

--- 获取船员显示信息
function CrewSystem:getCrewInfo(slotIndex)
    local slot = GameState.crewSlots[slotIndex]
    if not slot then return nil end
    local crewCfg = GameConfig.CREW_BY_ID[slot.crewId]
    local bonus = crewCfg.baseBonus + crewCfg.bonusPerLevel * (slot.level - 1)
    return {
        crewId = slot.crewId,
        level = slot.level,
        config = crewCfg,
        currentBonus = bonus,
        upgradeCost = self:getUpgradeCost(slotIndex),
    }
end

return CrewSystem
