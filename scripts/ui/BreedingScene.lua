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
local UICore          = require("ui.UICore")
local IconManager     = require("ui.IconManager")

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
-- 弹窗动画
local selectPopupT_ = 0
local tipPopupT_    = 0

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

-- 养殖观赏区：游动鱼影列表
-- { icon, x, y, vx, vy, size, phase, flipX, alpha }
-- x/y 是相对于观赏区矩形的绝对像素坐标
local breedingActors_ = {}
local actorsSyncTimer_ = 0   -- 每 2s 同步一次槽位 → actors

-- 观赏区尺寸缓存（每帧由 render 写入，update 读取）
local aquaX_, aquaY_, aquaW_, aquaH_ = 0, 0, 390, 220

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
    -- 弹窗动画
    if selectPopup_.open then
        selectPopupT_ = math.min(1.0, selectPopupT_ + dt / 0.25)
    else
        selectPopupT_ = math.max(0.0, selectPopupT_ - dt / 0.15)
    end
    if tipPopup_.open then
        tipPopupT_ = math.min(1.0, tipPopupT_ + dt / 0.25)
    else
        tipPopupT_ = math.max(0.0, tipPopupT_ - dt / 0.15)
    end

    -- 滚动
    local wheel = input.mouseMove.y  -- 这里不需要滚轮，暂不处理

    -- ── 观赏区鱼影同步 ──
    actorsSyncTimer_ = actorsSyncTimer_ - dt
    if actorsSyncTimer_ <= 0 then
        actorsSyncTimer_ = 2.0
        BreedingScene.syncActors()
    end

    -- ── 观赏区鱼影运动 ──
    local aw = aquaW_
    local ah = aquaH_
    for _, a in ipairs(breedingActors_) do
        a.x = a.x + a.vx * dt * aw
        a.y = a.y + a.vy * dt * ah
        a.phase = a.phase + dt
        -- 水平碰壁翻转
        local margin = a.size * 0.5
        if a.vx > 0 and a.x > aw - margin then
            a.vx = -math.abs(a.vx)
            a.flipX = true
        elseif a.vx < 0 and a.x < margin then
            a.vx = math.abs(a.vx)
            a.flipX = false
        end
        -- 垂直软边界（保持在观赏区内）
        local yMin = ah * 0.12 + margin
        local yMax = ah * 0.88 - margin
        if a.y < yMin then a.y = yMin; a.vy = math.abs(a.vy) end
        if a.y > yMax then a.y = yMax; a.vy = -math.abs(a.vy) end
    end
end

