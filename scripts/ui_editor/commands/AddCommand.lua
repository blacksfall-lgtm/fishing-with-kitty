-- ============================================================================
-- AddCommand: 添加节点命令
-- ============================================================================

local EditorNode = require("ui_editor.data.EditorNode")

local AddCommand = {}
AddCommand.__index = AddCommand

--- 创建添加命令
---@param nodeData table 节点的完整数据快照
function AddCommand.New(nodeData)
    return setmetatable({
        name = "添加 " .. (nodeData.name or nodeData.type),
        node_data = nodeData,
    }, AddCommand)
end

function AddCommand:execute(state)
    local data = self.node_data
    -- 重建节点
    local node = EditorNode.Create(data.type, {
        id        = data.id,
        name      = data.name,
        parent_id = data.parent_id,
        x         = data.x,
        y         = data.y,
        width     = data.width,
        height    = data.height,
        rotation  = data.rotation,
        style     = data.style,
        locked    = data.locked,
        visible   = data.visible,
    })
    state.nodes[node.id] = node
    -- 添加到父节点的 children
    if node.parent_id and state.nodes[node.parent_id] then
        local parent = state.nodes[node.parent_id]
        -- 防止重复添加
        local found = false
        for _, cid in ipairs(parent.children) do
            if cid == node.id then found = true; break end
        end
        if not found then
            table.insert(parent.children, node.id)
        end
    end
end

function AddCommand:undo(state)
    local nodeId = self.node_data.id
    local node = state.nodes[nodeId]
    if not node then return end

    -- 从父节点 children 移除
    if node.parent_id and state.nodes[node.parent_id] then
        local parent = state.nodes[node.parent_id]
        for i, cid in ipairs(parent.children) do
            if cid == nodeId then
                table.remove(parent.children, i)
                break
            end
        end
    end

    -- 从选中移除
    for i = #state.selection, 1, -1 do
        if state.selection[i] == nodeId then
            table.remove(state.selection, i)
        end
    end

    state.nodes[nodeId] = nil
end

return AddCommand
