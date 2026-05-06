-- ============================================================================
-- HitTest: 命中检测
-- ============================================================================

local HitTest = {}

--- 判断画布坐标 (cx, cy) 是否在节点绝对矩形内
---@param state table EditorState
---@param nodeId string
---@param cx number 画布坐标 X
---@param cy number 画布坐标 Y
---@return boolean
function HitTest.PointInNode(state, nodeId, cx, cy)
    local ax, ay, w, h = state:getAbsoluteRect(nodeId)
    return cx >= ax and cx <= ax + w and cy >= ay and cy <= ay + h
end

--- 从最上层往下找第一个命中的节点（排除根节点）
--- 后渲染的在上面，所以反向遍历渲染列表
---@param state table EditorState
---@param cx number 画布坐标 X
---@param cy number 画布坐标 Y
---@return string|nil nodeId
function HitTest.FindNodeAt(state, cx, cy)
    local ordered = state:getRenderOrder()

    -- 反向遍历（后渲染 = 上层 = 优先命中）
    for i = #ordered, 1, -1 do
        local nodeId = ordered[i]
        -- 跳过根节点
        if nodeId ~= state.root_id then
            local node = state.nodes[nodeId]
            if node and not node.locked and node.visible then
                if HitTest.PointInNode(state, nodeId, cx, cy) then
                    return nodeId
                end
            end
        end
    end

    return nil
end

--- 获取矩形范围内的所有节点 ID（用于框选）
---@param state table EditorState
---@param x1 number 画布坐标左上 X
---@param y1 number 画布坐标左上 Y
---@param x2 number 画布坐标右下 X
---@param y2 number 画布坐标右下 Y
---@return table nodeIds
function HitTest.FindNodesInRect(state, x1, y1, x2, y2)
    local rx = math.min(x1, x2)
    local ry = math.min(y1, y2)
    local rw = math.abs(x2 - x1)
    local rh = math.abs(y2 - y1)

    local result = {}
    local ordered = state:getRenderOrder()

    for _, nodeId in ipairs(ordered) do
        if nodeId ~= state.root_id then
            local node = state.nodes[nodeId]
            if node and not node.locked and node.visible then
                local ax, ay, w, h = state:getAbsoluteRect(nodeId)
                -- 判断矩形相交
                if ax < rx + rw and ax + w > rx and ay < ry + rh and ay + h > ry then
                    table.insert(result, nodeId)
                end
            end
        end
    end

    return result
end

return HitTest
