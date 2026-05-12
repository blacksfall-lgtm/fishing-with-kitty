-- ============================================================================
-- IndustryScene: 码头餐厅界面 (猫咪顾客动画版 v2, 纯 NanoVG 渲染)
-- ============================================================================
-- v2 变更:
--   - 每桌 2 只猫 (8 席位)
--   - 桌子图片保持原始宽高比
--   - 行走猫咪只在过道 (AISLE_X) 上显示
-- ============================================================================
local GameConfig      = require("config.GameConfig")
local GameState       = require("state.GameState")
local IndustrySystem  = require("systems.IndustrySystem")
local EconomySystem   = require("systems.EconomySystem")
local FormatUtils     = require("utils.FormatUtils")

local IndustryScene = {}

-- ============================================================================
-- NanoVG 图片句柄
-- ============================================================================
local imgDockBg_    = nil
local imgCoin_      = nil
local imgDiamond_   = nil
local imgCurrBg_    = nil
local imgPlus_      = nil
local imgAnchor_    = nil
local imgBtnSquare_ = nil
local imgBreeding_  = nil   -- 养殖按钮图标
local imgAquarium_  = nil   -- 鱼缸按钮图标
local imgResearch_  = nil   -- 研发按钮图标
local imgCodex_     = nil   -- 图鉴按钮图标
local imgBtnRound_  = nil   -- 圆形按钮底图
local imgMenuBoard_ = nil   -- 菜单黑板道具贴图
local menuBoardImgW_ = 0
local menuBoardImgH_ = 0
local imgTable_     = nil   -- 桶桌贴图
local dockImgW_     = 0
local dockImgH_     = 0
local tableImgW_    = 0     -- 桌子图片原始宽
local tableImgH_    = 0     -- 桌子图片原始高

-- 鱼类图标
local fishIcons_ = {}

-- 猫咪精灵帧: catSprites_[catType] = { walk = {img1..4}, sit = {img1..2} }
local catSprites_ = {}

-- 进度条序列帧: progressFrames_[0..8]  (0=空, 8=满)
local progressFrames_ = {}
local PROGRESS_FRAME_COUNT = 9   -- 0..8

-- ============================================================================
-- 点击检测
-- ============================================================================
local clickRects_ = {}

-- ============================================================================
-- 菜单面板状态
-- ============================================================================
local menuOpen_    = false
local menuScrollY_ = 0

-- 出海面板状态
local goFishingOpen_    = false
local selectedZoneIdx_  = 1     -- 1=近海, 2=外海
local selectedBaitIdx_  = 1     -- 选中的鱼饵索引
local imgPanelBg_       = nil   -- button_square_line.png (九宫格底框)
local imgCardBg_        = nil   -- input_rectangle.png  (卡片底图)

-- 菜谱升级弹窗状态
local upgradePopup_ = {
    open = false,
    recipeId = 0,
    recipeName = "",
    currentLevel = 0,
    cost = 0,
    curPrice = 0,
    nextPrice = 0,
    canAfford = false,
    fishReqs = {},       -- {{fishId, count, displayName, icon, have}, ...}
    fishEnough = false,  -- 鱼材料是否全部充足
}

local ZONE_LIST = {
    { key = "nearshore", name = "近海", icon = "zone_beach", desc = "平静浅滩" },
    { key = "offshore",  name = "外海", icon = "zone_ocean", desc = "风浪渐起" },
    { key = "deepocean", name = "深海", icon = "zone_deep", desc = "幽暗深处" },
    { key = "abyss",     name = "深渊", icon = "zone_abyss", desc = "未知领域" },
    { key = "legendary", name = "传说", icon = "zone_legend", desc = "传说之海" },
}

-- 解锁确认弹窗状态
local unlockPopup_ = {
    open = false,
    zoneIdx = 0,
    zoneKey = "",
    zoneName = "",
    cost = 0,
    canAfford = false,
}

local BAIT_LIST = {
    { id = 1, name = "普通鱼饵", icon = "worm", desc = "基础饵料，什么鱼都能钓", cost = 0 },
    { id = 2, name = "香甜鱼饵", icon = "candy_bait", desc = "吸引稀有鱼，品质提升",   cost = 50 },
    { id = 3, name = "闪光鱼饵", icon = "shiny_bait", desc = "大幅提升稀有鱼概率",     cost = 200 },
}

-- Toast 提示
local toastMsg_    = nil
local toastTimer_  = 0

-- 菜单道具浮动按钮动画
local menuBtnFloatTime_ = 0

-- 收银台动画
local cashBounce_  = 0

-- 底图绘制区域缓存 (cover-fit)
local dockDrawX_ = 0
local dockDrawY_ = 0
local dockDrawW_ = 0
local dockDrawH_ = 0

-- ============================================================================
-- 桌子布局
-- ============================================================================
-- 桌子宽度占 dock 宽度的比例 (基于宽度计算, 高度由图片宽高比推导)
local TABLE_W_RATIO    = 0.38
-- 猫咪大小 (相对桌子高度)
local CAT_SIZE_RATIO   = 0.75

-- ============================================================================
-- 调试模式 (桌子整体拖拽 + 座位拖拽)
-- ============================================================================
local DEBUG_TABLE_DRAG = false  -- 调试完成
local DEBUG_DRAG_TABLE_BOX = false  -- 整体框拖拽 (已关闭)
local debugDragging_   = false
local debugOffsetX_    = 0
local debugOffsetY_    = 0
-- 座位拖拽: 1(左) | 2(右) | nil
local debugDragSeat_   = nil
local debugSeatOffX_   = 0
local debugSeatOffY_   = 0

-- 收银台位置调试
local DEBUG_CASH_REG = false
local cashRegNX_ = 0.620  -- 归一化 X (左边缘, 相对 dock)
local cashRegNY_ = 0.140  -- 归一化 Y (相对 dock)
local debugDragCash_ = false
local debugCashOffX_ = 0
local debugCashOffY_ = 0

-- 菜单板位置/缩放调试
local DEBUG_MENU_BOARD = false  -- 菜单板调试完成
local menuBoardNX_ = 0.144     -- 归一化中心X (相对 dock)
local menuBoardNY_ = 0.246     -- 归一化顶部Y (相对 dock)
local menuBoardNH_ = 0.130     -- 归一化高度 (相对 dock)
local debugDragMenu_ = false
local debugMenuOffX_ = 0
local debugMenuOffY_ = 0
local debugMenuScaling_ = false -- 缩放中
local debugMenuScaleOffY_ = 0  -- 缩放起始Y偏移

-- 出海按钮位置调试
local DEBUG_GO_BTN = false
local goBtnNX_ = 0.88   -- 归一化 X (相对 dock)
local goBtnNY_ = 0.92   -- 归一化 Y (相对 dock)
local debugDragGoBtn_ = false
local debugGoBtnOffX_ = 0
local debugGoBtnOffY_ = 0

-- ============================================================================
-- 初始化
-- ============================================================================

