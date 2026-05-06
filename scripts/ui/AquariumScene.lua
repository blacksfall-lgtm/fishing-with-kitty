-- ============================================================================
-- AquariumScene: 鱼缸 NanoVG 场景
-- 渐变深海背景 + 气泡粒子 + 展示鱼 + Buff面板 + 收入显示 + 鱼选择弹窗
-- ============================================================================
local GameConfig      = require("config.GameConfig")
local GameState       = require("state.GameState")
local AquariumSystem  = require("systems.AquariumSystem")
local FormatUtils     = require("utils.FormatUtils")
local AffixConfig     = require("config.AffixConfig")
local AffixSystem     = require("systems.AffixSystem")

local AquariumScene = {}

-- ============================================================================
-- 状态
-- ============================================================================
local time_ = 0
local clickRects_ = {}

-- 气泡粒子
local bubbles_ = {}
local MAX_BUBBLES = 20

-- 鱼选择弹窗
local selectPopup_ = {
    open = false,
    slotIndex = 0,
    scrollY = 0,
    fishList = {},
}

-- toast 提示
local toastMsg_   = ""
local toastTimer_ = 0

-- 收入弹出
local incomePopText_  = ""
local incomePopTimer_ = 0

-- ============================================================================
-- 初始化
-- ============================================================================

function AquariumScene.init(nvg)
    -- 初始化气泡
    for i = 1, MAX_BUBBLES do
        bubbles_[i] = AquariumScene.newBubble()
    end

    -- 注册收入回调
    AquariumSystem.onIncome = function(totalGold)
        incomePopText_ = "+" .. FormatUtils.formatNumber(totalGold) .. " 💰"
        incomePopTimer_ = 2.0
    end

    print("[AquariumScene] 初始化完成")
end

function AquariumScene.newBubble()
    return {
        x = math.random() * 0.8 + 0.1,  -- 归一化 x [0.1, 0.9]
        y = 1.0 + math.random() * 0.3,   -- 从底部以下开始
        size = 2 + math.random() * 4,
        speed = 0.02 + math.random() * 0.04,
        wobble = math.random() * 6.28,
        alpha = 0.3 + math.random() * 0.4,
    }
end

-- ============================================================================
-- 更新
-- ============================================================================

function AquariumScene.update(dt)
    time_ = time_ + dt
    if toastTimer_ > 0 then
        toastTimer_ = toastTimer_ - dt
    end
    if incomePopTimer_ > 0 then
        incomePopTimer_ = incomePopTimer_ - dt
    end

    -- 更新气泡
    for i = 1, MAX_BUBBLES do
        local b = bubbles_[i]
        b.y = b.y - b.speed * dt
        if b.y < -0.1 then
            bubbles_[i] = AquariumScene.newBubble()
        end
    end
end

-- ============================================================================
-- 输入检测
-- ============================================================================

