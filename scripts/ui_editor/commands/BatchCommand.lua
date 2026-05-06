-- ============================================================================
-- BatchCommand: 批量命令（多个操作合为一次撤销）
-- ============================================================================

local BatchCommand = {}
BatchCommand.__index = BatchCommand

--- 创建批量命令
---@param commands table Command[] 子命令列表
---@param batchName string|nil 批量名称
function BatchCommand.New(commands, batchName)
    return setmetatable({
        name = batchName or "批量操作",
        commands = commands,
    }, BatchCommand)
end

function BatchCommand:execute(state)
    for _, cmd in ipairs(self.commands) do
        cmd:execute(state)
    end
end

function BatchCommand:undo(state)
    -- 反序撤销
    for i = #self.commands, 1, -1 do
        self.commands[i]:undo(state)
    end
end

return BatchCommand
