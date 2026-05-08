-- ============================================================================
-- IndustrySystem: 餐厅经营系统 (猫咪状态机 v3)
-- ============================================================================
-- 4桌 × 2座位 = 8 NPC 槽位
--
-- 状态机:
--   entering : 沿过道(x=0.5)从底部直线走到桌子水平位置 → 瞬移到座位
--   choosing : 5s问号("wondering") → 5s显示食物("decided") → 检查库存
--   eating   : 15s进食 → 金币提交收银台 → leaving
--   no_food  : 30s等待 → leaving
--   leaving  : 瞬移到座位水平位置过道 → 向下走出屏幕
-- ============================================================================
local GameConfig     = require("config.GameConfig")
local GameState      = require("state.GameState")
local ResearchSystem = require("systems.ResearchSystem")
local EconomySystem  = require("systems.EconomySystem")

local IndustrySystem = {}

-- ============================================================================
-- 配置
-- ============================================================================
local TABLE_COUNT             = 4
local SEATS_PER_TABLE         = 2
local TOTAL_SEATS             = TABLE_COUNT * SEATS_PER_TABLE  -- 8
local NPC_SPAWN_INTERVAL_MIN  = 2.5    -- NPC到来最短间隔(秒)
local NPC_SPAWN_INTERVAL_MAX  = 5.0    -- NPC到来最长间隔(秒)
local NPC_EAT_DURATION        = 15.0   -- 吃饭时间(秒)
local NPC_CHOOSE_WONDER       = 5.0    -- choosing阶段: 问号等待(秒)
local NPC_CHOOSE_DECIDED      = 5.0    -- choosing阶段: 显示食物等待(秒)
local NPC_CHOOSE_TOTAL        = NPC_CHOOSE_WONDER + NPC_CHOOSE_DECIDED  -- 10s
local NPC_NO_FOOD_WAIT        = 30.0   -- 没食物等待时间(秒)
local NPC_WALK_SPEED          = 0.55   -- 行走速度 (归一化 Y 坐标每秒)
local NPC_WALK_ANIM_FPS       = 6      -- 行走帧率

-- 5种猫咪类型
local CAT_TYPES = { "orange", "black", "white", "calico", "grey" }

-- ============================================================================
-- 桌子和座位布局 (归一化坐标)
-- ============================================================================

-- 4张桌子中心 (与 IndustryScene 对齐)
local TABLE_CENTERS = {
    { x = 0.264, y = 0.434 },   -- 左上
    { x = 0.724, y = 0.434 },   -- 右上
    { x = 0.264, y = 0.634 },   -- 左下
    { x = 0.724, y = 0.634 },   -- 右下
}

-- 座位相对于桌子中心的偏移 (归一化)
local SEAT_DX = { -0.154, 0.148 }   -- 左座/右座
local SEAT_DY = -0.001             -- 座位偏移

-- 过道 X 坐标 (归一化)
local AISLE_X = 0.50
-- 出入口 Y 坐标
local ENTRY_Y = 1.12
local EXIT_Y  = 1.15

-- 回调
IndustrySystem.onNpcEat   = nil  -- function(seatIdx, recipeId, price)
IndustrySystem.onCookFood = nil  -- function(recipeId)

-- ============================================================================
-- 状态
-- ============================================================================
-- seats_[i] = {
--   state         : "empty"|"entering"|"choosing"|"eating"|"no_food"|"leaving"
--   choosingPhase : "wondering"|"decided"   (仅 choosing 状态有效)
--   tableIdx      : number   所属桌子 (1-4)
--   seatInTable   : number   桌内座号 (1 or 2)
--   seatX         : number   座位归一化 X
--   seatY         : number   座位归一化 Y
--   timer         : number   计时器
--   wantRecipeId  : number   想要的配方 ID
--   catType       : string   猫咪类型
--   eatPrice      : number   本次消费金额
--   posX          : number   当前归一化位置 X
--   posY          : number   当前归一化位置 Y
--   walkTargetY   : number   行走目标 Y
--   animAge       : number   动画累计时间
--   hasFood       : boolean  库存是否有食物
-- }
local seats_ = {}
local spawnTimer_ = 0

-- ============================================================================
-- 工具: 座位位置计算
-- ============================================================================

local function getSeatPos(tableIdx, seatInTable)
    local tc = TABLE_CENTERS[tableIdx]
    return tc.x + SEAT_DX[seatInTable], tc.y + SEAT_DY
end

-- ============================================================================
-- 初始化
-- ============================================================================

