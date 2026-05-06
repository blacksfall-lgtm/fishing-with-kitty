-- ============================================================================
-- MoveCommand: 移动节点命令
-- ============================================================================

local MoveCommand = {}
MoveCommand.__index = MoveCommand

--- 创建移动命令
---@param nodeIds table 被移动的节点 ID 列表
---@param dx number X 偏移量
---@param dy number Y 偏移量
---@param oldPositions table {[id] = {x, y}} 移动前快照
function MoveCommand.New(nodeIds, dx, dy, oldPositions)
    return setmetatable({
        name = "移动",
        node_ids = nodeIds,
        dx = dx,
        dy = dy,
        old_positions = oldPositions,
    }, MoveCommand)
end

function MoveCommand:execute(state)
    for _, id in ipairs(self.node_ids) do
        local node = state.nodes[id]
        if node then
            local orig = self.old_positions[id]
            if orig then
                node.x = orig.x + self.dx
                node.y = orig.y + self.dy
            end
        end
    end
end

function MoveCommand:undo(state)
    for _, id in ipairs(self.node_ids) do
        local orig = self.old_positions[id]
        local node = state.nodes[id]
        if orig and node then
            node.x = orig.x
            node.y = orig.y
        end
    end
end

return MoveCommand