function IndustryScene.init(nvg)
    imgDockBg_ = nvgCreateImage(nvg, "image/dock_bg_v4.png", 0)
    if imgDockBg_ and imgDockBg_ > 0 then
        dockImgW_, dockImgH_ = nvgImageSize(nvg, imgDockBg_)
        print(string.format("[IndustryScene] 底图: %dx%d", dockImgW_, dockImgH_))
    end

    imgCoin_    = nvgCreateImage(nvg, "image/icon_coin_20260427064921.png", NVG_IMAGE_PREMULTIPLIED)
    imgDiamond_ = nvgCreateImage(nvg, "image/icon_diamond_v2_20260427070509.png", NVG_IMAGE_PREMULTIPLIED)
    imgCurrBg_  = nvgCreateImage(nvg, "image/button_rectangle_line.png", NVG_IMAGE_PREMULTIPLIED)
    imgPlus_    = nvgCreateImage(nvg, "image/icon_plus_20260427064347.png", NVG_IMAGE_PREMULTIPLIED)
    imgAnchor_  = nvgCreateImage(nvg, "image/icon_anchor.png", NVG_IMAGE_PREMULTIPLIED)
    imgBtnSquare_ = nvgCreateImage(nvg, "image/button_square_depth_line.png", NVG_IMAGE_PREMULTIPLIED)
    imgBreeding_  = nvgCreateImage(nvg, "image/icon_breeding_20260505133952.png", NVG_IMAGE_PREMULTIPLIED)
    imgAquarium_  = nvgCreateImage(nvg, "image/icon_aquarium_20260505134000.png", NVG_IMAGE_PREMULTIPLIED)
    imgResearch_  = nvgCreateImage(nvg, "image/icon_research_20260505200006.png", NVG_IMAGE_PREMULTIPLIED)
    imgCodex_     = nvgCreateImage(nvg, "image/icon_codex_20260505235236.png", NVG_IMAGE_PREMULTIPLIED)
    imgBtnRound_  = nvgCreateImage(nvg, "image/button_round_depth_line.png", NVG_IMAGE_PREMULTIPLIED)
    imgPanelBg_   = nvgCreateImage(nvg, "image/button_square_line.png", NVG_IMAGE_PREMULTIPLIED)
    imgCardBg_    = nvgCreateImage(nvg, "image/input_rectangle.png", NVG_IMAGE_PREMULTIPLIED)

    -- 菜单黑板道具
    imgMenuBoard_ = nvgCreateImage(nvg, "image/menu_board_20260428082414.png", NVG_IMAGE_PREMULTIPLIED)
    if imgMenuBoard_ and imgMenuBoard_ > 0 then
        menuBoardImgW_, menuBoardImgH_ = nvgImageSize(nvg, imgMenuBoard_)
        print(string.format("[IndustryScene] 菜单黑板: %dx%d", menuBoardImgW_, menuBoardImgH_))
    end

    -- 桶桌贴图
    imgTable_ = nvgCreateImage(nvg, "image/table_barrel.png", NVG_IMAGE_PREMULTIPLIED)
    if imgTable_ and imgTable_ > 0 then
        tableImgW_, tableImgH_ = nvgImageSize(nvg, imgTable_)
        print(string.format("[IndustryScene] 桶桌贴图: %dx%d (宽高比 %.2f)",
            tableImgW_, tableImgH_, tableImgW_ / math.max(1, tableImgH_)))
    end

    -- 鱼类图标
    local fishImageMap = {
        sardine    = "image/fish/fish_sardine.png",
        clownfish  = "image/fish/fish_clownfish.png",
        bubblefish = "image/fish/fish_bubblefish.png",
        coralfish  = "image/fish/fish_coralfish.png",
        shellfish  = "image/fish/fish_shellfish.png",
        bluefin    = "image/fish/fish_bluefin.png",
        flyingfish = "image/fish/fish_flyingfish.png",
        silverfish = "image/fish/fish_silverfish.png",
        gemfish    = "image/fish/fish_gemfish.png",
        octopus    = "image/fish/fish_octopus.png",
    }
    for name, path in pairs(fishImageMap) do
        local img = nvgCreateImage(nvg, path, NVG_IMAGE_PREMULTIPLIED)
        if img and img > 0 then fishIcons_[name] = img end
    end

    -- 猫咪精灵帧加载: catSprites_[catType] = { walk={img1..4}, sit={img1..2}, eat={img1..2} }
    local catSpriteFiles = {
        orange = {
            walk = {
                "image/cat_orange_walk1_20260505095228.png",
                "image/cat_orange_walk2_20260505100046.png",
                "image/cat_orange_walk3_20260505095948.png",
                "image/cat_orange_walk4_20260505100623.png",
            },
            sit = {
                "image/cat_orange_sit1_20260505102643.png",
                "image/cat_orange_sit2_20260505101412.png",
            },
            eat = {
                "image/cat_orange_eat1_20260505101652.png",
                "image/cat_orange_eat2_20260505103454.png",
            },
        },
        -- 其他花色待生成后添加
    }
    for catType, anims in pairs(catSpriteFiles) do
        catSprites_[catType] = {}
        for animName, paths in pairs(anims) do
            catSprites_[catType][animName] = {}
            for idx, path in ipairs(paths) do
                local img = nvgCreateImage(nvg, path, NVG_IMAGE_PREMULTIPLIED)
                if img and img > 0 then
                    catSprites_[catType][animName][idx] = img
                else
                    print(string.format("[IndustryScene] WARNING: 猫咪帧加载失败: %s", path))
                end
            end
        end
        local wc = catSprites_[catType].walk and #catSprites_[catType].walk or 0
        local sc = catSprites_[catType].sit and #catSprites_[catType].sit or 0
        local ec = catSprites_[catType].eat and #catSprites_[catType].eat or 0
        print(string.format("[IndustryScene] 猫咪[%s] walk=%d sit=%d eat=%d", catType, wc, sc, ec))
    end

    -- 加载进度条序列帧 (flair_circle_red_0 ~ flair_circle_red_8)
    for i = 0, 8 do
        local path = string.format("image/flair_circle_red_%d.png", i)
        local img = nvgCreateImage(nvg, path, NVG_IMAGE_PREMULTIPLIED)
        if img and img > 0 then
            progressFrames_[i] = img
        else
            print(string.format("[IndustryScene] WARNING: 进度条帧 %d 加载失败: %s", i, path))
        end
    end
    print(string.format("[IndustryScene] 进度条序列帧: %d 帧已加载", #progressFrames_ + 1))

    -- 初始化餐厅系统
    IndustrySystem:init()

    print("[IndustryScene] 初始化完成 (v2: 双座位, 过道行走, 序列帧进度条)")
end

-- ============================================================================
-- 更新
-- ============================================================================

function IndustryScene.update(dt)
    if toastTimer_ > 0 then
        toastTimer_ = toastTimer_ - dt
        if toastTimer_ <= 0 then toastMsg_ = nil end
    end
    if cashBounce_ > 0 then
        cashBounce_ = cashBounce_ - dt * 3
        if cashBounce_ < 0 then cashBounce_ = 0 end
    end
    -- 菜单道具浮动按钮动画
    menuBtnFloatTime_ = menuBtnFloatTime_ + dt
end

function IndustryScene.showToast(msg)
    toastMsg_ = msg
    toastTimer_ = 2.0
end

-- ============================================================================
-- 调试拖拽处理
-- ============================================================================

-- 计算所有桌子的统一包围框 (像素坐标, 含桌子尺寸)
function IndustryScene.getDebugBoundingBox()
    local tableCenters = IndustrySystem:getTableCenters()
    local TABLE_VISUAL_ASPECT = 1.3
    local tw = dockDrawW_ * TABLE_W_RATIO
    local th = tw / TABLE_VISUAL_ASPECT
    local pad = 8  -- 包围框内边距

    local minX, minY =  math.huge,  math.huge
    local maxX, maxY = -math.huge, -math.huge

    for i = 1, IndustrySystem:getTableCount() do
        local tc = tableCenters[i]
        local cx = dockDrawX_ + dockDrawW_ * tc.x
        local cy = dockDrawY_ + dockDrawH_ * tc.y
        local left   = cx - tw * 0.5
        local top    = cy - th * 0.5
        local right  = left + tw
        local bottom = top + th
        if left   < minX then minX = left   end
        if top    < minY then minY = top    end
        if right  > maxX then maxX = right  end
        if bottom > maxY then maxY = bottom end
    end

    return minX - pad, minY - pad, (maxX - minX) + pad * 2, (maxY - minY) + pad * 2
end

function IndustryScene.updateDebugDrag()
    if not DEBUG_TABLE_DRAG then return end

    local dpr = graphics:GetDPR()
    local pos = input:GetMousePosition()
    local logX = pos.x / dpr
    local logY = pos.y / dpr

    local bx, by, bw, bh = IndustryScene.getDebugBoundingBox()

    -- ── 按下: 优先检测座位点命中, 再检测整体框 ──
    if input:GetMouseButtonPress(MOUSEB_LEFT) then
        -- 座位命中检测 (用第1张桌子的座位作为代表)
        local tableCenters = IndustrySystem:getTableCenters()
        local seatDX, seatDY = IndustrySystem:getSeatOffsets()
        local hitRadius = 30  -- 点击热区半径 (放大便于触控)

        local tc1 = tableCenters[1]
        if tc1 then
            for seatIn = 1, 2 do
                local sx = dockDrawX_ + dockDrawW_ * (tc1.x + seatDX[seatIn])
                local sy = dockDrawY_ + dockDrawH_ * (tc1.y + seatDY)
                local dist = math.sqrt((logX - sx)^2 + (logY - sy)^2)
                if dist <= hitRadius then
                    debugDragSeat_ = seatIn
                    debugSeatOffX_ = logX - sx
                    debugSeatOffY_ = logY - sy
                    return
                end
            end
        end

        -- 整体框命中 (仅当开关打开时)
        if DEBUG_DRAG_TABLE_BOX and logX >= bx and logX <= bx + bw and logY >= by and logY <= by + bh then
            debugDragging_ = true
            debugOffsetX_ = logX - bx
            debugOffsetY_ = logY - by
            return
        end
    end

    -- ── 座位拖拽中 ──
    if debugDragSeat_ and input:GetMouseButtonDown(MOUSEB_LEFT) then
        local tableCenters = IndustrySystem:getTableCenters()
        local seatDX, seatDY = IndustrySystem:getSeatOffsets()
        local tc1 = tableCenters[1]
        if tc1 then
            local newSX = logX - debugSeatOffX_
            local newSY = logY - debugSeatOffY_
            -- 座位偏移 = 座位绝对位置 - 桌子中心
            local newDX = (newSX - dockDrawX_) / dockDrawW_ - tc1.x
            local newDY = (newSY - dockDrawY_) / dockDrawH_ - tc1.y
            local newSeatDX = { seatDX[1], seatDX[2] }
            newSeatDX[debugDragSeat_] = newDX
            IndustrySystem:setSeatOffsets(newSeatDX, newDY)
        end
        return
    elseif debugDragSeat_ then
        -- 松手 → 打印座位偏移
        local seatDX, seatDY = IndustrySystem:getSeatOffsets()
        print("[DEBUG] === 座位偏移最终值 ===")
        print(string.format("  SEAT_DX = { %.3f, %.3f }", seatDX[1], seatDX[2]))
        print(string.format("  SEAT_DY = %.3f", seatDY))
        print("[DEBUG] === END ===")
        debugDragSeat_ = nil
    end

    -- ── 整体框拖拽中 ──
    if debugDragging_ and input:GetMouseButtonDown(MOUSEB_LEFT) then
        local newBX = logX - debugOffsetX_
        local newBY = logY - debugOffsetY_
        local dx = newBX - bx
        local dy = newBY - by
        local dnx = dx / dockDrawW_
        local dny = dy / dockDrawH_

        local tableCenters = IndustrySystem:getTableCenters()
        for i = 1, IndustrySystem:getTableCount() do
            tableCenters[i].x = tableCenters[i].x + dnx
            tableCenters[i].y = tableCenters[i].y + dny
        end
    else
        if debugDragging_ then
            local tableCenters = IndustrySystem:getTableCenters()
            print("[DEBUG] === 桌子最终坐标 ===")
            for i = 1, IndustrySystem:getTableCount() do
                local tc = tableCenters[i]
                print(string.format("  桌子%d: { x = %.3f, y = %.3f },", i, tc.x, tc.y))
            end
            print("[DEBUG] === END ===")
            debugDragging_ = false
        end
    end
end

-- ============================================================================
-- 输入检测
-- ============================================================================

---@return string|nil action  "go_fishing" | "go_breeding" | "go_aquarium" | "go_research" | "go_codex" | nil
function IndustryScene.checkInput()
    -- 调试拖拽优先处理 (每帧都要调用, 不只是 press)
    IndustryScene.updateDebugDrag()
    if debugDragging_ or debugDragSeat_ then return nil end  -- 拖拽中, 吞掉点击

    -- 收银台拖拽调试
    IndustryScene.updateCashRegDrag()
    if debugDragCash_ then return nil end

    -- 出海按钮拖拽调试
    IndustryScene.updateGoBtnDrag()
    if debugDragGoBtn_ then return nil end

    -- 菜单板拖拽/缩放调试
    IndustryScene.updateMenuBoardDrag()
    if debugDragMenu_ or debugMenuScaling_ then return nil end

    if not input:GetMouseButtonPress(MOUSEB_LEFT) then
        return nil
    end

    local dpr = graphics:GetDPR()
    local pos = input:GetMousePosition()
    local logX = pos.x / dpr
    local logY = pos.y / dpr

    -- 出海面板打开时优先处理
    if goFishingOpen_ then
        for _, rect in ipairs(clickRects_) do
            if logX >= rect.x and logX <= rect.x + rect.w and
               logY >= rect.y and logY <= rect.y + rect.h then
                -- 解锁弹窗打开时，优先处理弹窗按钮
                if unlockPopup_.open then
                    if rect.action == "confirm_unlock" then
                        -- 扣币并解锁
                        if GameState:spendCoins(unlockPopup_.cost) then
                            GameState.unlockedZones[unlockPopup_.zoneKey] = true
                            selectedZoneIdx_ = unlockPopup_.zoneIdx
                            print("[GoFishing] 解锁海域: " .. unlockPopup_.zoneName)
                        end
                        unlockPopup_.open = false
                        return nil
                    elseif rect.action == "cancel_unlock" then
                        unlockPopup_.open = false
                        return nil
                    end
                    -- 弹窗打开时忽略其他点击
                    return nil
                end

                if rect.action == "select_zone" then
                    selectedZoneIdx_ = rect.data
                    return nil
                elseif rect.action == "try_unlock_zone" then
                    local zone = ZONE_LIST[rect.data]
                    local cost = EconomySystem.getZoneUnlockCost(zone.key)
                    unlockPopup_.open = true
                    unlockPopup_.zoneIdx = rect.data
                    unlockPopup_.zoneKey = zone.key
                    unlockPopup_.zoneName = zone.icon .. " " .. zone.name
                    unlockPopup_.cost = cost
                    unlockPopup_.canAfford = (GameState.coins >= cost)
                    return nil
                elseif rect.action == "select_bait" then
                    selectedBaitIdx_ = rect.data
                    return nil
                elseif rect.action == "confirm_go_fishing" then
                    goFishingOpen_ = false
                    unlockPopup_.open = false
                    local zone = ZONE_LIST[selectedZoneIdx_]
                    if zone then
                        GameState.currentZone = zone.key
                    end
                    return "go_fishing"
                elseif rect.action == "panel_bg" then
                    return nil  -- 吸收面板背景点击,不关闭
                elseif rect.action == "close_go_fishing" then
                    goFishingOpen_ = false
                    unlockPopup_.open = false
                    return nil
                end
            end
        end
        goFishingOpen_ = false
        return nil
    end

    if menuOpen_ then
        -- 升级弹窗优先处理
        if upgradePopup_.open then
            for _, rect in ipairs(clickRects_) do
                if logX >= rect.x and logX <= rect.x + rect.w and
                   logY >= rect.y and logY <= rect.y + rect.h then
                    if rect.action == "confirm_upgrade" then
                        local ok = GameState:upgradeRecipe(upgradePopup_.recipeId, upgradePopup_.cost, upgradePopup_.fishReqs)
                        if ok then
                            IndustryScene.showToast(upgradePopup_.recipeName .. " 升级成功!")
                        else
                            IndustryScene.showToast("升级失败")
                        end
                        upgradePopup_.open = false
                        return nil
                    elseif rect.action == "cancel_upgrade" then
                        upgradePopup_.open = false
                        return nil
                    end
                end
            end
            upgradePopup_.open = false
            return nil
        end

        for _, rect in ipairs(clickRects_) do
            if logX >= rect.x and logX <= rect.x + rect.w and
               logY >= rect.y and logY <= rect.y + rect.h then
                if rect.action == "cook" then
                    local ok, err = IndustrySystem:cookFood(rect.data)
                    if ok then
                        local recipe = GameConfig.SUSHI_BY_ID[rect.data]
                        IndustryScene.showToast(recipe.icon .. " " .. recipe.displayName .. " 排队合成中")
                    else
                        IndustryScene.showToast(err or "无法制作")
                    end
                    return nil
                elseif rect.action == "unlock_synthesis_slot" then
                    local ok, err = IndustrySystem:unlockQueueSlot()
                    if ok then
                        IndustryScene.showToast("待处理区扩容成功! (" .. GameState.unlockedSynthesisSlots .. "槽)")
                    else
                        IndustryScene.showToast(err or "无法扩容")
                    end
                    return nil
                elseif rect.action == "open_upgrade" then
                    local recipeId = rect.data
                    local recipe = GameConfig.SUSHI_BY_ID[recipeId]
                    local curLv = GameState:getRecipeLevel(recipeId)
                    local cost = GameConfig.getRecipeUpgradeCost(recipeId, curLv)
                    -- 获取升级所需鱼材料
                    local fishReqs = GameConfig.getRecipeUpgradeFish(recipeId, curLv)
                    local fishEnough = true
                    for _, req in ipairs(fishReqs) do
                        req.have = GameState:getFishCount(req.fishId)
                        if req.have < req.count then fishEnough = false end
                    end
                    upgradePopup_.open = true
                    upgradePopup_.recipeId = recipeId
                    upgradePopup_.recipeName = recipe.displayName
                    upgradePopup_.currentLevel = curLv
                    upgradePopup_.cost = cost
                    upgradePopup_.curPrice = IndustrySystem:getSellPrice(recipeId)
                    upgradePopup_.nextPrice = IndustrySystem:getSellPrice(recipeId, curLv + 1)
                    upgradePopup_.canAfford = GameState.coins >= cost and fishEnough
                    upgradePopup_.fishReqs = fishReqs
                    upgradePopup_.fishEnough = fishEnough
                    return nil
                elseif rect.action == "close_menu" then
                    menuOpen_ = false
                    upgradePopup_.open = false
                    return nil
                end
            end
        end
        menuOpen_ = false
        upgradePopup_.open = false
        return nil
    end

    for _, rect in ipairs(clickRects_) do
        if logX >= rect.x and logX <= rect.x + rect.w and
           logY >= rect.y and logY <= rect.y + rect.h then
            if rect.action == "go_fishing" then
                goFishingOpen_ = true
                selectedBaitIdx_ = 1
                return nil
            elseif rect.action == "go_breeding" then
                return "go_breeding"
            elseif rect.action == "go_aquarium" then
                return "go_aquarium"
            elseif rect.action == "go_research" then
                return "go_research"
            elseif rect.action == "go_codex" then
                return "go_codex"
            elseif rect.action == "open_menu" then
                menuOpen_ = true
                menuScrollY_ = 0
                return nil
            elseif rect.action == "collect_cash" then
                local amount = IndustrySystem:collectCash()
                if amount > 0 then
                    IndustryScene.showToast("收取 " .. FormatUtils.formatNumber(amount) .. " 金币!")
                    cashBounce_ = 1.0
                else
                    IndustryScene.showToast("收银台空空如也~")
                end
                return nil
            end
        end
    end

    return nil
end

-- ============================================================================
-- 渲染主函数
-- ============================================================================

function IndustryScene.render(nvg, x, y, w, h)
    clickRects_ = {}

    IndustryScene.renderBackground(nvg, x, y, w, h)
    IndustryScene.renderCurrencyBar(nvg, x, y + 14, w)
    -- IndustryScene.renderFishStorage(nvg)   -- 隐藏鱼仓
    IndustryScene.renderMenuSign(nvg)
    -- IndustryScene.renderFoodBar(nvg)       -- 隐藏库存条
    IndustryScene.renderTables(nvg)
    IndustryScene.renderCats(nvg)
    IndustryScene.renderCashRegister(nvg)
    IndustryScene.renderGoFishingBtn(nvg, x, y, w, h)

    if DEBUG_TABLE_DRAG then
        IndustryScene.renderDebugOverlay(nvg)
    end

    if goFishingOpen_ then
        IndustryScene.renderGoFishingPanel(nvg, x, y, w, h)
    elseif menuOpen_ then
        IndustryScene.renderMenuPanel(nvg, x, y, w, h)
    end
    if toastMsg_ and toastTimer_ > 0 then
        IndustryScene.renderToast(nvg, x, y, w, h)
    end
end

-- ============================================================================
-- 底图背景 (cover-fit)
-- ============================================================================

function IndustryScene.renderBackground(nvg, x, y, w, h)
    if not imgDockBg_ or imgDockBg_ <= 0 then
        nvgBeginPath(nvg)
        nvgRect(nvg, x, y, w, h)
        nvgFillColor(nvg, nvgRGBA(30, 165, 205, 255))
        nvgFill(nvg)
        return
    end

    local iw, ih = nvgImageSize(nvg, imgDockBg_)
    if iw <= 0 or ih <= 0 then iw, ih = dockImgW_, dockImgH_ end
    if iw <= 0 or ih <= 0 then return end

    local imgAspect = iw / ih
    local scrAspect = w / h
    local drawW, drawH
    if scrAspect > imgAspect then
        drawW = w; drawH = w / imgAspect
    else
        drawH = h; drawW = h * imgAspect
    end
    local drawX = x + (w - drawW) * 0.5
    local drawY = y + (h - drawH) * 0.5

    dockDrawX_ = x
    dockDrawY_ = y
    dockDrawW_ = w
    dockDrawH_ = h

    nvgSave(nvg)
    nvgScissor(nvg, x, y, w, h)

    local pat = nvgImagePattern(nvg, drawX, drawY, drawW, drawH, 0, imgDockBg_, 1.0)
    nvgBeginPath(nvg)
    nvgRect(nvg, drawX, drawY, drawW, drawH)
    nvgFillPaint(nvg, pat)
    nvgFill(nvg)

    nvgRestore(nvg)
end

-- ============================================================================
-- 货币栏
-- ============================================================================

function IndustryScene.renderCurrencyBar(nvg, x, y, w)
    local barH = 32
    local barW = 100
    local gap  = 10
    local totalW = barW * 2 + gap
    local startX = x + (w - totalW) * 0.5

    IndustryScene.drawCurrBar(nvg, startX, y, barW, barH,
        imgCoin_, FormatUtils.formatNumber(GameState.coins), false)
    IndustryScene.drawCurrBar(nvg, startX + barW + gap, y, barW, barH,
        imgDiamond_, FormatUtils.formatNumber(GameState.diamonds), true)
end

function IndustryScene.drawCurrBar(nvg, bx, by, bw, bh, imgIcon, text, showPlus)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, bx, by, bw, bh, 5)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 120))
    nvgFill(nvg)

    if imgCurrBg_ and imgCurrBg_ > 0 then
        local pat = nvgImagePattern(nvg, bx, by, bw, bh, 0, imgCurrBg_, 0.85)
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, bx, by, bw, bh, 5)
        nvgFillPaint(nvg, pat)
        nvgFill(nvg)
    end

    local iconSize = bh * 0.75
    local iconY = by + (bh - iconSize) * 0.5
    local iconX = bx + 3
    if imgIcon and imgIcon > 0 then
        local pat = nvgImagePattern(nvg, iconX, iconY, iconSize, iconSize, 0, imgIcon, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, iconX, iconY, iconSize, iconSize)
        nvgFillPaint(nvg, pat)
        nvgFill(nvg)
    end

    local textX = iconX + iconSize + 4
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, bh * 0.48)
    nvgFillColor(nvg, nvgRGBA(30, 30, 30, 240))
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgText(nvg, textX, by + bh * 0.5, text)

    if showPlus and imgPlus_ and imgPlus_ > 0 then
        local plusSize = bh * 0.6
        local plusX = bx + bw - plusSize - 2
        local plusY = by + (bh - plusSize) * 0.5
        local pat = nvgImagePattern(nvg, plusX, plusY, plusSize, plusSize, 0, imgPlus_, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, plusX, plusY, plusSize, plusSize)
        nvgFillPaint(nvg, pat)
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 鱼仓概览 (左上)
-- ============================================================================

