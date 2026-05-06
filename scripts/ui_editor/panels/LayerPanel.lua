-- ============================================================================
-- LayerPanel: 层级面板 — 显示节点树
-- ============================================================================

local UI = require("urhox-libs/UI")

local LayerPanel = {}
LayerPanel.__index = LayerPanel

--- 创建层级面板
---@param editorState table
---@return table panelInstance
function LayerPanel.Create(editorState)
    local self = setmetatable({}, LayerPanel)
    self.editorState_ = editorState
    self.lastNodeCount_ = -1
    self.lastSelHash_ = ""

    self.contentArea_ = UI.ScrollView {
        id = "layerContent",
        flexGrow = 1,
        flexBasis = 0,
    }

    self.container_ = UI.Panel {
        id = "layerPanel",
        width = "100%",
        height = 200,
        backgroundColor = { 28, 28, 40, 255 },
        borderColor = { 50, 50, 70, 100 },
        borderWidth = 1,
        flexDirection = "column",
        children = {
            UI.Label {
                text = "层级",
                fontSize = 11,
                fontColor = { 140, 140, 170, 200 },
                paddingTop = 6,
                paddingLeft = 10,
                paddingBottom = 4,
            },
            self.contentArea_,
        },
    }

    return self
end

function LayerPanel:GetWidget()
    return self.container_
end

--- 检查是否需要刷新
function LayerPanel:Update()
    local state = self.editorState_
    local count = 0
    for _ in pairs(state.nodes) do count = count + 1 end

    local selHash = table.concat(state.selection, ",")
    if count ~= self.lastNodeCount_ or selHash ~= self.lastSelHash_ then
        self.lastNodeCount_ = count
        self.lastSelHash_ = selHash
        self:Rebuild()
    end
end

--- 重建层级树
function LayerPanel:Rebuild()
    local state = self.editorState_
    self.contentArea_:ClearChildren()

    if not state.root_id then return end
    self:buildTreeItem(state.root_id, 0)
end

--- 递归构建树节点
function LayerPanel:buildTreeItem(nodeId, depth)
    local state = self.editorState_
    local node = state.nodes[nodeId]
    if not node then return end

    local isSelected = state:isSelected(nodeId)
    local isRoot = (nodeId == state.root_id)
    local indent = depth * 16

    -- 可见性标记
    local visIcon = node.visible and "o" or "-"
    local lockIcon = node.locked and "L" or ""
    local label = node.name or node.type

    local bgColor
    if isSelected then
        bgColor = { 59, 130, 246, 60 }
    else
        bgColor = { 0, 0, 0, 0 }
    end

    local row = UI.Button {
        text = string.rep("  ", depth) .. visIcon .. " " .. label .. " " .. lockIcon,
        fontSize = 11,
        height = 24,
        width = "100%",
        variant = "ghost",
        fontColor = isRoot and { 100, 140, 200, 200 } or { 190, 190, 210, 255 },
        backgroundColor = bgColor,
        onClick = function()
            if not isRoot then
                if input:GetQualifierDown(QUAL_SHIFT) then
                    state:toggleSelection(nodeId)
                else
                    state:selectNode(nodeId)
                end
            end
        end,
    }

    self.contentArea_:AddChild(row)

    -- 子节点
    for _, childId in ipairs(node.children) do
        self:buildTreeItem(childId, depth + 1)
    end
end

return LayerPanel
