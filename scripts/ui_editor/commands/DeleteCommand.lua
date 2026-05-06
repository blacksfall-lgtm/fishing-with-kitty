-- ============================================================================
-- DeleteCommand: 删除节点命令（支持递归删除子节点）
-- ============================================================================

local EditorNode = require("ui_editor.data.EditorNode")

local DeleteCommand = {}
DeleteCommand.__index = DeleteCommand

--- 创建删除命令
---@param state table EditorState — 用于获取完整子树快照
---@param nodeId string
function DeleteCommand.New(state, nodeId)
    local cmd = setmetatable({
        name = "删除",
        node_id = nodeId,
        snapshots = {},    -- 按删除顺序（叶先根后）排列的快照
        parent_id = nil,
        child_index = nil, -- 在父节点 children 中的原始位置
    }, DeleteCommand)

    -- 快照整棵子树
    cmd:snapshotSubtree(state, nodeId)

    -- 记录在父节点中的位置以便恢复顺序
    local node = state.nodes[nodeId]
    if node and node.parent_id then
        cmd.parent_id = node.parent_id
        local parent = state.nodes[node.parent_id]
        if parent then
            for i, cid in ipairs(parent.children) do
                if cid == nodeId then
                    cmd.child_index = i
                    break
                end
            end
        end
    end

    return cmd
end

--- 递归快照子树节点（深度优先，叶节点先入）
function DeleteCommand:snapshotSubtree(state, nodeId)
    local node = state.nodes[nodeId]
    if not node then return end

    for _, childId in ipairs(node.children) do
        self:snapshotSubtree(state, childId)
    end

    table.insert(self.snapshots, EditorNode.Serialize(node))
end

function DeleteCommand:execute(state)
    -- 按快照顺序（叶先根后）删除
    for _, snap in ipairs(self.snapshots) do
        local node = state.nodes[snap.id]
        if node then
            -- 从选中移除
            for i = #state.selection, 1, -1 do
                if state.selection[i] == snap.id then
                    table.remove(state.selection, i)
                end
            end
            state.nodes[snap.id] = nil
        end
    end

    -- 从父节点 children 移除根节点
    if self.parent_id and state.nodes[self.parent_id] then
        local parent = state.nodes[self.parent_id]
        for i, cid in ipairs(parent.children) do
            if cid == self.node_id then
                table.remove(parent.children, i)
                break
            end
        end
    end
end

function DeleteCommand:undo(state)
    -- 反序恢复（根先叶后）
    for i = #self.snapshots, 1, -1 do
        local snap = self.snapshots[i]
        local node = EditorNode.Create(snap.type, {
            id        = snap.id,
            name      = snap.name,
            parent_id = snap.parent_id,
            children  = snap.children,
            x         = snap.x,
            y         = snap.y,
            width     = snap.width,
            height    = snap.height,
            rotation  = snap.rotation,
            style     = snap.style,
            locked    = snap.locked,
            visible   = snap.visible,
        })
        state.nodes[node.id] = node
    end

    -- 恢复在父节点中的位置
    if self.parent_id and state.nodes[self.parent_id] then
        local parent = state.nodes[self.parent_id]
        if self.child_index then
            table.insert(parent.children, self.child_index, self.node_id)
        else
            table.insert(parent.children, self.node_id)
        end
    end
end

return DeleteCommand