function IndustrySystem:init()
    for i = 1, TOTAL_SEATS do
        seats_[i] = self:makeEmptySeat(i)
    end
    spawnTimer_ = self:randomSpawnInterval()
    print(string.format("[IndustrySystem] 餐厅系统初始化 (%d桌 × %d座 = %d席)",
        TABLE_COUNT, SEATS_PER_TABLE, TOTAL_SEATS))
end

function IndustrySystem:makeEmptySeat(seatIdx)
    local tableIdx   = math.ceil(seatIdx / SEATS_PER_TABLE)
    local seatInTable = ((seatIdx - 1) % SEATS_PER_TABLE) + 1
    local sx, sy = getSeatPos(tableIdx, seatInTable)
    return {
        state         = "empty",
        choosingPhase = nil,       -- "wondering"|"decided" (仅 choosing 有效)
        tableIdx      = tableIdx,
        seatInTable   = seatInTable,
        seatX         = sx,
        seatY         = sy,
        timer         = 0,
        wantRecipeId  = nil,
        catType       = "orange",
        eatPrice      = 0,
        posX          = AISLE_X,
        posY          = ENTRY_Y,
        walkTargetY   = sy,
        animAge       = 0,
        hasFood       = false,
    }
end

function IndustrySystem:randomSpawnInterval()
    local base = NPC_SPAWN_INTERVAL_MIN + math.random() * (NPC_SPAWN_INTERVAL_MAX - NPC_SPAWN_INTERVAL_MIN)
    -- 研发: 客流量缩短NPC到来间隔
    return base * ResearchSystem.getNpcFrequencyMultiplier()
end

-- ============================================================================
-- 合成队列（待处理区）
-- ============================================================================

--- 将寿司订单加入合成队列（消耗材料，开始计时）
---@param recipeId number
---@return boolean success
---@return string|nil errMsg
function IndustrySystem:cookFood(recipeId)
    local recipe = GameConfig.SUSHI_BY_ID[recipeId]
    if not recipe then return false, "配方不存在" end

    if not GameState.unlockedZones[recipe.zone] then
        return false, "需要解锁" .. (GameConfig.ZONE_DISPLAY[recipe.zone] or recipe.zone) .. "海域"
    end

    if not GameState:hasIngredientsForRecipe(recipe) then
        return false, "材料不足"
    end

    -- 检查队列是否有空位
    local freeSlot = self:findFreeQueueSlot()
    if not freeSlot then
        return false, "待处理区已满"
    end

    -- 消耗材料
    GameState:consumeIngredientsForRecipe(recipe)

    -- 加入队列
    local totalTime = GameConfig.INDUSTRY.SYNTHESIS_BASE_TIME
    GameState.synthesisQueue[freeSlot] = {
        recipeId = recipeId,
        timer = totalTime,
        totalTime = totalTime,
    }

    print(string.format("[IndustrySystem] 合成排队: %s → 槽%d (%.0f秒)",
        recipe.displayName, freeSlot, totalTime))

    if self.onCookFood then self.onCookFood(recipeId) end
    return true
end

--- 查找队列空槽
---@return number|nil
function IndustrySystem:findFreeQueueSlot()
    for i = 1, GameState.unlockedSynthesisSlots do
        if not GameState.synthesisQueue[i] then
            return i
        end
    end
    return nil
end

--- 获取队列已占用数
function IndustrySystem:getQueueUsedCount()
    local count = 0
    for i = 1, GameState.unlockedSynthesisSlots do
        if GameState.synthesisQueue[i] then
            count = count + 1
        end
    end
    return count
end

--- 解锁下一个队列槽位
---@return boolean success
---@return string|nil errMsg
function IndustrySystem:unlockQueueSlot()
    local FormatUtils = require("utils.FormatUtils")
    local next = GameState.unlockedSynthesisSlots + 1
    if next > GameConfig.INDUSTRY.QUEUE_MAX_SLOTS then
        return false, "已达最大槽位"
    end
    local cost = GameConfig.INDUSTRY.QUEUE_SLOT_UNLOCK_COST[next] or 99999
    if GameState.coins < cost then
        return false, "金币不足 (需要" .. FormatUtils.formatNumber(cost) .. ")"
    end
    GameState:spendCoins(cost)
    GameState.unlockedSynthesisSlots = next
    print(string.format("[IndustrySystem] 解锁合成槽 %d, 花费 %d", next, cost))
    return true
end

