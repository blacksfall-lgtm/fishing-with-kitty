-- ============================================================================
-- EditorState: 编辑器核心状态管理
-- ============================================================================

local EditorNode = require("ui_editor.data.EditorNode")
local Defaults   = require("ui_editor.data.Defaults")

local EditorState = {}
EditorState.__index = EditorState

--- 创建新的编辑器状态
---@return table state
function EditorState.New()
    local state = setmetatable({}, EditorState)

    -- 节点存储 (id → EditorNode)
    state.nodes     = {}
    state.root_id   = nil

    -- 选中
    state.selection = {}

    -- 剪贴板
    state.clipboard = {}

    -- 撤销/重做栈
    state.undo_stack = {}
    state.redo_stack = {}

    -- 画布视图
    state.canvas_offset_x = 0
    state.canvas_offset_y = 0
    state.canvas_zoom     = 1.0

    -- 交互状态
    state.drag_mode     = nil   -- nil | "move" | "resize" | "select_box"
    state.drag_start_x  = 0
    state.drag_start_y  = 0
    state.resize_handle = nil   -- "tl"|"t"|"tr"|"l"|"r"|"bl"|"b"|"br"

    -- 初始化根画布节点
    state:initRootCanvas()

    return state
end

--- 初始化根画布节点
function EditorState:initRootCanvas()
    local root = EditorNode.Create("panel", {
        name   = "画布",
        x      = 0,
        y      = 0,
        width  = 800,
        height = 600,
        style  = {
            bg_color      = "#1E1E2EFF",
            border_color  = "#444455FF",
            border_width  = 2,
            corner_radius = 0,
            opacity       = 1.0,
        },
    })
    self.nodes[root.id] = root
    self.root_id = root.id
end

-- ========== 节点 CRUD ==========

--- 添加节点到状态中
---@param node table EditorNode
function EditorState:addNode(node)
    self.nodes[node.id] = node
    -- 更新父节点的 children 列表
    if node.parent_id and self.nodes[node.parent_id] then
        local parent = self.nodes[node.parent_id]
        table.insert(parent.children, node.id)
    end
end

--- 创建并添加一个新节点
---@param nodeType string
---@param parentId string|nil 父节点 ID，nil 则挂到根节点
---@param overrides table|nil
---@return table node
function EditorState:createNode(nodeType, parentId, overrides)
    local defaults = Defaults.Get(nodeType)
    overrides = overrides or {}

    local parentNode = self.nodes[parentId or self.root_id]
    if not parentNode then
        parentNode = self.nodes[self.root_id]
    end

    local node = EditorNode.Create(nodeType, {
        name      = overrides.name or defaults.name,
        parent_id = parentNode.id,
        x         = overrides.x or 20,
        y         = overrides.y or 20,
        width     = overrides.width or defaults.width,
        height    = overrides.height or defaults.height,
        style     = overrides.style or defaults.style,
    })

    self:addNode(node)
    return node
end

--- 移除节点（递归移除子节点）
---@param nodeId string
function EditorState:removeNode(nodeId)
    local node = self.nodes[nodeId]
    if not node then return end

    -- 不允许删除根节点
    if nodeId == self.root_id then return end

    -- 递归删除子节点
    local childrenCopy = {}
    for i, cid in ipairs(node.children) do
        childrenCopy[i] = cid
    end
    for _, childId in ipairs(childrenCopy) do
        self:removeNode(childId)
    end

    -- 从父节点的 children 列表移除
    if node.parent_id and self.nodes[node.parent_id] then
        local parent = self.nodes[node.parent_id]
        for i, cid in ipairs(parent.children) do
            if cid == nodeId then
                table.remove(parent.children, i)
                break
            end
        end
    end

    -- 从选中列表移除
    for i = #self.selection, 1, -1 do
        if self.selection[i] == nodeId then
            table.remove(self.selection, i)
        end
    end

    -- 删除节点
    self.nodes[nodeId] = nil
end

--- 获取节点
---@param nodeId string
---@return table|nil
function EditorState:getNode(nodeId)
    return self.nodes[nodeId]
end

-- ========== 坐标计算 ==========

--- 计算节点的绝对位置（递归累加父节点坐标）
---@param nodeId string
---@return number absX, number absY
function EditorState:getAbsolutePosition(nodeId)
    local node = self.nodes[nodeId]
    if not node then return 0, 0 end

    local absX, absY = node.x, node.y
    local parentId = node.parent_id

    while parentId do
        local parent = self.nodes[parentId]
        if not parent then break end
        absX = absX + parent.x
        absY = absY + parent.y
        parentId = parent.parent_id
    end

    return absX, absY
end

--- 获取节点的绝对矩形
---@param nodeId string
---@return number x, number y, number w, number h
function EditorState:getAbsoluteRect(nodeId)
    local node = self.nodes[nodeId]
    if not node then return 0, 0, 0, 0 end
    local ax, ay = self:getAbsolutePosition(nodeId)
    return ax, ay, node.width, node.height
end

-- ========== 渲染顺序 ==========

--- 获取渲染顺序（深度优先，父先子后）
---@return table orderedIds
function EditorState:getRenderOrder()
    local result = {}

    local function traverse(nodeId)
        local node = self.nodes[nodeId]
        if not node then return end
        table.insert(result, nodeId)
        for _, childId in ipairs(node.children) do
            traverse(childId)
        end
    end

    if self.root_id then
        traverse(self.root_id)
    end

    return result
end

-- ========== 选中管理 ==========

--- 清空选中
function EditorState:clearSelection()
    self.selection = {}
end

--- 选中单个节点
---@param nodeId string
function EditorState:selectNode(nodeId)
    if nodeId == self.root_id then return end -- 根节点不可选中
    self.selection = { nodeId }
end

--- 切换节点选中状态（多选用）
---@param nodeId string
function EditorState:toggleSelection(nodeId)
    if nodeId == self.root_id then return end
    for i, id in ipairs(self.selection) do
        if id == nodeId then
            table.remove(self.selection, i)
            return
        end
    end
    table.insert(self.selection, nodeId)
end

--- 判断节点是否被选中
---@param nodeId string
---@return boolean
function EditorState:isSelected(nodeId)
    for _, id in ipairs(self.selection) do
        if id == nodeId then return true end
    end
    return false
end

--- 获取第一个选中的节点
---@return table|nil
function EditorState:getFirstSelected()
    if #self.selection > 0 then
        return self.nodes[self.selection[1]]
    end
    return nil
end

return EditorState