function IndustryScene.renderFishStorage(nvg)
    local bx = dockDrawX_ + dockDrawW_ * 0.04
    local by = dockDrawY_ + dockDrawH_ * 0.06
    local bw = dockDrawW_ * 0.28
    local bh = 24

    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, bx, by, bw, bh, 4)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 140))
    nvgFill(nvg)

    local totalFish = 0
    for _, count in pairs(GameState.fishInventory) do
        totalFish = totalFish + count
    end

    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 12)
    nvgFillColor(nvg, nvgRGBA(255, 240, 200, 240))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(nvg, bx + bw * 0.5, by + bh * 0.5, "鱼仓 " .. totalFish .. " 条")
end

-- ============================================================================
-- 菜单板拖拽/缩放调试
-- ============================================================================

function IndustryScene.updateMenuBoardDrag()
    if not DEBUG_MENU_BOARD then return end

    local dpr = graphics:GetDPR()
    local pos = input:GetMousePosition()
    local logX = pos.x / dpr
    local logY = pos.y / dpr

    -- 计算当前菜单板矩形
    local boardH = dockDrawH_ * menuBoardNH_
    local boardW = boardH
    if menuBoardImgW_ > 0 and menuBoardImgH_ > 0 then
        boardW = boardH * (menuBoardImgW_ / menuBoardImgH_)
    end
    local boardX = dockDrawX_ + dockDrawW_ * menuBoardNX_ - boardW * 0.5
    local boardY = dockDrawY_ + dockDrawH_ * menuBoardNY_

    if input:GetMouseButtonPress(MOUSEB_LEFT) then
        -- 右下角缩放手柄 (20x20区域)
        local handleSize = 20
        local hx = boardX + boardW - handleSize
        local hy = boardY + boardH - handleSize
        if logX >= hx and logX <= boardX + boardW and logY >= hy and logY <= boardY + boardH then
            debugMenuScaling_ = true
            debugMenuScaleOffY_ = logY - (boardY + boardH)
            return
        end
        -- 整体拖拽
        if logX >= boardX and logX <= boardX + boardW and logY >= boardY and logY <= boardY + boardH then
            debugDragMenu_ = true
            debugMenuOffX_ = logX - boardX
            debugMenuOffY_ = logY - boardY
            return
        end
    end

    -- 缩放拖拽中
    if debugMenuScaling_ and input:GetMouseButtonDown(MOUSEB_LEFT) then
        local newBottom = logY - debugMenuScaleOffY_
        local newH = newBottom - (dockDrawY_ + dockDrawH_ * menuBoardNY_)
        menuBoardNH_ = math.max(0.10, math.min(0.60, newH / dockDrawH_))
        return
    elseif debugMenuScaling_ then
        debugMenuScaling_ = false
        IndustryScene.printMenuBoardDebug()
    end

    -- 位置拖拽中
    if debugDragMenu_ and input:GetMouseButtonDown(MOUSEB_LEFT) then
        local newX = logX - debugMenuOffX_
        local newY = logY - debugMenuOffY_
        -- 反算当前boardW
        local curH = dockDrawH_ * menuBoardNH_
        local curW = curH
        if menuBoardImgW_ > 0 and menuBoardImgH_ > 0 then
            curW = curH * (menuBoardImgW_ / menuBoardImgH_)
        end
        menuBoardNX_ = (newX + curW * 0.5 - dockDrawX_) / dockDrawW_
        menuBoardNY_ = (newY - dockDrawY_) / dockDrawH_
        return
    elseif debugDragMenu_ then
        debugDragMenu_ = false
        IndustryScene.printMenuBoardDebug()
    end
end

function IndustryScene.printMenuBoardDebug()
    print("[DEBUG] === 菜单板最终参数 ===")
    print(string.format("  menuBoardNX_ = %.3f", menuBoardNX_))
    print(string.format("  menuBoardNY_ = %.3f", menuBoardNY_))
    print(string.format("  menuBoardNH_ = %.3f", menuBoardNH_))
    print("[DEBUG] === END ===")
end

-- ============================================================================
-- 菜单招牌 (右上)
-- ============================================================================

function IndustryScene.renderMenuSign(nvg)
    -- ── 菜单黑板道具 (图片贴图, 保持宽高比) ──
    local boardH = dockDrawH_ * menuBoardNH_
    local boardW = boardH
    if menuBoardImgW_ > 0 and menuBoardImgH_ > 0 then
        boardW = boardH * (menuBoardImgW_ / menuBoardImgH_)
    end
    local boardX = dockDrawX_ + dockDrawW_ * menuBoardNX_ - boardW * 0.5
    local boardY = dockDrawY_ + dockDrawH_ * menuBoardNY_

    if imgMenuBoard_ and imgMenuBoard_ > 0 then
        local pat = nvgImagePattern(nvg, boardX, boardY, boardW, boardH, 0, imgMenuBoard_, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, boardX, boardY, boardW, boardH)
        nvgFillPaint(nvg, pat)
        nvgFill(nvg)
    else
        -- 后备: 简单矩形
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, boardX, boardY, boardW, boardH, 4)
        nvgFillColor(nvg, nvgRGBA(50, 60, 50, 230))
        nvgFill(nvg)
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 13)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 220))
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgText(nvg, boardX + boardW * 0.5, boardY + boardH * 0.5, "菜单")
    end

    -- 黑板点击区域 (打开菜单)
    table.insert(clickRects_, {
        x = boardX, y = boardY,
        w = boardW, h = boardH,
        action = "open_menu",
    })

    -- ── 浮动圆形按钮 (黑板上方居中) ──
    local btnSize = 28
    local floatAmp = 3   -- 浮动幅度 (像素)
    local floatSpeed = 2.0
    local floatY = math.sin(menuBtnFloatTime_ * floatSpeed) * floatAmp
    local btnCX = boardX + boardW * 0.5
    local btnCY = boardY - btnSize * 0.5 - 2 + floatY
    local btnX = btnCX - btnSize * 0.5
    local btnY = btnCY - btnSize * 0.5

    -- 圆形底图
    if imgBtnRound_ and imgBtnRound_ > 0 then
        local pat = nvgImagePattern(nvg, btnX, btnY, btnSize, btnSize, 0, imgBtnRound_, 0.95)
        nvgBeginPath(nvg)
        nvgCircle(nvg, btnCX, btnCY, btnSize * 0.5)
        nvgFillPaint(nvg, pat)
        nvgFill(nvg)
    else
        nvgBeginPath(nvg)
        nvgCircle(nvg, btnCX, btnCY, btnSize * 0.5)
        nvgFillColor(nvg, nvgRGBA(200, 200, 210, 220))
        nvgFill(nvg)
    end

    -- 加号图标 (叠加在圆形上)
    if imgPlus_ and imgPlus_ > 0 then
        local iconSize = btnSize * 0.55
        local iconX = btnCX - iconSize * 0.5
        local iconY = btnCY - iconSize * 0.5
        local pat = nvgImagePattern(nvg, iconX, iconY, iconSize, iconSize, 0, imgPlus_, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, iconX, iconY, iconSize, iconSize)
        nvgFillPaint(nvg, pat)
        nvgFill(nvg)
    end

    -- 浮动按钮也触发打开菜单
    table.insert(clickRects_, {
        x = btnX, y = btnY, w = btnSize, h = btnSize,
        action = "open_menu",
    })

    -- ── 调试覆盖层 ──
    if DEBUG_MENU_BOARD then
        -- 绿色边框
        nvgBeginPath(nvg)
        nvgRect(nvg, boardX, boardY, boardW, boardH)
        nvgStrokeColor(nvg, nvgRGBA(0, 255, 0, 200))
        nvgStrokeWidth(nvg, 2)
        nvgStroke(nvg)

        -- 右下角缩放手柄 (橙色小方块)
        local handleSize = 20
        local hx = boardX + boardW - handleSize
        local hy = boardY + boardH - handleSize
        nvgBeginPath(nvg)
        nvgRect(nvg, hx, hy, handleSize, handleSize)
        nvgFillColor(nvg, nvgRGBA(255, 160, 0, 180))
        nvgFill(nvg)
        nvgStrokeColor(nvg, nvgRGBA(255, 200, 0, 255))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)

        -- 底部调试参数面板
        local screenW = graphics:GetWidth() / graphics:GetDPR()
        local screenH = graphics:GetHeight() / graphics:GetDPR()
        local panelH = 36
        local panelY = screenH - panelH
        nvgBeginPath(nvg)
        nvgRect(nvg, 0, panelY, screenW, panelH)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 180))
        nvgFill(nvg)

        local debugText = string.format(
            "MENU NX=%.3f  NY=%.3f  NH=%.3f",
            menuBoardNX_, menuBoardNY_, menuBoardNH_
        )
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 14)
        nvgFillColor(nvg, nvgRGBA(0, 255, 0, 255))
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgText(nvg, screenW * 0.5, panelY + panelH * 0.5, debugText)
    end
