-- ============================================================================
-- BreedingScene: 养殖场 NanoVG 场景
-- 网格槽位: 鱼图片 + 品质底框 + 收取按钮 + 点击tips
-- 配对繁殖: 两条相同鱼种 → 后代随机继承父母品质
-- ============================================================================
local GameConfig      = require("config.GameConfig")
local GameState       = require("state.GameState")
local BreedingSystem  = require("systems.BreedingSystem")
local WaterRenderer   = require("ui.WaterRenderer")
local FormatUtils     = require("utils.FormatUtils")
local AffixConfig     = require("config.AffixConfig")
local AffixSystem     = require("systems.AffixSystem")

local BreedingScene = {}

-- ============================================================================
-- 状态
-- ============================================================================
local time_ = 0
local clickRects_ = {}

-- 鱼图片缓存
local fishImages_ = {}  -- { [fishName] = { img=handle, w=N, h=N } }
local imagesLoaded_ = false

-- 鱼选择弹窗
local selectPopup_ = {
    open = false,
    slotIndex = 0,
    scrollY = 0,
    fishList = {},
}

-- 鱼信息 tips 弹窗
local tipPopup_ = {
    open = false,
    slotIndex = 0,
    fishId = 0,
    qualityId = 0,
    affixes = nil,
    whichFish = 0,  -- 1 或 2
}

-- toast 提示
local toastMsg_   = ""
local toastTimer_ = 0

-- 返回标志
local wantReturn_ = false

-- 滚动
local scrollY_ = 0
local maxScrollY_ = 0

-- ============================================================================
-- 初始化
-- ============================================================================

function BreedingScene.init(nvg)
    WaterRenderer.init(nvg)

    -- 加载鱼图片
    if not imagesLoaded_ then
        for name, path in pairs(GameConfig.FISH_IMAGE) do
            local img = nvgCreateImage(nvg, path, 0)
            if img and img > 0 then
                local iw, ih = nvgImageSize(nvg, img)
                if iw < 16 or ih < 16 then iw, ih = 256, 256 end
                fishImages_[name] = { img = img, w = iw, h = ih }
            end
        end
        imagesLoaded_ = true
    end

    print("[BreedingScene] 初始化完成")
end

function BreedingScene.update(dt)
    time_ = time_ + dt
    if toastTimer_ > 0 then
        toastTimer_ = toastTimer_ - dt
    end

    -- 滚动
    local wheel = input.mouseMove.y  -- 这里不需要滚轮，暂不处理
end

-- ============================================================================
-- 输入检测
-- ============================================================================

--- @return string|nil action  "go_back" | nil
function BreedingScene.checkInput()
    wantReturn_ = false

    if not input:GetMouseButtonPress(MOUSEB_LEFT) then
        return nil
    end

    local dpr = graphics:GetDPR()
    local mx = input.mousePosition.x / dpr
    local my = input.mousePosition.y / dpr

    -- tips 弹窗优先
    if tipPopup_.open then
        -- 点击任何位置关闭 tips
        tipPopup_.open = false
        return nil
    end

    -- 鱼选择弹窗
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
                    local uid = tonumber(parts[5])
                    if fishId and qualityId then
                        local ok, err = BreedingSystem:placeFish(
                            selectPopup_.slotIndex, fishId, qualityId, uid)
                        if ok then
                            BreedingScene.showToast("放入成功!")
                        else
                            BreedingScene.showToast(err or "放入失败")
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
                    BreedingScene.onSlotClick(slotIdx)
                end
                return nil
            elseif rect.action and rect.action:sub(1, 7) == "collect" then
                -- "collect_N"
                local slotIdx = tonumber(rect.action:sub(9))
                if slotIdx then
                    local result = BreedingSystem:collectProduce(slotIdx)
                    if result then
                        local fishCfg = GameConfig.FISH_BY_ID[result.fishId]
                        local qCfg = GameConfig.QUALITY[result.qualityId]
                        BreedingScene.showToast("收取 " .. fishCfg.displayName .. " [" .. qCfg.displayName .. "]!")
                    end
                end
                return nil
            elseif rect.action and rect.action:sub(1, 8) == "fish_tip" then
                -- "fish_tip_slotIdx_whichFish"
                local parts = {}
                for p in rect.action:gmatch("[^_]+") do
                    table.insert(parts, p)
                end
                local slotIdx = tonumber(parts[3])
                local whichFish = tonumber(parts[4])
                if slotIdx then
                    BreedingScene.showTip(slotIdx, whichFish)
                end
                return nil
            elseif rect.action and rect.action:sub(1, 10) == "remove_all" then
                -- "remove_all_N"
                local slotIdx = tonumber(rect.action:sub(12))
                if slotIdx then
                    BreedingSystem:removeFish(slotIdx)
                    BreedingScene.showToast("鱼已取回仓库!")
                end
                return nil
            elseif rect.action == "unlock_slot" then
                local ok, err = BreedingSystem:unlockSlot()
                if ok then
                    BreedingScene.showToast("解锁新槽位!")
                else
                    BreedingScene.showToast(err or "解锁失败")
                end
                return nil
            end
        end
    end

    return nil
