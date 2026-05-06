-- ============================================================================
-- UI 编辑器入口文件
-- 全部 15 阶段完整集成
-- ============================================================================

local UI = require("urhox-libs/UI")
local EditorState    = require("ui_editor.data.EditorState")
local EditorNode     = require("ui_editor.data.EditorNode")
local Defaults       = require("ui_editor.data.Defaults")
local CanvasWidget   = require("ui_editor.render.CanvasWidget")
local CommandManager = require("ui_editor.commands.CommandManager")
local DeleteCommand  = require("ui_editor.commands.DeleteCommand")
local AddCommand     = require("ui_editor.commands.AddCommand")
local BatchCommand   = require("ui_editor.commands.BatchCommand")
local ComponentPanel = require("ui_editor.panels.ComponentPanel")
local PropertyPanel  = require("ui_editor.panels.PropertyPanel")
local LayerPanel     = require("ui_editor.panels.LayerPanel")
local Toolbar        = require("ui_editor.panels.Toolbar")
local SaveLoad       = require("ui_editor.serialization.SaveLoad")

-- ============================================================================
-- 全局变量
-- ============================================================================

---@type table EditorState
local editorState_ = nil

---@type table UI root
local uiRoot_ = nil

---@type table PropertyPanel instance
local propertyPanel_ = nil

---@type table LayerPanel instance
local layerPanel_ = nil

local SAVE_FILENAME = "ui_editor_save.json"

-- ============================================================================
-- 生命周期
-- ============================================================================

function Start()
    graphics.windowTitle = "UI 编辑器"

    -- 1. 初始化 UI 系统
    UI.Init({
        fonts = {
            { family = "sans", weights = {
                normal = "Fonts/MiSans-Regular.ttf",
            } }
        },
        scale = UI.Scale.DEFAULT,
    })

    -- 2. 创建编辑器状态
    editorState_ = EditorState.New()

    -- 3. 居中画布视图
    CenterCanvasView()

    -- 4. 添加测试节点
    AddTestNodes()

    -- 5. 构建 UI
    CreateEditorUI()

    -- 6. 订阅事件
    SubscribeToEvent("KeyDown", "HandleKeyDown")
    SubscribeToEvent("Update", "HandleUpdate")

    print("[UI编辑器] 启动完毕 — 全部阶段")
    print("  中键拖拽 = 平移画布")
    print("  滚轮 = 缩放")
    print("  左键点击 = 选中节点")
    print("  Shift+左键 = 多选")
    print("  左键拖空白 = 框选")
    print("  左键拖节点 = 移动（带吸附）")
    print("  拖拽手柄 = 缩放")
    print("  Ctrl+Z = 撤销   Ctrl+Y = 重做")
    print("  Ctrl+C = 复制   Ctrl+V = 粘贴")
    print("  Delete = 删除选中")
end

function Stop()
    UI.Shutdown()
end

-- ============================================================================
-- 每帧更新
-- ============================================================================

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    -- 更新属性面板（检测选中变化）
    if propertyPanel_ then
        propertyPanel_:Update()
    end
    -- 更新层级面板（检测节点/选中变化）
    if layerPanel_ then
        layerPanel_:Update()
    end
end

-- ============================================================================
-- 初始化辅助
-- ============================================================================

--- 将画布居中到视口中央
function CenterCanvasView()
    local physW = graphics:GetWidth()
    local physH = graphics:GetHeight()
    local dpr   = graphics:GetDPR()
    local viewW = physW / dpr
    local viewH = physH / dpr

    local zoom = 0.8
    editorState_.canvas_zoom = zoom

    local rootNode = editorState_.nodes[editorState_.root_id]
    local canvasW = rootNode.width * zoom
    local canvasH = rootNode.height * zoom

    -- 居中偏移 — 考虑左右面板（左 140px + 右 220px）
    local leftW = 140
    local rightW = 220
    local centerW = viewW - leftW - rightW
    editorState_.canvas_offset_x = (centerW - canvasW) / 2
    editorState_.canvas_offset_y = (viewH - 36 - canvasH) / 2  -- 减去工具栏高度
end

