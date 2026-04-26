-- ============================================================================
-- 钓鱼大亨 - 入口文件 (纯 NanoVG 渲染，无 UI 库)
-- ============================================================================
local GameConfig      = require("config.GameConfig")
local GameState       = require("state.GameState")
local SaveManager     = require("state.SaveManager")
local FishingSystem   = require("systems.FishingSystem")
local BaitSystem      = require("systems.BaitSystem")
local FishSwarmSystem = require("systems.FishSwarmSystem")
local WaterScene      = require("ui.WaterScene")
local SwipeSystem     = require("systems.SwipeSystem")

---@type NVGContextWrapper
local vg_ = nil
local fontSans_ = -1

-- ============================================================================
-- 生命周期
-- ============================================================================

function Start()
    graphics.windowTitle = GameConfig.TITLE
    print("=== " .. GameConfig.TITLE .. " 启动 ===")

    -- 创建 NanoVG 上下文
    vg_ = nvgCreate(1)
    fontSans_ = nvgCreateFont(vg_, "sans", "Fonts/MiSans-Regular.ttf")

    -- 初始化游戏数据
    local loaded = SaveManager:load()
    if not loaded then
        GameState:initNewGame()
        print("[Main] 开始新游戏")
    end

    -- 初始化水面场景图片
    WaterScene.init(vg_)

    -- 钓鱼回调: 捕获时记录信息供渲染
    FishingSystem.onStateChange = function(newState) end
    FishingSystem.onCatch = function(info)
        WaterScene.showCatch(info)
    end

    -- 初始化滑动捕鱼系统
    SwipeSystem.init()
    SwipeSystem.setCatchCallback(function(fish)
        print(string.format("[SwipeSystem] 捕获鱼影 variant=%d pos=(%.2f,%.2f) size=%d",
            fish.variant or 0, fish.x or 0, fish.y or 0, fish.size or 0))
    end)

    -- 订阅事件
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
    SubscribeToEvent(vg_, "NanoVGRender", "HandleNanoVGRender")

    print("=== 初始化完成 ===")
end

function Stop()
    SaveManager:save()
    if vg_ then
        nvgDelete(vg_)
        vg_ = nil
    end
    print("=== 游戏退出 ===")
end

-- ============================================================================
-- 帧更新
-- ============================================================================

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    GameState.playTime = GameState.playTime + dt
    FishingSystem:update(dt)
    SaveManager:update(dt)
    WaterScene.update(dt)

    -- 滑动捕鱼: 需要逻辑分辨率和 DPR
    local physW = graphics:GetWidth()
    local physH = graphics:GetHeight()
    local dpr = graphics:GetDPR()
    SwipeSystem.update(dt, physW / dpr, physH / dpr, dpr)
end

-- ============================================================================
-- NanoVG 渲染
-- ============================================================================

function HandleNanoVGRender(eventType, eventData)
    if not vg_ then return end

    -- 模式 B: 系统逻辑分辨率 + DPR
    local physW = graphics:GetWidth()
    local physH = graphics:GetHeight()
    local dpr = graphics:GetDPR()
    local w = physW / dpr
    local h = physH / dpr

    nvgBeginFrame(vg_, w, h, dpr)
    WaterScene.render(vg_, 0, 0, w, h)
    nvgEndFrame(vg_)
end

-- ============================================================================
-- 输入
-- ============================================================================

---@param eventType string
---@param eventData KeyDownEventData
function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()

    if key == KEY_F or key == KEY_SPACE then
        FishingSystem:cast()
    end
    if key == KEY_A then
        FishingSystem.autoFishing = not FishingSystem.autoFishing
    end
    if key == KEY_S then
        SaveManager:save()
    end
    if key == KEY_W then
        FishSwarmSystem.forceWave()
    end
end