end

-- ============================================================================
-- 槽位点击 → 打开鱼选择弹窗
-- ============================================================================

function BreedingScene.onSlotClick(slotIdx)
    local slot = GameState.breedingSlots[slotIdx]

    -- 检查是否已满
    if slot and slot.fish2 then
        return  -- 已配对，不操作
    end

    selectPopup_.slotIndex = slotIdx
    selectPopup_.scrollY = 0
    selectPopup_.fishList = {}

    -- 如果已有一条鱼，只列出相同种类
    local filterFishId = slot and slot.fishId or nil

    -- 词条鱼
    for _, indiv in pairs(GameState:getAllIndividuals()) do
        local fish = GameConfig.FISH_BY_ID[indiv.fishId]
        if fish and (not filterFishId or indiv.fishId == filterFishId) then
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

    -- 普通鱼
    for _, fish in ipairs(GameConfig.FISH) do
        if not filterFishId or fish.id == filterFishId then
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
    end

    if #selectPopup_.fishList == 0 then
        if filterFishId then
            local fc = GameConfig.FISH_BY_ID[filterFishId]
            BreedingScene.showToast("没有更多 " .. (fc and fc.displayName or "") .. " 了!")
        else
            BreedingScene.showToast("没有可放入的鱼!")
        end
        return
    end

    selectPopup_.open = true
end

-- ============================================================================
-- Tips 弹窗
-- ============================================================================

function BreedingScene.showTip(slotIdx, whichFish)
    local slot = GameState.breedingSlots[slotIdx]
    if not slot then return end

    local fishInfo = (whichFish == 2) and slot.fish2 or slot.fish1
    if not fishInfo then return end

    tipPopup_.open = true
    tipPopup_.slotIndex = slotIdx
    tipPopup_.fishId = slot.fishId
    tipPopup_.qualityId = fishInfo.qualityId
    tipPopup_.affixes = fishInfo.affixes
    tipPopup_.whichFish = whichFish or 1
end

function BreedingScene.showToast(msg)
    toastMsg_ = msg
    toastTimer_ = 2.0
end

-- ============================================================================
-- 渲染主函数
-- ============================================================================

function BreedingScene.render(nvg, x, y, w, h)
    clickRects_ = {}

    -- 1) 水面背景
    WaterRenderer.render(nvg, x, y, w, h, time_)

    -- 2) 顶部 HUD
    BreedingScene.renderHUD(nvg, x, y, w, h)

    -- 3) 网格槽位区域 (主体)
    local gridTop = y + 48
    local gridH = h - 58
    BreedingScene.renderSlotGrid(nvg, x + 8, gridTop, w - 16, gridH)

    -- 4) 鱼选择弹窗
    if selectPopup_.open then
        BreedingScene.renderSelectPopup(nvg, x, y, w, h)
    end

    -- 5) Tips 弹窗
    if tipPopup_.open then
        BreedingScene.renderTipPopup(nvg, x, y, w, h)
    end

    -- 6) Toast
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
-- 网格槽位
-- ============================================================================

