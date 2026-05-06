-- ============================================================================
-- BreedingSystem: 养殖系统 - 配对繁殖
-- 规则: 放入两条相同鱼种 → 定时产出后代 → 品质随机继承父母之一
-- ============================================================================
local GameConfig     = require("config.GameConfig")
local GameState      = require("state.GameState")
local AffixSystem    = require("systems.AffixSystem")
local FormatUtils    = require("utils.FormatUtils")
local ResearchSystem = require("systems.ResearchSystem")
local CodexSystem    = require("systems.CodexSystem")

local BreedingSystem = {}

--- 产出回调 (slotIndex, fishId, qualityId, uid)
BreedingSystem.onProduce = nil

-- ============================================================================
-- 配对繁殖: 放入鱼
-- ============================================================================

--- 放入第一条鱼或第二条鱼到养殖槽
--- @param slotIndex number 槽位索引
--- @param fishId number 鱼种ID
--- @param qualityId number 品质
--- @param uid number|nil 词条鱼UID (nil=普通鱼)
--- @return boolean, string|nil
function BreedingSystem:placeFish(slotIndex, fishId, qualityId, uid)
    if slotIndex < 1 or slotIndex > GameState.unlockedBreedingSlots then
        return false, "槽位未解锁"
    end

    local slot = GameState.breedingSlots[slotIndex]

    -- 如果槽位已满(2条鱼)，不允许放入
    if slot and slot.fish2 then
        return false, "槽位已满"
    end

    -- 如果已有一条鱼，检查是否同种
    if slot and slot.fishId ~= fishId then
        return false, "需要相同种类的鱼"
    end

    -- 获取词条数据 (在消耗前)
    local affixes = nil
    if uid then
        local indData = GameState:getIndividualFish(uid)
        if not indData then
            return false, "词条鱼不存在"
        end
        affixes = {}
        for _, id in ipairs(indData.affixes or {}) do
            table.insert(affixes, id)
        end
        -- 消耗词条鱼
        if not GameState:removeIndividualFish(uid) then
            return false, "消耗词条鱼失败"
        end
    else
        -- 消耗普通鱼
        if not GameState:removeFish(fishId, qualityId) then
            return false, "没有这条鱼"
        end
    end

    local fishCfg = GameConfig.FISH_BY_ID[fishId]

    if not slot then
        -- 放入第一条鱼
        GameState.breedingSlots[slotIndex] = {
            fishId = fishId,
            -- 第一条鱼信息
            fish1 = { qualityId = qualityId, affixes = affixes },
            -- 第二条鱼 (待放入)
            fish2 = nil,
            -- 产出计时器
            timer = 0,
            produceTime = 0,  -- 配对完成后设置
            -- 产出的鱼暂存 (等待收取)
            produced = nil,  -- { fishId, qualityId, affixes }
        }
        print(string.format("[BreedingSystem] 槽位%d: 放入第一条 %s (品质%d%s)",
            slotIndex, fishCfg.displayName, qualityId,
            affixes and " [词条]" or ""))
        return true
    else
        -- 放入第二条鱼 → 配对完成，开始繁殖倒计时
        slot.fish2 = { qualityId = qualityId, affixes = affixes }

        -- 产出时间取两条鱼品质的平均值
        local avgQ = (slot.fish1.qualityId + qualityId) / 2
        local qIdx = math.max(1, math.min(5, math.floor(avgQ + 0.5)))
        local qualityMulti = GameConfig.BREEDING.QUALITY_TIME_MULTI[qIdx] or 1
        slot.produceTime = GameConfig.BREEDING.BASE_PRODUCE_TIME * qualityMulti
        slot.timer = 0

        print(string.format("[BreedingSystem] 槽位%d: 配对完成 %s (品质%d+%d), 产出周期 %.0f秒",
            slotIndex, fishCfg.displayName, slot.fish1.qualityId, qualityId, slot.produceTime))
        return true
    end
end

-- ============================================================================
-- 取出鱼 (归还到背包)
-- ============================================================================

--- 取出一条鱼 (whichFish: 1=第一条, 2=第二条)
--- @param slotIndex number
--- @param whichFish number|nil 1或2, nil=取出全部
--- @return boolean
function BreedingSystem:removeFish(slotIndex, whichFish)
    local slot = GameState.breedingSlots[slotIndex]
    if not slot then return false end

    local function returnFish(fishInfo)
        GameState:addFish(slot.fishId, fishInfo.qualityId)
        if fishInfo.affixes and #fishInfo.affixes > 0 then
            GameState:addIndividualFish(slot.fishId, fishInfo.qualityId, fishInfo.affixes)
        end
    end

    if whichFish == 1 and slot.fish1 then
        returnFish(slot.fish1)
        -- 如果只有1条，清空槽位
        if not slot.fish2 then
            GameState.breedingSlots[slotIndex] = nil
        else
            -- 把 fish2 变成 fish1
            slot.fish1 = slot.fish2
            slot.fish2 = nil
            slot.timer = 0
            slot.produceTime = 0
            slot.produced = nil
        end
        return true
    elseif whichFish == 2 and slot.fish2 then
        returnFish(slot.fish2)
        slot.fish2 = nil
        slot.timer = 0
        slot.produceTime = 0
        slot.produced = nil
        return true
    else
        -- 取出全部
        if slot.fish1 then returnFish(slot.fish1) end
        if slot.fish2 then returnFish(slot.fish2) end
        GameState.breedingSlots[slotIndex] = nil
        return true
    end
