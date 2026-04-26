-- ============================================================================
-- BaitSystem: 饵料选择与管理
-- ============================================================================
local GameConfig = require("config.GameConfig")
local GameState  = require("state.GameState")

local BaitSystem = {}

--- 选择饵料
function BaitSystem:selectBait(baitId)
    local bait = GameConfig.BAIT_BY_ID[baitId]
    if not bait then return false end

    if baitId > 1 then
        local count = GameState.baitInventory[baitId] or 0
        if count <= 0 then
            print("[BaitSystem] 饵料不足: " .. bait.displayName)
            return false
        end
    end

    GameState.currentBaitId = baitId
    print("[BaitSystem] 切换饵料: " .. bait.displayName)
    return true
end

--- 购买饵料
function BaitSystem:buyBait(baitId, count)
    count = count or 10
    local bait = GameConfig.BAIT_BY_ID[baitId]
    if not bait then return false end

    local totalCost = bait.cost * count
    if not GameState:spendCoins(totalCost) then
        print("[BaitSystem] 金币不足")
        return false
    end

    GameState.baitInventory[baitId] = (GameState.baitInventory[baitId] or 0) + count
    print(string.format("[BaitSystem] 购买 %s x%d, 花费 %d 金币",
        bait.displayName, count, totalCost))
    return true
end

--- 获取当前饵料信息
function BaitSystem:getCurrentBait()
    return GameConfig.BAIT_BY_ID[GameState.currentBaitId]
end

--- 获取饵料数量
function BaitSystem:getBaitCount(baitId)
    if baitId == 1 then return 999 end  -- 基础鱼饵无限
    return GameState.baitInventory[baitId] or 0
end

return BaitSystem