--- @return string|nil action  "go_back" | nil
function AquariumScene.checkInput()
    if not input:GetMouseButtonPress(MOUSEB_LEFT) then
        return nil
    end

    local dpr = graphics:GetDPR()
    local mx = input.mousePosition.x / dpr
    local my = input.mousePosition.y / dpr

    -- 弹窗优先
    if selectPopup_.open then
        for _, rect in ipairs(clickRects_) do
            if mx >= rect.x and mx <= rect.x + rect.w and
               my >= rect.y and my <= rect.y + rect.h then
                if rect.action == "close_select" then
                    selectPopup_.open = false
                    return nil
                elseif rect.action and rect.action:sub(1, 11) == "select_fish" then
                    local parts = {}
                    for p in rect.action:gmatch("[^_]+") do
                        table.insert(parts, p)
                    end
                    local fishId = tonumber(parts[3])
                    local qualityId = tonumber(parts[4])
                    local uid = tonumber(parts[5])  -- nil = 普通鱼
                    if fishId and qualityId then
                        local ok, err
                        if uid then
                            ok, err = AquariumSystem:placeFishWithAffix(
                                selectPopup_.slotIndex, fishId, qualityId, uid)
                        else
                            ok, err = AquariumSystem:placeFish(
                                selectPopup_.slotIndex, fishId, qualityId)
                        end
                        if ok then
                            AquariumScene.showToast("放入成功!")
                        else
                            AquariumScene.showToast(err or "放入失败")
                        end
                        selectPopup_.open = false
                    end
                    return nil
                end
            end
        end
        selectPopup_.open = false
        return nil
    end

    -- 普通点击
    for _, rect in ipairs(clickRects_) do
        if mx >= rect.x and mx <= rect.x + rect.w and
           my >= rect.y and my <= rect.y + rect.h then
            if rect.action == "go_back" then
                return "go_back"
            elseif rect.action and rect.action:sub(1, 9) == "open_slot" then
                local slotIdx = tonumber(rect.action:sub(11))
                if slotIdx then
                    AquariumScene.onSlotClick(slotIdx)
                end
                return nil
            elseif rect.action and rect.action:sub(1, 11) == "remove_slot" then
                local slotIdx = tonumber(rect.action:sub(13))
                if slotIdx then
                    local ok = AquariumSystem:removeFish(slotIdx)
                    if ok then
                        AquariumScene.showToast("鱼已取回仓库!")
                    end
                end
                return nil
            elseif rect.action == "unlock_slot" then
                local ok, err = AquariumSystem:unlockSlot()
                if ok then
                    AquariumScene.showToast("解锁新槽位!")
                else
                    AquariumScene.showToast(err or "解锁失败")
                end
                return nil
            end
        end
    end

    return nil
end

function AquariumScene.onSlotClick(slotIdx)
    local slot = GameState.aquariumSlots[slotIdx]
    if slot then return end

    selectPopup_.slotIndex = slotIdx
    selectPopup_.scrollY = 0
    selectPopup_.fishList = {}

    -- 先列出词条鱼（个体）
    for _, indiv in pairs(GameState:getAllIndividuals()) do
        local fish = GameConfig.FISH_BY_ID[indiv.fishId]
        if fish then
            local qCfg = GameConfig.QUALITY[indiv.qualityId]
            local summary = AffixSystem.getAffixSummary(indiv.affixes)
            table.insert(selectPopup_.fishList, {
                fishId = indiv.fishId,
                qualityId = indiv.qualityId,
                count = 1,
                displayName = fish.displayName,
                icon = fish.icon,
                qualityName = qCfg.displayName,
                qualityColor = qCfg.color,
                uid = indiv.uid,
                affixes = indiv.affixes,
                affixSummary = summary,
                isAffix = true,
            })
        end
    end

    -- 再列出普通鱼（排除词条鱼数量）
    for _, fish in ipairs(GameConfig.FISH) do
        for q = 1, 5 do
            local total = GameState:getFishCount(fish.id, q)
            local affixCount = GameState:getIndividualCount(fish.id, q)
            local normalCount = total - affixCount
            if normalCount > 0 then
                local qCfg = GameConfig.QUALITY[q]
                table.insert(selectPopup_.fishList, {
                    fishId = fish.id,
                    qualityId = q,
                    count = normalCount,
                    displayName = fish.displayName,
                    icon = fish.icon,
                    qualityName = qCfg.displayName,
                    qualityColor = qCfg.color,
                    isAffix = false,
                })
            end
        end
    end

    if #selectPopup_.fishList == 0 then
        AquariumScene.showToast("没有可放入的鱼!")
        return
    end

    selectPopup_.open = true
end

function AquariumScene.showToast(msg)
    toastMsg_ = msg
    toastTimer_ = 2.0
end

-- ============================================================================
-- 渲染
-- ============================================================================

