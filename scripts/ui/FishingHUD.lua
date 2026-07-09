-- ============================================================================
-- FishingHUD: 钓鱼主界面 HUD 层
-- 包含：顶栏货币、鱼仓面板、船员卡槽、底部导航、设置按钮
-- 坐标系：1080×2400 设计分辨率
-- ============================================================================
local UICore    = require("ui.UICore")
local GameState = require("state.GameState")
local GameConfig = require("config.GameConfig")
local FishSwarmSystem = require("systems.FishSwarmSystem")

local FishingHUD = {}

local DW = UICore.DESIGN_W   -- 1080
local DH = UICore.DESIGN_H   -- 2400

-- ============================================================================
-- 图片句柄
-- ============================================================================
local img_ = {}
local imgLoaded_ = false

-- 船员头像映射 (使用 cat 版本)
local CREW_PORTRAITS = {
    fisher    = "image/crew_cat_fisher_20260428111553.png",
    netter    = "image/crew_cat_netter_20260428111624.png",
    harvester = "image/crew_cat_harvester_20260428111551.png",
    baiter    = "image/crew_cat_baiter_20260428111546.png",
    captain   = "image/crew_cat_captain_20260428111545.png",
    chef      = "image/crew_cat_chef_20260428111724.png",
    merchant  = "image/crew_cat_merchant_20260428111725.png",
    navigator = "image/crew_cat_navigator_20260428111849.png",
    deckhand  = "image/crew_cat_deckhand_20260428111727.png",
    sailor    = "image/crew_cat_sailor_20260428112047.png",
}

-- ============================================================================
-- 运行时状态
-- ============================================================================
local time_         = 0
local animEnter_    = 0      -- 入场动画进度 0→1

-- 鱼仓面板展开/收起
local holdExpanded_ = false
local holdAnim_     = 0.0    -- 0=收起 1=展开
local holdPopupT_   = 0.0   -- 弹窗缩放动画 0→1

-- 当前激活底部 Tab
local activeTab_    = "fishing"

-- 按钮点击回调
local onTabChange_   = nil
local onCrewSlotTap_ = nil
local onBagTap_      = nil
local onSettingsTap_ = nil

-- 波次预告动画
local waveAlertAnim_  = 0.0
local waveAlertTimer_ = 0.0

-- ============================================================================
-- 布局常量（1080×2400 设计坐标）
-- ============================================================================
-- 顶部货币栏
local TOP_BAR_H    = 130
local TOP_BAR_Y    = 48
local COIN_X       = 230
local GEM_X        = 650

-- 船员卡槽（右侧竖排）
local CREW_SLOT_W  = 148
local CREW_SLOT_H  = 148
local CREW_SLOT_X  = DW - CREW_SLOT_W - 16
local CREW_SLOT_GAP = 14
local CREW_SLOT_Y0  = DH * 0.35

-- 底部导航栏
local NAV_H    = 190
local NAV_Y    = DH - NAV_H - 28
local NAV_TABS   = { "fishing", "industry", "breeding", "aquarium" }
local NAV_ICONS  = { "⚓", "🏭", "🐟", "🐠" }
local NAV_LABELS = { "钓鱼", "产业", "养殖", "鱼缸" }

-- 鱼仓按钮（左下）
local BAG_BTN_X = 60
local BAG_BTN_Y = DH - NAV_H - 210
local BAG_BTN_W = 138
local BAG_BTN_H = 138

-- ============================================================================
-- 初始化
-- ============================================================================
local function loadImg(nvg, path)
    local h = nvgCreateImage(nvg, path, 0)
    if not h or h <= 0 then
        print("[FishingHUD] 图片加载失败: " .. path)
        return -1
    end
    return h
end

function FishingHUD.init(nvg)
    if imgLoaded_ then return end

    img_.crew = {}
    for crewType, path in pairs(CREW_PORTRAITS) do
        img_.crew[crewType] = loadImg(nvg, path)
    end

    imgLoaded_ = true
    animEnter_ = 0.0
    print("[FishingHUD] 初始化完成")