-- ============================================================================
-- 观赏区鱼影同步：从养殖槽提取鱼种，生成/更新 actors
-- ============================================================================
function BreedingScene.syncActors()
    -- 统计槽位中各鱼种数量
    local fishCounts = {}  -- icon → count
    for _, slot in pairs(GameState.breedingSlots) do
        if slot and slot.fishId then
            local cfg = GameConfig.FISH_BY_ID[slot.fishId]
            if cfg then
                local key = cfg.icon or ("fish_" .. cfg.name)
                fishCounts[key] = (fishCounts[key] or 0) + 1
                if slot.fish2 then
                    fishCounts[key] = fishCounts[key] + 1
                end
            end
        end
    end

    -- 目标数量：每条鱼对应 1 个 actor，上限 12 个
    local desired = {}
    for icon, cnt in pairs(fishCounts) do
        for _ = 1, math.min(cnt, 3) do
            table.insert(desired, icon)
        end
    end
    -- 至少保留 3 个占位（空槽时也有鱼影）
    if #desired == 0 then return end

    -- 将现有 actors 按 icon 索引
    local existing = {}
    for _, a in ipairs(breedingActors_) do
        existing[a.icon] = existing[a.icon] or {}
        table.insert(existing[a.icon], a)
    end

    -- 重建 actors 列表
    local aw = math.max(aquaW_, 100)
    local ah = math.max(aquaH_, 80)
    local newActors = {}
    for _, icon in ipairs(desired) do
        local pool = existing[icon]
        if pool and #pool > 0 then
            -- 复用已有
            table.insert(newActors, table.remove(pool))
        else
            -- 新建：随机位置、速度
            local sz = 36 + math.random() * 28
            local spd = 0.06 + math.random() * 0.08
            local dir = math.random() < 0.5
            table.insert(newActors, {
                icon  = icon,
                x     = math.random() * (aw - sz) + sz * 0.5,
                y     = ah * 0.2 + math.random() * (ah * 0.6),
                vx    = dir and spd or -spd,
                vy    = (math.random() - 0.5) * 0.04,
                size  = sz,
                phase = math.random() * math.pi * 2,
                flipX = not dir,
            })
        end
    end
    breedingActors_ = newActors
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

    -- 布局参数
    local hudH    = 46
    local aquaH   = math.floor(h * 0.40)   -- 上 40%: 观赏区
    local slotH   = h - hudH - aquaH - 4    -- 下方: 槽位面板

    local aquaTop = y + hudH
    local slotTop = aquaTop + aquaH + 4

    -- 缓存观赏区尺寸供 update() 使用
    aquaX_ = x; aquaY_ = aquaTop; aquaW_ = w; aquaH_ = aquaH

    -- 1) 水面背景（覆盖全屏）
    WaterRenderer.render(nvg, x, y, w, h, time_)

    -- 2) 顶部 HUD
    BreedingScene.renderHUD(nvg, x, y, w, h)

    -- 3) 观赏区（鱼影游动）
    BreedingScene.renderAquarium(nvg, x, aquaTop, w, aquaH)

    -- 4) 槽位面板
    BreedingScene.renderSlotGrid(nvg, x + 6, slotTop, w - 12, slotH)

    -- 5) 鱼选择弹窗
    if selectPopup_.open then
        BreedingScene.renderSelectPopup(nvg, x, y, w, h)
    end

    -- 6) Tips 弹窗
    if tipPopup_.open then
        BreedingScene.renderTipPopup(nvg, x, y, w, h)
    end

    -- 6) Toast
    if toastTimer_ > 0 then
        local sc = w / 390
        sc = math.max(0.7, math.min(1.5, sc))
        local alpha = math.min(1, toastTimer_ * 2)
        local tx = x + w * 0.5
        local ty = y + h * 0.42
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, math.floor(15 * sc))
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        local tw = nvgTextBounds(nvg, 0, 0, toastMsg_)
        local pw = tw + math.floor(40 * sc)
        local ph = math.floor(38 * sc)
        nvgSave(nvg)
        nvgGlobalAlpha(nvg, alpha)
        -- 面板背景
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, tx - pw * 0.5, ty - ph * 0.5, pw, ph, math.floor(12 * sc))
        nvgFillColor(nvg, nvgRGBA(8, 38, 82, 220))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, tx - pw * 0.5, ty - ph * 0.5, pw, ph, math.floor(12 * sc))
        nvgStrokeColor(nvg, nvgRGBA(60, 210, 248, 180))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)
        -- 文字描边
        nvgFillColor(nvg, nvgRGBA(5, 18, 55, 255))
        for i = 0, 7 do
            local a = i * math.pi / 4
            nvgText(nvg, tx + math.cos(a) * 1.5, ty + math.sin(a) * 1.5, toastMsg_)
        end
        nvgFillColor(nvg, nvgRGBA(235, 248, 255, 255))
        nvgText(nvg, tx, ty, toastMsg_)
        nvgRestore(nvg)
    end
end

-- ============================================================================
-- 观赏区：水族缸风格，展示已养殖的鱼影
-- ============================================================================