end

-- ============================================================================
-- 收取产出的鱼
-- ============================================================================

--- 收取产出
--- @param slotIndex number
--- @return table|nil producedInfo  { fishId, qualityId, affixes }
function BreedingSystem:collectProduce(slotIndex)
    local slot = GameState.breedingSlots[slotIndex]
    if not slot or not slot.produced then return nil end

    local p = slot.produced
    GameState:addFish(p.fishId, p.qualityId)

    local childUid = nil
    if p.affixes and #p.affixes > 0 then
        childUid = GameState:addIndividualFish(p.fishId, p.qualityId, p.affixes)
    end

    local result = {
        fishId = p.fishId,
        qualityId = p.qualityId,
        affixes = p.affixes,
        uid = childUid,
    }

    slot.produced = nil
    -- 重置计时器开始下一轮
    slot.timer = 0

    if self.onProduce then
        self.onProduce(slotIndex, p.fishId, p.qualityId, childUid)
    end

    return result
end

-- ============================================================================
-- 每帧更新
-- ============================================================================

function BreedingSystem:update(dt)
    -- 研发: 繁殖加速倍率
    local effectiveDt = dt * ResearchSystem.getBreedSpeedMultiplier()
    for i = 1, GameState.unlockedBreedingSlots do
        local slot = GameState.breedingSlots[i]
        if slot and slot.fish1 and slot.fish2 and not slot.produced then
            -- 配对完成且没有待收取的产出 → 计时
            slot.timer = slot.timer + effectiveDt
            if slot.timer >= slot.produceTime then
                slot.timer = slot.produceTime  -- 锁定在满

                -- 产出: 随机继承父母之一的品质
                local parentQ1 = slot.fish1.qualityId
                local parentQ2 = slot.fish2.qualityId
                local childQ = math.random() < 0.5 and parentQ1 or parentQ2

                -- 品质突变: 同品质时有小概率升级
                local mutated = false
                local mc = GameConfig.BREED_MUTATION
                if parentQ1 == parentQ2 and childQ < mc.MAX_QUALITY then
                    local factor = mc.QUALITY_FACTOR[childQ] or 0
                    -- 图鉴buff加成突变概率
                    local codexBuff = CodexSystem.getActiveBuffs()
                    local mutChance = mc.BASE_CHANCE * factor + (codexBuff.breedMutation or 0)
                    if math.random() < mutChance then
                        childQ = childQ + 1
                        mutated = true
                    end
                end

                -- 词条继承
                local childAffixes = nil
                local a1 = slot.fish1.affixes or {}
                local a2 = slot.fish2.affixes or {}
                if #a1 > 0 or #a2 > 0 then
                    childAffixes = AffixSystem.inheritAffixes(a1, a2)
                    if #childAffixes == 0 then childAffixes = nil end
                end

                slot.produced = {
                    fishId = slot.fishId,
                    qualityId = childQ,
                    affixes = childAffixes,
                }

                -- 记录图鉴
                CodexSystem.recordCatch(slot.fishId, childQ, childAffixes)

                local fishCfg = GameConfig.FISH_BY_ID[slot.fishId]
                local qCfg = GameConfig.QUALITY[childQ]
                local mutStr = mutated and " ★突变!" or ""
                print(string.format("[BreedingSystem] 槽位%d产出: %s [%s] (继承自品质%d/%d)%s",
                    i, fishCfg.displayName, qCfg.displayName, parentQ1, parentQ2, mutStr))
            end
        end
    end
end

-- ============================================================================
-- 查询接口
-- ============================================================================

--- 解锁新槽位
function BreedingSystem:unlockSlot()
    local next = GameState.unlockedBreedingSlots + 1
    -- 研发: 养殖扩建增加槽位上限
    local maxSlots = GameConfig.BREEDING.MAX_SLOTS + ResearchSystem.getBreedSlotsBonus()
    if next > maxSlots then
        return false, "已达最大槽位"
    end
    local cost = GameConfig.BREEDING.SLOT_UNLOCK_COST[next] or 0
    if cost > 0 and not GameState:spendCoins(cost) then
        return false, "金币不足 (需要" .. FormatUtils.formatNumber(cost) .. ")"
    end
    GameState.unlockedBreedingSlots = next
    print("[BreedingSystem] 解锁养殖槽位" .. next)
    return true
end

--- 槽位是否已配对 (2条鱼)
function BreedingSystem:isPaired(slotIndex)
    local slot = GameState.breedingSlots[slotIndex]
    return slot and slot.fish1 and slot.fish2
end

--- 槽位是否有待收取的产出
function BreedingSystem:hasProduced(slotIndex)
    local slot = GameState.breedingSlots[slotIndex]
    return slot and slot.produced ~= nil
end

--- 获取槽位进度 (0~1)
function BreedingSystem:getSlotProgress(slotIndex)
    local slot = GameState.breedingSlots[slotIndex]
    if not slot or not slot.fish2 then return 0 end
    if slot.produced then return 1 end
    if slot.produceTime <= 0 then return 0 end
    return math.min(1, slot.timer / slot.produceTime)
end

--- 获取槽位剩余时间
function BreedingSystem:getSlotRemainingTime(slotIndex)
    local slot = GameState.breedingSlots[slotIndex]
    if not slot or not slot.fish2 then return 0 end
    if slot.produced then return 0 end
    if slot.produceTime <= 0 then return 0 end
    return math.max(0, slot.produceTime - slot.timer)
end

return BreedingSystem
