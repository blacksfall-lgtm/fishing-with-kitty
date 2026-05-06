-- ============================================================================
-- CommandManager: 命令系统 — 执行/撤销/重做
-- ============================================================================

local CommandManager = {}

--- 执行命令
---@param state table EditorState
---@param cmd table Command {execute, undo, name}
function CommandManager.Execute(state, cmd)
    cmd:execute(state)
    table.insert(state.undo_stack, cmd)
    state.redo_stack = {}  -- 新操作清空重做栈
end

--- 撤销
---@param state table EditorState
---@return boolean success
function CommandManager.Undo(state)
    local cmd = table.remove(state.undo_stack)
    if cmd then
        cmd:undo(state)
        table.insert(state.redo_stack, cmd)
        return true
    end
    return false
end

--- 重做
---@param state table EditorState
---@return boolean success
function CommandManager.Redo(state)
    local cmd = table.remove(state.redo_stack)
    if cmd then
        cmd:execute(state)
        table.insert(state.undo_stack, cmd)
        return true
    end
    return false
end

--- 获取撤销/重做栈信息
function CommandManager.GetInfo(state)
    return {
        undoCount = #state.undo_stack,
        redoCount = #state.redo_stack,
        lastUndo  = #state.undo_stack > 0 and state.undo_stack[#state.undo_stack].name or nil,
        lastRedo  = #state.redo_stack > 0 and state.redo_stack[#state.redo_stack].name or nil,
    }
end

return CommandManager
