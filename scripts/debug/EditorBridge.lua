-- ============================================================================
-- EditorBridge: UI 编辑器桥接模块
-- 将 ui_editor/ 的模块包装为可从主游戏调用的接口
-- 懒初始化: 首次 activate() 时创建编辑器状态和 UI
-- ============================================================================

local UI = require("urhox-libs/UI")

local EditorBridge = {}

-- 编辑器模块 (懒加载)
local EditorState_    = nil
local EditorNode_     = nil
local CanvasWidget_   = nil
local CommandManager_ = nil
local DeleteCommand_  = nil
local AddCommand_     = nil
local BatchCommand_   = nil
local ComponentPanel_ = nil
local PropertyPanel_  = nil
local LayerPanel_     = nil
local Toolbar_        = nil
local SaveLoad_       = nil

-- 运行时状态
local editorState_ = nil
local uiRoot_      = nil
local propertyPanel_ = nil
local layerPanel_    = nil
local initialized_   = false

local SAVE_FILENAME = "ui_editor_save.json"

-- ============================================================================
-- 懒加载编辑器模块
-- ============================================================================
local function loadModules()
    if EditorState_ then return end
    EditorState_    = require("ui_editor.data.EditorState")
    EditorNode_     = require("ui_editor.data.EditorNode")
    CanvasWidget_   = require("ui_editor.render.CanvasWidget")
    CommandManager_ = require("ui_editor.commands.CommandManager")
    DeleteCommand_  = require("ui_editor.commands.DeleteCommand")
    AddCommand_     = require("ui_editor.commands.AddCommand")
    BatchCommand_   = require("ui_editor.commands.BatchCommand")
    ComponentPanel_ = require("ui_editor.panels.ComponentPanel")
    PropertyPanel_  = require("ui_editor.panels.PropertyPanel")
    LayerPanel_     = require("ui_editor.panels.LayerPanel")
    Toolbar_        = require("ui_editor.panels.Toolbar")
    SaveLoad_       = require("ui_editor.serialization.SaveLoad")
end

-- ============================================================================
-- 创建编辑器 UI (参考 ui_editor/main.lua)
-- ============================================================================
local function createEditorUI()
    if not editorState_ then return end

    -- 居中画布视图
    local physW = graphics:GetWidth()
    local physH = graphics:GetHeight()
    local dpr   = graphics:GetDPR()
    local viewW = physW / dpr
    local viewH = physH / dpr

    local rootNode = editorState_.nodes[editorState_.root_id]
    local leftW = 140
    local rightW = 220
    local centerW = viewW - leftW - rightW
    local bodyH = viewH - 36  -- 减去工具栏高度

    -- 自动计算缩放以适应中间区域（与 FitView 同逻辑）
    local scaleX = (centerW - 40) / rootNode.width
    local scaleY = (bodyH - 40) / rootNode.height
    local zoom = math.min(scaleX, scaleY, 2.0)
    zoom = math.max(zoom, 0.1)
    editorState_.canvas_zoom = zoom
    editorState_.canvas_offset_x = (centerW - rootNode.width * zoom) / 2
    editorState_.canvas_offset_y = (bodyH - rootNode.height * zoom) / 2

    -- 工具栏
    local toolbar = Toolbar_.Create(editorState_, {
        onSave = function()
            local ok = SaveLoad_.SaveToFile(editorState_, SAVE_FILENAME)
            print(ok and "[EditorBridge] 保存成功" or "[EditorBridge] 保存失败")
        end,
        onLoad = function()
            local ok, err = SaveLoad_.LoadFromFile(editorState_, SAVE_FILENAME)
            if ok then
                print("[EditorBridge] 加载成功")
                if propertyPanel_ then propertyPanel_.lastSelectionId_ = "__force__" end
                if layerPanel_ then layerPanel_.lastNodeCount_ = -1 end
            else
                print("[EditorBridge] 加载失败: " .. tostring(err))
            end
        end,
        onFitView = function()
            -- FitView
            local fitSx = (centerW - 40) / rootNode.width
            local fitSy = (bodyH - 40) / rootNode.height
            local z = math.min(fitSx, fitSy, 2.0)
            z = math.max(z, 0.1)
            editorState_.canvas_zoom = z
            editorState_.canvas_offset_x = (centerW - rootNode.width * z) / 2
            editorState_.canvas_offset_y = (bodyH - rootNode.height * z) / 2
        end,
    })

    -- 左侧
    layerPanel_ = LayerPanel_.Create(editorState_)
    local leftSidebar = UI.Panel {
        id = "edBridge_left",
        width = 140,
        flexDirection = "column",
        children = {
            ComponentPanel_.Create(editorState_),
            UI.Panel { width = "100%", height = 1, backgroundColor = { 50, 50, 70, 100 } },
            layerPanel_:GetWidget(),
        },
    }

    -- 右侧
    propertyPanel_ = PropertyPanel_.Create(editorState_)

    -- 中间画布
    local canvasArea = CanvasWidget_ {
        id = "edBridge_canvas",
        flexGrow = 1,
        editorState = editorState_,
    }

    local centerArea = UI.Panel {
        id = "edBridge_center",
        flexGrow = 1,
        flexDirection = "column",
        children = { canvasArea },
    }

    local body = UI.Panel {
        id = "edBridge_body",
        flexGrow = 1,
        flexDirection = "row",
        children = { leftSidebar, centerArea, propertyPanel_:GetWidget() },
    }

    uiRoot_ = UI.Panel {
        id = "editorBridgeRoot",
        width = "100%",
        height = "100%",
        flexDirection = "column",
        backgroundColor = { 22, 22, 34, 255 },
        children = { toolbar, body },
    }
