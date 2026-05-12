-- ============================================================================
-- GameState: 运行时状态单例
-- ============================================================================
local GameConfig = require("config.GameConfig")

local GameState = {
    -- 货币
    coins = 0,
    diamonds = 0,

    -- 鱼背包: key = "fishId_qualityId", value = count
    fishInventory = {},

    -- 当前海域
    currentZone = "nearshore",

    -- 船员槽位: { [slotIndex] = { crewId=N, level=N } }
    crewSlots = {},
    unlockedCrewSlots = 1,

    -- 合成队列（待处理区）: { [slotIndex] = { recipeId, timer, totalTime } or nil }
    synthesisQueue = {},
    unlockedSynthesisSlots = 3,

    -- 餐厅系统
    foodStock = {},         -- { [recipeId] = count } 已合成食物库存
    recipeLevels = {},      -- { [recipeId] = level } 菜谱等级 (1-10, 默认1)
    cashRegister = 0,       -- 收银台累积金币
    totalNpcServed = 0,     -- 累计服务NPC数

    -- 养殖槽: { [slotIndex] = { fishId, qualityId, timer, produceTime, parentQ } or nil }
    -- 配对繁殖: 需要两个相同鱼种, 后代随机继承父母品质
    breedingSlots = {},
    unlockedBreedingSlots = 4,

    -- 鱼缸槽: { [slotIndex] = { fishId, qualityId } or nil }
    aquariumSlots = {},
    unlockedAquariumSlots = 5,
    aquariumIncomeTimer = 0,  -- 鱼缸收入计时器

    -- 船只等级
    boatLevel = 1,

    -- 装备等级: { rod=N, net=N, bait=N, lamp=N }
    equipLevels = { rod = 1, net = 1, bait = 1, lamp = 1 },

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

    -- 词条鱼个体存储: { [uid] = {uid, fishId, qualityId, affixes={affix_id,...}} }
    fishIndividuals = {},
    nextFishUID = 1,

    -- 当前装备的鱼饵类型
    currentBait = "normal",

    -- 已发现的鱼种: { [fishId] = true }
    discoveredFish = {},

    -- 研发等级: { [researchKey] = level }
    researchLevels = {},

    -- 图鉴系统: 已收集的鱼种×品质 { ["fishId_qualityId"] = true }
    codexFishQualities = {},
    -- 图鉴系统: 已发现的词条 { [affixId] = true }
    codexAffixes = {},
    -- 图鉴系统: 已领取的奖励 { ["fish_1"] = true, ["affix_2"] = true }
    codexRewards = {},
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

--- 获取鱼仓总鱼数
function GameState:getTotalFishInHold()
    local total = 0
    for _, count in pairs(self.fishInventory) do
        total = total + count
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

--- 获取普通鱼数量（总数 - 词条鱼个体数），用于配方消耗判断
--- 词条鱼是特殊个体，不应被配方/升级自动消耗
function GameState:getNormalFishCount(fishId, qualityId)
    if qualityId then
        local total = self.fishInventory[GameState.makeFishKey(fishId, qualityId)] or 0
        local indivCount = self:getIndividualCount(fishId, qualityId)
        return math.max(0, total - indivCount)
    end
    -- 不指定品质则合计所有品质的普通鱼
    local total = 0
    for q = 1, 5 do
        local inv = self.fishInventory[GameState.makeFishKey(fishId, q)] or 0
        local indiv = self:getIndividualCount(fishId, q)
        total = total + math.max(0, inv - indiv)
    end
    return total
end

--- 检查是否有足够的普通鱼来制作寿司（排除词条鱼）
function GameState:hasIngredientsForRecipe(recipe)
    for _, ing in ipairs(recipe.ingredients) do
        if self:getNormalFishCount(ing.fishId) < ing.count then
            return false
        end
    end
    return true
end

--- 消耗配方所需的普通鱼（优先消耗低品质，排除词条鱼）
function GameState:consumeIngredientsForRecipe(recipe)
    if not self:hasIngredientsForRecipe(recipe) then return false end
    for _, ing in ipairs(recipe.ingredients) do
        local remaining = ing.count
        for q = 1, 5 do
            if remaining <= 0 then break end
            local key = GameState.makeFishKey(ing.fishId, q)
            local total = self.fishInventory[key] or 0
            local indivCount = self:getIndividualCount(ing.fishId, q)
            local normalAvail = math.max(0, total - indivCount)
            local consume = math.min(normalAvail, remaining)
            if consume > 0 then
                self.fishInventory[key] = total - consume
                if self.fishInventory[key] <= 0 then
                    self.fishInventory[key] = nil
                end
                remaining = remaining - consume
            end
        end
    end
    return true
end

-- ========== 词条鱼个体操作 ==========

--- 添加一条词条鱼个体（同时也占fishInventory的1个计数）
--- @param fishId number
--- @param qualityId number
--- @param affixes number[] 词条ID列表
--- @return number uid
function GameState:addIndividualFish(fishId, qualityId, affixes)
    local uid = self.nextFishUID
    self.nextFishUID = self.nextFishUID + 1
    self.fishIndividuals[uid] = {
        uid = uid,
        fishId = fishId,
        qualityId = qualityId,
        affixes = affixes or {},
    }
    print(string.format("[GameState] 词条鱼入库: uid=%d fish=%d quality=%d 词条数=%d",
        uid, fishId, qualityId, #(affixes or {})))
    return uid
end

--- 移除一条词条鱼个体（同时从fishInventory减1）
--- @param uid number
--- @return boolean
function GameState:removeIndividualFish(uid)
    local ind = self.fishIndividuals[uid]
    if not ind then return false end
    -- 从计数背包减1
    self:removeFish(ind.fishId, ind.qualityId, 1)
    self.fishIndividuals[uid] = nil
    return true
end

--- 获取词条鱼个体数据
--- @param uid number
--- @return table|nil
function GameState:getIndividualFish(uid)
    return self.fishIndividuals[uid]
end

--- 获取某种鱼的所有词条个体
--- @param fishId number
--- @return table[]
function GameState:getIndividualsByFishId(fishId)
    local result = {}
    for _, ind in pairs(self.fishIndividuals) do
        if ind.fishId == fishId then
            table.insert(result, ind)
        end
    end
    return result
end

--- 获取所有词条鱼个体
--- @return table
function GameState:getAllIndividuals()
    return self.fishIndividuals
end

--- 获取某种鱼的词条鱼数量
--- @param fishId number
--- @param qualityId number|nil
--- @return number
function GameState:getIndividualCount(fishId, qualityId)
    local count = 0
    for _, ind in pairs(self.fishIndividuals) do
        if ind.fishId == fishId then
            if qualityId == nil or ind.qualityId == qualityId then
                count = count + 1
            end
        end
    end
    return count
end

-- ========== 食物库存操作 ==========

function GameState:addFood(recipeId, count)
    count = count or 1
    self.foodStock[recipeId] = (self.foodStock[recipeId] or 0) + count
end

function GameState:getFoodCount(recipeId)
    return self.foodStock[recipeId] or 0
end

function GameState:removeFood(recipeId, count)
    count = count or 1
    local current = self.foodStock[recipeId] or 0
    if current < count then return false end
    self.foodStock[recipeId] = current - count
    if self.foodStock[recipeId] <= 0 then
        self.foodStock[recipeId] = nil
    end
    return true
end

function GameState:getTotalFoodCount()
    local total = 0
    for _, count in pairs(self.foodStock) do
        total = total + count
    end
    return total
end

-- ========== 菜谱等级操作 ==========

function GameState:getRecipeLevel(recipeId)
    return self.recipeLevels[recipeId] or 1
end

function GameState:upgradeRecipe(recipeId, cost, fishReqs)
    local cur = self:getRecipeLevel(recipeId)
    if cur >= GameConfig.RECIPE_MAX_LEVEL then return false end
    -- 检查金币
    if self.coins < cost then return false end
    -- 检查鱼材料（只检查普通鱼，排除词条鱼）
    if fishReqs then
        for _, req in ipairs(fishReqs) do
            if self:getNormalFishCount(req.fishId) < req.count then
                return false
            end
        end
    end
    -- 扣除金币
    if not self:spendCoins(cost) then return false end
    -- 扣除鱼材料（优先消耗低品质普通鱼，排除词条鱼）
    if fishReqs then
        for _, req in ipairs(fishReqs) do
            local remaining = req.count
            for q = 1, 5 do
                if remaining <= 0 then break end
                local key = GameState.makeFishKey(req.fishId, q)
                local total = self.fishInventory[key] or 0
                local indivCount = self:getIndividualCount(req.fishId, q)
                local normalAvail = math.max(0, total - indivCount)
                local consume = math.min(normalAvail, remaining)
                if consume > 0 then
                    self.fishInventory[key] = total - consume
                    if self.fishInventory[key] <= 0 then
                        self.fishInventory[key] = nil
                    end
                    remaining = remaining - consume
                end
            end
        end
    end
    self.recipeLevels[recipeId] = cur + 1
    return true
end

-- ========== 收银台操作 ==========

function GameState:addToCashRegister(amount)
    self.cashRegister = self.cashRegister + amount
end

function GameState:collectCashRegister()
    local amount = self.cashRegister
    if amount <= 0 then return 0 end
    self.cashRegister = 0
    self:addCoins(amount)
    return amount
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
        currentZone = self.currentZone,
        crewSlots = self.crewSlots,
        unlockedCrewSlots = self.unlockedCrewSlots,
        synthesisQueue = self.synthesisQueue,
        unlockedSynthesisSlots = self.unlockedSynthesisSlots,
        recipeLevels = self.recipeLevels,
        boatLevel = self.boatLevel,
        equipLevels = self.equipLevels,
        breedingSlots = self.breedingSlots,
        unlockedBreedingSlots = self.unlockedBreedingSlots,
        aquariumSlots = self.aquariumSlots,
        unlockedAquariumSlots = self.unlockedAquariumSlots,
        aquariumIncomeTimer = self.aquariumIncomeTimer,
        fishIndividuals = self.fishIndividuals,
        nextFishUID = self.nextFishUID,
        currentBait = self.currentBait,
        discoveredFish = self.discoveredFish,
        unlockedZones = self.unlockedZones,
        unlockedRecipes = self.unlockedRecipes,
        totalFishCaught = self.totalFishCaught,
        totalSushiSold = self.totalSushiSold,
        totalCoinsEarned = self.totalCoinsEarned,
        playTime = self.playTime,
        researchLevels = self.researchLevels,
        codexFishQualities = self.codexFishQualities,
        codexAffixes = self.codexAffixes,
        codexRewards = self.codexRewards,
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
    self.diamonds = 850
    self.currentZone = "nearshore"
    self.unlockedCrewSlots = 1
    self.unlockedSynthesisSlots = GameConfig.INDUSTRY.QUEUE_INITIAL_SLOTS
    self.unlockedBreedingSlots = 4
    self.unlockedAquariumSlots = 5
    self.unlockedZones = { nearshore = true, offshore = false, deepocean = false, abyss = false, legendary = false }
    self.unlockedRecipes = { [1] = true }  -- 解锁第一个寿司
    print("[GameState] 新游戏初始化完成")
end

return GameState