function BreedingScene.renderSlotGrid(nvg, gx, gy, gw, gh)
    -- 半透明底板
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, gx, gy, gw, gh, 10)
    nvgFillColor(nvg, nvgRGBA(5, 20, 45, 160))
    nvgFill(nvg)

    -- 标题行
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 14)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(180, 220, 255, 200))
    nvgText(nvg, gx + 10, gy + 6, "养殖槽位 (" .. GameState.unlockedBreedingSlots .. "/" .. GameConfig.BREEDING.MAX_SLOTS .. ")")

    -- 网格参数: 4 列
    local cols = 4
    local pad = 8
    local titleH = 26
    local contentTop = gy + titleH
    local contentH = gh - titleH - 4
    local cellW = math.floor((gw - pad * (cols + 1)) / cols)
    local cellH = cellW + 30  -- 正方形 + 底部按钮区

    -- 裁剪区域
    nvgSave(nvg)
    nvgScissor(nvg, gx, contentTop, gw, contentH)

    local totalSlots = math.min(GameConfig.BREEDING.MAX_SLOTS, GameState.unlockedBreedingSlots + 1)  -- 显示到下一个锁定槽
    local rows = math.ceil(totalSlots / cols)

    for i = 1, totalSlots do
        local row = math.floor((i - 1) / cols)
        local col = (i - 1) % cols
        local cx = gx + pad + col * (cellW + pad)
        local cy = contentTop + pad + row * (cellH + pad) - scrollY_

        -- 超出可见范围跳过
        if cy + cellH < contentTop or cy > contentTop + contentH then
            goto continue
        end

        if i <= GameState.unlockedBreedingSlots then
            local slot = GameState.breedingSlots[i]
            if slot then
                BreedingScene.renderOccupiedCell(nvg, cx, cy, cellW, cellH, i, slot)
            else
                BreedingScene.renderEmptyCell(nvg, cx, cy, cellW, cellH, i)
            end
        else
            BreedingScene.renderLockedCell(nvg, cx, cy, cellW, cellH, i)
        end

        ::continue::
    end

    nvgRestore(nvg)

    -- 更新最大滚动
    maxScrollY_ = math.max(0, rows * (cellH + pad) + pad - contentH)
end

-- ============================================================================
-- 有鱼的槽位格子
-- ============================================================================

