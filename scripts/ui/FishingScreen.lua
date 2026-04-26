-- ============================================================================
-- FishingScreen: 钓鱼主界面
-- 参照参考图布局: 顶部海域信息 → 分层水面场景 → 进度/状态 → 底部操作区
-- ============================================================================
local UI = require("urhox-libs/UI")
local GameConfig    = require("config.GameConfig")
local GameState     = require("state.GameState")
local FishingSystem = require("systems.FishingSystem")
local BaitSystem    = require("systems.BaitSystem")
local FormatUtils   = require("utils.FormatUtils")
local WaterScene    = require("ui.WaterScene")

local FishingScreen = {}

-- UI引用
local screenRoot_
local statusLabel_
local castBtn_
local autoBtn_
local progressBar_
local catchModal_
local catchTitle_
local catchDetail_
local baitInfoLabel_
local zoneLabel_
local fishCountLabel_

-- ============================================================================
-- 构建
-- ============================================================================

function FishingScreen.build()

    -- ---------- 顶部信息栏 ----------
    zoneLabel_ = UI.Label {
        text = "📍 " .. GameConfig.ZONE_DISPLAY[GameState.currentZone],
        fontSize = 12,
        fontColor = { 180, 220, 255, 200 },
    }
    fishCountLabel_ = UI.Label {
        text = FishingScreen.getInventoryText(),
        fontSize = 12,
        fontColor = { 180, 220, 255, 200 },
    }
    baitInfoLabel_ = UI.Label {
        text = FishingScreen.getBaitText(),
        fontSize = 12,
        fontColor = { 180, 220, 255, 200 },
    }

    local infoBar = UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        paddingHorizontal = 16,
        paddingVertical = 6,
        backgroundColor = { 8, 20, 50, 200 },
        children = { zoneLabel_, baitInfoLabel_, fishCountLabel_ },
    }

    -- ---------- 水面场景 (使用 WaterScene 组件) ----------
    local waterPanel = WaterScene.build()

    -- ---------- 状态/进度条 悬浮在水面场景上方 ----------
    statusLabel_ = UI.Label {
        id = "fishingStatus",
        text = "准备钓鱼",
        fontSize = 16,
        fontWeight = "bold",
        fontColor = { 255, 255, 255, 230 },
        textAlign = "center",
    }

    progressBar_ = UI.ProgressBar {
        id = "fishingProgress",
        value = 0,
        width = "65%",
        maxWidth = 260,
        height = 6,
        backgroundColor = { 255, 255, 255, 30 },
        fillColor = "#4FC3F7",
        borderRadius = 3,
        transition = "value 0.15s easeOut",
    }

    -- 状态悬浮层 (绝对定位在水面底部)
    local statusOverlay = UI.Panel {
        position = "absolute",
        bottom = 12,
        left = 0,
        right = 0,
        alignItems = "center",
        gap = 6,
        pointerEvents = "none",
        children = {
            statusLabel_,
            progressBar_,
        }
    }

    -- 水面区域容器 (包含水面+状态悬浮)
    local waterContainer = UI.Panel {
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        children = {
            waterPanel,
            statusOverlay,
        }
    }

    -- ---------- 底部操作区 ----------

    -- 抛竿按钮
    castBtn_ = UI.Button {
        id = "castBtn",
        text = "🎣 抛竿",
        fontSize = 16,
        fontWeight = "bold",
        width = 160,
        height = 48,
        borderRadius = 24,
        backgroundColor = { 30, 130, 230, 255 },
        hoverBackgroundColor = { 50, 150, 250, 255 },
        pressedBackgroundColor = { 20, 100, 200, 255 },
        textColor = { 255, 255, 255, 255 },
        transition = "backgroundColor 0.15s easeOut, scale 0.1s easeOut",
        onClick = function()
            FishingSystem:cast()
        end,
    }

    -- 自动钓鱼按钮
    autoBtn_ = UI.Button {
        id = "autoBtn",
        text = "⚡ 自动: 关",
        fontSize = 11,
        width = 90,
        height = 36,
        borderRadius = 18,
        backgroundColor = { 50, 60, 80, 255 },
        hoverBackgroundColor = { 65, 75, 95, 255 },
        textColor = { 200, 210, 230, 255 },
        transition = "backgroundColor 0.15s easeOut",
        onClick = function()
            FishingSystem.autoFishing = not FishingSystem.autoFishing
            if FishingSystem.autoFishing then
                autoBtn_:SetText("⚡ 自动: 开")
                autoBtn_:SetStyle({ backgroundColor = { 30, 110, 70, 255 } })
            else
                autoBtn_:SetText("⚡ 自动: 关")
                autoBtn_:SetStyle({ backgroundColor = { 50, 60, 80, 255 } })
            end
        end,
    }

    -- 饵料按钮行
    local baitButtons = {}
    for _, bait in ipairs(GameConfig.BAIT) do
        local baitId = bait.id
        local isActive = (GameState.currentBaitId == baitId)
        table.insert(baitButtons, UI.Button {
            id = "bait_" .. baitId,
            text = bait.icon .. " " .. bait.displayName,
            fontSize = 10,
            height = 30,
            flexGrow = 1,
            flexBasis = 0,
            borderRadius = 6,
            backgroundColor = isActive
                and { 40, 100, 170, 255 } or { 35, 45, 65, 255 },
            hoverBackgroundColor = isActive
                and { 50, 110, 180, 255 } or { 50, 60, 80, 255 },
            textColor = isActive
                and { 180, 220, 255, 255 } or { 150, 160, 180, 255 },
            transition = "backgroundColor 0.15s easeOut",
            onClick = function()
                BaitSystem:selectBait(baitId)
                FishingScreen.refreshBaitButtons()
            end,
        })
    end

    -- 海域切换按钮行
    local zoneButtons = {}
    for _, zoneName in ipairs({"nearshore", "offshore"}) do
        local zn = zoneName
        local unlocked = GameState.unlockedZones[zn]
        local isActive = (GameState.currentZone == zn)
        table.insert(zoneButtons, UI.Button {
            id = "zone_" .. zn,
            text = (isActive and "● " or "") .. GameConfig.ZONE_DISPLAY[zn] .. (not unlocked and " 🔒" or ""),
            fontSize = 11,
            height = 30,
            flexGrow = 1,
            flexBasis = 0,
            borderRadius = 6,
            disabled = not unlocked,
            backgroundColor = isActive
                and { 40, 100, 170, 255 } or { 35, 45, 65, 255 },
            textColor = isActive
                and { 180, 220, 255, 255 } or { 150, 160, 180, 255 },
            transition = "backgroundColor 0.15s easeOut",
            onClick = function()
                if unlocked then
                    GameState.currentZone = zn
                    FishingScreen.refreshZone()
                end
            end,
        })
    end

    -- 底部操作面板
    local controlPanel = UI.Panel {
        width = "100%",
        paddingHorizontal = 16,
        paddingTop = 10,
        paddingBottom = 12,
        gap = 8,
        alignItems = "center",
        backgroundColor = { 12, 22, 45, 250 },
        borderWidth = { top = 1 },
        borderColor = { 50, 80, 130, 80 },
        children = {
            -- 钓鱼 + 自动按钮
            UI.Panel {
                flexDirection = "row",
                gap = 12,
                alignItems = "center",
                children = { castBtn_, autoBtn_ },
            },
            -- 海域切换
            UI.Panel {
                width = "100%",
                maxWidth = 300,
                flexDirection = "row",
                gap = 6,
                children = zoneButtons,
            },
            -- 饵料切换
            UI.Panel {
                id = "baitRow",
                width = "100%",
                maxWidth = 300,
                flexDirection = "row",
                gap = 6,
                children = baitButtons,
            },
        }
    }

    -- ---------- 捕获弹窗 (Modal) ----------
    catchTitle_ = UI.Label {
        text = "🎉 钓到了!",
        fontSize = 18,
        fontWeight = "bold",
        fontColor = { 255, 215, 0, 255 },
        textAlign = "center",
    }
    catchDetail_ = UI.Label {
        text = "",
        fontSize = 14,
        fontColor = { 230, 240, 255, 255 },
        textAlign = "center",
        whiteSpace = "normal",
        lineHeight = 1.6,
    }

    catchModal_ = UI.Panel {
        id = "catchModal",
        visible = false,
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 0, 0, 0, 100 },
        pointerEvents = "auto",
        onClick = function()
            catchModal_:SetVisible(false)
        end,
        children = {
            UI.Panel {
                width = "80%",
                maxWidth = 280,
                padding = 20,
                alignItems = "center",
                gap = 10,
                backgroundColor = { 20, 50, 90, 240 },
                borderRadius = 16,
                borderWidth = 2,
                borderColor = { 80, 160, 255, 150 },
                boxShadow = {
                    { x = 0, y = 4, blur = 20, spread = 0, color = { 0, 100, 255, 60 } },
                },
                children = {
                    catchTitle_,
                    UI.Divider { color = { 60, 120, 200, 80 }, spacing = 4 },
                    catchDetail_,
                    UI.Label {
                        text = "点击任意处关闭",
                        fontSize = 10,
                        fontColor = { 150, 170, 200, 150 },
                        marginTop = 4,
                    },
                },
            }
        },
    }

    -- ---------- 组装 ----------
    screenRoot_ = UI.Panel {
        id = "fishingScreen",
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        flexDirection = "column",
        children = {
            infoBar,
            waterContainer,
            controlPanel,
            catchModal_,
        }
    }

    -- 注册回调
    FishingSystem.onStateChange = function(newState)
        FishingScreen.onFishingStateChange(newState)
    end
    FishingSystem.onCatch = function(catchInfo)
        FishingScreen.onCatch(catchInfo)
    end

    return screenRoot_
