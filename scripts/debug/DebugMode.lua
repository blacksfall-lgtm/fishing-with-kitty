-- ============================================================================
-- DebugMode: 调试模式状态机
-- 三种模式: GAME → DEBUG → EDITOR
-- F12: GAME ↔ DEBUG 切换
-- F5:  DEBUG → EDITOR
-- ESC: EDITOR → DEBUG, DEBUG → GAME
-- ============================================================================

local UI = require("urhox-libs/UI")
local DebugOverlay = require("debug.DebugOverlay")
local EditorBridge = require("debug.EditorBridge")

local DebugMode = {}

-- 模式常量
DebugMode.MODE_GAME   = "game"
DebugMode.MODE_DEBUG  = "debug"
DebugMode.MODE_EDITOR = "editor"

-- 状态
local currentMode_ = DebugMode.MODE_GAME
local overlayRoot_ = nil      -- DEBUG 模式的 UI 根节点
local overlayWidget_ = nil    -- DebugOverlay 控件实例
local uiInitialized_ = false

-- ============================================================================
-- 初始化
-- ============================================================================

--- 初始化调试模式系统 (在 main Start() 中调用)
function DebugMode.init()
    -- 初始化 UI 系统 (游戏默认不启用)
    if not uiInitialized_ then
        UI.Init({
            fonts = {
                { family = "sans", weights = {
                    normal = "Fonts/MiSans-Regular.ttf",
                } }
            },
            scale = UI.Scale.DEFAULT,
        })
        UI.SetEnabled(false)  -- 默认禁用, GAME 模式零开销
        uiInitialized_ = true
        print("[DebugMode] UI 系统初始化完成 (默认禁用)")
    end

    currentMode_ = DebugMode.MODE_GAME
end

-- ============================================================================
-- 模式切换
-- ============================================================================

--- 进入 DEBUG 模式
local function enterDebugMode()
    print("[DebugMode] 进入 DEBUG 模式")

    -- 创建调试覆盖层 (懒创建)
    if not overlayRoot_ then
        overlayWidget_ = DebugOverlay {
            onRegionSelected = function(region)
                print(string.format("[DebugMode] 选中区域: %s (%.0f,%.0f %.0fx%.0f)",
                    region.name, region.x, region.y, region.w, region.h))
            end,
        }
        overlayRoot_ = UI.Panel {
            id = "debugOverlayRoot",
            width = "100%",
            height = "100%",
            backgroundColor = { 0, 0, 0, 0 },
            children = { overlayWidget_ },
        }
    end

    -- 切换 UI 到 debug overlay
    UI.SetRoot(overlayRoot_, false)
    UI.SetEnabled(true)
    -- 让 UI 接收输入以检测点击
    UI.EnableAutoEventsInput()

    currentMode_ = DebugMode.MODE_DEBUG
end

--- 退出 DEBUG 模式回到 GAME
local function exitDebugMode()
    print("[DebugMode] 退出 DEBUG 模式")
    UI.SetEnabled(false)
    currentMode_ = DebugMode.MODE_GAME
end

--- 进入 EDITOR 模式
local function enterEditorMode()
    print("[DebugMode] 进入 EDITOR 模式")
    -- 获取 DEBUG 模式中选中的区域，传给编辑器
    local selectedRegion = overlayWidget_ and overlayWidget_:GetSelectedRegion() or nil
    -- EditorBridge 会自行设置 UI root 并启用 UI
    EditorBridge.activate(selectedRegion)
    currentMode_ = DebugMode.MODE_EDITOR
end

--- 退出 EDITOR 模式回到 DEBUG
local function exitEditorMode()
    print("[DebugMode] 退出 EDITOR 模式")
    EditorBridge.deactivate()
    -- 切回 debug overlay
    enterDebugMode()
end

-- ============================================================================
-- 按键处理
-- ============================================================================

--- 处理按键事件 (在 main HandleKeyDown 中调用)
--- @return boolean 是否已消费按键
function DebugMode.handleKeyDown(key, ctrl)
    -- Ctrl+D: GAME ↔ DEBUG 切换
    if key == KEY_D and ctrl then
        if currentMode_ == DebugMode.MODE_GAME then
            enterDebugMode()
        elseif currentMode_ == DebugMode.MODE_DEBUG then
            exitDebugMode()
        end
        return true
    end

    -- Ctrl+E: DEBUG → EDITOR
    if key == KEY_E and ctrl then
        if currentMode_ == DebugMode.MODE_DEBUG then
            enterEditorMode()
            return true
        end
    end

    -- ESC: EDITOR → DEBUG, DEBUG → GAME
    if key == KEY_ESCAPE then
        if currentMode_ == DebugMode.MODE_EDITOR then
            exitEditorMode()
            return true
        elseif currentMode_ == DebugMode.MODE_DEBUG then
            exitDebugMode()
            return true
        end
    end

    -- 编辑器模式下, 将按键转发给 EditorBridge
    if currentMode_ == DebugMode.MODE_EDITOR then
        return EditorBridge.handleKeyDown(key, ctrl)
    end

    return false
end

-- ============================================================================
-- 帧更新
-- ============================================================================

--- 每帧更新 (在 main HandleUpdate 中调用)
function DebugMode.update(dt)
    if currentMode_ == DebugMode.MODE_EDITOR then
        EditorBridge.update(dt)
    end
end

-- ============================================================================
-- 查询接口
-- ============================================================================

--- 获取当前模式
function DebugMode.getMode()
    return currentMode_
end

--- 当前是否为 GAME 模式 (主循环需要更新游戏逻辑)
function DebugMode.isGameMode()
    return currentMode_ == DebugMode.MODE_GAME
end

--- 当前是否为 DEBUG 模式
function DebugMode.isDebugMode()
    return currentMode_ == DebugMode.MODE_DEBUG
end

--- 当前是否为 EDITOR 模式
function DebugMode.isEditorMode()
    return currentMode_ == DebugMode.MODE_EDITOR
end

--- 是否应该处理游戏输入 (GAME 模式 + DEBUG 模式下游戏仍运行)
function DebugMode.shouldProcessGameInput()
    return currentMode_ == DebugMode.MODE_GAME
end

--- 是否应该更新游戏逻辑
function DebugMode.shouldUpdateGame()
    return currentMode_ == DebugMode.MODE_GAME or currentMode_ == DebugMode.MODE_DEBUG
end

--- 是否应该渲染游戏画面
function DebugMode.shouldRenderGame()
    -- 三种模式都渲染游戏画面 (编辑器时作为背景)
    return true
end

return DebugMode