function AquariumScene.render(nvg, x, y, w, h)
    clickRects_ = {}

    -- 1) 深海渐变背景
    AquariumScene.renderBackground(nvg, x, y, w, h)

    -- 2) 气泡粒子
    AquariumScene.renderBubbles(nvg, x, y, w, h)

    -- 3) 鱼缸展示区 (上半部分 50%)
    local displayH = h * 0.38
    local displayY = y + 46
    AquariumScene.renderFishDisplay(nvg, x + 10, displayY, w - 20, displayH)

    -- 4) Buff 面板
    local buffY = displayY + displayH + 6
    local buffH = 60
    AquariumScene.renderBuffPanel(nvg, x + 10, buffY, w - 20, buffH)

    -- 5) 底部槽位面板
    local slotY = buffY + buffH + 6
    local slotH = y + h - slotY - 8
    AquariumScene.renderSlotPanel(nvg, x + 10, slotY, w - 20, slotH)

    -- 6) 鱼选择弹窗
    if selectPopup_.open then
        AquariumScene.renderSelectPopup(nvg, x, y, w, h)
    end

    -- 7) 顶部 HUD
    AquariumScene.renderHUD(nvg, x, y, w, h)

    -- 8) 收入弹出动画
    if incomePopTimer_ > 0 then
        local alpha = math.min(1, incomePopTimer_) * 255
        local popY = y + h * 0.35 - (2.0 - incomePopTimer_) * 30
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 20)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(255, 215, 0, math.floor(alpha)))
        nvgText(nvg, x + w * 0.5, popY, incomePopText_)
    end

    -- 9) Toast
    if toastTimer_ > 0 then
        local alpha = math.min(1, toastTimer_ * 2) * 220
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 16)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        local tw = nvgTextBounds(nvg, 0, 0, toastMsg_)
        local tx = x + w * 0.5
        local ty = y + h * 0.4
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, tx - tw * 0.5 - 16, ty - 14, tw + 32, 28, 14)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, math.floor(alpha * 0.7)))
        nvgFill(nvg)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, math.floor(alpha)))
        nvgText(nvg, tx, ty, toastMsg_)
    end
end

-- ============================================================================
-- 深海渐变背景
-- ============================================================================

function AquariumScene.renderBackground(nvg, x, y, w, h)
    -- 从深蓝到更深的蓝黑渐变
    local bgPaint = nvgLinearGradient(nvg, x, y, x, y + h,
        nvgRGBA(15, 50, 100, 255),
        nvgRGBA(5, 15, 40, 255))
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillPaint(nvg, bgPaint)
    nvgFill(nvg)

    -- 微弱的光线从顶部照下
    local lightPaint = nvgLinearGradient(nvg, x + w * 0.5, y, x + w * 0.5, y + h * 0.4,
        nvgRGBA(40, 120, 180, 50),
        nvgRGBA(40, 120, 180, 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h * 0.4)
    nvgFillPaint(nvg, lightPaint)
    nvgFill(nvg)
end

-- ============================================================================
-- 气泡粒子
-- ============================================================================

function AquariumScene.renderBubbles(nvg, x, y, w, h)
    for i = 1, MAX_BUBBLES do
        local b = bubbles_[i]
        if b.y >= 0 and b.y <= 1.0 then
            local bx = x + b.x * w + math.sin(time_ * 1.5 + b.wobble) * 6
            local by = y + b.y * h
            local alpha = math.floor(b.alpha * 255)

            nvgBeginPath(nvg)
            nvgCircle(nvg, bx, by, b.size)
            nvgStrokeColor(nvg, nvgRGBA(150, 210, 255, alpha))
            nvgStrokeWidth(nvg, 1)
            nvgStroke(nvg)

            -- 高光点
            nvgBeginPath(nvg)
            nvgCircle(nvg, bx - b.size * 0.25, by - b.size * 0.25, b.size * 0.3)
            nvgFillColor(nvg, nvgRGBA(200, 240, 255, math.floor(alpha * 0.6)))
            nvgFill(nvg)
        end
    end
end

-- ============================================================================
-- 鱼缸展示区：展示放置的鱼在水中漫游
-- ============================================================================

function AquariumScene.renderFishDisplay(nvg, x, y, w, h)
    -- 半透明鱼缸玻璃边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, 10)
    nvgStrokeColor(nvg, nvgRGBA(100, 180, 220, 80))
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)

    -- 玻璃反光效果
    local glassPaint = nvgLinearGradient(nvg, x, y, x, y + h * 0.3,
        nvgRGBA(150, 200, 255, 25),
        nvgRGBA(150, 200, 255, 0))
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x + 2, y + 2, w - 4, h * 0.3, 8)
    nvgFillPaint(nvg, glassPaint)
    nvgFill(nvg)

    -- 绘制放置的鱼
    local margin = 12
    local innerX = x + margin
    local innerY = y + margin
    local innerW = w - margin * 2
    local innerH = h - margin * 2

    local fishCount = 0
    for i = 1, GameState.unlockedAquariumSlots do
        local slot = GameState.aquariumSlots[i]
        if slot then
            fishCount = fishCount + 1
            local fishCfg = GameConfig.FISH_BY_ID[slot.fishId]
            if fishCfg then
                local seed = i * 97.3
                local speed = 0.25 + (i % 4) * 0.1
                local phase = seed + time_ * speed

                -- 水平来回
                local normX = 0.5 + math.sin(phase) * 0.38
                -- 垂直分层
                local row = math.floor((fishCount - 1) / 3)
                local col = (fishCount - 1) % 3
                local normY = 0.2 + row * 0.35 + math.sin(phase * 0.5 + seed) * 0.05
                normY = math.min(0.85, normY)

                local fishX = innerX + normX * innerW
                local fishY = innerY + normY * innerH

                local dir = math.cos(phase)
                local flipX = dir < 0 and -1 or 1

                -- 品质光环 (脉冲)
                local qCfg = GameConfig.QUALITY[slot.qualityId]
                if qCfg and slot.qualityId >= 2 then
                    local pulse = 0.6 + math.sin(time_ * 2 + seed) * 0.4
                    local glowAlpha = math.floor(60 * pulse)
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, fishX, fishY, 20)
                    nvgFillColor(nvg, nvgRGBA(qCfg.color[1], qCfg.color[2], qCfg.color[3], glowAlpha))
                    nvgFill(nvg)
                end

                -- 鱼 emoji
                nvgSave(nvg)
                nvgTranslate(nvg, fishX, fishY)
                nvgScale(nvg, flipX, 1)
                nvgFontFace(nvg, "sans")
                nvgFontSize(nvg, 26)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(nvg, nvgRGBA(255, 255, 255, 230))
                nvgText(nvg, 0, 0, fishCfg.icon)
                nvgRestore(nvg)
            end
        end
    end

    -- 空鱼缸提示
    if fishCount == 0 then
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 14)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(120, 160, 200, 150))
        nvgText(nvg, x + w * 0.5, y + h * 0.5, "鱼缸空空的，放入鱼获得收益吧！")
    end