end

-- ============================================================================
-- 状态变化回调
-- ============================================================================

function FishingScreen.onFishingStateChange(state)
    local texts = {
        idle    = "准备钓鱼",
        casting = "抛竿中...",
        waiting = "等待咬钩... 🌊",
        reeling = "有鱼上钩! 💪",
        caught  = "钓到了! 🎉",
    }
    if statusLabel_ then
        statusLabel_:SetText(texts[state] or state)
    end

    -- 按钮状态
    if castBtn_ then
        castBtn_:SetDisabled(state ~= "idle")
        if state == "idle" then
            castBtn_:SetText("🎣 抛竿")
            castBtn_:SetStyle({ backgroundColor = { 30, 130, 230, 255 } })
        elseif state == "waiting" then
            castBtn_:SetText("🌊 等待中...")
            castBtn_:SetStyle({ backgroundColor = { 40, 80, 130, 255 } })
        elseif state == "reeling" then
            castBtn_:SetText("💪 收杆!")
            castBtn_:SetStyle({ backgroundColor = { 220, 120, 30, 255 } })
        else
            castBtn_:SetText("...")
            castBtn_:SetStyle({ backgroundColor = { 60, 70, 90, 255 } })
        end
    end
end

-- ============================================================================
-- 捕获回调
-- ============================================================================