end

-- ============================================================================
-- 食物库存条
-- ============================================================================

function IndustryScene.renderFoodBar(nvg)
    local totalFood = GameState:getTotalFoodCount()

    local barY = dockDrawY_ + dockDrawH_ * 0.20
    local barH = 26
    local barX = dockDrawX_ + dockDrawW_ * 0.04
    local barMaxW = dockDrawW_ * 0.92

    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, barX, barY, barMaxW, barH, 5)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 100))
    nvgFill(nvg)

    nvgFontFace(nvg, "sans")
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    local cy = barY + barH * 0.5
    local cx = barX + 8

    nvgFontSize(nvg, 11)
    nvgFillColor(nvg, nvgRGBA(200, 180, 140, 200))
    nvgText(nvg, cx, cy, "库存:")
    cx = cx + 32

    if totalFood <= 0 then
        nvgFillColor(nvg, nvgRGBA(160, 140, 110, 150))
        nvgFontSize(nvg, 10)
        nvgText(nvg, cx, cy, "空 — 点菜单合成食物")
        return
    end

    for _, recipe in ipairs(GameConfig.SUSHI) do
        local count = GameState:getFoodCount(recipe.id)
        if count > 0 then
            nvgFontSize(nvg, 14)
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, 240))
            nvgText(nvg, cx, cy, recipe.icon)
            cx = cx + 18

            nvgFontSize(nvg, 11)
            nvgFillColor(nvg, nvgRGBA(255, 230, 160, 230))
            local countStr = "x" .. count
            nvgText(nvg, cx, cy, countStr)
            cx = cx + nvgTextBounds(nvg, 0, 0, countStr) + 10

            if cx > barX + barMaxW - 20 then break end
        end
    end
end

-- ============================================================================
-- 桌子渲染 (保持图片宽高比)
-- ============================================================================

function IndustryScene.renderTables(nvg)
    local tableCenters = IndustrySystem:getTableCenters()

    -- 桶桌视觉宽高比 ~1.3:1 (nvgImageSize 返回 16x16 不可靠, 硬编码)
    local TABLE_VISUAL_ASPECT = 1.3
    local tw = dockDrawW_ * TABLE_W_RATIO
    local th = tw / TABLE_VISUAL_ASPECT

    for i = 1, IndustrySystem:getTableCount() do
        local tc = tableCenters[i]
        -- 桌子中心坐标
        local cx = dockDrawX_ + dockDrawW_ * tc.x
        local cy = dockDrawY_ + dockDrawH_ * tc.y
        -- 左上角
        local tx = cx - tw * 0.5
        local ty = cy - th * 0.5

        if imgTable_ and imgTable_ > 0 then
            local pat = nvgImagePattern(nvg, tx, ty, tw, th, 0, imgTable_, 1.0)
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, tx, ty, tw, th, 4)
            nvgFillPaint(nvg, pat)
            nvgFill(nvg)
        else
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, tx, ty, tw, th, 5)
            nvgFillColor(nvg, nvgRGBA(160, 110, 60, 220))
            nvgFill(nvg)
        end
    end
end

-- ============================================================================
-- 猫咪统一渲染 (占位圆形 + 气泡 + 进度条)
-- ============================================================================

-- 猫咪颜色映射
local CAT_COLORS = {
    orange = { 240, 160,  60 },
    black  = {  60,  60,  60 },
    white  = { 230, 230, 230 },
    calico = { 200, 150,  80 },
    grey   = { 150, 150, 150 },
}

-- 辅助: 绘制猫咪精灵帧 (以 cx,cy 为中心, size 为边长)
-- animName: "walk"|"sit"|"eat",  animAge: 累计时间,  fps: 帧率
-- 返回 true 表示绘制了精灵, false 表示无精灵需要 fallback
local function drawCatSprite(nvg, catType, animName, animAge, cx, cy, size, fps)
    local sprites = catSprites_[catType]
    if not sprites then sprites = catSprites_["orange"] end  -- fallback 到橘猫
    if not sprites then return false end
    local frames = sprites[animName]
    if not frames or #frames == 0 then return false end

    fps = fps or 4
    local frameIdx = math.floor(animAge * fps) % #frames + 1
    local img = frames[frameIdx]
    if not img or img <= 0 then return false end

    local half = size * 0.5
    local pat = nvgImagePattern(nvg, cx - half, cy - half, size, size, 0, img, 1.0)
    nvgBeginPath(nvg)
    nvgRect(nvg, cx - half, cy - half, size, size)
    nvgFillPaint(nvg, pat)
    nvgFill(nvg)
    return true
end

function IndustryScene.renderCats(nvg)
    local seats = IndustrySystem:getSeatStates()
    local totalSeats = IndustrySystem:getTotalSeats()

    for i = 1, totalSeats do
        local s = seats[i]
        if s.state ~= "empty" then
            if s.state == "entering" or s.state == "leaving" then
                IndustryScene.renderWalkingCat(nvg, s)
            else
                IndustryScene.renderSeatedCat(nvg, s)
            end
        end
    end
end

-- 行走中的猫咪 (entering / leaving)
function IndustryScene.renderWalkingCat(nvg, s)
    local px = dockDrawX_ + dockDrawW_ * s.posX
    local py = dockDrawY_ + dockDrawH_ * s.posY
    local spriteSize = dockDrawW_ * 0.09  -- 行走精灵尺寸

    -- 尝试用精灵帧绘制
    if drawCatSprite(nvg, s.catType, "walk", s.animAge, px, py, spriteSize, 6) then
        return  -- 精灵绘制成功
    end

    -- fallback: 占位圆形
    local r = dockDrawW_ * 0.035  -- fallback 圆圈
    local col = CAT_COLORS[s.catType] or CAT_COLORS.orange
    nvgBeginPath(nvg)
    nvgCircle(nvg, px, py, r)
    nvgFillColor(nvg, nvgRGBA(col[1], col[2], col[3], 220))
    nvgFill(nvg)
end

-- 坐着的猫咪 (choosing / eating / no_food)
function IndustryScene.renderSeatedCat(nvg, s)
    local px = dockDrawX_ + dockDrawW_ * s.posX
    local py = dockDrawY_ + dockDrawH_ * s.posY
    local spriteSize = dockDrawW_ * 0.10  -- 坐着精灵尺寸

    -- 根据状态选择动画
    local animName = "sit"
    local fps = 2   -- 坐着慢切帧
    if s.state == "eating" then
        animName = "eat"
        fps = 3
    end

    -- 尝试用精灵帧绘制
    local drawn = drawCatSprite(nvg, s.catType, animName, s.animAge, px, py, spriteSize, fps)

    if not drawn then
        -- fallback: 占位圆形
        local r = dockDrawW_ * 0.04  -- fallback 圆圈
        local col = CAT_COLORS[s.catType] or CAT_COLORS.orange
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, r)
        nvgFillColor(nvg, nvgRGBA(col[1], col[2], col[3], 230))
        nvgFill(nvg)
    end

    -- ── 状态特定装饰 (气泡/进度条/倒计时) ──
    local catR = spriteSize * 0.5  -- 用于气泡定位

    if s.state == "choosing" then
        IndustryScene.renderChoosingBubble(nvg, px, py, catR, s)
    elseif s.state == "eating" then
        IndustryScene.renderEatingOverlay(nvg, px, py, catR, s)
    elseif s.state == "no_food" then
        IndustryScene.renderNoFoodOverlay(nvg, px, py, catR, s)
    end
end

-- choosing 状态: 气泡框 (问号 / 食物图标)
function IndustryScene.renderChoosingBubble(nvg, cx, cy, catR, s)
    local bubbleR = catR * 0.7
    local bubbleX = cx + catR * 0.6
    local bubbleY = cy - catR * 1.4

    -- 气泡背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, bubbleX - bubbleR, bubbleY - bubbleR, bubbleR * 2, bubbleR * 2, bubbleR * 0.4)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 220))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(100, 80, 60, 140))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)

    -- 小三角 (指向猫咪)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, bubbleX - bubbleR * 0.3, bubbleY + bubbleR)
    nvgLineTo(nvg, bubbleX - bubbleR * 0.5, bubbleY + bubbleR + bubbleR * 0.4)
    nvgLineTo(nvg, bubbleX + bubbleR * 0.1, bubbleY + bubbleR)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 220))
    nvgFill(nvg)

    -- 内容: wondering=问号, decided=食物图标
    nvgFontFace(nvg, "sans")
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    if s.choosingPhase == "wondering" then
        nvgFontSize(nvg, bubbleR * 1.4)
        nvgFillColor(nvg, nvgRGBA(120, 100, 80, 200))
        nvgText(nvg, bubbleX, bubbleY, "?")
    elseif s.choosingPhase == "decided" then
        local recipe = GameConfig.SUSHI_BY_ID[s.wantRecipeId]
        if recipe then
            nvgFontSize(nvg, bubbleR * 1.2)
            nvgFillColor(nvg, nvgRGBA(60, 50, 40, 240))
            nvgText(nvg, bubbleX, bubbleY, recipe.icon)
        end
    end
end

-- eating 状态: 进度条 + 食物图标
function IndustryScene.renderEatingOverlay(nvg, cx, cy, catR, s)
    local eatDur = IndustrySystem:getEatDuration()
    local progress = 1.0 - math.max(0, s.timer / eatDur)

    -- 进度条 (序列帧, 头顶)
    local progR = catR * 0.55
    local progY = cy - catR * 1.3
    IndustryScene.drawCircleProgress(nvg, cx, progY, progR, progress,
        nvgRGBA(80, 200, 80, 240), nvgRGBA(50, 50, 50, 120))

    -- 食物图标 (猫咪下方)
    local recipe = GameConfig.SUSHI_BY_ID[s.wantRecipeId]
    if recipe then
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, catR * 0.8)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 220))
        nvgText(nvg, cx, cy + catR * 1.3, recipe.icon)
    end
end

-- no_food 状态: 食物图标气泡 + 等待倒计时
function IndustryScene.renderNoFoodOverlay(nvg, cx, cy, catR, s)
    -- 头顶气泡 (显示想要的食物)
    local bubbleR = catR * 0.7
    local bubbleX = cx + catR * 0.6
    local bubbleY = cy - catR * 1.4

    -- 气泡背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, bubbleX - bubbleR, bubbleY - bubbleR, bubbleR * 2, bubbleR * 2, bubbleR * 0.4)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 220))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(200, 80, 60, 180))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)

    -- 小三角 (指向猫咪)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, bubbleX - bubbleR * 0.3, bubbleY + bubbleR)
    nvgLineTo(nvg, bubbleX - bubbleR * 0.5, bubbleY + bubbleR + bubbleR * 0.4)
    nvgLineTo(nvg, bubbleX + bubbleR * 0.1, bubbleY + bubbleR)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 220))
    nvgFill(nvg)

    -- 食物图标
    nvgFontFace(nvg, "sans")
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    local recipe = GameConfig.SUSHI_BY_ID[s.wantRecipeId]
    if recipe then
        nvgFontSize(nvg, bubbleR * 1.2)
        nvgFillColor(nvg, nvgRGBA(60, 50, 40, 240))
        nvgText(nvg, bubbleX, bubbleY, recipe.icon)
    else
        nvgFontSize(nvg, bubbleR * 1.4)
        nvgFillColor(nvg, nvgRGBA(255, 80, 60, 220))
        nvgText(nvg, bubbleX, bubbleY, "!")
    end

    -- 倒计时秒数
    local remaining = math.ceil(math.max(0, s.timer))
    nvgFontSize(nvg, catR * 0.5)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 230))
    nvgText(nvg, cx, cy + catR * 1.3, remaining .. "s")
end

-- ============================================================================
-- 圆环进度条 (序列帧版)
-- ============================================================================