end

-- ============================================================================
-- Buff 面板
-- ============================================================================

function AquariumScene.renderBuffPanel(nvg, x, y, w, h)
    -- 面板背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, 10)
    nvgFillColor(nvg, nvgRGBA(10, 30, 60, 180))
    nvgFill(nvg)

    -- 标题行
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 13)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(180, 210, 255, 200))
    nvgText(nvg, x + 10, y + 6, "🔮 全局加成")

    -- 收入信息(右侧)
    local income = AquariumSystem:getEstimatedIncome()
    local interval = GameConfig.AQUARIUM.INCOME.INTERVAL
    nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(255, 215, 0, 200))
    nvgFontSize(nvg, 12)
    nvgText(nvg, x + w - 10, y + 7,
        "💰 " .. FormatUtils.formatNumber(income) .. "/" .. interval .. "s")

    -- Buff 条目 (2x2 网格)
    local buffs = AquariumSystem:getBuffSummary()
    local cellW = (w - 20) / 2
    local cellH = 18
    local startY = y + 24

    for idx, buff in ipairs(buffs) do
        local col = (idx - 1) % 2
        local row = math.floor((idx - 1) / 2)
        local cx = x + 10 + col * cellW
        local cy = startY + row * cellH

        -- 图标 + 名称
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 12)
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(170, 190, 220, 200))
        nvgText(nvg, cx, cy, buff.icon .. " " .. buff.name)

        -- 值
        local valueStr = buff.value > 0
            and ("+" .. FormatUtils.formatPercent(buff.value))
            or "+0%"
        local valueColor = buff.value > 0
            and nvgRGBA(100, 220, 140, 220)
            or nvgRGBA(100, 110, 130, 160)
        nvgFillColor(nvg, valueColor)
        nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        nvgText(nvg, cx + cellW - 4, cy, valueStr)
    end
