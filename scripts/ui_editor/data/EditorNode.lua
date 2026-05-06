-- ============================================================================
-- EditorNode: UI 编辑器节点定义 + 工厂方法
-- ============================================================================

local EditorNode = {}
EditorNode.__index = EditorNode

-- 全局自增 ID 计数器
local nextId_ = 1

--- 重置 ID 计数器（加载文件后需要调用）
function EditorNode.ResetIdCounter(startId)
    nextId_ = startId or 1
end

--- 获取当前 ID 计数器值
function EditorNode.GetNextId()
    return nextId_
end

--- 生成唯一节点 ID
local function generateId()
    local id = "node_" .. nextId_
    nextId_ = nextId_ + 1
    return id
end

--- 创建新节点
---@param nodeType string 组件类型: panel, button, text, image, slider
---@param overrides table|nil 覆盖默认属性
---@return table EditorNode
function EditorNode.Create(nodeType, overrides)
    overrides = overrides or {}

    local node = {
        id        = overrides.id or generateId(),
        type      = nodeType,
        name      = overrides.name or (nodeType .. "_" .. nextId_),
        parent_id = overrides.parent_id or nil,
        children  = overrides.children or {},

        -- 变换（相对于父节点）
        x         = overrides.x or 0,
        y         = overrides.y or 0,
        width     = overrides.width or 100,
        height    = overrides.height or 60,
        rotation  = overrides.rotation or 0,

        -- 外观
        style     = {},

        -- 元数据
        locked    = overrides.locked or false,
        visible   = (overrides.visible == nil) and true or overrides.visible,
    }

    -- 合并样式
    if overrides.style then
        for k, v in pairs(overrides.style) do
            node.style[k] = v
        end
    end

    setmetatable(node, EditorNode)
    return node
end

--- 深拷贝节点（用于剪贴板/撤销快照）
---@param node table
---@param newId boolean|nil 是否生成新 ID
---@return table
function EditorNode.Clone(node, newId)
    local clone = {
        id        = newId and generateId() or node.id,
        type      = node.type,
        name      = node.name .. (newId and " (副本)" or ""),
        parent_id = node.parent_id,
        children  = {},
        x         = node.x,
        y         = node.y,
        width     = node.width,
        height    = node.height,
        rotation  = node.rotation,
        style     = {},
        locked    = node.locked,
        visible   = node.visible,
    }

    -- 深拷贝 children 列表
    for i, childId in ipairs(node.children) do
        clone.children[i] = childId
    end

    -- 深拷贝样式
    for k, v in pairs(node.style) do
        clone.style[k] = v
    end

    setmetatable(clone, EditorNode)
    return clone
end

--- 序列化节点为纯 table（用于 JSON 保存）
---@param node table
---@return table
function EditorNode.Serialize(node)
    local data = {
        id        = node.id,
        type      = node.type,
        name      = node.name,
        parent_id = node.parent_id,
        children  = {},
        x         = node.x,
        y         = node.y,
        width     = node.width,
        height    = node.height,
        rotation  = node.rotation,
        style     = {},
        locked    = node.locked,
        visible   = node.visible,
    }

    for i, childId in ipairs(node.children) do
        data.children[i] = childId
    end

    for k, v in pairs(node.style) do
        data.style[k] = v
    end

    return data
end

return EditorNode