function BreedingScene.renderOccupiedCell(nvg, cx, cy, cw, ch, slotIdx, slot)
    local fishCfg = GameConfig.FISH_BY_ID[slot.fishId]
    local fishName = fishCfg and fishCfg.name or "sardine"

    -- 获取两条鱼的品质颜色
    local q1 = slot.fish1 and slot.fish1.qualityId or 1
    local q2 = slot.fish2 and slot.fish2.qualityId or nil
    local qCfg1 = GameConfig.QUALITY[q1]

    -- 底框用更高品质的颜色
    local borderQ = q1
    if q2 and q2 > q1 then borderQ = q2 end
    local borderCfg = GameConfig.QUALITY[borderQ]
    local bc = borderCfg.color

    -- === 品质底框 ===
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, cx, cy, cw, cw, 8)  -- 正方形区域
    nvgFillColor(nvg, nvgRGBA(bc[1], bc[2], bc[3], 40))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(bc[1], bc[2], bc[3], 180))
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)

    -- === 鱼图片 ===
    local imgData = fishImages_[fishName]
    local imgArea = cw - 12
    local imgX = cx + 6
    local imgY = cy + 6

    if imgData and imgData.img > 0 then
        -- 绘制鱼图片
        local scale = imgArea / math.max(imgData.w, imgData.h)
        local drawW = imgData.w * scale
        local drawH = imgData.h * scale
        local drawX = imgX + (imgArea - drawW) * 0.5
        local drawY = imgY + (imgArea - drawH) * 0.5

        local imgPat = nvgImagePattern(nvg, drawX, drawY, drawW, drawH, 0, imgData.img, 1.0)
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, drawX, drawY, drawW, drawH, 4)
        nvgFillPaint(nvg, imgPat)
        nvgFill(nvg)
    else
        -- Emoji 回退
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 36)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 220))
        nvgText(nvg, cx + cw * 0.5, cy + cw * 0.5, fishCfg and fishCfg.icon or "fish_sardine")
    end

    -- 点击鱼图片区域 → 显示 tips (第一条鱼)
    table.insert(clickRects_, {
        x = cx, y = cy, w = cw, h = cw,
        action = "fish_tip_" .. slotIdx .. "_1",
    })

    -- === 配对状态指示 ===
    local isPaired = slot.fish2 ~= nil
    local hasProduced = slot.produced ~= nil

    if not isPaired then
        -- 只有一条鱼，显示"等待配对"标签
        local labelY = cy + cw - 18
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cx + 2, labelY, cw - 4, 16, 4)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 160))
        nvgFill(nvg)
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 10)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(255, 200, 100, 220))
        nvgText(nvg, cx + cw * 0.5, labelY + 8, "➕ 配对")

        -- 点击"配对"区域 → 打开选鱼弹窗 (筛选同种)
        table.insert(clickRects_, {
            x = cx + 2, y = labelY, w = cw - 4, h = 16,
            action = "open_slot_" .. slotIdx,
        })
    else
        -- 已配对: 显示品质标签
        local labelY = cy + cw - 18
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cx + 2, labelY, cw - 4, 16, 4)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 160))
        nvgFill(nvg)

        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 10)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

        local qCfg2 = GameConfig.QUALITY[q2]
        nvgFillColor(nvg, nvgRGBA(qCfg1.color[1], qCfg1.color[2], qCfg1.color[3], 220))
        nvgText(nvg, cx + cw * 0.3, labelY + 8, qCfg1.displayName)
        nvgFillColor(nvg, nvgRGBA(200, 200, 200, 180))
        nvgText(nvg, cx + cw * 0.5, labelY + 8, "×")
        nvgFillColor(nvg, nvgRGBA(qCfg2.color[1], qCfg2.color[2], qCfg2.color[3], 220))
        nvgText(nvg, cx + cw * 0.7, labelY + 8, qCfg2.displayName)
    end

    -- === 底部区域: 进度/收取/取出 ===
    local bottomY = cy + cw + 2
    local bottomH = ch - cw - 2

    if hasProduced then
        -- 有产出 → 收取按钮
        local pFish = slot.produced
        local pQCfg = GameConfig.QUALITY[pFish.qualityId]
        local btnW = cw
        local btnH = bottomH

        -- 发光收取按钮
        local pulse = 0.5 + 0.5 * math.sin(time_ * 3)
        local gAlpha = math.floor(120 + 80 * pulse)
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cx, bottomY, btnW, btnH, 6)
        nvgFillColor(nvg, nvgRGBA(40, 160, 80, gAlpha))
        nvgFill(nvg)

        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 12)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 240))
        nvgText(nvg, cx + btnW * 0.5, bottomY + btnH * 0.5, "收取")

        table.insert(clickRects_, {
            x = cx, y = bottomY, w = btnW, h = btnH,
            action = "collect_" .. slotIdx,
        })
    elseif isPaired then
        -- 繁殖中 → 进度条
        local progress = BreedingSystem:getSlotProgress(slotIdx)
        local remaining = BreedingSystem:getSlotRemainingTime(slotIdx)

        -- 进度条背景
        local barX = cx + 2
        local barY = bottomY + 2
        local barW = cw - 4
        local barH = 8

        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, barX, barY, barW, barH, 4)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 120))
        nvgFill(nvg)

        if progress > 0 then
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, barX, barY, barW * progress, barH, 4)
            nvgFillColor(nvg, nvgRGBA(80, 200, 120, 220))
            nvgFill(nvg)
        end

        -- 时间文字
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 10)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(180, 210, 240, 180))
        nvgText(nvg, cx + cw * 0.5, barY + barH + 2, FormatUtils.formatTime(remaining))

        -- 取出按钮 (小)
        local rmW = cw
        local rmH = 12
        local rmY = barY + barH + 14
        nvgFontSize(nvg, 9)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(180, 100, 80, 160))
        nvgText(nvg, cx + rmW * 0.5, rmY + rmH * 0.5, "取出")
        table.insert(clickRects_, {
            x = cx, y = rmY, w = rmW, h = rmH,
            action = "remove_all_" .. slotIdx,
        })
    else
        -- 只有一条鱼，显示取出
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 10)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(180, 100, 80, 180))
        nvgText(nvg, cx + cw * 0.5, bottomY + bottomH * 0.5, "取出")
        table.insert(clickRects_, {
            x = cx, y = bottomY, w = cw, h = bottomH,
            action = "remove_all_" .. slotIdx,
        })
    end