end

-- ============================================================================
-- 底部槽位面板
-- ============================================================================

function AquariumScene.renderSlotPanel(nvg, px, py, pw, ph)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, px, py, pw, ph, 12)
    nvgFillColor(nvg, nvgRGBA(10, 30, 60, 180))
    nvgFill(nvg)

    -- 标题
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 14)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(200, 220, 255, 220))
    nvgText(nvg, px + 12, py + 8, "鱼缸槽位")

    -- 槽位卡片 (2列布局)
    local cols = 2
    local cardGap = 5
    local cardW = math.floor((pw - 16 - cardGap * (cols - 1)) / cols)
    local cardH = 46
    local startX = px + 8
    local startY = py + 28

    for i = 1, GameConfig.AQUARIUM.MAX_SLOTS do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local cx = startX + col * (cardW + cardGap)
        local cy = startY + row * (cardH + cardGap)

        if cy + cardH > py + ph then break end

        if i <= GameState.unlockedAquariumSlots then
            local slot = GameState.aquariumSlots[i]
            if slot then
                AquariumScene.renderOccupiedSlot(nvg, cx, cy, cardW, cardH, i, slot)
            else
                AquariumScene.renderEmptySlot(nvg, cx, cy, cardW, cardH, i)
            end
        else
            AquariumScene.renderLockedSlot(nvg, cx, cy, cardW, cardH, i)
        end
    end
end

function AquariumScene.renderOccupiedSlot(nvg, x, y, w, h, slotIdx, slot)
    local fishCfg = GameConfig.FISH_BY_ID[slot.fishId]
    local qCfg = GameConfig.QUALITY[slot.qualityId]

    -- 卡片背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, 8)
    nvgFillColor(nvg, nvgRGBA(20, 50, 80, 200))
    nvgFill(nvg)

    -- 品质色条(左)
    if qCfg then
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, x, y, 3, h, 2)
        nvgFillColor(nvg, nvgRGBA(qCfg.color[1], qCfg.color[2], qCfg.color[3], 220))
        nvgFill(nvg)
    end

    -- 鱼图标
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 18)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 220))
    nvgText(nvg, x + 8, y + h * 0.35, fishCfg and fishCfg.icon or "🐟")

    -- 名称
    nvgFontSize(nvg, 11)
    nvgFillColor(nvg, nvgRGBA(210, 225, 250, 210))
    local nameStr = (fishCfg and fishCfg.displayName or "???")
    nvgText(nvg, x + 26, y + h * 0.35, nameStr)

    -- Buff 信息 + 词条徽章
    if fishCfg then
        local buffDef = GameConfig.AQUARIUM.BUFF_PER_TYPE[fishCfg.fishType]
        if buffDef then
            local qMulti = GameConfig.AQUARIUM.QUALITY_BUFF_MULTI[slot.qualityId] or 1
            local affixMulti = 1.0
            if slot.affixes and #slot.affixes > 0 then
                affixMulti = AffixSystem.calcValueMultiplier(slot.affixes)
            end
            local buffVal = buffDef.base * qMulti * affixMulti
            nvgFontSize(nvg, 10)
            nvgFillColor(nvg, nvgRGBA(100, 220, 140, 200))
            nvgText(nvg, x + 8, y + h * 0.72,
                "+" .. FormatUtils.formatPercent(buffVal))
        end
    end

    -- 取出按钮
    local btnW = 32
    local btnH = 20
    local btnX = x + w - btnW - 5
    local btnY = y + (h - btnH) * 0.5

    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, btnX, btnY, btnW, btnH, 5)
    nvgFillColor(nvg, nvgRGBA(180, 70, 50, 180))
    nvgFill(nvg)

    nvgFontSize(nvg, 10)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 220))
    nvgText(nvg, btnX + btnW * 0.5, btnY + btnH * 0.5, "取出")

    table.insert(clickRects_, {
        x = btnX, y = btnY, w = btnW, h = btnH,
        action = "remove_slot_" .. slotIdx,
    })

    -- 词条徽章（取出按钮左侧）
    if slot.affixes and #slot.affixes > 0 then
        local summary = AffixSystem.getAffixSummary(slot.affixes)
        local highest = AffixSystem.getHighestRarity(slot.affixes)
        local rc = AffixConfig.RARITY[highest] or AffixConfig.RARITY[1]
        nvgFontSize(nvg, 9)
        nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(rc.color[1], rc.color[2], rc.color[3], 220))
        nvgText(nvg, btnX - 4, y + h * 0.35, "✦" .. summary)

        if AffixSystem.isFullAffix(slot.affixes) then
            local t = time_ * 2.0
            local rr = math.floor(128 + 127 * math.sin(t))
            local gg = math.floor(128 + 127 * math.sin(t + 2.09))
            local bb = math.floor(128 + 127 * math.sin(t + 4.19))
            nvgFillColor(nvg, nvgRGBA(rr, gg, bb, 255))
            nvgText(nvg, btnX - 4, y + h * 0.7, "★满")
        end

        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    end