function IndustryScene.drawCircleProgress(nvg, cx, cy, r, progress, fgColor, bgColor)
    -- 根据 progress (0~1) 选择帧索引 (0~8)
    local frameIdx = math.floor(progress * 8 + 0.5)
    frameIdx = math.max(0, math.min(8, frameIdx))

    local img = progressFrames_[frameIdx]
    if img and img > 0 then
        -- 以 (cx, cy) 为中心, 直径 = 2*r 绘制序列帧
        local size = r * 2
        local dx = cx - r
        local dy = cy - r
        local pat = nvgImagePattern(nvg, dx, dy, size, size, 0, img, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, dx, dy, size, size)
        nvgFillPaint(nvg, pat)
        nvgFill(nvg)
    else
        -- 后备: 简单圆形
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, r)
        nvgFillColor(nvg, bgColor)
        nvgFill(nvg)
    end
end

-- ============================================================================
-- (行走猫咪渲染已合并到 renderCats / renderWalkingCat)
-- ============================================================================

-- ============================================================================
-- 收银台
-- ============================================================================

function IndustryScene.updateCashRegDrag()
    if not DEBUG_CASH_REG then return end

    local dpr = graphics:GetDPR()
    local pos = input:GetMousePosition()
    local logX = pos.x / dpr
    local logY = pos.y / dpr

    local regW = dockDrawW_ * 0.30
    local regH = 36
    local regX = dockDrawX_ + dockDrawW_ * cashRegNX_
    local regY = dockDrawY_ + dockDrawH_ * cashRegNY_

    if input:GetMouseButtonPress(MOUSEB_LEFT) then
        if logX >= regX and logX <= regX + regW and logY >= regY and logY <= regY + regH then
            debugDragCash_ = true
            debugCashOffX_ = logX - regX
            debugCashOffY_ = logY - regY
            return
        end
    end

    if debugDragCash_ and input:GetMouseButtonDown(MOUSEB_LEFT) then
        local newX = logX - debugCashOffX_
        local newY = logY - debugCashOffY_
        cashRegNX_ = (newX - dockDrawX_) / dockDrawW_
        cashRegNY_ = (newY - dockDrawY_) / dockDrawH_
        return
    elseif debugDragCash_ then
        print("[DEBUG] === 收银台最终位置 ===")
        print(string.format("  cashRegNX_ = %.3f", cashRegNX_))
        print(string.format("  cashRegNY_ = %.3f", cashRegNY_))
        print("[DEBUG] === END ===")
        debugDragCash_ = false
    end
end

function IndustryScene.renderCashRegister(nvg)
    local cashAmount = IndustrySystem:getCashRegisterAmount()

    -- 无金币时不显示
    if cashAmount <= 0 then return end

    local regW = dockDrawW_ * 0.30
    local regH = 36
    local regX = dockDrawX_ + dockDrawW_ * cashRegNX_
    local regY = dockDrawY_ + dockDrawH_ * cashRegNY_
    local triH = 6
    local cornerR = regH * 0.3

    local bounceOffset = math.sin(cashBounce_ * math.pi) * 4
    local drawY = regY - bounceOffset

    -- 气泡底框 (白色圆角矩形)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, regX, drawY, regW, regH, cornerR)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 230))
    nvgFill(nvg)

    -- 底部小三角
    local triCX = regX + regW * 0.5
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, triCX - 6, drawY + regH)
    nvgLineTo(nvg, triCX, drawY + regH + triH)
    nvgLineTo(nvg, triCX + 6, drawY + regH)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 230))
    nvgFill(nvg)

    -- 金币图标 + 金额 (上半行, 水平居中)
    local iconSize = regH * 0.48
    local amountText = FormatUtils.formatNumber(cashAmount)
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 13)
    local textW = nvgTextBounds(nvg, 0, 0, amountText)
    local contentW = iconSize + 3 + textW
    local contentX = regX + (regW - contentW) * 0.5
    local rowY = drawY + regH * 0.35

    -- 金币图标
    if imgCoin_ and imgCoin_ > 0 then
        local iconY = rowY - iconSize * 0.5
        local pat = nvgImagePattern(nvg, contentX, iconY, iconSize, iconSize, 0, imgCoin_, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, contentX, iconY, iconSize, iconSize)
        nvgFillPaint(nvg, pat)
        nvgFill(nvg)
    end

    -- 金额文字
    nvgFillColor(nvg, nvgRGBA(80, 60, 30, 255))
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgText(nvg, contentX + iconSize + 3, rowY, amountText)

    -- 点击收取 (下半行)
    nvgFontSize(nvg, 9)
    nvgFillColor(nvg, nvgRGBA(140, 120, 80, 200))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(nvg, regX + regW * 0.5, drawY + regH * 0.75, "点击收取")

    table.insert(clickRects_, {
        x = regX, y = drawY, w = regW, h = regH + triH,
        action = "collect_cash",
    })

    -- ── 调试: 绿色边框 + 顶部坐标 ──
    if DEBUG_CASH_REG then
        nvgBeginPath(nvg)
        nvgRect(nvg, regX, drawY, regW, regH + triH)
        nvgStrokeColor(nvg, debugDragCash_
            and nvgRGBA(255, 255, 0, 255)
            or nvgRGBA(0, 255, 0, 220))
        nvgStrokeWidth(nvg, 2)
        nvgStroke(nvg)

        local screenW = graphics:GetWidth() / graphics:GetDPR()
        local panelH = 22
        nvgBeginPath(nvg)
        nvgRect(nvg, 0, 0, screenW, panelH)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 210))
        nvgFill(nvg)

        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 10)
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(0, 255, 100, 255))
        nvgText(nvg, 4, panelH * 0.5,
            string.format(">> 收银台  NX=%.3f  NY=%.3f  px=(%.0f, %.0f)  拖动绿框调整",
                cashRegNX_, cashRegNY_, regX, drawY))
    end
end

-- ============================================================================
-- 出海按钮 - 拖拽调试
-- ============================================================================

function IndustryScene.updateGoBtnDrag()
    if not DEBUG_GO_BTN then return end

    local dpr = graphics:GetDPR()
    local pos = input:GetMousePosition()
    local logX = pos.x / dpr
    local logY = pos.y / dpr

    local btnSize = 58
    local btnX = dockDrawX_ + dockDrawW_ * goBtnNX_ - btnSize * 0.5
    local btnY = dockDrawY_ + dockDrawH_ * goBtnNY_ - btnSize * 0.5

    if input:GetMouseButtonPress(MOUSEB_LEFT) then
        if logX >= btnX and logX <= btnX + btnSize and logY >= btnY and logY <= btnY + btnSize then
            debugDragGoBtn_ = true
            debugGoBtnOffX_ = logX - btnX
            debugGoBtnOffY_ = logY - btnY
            return
        end
    end

    if debugDragGoBtn_ and input:GetMouseButtonDown(MOUSEB_LEFT) then
        local newX = logX - debugGoBtnOffX_ + btnSize * 0.5
        local newY = logY - debugGoBtnOffY_ + btnSize * 0.5
        goBtnNX_ = (newX - dockDrawX_) / dockDrawW_
        goBtnNY_ = (newY - dockDrawY_) / dockDrawH_
        return
    elseif debugDragGoBtn_ then
        print("[DEBUG] === 出海按钮最终位置 ===")
        print(string.format("  goBtnNX_ = %.3f", goBtnNX_))
        print(string.format("  goBtnNY_ = %.3f", goBtnNY_))
        print("[DEBUG] === END ===")
        debugDragGoBtn_ = false
    end
end

-- ============================================================================
-- 出海按钮
-- ============================================================================

function IndustryScene.renderGoFishingBtn(nvg, x, y, w, h)
    -- 3 个按钮横排: 养殖 | 鱼缸 | 出海, 右下角排列
    local btnSize = 58
    local margin = 12
    local gap = 8
    local btnCount = 5
    local totalW = btnSize * btnCount + gap * (btnCount - 1)

    local startX = x + w - totalW - margin
    local btnY = y + h - btnSize - margin

    -- 按钮定义: {icon图片, fallback emoji, 标签, action}
    local buttons = {
        { img = imgCodex_,     fallback = "codex", label = "图鉴", action = "go_codex" },
        { img = imgResearch_,  fallback = "research", label = "研发", action = "go_research" },
        { img = imgBreeding_,  fallback = "egg", label = "养殖", action = "go_breeding" },
        { img = imgAquarium_,  fallback = "aquarium", label = "鱼缸", action = "go_aquarium" },
        { img = imgAnchor_,    fallback = "anchor", label = "出海", action = "go_fishing" },
    }

    for i, btn in ipairs(buttons) do
        local btnX = startX + (i - 1) * (btnSize + gap)

        -- 1) 底框贴图 (button_square_depth_line.png, 1:1 不拉伸)
        if imgBtnSquare_ and imgBtnSquare_ > 0 then
            local pat = nvgImagePattern(nvg, btnX, btnY, btnSize, btnSize, 0, imgBtnSquare_, 0.92)
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, btnX, btnY, btnSize, btnSize, 5)
            nvgFillPaint(nvg, pat)
            nvgFill(nvg)
        else
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, btnX, btnY, btnSize, btnSize, 5)
            nvgFillColor(nvg, nvgRGBA(220, 220, 230, 200))
            nvgFill(nvg)
        end

        -- 2) 图标 + 文字居中
        local iconSize = 22
        local textH = 12
        local igap = 2
        local totalH = iconSize + igap + textH
        local startY = btnY + (btnSize - totalH) * 0.5 - 3
        local cx = btnX + btnSize * 0.5

        local iconX = cx - iconSize * 0.5
        local iconY = startY
        if btn.img and btn.img > 0 then
            local pat = nvgImagePattern(nvg, iconX, iconY, iconSize, iconSize, 0, btn.img, 1.0)
            nvgBeginPath(nvg)
            nvgRect(nvg, iconX, iconY, iconSize, iconSize)
            nvgFillPaint(nvg, pat)
            nvgFill(nvg)
        else
            nvgFontFace(nvg, "sans")
            nvgFontSize(nvg, 18)
            nvgFillColor(nvg, nvgRGBA(80, 80, 100, 220))
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgText(nvg, cx, iconY, btn.fallback)
        end

        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 12)
        nvgFillColor(nvg, nvgRGBA(60, 60, 80, 220))
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgText(nvg, cx, iconY + iconSize + igap, btn.label)

        table.insert(clickRects_, {
            x = btnX, y = btnY, w = btnSize, h = btnSize,
            action = btn.action,
        })
    end

    -- ── 调试: 绿色边框 + 顶部坐标 ──
    if DEBUG_GO_BTN then
        -- 出海按钮(最后一个)的位置
        local debugBtnX = startX + (btnCount - 1) * (btnSize + gap)
        nvgBeginPath(nvg)
        nvgRect(nvg, debugBtnX, btnY, btnSize, btnSize)
        nvgStrokeColor(nvg, debugDragGoBtn_
            and nvgRGBA(255, 255, 0, 255)
            or nvgRGBA(0, 255, 0, 220))
        nvgStrokeWidth(nvg, 2)
        nvgStroke(nvg)

        -- 顶部信息条
        local screenW = graphics:GetWidth() / graphics:GetDPR()
        local panelH = 22
        nvgBeginPath(nvg)
        nvgRect(nvg, 0, 0, screenW, panelH)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 210))
        nvgFill(nvg)

        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 10)
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(0, 255, 100, 255))
        nvgText(nvg, 4, panelH * 0.5,
            string.format(">> 出海按钮  NX=%.3f  NY=%.3f  px=(%.0f, %.0f)  拖动绿框调整位置",
                goBtnNX_, goBtnNY_, debugBtnX, btnY))
    end
end

-- ============================================================================
-- 九宫格绘制工具
-- ============================================================================

--- 绘制一个九宫格切片
local function draw9Patch(nvg, handle, imgW, imgH,
                          srcX, srcY, srcW, srcH,
                          dstX, dstY, dstW, dstH, opacity)
    if dstW <= 0 or dstH <= 0 or srcW <= 0 or srcH <= 0 then return end
    local scaleX = dstW / srcW
    local scaleY = dstH / srcH
    local patX = dstX - srcX * scaleX
    local patY = dstY - srcY * scaleY
    local patW = imgW * scaleX
    local patH = imgH * scaleY
    local pat = nvgImagePattern(nvg, patX, patY, patW, patH, 0, handle, opacity)
    nvgBeginPath(nvg)
    nvgRect(nvg, dstX, dstY, dstW, dstH)
    nvgFillPaint(nvg, pat)
    nvgFill(nvg)
end

