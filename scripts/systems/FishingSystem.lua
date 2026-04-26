-- ============================================================================
-- FishingSystem: 捕鱼状态机 + 鱼池抽取 + 品质roll
-- ============================================================================
local GameConfig = require("config.GameConfig")
local GameState  = require("state.GameState")
local MathUtils  = require("utils.MathUtils")

local FishingSystem = {}

-- 状态枚举
FishingSystem.STATE = {
    IDLE     = "idle",
    CASTING  = "casting",
    WAITING  = "waiting",
    REELING  = "reeling",
    CAUGHT   = "caught",
}

-- 运行时状态
FishingSystem.state = "idle"
FishingSystem.stateTimer = 0
FishingSystem.waitTarget = 0
FishingSystem.lastCatch = nil      -- { fishId, qualityId, fishData, qualityData }
FishingSystem.autoFishing = false
FishingSystem.autoTimer = 0

-- 回调
FishingSystem.onStateChange = nil   -- function(newState)
FishingSystem.onCatch = nil         -- function(catchInfo)

--- 开始钓鱼
function FishingSystem:cast()
    if self.state ~= "idle" then return false end

    -- 消耗饵料（基础鱼饵无限）
    local baitId = GameState.currentBaitId
    if baitId > 1 then
        local count = GameState.baitInventory[baitId] or 0
        if count <= 0 then
            print("[FishingSystem] 饵料不足，切换为基础鱼饵")
            GameState.currentBaitId = 1
            baitId = 1
        else
            -- 检查饵料手是否触发不消耗
            local saveBait = false
            for _, slot in pairs(GameState.crewSlots) do
                if slot and GameConfig.CREW_BY_ID[slot.crewId].type == "baiter" then
                    local bonus = GameConfig.CREW_BY_ID[slot.crewId].baseBonus
                        + GameConfig.CREW_BY_ID[slot.crewId].bonusPerLevel * (slot.level - 1)
                    if math.random() < bonus then
                        saveBait = true
                    end
                end
            end
            if not saveBait then
                GameState.baitInventory[baitId] = count - 1
            end
        end
    end

    self:setState("casting")
    self.stateTimer = 0
    return true
end

--- 更新状态机
function FishingSystem:update(dt)
    self.stateTimer = self.stateTimer + dt

    if self.state == "casting" then
        if self.stateTimer >= GameConfig.FISHING.CAST_TIME then
            self:setState("waiting")
            self.stateTimer = 0
            -- 随机等待时间（受船员加成影响）
            local minWait = GameConfig.FISHING.MIN_WAIT_TIME
            local maxWait = GameConfig.FISHING.MAX_WAIT_TIME
            local speedBonus = self:getCrewSpeedBonus()
            self.waitTarget = minWait + math.random() * (maxWait - minWait)
            self.waitTarget = self.waitTarget * (1 - speedBonus)
        end

    elseif self.state == "waiting" then
        if self.stateTimer >= self.waitTarget then
            self:setState("reeling")
            self.stateTimer = 0
        end

    elseif self.state == "reeling" then
        if self.stateTimer >= GameConfig.FISHING.REEL_TIME then
            -- 执行抽鱼
            local fishId, qualityId = self:rollCatch()
            local fishData = GameConfig.FISH_BY_ID[fishId]
            local qualityData = GameConfig.QUALITY[qualityId]

            -- 添加到背包
            GameState:addFish(fishId, qualityId)

            -- 检查捞网手：双倍捕获
            local bonusCatch = false
            for _, slot in pairs(GameState.crewSlots) do
                if slot and GameConfig.CREW_BY_ID[slot.crewId].type == "netter" then
                    local bonus = GameConfig.CREW_BY_ID[slot.crewId].baseBonus
                        + GameConfig.CREW_BY_ID[slot.crewId].bonusPerLevel * (slot.level - 1)
                    if math.random() < bonus then
                        bonusCatch = true
                    end
                end
            end
            if bonusCatch then
                local bonusFish, bonusQ = self:rollCatch()
                GameState:addFish(bonusFish, bonusQ)
                print("[FishingSystem] 捞网手触发! 额外捕获一条鱼")
            end

            self.lastCatch = {
                fishId = fishId,
                qualityId = qualityId,
                fishData = fishData,
                qualityData = qualityData,
                bonusCatch = bonusCatch,
            }

            self:setState("caught")
            self.stateTimer = 0

            if self.onCatch then
                self.onCatch(self.lastCatch)
            end
        end

    elseif self.state == "caught" then
        if self.stateTimer >= GameConfig.FISHING.CATCH_DISPLAY_TIME then
            self:setState("idle")
            self.stateTimer = 0
            self.lastCatch = nil
        end
    end

    -- 自动捕鱼
    if self.autoFishing and self.state == "idle" then
        self.autoTimer = self.autoTimer + dt
        local autoInterval = GameConfig.FISHING.AUTO_FISH_INTERVAL * (1 - self:getCrewSpeedBonus())
        if self.autoTimer >= autoInterval then
            self.autoTimer = 0
            self:cast()
        end
    end