end

-- ============================================================================
-- 公开接口
-- ============================================================================

--- 从游戏 UI 区域同步节点到编辑器
--- 从 region 数据构造编辑器节点样式
local function makeStyle(region)
    return {
        bg_image      = region.bg_image or "",
        bg_image_mode = region.bg_image_mode or "fill",
        slice_border  = region.slice_border or 8,
        bg_color      = region.bg_color or "#4A90D9FF",
        corner_radius = region.corner_radius or 6,
        border_color  = "#3A70B0FF",
        border_width  = 1,
        opacity       = 1.0,
        text          = region.text or "",
        font_size     = region.font_size or 14,
        font_color    = "#FFFFFFFF",
        text_align    = "center",
    }
end

--- 同步游戏 UI 区域到编辑器 (层级结构)
--- @param filterName string|nil  按名称过滤只导入匹配的组
local function syncGameRegions(filterName)
    local WaterScene = require("ui.WaterScene")
    local groups = WaterScene.getUIRegions(filterName)

    -- 先清除所有非根节点（重新导入）
    local toRemove = {}
    for id, node in pairs(editorState_.nodes) do
        if id ~= editorState_.root_id then
            table.insert(toRemove, id)
        end
    end
    for _, id in ipairs(toRemove) do
        editorState_:removeNode(id)
    end

    -- 导入层级结构
    local totalCount = 0
    for _, group in ipairs(groups) do
        -- 创建组（父节点）挂在根下
        local groupNode = editorState_:createNode(group.nodeType or "panel", nil, {
            name   = group.name,
            x      = group.x,
            y      = group.y,
            width  = group.w,
            height = group.h,
            style  = makeStyle(group),
        })
        totalCount = totalCount + 1

        -- 创建子节点挂在组下（坐标已经是相对于组的）
        for _, child in ipairs(group.children or {}) do
            editorState_:createNode(child.nodeType or "button", groupNode.id, {
                name   = child.name,
                x      = child.x,
                y      = child.y,
                width  = child.w,
                height = child.h,
                style  = makeStyle(child),
            })
            totalCount = totalCount + 1
        end
    end
    print(string.format("[EditorBridge] 同步了 %d 个组 (%d 个节点)", #groups, totalCount))
end

--- 初始化编辑器 (懒初始化, 只在首次 activate 时执行)
function EditorBridge.ensureInit()
    if initialized_ then return end
    loadModules()

    editorState_ = EditorState_.New()

    -- 将根画布尺寸设置为游戏逻辑分辨率，使坐标匹配
    local physW = graphics:GetWidth()
    local physH = graphics:GetHeight()
    local dpr   = graphics:GetDPR()
    local logW  = math.floor(physW / dpr)
    local logH  = math.floor(physH / dpr)
    local rootNode = editorState_.nodes[editorState_.root_id]
    if rootNode then
        rootNode.width  = logW
        rootNode.height = logH
        print(string.format("[EditorBridge] 画布尺寸设为 %dx%d (逻辑分辨率)", logW, logH))
    end

    -- 不在初始化时导入节点，等 activate 时按选中过滤导入

    createEditorUI()
    initialized_ = true
    print("[EditorBridge] 编辑器初始化完成")
end

--- 激活编辑器: 设置 UI root 为编辑器界面
--- @param selectedRegion table|nil 从 DEBUG 模式传入的选中区域 { name, x, y, w, h }
function EditorBridge.activate(selectedRegion)
    EditorBridge.ensureInit()

    -- 按选中区域名称过滤，只导入该组
    local filterName = selectedRegion and selectedRegion.name or nil
    syncGameRegions(filterName)

    -- 预选匹配的编辑器节点
    if filterName then
        local targetId = nil
        for id, node in pairs(editorState_.nodes) do
            if id ~= editorState_.root_id and node.name == filterName then
                targetId = id
                break
            end
        end
        if targetId then
            editorState_.selection = { targetId }
            print("[EditorBridge] 预选节点: " .. filterName)
        end
    end

    -- 强制刷新面板
    if propertyPanel_ then propertyPanel_.lastSelectionId_ = "__force__" end
    if layerPanel_ then layerPanel_.lastNodeCount_ = -1 end

    if uiRoot_ then
        UI.SetRoot(uiRoot_, false)
    end
    UI.SetEnabled(true)
    UI.EnableAutoEventsInput()
    print("[EditorBridge] 编辑器已激活")
end

--- 停用编辑器: 不销毁, 仅隐藏
function EditorBridge.deactivate()
    print("[EditorBridge] 编辑器已停用")
end

--- 每帧更新 (编辑器模式下调用)
function EditorBridge.update(dt)
    if propertyPanel_ then propertyPanel_:Update() end
    if layerPanel_ then layerPanel_:Update() end
end

--- 处理键盘事件 (编辑器模式下调用)
--- @return boolean 是否已消费按键
function EditorBridge.handleKeyDown(key, ctrl)
    if not initialized_ then return false end

    -- Ctrl+Z: 撤销
    if key == KEY_Z and ctrl then
        if CommandManager_.Undo(editorState_) then
            if propertyPanel_ then propertyPanel_.lastSelectionId_ = "__force__" end
        end
        return true
    end

    -- Ctrl+Y: 重做
    if key == KEY_Y and ctrl then
        if CommandManager_.Redo(editorState_) then
            if propertyPanel_ then propertyPanel_.lastSelectionId_ = "__force__" end
        end
        return true
    end

    -- Ctrl+C: 复制
    if key == KEY_C and ctrl then
        if #editorState_.selection > 0 then
            editorState_.clipboard = {}
            for _, id in ipairs(editorState_.selection) do
                local node = editorState_.nodes[id]
                if node then
                    table.insert(editorState_.clipboard, EditorNode_.Serialize(node))
                end
            end
        end
        return true
    end

    -- Ctrl+V: 粘贴
    if key == KEY_V and ctrl then
        if #editorState_.clipboard > 0 then
            local cmds = {}
            local newIds = {}
            for _, snapData in ipairs(editorState_.clipboard) do
                local newNode = EditorNode_.Create(snapData.type, {
                    name = snapData.name .. " 副本",
                    parent_id = snapData.parent_id or editorState_.root_id,
                    x = snapData.x + 20, y = snapData.y + 20,
                    width = snapData.width, height = snapData.height,
                    rotation = snapData.rotation, style = snapData.style,
                    locked = false, visible = true,
                })
                table.insert(cmds, AddCommand_.New(EditorNode_.Serialize(newNode)))
                table.insert(newIds, newNode.id)
            end
            if #cmds == 1 then
                CommandManager_.Execute(editorState_, cmds[1])
            else
                CommandManager_.Execute(editorState_, BatchCommand_.New(cmds, "粘贴"))
            end
            editorState_.selection = newIds
            if propertyPanel_ then propertyPanel_.lastSelectionId_ = "__force__" end
        end
        return true
    end

    -- Ctrl+S: 保存
    if key == KEY_S and ctrl then
        SaveLoad_.SaveToFile(editorState_, SAVE_FILENAME)
        return true
    end

    -- Delete / Backspace: 删除选中
    if key == KEY_DELETE or key == KEY_BACKSPACE then
        if #editorState_.selection > 0 then
            local cmds = {}
            for _, id in ipairs(editorState_.selection) do
                if id ~= editorState_.root_id then
                    table.insert(cmds, DeleteCommand_.New(editorState_, id))
                end
            end
            if #cmds == 1 then
                CommandManager_.Execute(editorState_, cmds[1])
            elseif #cmds > 1 then
                CommandManager_.Execute(editorState_, BatchCommand_.New(cmds, "批量删除"))
            end
            if propertyPanel_ then propertyPanel_.lastSelectionId_ = "__force__" end
        end
        return true
    end

    return false
end

--- 获取编辑器 UI Root (用于 SetRoot 切换)
function EditorBridge.getRoot()
    EditorBridge.ensureInit()
    return uiRoot_
end

return EditorBridge
