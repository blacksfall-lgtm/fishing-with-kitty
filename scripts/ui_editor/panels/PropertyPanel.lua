-- ============================================================================
-- PropertyPanel: 右侧属性面板 — 查看 + 修改选中节点属性
-- ============================================================================

local UI = require("urhox-libs/UI")
local CommandManager = require("ui_editor.commands.CommandManager")
local ModifyCommand  = require("ui_editor.commands.ModifyCommand")

local PropertyPanel = {}
PropertyPanel.__index = PropertyPanel

--- 创建属性面板
---@param editorState table
---@return table panelInstance
function PropertyPanel.Create(editorState)
    local self = setmetatable({}, PropertyPanel)
    self.editorState_ = editorState
    self.lastSelectionId_ = nil
    self.container_ = nil
    self.contentArea_ = nil

    -- 空状态提示
    self.emptyLabel_ = UI.Label {
        text = "选中节点查看属性",
        fontSize = 11,
        fontColor = { 120, 120, 150, 160 },
        paddingTop = 20,
        alignSelf = "center",
    }

    -- 内容滚动区
    self.contentArea_ = UI.ScrollView {
        id = "propContent",
        flexGrow = 1,
        flexBasis = 0,
        children = { self.emptyLabel_ },
    }

    self.container_ = UI.Panel {
        id = "propertyPanel",
        width = 220,
        backgroundColor = { 28, 28, 40, 255 },
        borderColor = { 50, 50, 70, 100 },
        borderWidth = 1,
        flexDirection = "column",
        children = {
            UI.Label {
                text = "属性",
                fontSize = 11,
                fontColor = { 140, 140, 170, 200 },
                paddingTop = 8,
                paddingLeft = 10,
                paddingBottom = 6,
            },
            self.contentArea_,
        },
    }

    return self
end

--- 获取面板 Widget
function PropertyPanel:GetWidget()
    return self.container_
end