function BreedingScene.renderAquarium(nvg, x, y, w, h)
    -- ── 顶部渐变分隔线（HUD 下方入水感）──
    local topFadePaint = nvgLinearGradient(nvg, x, y, x, y + 14,
        nvgRGBA(60, 210, 248, 60), nvgRGBA(60, 210, 248, 0))
    nvgBeginPath(nvg); nvgRect(nvg, x, y, w, 14)
    nvgFillPaint(nvg, topFadePaint); nvgFill(nvg)

    -- ── 焦散纹理动画（用 NanoVG 程序化波纹模拟）──
    local waveCount = 8
    for i = 1, waveCount do
        local wx  = x + (i / waveCount) * w + math.sin(time_ * 0.7 + i * 1.3) * w * 0.08
        local wy  = y + (i * 0.13 % 1.0) * h + math.cos(time_ * 0.5 + i * 0.9) * h * 0.06
        local wr  = w * 0.04 + math.sin(time_ + i) * w * 0.012
        local wa  = math.floor(8 + 6 * math.sin(time_ * 0.8 + i * 0.7))
        nvgBeginPath(nvg)
        nvgEllipse(nvg, wx, wy, wr, wr * 0.35)
        nvgStrokeColor(nvg, nvgRGBA(120, 220, 255, wa))
        nvgStrokeWidth(nvg, 1.0)
        nvgStroke(nvg)
    end

    -- ── 水深渐变叠加（给整个观赏区加一层半透明深色）──
    local depthPaint = nvgLinearGradient(nvg, x, y, x, y + h,
        nvgRGBA(5, 25, 65, 30), nvgRGBA(3, 15, 45, 80))
    nvgBeginPath(nvg); nvgRect(nvg, x, y, w, h)
    nvgFillPaint(nvg, depthPaint); nvgFill(nvg)

    -- ── 绘制鱼影 actors ──
    if #breedingActors_ > 0 then
        nvgSave(nvg)
        nvgScissor(nvg, x, y, w, h)
        for _, a in ipairs(breedingActors_) do
            -- 上下浮动偏移
            local wobble = math.sin(a.phase * 1.2) * 4
            local ax = x + a.x
            local ay = y + a.y + wobble

            -- 边缘淡出透明度
            local edgeDist = math.min(a.x, w - a.x, a.y, h - a.y)
            local edgeAlpha = math.min(1.0, edgeDist / (a.size * 0.8))
            -- 微呼吸缩放
            local breathScale = 1.0 + 0.03 * math.sin(a.phase * 0.8)
            local drawSize = a.size * breathScale

            nvgSave(nvg)
            nvgTranslate(nvg, ax, ay)
            if a.flipX then
                nvgScale(nvg, -1, 1)
            end

            -- 阴影光晕（鱼下方）
            local shadowPaint = nvgRadialGradient(nvg,
                0, drawSize * 0.35,
                drawSize * 0.1, drawSize * 0.55,
                nvgRGBA(0, 10, 30, math.floor(60 * edgeAlpha)),
                nvgRGBA(0, 10, 30, 0))
            nvgBeginPath(nvg)
            nvgEllipse(nvg, 0, drawSize * 0.35, drawSize * 0.55, drawSize * 0.18)
            nvgFillPaint(nvg, shadowPaint); nvgFill(nvg)

            -- 鱼图标
            nvgGlobalAlpha(nvg, 0.82 * edgeAlpha)
            IconManager.drawCentered(nvg, a.icon, 0, 0, drawSize)
            nvgGlobalAlpha(nvg, 1.0)

            nvgRestore(nvg)
        end
        nvgRestore(nvg)
    else
        -- 无鱼时显示提示
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 13)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(100, 160, 210, 100))
        nvgText(nvg, x + w * 0.5, y + h * 0.5, "放入鱼苗后，鱼儿会在这里游动 🐟")
    end

    -- ── 底部分隔线（入水感渐变）──
    local bottomPaint = nvgLinearGradient(nvg, x, y + h - 10, x, y + h,
        nvgRGBA(0, 10, 30, 0), nvgRGBA(0, 10, 30, 100))
    nvgBeginPath(nvg); nvgRect(nvg, x, y + h - 10, w, 10)
    nvgFillPaint(nvg, bottomPaint); nvgFill(nvg)

    -- 底部 C_GEM 分隔线
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, x + 10, y + h)
    nvgLineTo(nvg, x + w - 10, y + h)
    nvgStrokeColor(nvg, nvgRGBA(60, 210, 248, 80))
    nvgStrokeWidth(nvg, 1.0)
    nvgStroke(nvg)

    -- ── 右上角：养殖中数量角标 ──
    local activeCount = 0
    for _, slot in pairs(GameState.breedingSlots) do
        if slot and slot.fishId then activeCount = activeCount + 1 end
    end
    if activeCount > 0 then
        local badgeStr = "🐡 " .. activeCount .. " 条"
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 11)
        nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(5, 18, 55, 160))
        nvgText(nvg, x + w - 7, y + 6, badgeStr)
        nvgFillColor(nvg, nvgRGBA(60, 210, 248, 200))
        nvgText(nvg, x + w - 8, y + 5, badgeStr)
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

    -- 标题行（6方向描边）
    local titleStr = "养殖槽位 (" .. GameState.unlockedBreedingSlots .. "/" .. GameConfig.BREEDING.MAX_SLOTS .. ")"
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 14)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    local titleMidY = gy + 13
    nvgFillColor(nvg, nvgRGBA(5, 18, 55, 180))
    for i = 0, 5 do
        local a = i * math.pi / 3
        nvgText(nvg, gx + 10 + math.cos(a) * 1.5, titleMidY + math.sin(a) * 1.5, titleStr)
    end
    nvgFillColor(nvg, nvgRGBA(160, 220, 255, 220))
    nvgText(nvg, gx + 10, titleMidY, titleStr)

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
    local t = UICore.easeOutCubic(tipPopupT_)
    if t <= 0 then return end

    local fishCfg = GameConfig.FISH_BY_ID[tipPopup_.fishId]
    if not fishCfg then
        tipPopup_.open = false
        return
    end

    local qCfg = GameConfig.QUALITY[tipPopup_.qualityId]
    local qc = qCfg.color

    -- 遮罩淡入
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, sw, sh)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, math.floor(t * 140)))
    nvgFill(nvg)

    local popW = math.min(sw - 40, 280)
    local popH = 270
    local popCX = sx + sw * 0.5
    local popCY = sy + sh * 0.5

    -- scale-in 动画
    local scale = 0.85 + 0.15 * t
    nvgSave(nvg)
    nvgGlobalAlpha(nvg, t)
    nvgTranslate(nvg, popCX, popCY)
    nvgScale(nvg, scale, scale)
    nvgTranslate(nvg, -popW * 0.5, -popH * 0.5)

    local popX, popY = 0, 0

    -- 面板背景渐变
    local bgPaint = nvgLinearGradient(nvg, popX, popY, popX, popY + popH,
        nvgRGBA(12, 40, 80, 250), nvgRGBA(8, 28, 60, 252))
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, popX, popY, popW, popH, 14)
    nvgFillPaint(nvg, bgPaint)
    nvgFill(nvg)
    -- 品质色边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, popX, popY, popW, popH, 14)
    nvgStrokeColor(nvg, nvgRGBA(qc[1], qc[2], qc[3], 200))
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)

    -- 鱼图片 (居中)
    local imgSize = 80
    local imgCx = popX + popW * 0.5
    local imgCy = popY + 20

    local imgData = fishImages_[fishCfg.name]
    if imgData and imgData.img > 0 then
        local imgScale = imgSize / math.max(imgData.w, imgData.h)
        local drawW = imgData.w * imgScale
        local drawH = imgData.h * imgScale
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

    -- 鱼名称（8方向描边）
    local textY = popY + 20 + imgSize + 14
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 16)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    local nameCX = popX + popW * 0.5
    nvgFillColor(nvg, nvgRGBA(5, 18, 55, 220))
    for i = 0, 7 do
        local a = i * math.pi / 4
        nvgText(nvg, nameCX + math.cos(a) * 2, textY + math.sin(a) * 2, fishCfg.displayName)
    end
    nvgFillColor(nvg, nvgRGBA(qc[1], qc[2], qc[3], 255))
    nvgText(nvg, nameCX, textY, fishCfg.displayName)

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
    nvgFillColor(nvg, nvgRGBA(80, 140, 200, 130))
    nvgText(nvg, popX + popW * 0.5, popY + popH - 14, "点击任意位置关闭")

    nvgRestore(nvg)
    nvgGlobalAlpha(nvg, 1.0)