end

function AquariumScene.renderEmptySlot(nvg, x, y, w, h, slotIdx)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, 8)
    nvgStrokeColor(nvg, nvgRGBA(80, 130, 180, 100))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)

    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 18)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(80, 140, 200, 150))
    nvgText(nvg, x + w * 0.35, y + h * 0.5, "+")

    nvgFontSize(nvg, 11)
    nvgFillColor(nvg, nvgRGBA(120, 160, 200, 150))
    nvgText(nvg, x + w * 0.65, y + h * 0.5, "放入")

    table.insert(clickRects_, {
        x = x, y = y, w = w, h = h,
        action = "open_slot_" .. slotIdx,
    })
end

function AquariumScene.renderLockedSlot(nvg, x, y, w, h, slotIdx)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, 8)
    nvgFillColor(nvg, nvgRGBA(20, 30, 40, 150))
    nvgFill(nvg)

    local cost = GameConfig.AQUARIUM.SLOT_UNLOCK_COST[slotIdx] or 0
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 11)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(150, 150, 170, 140))
    nvgText(nvg, x + w * 0.5, y + h * 0.5,
        "🔒 " .. FormatUtils.formatNumber(cost))

    table.insert(clickRects_, {
        x = x, y = y, w = w, h = h,
        action = "unlock_slot",
    })
end

-- ============================================================================
-- 鱼选择弹窗
-- ============================================================================

