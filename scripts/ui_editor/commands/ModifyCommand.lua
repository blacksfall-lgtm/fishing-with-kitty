-- ============================================================================
-- ModifyCommand: 修改属性命令
-- ============================================================================

local ModifyCommand = {}
ModifyCommand.__index = ModifyCommand

--- 创建属性修改命令
---@param nodeId string
---@param path string 属性路径: "name", "x", "style.bg_color" 等
---@param oldValue any
---@param newValue any
function ModifyCommand.New(nodeId, path, oldValue, newValue)
    return setmetatable({
        name = "修改 " .. path,
        node_id = nodeId,
        path = path,
        old_value = oldValue,
        new_value = newValue,
    }, ModifyCommand)
end

--- 设置嵌套属性
local function setField(node, path, value)
    local parts = {}
    for part in path:gmatch("[^%.]+") do
        table.insert(parts, part)
    end

    local target = node
    for i = 1, #parts - 1 do
        target = target[parts[i]]
        if not target then return end
    end
    target[parts[#parts]] = value
end

--- 获取嵌套属性
local function getField(node, path)
    local parts = {}
    for part in path:gmatch("[^%.]+") do
        table.insert(parts, part)
    end

    local target = node
    for i = 1, #parts - 1 do
        target = target[parts[i]]
        if not target then return nil end
    end
    return target[parts[#parts]]
end

function ModifyCommand:execute(state)
    local node = state.nodes[self.node_id]
    if node then
        setField(node, self.path, self.new_value)
    end
end

function ModifyCommand:undo(state)
    local node = state.nodes[self.node_id]
    if node then
        setField(node, self.path, self.old_value)
    end
end

-- 暴露工具函数
ModifyCommand.getField = getField
ModifyCommand.setField = setField

return ModifyCommand
