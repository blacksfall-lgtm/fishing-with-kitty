-- ============================================================================
-- IndustrySystem: 寿司加工队列 + 自动出售
-- ============================================================================
local GameConfig = require("config.GameConfig")
local GameState  = require("state.GameState")

local IndustrySystem = {}

IndustrySystem.onSushiComplete = nil  -- function(recipeId, sellPrice)

--- 开始加工寿司
function IndustrySystem:startProcessing(recipeId)
    local recipe = GameConfig.SUSHI_BY_ID[recipeId]
    if not recipe then return false, "配方不存在" end

    -- 找到空闲槽位
    local slotIndex = nil
    for i = 1, GameState.unlockedIndustrySlots do
        if not GameState.processingSlots[i] then
            slotIndex = i
            break
        end
    end
    if not slotIndex then return false, "加工位已满" end

    -- 检查材料
    if not GameState:hasIngredientsForRecipe(recipe) then
        return false, "材料不足"
    end

    -- 消耗材料
    GameState:consumeIngredientsForRecipe(recipe)

    -- 计算加工时间（受buff影响）
    local speedBuff = 1 + GameState.cachedBuffs.processSpeed
    local duration = recipe.processTime / speedBuff

    GameState.processingSlots[slotIndex] = {
        recipeId = recipeId,
        startTime = GameState.playTime,
        duration = duration,
    }

    print(string.format("[IndustrySystem] 开始加工: %s (槽位%d, %.1f秒)",
        recipe.displayName, slotIndex, duration))
    return true
end

--- 更新加工队列
function IndustrySystem:update(dt)
    for i = 1, GameState.unlockedIndustrySlots do
        local slot = GameState.processingSlots[i]
        if slot then
            local elapsed = GameState.playTime - slot.startTime
            if elapsed >= slot.duration then
                -- 加工完成，出售
                local recipe = GameConfig.SUSHI_BY_ID[slot.recipeId]
                local sellPrice = self:getSellPrice(slot.recipeId)

                GameState:addCoins(sellPrice)
                GameState.totalSushiSold = GameState.totalSushiSold + 1
                GameState.processingSlots[i] = nil

                print(string.format("[IndustrySystem] 寿司完成: %s, 售价: %d",
                    recipe.displayName, sellPrice))

                if self.onSushiComplete then
                    self.onSushiComplete(slot.recipeId, sellPrice)
                end
            end
        end
    end
end

--- 获取寿司售价（含buff）
function IndustrySystem:getSellPrice(recipeId)
    local recipe = GameConfig.SUSHI_BY_ID[recipeId]
    if not recipe then return 0 end

    local price = recipe.basePrice
    -- 鱼缸buff: 寿司售价加成
    price = price * (1 + GameState.cachedBuffs.sushiPrice)
    -- 金币倍率buff
    price = price * (1 + GameState.cachedBuffs.coinMultiplier)

    return math.floor(price)
end

--- 获取加工槽进度 (0~1)
function IndustrySystem:getSlotProgress(slotIndex)
    local slot = GameState.processingSlots[slotIndex]
    if not slot then return 0 end
    local elapsed = GameState.playTime - slot.startTime
    return math.min(1, elapsed / slot.duration)
end

--- 获取加工槽剩余时间
function IndustrySystem:getSlotRemainingTime(slotIndex)
    local slot = GameState.processingSlots[slotIndex]
    if not slot then return 0 end
    local elapsed = GameState.playTime - slot.startTime
    return math.max(0, slot.duration - elapsed)
end

return IndustrySystem