end

-- ============================================================================
-- 空槽位
-- ============================================================================

function BreedingScene.renderEmptyCell(nvg, cx, cy, cw, ch, slotIdx)
    -- 虚线框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, cx, cy, cw, cw, 8)
    nvgStrokeColor(nvg, nvgRGBA(80, 120, 180, 100))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)

    -- "+" 号
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 28)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(100, 160, 220, 150))
    nvgText(nvg, cx + cw * 0.5, cy + cw * 0.4, "+")

    nvgFontSize(nvg, 11)
    nvgFillColor(nvg, nvgRGBA(120, 160, 200, 150))
    nvgText(nvg, cx + cw * 0.5, cy + cw * 0.7, "放入鱼")

    table.insert(clickRects_, {
        x = cx, y = cy, w = cw, h = ch,
        action = "open_slot_" .. slotIdx,
    })
end

-- ============================================================================
-- 锁定槽位
-- ============================================================================

function BreedingScene.renderLockedCell(nvg, cx, cy, cw, ch, slotIdx)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, cx, cy, cw, cw, 8)
    nvgFillColor(nvg, nvgRGBA(20, 25, 35, 150))
    nvgFill(nvg)

    local cost = GameConfig.BREEDING.SLOT_UNLOCK_COST[slotIdx] or 0

    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 20)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(120, 120, 140, 150))
    nvgText(nvg, cx + cw * 0.5, cy + cw * 0.4, "锁定")

    nvgFontSize(nvg, 9)
    nvgFillColor(nvg, nvgRGBA(160, 160, 180, 140))
    nvgText(nvg, cx + cw * 0.5, cy + cw * 0.7, FormatUtils.formatNumber(cost) .. " 金币")

    table.insert(clickRects_, {
        x = cx, y = cy, w = cw, h = ch,
        action = "unlock_slot",
    })
end

-- ============================================================================
-- Tips 弹窗 (鱼类信息)
-- ============================================================================