--- 适配视图 — 缩放画布使根节点完全可见
function FitView()
    local physW = graphics:GetWidth()
    local physH = graphics:GetHeight()
    local dpr   = graphics:GetDPR()
    local viewW = physW / dpr
    local viewH = physH / dpr

    local leftW = 140
    local rightW = 220
    local topH = 36
    local centerW = viewW - leftW - rightW
    local centerH = viewH - topH

    local rootNode = editorState_.nodes[editorState_.root_id]
    if not rootNode then return end

    local scaleX = (centerW - 40) / rootNode.width
    local scaleY = (centerH - 40) / rootNode.height
    local zoom = math.min(scaleX, scaleY, 2.0)
    zoom = math.max(zoom, 0.25)

    editorState_.canvas_zoom = zoom

    local canvasW = rootNode.width * zoom
    local canvasH = rootNode.height * zoom
    editorState_.canvas_offset_x = (centerW - canvasW) / 2
    editorState_.canvas_offset_y = (centerH - canvasH) / 2
end

--- 添加测试节点，验证功能
function AddTestNodes()
    editorState_:createNode("panel", nil, {
        name = "主面板",
        x = 40, y = 40,
        width = 300, height = 200,
    })
    editorState_:createNode("button", nil, {
        name = "登录按钮",
        x = 80, y = 280,
        width = 140, height = 44,
    })
    editorState_:createNode("text", nil, {
        name = "标题文本",
        x = 400, y = 60,
        width = 200, height = 36,
    })
    editorState_:createNode("image", nil, {
        name = "头像",
        x = 420, y = 120,
        width = 80, height = 80,
    })
    editorState_:createNode("slider", nil, {
        name = "音量滑块",
        x = 400, y = 250,
        width = 220, height = 32,
    })
end

-- ============================================================================
-- UI 布局
-- ============================================================================

function CreateEditorUI()
    -- 顶部工具栏
    local toolbar = Toolbar.Create(editorState_, {
        onSave = function()
            local ok = SaveLoad.SaveToFile(editorState_, SAVE_FILENAME)
            if ok then
                print("[UI编辑器] 保存成功: " .. SAVE_FILENAME)
            else
                print("[UI编辑器] 保存失败!")
            end
        end,
        onLoad = function()
            local ok, err = SaveLoad.LoadFromFile(editorState_, SAVE_FILENAME)
            if ok then
                print("[UI编辑器] 加载成功: " .. SAVE_FILENAME)
                CenterCanvasView()
                -- 强制刷新面板
                if propertyPanel_ then
                    propertyPanel_.lastSelectionId_ = "__force__"
                end
                if layerPanel_ then
                    layerPanel_.lastNodeCount_ = -1
                end
            else
                print("[UI编辑器] 加载失败: " .. tostring(err))
            end
        end,
        onFitView = FitView,
    })

    -- 左侧: 组件面板 + 层级面板
    layerPanel_ = LayerPanel.Create(editorState_)
    local leftSidebar = UI.Panel {
        id = "leftSidebar",
        width = 140,
        flexDirection = "column",
        children = {
            ComponentPanel.Create(editorState_),
            -- 分隔线
            UI.Panel {
                width = "100%",
                height = 1,
                backgroundColor = { 50, 50, 70, 100 },
            },
            layerPanel_:GetWidget(),
        },
    }

    -- 右侧: 属性面板
    propertyPanel_ = PropertyPanel.Create(editorState_)

    -- 中间画布
    local canvasArea = CanvasWidget {
        id = "canvas",
        flexGrow = 1,
        editorState = editorState_,
    }

    -- 中间区域: 画布
    local centerArea = UI.Panel {
        id = "centerArea",
        flexGrow = 1,
        flexDirection = "column",
        children = {
            canvasArea,
        },
    }

    -- 主体: 左栏 + 中间 + 右栏
    local body = UI.Panel {
        id = "body",
        flexGrow = 1,
        flexDirection = "row",
        children = {
            leftSidebar,
            centerArea,
            propertyPanel_:GetWidget(),
        },
    }

    -- 根布局: 顶栏 + 主体
    uiRoot_ = UI.Panel {
        id = "editorRoot",
        width = "100%",
        height = "100%",
        flexDirection = "column",
        backgroundColor = { 22, 22, 34, 255 },
        children = {
            toolbar,
            body,
        },
    }

    UI.SetRoot(uiRoot_)