end

-- ============================================================================
-- 鱼选择弹窗
-- ============================================================================

function BreedingScene.renderSelectPopup(nvg, sx, sy, sw, sh)
    local t = UICore.easeOutCubic(selectPopupT_)
    if t <= 0 then return end

    -- 遮罩淡入
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, sw, sh)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, math.floor(t * 160)))
    nvgFill(nvg)

    local popW = math.min(sw - 30, 320)
    local popH = math.min(sh - 60, 400)
    local popCX = sx + sw * 0.5
    local popCY = sy + sh * 0.5

    -- scale-in 动画
    local scale = 0.85 + 0.15 * t
    nvgSave(nvg)
    nvgGlobalAlpha(nvg, t)
    nvgTranslate(nvg, popCX, popCY)
    nvgScale(nvg, scale, scale)
    nvgTranslate(nvg, -popW * 0.5, -popH * 0.5)

    local popX, popY = 0, 0

    -- 面板背景渐变
    local bgPaint = nvgLinearGradient(nvg, popX, popY, popX, popY + popH,
        nvgRGBA(12, 55, 108, 245), nvgRGBA(8, 38, 82, 250))
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, popX, popY, popW, popH, 14)
    nvgFillPaint(nvg, bgPaint)
    nvgFill(nvg)
    -- 边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, popX, popY, popW, popH, 14)
    nvgStrokeColor(nvg, nvgRGBA(60, 210, 248, 200))
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)

    -- 标题栏
    local titleH = 44
    local titlePaint = nvgLinearGradient(nvg, popX, popY, popX, popY + titleH,
        nvgRGBA(20, 75, 140, 220), nvgRGBA(12, 55, 108, 200))
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, popX + 2, popY + 2, popW - 4, titleH, 12)
    nvgFillPaint(nvg, titlePaint)
    nvgFill(nvg)

    local slot = GameState.breedingSlots[selectPopup_.slotIndex]
    local titleStr = "选择鱼苗"
    if slot and slot.fish1 then
        local fc = GameConfig.FISH_BY_ID[slot.fishId]
        titleStr = "配对: " .. (fc and fc.displayName or "???")
    end

    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 15)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(5, 18, 55, 200))
    for i = 0, 7 do
        local a = i * math.pi / 4
        nvgText(nvg, popX + popW * 0.5 + math.cos(a) * 2, popY + titleH * 0.5 + math.sin(a) * 2, titleStr)
    end
    nvgFillColor(nvg, nvgRGBA(235, 248, 255, 255))
    nvgText(nvg, popX + popW * 0.5, popY + titleH * 0.5, titleStr)

    -- 关闭按钮
    local closeSize = 28
    local closeX = popX + popW - closeSize - 6
    local closeY = popY + (titleH - closeSize) * 0.5
    nvgBeginPath(nvg)
    nvgCircle(nvg, closeX + closeSize * 0.5, closeY + closeSize * 0.5, closeSize * 0.5)
    nvgFillColor(nvg, nvgRGBA(180, 60, 50, 200))
    nvgFill(nvg)
    nvgFontSize(nvg, 15)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 240))
    nvgText(nvg, closeX + closeSize * 0.5, closeY + closeSize * 0.5, "✕")

    -- 关闭按钮点击区（近似屏幕坐标）
    local screenCloseX = popCX + popW * 0.5 - closeSize - 6
    local screenCloseY = popCY - popH * 0.5 + (titleH - closeSize) * 0.5
    table.insert(clickRects_, {
        x = screenCloseX, y = screenCloseY, w = closeSize, h = closeSize,
        action = "close_select",
    })

    -- 鱼列表 (注意：listY 从 titleH 后开始，避免覆盖标题)
    local listX = popX + 10
    local listY = popY + titleH + 8
    local listW = popW - 20
    local itemH = 52
    local listH = popH - titleH - 16

    -- 屏幕坐标（用于 clickRects，不受 NanoVG 变换影响）
    local screenListX = popCX - popW * 0.5 + 10
    local screenListTop = popCY - popH * 0.5 + titleH + 8

    nvgSave(nvg)
    nvgScissor(nvg, listX, listY, listW, listH)

    for idx, fish in ipairs(selectPopup_.fishList) do
        local iy = listY + (idx - 1) * (itemH + 4) - selectPopup_.scrollY
        if iy + itemH < listY or iy > listY + listH then
            goto continue
        end

        -- 卡片背景渐变
        local cardPaint = nvgLinearGradient(nvg, listX, iy, listX, iy + itemH,
            nvgRGBA(30, 70, 120, 210), nvgRGBA(18, 48, 90, 200))
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, listX, iy, listW, itemH, 7)
        nvgFillPaint(nvg, cardPaint)
        nvgFill(nvg)
        -- 卡片边框
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, listX, iy, listW, itemH, 7)
        nvgStrokeColor(nvg, nvgRGBA(60, 140, 220, 80))
        nvgStrokeWidth(nvg, 1)
        nvgStroke(nvg)

        -- 品质色条（左侧竖条）
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, listX, iy + 4, 4, itemH - 8, 2)
        nvgFillColor(nvg, nvgRGBA(fish.qualityColor[1], fish.qualityColor[2],
                                   fish.qualityColor[3], 240))
        nvgFill(nvg)

        -- 鱼图片 (小)
        local fishCfg = GameConfig.FISH_BY_ID[fish.fishId]
        local fishName = fishCfg and fishCfg.name or "sardine"
        local imgData = fishImages_[fishName]
        local thumbSize = 38
        local thumbX = listX + 10
        local thumbY = iy + (itemH - thumbSize) * 0.5

        if imgData and imgData.img > 0 then
            local thumbScale = thumbSize / math.max(imgData.w, imgData.h)
            local dw = imgData.w * thumbScale
            local dh = imgData.h * thumbScale
            local dx = thumbX + (thumbSize - dw) * 0.5
            local dy = thumbY + (thumbSize - dh) * 0.5

            local pat = nvgImagePattern(nvg, dx, dy, dw, dh, 0, imgData.img, 1.0)
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, dx, dy, dw, dh, 3)
            nvgFillPaint(nvg, pat)
            nvgFill(nvg)
        else
            nvgFontFace(nvg, "sans")
            nvgFontSize(nvg, 24)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, 220))
            nvgText(nvg, thumbX + thumbSize * 0.5, thumbY + thumbSize * 0.5, fish.icon)
        end

        -- 名称（6方向描边）
        local textX = thumbX + thumbSize + 8
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 13)
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        local nameY = iy + itemH * 0.35
        nvgFillColor(nvg, nvgRGBA(5, 18, 55, 200))
        for i = 0, 5 do
            local a = i * math.pi / 3
            nvgText(nvg, textX + math.cos(a) * 1.5, nameY + math.sin(a) * 1.5,
                fish.displayName .. " [" .. fish.qualityName .. "]")
        end
        nvgFillColor(nvg, nvgRGBA(fish.qualityColor[1], fish.qualityColor[2],
                                   fish.qualityColor[3], 240))
        nvgText(nvg, textX, nameY, fish.displayName .. " [" .. fish.qualityName .. "]")

        -- 数量 / 词条信息（小字）
        nvgFontSize(nvg, 11)
        local subY = iy + itemH * 0.72
        if fish.isAffix and fish.affixSummary then
            local highest = AffixSystem.getHighestRarity(fish.affixes)
            local rc = AffixConfig.RARITY[highest] or AffixConfig.RARITY[1]
            nvgFillColor(nvg, nvgRGBA(rc.color[1], rc.color[2], rc.color[3], 220))
            nvgText(nvg, textX, subY, "✦" .. fish.affixSummary)
        else
            nvgFillColor(nvg, nvgRGBA(160, 200, 240, 180))
            nvgText(nvg, textX, subY, "x" .. fish.count)
        end

        -- 整行可点（使用屏幕坐标）
        local screenIY = screenListTop + (idx - 1) * (itemH + 4) - selectPopup_.scrollY * scale
        local actionStr = "select_fish_" .. fish.fishId .. "_" .. fish.qualityId
        if fish.uid then
            actionStr = actionStr .. "_" .. fish.uid
        end
        table.insert(clickRects_, {
            x = screenListX, y = screenIY, w = listW, h = itemH,
            action = actionStr,
        })

        ::continue::
    end

    nvgRestore(nvg)   -- 释放 scissor

    nvgRestore(nvg)   -- 释放 scale-in 变换
    nvgGlobalAlpha(nvg, 1.0)