function BreedingScene.renderTipPopup(nvg, sx, sy, sw, sh)
    -- 遮罩
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, sw, sh)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 120))
    nvgFill(nvg)

    local fishCfg = GameConfig.FISH_BY_ID[tipPopup_.fishId]
    if not fishCfg then
        tipPopup_.open = false
        return
    end

    local qCfg = GameConfig.QUALITY[tipPopup_.qualityId]
    local qc = qCfg.color

    -- 弹窗面板
    local popW = math.min(sw - 40, 280)
    local popH = 260
    local popX = sx + (sw - popW) * 0.5
    local popY = sy + (sh - popH) * 0.5

    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, popX, popY, popW, popH, 14)
    nvgFillColor(nvg, nvgRGBA(12, 30, 55, 245))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(qc[1], qc[2], qc[3], 180))
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)

    -- 鱼图片 (居中)
    local imgSize = 80
    local imgCx = popX + popW * 0.5
    local imgCy = popY + 20

    local imgData = fishImages_[fishCfg.name]
    if imgData and imgData.img > 0 then
        local scale = imgSize / math.max(imgData.w, imgData.h)
        local drawW = imgData.w * scale
        local drawH = imgData.h * scale
        local drawX = imgCx - drawW * 0.5
        local drawY = imgCy

        -- 品质底框
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, drawX - 4, drawY - 4, drawW + 8, drawH + 8, 8)
        nvgFillColor(nvg, nvgRGBA(qc[1], qc[2], qc[3], 50))
        nvgFill(nvg)
        nvgStrokeColor(nvg, nvgRGBA(qc[1], qc[2], qc[3], 150))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)

        local imgPat = nvgImagePattern(nvg, drawX, drawY, drawW, drawH, 0, imgData.img, 1.0)
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, drawX, drawY, drawW, drawH, 4)
        nvgFillPaint(nvg, imgPat)
        nvgFill(nvg)
    else
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 50)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 220))
        nvgText(nvg, imgCx, imgCy + imgSize * 0.5, fishCfg.icon)
    end

    -- 鱼名称
    local textY = popY + 20 + imgSize + 14
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 16)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(qc[1], qc[2], qc[3], 240))
    nvgText(nvg, popX + popW * 0.5, textY, fishCfg.displayName)

    -- 品质
    textY = textY + 22
    nvgFontSize(nvg, 13)
    nvgFillColor(nvg, nvgRGBA(qc[1], qc[2], qc[3], 200))
    nvgText(nvg, popX + popW * 0.5, textY, "品质: " .. qCfg.displayName .. " (×" .. qCfg.multiplier .. ")")

    -- 描述
    textY = textY + 22
    nvgFontSize(nvg, 12)
    nvgFillColor(nvg, nvgRGBA(180, 200, 220, 200))
    nvgText(nvg, popX + popW * 0.5, textY, fishCfg.desc or "")

    -- 基础价值
    textY = textY + 20
    nvgFontSize(nvg, 12)
    nvgFillColor(nvg, nvgRGBA(255, 215, 0, 200))
    nvgText(nvg, popX + popW * 0.5, textY, "基础价值: " .. fishCfg.baseValue)

    -- 海域
    textY = textY + 18
    nvgFillColor(nvg, nvgRGBA(100, 180, 255, 180))
    nvgText(nvg, popX + popW * 0.5, textY,
        (GameConfig.ZONE_DISPLAY[fishCfg.zone] or fishCfg.zone))

    -- 词条信息
    if tipPopup_.affixes and #tipPopup_.affixes > 0 then
        textY = textY + 22
        local summary = AffixSystem.getAffixSummary(tipPopup_.affixes)
        local highest = AffixSystem.getHighestRarity(tipPopup_.affixes)
        local rc = AffixConfig.RARITY[highest] or AffixConfig.RARITY[1]
        nvgFillColor(nvg, nvgRGBA(rc.color[1], rc.color[2], rc.color[3], 230))
        nvgText(nvg, popX + popW * 0.5, textY, "✦ 词条: " .. summary)
    end

    -- "点击关闭" 提示
    nvgFontSize(nvg, 10)
    nvgFillColor(nvg, nvgRGBA(120, 140, 160, 140))
    nvgText(nvg, popX + popW * 0.5, popY + popH - 16, "点击任意位置关闭")
end

-- ============================================================================
-- 鱼选择弹窗
-- ============================================================================