--- 九宫格绘制：将图片按 border 切成 9 块拉伸
local function drawNineSlice(nvg, handle, sx, sy, sw, sh, border, opacity)
    local imgW, imgH = nvgImageSize(nvg, handle)
    if imgW <= 0 or imgH <= 0 then return end
    local b = math.min(border, math.floor(imgW / 2), math.floor(imgH / 2))
    if b <= 0 then b = 1 end
    local dbX = math.min(b, math.floor(sw / 2))
    local dbY = math.min(b, math.floor(sh / 2))
    local srcMidW = imgW - b * 2
    local srcMidH = imgH - b * 2
    -- 用整像素坐标避免拼接缝隙
    local x0 = math.floor(sx)
    local y0 = math.floor(sy)
    local x1 = math.floor(sx + dbX)
    local y1 = math.floor(sy + dbY)
    local x2 = math.floor(sx + sw - dbX)
    local y2 = math.floor(sy + sh - dbY)
    local x3 = math.floor(sx + sw)
    local y3 = math.floor(sy + sh)
    -- 四角
    draw9Patch(nvg, handle, imgW, imgH, 0,        0,        b,       b,       x0, y0, x1-x0, y1-y0, opacity)
    draw9Patch(nvg, handle, imgW, imgH, imgW-b,   0,        b,       b,       x2, y0, x3-x2, y1-y0, opacity)
    draw9Patch(nvg, handle, imgW, imgH, 0,        imgH-b,   b,       b,       x0, y2, x1-x0, y3-y2, opacity)
    draw9Patch(nvg, handle, imgW, imgH, imgW-b,   imgH-b,   b,       b,       x2, y2, x3-x2, y3-y2, opacity)
    -- 四边
    draw9Patch(nvg, handle, imgW, imgH, b,        0,        srcMidW, b,       x1, y0, x2-x1, y1-y0, opacity)
    draw9Patch(nvg, handle, imgW, imgH, b,        imgH-b,   srcMidW, b,       x1, y2, x2-x1, y3-y2, opacity)
    draw9Patch(nvg, handle, imgW, imgH, 0,        b,        b,       srcMidH, x0, y1, x1-x0, y2-y1, opacity)
    draw9Patch(nvg, handle, imgW, imgH, imgW-b,   b,        b,       srcMidH, x2, y1, x3-x2, y2-y1, opacity)
    -- 中心
    draw9Patch(nvg, handle, imgW, imgH, b,        b,        srcMidW, srcMidH, x1, y1, x2-x1, y2-y1, opacity)
end

-- ============================================================================
-- 出海面板 (覆盖层)
-- ============================================================================

function IndustryScene.renderGoFishingPanel(nvg, x, y, w, h)
    -- 半透明遮罩
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 120))
    nvgFill(nvg)

    -- 面板尺寸
    local panelW = math.min(260, w * 0.70)
    local panelH = math.min(420, h * 0.78)
    local px = x + (w - panelW) * 0.5
    local py = y + (h - panelH) * 0.5

    -- 九宫格底框
    if imgPanelBg_ and imgPanelBg_ > 0 then
        drawNineSlice(nvg, imgPanelBg_, px, py, panelW, panelH, 16, 0.95)
    else
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, px, py, panelW, panelH, 10)
        nvgFillColor(nvg, nvgRGBA(240, 235, 225, 245))
        nvgFill(nvg)
    end

    -- NOTE: close_go_fishing backdrop 移至函数末尾注册,
    -- 确保面板内按钮在 clickRects_ 中排在 backdrop 之前,
    -- 这样 for 循环优先匹配面板按钮而非全屏关闭区域.

    local contentX = px + 14
    local contentW = panelW - 28
    local curY = py + 12

    -- ── 标题 ──
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 17)
    nvgFillColor(nvg, nvgRGBA(60, 50, 40, 255))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgText(nvg, px + panelW * 0.5, curY, "出海准备")
    curY = curY + 26

    -- ── 分割线 ──
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, contentX, curY)
    nvgLineTo(nvg, contentX + contentW, curY)
    nvgStrokeColor(nvg, nvgRGBA(180, 170, 150, 100))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    curY = curY + 8

    -- ── 海域选择 ──
    nvgFontSize(nvg, 12)
    nvgFillColor(nvg, nvgRGBA(100, 90, 70, 200))
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgText(nvg, contentX, curY, "选择海域")
    curY = curY + 16

    -- 5 海域：每行排列，小标签
    local zoneItemH = 28
    local zoneGap = 4
    for i, zone in ipairs(ZONE_LIST) do
        local zy = curY + (i - 1) * (zoneItemH + zoneGap)
        local selected = (i == selectedZoneIdx_)
        local unlocked = GameState.unlockedZones[zone.key]
        local cost = EconomySystem.getZoneUnlockCost(zone.key)

        -- 背景
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, contentX, zy, contentW, zoneItemH, 6)
        if selected and unlocked then
            nvgFillColor(nvg, nvgRGBA(70, 140, 200, 55))
        elseif unlocked then
            nvgFillColor(nvg, nvgRGBA(200, 195, 185, 35))
        else
            nvgFillColor(nvg, nvgRGBA(160, 155, 145, 25))
        end
        nvgFill(nvg)

        -- 选中边框
        if selected and unlocked then
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, contentX, zy, contentW, zoneItemH, 6)
            nvgStrokeColor(nvg, nvgRGBA(70, 140, 200, 180))
            nvgStrokeWidth(nvg, 1.5)
            nvgStroke(nvg)
        end

        -- 左侧: 图标 + 名称
        nvgFontSize(nvg, 13)
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, unlocked and nvgRGBA(50, 45, 35, 255) or nvgRGBA(140, 135, 125, 200))
        nvgText(nvg, contentX + 8, zy + zoneItemH * 0.5, zone.icon .. " " .. zone.name)

        -- 右侧: 描述 或 锁定+费用
        nvgFontSize(nvg, 10)
        nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        if unlocked then
            nvgFillColor(nvg, nvgRGBA(120, 110, 95, 160))
            nvgText(nvg, contentX + contentW - 8, zy + zoneItemH * 0.5, zone.desc)
        else
            nvgFillColor(nvg, nvgRGBA(180, 140, 40, 200))
            nvgText(nvg, contentX + contentW - 8, zy + zoneItemH * 0.5, "" .. FormatUtils.formatNumber(cost) .. " 金币")
        end

        -- 点击区域：已解锁选中，未解锁弹确认
        table.insert(clickRects_, {
            x = contentX, y = zy, w = contentW, h = zoneItemH,
            action = unlocked and "select_zone" or "try_unlock_zone",
            data = i,
        })
    end
    curY = curY + #ZONE_LIST * (zoneItemH + zoneGap) + 8

    -- ── 鱼饵选择 ──
    nvgFontSize(nvg, 12)
    nvgFillColor(nvg, nvgRGBA(100, 90, 70, 200))
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgText(nvg, contentX, curY, "选择鱼饵")
    curY = curY + 18

    local baitItemH = 36
    for i, bait in ipairs(BAIT_LIST) do
        local by = curY + (i - 1) * (baitItemH + 6)
        local selected = (i == selectedBaitIdx_)

        -- 背景
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, contentX, by, contentW, baitItemH, 8)
        if selected then
            nvgFillColor(nvg, nvgRGBA(70, 140, 200, 50))
        else
            nvgFillColor(nvg, nvgRGBA(200, 195, 185, 30))
        end
        nvgFill(nvg)

        -- 选中边框
        if selected then
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, contentX, by, contentW, baitItemH, 8)
            nvgStrokeColor(nvg, nvgRGBA(70, 140, 200, 180))
            nvgStrokeWidth(nvg, 1.5)
            nvgStroke(nvg)
        end

        -- 图标
        nvgFontSize(nvg, 16)
        nvgFillColor(nvg, nvgRGBA(50, 45, 35, 255))
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgText(nvg, contentX + 8, by + baitItemH * 0.5, bait.icon)

        -- 名称
        nvgFontSize(nvg, 12)
        nvgFillColor(nvg, nvgRGBA(50, 45, 35, 255))
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgText(nvg, contentX + 30, by + 4, bait.name)

        -- 描述
        nvgFontSize(nvg, 9)
        nvgFillColor(nvg, nvgRGBA(120, 110, 95, 180))
        nvgText(nvg, contentX + 30, by + 20, bait.desc)

        -- 费用 (右侧)
        if bait.cost > 0 then
            nvgFontSize(nvg, 11)
            nvgFillColor(nvg, nvgRGBA(200, 160, 40, 255))
            nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgText(nvg, contentX + contentW - 8, by + baitItemH * 0.5,
                FormatUtils.formatNumber(bait.cost) .. " 金币")
        else
            nvgFontSize(nvg, 10)
            nvgFillColor(nvg, nvgRGBA(100, 170, 80, 220))
            nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgText(nvg, contentX + contentW - 8, by + baitItemH * 0.5, "免费")
        end

        -- 点击区域
        table.insert(clickRects_, {
            x = contentX, y = by, w = contentW, h = baitItemH,
            action = "select_bait", data = i,
        })
    end
    curY = curY + #BAIT_LIST * (baitItemH + 6) + 8

    -- ── 出发按钮 ──
    local goBtnW = 130
    local goBtnH = 34
    local goBtnX = px + (panelW - goBtnW) * 0.5
    local goBtnY = curY

    -- 按钮底色
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, goBtnX, goBtnY, goBtnW, goBtnH, 10)
    nvgFillColor(nvg, nvgRGBA(70, 150, 210, 230))
    nvgFill(nvg)

    -- 按钮文字
    nvgFontSize(nvg, 15)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(nvg, goBtnX + goBtnW * 0.5, goBtnY + goBtnH * 0.5, "⛵ 出发!")

    table.insert(clickRects_, {
        x = goBtnX, y = goBtnY, w = goBtnW, h = goBtnH,
        action = "confirm_go_fishing",
    })

    -- ── 解锁确认弹窗 ──
    if unlockPopup_.open then
        -- 遮罩（在面板之上）
        nvgBeginPath(nvg)
        nvgRect(nvg, px, py, panelW, panelH)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 100))
        nvgFill(nvg)

        local popW = math.min(200, panelW - 20)
        local popH = 110
        local popX = px + (panelW - popW) * 0.5
        local popY = py + (panelH - popH) * 0.5

        -- 弹窗底框 (九宫格)
        if imgPanelBg_ and imgPanelBg_ > 0 then
            drawNineSlice(nvg, imgPanelBg_, popX, popY, popW, popH, 16, 1.0)
        else
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, popX, popY, popW, popH, 8)
            nvgFillColor(nvg, nvgRGBA(250, 245, 235, 250))
            nvgFill(nvg)
        end

        -- 标题
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 13)
        nvgFillColor(nvg, nvgRGBA(60, 50, 40, 255))
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgText(nvg, popX + popW * 0.5, popY + 12, "解锁 " .. unlockPopup_.zoneName .. "？")

        -- 费用显示
        nvgFontSize(nvg, 14)
        local coinColor
        if unlockPopup_.canAfford then
            coinColor = nvgRGBA(200, 160, 40, 255)
        else
            coinColor = nvgRGBA(220, 60, 50, 255)  -- 红色：余额不足
        end
        nvgFillColor(nvg, coinColor)
        nvgText(nvg, popX + popW * 0.5, popY + 32, FormatUtils.formatNumber(unlockPopup_.cost) .. " 金币")

        -- 当前金币
        nvgFontSize(nvg, 10)
        nvgFillColor(nvg, unlockPopup_.canAfford and nvgRGBA(100, 95, 80, 180) or nvgRGBA(220, 60, 50, 180))
        nvgText(nvg, popX + popW * 0.5, popY + 52, "当前: " .. FormatUtils.formatNumber(GameState.coins))

        -- 按钮区
        local btnW2 = 72
        local btnH2 = 28
        local btnGap = 12
        local btnTotalW = btnW2 * 2 + btnGap
        local btnStartX = popX + (popW - btnTotalW) * 0.5
        local btnY2 = popY + popH - btnH2 - 12

        -- 取消按钮
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, btnStartX, btnY2, btnW2, btnH2, 6)
        nvgFillColor(nvg, nvgRGBA(180, 175, 165, 150))
        nvgFill(nvg)
        nvgFontSize(nvg, 12)
        nvgFillColor(nvg, nvgRGBA(80, 70, 60, 255))
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgText(nvg, btnStartX + btnW2 * 0.5, btnY2 + btnH2 * 0.5, "取消")
        table.insert(clickRects_, {
            x = btnStartX, y = btnY2, w = btnW2, h = btnH2,
            action = "cancel_unlock",
        })

        -- 确认按钮
        local confirmX = btnStartX + btnW2 + btnGap
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, confirmX, btnY2, btnW2, btnH2, 6)
        if unlockPopup_.canAfford then
            nvgFillColor(nvg, nvgRGBA(70, 150, 210, 220))
        else
            nvgFillColor(nvg, nvgRGBA(160, 155, 145, 120))
        end
        nvgFill(nvg)
        nvgFontSize(nvg, 12)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgText(nvg, confirmX + btnW2 * 0.5, btnY2 + btnH2 * 0.5, unlockPopup_.canAfford and "确认" or "不足")
        if unlockPopup_.canAfford then
            table.insert(clickRects_, {
                x = confirmX, y = btnY2, w = btnW2, h = btnH2,
                action = "confirm_unlock",
            })
        end
    end

    -- 面板背景吸收点击（防止穿透到 close_go_fishing）
    table.insert(clickRects_, { x = px, y = py, w = panelW, h = panelH, action = "panel_bg" })
    -- 关闭区域 (面板外点击关闭) — 必须最后注册,
    -- 这样 clickRects_ 遍历时面板内按钮优先匹配
    table.insert(clickRects_, { x = x, y = y, w = w, h = h, action = "close_go_fishing" })
end

-- ============================================================================
-- 菜单面板 (覆盖层)
-- ============================================================================