end

--- 抽取鱼（基于海域+饵料）
function FishingSystem:rollCatch()
    local zone = GameState.currentZone
    local pool = GameConfig.FISH_BY_ZONE[zone]
    local bait = GameConfig.BAIT_BY_ID[GameState.currentBaitId]

    -- 构建权重列表
    local weights = {}
    for i, fish in ipairs(pool) do
        local w = fish.catchWeight
        -- 饵料加成
        if bait and bait.modifiers[fish.fishType] then
            w = w * bait.modifiers[fish.fishType]
        end
        weights[i] = w
    end

    local index = MathUtils.weightedRandom(pool, weights)
    local fishId = pool[index].id

    -- roll品质
    local qualityId = self:rollQuality(fishId)
    return fishId, qualityId
end

--- 品质roll
function FishingSystem:rollQuality(fishId)
    local fish = GameConfig.FISH_BY_ID[fishId]
    local weights = {}
    for i = 1, 5 do
        weights[i] = fish.qualityWeights[i]
    end

    -- 饵料品质加成
    local bait = GameConfig.BAIT_BY_ID[GameState.currentBaitId]
    if bait and bait.modifiers.qualityBoost then
        -- 提升高品质权重
        local boost = bait.modifiers.qualityBoost
        for i = 2, 5 do
            weights[i] = weights[i] * (1 + boost * i)
        end
    end

    return MathUtils.weightedRandom(GameConfig.QUALITY, weights)
end

--- 获取船员捕鱼速度加成
function FishingSystem:getCrewSpeedBonus()
    local bonus = 0
    for _, slot in pairs(GameState.crewSlots) do
        if slot then
            local crew = GameConfig.CREW_BY_ID[slot.crewId]
            if crew.type == "fisher" then
                bonus = bonus + crew.baseBonus + crew.bonusPerLevel * (slot.level - 1)
            end
        end
    end
    return MathUtils.clamp(bonus, 0, 0.8)  -- 最多减少80%
end

--- 设置状态
function FishingSystem:setState(newState)
    self.state = newState
    print("[FishingSystem] 状态: " .. newState)
    if self.onStateChange then
        self.onStateChange(newState)
    end
end

--- 获取状态进度 (0~1)
function FishingSystem:getProgress()
    if self.state == "casting" then
        return MathUtils.clamp(self.stateTimer / GameConfig.FISHING.CAST_TIME, 0, 1)
    elseif self.state == "waiting" then
        if self.waitTarget > 0 then
            return MathUtils.clamp(self.stateTimer / self.waitTarget, 0, 1)
        end
    elseif self.state == "reeling" then
        return MathUtils.clamp(self.stateTimer / GameConfig.FISHING.REEL_TIME, 0, 1)
    elseif self.state == "caught" then
        return MathUtils.clamp(self.stateTimer / GameConfig.FISHING.CATCH_DISPLAY_TIME, 0, 1)
    end
    return 0
end

return FishingSystem