end

-- ============================================================================
-- 顶部 HUD
-- ============================================================================

function BreedingScene.renderHUD(nvg, x, y, w, h)
    local sc = w / 390
    sc = math.max(0.7, math.min(1.5, sc))
    local hudH = 46
    local midY = y + hudH * 0.5

    -- HUD 渐变背景
    local bgPaint = nvgLinearGradient(nvg, x, y, x, y + hudH,
        nvgRGBA(10, 50, 105, 235), nvgRGBA(6, 36, 80, 240))
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, hudH)
    nvgFillPaint(nvg, bgPaint)
    nvgFill(nvg)
    -- 底部高光线
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, x, y + hudH)
    nvgLineTo(nvg, x + w, y + hudH)
    nvgStrokeColor(nvg, nvgRGBA(60, 210, 248, 70))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)

    -- 返回按钮
    local btnW = math.floor(64 * sc)
    local btnH = math.floor(30 * sc)
    local btnX = x + math.floor(10 * sc)
    local btnY = midY - btnH * 0.5
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, btnX, btnY, btnW, btnH, 7)
    nvgFillColor(nvg, nvgRGBA(12, 48, 95, 220))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, btnX, btnY, btnW, btnH, 7)
    nvgStrokeColor(nvg, nvgRGBA(60, 210, 248, 160))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)
    local btnMid = btnX + btnW * 0.5
    local btnMidY = btnY + btnH * 0.5
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, math.floor(13 * sc))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(5, 18, 55, 200))
    for i = 0, 7 do
        local a = i * math.pi / 4
        nvgText(nvg, btnMid + math.cos(a) * 1.5, btnMidY + math.sin(a) * 1.5, "← 返回")
    end
    nvgFillColor(nvg, nvgRGBA(200, 235, 255, 240))
    nvgText(nvg, btnMid, btnMidY, "← 返回")
    table.insert(clickRects_, { x = btnX, y = btnY, w = btnW, h = btnH, action = "go_back" })

    -- 标题
    nvgFontSize(nvg, math.floor(16 * sc))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(5, 18, 55, 200))
    for i = 0, 7 do
        local a = i * math.pi / 4
        nvgText(nvg, x + w * 0.5 + math.cos(a) * 2, midY + math.sin(a) * 2, "养殖场")
    end
    nvgFillColor(nvg, nvgRGBA(235, 248, 255, 255))
    nvgText(nvg, x + w * 0.5, midY, "养殖场")

    -- 金币
    local coinsStr = FormatUtils.formatNumber(GameState.coins) .. " 💰"
    nvgFontSize(nvg, math.floor(12 * sc))
    nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(80, 40, 0, 200))
    for i = 0, 5 do
        local a = i * math.pi / 3
        nvgText(nvg, x + w - math.floor(10 * sc) + math.cos(a) * 1.5, midY + math.sin(a) * 1.5, coinsStr)
    end
    nvgFillColor(nvg, nvgRGBA(255, 220, 40, 240))
    nvgText(nvg, x + w - math.floor(10 * sc), midY, coinsStr)
end

return BreedingScene
