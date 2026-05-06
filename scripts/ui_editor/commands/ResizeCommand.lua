-- ============================================================================
-- ResizeCommand: 缩放节点命令
-- ============================================================================

local ResizeCommand = {}
ResizeCommand.__index = ResizeCommand

--- 创建缩放命令
---@param nodeId string
---@param oldRect table {x, y, w, h}
---@param newRect table {x, y, w, h}
function ResizeCommand.New(nodeId, oldRect, newRect)
    return setmetatable({
        name = "缩放",
        node_id = nodeId,
        old_rect = oldRect,
        new_rect = newRect,
    }, ResizeCommand)
end

function ResizeCommand:execute(state)
    local node = state.nodes[self.node_id]
    if node then
        node.x = self.new_rect.x
        node.y = self.new_rect.y
        node.width = self.new_rect.w
        node.height = self.new_rect.h
    end
end

function ResizeCommand:undo(state)
    local node = state.nodes[self.node_id]
    if node then
        node.x = self.old_rect.x
        node.y = self.old_rect.y
        node.width = self.old_rect.w
        node.height = self.old_rect.h
    end
end

return ResizeCommand
