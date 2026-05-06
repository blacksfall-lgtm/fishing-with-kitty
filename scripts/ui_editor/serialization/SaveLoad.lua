-- ============================================================================
-- SaveLoad: JSON 保存/加载
-- ============================================================================

local EditorNode = require("ui_editor.data.EditorNode")

local SaveLoad = {}

--- 保存编辑器状态为 JSON 字符串
---@param state table EditorState
---@return string json
function SaveLoad.Save(state)
    local rootNode = state.nodes[state.root_id]
    local data = {
        version = 1,
        canvas = {
            width = rootNode and rootNode.width or 800,
            height = rootNode and rootNode.height or 600,
        },
        nodes = {},
    }

    -- 按渲染顺序序列化
    local ordered = state:getRenderOrder()
    for _, nodeId in ipairs(ordered) do
        local node = state.nodes[nodeId]
        if node then
            table.insert(data.nodes, EditorNode.Serialize(node))
        end
    end

    return cjson.encode(data)
end

--- 从 JSON 字符串加载编辑器状态
---@param state table EditorState
---@param jsonStr string
---@return boolean success, string|nil error
function SaveLoad.Load(state, jsonStr)
    local ok, data = pcall(cjson.decode, jsonStr)
    if not ok then
        return false, "JSON 解析失败: " .. tostring(data)
    end

    if not data.nodes or #data.nodes == 0 then
        return false, "无效的保存文件: 没有节点数据"
    end

    -- 清空当前状态
    state.nodes = {}
    state.selection = {}
    state.undo_stack = {}
    state.redo_stack = {}
    state.clipboard = {}

    -- 找到最大 ID 编号以重置计数器
    local maxIdNum = 0
    for _, nodeData in ipairs(data.nodes) do
        local num = tonumber(nodeData.id:match("node_(%d+)"))
        if num and num > maxIdNum then
            maxIdNum = num
        end
    end
    EditorNode.ResetIdCounter(maxIdNum + 1)

    -- 重建节点
    for _, nodeData in ipairs(data.nodes) do
        local node = EditorNode.Create(nodeData.type, {
            id        = nodeData.id,
            name      = nodeData.name,
            parent_id = nodeData.parent_id,
            children  = nodeData.children or {},
            x         = nodeData.x,
            y         = nodeData.y,
            width     = nodeData.width,
            height    = nodeData.height,
            rotation  = nodeData.rotation or 0,
            style     = nodeData.style or {},
            locked    = nodeData.locked or false,
            visible   = (nodeData.visible == nil) and true or nodeData.visible,
        })
        state.nodes[node.id] = node
    end

    -- 设置根节点（第一个 parent_id 为 nil 的节点）
    for id, node in pairs(state.nodes) do
        if not node.parent_id then
            state.root_id = id
            break
        end
    end

    -- 如果有 canvas 尺寸信息，更新根节点
    if data.canvas and state.root_id then
        local root = state.nodes[state.root_id]
        if root then
            root.width = data.canvas.width or root.width
            root.height = data.canvas.height or root.height
        end
    end

    return true
end

--- 保存到文件
---@param state table EditorState
---@param filename string
---@return boolean success
function SaveLoad.SaveToFile(state, filename)
    local jsonStr = SaveLoad.Save(state)
    local file = File(filename, FILE_WRITE)
    if file then
        file:WriteString(jsonStr)
        file:Close()
        return true
    end
    return false
end

--- 从文件加载
---@param state table EditorState
---@param filename string
---@return boolean success, string|nil error
function SaveLoad.LoadFromFile(state, filename)
    if not fileSystem:FileExists(filename) then
        return false, "文件不存在: " .. filename
    end
    local file = File(filename, FILE_READ)
    if not file then
        return false, "无法打开文件: " .. filename
    end
    local ok, jsonStr = pcall(function() return file:ReadText() end)
    file:Close()
    if not ok then
        return false, "读取文件失败: " .. filename
    end
    if not jsonStr or jsonStr == "" then
        return false, "文件为空"
    end
    return SaveLoad.Load(state, jsonStr)
end

return SaveLoad