function BreedingScene.renderSelectPopup(nvg, sx, sy, sw, sh)
    -- 遮罩
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, sw, sh)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 120))
    nvgFill(nvg)

    -- 弹窗面板
    local popW = math.min(sw - 30, 320)
    local popH = math.min(sh - 60, 400)
    local popX = sx + (sw - popW) * 0.5
    local popY = sy + (sh - popH) * 0.5

    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, popX, popY, popW, popH, 14)
    nvgFillColor(nvg, nvgRGBA(15, 35, 65, 240))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(80, 140, 200, 150))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)

    -- 标题
    local slot = GameState.breedingSlots[selectPopup_.slotIndex]
    local titleStr = "选择鱼苗"
    if slot and slot.fish1 then
        local fc = GameConfig.FISH_BY_ID[slot.fishId]
        titleStr = "配对: " .. (fc and fc.displayName or "???")
    end

    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 15)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(220, 235, 255, 230))
    nvgText(nvg, popX + popW * 0.5, popY + 12, titleStr)

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

    -- 鱼列表
    local listX = popX + 10
    local listY = popY + 36
    local listW = popW - 20
    local itemH = 48
    local listH = popH - 48

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
        nvgFillColor(nvg, nvgRGBA(25, 55, 90, 200))
        nvgFill(nvg)

        -- 品质色条
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, listX, iy, 3, itemH, 2)
        nvgFillColor(nvg, nvgRGBA(fish.qualityColor[1], fish.qualityColor[2],
                                   fish.qualityColor[3], 220))
        nvgFill(nvg)

        -- 鱼图片 (小)
        local fishCfg = GameConfig.FISH_BY_ID[fish.fishId]
        local fishName = fishCfg and fishCfg.name or "sardine"
        local imgData = fishImages_[fishName]
        local thumbSize = 36
        local thumbX = listX + 8
        local thumbY = iy + (itemH - thumbSize) * 0.5

        if imgData and imgData.img > 0 then
            local scale = thumbSize / math.max(imgData.w, imgData.h)
            local dw = imgData.w * scale
            local dh = imgData.h * scale
            local dx = thumbX + (thumbSize - dw) * 0.5
            local dy = thumbY + (thumbSize - dh) * 0.5

            local pat = nvgImagePattern(nvg, dx, dy, dw, dh, 0, imgData.img, 1.0)
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, dx, dy, dw, dh, 3)
            nvgFillPaint(nvg, pat)
            nvgFill(nvg)
        else
            nvgFontFace(nvg, "sans")
            nvgFontSize(nvg, 22)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, 220))
            nvgText(nvg, thumbX + thumbSize * 0.5, thumbY + thumbSize * 0.5, fish.icon)
        end

        -- 名称 + 品质
        local textX = thumbX + thumbSize + 6
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 13)
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(220, 235, 255, 220))
        nvgText(nvg, textX, iy + itemH * 0.35,
            fish.displayName .. " [" .. fish.qualityName .. "]")

        -- 数量 / 词条信息
        nvgFontSize(nvg, 11)
        if fish.isAffix and fish.affixSummary then
            local highest = AffixSystem.getHighestRarity(fish.affixes)
            local rc = AffixConfig.RARITY[highest] or AffixConfig.RARITY[1]
            nvgFillColor(nvg, nvgRGBA(rc.color[1], rc.color[2], rc.color[3], 220))
            nvgText(nvg, textX, iy + itemH * 0.7, "✦" .. fish.affixSummary)
        else
            nvgFillColor(nvg, nvgRGBA(160, 180, 200, 180))
            nvgText(nvg, textX, iy + itemH * 0.7, "x" .. fish.count)
        end

        -- 整行可点
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

function BreedingScene.renderHUD(nvg, x, y, w, h)
    -- 半透明顶栏背景
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, 44)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 100))
    nvgFill(nvg)

    -- 返回按钮
    local btnW = 56
    local btnH = 26
    local btnX = x + 8
    local btnY = y + 9

    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, btnX, btnY, btnW, btnH, 8)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 140))
    nvgFill(nvg)

    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 12)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 220))
    nvgText(nvg, btnX + btnW * 0.5, btnY + btnH * 0.5, "← 返回")

    table.insert(clickRects_, {
        x = btnX, y = btnY, w = btnW, h = btnH,
        action = "go_back",
    })

    -- 标题
    nvgFontSize(nvg, 17)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 240, 200, 230))
    nvgText(nvg, x + w * 0.5, btnY + btnH * 0.5, "养殖场")

    -- 金币
    nvgFontSize(nvg, 12)
    nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 215, 0, 230))
    nvgText(nvg, x + w - 10, btnY + btnH * 0.5,
        FormatUtils.formatNumber(GameState.coins) .. " 金币")
end

return BreedingScene
