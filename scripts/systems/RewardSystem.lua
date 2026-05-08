-- ============================================================================
-- RewardSystem: 统一奖励发放系统
-- ============================================================================
-- 接收 DropSystem 生成的 catchResult，执行所有副作用:
--   - 发放金币
--   - 鱼入仓 (所有体型的鱼都入仓，含小鱼)
--   - 词条鱼个体入库
--   - 图鉴记录
--   - 新鱼发现检测
--   - 触发捕获动画 / 弹窗
-- 不直接渲染，通过回调通知 UI 层。
-- ============================================================================
local GameConfig     = require("config.GameConfig")
local GameState      = require("state.GameState")
local CatchAnimSystem = require("systems.CatchAnimSystem")
local CodexSystem    = require("systems.CodexSystem")
local ResearchSystem = require("systems.ResearchSystem")

local RewardSystem = {}

-- ========== UI 回调 (由 main.lua 设置) ==========
---@type fun(popup:table)|nil
local showAffixPopupFn_ = nil
---@type fun(popup:table)|nil
local showNewFishPopupFn_ = nil
---@type fun(fishName:string):table|nil
local getFishImageFn_ = nil
---@type fun():{x:number,y:number}|nil
local getBucketCenterFn_ = nil

--- 设置 UI 回调
---@param callbacks table { showAffixPopup, showNewFishPopup, getFishImage, getBucketCenter }
function RewardSystem.setCallbacks(callbacks)
    showAffixPopupFn_   = callbacks.showAffixPopup
    showNewFishPopupFn_ = callbacks.showNewFishPopup
    getFishImageFn_     = callbacks.getFishImage
    getBucketCenterFn_  = callbacks.getBucketCenter
end

-- ============================================================================
-- 核心: 发放捕获奖励
-- ============================================================================

--- 发放捕获奖励 (普通捕获 / 稀有鱼 / Boss 掉落)
---@param catchResult table 来自 DropSystem.generateXxx 的结果
---@param screenInfo table { screenX, screenY, w, h, variant, dir, size, fishShadowRef }
function RewardSystem.grantCatchReward(catchResult, screenInfo)
    local cr = catchResult
    local sx = screenInfo.screenX or 0
    local sy = screenInfo.screenY or 0
    local w  = screenInfo.w or 1
    local h  = screenInfo.h or 1

    -- 1. 发放金币
    if cr.coinValue and cr.coinValue > 0 then
        GameState:addCoins(cr.coinValue)
        CatchAnimSystem.triggerCoinPopup(sx, sy, cr.coinValue)
    end

    -- 2. 所有鱼都入仓 (不再排除小鱼)
    local holdCap = GameConfig.FISH_HOLD_CAPACITY + ResearchSystem.getHoldCapacityBonus()
    local enteredHold = false

    if GameState:getTotalFishInHold() < holdCap then
        GameState:addFish(cr.fishId, cr.qualityId, 1)
        enteredHold = true

        -- 飞向渔船动画
        if getBucketCenterFn_ then
            local boatX, boatY = getBucketCenterFn_()
            local fishImgInfo = getFishImageFn_ and getFishImageFn_(cr.fishName) or nil
            CatchAnimSystem.trigger(
                sx, sy,
                boatX, boatY,
                screenInfo.variant or 1,
                screenInfo.dir or 1,
                screenInfo.size or 40,
                w, h,
                fishImgInfo
            )
        end
    else
        print(string.format("[Reward] 鱼仓已满! %s 仅获金币 +%d",
            cr.displayName, cr.coinValue))
    end

    -- 3. 图鉴记录 (无论是否入仓)
    CodexSystem.recordCatch(cr.fishId, cr.qualityId, cr.affixes)

    -- 4. 新鱼发现检测
    if not GameState.discoveredFish[cr.fishId] then
        GameState.discoveredFish[cr.fishId] = true
        if showNewFishPopupFn_ then
            showNewFishPopupFn_({
                name = cr.fishName,
                displayName = cr.displayName,
                icon = cr.icon,
                qualityId = cr.qualityId,
            })
        end
    end

    -- 5. 词条鱼个体入库 + 弹窗
    if cr.affixes and #cr.affixes > 0 then
        local uid = GameState:addIndividualFish(cr.fishId, cr.qualityId, cr.affixes)
        print(string.format("[Reward] 词条鱼! uid=%d %s 品质%d 词条[%s] ×%.0f%%价值",
            uid, cr.displayName, cr.qualityId, cr.summary, cr.valueMult * 100))

        if showAffixPopupFn_ then
            showAffixPopupFn_({
                fishName    = cr.fishName,
                displayName = cr.displayName,
                affixes     = cr.affixes,
                summary     = cr.summary,
                valueMult   = cr.valueMult,
                isBossDrop  = cr.isBossDrop or false,
                isRareFish  = cr.isRareFish or false,
            })
        end
    end

    -- 6. 日志
    local tag = cr.isBossDrop and "Boss" or (cr.isRareFish and "稀有" or "普通")
    print(string.format("[Reward] [%s] %s 品质%d %s +%d币 入仓=%s",
        tag, cr.displayName, cr.qualityId, cr.sizeTier,
        cr.coinValue, tostring(enteredHold)))
end

return RewardSystem
