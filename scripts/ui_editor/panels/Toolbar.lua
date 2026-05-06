-- ============================================================================
-- Toolbar: 顶部工具栏
-- ============================================================================

local UI = require("urhox-libs/UI")
local CommandManager = require("ui_editor.commands.CommandManager")
local SaveLoad       = require("ui_editor.serialization.SaveLoad")

local Toolbar = {}

--- 创建工具栏
---@param editorState table
---@param callbacks table {onSave, onLoad, onFitView}
---@return table widget
function Toolbar.Create(editorState, callbacks)
    callbacks = callbacks or {}

    local function makeBtn(text, onClick)
        return UI.Button {
            text = text,
            fontSize = 11,
            height = 26,
            paddingLeft = 8,
            paddingRight = 8,
            variant = "ghost",
            fontColor = { 200, 200, 220, 255 },
            onClick = onClick,
        }
    end

    return UI.Panel {
        id = "toolbar",
        width = "100%",
        height = 36,
        backgroundColor = { 30, 30, 42, 255 },
        borderColor = { 50, 50, 70, 100 },
        borderWidth = 1,
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = 12,
        paddingRight = 12,
        gap = 4,
        children = {
            UI.Label {
                text = "UI 编辑器",
                fontSize = 14,
                fontColor = { 200, 200, 220, 255 },
            },

            -- 分隔
            UI.Panel { width = 1, height = 20, backgroundColor = { 60, 60, 80, 100 }, marginLeft = 8, marginRight = 4 },

            makeBtn("撤销", function()
                if CommandManager.Undo(editorState) then
                    print("[UI编辑器] 撤销成功")
                end
            end),
            makeBtn("重做", function()
                if CommandManager.Redo(editorState) then
                    print("[UI编辑器] 重做成功")
                end
            end),

            UI.Panel { width = 1, height = 20, backgroundColor = { 60, 60, 80, 100 }, marginLeft = 4, marginRight = 4 },

            makeBtn("保存", function()
                if callbacks.onSave then callbacks.onSave() end
            end),
            makeBtn("加载", function()
                if callbacks.onLoad then callbacks.onLoad() end
            end),

            UI.Panel { width = 1, height = 20, backgroundColor = { 60, 60, 80, 100 }, marginLeft = 4, marginRight = 4 },

            makeBtn("适配视图", function()
                if callbacks.onFitView then callbacks.onFitView() end
            end),

            -- 弹性空间
            UI.Panel { flexGrow = 1 },

            -- 状态信息
            UI.Label {
                id = "toolbarInfo",
                text = "",
                fontSize = 10,
                fontColor = { 120, 120, 150, 160 },
            },
        },
    }
end

return Toolbar