function AquariumScene.renderSelectPopup(nvg, sx, sy, sw, sh)
    -- 遮罩
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, sw, sh)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 120))
    nvgFill(nvg)

    -- 弹窗面板
    local popW = math.min(sw - 40, 320)
    local popH = math.min(sh - 80, 380)
    local popX = sx + (sw - popW) * 0.5
    local popY = sy + (sh - popH) * 0.5

    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, popX, popY, popW, popH, 14)
    nvgFillColor(nvg, nvgRGBA(10, 25, 55, 240))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(60, 120, 180, 150))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)

    -- 标题
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 16)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(220, 235, 255, 230))
    nvgText(nvg, popX + popW * 0.5, popY + 12,
        "选择鱼 (槽位 " .. selectPopup_.slotIndex .. ")")

    -- 关闭按钮
    local closeSize = 24
    local closeX = popX + popW - closeSize - 8
    local closeY = popY + 8
    nvgFontSize(nvg, 18)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(200, 100, 80, 220))
    nvgText(nvg, closeX + closeSize * 0.5, closeY + closeSize * 0.5, "✕")
    table.insert(clickRects_, {
        x = closeX, y = closeY, w = closeSize, h = closeSize,
        action = "close_select",
    })

    -- 提示: 放入鱼会提供什么Buff
    nvgFontSize(nvg, 11)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(160, 190, 220, 180))
    nvgText(nvg, popX + popW * 0.5, popY + 32,
        "放入鱼可获得全局加成和定期金币收入")

    -- 鱼列表
    local listX = popX + 10
    local listY = popY + 50
    local listW = popW - 20
    local itemH = 44
    local listH = popH - 62

    nvgSave(nvg)
    nvgScissor(nvg, listX, listY, listW, listH)

    for idx, fish in ipairs(selectPopup_.fishList) do
        local iy = listY + (idx - 1) * (itemH + 4) - selectPopup_.scrollY
        if iy + itemH < listY or iy > listY + listH then
            goto continue
        end

        -- 卡片
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, listX, iy, listW, itemH, 6)
        nvgFillColor(nvg, nvgRGBA(20, 45, 80, 200))
        nvgFill(nvg)

        -- 品质色条
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, listX, iy, 3, itemH, 2)
        nvgFillColor(nvg, nvgRGBA(fish.qualityColor[1], fish.qualityColor[2],
                                   fish.qualityColor[3], 220))
        nvgFill(nvg)

        -- 图标
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 20)
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 220))
        nvgText(nvg, listX + 10, iy + itemH * 0.4, fish.icon)

        -- 名称 + 品质
        nvgFontSize(nvg, 13)
        nvgFillColor(nvg, nvgRGBA(220, 235, 255, 220))
        nvgText(nvg, listX + 36, iy + itemH * 0.35,
            fish.displayName .. " [" .. fish.qualityName .. "]")

        -- 数量 + Buff 预览 / 词条信息
        nvgFontSize(nvg, 10)
        if fish.isAffix and fish.affixSummary then
            -- 词条鱼: 显示词条摘要
            local badgeText = "✦" .. fish.affixSummary
            local highest = AffixSystem.getHighestRarity(fish.affixes)
            local rc = AffixConfig.RARITY[highest] or AffixConfig.RARITY[1]
            nvgFillColor(nvg, nvgRGBA(rc.color[1], rc.color[2], rc.color[3], 220))
            nvgText(nvg, listX + 36, iy + itemH * 0.7, badgeText)

            if AffixSystem.isFullAffix(fish.affixes) then
                nvgFillColor(nvg, nvgRGBA(255, 215, 0, 255))
                nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                nvgText(nvg, listX + listW - 4, iy + itemH * 0.7, "★满词条")
                nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            end
        else
            nvgFillColor(nvg, nvgRGBA(140, 170, 200, 180))
            local fishCfg = GameConfig.FISH_BY_ID[fish.fishId]
            local buffStr = "x" .. fish.count
            if fishCfg then
                local buffDef = GameConfig.AQUARIUM.BUFF_PER_TYPE[fishCfg.fishType]
                if buffDef then
                    local qMulti = GameConfig.AQUARIUM.QUALITY_BUFF_MULTI[fish.qualityId] or 1
                    buffStr = buffStr .. "  +" .. FormatUtils.formatPercent(buffDef.base * qMulti)
                end
            end
            nvgText(nvg, listX + 36, iy + itemH * 0.7, buffStr)
        end

        -- 整行可点 (词条鱼带uid)
        local actionStr = "select_fish_" .. fish.fishId .. "_" .. fish.qualityId
        if fish.uid then
            actionStr = actionStr .. "_" .. fish.uid
        end
        table.insert(clickRects_, {
            x = listX, y = iy, w = listW, h = itemH,
            action = actionStr,
        })

        ::continue::
    end

    nvgRestore(nvg)
end

-- ============================================================================
-- 顶部 HUD
-- ============================================================================

function AquariumScene.renderHUD(nvg, x, y, w, h)
    -- 返回按钮
    local btnW = 60
    local btnH = 28
    local btnX = x + 12
    local btnY = y + 10

    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, btnX, btnY, btnW, btnH, 8)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 140))
    nvgFill(nvg)

    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 13)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 220))
    nvgText(nvg, btnX + btnW * 0.5, btnY + btnH * 0.5, "← 返回")

    table.insert(clickRects_, {
        x = btnX, y = btnY, w = btnW, h = btnH,
        action = "go_back",
    })

    -- 标题
    nvgFontSize(nvg, 18)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(150, 210, 255, 230))
    nvgText(nvg, x + w * 0.5, btnY + btnH * 0.5, "🐠 鱼缸")

    -- 金币
    nvgFontSize(nvg, 13)
    nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 215, 0, 230))
    nvgText(nvg, x + w - 12, btnY + btnH * 0.5,
        "💰 " .. FormatUtils.formatNumber(GameState.coins))
end

return AquariumScene