end

-- ============================================================================
-- 设置回调
-- ============================================================================
function FishingHUD.setOnTabChange(fn)   onTabChange_   = fn end
function FishingHUD.setOnCrewSlotTap(fn) onCrewSlotTap_ = fn end
function FishingHUD.setOnBagTap(fn)      onBagTap_      = fn end
function FishingHUD.setOnSettingsTap(fn) onSettingsTap_ = fn end

-- ============================================================================
-- 更新
-- ============================================================================
function FishingHUD.update(dt)
    time_ = time_ + dt

    -- 入场动画（0.5s 完成）
    if animEnter_ < 1.0 then
        animEnter_ = math.min(1.0, animEnter_ + dt / 0.5)
    end

    -- 鱼仓展开/收起滑动动画
    local targetHold = holdExpanded_ and 1.0 or 0.0
    holdAnim_ = holdAnim_ + (targetHold - holdAnim_) * math.min(1, dt * 12)

    -- 鱼仓弹窗缩放动画（0.25s easeOutCubic）
    if holdExpanded_ then
        holdPopupT_ = math.min(1.0, holdPopupT_ + dt / 0.25)
    else
        holdPopupT_ = math.max(0.0, holdPopupT_ - dt / 0.15)
    end

    -- 波次预告
    if FishSwarmSystem.isWaveActive() then
        waveAlertTimer_ = 2.0
    elseif waveAlertTimer_ > 0 then
        waveAlertTimer_ = waveAlertTimer_ - dt
    end
    if waveAlertTimer_ > 0 then
        waveAlertAnim_ = waveAlertAnim_ + dt * 4
    end
end

-- ============================================================================
-- 渲染主入口
-- ============================================================================
function FishingHUD.render(nvg, w, h)
    UICore.beginDesign(nvg, w, h)

    local topT  = UICore.easeOutBack(math.min(1, animEnter_ / 0.8))
    local botT  = UICore.easeOutBack(math.min(1, math.max(0, (animEnter_ - 0.1) / 0.8)))
    local sideT = UICore.easeOutCubic(math.min(1, math.max(0, (animEnter_ - 0.2) / 0.7)))

    -- 顶部货币栏（从上方滑入）
    nvgSave(nvg)
    nvgTranslate(nvg, 0, (topT - 1) * (TOP_BAR_Y + TOP_BAR_H + 20))
    FishingHUD.renderTopBar(nvg)
    nvgRestore(nvg)

    -- 右侧船员槽（从右侧滑入）
    nvgSave(nvg)
    nvgTranslate(nvg, (1 - sideT) * (CREW_SLOT_W + 24), 0)
    FishingHUD.renderCrewSlots(nvg)
    nvgRestore(nvg)

    -- 底部导航 + 鱼仓按钮（从下方滑入）
    nvgSave(nvg)
    nvgTranslate(nvg, 0, (1 - botT) * (NAV_H + 60))
    FishingHUD.renderBottomNav(nvg)
    FishingHUD.renderBagButton(nvg)
    nvgRestore(nvg)

    -- 鱼仓展开面板（弹窗动画）
    if holdPopupT_ > 0.01 then
        FishingHUD.renderHoldPanel(nvg)
    end

    -- 波次预告
    FishingHUD.renderWaveAlert(nvg)

    UICore.endDesign(nvg)
end