function FishingScreen.onCatch(info)
    if not catchModal_ or not catchDetail_ then return end

    local qColor = info.qualityData.color
    local value = math.floor(info.fishData.baseValue * info.qualityData.multiplier)
    local lines = {
        info.fishData.icon .. " " .. info.fishData.displayName,
        "品质: " .. info.qualityData.displayName .. "  💰 " .. value,
    }
    if info.bonusCatch then
        table.insert(lines, "🥅 捞网手额外捕获!")
    end

    catchDetail_:SetText(table.concat(lines, "\n"))
    catchDetail_:SetStyle({
        fontColor = { qColor[1], qColor[2], qColor[3], 255 },
    })
    catchModal_:SetVisible(true)
end

-- ============================================================================
-- 每帧刷新
-- ============================================================================

function FishingScreen.update(dt)
    -- 更新水面动画
    WaterScene.update(dt)

    -- 进度条
    if progressBar_ then
        progressBar_:SetValue(FishingSystem:getProgress())
    end

    -- 捕获弹窗自动关闭
    if FishingSystem.state ~= "caught" and catchModal_ then
        catchModal_:SetVisible(false)
    end

    -- 库存文字
    if fishCountLabel_ then
        fishCountLabel_:SetText(FishingScreen.getInventoryText())
    end
end

-- ============================================================================
-- 辅助刷新
-- ============================================================================

function FishingScreen.refreshBaitButtons()
    if baitInfoLabel_ then
        baitInfoLabel_:SetText(FishingScreen.getBaitText())
    end
    if not screenRoot_ then return end
    for _, bait in ipairs(GameConfig.BAIT) do
        local btn = screenRoot_:FindById("bait_" .. bait.id)
        if btn then
            local isActive = (GameState.currentBaitId == bait.id)
            btn:SetStyle({
                backgroundColor = isActive
                    and { 40, 100, 170, 255 } or { 35, 45, 65, 255 },
            })
        end
    end
end

function FishingScreen.refreshZone()
    if zoneLabel_ then
        zoneLabel_:SetText("📍 " .. GameConfig.ZONE_DISPLAY[GameState.currentZone])
    end
    if not screenRoot_ then return end
    for _, zoneName in ipairs({"nearshore", "offshore"}) do
        local btn = screenRoot_:FindById("zone_" .. zoneName)
        if btn then
            local isActive = (GameState.currentZone == zoneName)
            local unlocked = GameState.unlockedZones[zoneName]
            btn:SetText((isActive and "● " or "") .. GameConfig.ZONE_DISPLAY[zoneName] .. (not unlocked and " 🔒" or ""))
            btn:SetStyle({
                backgroundColor = isActive
                    and { 40, 100, 170, 255 } or { 35, 45, 65, 255 },
            })
        end
    end
end

function FishingScreen.getBaitText()
    local bait = BaitSystem:getCurrentBait()
    local count = BaitSystem:getBaitCount(GameState.currentBaitId)
    local countStr = count >= 999 and "∞" or tostring(count)
    return bait.icon .. " " .. bait.displayName .. " x" .. countStr
end

function FishingScreen.getInventoryText()
    local total = 0
    for _, count in pairs(GameState.fishInventory) do
        total = total + count
    end
    return "🎒 " .. total .. "条"
end

return FishingScreen