function IndustryScene.renderMenuPanel(nvg, x, y, w, h)
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 120))
    nvgFill(nvg)

    local panelW = w * 0.88
    local panelH = h * 0.7
    local panelX = x + (w - panelW) * 0.5
    local panelY = y + (h - panelH) * 0.4

    -- 九宫格底框
    if imgPanelBg_ and imgPanelBg_ > 0 then
        drawNineSlice(nvg, imgPanelBg_, panelX, panelY, panelW, panelH, 16, 0.95)
    else
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, panelX, panelY, panelW, panelH, 12)
        nvgFillColor(nvg, nvgRGBA(50, 40, 30, 240))
        nvgFill(nvg)
    end

    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 20)
    nvgFillColor(nvg, nvgRGBA(60, 50, 40, 250))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgText(nvg, panelX + panelW * 0.5, panelY + 14, "菜单")

    local closeSize = 28
    local closeX = panelX + panelW - closeSize - 8
    local closeY = panelY + 8
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, closeX, closeY, closeSize, closeSize, 4)
    nvgFillColor(nvg, nvgRGBA(200, 80, 60, 200))
    nvgFill(nvg)
    nvgFontSize(nvg, 16)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 240))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(nvg, closeX + closeSize * 0.5, closeY + closeSize * 0.5, "X")

    table.insert(clickRects_, {
        x = closeX, y = closeY, w = closeSize, h = closeSize,
        action = "close_menu",
    })

    -- ---- 待处理区（合成队列）----
    local queueY = panelY + 50
    local cardMargin = 8
    queueY = IndustryScene.renderSynthesisQueue(nvg, panelX + cardMargin, queueY,
        panelW - cardMargin * 2)

    -- ---- 配方卡片 ----
    local cardY = queueY + 8
    for _, recipe in ipairs(GameConfig.SUSHI) do
        IndustryScene.renderRecipeCard(nvg, panelX + cardMargin, cardY,
            panelW - cardMargin * 2, recipe)
        cardY = cardY + 96
    end

    -- ---- 升级弹窗 ----
    if upgradePopup_.open then
        IndustryScene.renderUpgradePopup(nvg, x, y, w, h)
    end
end

-- ============================================================================
-- 合成队列（待处理区）渲染
-- ============================================================================

--- 渲染合成队列区域，返回区域底部 Y 坐标
---@param nvg userdata
---@param ax number  区域左边
---@param ay number  区域顶边
---@param aw number  区域宽度
---@return number bottomY
function IndustryScene.renderSynthesisQueue(nvg, ax, ay, aw)
    local maxSlots = GameConfig.INDUSTRY.QUEUE_MAX_SLOTS
    local unlocked = GameState.unlockedSynthesisSlots
    local queue    = GameState.synthesisQueue

    -- 区域标题
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 13)
    nvgFillColor(nvg, nvgRGBA(80, 70, 50, 220))
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    local usedCount = IndustrySystem:getQueueUsedCount()
    nvgText(nvg, ax, ay, string.format("待处理区 (%d/%d)", usedCount, unlocked))

    -- 解锁按钮（标题右侧）
    if unlocked < maxSlots then
        local nextCost = GameConfig.INDUSTRY.QUEUE_SLOT_UNLOCK_COST[unlocked + 1] or 99999
        local canAfford = GameState.coins >= nextCost
        local ubtnW = 72
        local ubtnH = 20
        local ubtnX = ax + aw - ubtnW
        local ubtnY = ay - 2

        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, ubtnX, ubtnY, ubtnW, ubtnH, 4)
        if canAfford then
            nvgFillColor(nvg, nvgRGBA(70, 160, 90, 220))
        else
            nvgFillColor(nvg, nvgRGBA(160, 155, 145, 140))
        end
        nvgFill(nvg)

        nvgFontSize(nvg, 10)
        nvgFillColor(nvg, canAfford and nvgRGBA(255, 255, 255, 240) or nvgRGBA(200, 195, 185, 180))
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        if nextCost > 0 then
            nvgText(nvg, ubtnX + ubtnW * 0.5, ubtnY + ubtnH * 0.5,
                "扩容 " .. FormatUtils.formatNumber(nextCost) .. " 金币")
        else
            nvgText(nvg, ubtnX + ubtnW * 0.5, ubtnY + ubtnH * 0.5, "扩容 (免费)")
        end

        table.insert(clickRects_, {
            x = ubtnX, y = ubtnY, w = ubtnW, h = ubtnH,
            action = "unlock_synthesis_slot",
        })
    end

    -- 槽位网格
    local slotSize = 48
    local slotGap = 6
    local slotsPerRow = math.floor((aw + slotGap) / (slotSize + slotGap))
    if slotsPerRow < 1 then slotsPerRow = 1 end
    local gridY = ay + 20

    for i = 1, maxSlots do
        local col = ((i - 1) % slotsPerRow)
        local row = math.floor((i - 1) / slotsPerRow)
        local sx = ax + col * (slotSize + slotGap)
        local sy = gridY + row * (slotSize + slotGap + 14)

        if i > unlocked then
            -- 锁定槽位
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, sx, sy, slotSize, slotSize, 6)
            nvgFillColor(nvg, nvgRGBA(100, 95, 85, 60))
            nvgFill(nvg)
            nvgStrokeColor(nvg, nvgRGBA(140, 130, 120, 80))
            nvgStrokeWidth(nvg, 1)
            nvgStroke(nvg)

            nvgFontSize(nvg, 18)
            nvgFillColor(nvg, nvgRGBA(140, 130, 115, 120))
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgText(nvg, sx + slotSize * 0.5, sy + slotSize * 0.5, "锁定")
        elseif queue[i] then
            -- 合成中
            local slot = queue[i]
            local recipe = GameConfig.SUSHI_BY_ID[slot.recipeId]
            local progress = 1.0 - (slot.timer / slot.totalTime)
            progress = math.max(0, math.min(1, progress))

            -- 槽位背景
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, sx, sy, slotSize, slotSize, 6)
            nvgFillColor(nvg, nvgRGBA(255, 240, 210, 180))
            nvgFill(nvg)
            nvgStrokeColor(nvg, nvgRGBA(220, 180, 80, 180))
            nvgStrokeWidth(nvg, 1.5)
            nvgStroke(nvg)

            -- 配方图标
            if recipe then
                nvgFontSize(nvg, 20)
                nvgFillColor(nvg, nvgRGBA(0, 0, 0, 220))
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgText(nvg, sx + slotSize * 0.5, sy + slotSize * 0.4, recipe.icon)
            end

            -- 进度条（序列帧）
            local progR = 10
            IndustryScene.drawCircleProgress(nvg,
                sx + slotSize - progR - 2,
                sy + slotSize - progR - 2,
                progR, progress,
                nvgRGBA(220, 160, 40, 255),
                nvgRGBA(80, 70, 60, 120))

            -- 剩余时间文字（槽位下方）
            local remaining = math.ceil(math.max(0, slot.timer))
            nvgFontSize(nvg, 9)
            nvgFillColor(nvg, nvgRGBA(160, 120, 30, 220))
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgText(nvg, sx + slotSize * 0.5, sy + slotSize + 1, remaining .. "s")
        else
            -- ⬜ 空闲槽位
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, sx, sy, slotSize, slotSize, 6)
            nvgFillColor(nvg, nvgRGBA(230, 225, 215, 100))
            nvgFill(nvg)
            nvgStrokeColor(nvg, nvgRGBA(180, 170, 155, 100))
            nvgStrokeWidth(nvg, 1)
            nvgStroke(nvg)

            nvgFontSize(nvg, 10)
            nvgFillColor(nvg, nvgRGBA(160, 150, 135, 120))
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgText(nvg, sx + slotSize * 0.5, sy + slotSize * 0.5, "空")
        end
    end

    -- 计算区域底部
    local totalRows = math.ceil(maxSlots / slotsPerRow)
    local bottomY = gridY + totalRows * (slotSize + slotGap + 14)
    return bottomY
end

-- ============================================================================
-- 菜谱升级弹窗
-- ============================================================================

function IndustryScene.renderUpgradePopup(nvg, x, y, w, h)
    -- 半透明遮罩
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 140))
    nvgFill(nvg)

    -- 弹窗高度随鱼材料行数自适应
    local fishCount = #upgradePopup_.fishReqs
    local popW = math.min(240, w * 0.65)
    local popH = 200 + fishCount * 18
    local popX = math.floor(x + (w - popW) * 0.5)
    local popY = math.floor(y + (h - popH) * 0.4)

    -- 九宫格底板
    if imgPanelBg_ and imgPanelBg_ > 0 then
        drawNineSlice(nvg, imgPanelBg_, popX, popY, popW, popH, 16, 1.0)
    else
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, popX, popY, popW, popH, 12)
        nvgFillColor(nvg, nvgRGBA(245, 240, 230, 245))
        nvgFill(nvg)
    end

    local pad = 14
    local centerX = popX + popW * 0.5
    local ty = popY + pad

    -- 标题
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 16)
    nvgFillColor(nvg, nvgRGBA(50, 40, 25, 240))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgText(nvg, centerX, ty, "升级 " .. upgradePopup_.recipeName)
    ty = ty + 28

    -- 等级变化
    nvgFontSize(nvg, 13)
    nvgFillColor(nvg, nvgRGBA(80, 70, 50, 220))
    local lvlFrom = upgradePopup_.currentLevel
    local lvlTo = lvlFrom + 1
    nvgText(nvg, centerX, ty, string.format("等级: Lv.%d → Lv.%d", lvlFrom, lvlTo))
    ty = ty + 22

    -- 售价变化
    nvgFontSize(nvg, 13)
    nvgFillColor(nvg, nvgRGBA(160, 120, 20, 230))
    nvgText(nvg, centerX, ty, string.format("售价: %s → %s 金币",
        FormatUtils.formatNumber(upgradePopup_.curPrice),
        FormatUtils.formatNumber(upgradePopup_.nextPrice)))
    ty = ty + 24

    -- ---- 消耗区域 ----
    -- 分隔线
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, popX + pad, math.floor(ty))
    nvgLineTo(nvg, popX + popW - pad, math.floor(ty))
    nvgStrokeColor(nvg, nvgRGBA(180, 170, 150, 100))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    ty = ty + 8

    nvgFontSize(nvg, 12)
    nvgFillColor(nvg, nvgRGBA(100, 90, 70, 200))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgText(nvg, centerX, ty, "升级消耗")
    ty = ty + 18

    -- 金币费用
    nvgFontSize(nvg, 13)
    local coinOk = GameState.coins >= upgradePopup_.cost
    nvgFillColor(nvg, coinOk and nvgRGBA(80, 70, 50, 220) or nvgRGBA(220, 50, 30, 240))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgText(nvg, centerX, ty, string.format("金币 %s / %s",
        FormatUtils.formatNumber(upgradePopup_.cost),
        FormatUtils.formatNumber(GameState.coins)))
    ty = ty + 18

    -- 鱼材料列表
    for _, req in ipairs(upgradePopup_.fishReqs) do
        nvgFontSize(nvg, 13)
        local enough = (req.have or 0) >= req.count
        nvgFillColor(nvg, enough and nvgRGBA(60, 100, 60, 230) or nvgRGBA(220, 50, 30, 240))
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgText(nvg, centerX, ty, string.format("%s %s ×%d / %d",
            req.icon, req.displayName, req.count, req.have or 0))
        ty = ty + 18
    end

    -- 不足提示
    if not upgradePopup_.canAfford then
        ty = ty + 2
        nvgFontSize(nvg, 11)
        nvgFillColor(nvg, nvgRGBA(220, 50, 30, 200))
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        if not coinOk and not upgradePopup_.fishEnough then
            nvgText(nvg, centerX, ty, "(金币和材料不足)")
        elseif not coinOk then
            nvgText(nvg, centerX, ty, "(金币不足)")
        else
            nvgText(nvg, centerX, ty, "(材料不足)")
        end
    end

    -- 按钮
    local btnW = 80
    local btnH = 30
    local btnY = popY + popH - btnH - pad
    local gap = 16

    -- 取消按钮
    local cancelX = math.floor(centerX - gap / 2 - btnW)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, cancelX, btnY, btnW, btnH, 6)
    nvgFillColor(nvg, nvgRGBA(190, 180, 165, 200))
    nvgFill(nvg)
    nvgFontSize(nvg, 13)
    nvgFillColor(nvg, nvgRGBA(80, 70, 55, 230))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(nvg, cancelX + btnW * 0.5, btnY + btnH * 0.5, "取消")
    table.insert(clickRects_, {
        x = cancelX, y = btnY, w = btnW, h = btnH,
        action = "cancel_upgrade",
    })

    -- 升级按钮
    local confirmX = math.floor(centerX + gap / 2)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, confirmX, btnY, btnW, btnH, 6)
    if upgradePopup_.canAfford then
        local gp = nvgLinearGradient(nvg, confirmX, btnY, confirmX, btnY + btnH,
            nvgRGBA(100, 200, 120, 240), nvgRGBA(60, 160, 80, 240))
        nvgFillPaint(nvg, gp)
    else
        nvgFillColor(nvg, nvgRGBA(180, 170, 155, 160))
    end
    nvgFill(nvg)
    nvgFontSize(nvg, 13)
    nvgFillColor(nvg, upgradePopup_.canAfford
        and nvgRGBA(255, 255, 255, 240)
        or nvgRGBA(140, 135, 125, 160))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(nvg, confirmX + btnW * 0.5, btnY + btnH * 0.5, "升级")
    if upgradePopup_.canAfford then
        table.insert(clickRects_, {
            x = confirmX, y = btnY, w = btnW, h = btnH,
            action = "confirm_upgrade",
        })
    end
