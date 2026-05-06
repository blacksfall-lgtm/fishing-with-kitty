-- ============================================================================
-- FishingScreen: 钓鱼主界面
-- 参照参考图布局: 顶部海域信息 → 分层水面场景 → 底部操作区
-- ============================================================================
local UI = require("urhox-libs/UI")
local GameConfig    = require("config.GameConfig")
local GameState     = require("state.GameState")
local FormatUtils   = require("utils.FormatUtils")
local WaterScene    = require("ui.WaterScene")

local FishingScreen = {}

-- UI引用
local screenRoot_
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

    local infoBar = UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        paddingHorizontal = 16,
        paddingVertical = 6,
        backgroundColor = { 8, 20, 50, 200 },
        children = { zoneLabel_, fishCountLabel_ },
    }

    -- ---------- 水面场景 (使用 WaterScene 组件) ----------
    local waterPanel = WaterScene.build()

    -- 水面区域容器
    local waterContainer = UI.Panel {
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        children = {
            waterPanel,
        }
    }

    -- ---------- 底部操作区 ----------

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
            -- 海域切换
            UI.Panel {
                width = "100%",
                maxWidth = 300,
                flexDirection = "row",
                gap = 6,
                children = zoneButtons,
            },
        }
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
        }
    }

    return screenRoot_
end

-- ============================================================================
-- 每帧刷新
-- ============================================================================

function FishingScreen.update(dt)
    -- 更新水面动画
    WaterScene.update(dt)

    -- 库存文字
    if fishCountLabel_ then
        fishCountLabel_:SetText(FishingScreen.getInventoryText())
    end
end

-- ============================================================================
-- 辅助刷新
-- ============================================================================

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

function FishingScreen.getInventoryText()
    local total = 0
    for _, count in pairs(GameState.fishInventory) do
        total = total + count
    end
    return "🎒 " .. total .. "条"
end

return FishingScreen
