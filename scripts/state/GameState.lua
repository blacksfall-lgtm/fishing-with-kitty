-- ============================================================================
-- GameState: 运行时状态单例
-- ============================================================================
local GameConfig = require("config.GameConfig")

local GameState = {
    -- 货币
    coins = 0,

    -- 鱼背包: key = "fishId_qualityId", value = count
    fishInventory = {},

    -- 饵料背包: key = baitId, value = count
    baitInventory = {},

    -- 当前选择的饵料ID
    currentBaitId = 1,

    -- 当前海域
    currentZone = "nearshore",

    -- 船员槽位: { [slotIndex] = { crewId=N, level=N } }
    crewSlots = {},
    unlockedCrewSlots = 1,

    -- 产业加工槽: { [slotIndex] = { recipeId, startTime, duration } or nil }
    processingSlots = {},
    unlockedIndustrySlots = 1,

    -- 养殖槽: { [slotIndex] = { fishId, qualityId, timer, produceTime } or nil }
    breedingSlots = {},
    unlockedBreedingSlots = 2,

    -- 鱼缸槽: { [slotIndex] = { fishId, qualityId } or nil }
    aquariumSlots = {},
    unlockedAquariumSlots = 5,

    -- 解锁进度
    unlockedZones = { nearshore = true, offshore = false },
    unlockedRecipes = {},

    -- 统计
    totalFishCaught = 0,
    totalSushiSold = 0,
    totalCoinsEarned = 0,
    playTime = 0,

    -- 缓存的Buff（由AquariumSystem计算）
    cachedBuffs = {
        sushiPrice = 0,
        processSpeed = 0,
        coinMultiplier = 0,
        comboBonus = 0,
    },
}

-- ========== 鱼背包操作 ==========

--- 生成背包key
function GameState.makeFishKey(fishId, qualityId)
    return fishId .. "_" .. qualityId
end

--- 添加鱼到背包
function GameState:addFish(fishId, qualityId, count)
    count = count or 1
    local key = GameState.makeFishKey(fishId, qualityId)
    self.fishInventory[key] = (self.fishInventory[key] or 0) + count
    self.totalFishCaught = self.totalFishCaught + count
    print(string.format("[GameState] 获得鱼: %s (品质%d) x%d, 当前持有: %d",
        GameConfig.FISH_BY_ID[fishId].displayName, qualityId, count,
        self.fishInventory[key]))
end

--- 消耗鱼
function GameState:removeFish(fishId, qualityId, count)
    count = count or 1
    local key = GameState.makeFishKey(fishId, qualityId)
    local current = self.fishInventory[key] or 0
    if current < count then return false end
    self.fishInventory[key] = current - count
    if self.fishInventory[key] <= 0 then
        self.fishInventory[key] = nil
    end
    return true
end

--- 获取某种鱼的数量
function GameState:getFishCount(fishId, qualityId)
    if qualityId then
        return self.fishInventory[GameState.makeFishKey(fishId, qualityId)] or 0
    end
    -- 不指定品质则合计所有品质
    local total = 0
    for q = 1, 5 do
        total = total + (self.fishInventory[GameState.makeFishKey(fishId, q)] or 0)
    end
    return total
end

--- 获取某种鱼中品质最低的qualityId（优先消耗低品质）
function GameState:getLowestQualityFish(fishId)
    for q = 1, 5 do
        local key = GameState.makeFishKey(fishId, q)
        if (self.fishInventory[key] or 0) > 0 then
            return q
        end
    end
    return nil
end

--- 检查是否有足够的鱼来制作寿司
function GameState:hasIngredientsForRecipe(recipe)
    for _, ing in ipairs(recipe.ingredients) do
        if self:getFishCount(ing.fishId) < ing.count then
            return false
        end
    end
    return true
end

--- 消耗配方所需的鱼（优先消耗低品质）
function GameState:consumeIngredientsForRecipe(recipe)
    if not self:hasIngredientsForRecipe(recipe) then return false end
    for _, ing in ipairs(recipe.ingredients) do
        local remaining = ing.count
        for q = 1, 5 do
            if remaining <= 0 then break end
            local key = GameState.makeFishKey(ing.fishId, q)
            local available = self.fishInventory[key] or 0
            local consume = math.min(available, remaining)
            if consume > 0 then
                self.fishInventory[key] = available - consume
                if self.fishInventory[key] <= 0 then
                    self.fishInventory[key] = nil
                end
                remaining = remaining - consume
            end
        end
    end
    return true
end

-- ========== 货币操作 ==========

function GameState:addCoins(amount)
    self.coins = self.coins + amount
    self.totalCoinsEarned = self.totalCoinsEarned + amount
end

function GameState:spendCoins(amount)
    if self.coins < amount then return false end
    self.coins = self.coins - amount
    return true
end

-- ========== 序列化/反序列化 ==========

function GameState:serialize()
    return {
        coins = self.coins,
        fishInventory = self.fishInventory,
        baitInventory = self.baitInventory,
        currentBaitId = self.currentBaitId,
        currentZone = self.currentZone,
        crewSlots = self.crewSlots,
        unlockedCrewSlots = self.unlockedCrewSlots,
        processingSlots = self.processingSlots,
        unlockedIndustrySlots = self.unlockedIndustrySlots,
        breedingSlots = self.breedingSlots,
        unlockedBreedingSlots = self.unlockedBreedingSlots,
        aquariumSlots = self.aquariumSlots,
        unlockedAquariumSlots = self.unlockedAquariumSlots,
        unlockedZones = self.unlockedZones,
        unlockedRecipes = self.unlockedRecipes,
        totalFishCaught = self.totalFishCaught,
        totalSushiSold = self.totalSushiSold,
        totalCoinsEarned = self.totalCoinsEarned,
        playTime = self.playTime,
    }
end

function GameState:deserialize(data)
    if not data then return end
    for k, v in pairs(data) do
        if self[k] ~= nil then
            self[k] = v
        end
    end
end

--- 初始化新游戏
function GameState:initNewGame()
    self.coins = GameConfig.INITIAL_COINS
    self.baitInventory = { [1] = 999 }  -- 初始大量基础鱼饵
    self.currentBaitId = 1
    self.currentZone = "nearshore"
    self.unlockedCrewSlots = 1
    self.unlockedIndustrySlots = 1
    self.unlockedBreedingSlots = 2
    self.unlockedAquariumSlots = 5
    self.unlockedZones = { nearshore = true, offshore = false }
    self.unlockedRecipes = { [1] = true }  -- 解锁第一个寿司
    print("[GameState] 新游戏初始化完成")
end

return GameState