end

-- ============================================================================
-- 配方卡片（九宫格底图 + 等级/升级）
-- ============================================================================

function IndustryScene.renderRecipeCard(nvg, cx, cy, cw, recipe)
    local cardH = 90
    local canMake = GameState:hasIngredientsForRecipe(recipe)
    local isZoneUnlocked = GameState.unlockedZones[recipe.zone]
    local level = GameState:getRecipeLevel(recipe.id)
    local isMaxLevel = level >= GameConfig.RECIPE_MAX_LEVEL

    -- 九宫格卡片底图
    if imgCardBg_ and imgCardBg_ > 0 then
        drawNineSlice(nvg, imgCardBg_, cx, cy, cw, cardH, 10, isZoneUnlocked and 0.95 or 0.5)
    else
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cx, cy, cw, cardH, 8)
        nvgFillColor(nvg, nvgRGBA(245, 240, 230, 200))
        nvgFill(nvg)
    end

    local pad = 8
    local textX = cx + pad
    local textY = cy + pad

    -- ---- 未解锁 ----
    if not isZoneUnlocked then
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 14)
        nvgFillColor(nvg, nvgRGBA(140, 130, 115, 180))
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgText(nvg, textX, textY, "锁定 " .. recipe.displayName)
        nvgFontSize(nvg, 11)
        nvgFillColor(nvg, nvgRGBA(160, 140, 110, 160))
        nvgText(nvg, textX, textY + 20,
            "需要解锁" .. (GameConfig.ZONE_DISPLAY[recipe.zone] or recipe.zone))
        return cardH
    end

    -- ---- 第一行: 名称 + 等级 ----
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 14)
    nvgFillColor(nvg, nvgRGBA(50, 40, 25, 240))
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgText(nvg, textX, textY, recipe.icon .. " " .. recipe.displayName)

    -- 等级标签
    local lvlText = isMaxLevel and "MAX" or ("Lv." .. level)
    local lvlColor = isMaxLevel and nvgRGBA(220, 160, 30, 240) or nvgRGBA(100, 140, 60, 230)
    local nameW = nvgTextBounds(nvg, 0, 0, recipe.icon .. " " .. recipe.displayName)
    nvgFontSize(nvg, 11)
    nvgFillColor(nvg, lvlColor)
    nvgText(nvg, textX + nameW + 6, textY + 2, lvlText)

    -- ---- 第一行右侧: 售价 + 库存 ----
    local sellPrice = IndustrySystem:getSellPrice(recipe.id)
    local rightX = cx + cw - pad
    nvgFontSize(nvg, 12)
    nvgFillColor(nvg, nvgRGBA(160, 120, 20, 230))
    nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    nvgText(nvg, rightX, textY, FormatUtils.formatNumber(sellPrice) .. " 金币")

    local stock = GameState:getFoodCount(recipe.id)
    nvgFontSize(nvg, 10)
    nvgFillColor(nvg, nvgRGBA(80, 110, 150, 210))
    nvgText(nvg, rightX, textY + 15, "库存:" .. stock)

    -- ---- 第二行: 消耗材料 ----
    local matX = textX
    local matY = cy + 32
    nvgFontSize(nvg, 11)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(100, 90, 70, 180))
    nvgText(nvg, matX, matY, "消耗:")
    matX = matX + nvgTextBounds(nvg, 0, 0, "消耗:") + 4

    for _, ing in ipairs(recipe.ingredients) do
        local fish = GameConfig.FISH_BY_ID[ing.fishId]
        local have = GameState:getFishCount(ing.fishId)
        local need = ing.count
        local enough = have >= need

        local iconSize = 16
        local fishImg = fishIcons_[fish.name]
        if fishImg and fishImg > 0 then
            local pat = nvgImagePattern(nvg, matX, matY, iconSize, iconSize, 0, fishImg, enough and 1.0 or 0.4)
            nvgBeginPath(nvg)
            nvgRect(nvg, matX, matY, iconSize, iconSize)
            nvgFillPaint(nvg, pat)
            nvgFill(nvg)
            matX = matX + iconSize + 2
        end

        nvgFontSize(nvg, 11)
        nvgFillColor(nvg, enough and nvgRGBA(60, 150, 50, 230) or nvgRGBA(220, 60, 40, 220))
        local matText = string.format("%d/%d", have, need)
        nvgText(nvg, matX, matY + 2, matText)
        matX = matX + nvgTextBounds(nvg, 0, 0, matText) + 8
    end

    -- ---- 第三行: 合成按钮 + 升级按钮 ----
    local btnH = 24
    local btnY = cy + cardH - btnH - pad

    -- 升级按钮（右侧）
    local upgW = 48
    local upgX = cx + cw - pad - upgW
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, upgX, btnY, upgW, btnH, 5)
    if isMaxLevel then
        nvgFillColor(nvg, nvgRGBA(180, 170, 155, 120))
    else
        local upgPaint = nvgLinearGradient(nvg, upgX, btnY, upgX, btnY + btnH,
            nvgRGBA(100, 200, 120, 230), nvgRGBA(60, 160, 80, 230))
        nvgFillPaint(nvg, upgPaint)
    end
    nvgFill(nvg)
    nvgFontSize(nvg, 11)
    nvgFillColor(nvg, isMaxLevel and nvgRGBA(140, 135, 125, 160) or nvgRGBA(255, 255, 255, 240))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(nvg, upgX + upgW * 0.5, btnY + btnH * 0.5, isMaxLevel and "MAX" or "升级")

    if not isMaxLevel then
        table.insert(clickRects_, {
            x = upgX, y = btnY, w = upgW, h = btnH,
            action = "open_upgrade", data = recipe.id,
        })
    end

    -- 合成按钮（升级按钮左侧）
    local cookW = 48
    local cookX = upgX - cookW - 6
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, cookX, btnY, cookW, btnH, 5)
    if canMake then
        local btnPaint = nvgLinearGradient(nvg, cookX, btnY, cookX, btnY + btnH,
            nvgRGBA(255, 180, 60, 240), nvgRGBA(230, 140, 30, 240))
        nvgFillPaint(nvg, btnPaint)
    else
        nvgFillColor(nvg, nvgRGBA(200, 190, 175, 140))
    end
    nvgFill(nvg)
    nvgFontSize(nvg, 11)
    nvgFillColor(nvg, canMake and nvgRGBA(50, 30, 10, 240) or nvgRGBA(150, 140, 125, 160))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(nvg, cookX + cookW * 0.5, btnY + btnH * 0.5, "合成")

    if canMake then
        table.insert(clickRects_, {
            x = cookX, y = btnY, w = cookW, h = btnH,
            action = "cook", data = recipe.id,
        })
    end

    return cardH
end

-- ============================================================================
-- Toast
-- ============================================================================

function IndustryScene.renderToast(nvg, x, y, w, h)
    if not toastMsg_ then return end
    local alpha = math.min(1.0, toastTimer_ * 2) * 255

    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 14)
    local tw = nvgTextBounds(nvg, 0, 0, toastMsg_)
    local toastW = tw + 40
    local toastH = 36
    local tx = x + (w - toastW) * 0.5
    local ty = y + h * 0.3

    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, tx, ty, toastW, toastH, 8)
    nvgFillColor(nvg, nvgRGBA(30, 25, 20, math.floor(alpha * 0.9)))
    nvgFill(nvg)

    nvgFillColor(nvg, nvgRGBA(255, 230, 180, math.floor(alpha)))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(nvg, tx + toastW * 0.5, ty + toastH * 0.5, toastMsg_)
end

-- ============================================================================
-- 调试框渲染
-- ============================================================================

function IndustryScene.renderDebugOverlay(nvg)
    local tableCenters = IndustrySystem:getTableCenters()
    local TABLE_VISUAL_ASPECT = 1.3
    local tw = dockDrawW_ * TABLE_W_RATIO
    local th = tw / TABLE_VISUAL_ASPECT

    -- 统一包围框 (仅整体拖拽开启时绘制)
    local bx, by, bw, bh = IndustryScene.getDebugBoundingBox()

    if DEBUG_DRAG_TABLE_BOX then
        nvgBeginPath(nvg)
        nvgRect(nvg, bx, by, bw, bh)
        nvgFillColor(nvg, debugDragging_
            and nvgRGBA(255, 255, 0, 30)
            or nvgRGBA(0, 255, 0, 20))
        nvgFill(nvg)

        nvgBeginPath(nvg)
        nvgRect(nvg, bx, by, bw, bh)
        nvgStrokeColor(nvg, debugDragging_
            and nvgRGBA(255, 255, 0, 255)
            or nvgRGBA(0, 255, 0, 220))
        nvgStrokeWidth(nvg, debugDragging_ and 3 or 2)
        nvgStroke(nvg)
    end

    -- 每张桌子的中心十字线 + 座位标记
    local seatDX, seatDY = IndustrySystem:getSeatOffsets()
    for i = 1, IndustrySystem:getTableCount() do
        local tc = tableCenters[i]
        local cx = dockDrawX_ + dockDrawW_ * tc.x
        local cy = dockDrawY_ + dockDrawH_ * tc.y

        -- 桌子中心十字
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx - 6, cy)
        nvgLineTo(nvg, cx + 6, cy)
        nvgMoveTo(nvg, cx, cy - 6)
        nvgLineTo(nvg, cx, cy + 6)
        nvgStrokeColor(nvg, nvgRGBA(255, 60, 60, 200))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)

        -- 座位标记 (圆点 + 连线)
        for seatIn = 1, 2 do
            local sx = dockDrawX_ + dockDrawW_ * (tc.x + seatDX[seatIn])
            local sy = dockDrawY_ + dockDrawH_ * (tc.y + seatDY)
            local isDragThis = (debugDragSeat_ == seatIn and i == 1)
            local seatR = isDragThis and 14 or 10

            -- 连线: 桌子中心 → 座位
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, cx, cy)
            nvgLineTo(nvg, sx, sy)
            nvgStrokeColor(nvg, nvgRGBA(255, 180, 0, 120))
            nvgStrokeWidth(nvg, 1)
            nvgStroke(nvg)

            -- 座位圆点
            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, sy, seatR)
            nvgFillColor(nvg, isDragThis
                and nvgRGBA(255, 255, 0, 220)
                or nvgRGBA(0, 180, 255, 200))
            nvgFill(nvg)
            nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, 200))
            nvgStrokeWidth(nvg, 1.5)
            nvgStroke(nvg)

            -- 座位标号 (仅第1张桌子标注, 其他桌子共享偏移)
            if i == 1 then
                nvgFontFace(nvg, "sans")
                nvgFontSize(nvg, 9)
                nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgText(nvg, sx, sy, seatIn == 1 and "L" or "R")
            end
        end
    end

    -- 调试信息面板 (屏幕最顶部, 不遮挡桌子)
    local screenW = graphics:GetWidth() / graphics:GetDPR()
    local panelW = screenW
    local panelX = 0
    local panelY = 0
    local lineH = 13
    local lineCount = 4 + IndustrySystem:getTableCount()  -- 基础4行 + 每张桌子1行
    local infoH = lineCount * lineH + 8

    nvgBeginPath(nvg)
    nvgRect(nvg, panelX, panelY, panelW, infoH)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 210))
    nvgFill(nvg)

    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 10)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(0, 255, 100, 255))

    local ly = panelY + 4
    -- 提示
    nvgFillColor(nvg, debugDragSeat_
        and nvgRGBA(255, 255, 0, 255)
        or nvgRGBA(200, 200, 200, 240))
    local hint = debugDragSeat_
        and string.format(">> 拖拽座位 %s ...", debugDragSeat_ == 1 and "L" or "R")
        or ">> 拖动蓝色圆点调整座位位置"
    nvgText(nvg, panelX + 4, ly, hint)
    ly = ly + lineH

    -- 座位偏移 (高亮)
    nvgFillColor(nvg, nvgRGBA(100, 200, 255, 255))
    nvgText(nvg, panelX + 4, ly,
        string.format("SEAT_DX={%.3f, %.3f}  SEAT_DY=%.3f",
            seatDX[1], seatDX[2], seatDY))
    ly = ly + lineH

    -- 尺寸信息
    nvgFillColor(nvg, nvgRGBA(0, 255, 100, 255))
    nvgText(nvg, panelX + 4, ly,
        string.format("W_RATIO=%.2f  ASPECT=%.1f  sz=%.0fx%.0f  dock=%.0fx%.0f",
            TABLE_W_RATIO, TABLE_VISUAL_ASPECT, tw, th, dockDrawW_, dockDrawH_))
    ly = ly + lineH

    -- 每张桌子坐标
    for i = 1, IndustrySystem:getTableCount() do
        local tc = tableCenters[i]
        nvgText(nvg, panelX + 4, ly,
            string.format("T%d: x=%.3f y=%.3f",
                i, tc.x, tc.y))
        ly = ly + lineH
    end
end

return IndustryScene