-- ============================================================================
-- 顶部货币栏
-- ============================================================================
function FishingHUD.renderTopBar(nvg)
    local bx = 20
    local by = TOP_BAR_Y
    local bw = DW - 40
    local bh = TOP_BAR_H

    -- 面板背景（渐变深蓝）
    UICore.fillRRectGrad(nvg, bx, by, bw, bh, 22,
        { 14, 58, 115 }, 230,
        {  8, 40,  88 }, 235)
    -- 边框
    UICore.strokeRRect(nvg, bx, by, bw, bh, 22, UICore.C_GEM, 2, 150)
    -- 底部高光线
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, bx + 22, by + bh)
    nvgLineTo(nvg, bx + bw - 22, by + bh)
    nvgStrokeColor(nvg, nvgRGBA(60, 210, 248, 60))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)

    -- ── 金币区 ──────────────────────────────────────────
    local coinsText = FishingHUD.formatNumber(GameState.coins)
    local mid = by + bh * 0.5

    -- 金币圆标
    nvgBeginPath(nvg)
    nvgCircle(nvg, COIN_X - 56, mid, 30)
    nvgFillColor(nvg, nvgRGBA(255, 220, 40, 255))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgCircle(nvg, COIN_X - 56, mid, 30)
    nvgStrokeColor(nvg, nvgRGBA(200, 140, 0, 200))
    nvgStrokeWidth(nvg, 2.5)
    nvgStroke(nvg)
    UICore.strokeText(nvg, "G",
        COIN_X - 56, mid,
        30, { 120, 60, 0 }, { 80, 30, 0 }, 2,
        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    UICore.strokeText(nvg, coinsText,
        COIN_X + 36, mid,
        UICore.FS_BODY, UICore.C_COIN, UICore.C_STROKE, 4,
        NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)

    -- ── 分隔线 ──────────────────────────────────────────
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, DW * 0.5, by + 18)
    nvgLineTo(nvg, DW * 0.5, by + bh - 18)
    nvgStrokeColor(nvg, nvgRGBA(60, 210, 248, 80))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)

    -- ── 宝石区 ──────────────────────────────────────────
    local gemText = tostring(GameState.diamonds)
    -- 宝石菱形
    nvgSave(nvg)
    nvgTranslate(nvg, GEM_X - 56, mid)
    nvgRotate(nvg, math.pi / 4)
    nvgBeginPath(nvg)
    nvgRect(nvg, -20, -20, 40, 40)
    nvgFillColor(nvg, UICore.rgba(UICore.C_GEM, 255))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgRect(nvg, -20, -20, 40, 40)
    nvgStrokeColor(nvg, nvgRGBA(20, 160, 200, 200))
    nvgStrokeWidth(nvg, 2.5)
    nvgStroke(nvg)
    nvgRestore(nvg)
    UICore.strokeText(nvg, gemText,
        GEM_X + 36, mid,
        UICore.FS_BODY, UICore.C_GEM, UICore.C_STROKE, 4,
        NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)

    -- ── 设置按钮 ────────────────────────────────────────
    local settX = DW - 68
    nvgBeginPath(nvg)
    nvgCircle(nvg, settX, mid, 38)
    nvgFillColor(nvg, nvgRGBA(20, 65, 125, 220))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgCircle(nvg, settX, mid, 38)
    nvgStrokeColor(nvg, UICore.rgba(UICore.C_GEM, 160))
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)
    UICore.strokeText(nvg, "⚙",
        settX, mid,
        40, UICore.C_TITLE, UICore.C_STROKE, 3,
        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- ── 鱼仓小标（顶栏中央） ────────────────────────────
    local totalFish = GameState:getTotalFishInHold()
    local maxHold = 50 + (GameState.equipLevels and GameState.equipLevels.net or 1) * 10
    local holdTxt = string.format("🐟 %d/%d", totalFish, maxHold)
    UICore.strokeText(nvg, holdTxt,
        DW * 0.5 + 18, mid,
        UICore.FS_TINY, { 190, 235, 255 }, UICore.C_STROKE, 3,
        NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
end

-- ============================================================================
-- 右侧船员卡槽
-- ============================================================================
function FishingHUD.renderCrewSlots(nvg)
    local maxSlots = 3
    local unlocked = GameState.unlockedCrewSlots or 1

    for i = 1, maxSlots do
        local slotY = CREW_SLOT_Y0 + (i - 1) * (CREW_SLOT_H + CREW_SLOT_GAP)
        local sx = CREW_SLOT_X
        local sy = slotY

        local crew = GameState.crewSlots and GameState.crewSlots[i]
        local isUnlocked = (i <= unlocked)

        -- 槽位背景
        if isUnlocked then
            if crew then
                -- 已配置：深蓝亮边
                UICore.fillRRectGrad(nvg, sx, sy, CREW_SLOT_W, CREW_SLOT_H, 16,
                    { 16, 58, 118 }, 238,
                    { 10, 40,  90 }, 242)
                UICore.strokeRRect(nvg, sx, sy, CREW_SLOT_W, CREW_SLOT_H, 16,
                    UICore.C_GEM, 2.5, 210)
            else
                -- 空槽：虚线感淡框
                UICore.fillRRect(nvg, sx, sy, CREW_SLOT_W, CREW_SLOT_H, 16,
                    { 18, 52, 96 }, 170)
                UICore.strokeRRect(nvg, sx, sy, CREW_SLOT_W, CREW_SLOT_H, 16,
                    { 70, 150, 210 }, 1.5, 110)
                -- "+" 提示
                UICore.strokeText(nvg, "+",
                    sx + CREW_SLOT_W * 0.5, sy + CREW_SLOT_H * 0.5,
                    UICore.FS_HEADING, { 100, 175, 240 }, UICore.C_STROKE, 3,
                    NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            end
        else
            -- 锁定：暗色
            UICore.fillRRect(nvg, sx, sy, CREW_SLOT_W, CREW_SLOT_H, 16,
                { 8, 22, 48 }, 200)
            UICore.strokeRRect(nvg, sx, sy, CREW_SLOT_W, CREW_SLOT_H, 16,
                { 35, 55, 88 }, 1.5, 170)
            UICore.strokeText(nvg, "🔒",
                sx + CREW_SLOT_W * 0.5, sy + CREW_SLOT_H * 0.45,
                UICore.FS_SMALL, { 70, 100, 150 }, UICore.C_STROKE, 2,
                NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        end

        -- 有船员：头像 + 等级
        if isUnlocked and crew then
            local crewConf = GameConfig.CREW_BY_ID and GameConfig.CREW_BY_ID[crew.crewId]
            local crewType = crewConf and crewConf.type or "fisher"
            local portrait = img_.crew and img_.crew[crewType]
            local floatY   = math.sin(time_ * 3 + i * 1.2) * 4

            nvgSave(nvg)
            nvgTranslate(nvg, 0, floatY)

            if portrait and portrait > 0 then
                local imgX = sx + 8
                local imgY = sy + 8
                local imgW = CREW_SLOT_W - 16
                local imgH = CREW_SLOT_H - 38
                nvgSave(nvg)
                nvgBeginPath(nvg)
                nvgRoundedRect(nvg, imgX, imgY, imgW, imgH, 10)
                nvgScissor(nvg, imgX, imgY, imgW, imgH)
                UICore.drawImageTL(nvg, portrait, imgX, imgY, imgW, imgH, 1.0)
                nvgRestore(nvg)
            end

            -- 等级标签
            local lvl = crew.level or 1
            UICore.fillRRect(nvg, sx + 4, sy + CREW_SLOT_H - 30, CREW_SLOT_W - 8, 26, 6,
                { 8, 32, 78 }, 230)
            UICore.strokeText(nvg, "Lv." .. lvl,
                sx + CREW_SLOT_W * 0.5, sy + CREW_SLOT_H - 17,
                UICore.FS_TINY - 4, UICore.C_COIN, UICore.C_STROKE, 2,
                NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

            nvgRestore(nvg)
        end
    end
end

-- ============================================================================
-- 底部导航栏
-- ============================================================================
function FishingHUD.renderBottomNav(nvg)
    local bx = 20
    local by = NAV_Y
    local bw = DW - 40
    local bh = NAV_H
    local tabW = bw / #NAV_TABS

    -- 背景
    UICore.fillRRectGrad(nvg, bx, by, bw, bh, 24,
        { 14, 58, 115 }, 230,
        {  8, 40,  88 }, 240)
    UICore.strokeRRect(nvg, bx, by, bw, bh, 24, UICore.C_GEM, 2, 150)
    -- 顶部高光线
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, bx + 24, by)
    nvgLineTo(nvg, bx + bw - 24, by)
    nvgStrokeColor(nvg, nvgRGBA(60, 210, 248, 80))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)

    for i, tab in ipairs(NAV_TABS) do
        local tx = bx + (i - 1) * tabW
        local isActive = (tab == activeTab_)

        -- 激活高亮背景
        if isActive then
            UICore.fillRRectGrad(nvg, tx + 8, by + 8, tabW - 16, bh - 16, 16,
                { 32, 92, 175 }, 210,
                { 20, 68, 148 }, 220)
            UICore.strokeRRect(nvg, tx + 8, by + 8, tabW - 16, bh - 16, 16,
                UICore.C_GEM, 2, 190)
        end

        -- 图标
        local iconC = isActive and UICore.C_GEM or { 110, 162, 210 }
        UICore.strokeText(nvg, NAV_ICONS[i],
            tx + tabW * 0.5, by + bh * 0.36,
            UICore.FS_BODY, iconC, UICore.C_STROKE, 3,
            NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

        -- 标签
        local lblC = isActive and UICore.C_TITLE or { 110, 155, 200 }
        UICore.strokeText(nvg, NAV_LABELS[i],
            tx + tabW * 0.5, by + bh * 0.78,
            UICore.FS_TINY - 2, lblC, UICore.C_STROKE, 3,
            NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    end
end

-- ============================================================================
-- 鱼仓快捷按钮（左下角）
-- ============================================================================
function FishingHUD.renderBagButton(nvg)
    local bx = BAG_BTN_X
    local by = BAG_BTN_Y
    local bw = BAG_BTN_W
    local bh = BAG_BTN_H

    local floatY = math.sin(time_ * 2.5) * 6

    nvgSave(nvg)
    nvgTranslate(nvg, 0, floatY)

    -- 外发光
    if holdExpanded_ then
        local glow = nvgRadialGradient(nvg, bx + bw * 0.5, by + bh * 0.5,
            bw * 0.3, bw * 0.9,
            nvgRGBA(60, 210, 248, 80), nvgRGBA(60, 210, 248, 0))
        nvgBeginPath(nvg)
        nvgRect(nvg, bx - bw * 0.4, by - bh * 0.4, bw * 1.8, bh * 1.8)
        nvgFillPaint(nvg, glow)
        nvgFill(nvg)
    end

    UICore.fillRRectGrad(nvg, bx, by, bw, bh, 20,
        { 16, 62, 122 }, 230,
        {  9, 44,  94 }, 238)
    UICore.strokeRRect(nvg, bx, by, bw, bh, 20,
        holdExpanded_ and UICore.C_GEM or { 52, 140, 210 },
        2, holdExpanded_ and 220 or 160)

    -- 桶图标
    UICore.strokeText(nvg, "🪣",
        bx + bw * 0.5, by + bh * 0.42,
        UICore.FS_HEADING - 4, UICore.C_TITLE, UICore.C_STROKE, 3,
        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 数量角标
    local total = GameState:getTotalFishInHold()
    if total > 0 then
        local badgeR = 24
        local bBx = bx + bw - badgeR + 4
        local bBy = by + badgeR - 4
        nvgBeginPath(nvg)
        nvgCircle(nvg, bBx, bBy, badgeR)
        nvgFillColor(nvg, nvgRGBA(215, 45, 45, 245))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgCircle(nvg, bBx, bBy, badgeR)
        nvgStrokeColor(nvg, nvgRGBA(255, 100, 100, 180))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)
        UICore.strokeText(nvg, tostring(math.min(total, 99)),
            bBx, bBy,
            UICore.FS_TINY - 2, { 255, 255, 255 }, { 120, 0, 0 }, 2,
            NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    end

    nvgRestore(nvg)
end

-- ============================================================================
-- 鱼仓展开面板（弹窗缩放动画）
-- ============================================================================
function FishingHUD.renderHoldPanel(nvg)
    if holdPopupT_ < 0.01 then return end

    local panelW = DW - 40
    local panelH = DH * 0.42
    local panelCX = DW * 0.5
    local panelCY = NAV_Y - panelH * 0.5 - 10

    -- 弹窗动画（easeOutCubic 0.25s: 85%→100%，同时淡入）
    local t = UICore.easeOutCubic(holdPopupT_)
    local scale = 0.85 + 0.15 * t

    -- 遮罩
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, DW, DH)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, math.floor(t * 140)))
    nvgFill(nvg)

    nvgSave(nvg)
    nvgGlobalAlpha(nvg, t)
    nvgTranslate(nvg, panelCX, panelCY)
    nvgScale(nvg, scale, scale)
    nvgTranslate(nvg, -panelW * 0.5, -panelH * 0.5)

    -- 面板本体
    UICore.drawPanel(nvg, 0, 0, panelW, panelH, 22)

    -- 顶部拖拽条
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, panelW * 0.37, 12, panelW * 0.26, 8, 4)
    nvgFillColor(nvg, nvgRGBA(80, 160, 220, 180))
    nvgFill(nvg)

    -- 标题栏
    local titleH = UICore.drawPanelTitle(nvg, 0, 20, panelW, "鱼仓")

    -- 网格显示鱼种
    local cols  = 5
    local cellW = 164
    local cellH = 148
    local gapX  = 12
    local totalW = cols * cellW + (cols - 1) * gapX
    local gLeft = (panelW - totalW) * 0.5
    local gTop  = 20 + titleH + 16

    local items = {}
    for key, count in pairs(GameState.fishInventory) do
        if count and count > 0 then
            local sep = key:find("_")
            if sep then
                local fishId  = tonumber(key:sub(1, sep - 1))
                local quality = tonumber(key:sub(sep + 1))
                local fishConf = GameConfig.FISH_BY_ID and GameConfig.FISH_BY_ID[fishId]
                if fishConf then
                    table.insert(items, {
                        fishId  = fishId,
                        quality = quality,
                        count   = count,
                        name    = fishConf.displayName or "鱼",
                    })
                end
            end
        end
    end

    -- 按品质降序
    table.sort(items, function(a, b)
        if a.quality ~= b.quality then return a.quality > b.quality end
        return a.fishId < b.fishId
    end)

    -- scissor 裁剪
    nvgSave(nvg)
    nvgScissor(nvg, 4, gTop, panelW - 8, panelH - gTop - 10)

    for idx, item in ipairs(items) do
        local col = (idx - 1) % cols
        local row = math.floor((idx - 1) / cols)
        local cx  = gLeft + col * (cellW + gapX) + cellW * 0.5
        local cy  = gTop  + row * (cellH + 12) + cellH * 0.5

        if cy - cellH * 0.5 > panelH then break end

        local qc = UICore.qualityColor(item.quality)
        -- 品质底框
        UICore.fillRRect(nvg, cx - cellW * 0.5, cy - cellH * 0.5, cellW, cellH, 12, qc, 28)
        UICore.strokeRRect(nvg, cx - cellW * 0.5, cy - cellH * 0.5, cellW, cellH, 12, qc, 2, 190)

        -- 鱼名（正文字号）
        UICore.strokeText(nvg, item.name,
            cx, cy - 26,
            UICore.FS_SMALL, UICore.C_TITLE, UICore.C_STROKE, 3,
            NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

        -- 品质标签（小字，品质色）
        UICore.strokeText(nvg, UICore.qualityName(item.quality),
            cx, cy + 6,
            UICore.FS_TINY - 2, qc, UICore.C_STROKE, 2,
            NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

        -- 数量（金色）
        UICore.strokeText(nvg, "×" .. item.count,
            cx, cy + 44,
            UICore.FS_SMALL, UICore.C_COIN, UICore.C_STROKE, 3,
            NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    end

    nvgRestore(nvg)

    -- 空提示
    if #items == 0 then
        UICore.strokeText(nvg, "鱼仓空空如也，快去钓鱼吧！",
            panelW * 0.5, panelH * 0.52,
            UICore.FS_SMALL, { 110, 165, 220 }, UICore.C_STROKE, 3,
            NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    end

    nvgRestore(nvg)
    nvgGlobalAlpha(nvg, 1.0)
end

-- ============================================================================
-- 波次预告
-- ============================================================================
function FishingHUD.renderWaveAlert(nvg)
    if waveAlertTimer_ <= 0 then return end

    local pulse = 0.72 + math.abs(math.sin(waveAlertAnim_)) * 0.28
    local alpha = math.min(1.0, waveAlertTimer_) * pulse

    local tw, th = 540, 96
    local tx = (DW - tw) * 0.5
    local ty = DH * 0.22

    nvgSave(nvg)
    nvgGlobalAlpha(nvg, alpha)

    UICore.fillRRectGrad(nvg, tx, ty, tw, th, 16,
        { 190, 65, 20 }, 210,
        { 150, 45, 10 }, 220)
    UICore.strokeRRect(nvg, tx, ty, tw, th, 16, UICore.C_COIN, 2.5, 230)

    UICore.strokeText(nvg, "⚡ 鱼潮来袭！",
        tx + tw * 0.5, ty + th * 0.5,
        UICore.FS_HEADING - 4, UICore.C_COIN, { 100, 30, 0 }, 5,
        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    nvgRestore(nvg)
end

-- ============================================================================
-- 工具函数
-- ============================================================================
function FishingHUD.formatNumber(n)
    n = n or 0
    if n >= 1000000 then
        return string.format("%.1fM", n / 1000000)
    elseif n >= 1000 then
        return string.format("%.1fK", n / 1000)
    end
    return tostring(n)
end

-- ============================================================================
-- 输入处理（接受设计坐标）
-- ============================================================================
local function inRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

function FishingHUD.onTouchDown(dx, dy)
    -- 设置按钮
    local settX = DW - 68
    local settY = TOP_BAR_Y + TOP_BAR_H * 0.5
    if math.sqrt((dx - settX)^2 + (dy - settY)^2) < 44 then
        if onSettingsTap_ then onSettingsTap_() end
        return true
    end

    -- 鱼仓按钮
    if inRect(dx, dy, BAG_BTN_X, BAG_BTN_Y, BAG_BTN_W, BAG_BTN_H) then
        holdExpanded_ = not holdExpanded_
        if onBagTap_ then onBagTap_() end
        return true
    end

    -- 鱼仓展开时，点击面板外关闭
    if holdExpanded_ then
        local panelW = DW - 40
        local panelH = DH * 0.42
        local panelX = 20
        local panelY = NAV_Y - panelH - 10
        if not inRect(dx, dy, panelX, panelY, panelW, panelH) then
            holdExpanded_ = false
            return true
        end
    end

    -- 底部导航
    if inRect(dx, dy, 20, NAV_Y, DW - 40, NAV_H) then
        local tabW = (DW - 40) / #NAV_TABS
        local colIdx = math.floor((dx - 20) / tabW) + 1
        colIdx = math.max(1, math.min(#NAV_TABS, colIdx))
        local newTab = NAV_TABS[colIdx]
        if newTab ~= activeTab_ then
            activeTab_ = newTab
            holdExpanded_ = false
            if onTabChange_ then onTabChange_(newTab) end
        end
        return true
    end

    -- 船员槽
    for i = 1, 3 do
        local slotY = CREW_SLOT_Y0 + (i - 1) * (CREW_SLOT_H + CREW_SLOT_GAP)
        if inRect(dx, dy, CREW_SLOT_X, slotY, CREW_SLOT_W, CREW_SLOT_H) then
            if onCrewSlotTap_ then onCrewSlotTap_(i) end
            return true
        end
    end

    return false
end

-- ============================================================================
-- 查询接口
-- ============================================================================
function FishingHUD.getActiveTab()   return activeTab_ end
function FishingHUD.setActiveTab(t)  activeTab_ = t end
function FishingHUD.isHoldExpanded() return holdExpanded_ end

return FishingHUD