--- 更新合成队列计时（在 update 中调用）
function IndustrySystem:updateSynthesisQueue(dt)
    -- 研发: 合成加速倍率
    local effectiveDt = dt * ResearchSystem.getSynthesisSpeedMultiplier()
    for i = 1, GameState.unlockedSynthesisSlots do
        local slot = GameState.synthesisQueue[i]
        if slot then
            slot.timer = slot.timer - effectiveDt
            if slot.timer <= 0 then
                -- 合成完成
                GameState:addFood(slot.recipeId, 1)
                local recipe = GameConfig.SUSHI_BY_ID[slot.recipeId]
                print(string.format("[IndustrySystem] 合成完成: %s 库存=%d",
                    recipe and recipe.displayName or "?",
                    GameState:getFoodCount(slot.recipeId)))
                GameState.synthesisQueue[i] = nil

                -- 触发完成回调
                if self.onSynthesisComplete then
                    self.onSynthesisComplete(i, slot.recipeId)
                end
            end
        end
    end
end

-- ============================================================================
-- 获取售价
-- ============================================================================

function IndustrySystem:getSellPrice(recipeId, overrideLevel)
    return EconomySystem.calcSushiPrice(recipeId, overrideLevel)
end

-- ============================================================================
-- 帧更新
-- ============================================================================

function IndustrySystem:update(dt)
    -- 更新合成队列
    self:updateSynthesisQueue(dt)

    -- 生成NPC计时
    spawnTimer_ = spawnTimer_ - dt
    if spawnTimer_ <= 0 then
        self:trySpawnNpc()
        spawnTimer_ = self:randomSpawnInterval()
    end

    -- 更新每个座位
    for i = 1, TOTAL_SEATS do
        local s = seats_[i]

        if s.state == "entering" then
            -- 沿过道直线向上走 (posX 保持 AISLE_X, posY 减小)
            s.animAge = s.animAge + dt
            s.posY = s.posY - NPC_WALK_SPEED * dt

            if s.posY <= TABLE_CENTERS[s.tableIdx].y then
                -- 到达桌子的 Y 坐标 → 瞬移到座位
                s.posX = s.seatX
                s.posY = s.seatY
                s.state = "choosing"
                s.choosingPhase = "wondering"
                s.timer = NPC_CHOOSE_TOTAL  -- 10s 倒计时
                s.animAge = 0
                print(string.format("[IndustrySystem] 座%d (桌%d-%d) 猫到达座位, 开始选食物 (wondering)",
                    i, s.tableIdx, s.seatInTable))
            end

        elseif s.state == "choosing" then
            s.timer = s.timer - dt
            s.animAge = s.animAge + dt

            -- 阶段切换: 前5s wondering → 后5s decided
            if s.choosingPhase == "wondering" and s.timer <= NPC_CHOOSE_DECIDED then
                s.choosingPhase = "decided"
                local recipe = GameConfig.SUSHI_BY_ID[s.wantRecipeId]
                print(string.format("[IndustrySystem] 座%d 选定食物: %s %s",
                    i, recipe.icon, recipe.displayName))
            end

            -- 倒计时结束: 检查库存
            if s.timer <= 0 then
                if s.wantRecipeId and GameState:getFoodCount(s.wantRecipeId) > 0 then
                    GameState:removeFood(s.wantRecipeId, 1)
                    s.eatPrice = self:getSellPrice(s.wantRecipeId)
                    s.state = "eating"
                    s.choosingPhase = nil
                    s.timer = NPC_EAT_DURATION
                    s.hasFood = true
                    s.animAge = 0
                    print(string.format("[IndustrySystem] 座%d 获取食物, 开始进食 %s (%.0f秒)",
                        i, GameConfig.SUSHI_BY_ID[s.wantRecipeId].displayName, NPC_EAT_DURATION))
                else
                    s.state = "no_food"
                    s.choosingPhase = nil
                    s.timer = NPC_NO_FOOD_WAIT  -- 30s
                    s.hasFood = false
                    s.animAge = 0
                    print(string.format("[IndustrySystem] 座%d 没有 %s, 等待 %.0f秒后离开",
                        i, GameConfig.SUSHI_BY_ID[s.wantRecipeId].displayName, NPC_NO_FOOD_WAIT))
                end
            end

        elseif s.state == "eating" then
            s.timer = s.timer - dt
            s.animAge = s.animAge + dt
            if s.timer <= 0 then
                GameState:addToCashRegister(s.eatPrice)
                GameState.totalNpcServed = GameState.totalNpcServed + 1
                GameState.totalSushiSold = GameState.totalSushiSold + 1
                print(string.format("[IndustrySystem] 座%d 吃完 %s +%d金币 → 收银台(%d)",
                    i, GameConfig.SUSHI_BY_ID[s.wantRecipeId].displayName,
                    s.eatPrice, GameState.cashRegister))
                if self.onNpcEat then
                    self.onNpcEat(i, s.wantRecipeId, s.eatPrice)
                end
                self:startLeaving(i)
            end

        elseif s.state == "no_food" then
            s.timer = s.timer - dt
            s.animAge = s.animAge + dt
            if s.timer <= 0 then
                self:startLeaving(i)
            end

        elseif s.state == "leaving" then
            -- 沿过道直线向下走
            s.animAge = s.animAge + dt
            s.posY = s.posY + NPC_WALK_SPEED * dt
            if s.posY >= EXIT_Y then
                seats_[i] = self:makeEmptySeat(i)
            end
        end
    end