--- 每帧检查是否需要刷新
function PropertyPanel:Update()
    local state = self.editorState_
    local selId = (#state.selection == 1) and state.selection[1] or nil

    if selId ~= self.lastSelectionId_ then
        self.lastSelectionId_ = selId
        self:Rebuild()
    end
end

--- 重建属性面板内容
function PropertyPanel:Rebuild()
    local state = self.editorState_
    local selId = self.lastSelectionId_
    self.contentArea_:ClearChildren()

    if not selId then
        self.contentArea_:AddChild(self.emptyLabel_)
        return
    end

    local node = state.nodes[selId]
    if not node then
        self.contentArea_:AddChild(self.emptyLabel_)
        return
    end

    -- 基础分组
    self:addSectionHeader("基础")
    self:addTextRow("名称", node.name, function(val)
        self:commitChange(selId, "name", node.name, val)
    end)
    self:addReadonlyRow("类型", node.type)
    self:addCheckboxRow("可见", node.visible, function(val)
        self:commitChange(selId, "visible", node.visible, val)
    end)
    self:addCheckboxRow("锁定", node.locked, function(val)
        self:commitChange(selId, "locked", node.locked, val)
    end)

    -- 变换分组
    self:addSectionHeader("变换")
    self:addNumberRow("X", node.x, function(val)
        self:commitChange(selId, "x", node.x, val)
    end)
    self:addNumberRow("Y", node.y, function(val)
        self:commitChange(selId, "y", node.y, val)
    end)
    self:addNumberRow("宽度", node.width, function(val)
        self:commitChange(selId, "width", node.width, math.max(10, val))
    end)
    self:addNumberRow("高度", node.height, function(val)
        self:commitChange(selId, "height", node.height, math.max(10, val))
    end)
    self:addNumberRow("旋转", node.rotation, function(val)
        self:commitChange(selId, "rotation", node.rotation, val)
    end)

    -- 外观分组
    self:addSectionHeader("外观")
    self:addTextRow("背景色", node.style.bg_color or "", function(val)
        self:commitChange(selId, "style.bg_color", node.style.bg_color, val)
    end)
    self:addTextRow("边框色", node.style.border_color or "", function(val)
        self:commitChange(selId, "style.border_color", node.style.border_color, val)
    end)
    self:addNumberRow("边框宽", node.style.border_width or 0, function(val)
        self:commitChange(selId, "style.border_width", node.style.border_width, math.max(0, val))
    end)
    self:addNumberRow("圆角", node.style.corner_radius or 0, function(val)
        self:commitChange(selId, "style.corner_radius", node.style.corner_radius, math.max(0, val))
    end)
    self:addSliderRow("透明度", node.style.opacity or 1.0, 0, 1.0, function(val)
        self:commitChange(selId, "style.opacity", node.style.opacity, val)
    end)

    -- 图片属性（所有支持 bg_image 的类型）
    if node.type == "image" or node.type == "button" or node.type == "panel" then
        self:addSectionHeader("图片")
        self:addImageRow("背景图", node.style.bg_image or "", function(val)
            self:commitChange(selId, "style.bg_image", node.style.bg_image, val)
        end)
        self:addDropdownRow("图片模式", node.style.bg_image_mode or "fill", {
            { value = "fill",   label = "拉伸填充" },
            { value = "9slice", label = "九宫格" },
        }, function(val)
            self:commitChange(selId, "style.bg_image_mode", node.style.bg_image_mode, val)
        end)
        if (node.style.bg_image_mode or "fill") == "9slice" then
            self:addNumberRow("切片边距", node.style.slice_border or 8, function(val)
                self:commitChange(selId, "style.slice_border", node.style.slice_border, math.max(1, val))
            end)
        end
    end

    -- 文本属性（仅 text/button）
    if node.type == "text" or node.type == "button" then
        self:addSectionHeader("文本")
        self:addTextRow("内容", node.style.text or "", function(val)
            self:commitChange(selId, "style.text", node.style.text, val)
        end)
        self:addNumberRow("字号", node.style.font_size or 14, function(val)
            self:commitChange(selId, "style.font_size", node.style.font_size, math.max(8, val))
        end)
        self:addTextRow("字体色", node.style.font_color or "#FFFFFFFF", function(val)
            self:commitChange(selId, "style.font_color", node.style.font_color, val)
        end)
    end
end

--- 提交属性修改（走命令系统）
function PropertyPanel:commitChange(nodeId, path, oldVal, newVal)
    if oldVal == newVal then return end
    local cmd = ModifyCommand.New(nodeId, path, oldVal, newVal)
    CommandManager.Execute(self.editorState_, cmd)
    -- 刷新面板
    self.lastSelectionId_ = nil
end

-- ========== UI 构建辅助 ==========

function PropertyPanel:addSectionHeader(title)
    self.contentArea_:AddChild(UI.Label {
        text = title,
        fontSize = 10,
        fontColor = { 100, 140, 200, 200 },
        paddingTop = 8,
        paddingBottom = 2,
        paddingLeft = 10,
    })
end

function PropertyPanel:addReadonlyRow(label, value)
    self.contentArea_:AddChild(UI.Panel {
        width = "100%",
        height = 28,
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = 10,
        paddingRight = 10,
        children = {
            UI.Label { text = label, fontSize = 11, fontColor = { 160, 160, 180, 200 }, width = 55 },
            UI.Label { text = tostring(value), fontSize = 11, fontColor = { 200, 200, 220, 255 }, flexGrow = 1 },
        },
    })
end

function PropertyPanel:addTextRow(label, value, onChange)
    local inputWidget = UI.TextField {
        value = tostring(value),
        fontSize = 11,
        height = 22,
        flexGrow = 1,
        backgroundColor = { 40, 40, 55, 255 },
        borderColor = { 60, 60, 80, 150 },
        fontColor = { 220, 220, 240, 255 },
        onSubmit = function(self2, val)
            if onChange then onChange(val) end
        end,
    }

    self.contentArea_:AddChild(UI.Panel {
        width = "100%",
        height = 28,
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = 10,
        paddingRight = 10,
        gap = 4,
        children = {
            UI.Label { text = label, fontSize = 11, fontColor = { 160, 160, 180, 200 }, width = 55 },
            inputWidget,
        },
    })
end

function PropertyPanel:addNumberRow(label, value, onChange)
    local inputWidget = UI.TextField {
        value = tostring(math.floor(value * 100) / 100),
        fontSize = 11,
        height = 22,
        flexGrow = 1,
        backgroundColor = { 40, 40, 55, 255 },
        borderColor = { 60, 60, 80, 150 },
        fontColor = { 220, 220, 240, 255 },
        onSubmit = function(self2, val)
            local num = tonumber(val)
            if num and onChange then onChange(num) end
        end,
    }

    self.contentArea_:AddChild(UI.Panel {
        width = "100%",
        height = 28,
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = 10,
        paddingRight = 10,
        gap = 4,
        children = {
            UI.Label { text = label, fontSize = 11, fontColor = { 160, 160, 180, 200 }, width = 55 },
            inputWidget,
        },
    })
end

function PropertyPanel:addCheckboxRow(label, value, onChange)
    self.contentArea_:AddChild(UI.Panel {
        width = "100%",
        height = 28,
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = 10,
        paddingRight = 10,
        gap = 4,
        children = {
            UI.Label { text = label, fontSize = 11, fontColor = { 160, 160, 180, 200 }, width = 55 },
            UI.Checkbox {
                checked = value,
                onChange = function(self2, val)
                    if onChange then onChange(val) end
                end,
            },
        },
    })
end

--- 图片资源列表（游戏中可用的图片）
local IMAGE_OPTIONS = {
    { value = "",                                           label = "(无)" },
    { value = "image/button_square_depth_line.png",         label = "方形按钮" },
    { value = "image/button_rectangle_depth_line.png",      label = "矩形按钮" },
    { value = "image/button_round_depth_line.png",          label = "圆形按钮" },
    { value = "image/button_square_line.png",               label = "方形线框" },
    { value = "image/button_rectangle_line.png",            label = "矩形线框" },
    { value = "image/button_round_line.png",                label = "圆形线框" },
    { value = "image/icon_anchor.png",                      label = "锚-返航" },
    { value = "image/icon_boat_upgrade_20260428113157.png", label = "船只升级" },
    { value = "image/icon_upgrade_arrow_20260428113242.png",label = "升级箭头" },
    { value = "image/icon_coin_20260427064921.png",         label = "金币" },
    { value = "image/icon_diamond_v2_20260427070509.png",   label = "钻石" },
    { value = "image/icon_backpack_20260427075646.png",     label = "背包" },
    { value = "image/icon_settings_20260427075642.png",     label = "设置" },
    { value = "image/icon_plus_20260427064347.png",         label = "加号" },
    { value = "image/equip_lamp_20260428114727.png",        label = "装备-灯" },
    { value = "image/equip_net_20260428114735.png",         label = "装备-网" },
    { value = "image/fishing_rod_20260428044026.png",       label = "鱼竿" },
    { value = "image/menu_board_20260428082414.png",        label = "菜单板" },
    { value = "image/dock_bg_v4.png",                       label = "码头背景" },
    { value = "image/table_barrel.png",                     label = "木桶" },
    { value = "image/divider.png",                          label = "分隔线" },
}

function PropertyPanel:addImageRow(label, value, onChange)
    -- 找到当前选中项
    local currentLabel = "(无)"
    for _, opt in ipairs(IMAGE_OPTIONS) do
        if opt.value == value then
            currentLabel = opt.label
            break
        end
    end

    -- 如果当前值不在列表中但非空，显示路径
    if value ~= "" and currentLabel == "(无)" then
        -- 从路径中提取文件名
        local fname = value:match("[^/]+$") or value
        currentLabel = fname
    end

    -- 使用 Dropdown 选择器
    local dropdown = UI.Dropdown {
        options = IMAGE_OPTIONS,
        value = value,
        placeholder = currentLabel,
        height = 24,
        fontSize = 10,
        flexGrow = 1,
        maxVisibleItems = 8,
        backgroundColor = { 40, 40, 55, 255 },
        borderColor = { 60, 60, 80, 150 },
        fontColor = { 220, 220, 240, 255 },
        onChange = function(self2, val, opt)
            if onChange then onChange(val) end
        end,
    }

    self.contentArea_:AddChild(UI.Panel {
        width = "100%",
        height = 28,
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = 10,
        paddingRight = 10,
        gap = 4,
        children = {
            UI.Label { text = label, fontSize = 11, fontColor = { 160, 160, 180, 200 }, width = 55 },
            dropdown,
        },
    })
end

function PropertyPanel:addDropdownRow(label, value, options, onChange)
    local dropdown = UI.Dropdown {
        options = options,
        value = value,
        height = 24,
        fontSize = 10,
        flexGrow = 1,
        maxVisibleItems = 6,
        backgroundColor = { 40, 40, 55, 255 },
        borderColor = { 60, 60, 80, 150 },
        fontColor = { 220, 220, 240, 255 },
        onChange = function(self2, val, opt)
            if onChange then onChange(val) end
        end,
    }

    self.contentArea_:AddChild(UI.Panel {
        width = "100%",
        height = 28,
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = 10,
        paddingRight = 10,
        gap = 4,
        children = {
            UI.Label { text = label, fontSize = 11, fontColor = { 160, 160, 180, 200 }, width = 55 },
            dropdown,
        },
    })
end

function PropertyPanel:addSliderRow(label, value, minVal, maxVal, onChange)
    self.contentArea_:AddChild(UI.Panel {
        width = "100%",
        height = 28,
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = 10,
        paddingRight = 10,
        gap = 4,
        children = {
            UI.Label { text = label, fontSize = 11, fontColor = { 160, 160, 180, 200 }, width = 55 },
            UI.Slider {
                value = math.floor(value * 100),
                min = math.floor(minVal * 100),
                max = math.floor(maxVal * 100),
                flexGrow = 1,
                height = 20,
                onChangeEnd = function(self2, val)
                    if onChange then onChange(val / 100.0) end
                end,
            },
        },
    })
end

return PropertyPanel