end

-- ============================================================================
-- 键盘事件
-- ============================================================================

---@param eventType string
---@param eventData KeyDownEventData
function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()
    local ctrl = input:GetQualifierDown(QUAL_CTRL)

    -- Ctrl+Z: 撤销
    if key == KEY_Z and ctrl then
        if CommandManager.Undo(editorState_) then
            -- 强制刷新属性面板
            if propertyPanel_ then
                propertyPanel_.lastSelectionId_ = "__force__"
            end
        end
        return
    end

    -- Ctrl+Y: 重做
    if key == KEY_Y and ctrl then
        if CommandManager.Redo(editorState_) then
            if propertyPanel_ then
                propertyPanel_.lastSelectionId_ = "__force__"
            end
        end
        return
    end

    -- Ctrl+C: 复制
    if key == KEY_C and ctrl then
        CopySelection()
        return
    end

    -- Ctrl+V: 粘贴
    if key == KEY_V and ctrl then
        PasteFromClipboard()
        return
    end

    -- Ctrl+S: 保存
    if key == KEY_S and ctrl then
        local ok = SaveLoad.SaveToFile(editorState_, SAVE_FILENAME)
        if ok then print("[UI编辑器] 已保存") end
        return
    end

    -- Delete / Backspace: 删除选中
    if key == KEY_DELETE or key == KEY_BACKSPACE then
        DeleteSelection()
        return
    end

    -- Escape: 清空选中
    if key == KEY_ESCAPE then
        editorState_:clearSelection()
        return
    end
end

-- ============================================================================
-- 编辑操作
-- ============================================================================

--- 删除选中节点
function DeleteSelection()
    if #editorState_.selection == 0 then return end

    local cmds = {}
    for _, id in ipairs(editorState_.selection) do
        if id ~= editorState_.root_id then
            table.insert(cmds, DeleteCommand.New(editorState_, id))
        end
    end

    if #cmds == 0 then return end

    if #cmds == 1 then
        CommandManager.Execute(editorState_, cmds[1])
    else
        CommandManager.Execute(editorState_, BatchCommand.New(cmds, "批量删除"))
    end

    if propertyPanel_ then
        propertyPanel_.lastSelectionId_ = "__force__"
    end
end

--- 复制选中节点到剪贴板
function CopySelection()
    if #editorState_.selection == 0 then return end

    editorState_.clipboard = {}
    for _, id in ipairs(editorState_.selection) do
        local node = editorState_.nodes[id]
        if node then
            table.insert(editorState_.clipboard, EditorNode.Serialize(node))
        end
    end
    print("[UI编辑器] 已复制 " .. #editorState_.clipboard .. " 个节点")
end

--- 从剪贴板粘贴
function PasteFromClipboard()
    if #editorState_.clipboard == 0 then return end

    local PASTE_OFFSET = 20
    local cmds = {}
    local newIds = {}

    for _, snapData in ipairs(editorState_.clipboard) do
        -- 创建新节点（新 ID）
        local newNode = EditorNode.Create(snapData.type, {
            name      = snapData.name .. " 副本",
            parent_id = snapData.parent_id or editorState_.root_id,
            x         = snapData.x + PASTE_OFFSET,
            y         = snapData.y + PASTE_OFFSET,
            width     = snapData.width,
            height    = snapData.height,
            rotation  = snapData.rotation,
            style     = snapData.style,
            locked    = false,
            visible   = true,
        })

        local cmd = AddCommand.New(EditorNode.Serialize(newNode))
        table.insert(cmds, cmd)
        table.insert(newIds, newNode.id)
    end

    if #cmds == 1 then
        CommandManager.Execute(editorState_, cmds[1])
    else
        CommandManager.Execute(editorState_, BatchCommand.New(cmds, "粘贴"))
    end

    -- 选中粘贴的节点
    editorState_.selection = newIds
    print("[UI编辑器] 已粘贴 " .. #newIds .. " 个节点")

    if propertyPanel_ then
        propertyPanel_.lastSelectionId_ = "__force__"
    end
end
