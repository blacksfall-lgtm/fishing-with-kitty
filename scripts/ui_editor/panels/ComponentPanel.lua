-- ============================================================================
-- ComponentPanel: 左侧组件面板 — 点击添加节点
-- ============================================================================

local UI = require("urhox-libs/UI")
local Defaults       = require("ui_editor.data.Defaults")
local EditorNode     = require("ui_editor.data.EditorNode")
local CommandManager = require("ui_editor.commands.CommandManager")
local AddCommand     = require("ui_editor.commands.AddCommand")

local ComponentPanel = {}

--- 创建组件面板 Widget
---@param editorState table
---@return table widget
function ComponentPanel.Create(editorState)
    local types = Defaults.GetTypeList()
    local buttons = {}

    for _, info in ipairs(types) do
        table.insert(buttons, UI.Button {
            text = info.icon .. " " .. info.name,
            fontSize = 12,
            width = "100%",
            height = 36,
            variant = "ghost",
            fontColor = { 200, 200, 220, 255 },
            onClick = function()
                ComponentPanel.AddNode(editorState, info.type)
            end,
        })
    end

    return UI.Panel {
        id = "componentPanel",
        width = 140,
        backgroundColor = { 28, 28, 40, 255 },
        borderColor = { 50, 50, 70, 100 },
        borderWidth = 1,
        flexDirection = "column",
        paddingTop = 8,
        paddingBottom = 8,
        paddingLeft = 6,
        paddingRight = 6,
        gap = 2,
        children = {
            UI.Label {
                text = "组件",
                fontSize = 11,
                fontColor = { 140, 140, 170, 200 },
                paddingBottom = 6,
                paddingLeft = 4,
            },
            table.unpack(buttons),
        },
    }
end

--- 添加节点到画布中央
function ComponentPanel.AddNode(editorState, nodeType)
    local defaults = Defaults.Get(nodeType)
    local rootNode = editorState.nodes[editorState.root_id]

    -- 放置在画布可视区域中央
    local cx = (rootNode.width - defaults.width) / 2
    local cy = (rootNode.height - defaults.height) / 2

    -- 避免与已有节点完全重叠，做一点偏移
    local offset = (#editorState.selection > 0) and 20 or 0
    cx = cx + offset
    cy = cy + offset

    local node = EditorNode.Create(nodeType, {
        name      = defaults.name,
        parent_id = editorState.root_id,
        x         = cx,
        y         = cy,
        width     = defaults.width,
        height    = defaults.height,
        style     = defaults.style,
    })

    local cmd = AddCommand.New(EditorNode.Serialize(node))
    CommandManager.Execute(editorState, cmd)
    editorState:selectNode(node.id)
end

return ComponentPanel