end

function IndustrySystem:startLeaving(seatIdx)
    local s = seats_[seatIdx]
    -- 瞬移到座位水平位置的过道 (seatX, 桌子Y)
    s.posX = s.seatX
    s.posY = TABLE_CENTERS[s.tableIdx].y
    s.state = "leaving"
    s.choosingPhase = nil
    s.animAge = 0
    print(string.format("[IndustrySystem] 座%d 猫咪离场 (瞬移到 x=%.3f, 向下走)", seatIdx, s.seatX))
end

-- ============================================================================
-- 生成NPC
-- ============================================================================

function IndustrySystem:trySpawnNpc()
    -- 找空座位
    local emptySeats = {}
    for i = 1, TOTAL_SEATS do
        if seats_[i].state == "empty" then
            table.insert(emptySeats, i)
        end
    end
    if #emptySeats == 0 then return end

    local seatIdx = emptySeats[math.random(1, #emptySeats)]

    -- 随机选一个已解锁的配方
    local unlocked = {}
    for _, recipe in ipairs(GameConfig.SUSHI) do
        if GameState.unlockedZones[recipe.zone] then
            table.insert(unlocked, recipe)
        end
    end
    if #unlocked == 0 then return end

    local chosen = unlocked[math.random(1, #unlocked)]
    local s = seats_[seatIdx]

    s.catType = CAT_TYPES[math.random(1, #CAT_TYPES)]
    s.wantRecipeId = chosen.id
    s.state = "entering"
    s.choosingPhase = nil
    s.animAge = 0
    s.posX = AISLE_X
    s.posY = ENTRY_Y

    print(string.format("[IndustrySystem] 座%d (桌%d-%d) %s猫入场, 想吃 %s",
        seatIdx, s.tableIdx, s.seatInTable, s.catType, chosen.displayName))
end

-- ============================================================================
-- 查询接口 (供 Scene 使用)
-- ============================================================================

function IndustrySystem:getSeatStates()
    return seats_
end

function IndustrySystem:getTotalSeats()
    return TOTAL_SEATS
end

function IndustrySystem:getTableCount()
    return TABLE_COUNT
end

function IndustrySystem:getTableCenters()
    return TABLE_CENTERS
end

function IndustrySystem:getCashRegisterAmount()
    return GameState.cashRegister
end

function IndustrySystem:collectCash()
    return GameState:collectCashRegister()
end

function IndustrySystem:getWalkAnimFPS()
    return NPC_WALK_ANIM_FPS
end

function IndustrySystem:getEatDuration()
    return NPC_EAT_DURATION
end

function IndustrySystem:getChooseTotalDuration()
    return NPC_CHOOSE_TOTAL
end

function IndustrySystem:getChooseWonderDuration()
    return NPC_CHOOSE_WONDER
end

function IndustrySystem:getNoFoodWaitDuration()
    return NPC_NO_FOOD_WAIT
end

function IndustrySystem:getSeatOffsets()
    return SEAT_DX, SEAT_DY
end

function IndustrySystem:setSeatOffsets(dx, dy)
    SEAT_DX = dx
    SEAT_DY = dy
    -- 刷新所有座位的绝对坐标
    for i = 1, #seats_ do
        local s = seats_[i]
        local sx, sy = getSeatPos(s.tableIdx, s.seatInTable)
        s.seatX = sx
        s.seatY = sy
        -- 如果猫咪正坐着, 也更新当前位置
        if s.state == "choosing" or s.state == "eating" or s.state == "no_food" then
            s.posX = sx
            s.posY = sy
        end
    end
end

return IndustrySystem
