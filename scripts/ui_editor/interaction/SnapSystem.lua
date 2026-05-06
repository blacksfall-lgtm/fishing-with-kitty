-- ============================================================================
-- SnapSystem: 对齐吸附 + 辅助线
-- ============================================================================

local SnapSystem = {}

local SNAP_THRESHOLD = 5  -- 吸附阈值（画布像素）

--- 计算吸附建议
---@param state table EditorState
---@param dragIds table 正在拖拽的节点 ID 列表
---@param proposedDx number 提议的 X 偏移
---@param proposedDy number 提议的 Y 偏移
---@return number snapDx, number snapDy, table guides
function SnapSystem.CalcSnap(state, dragIds, proposedDx, proposedDy)
    -- 收集被拖拽节点的边线
    local dragEdges = SnapSystem.GetEdges(state, dragIds, proposedDx, proposedDy)
    if not dragEdges then return proposedDx, proposedDy, {} end

    -- 收集其他节点的边线
    local otherEdges = SnapSystem.GetOtherEdges(state, dragIds)

    local guides = {}
    local snapDx = proposedDx
    local snapDy = proposedDy

    -- X 方向吸附
    local bestXDist = SNAP_THRESHOLD + 1
    local bestXSnap = nil
    for _, de in ipairs(dragEdges.verticals) do
        for _, oe in ipairs(otherEdges.verticals) do
            local dist = math.abs(de.pos - oe.pos)
            if dist < bestXDist then
                bestXDist = dist
                bestXSnap = { dragEdge = de, otherEdge = oe, delta = oe.pos - de.pos }
            end
        end
    end

    -- Y 方向吸附
    local bestYDist = SNAP_THRESHOLD + 1
    local bestYSnap = nil
    for _, de in ipairs(dragEdges.horizontals) do
        for _, oe in ipairs(otherEdges.horizontals) do
            local dist = math.abs(de.pos - oe.pos)
            if dist < bestYDist then
                bestYDist = dist
                bestYSnap = { dragEdge = de, otherEdge = oe, delta = oe.pos - de.pos }
            end
        end
    end

    if bestXSnap and bestXDist <= SNAP_THRESHOLD then
        snapDx = proposedDx + bestXSnap.delta
        table.insert(guides, {
            type = "vertical",
            pos = bestXSnap.otherEdge.pos,
            min = math.min(bestXSnap.dragEdge.min, bestXSnap.otherEdge.min),
            max = math.max(bestXSnap.dragEdge.max, bestXSnap.otherEdge.max),
        })
    end

    if bestYSnap and bestYDist <= SNAP_THRESHOLD then
        snapDy = proposedDy + bestYSnap.delta
        table.insert(guides, {
            type = "horizontal",
            pos = bestYSnap.otherEdge.pos,
            min = math.min(bestYSnap.dragEdge.min, bestYSnap.otherEdge.min),
            max = math.max(bestYSnap.dragEdge.max, bestYSnap.otherEdge.max),
        })
    end

    return snapDx, snapDy, guides
end

--- 获取一组节点的边线（考虑偏移）
function SnapSystem.GetEdges(state, nodeIds, dx, dy)
    local verticals = {}    -- x 方向的线
    local horizontals = {}  -- y 方向的线

    for _, nid in ipairs(nodeIds) do
        local ax, ay, w, h = state:getAbsoluteRect(nid)
        ax = ax + (dx or 0)
        ay = ay + (dy or 0)

        -- 左、中、右
        table.insert(verticals, { pos = ax, min = ay, max = ay + h, label = "left" })
        table.insert(verticals, { pos = ax + w / 2, min = ay, max = ay + h, label = "center" })
        table.insert(verticals, { pos = ax + w, min = ay, max = ay + h, label = "right" })

        -- 上、中、下
        table.insert(horizontals, { pos = ay, min = ax, max = ax + w, label = "top" })
        table.insert(horizontals, { pos = ay + h / 2, min = ax, max = ax + w, label = "center" })
        table.insert(horizontals, { pos = ay + h, min = ax, max = ax + w, label = "bottom" })
    end

    return { verticals = verticals, horizontals = horizontals }
end

--- 获取其他节点（非拖拽中）的边线
function SnapSystem.GetOtherEdges(state, excludeIds)
    local excludeSet = {}
    for _, id in ipairs(excludeIds) do
        excludeSet[id] = true
    end

    local ids = {}
    for id, node in pairs(state.nodes) do
        if not excludeSet[id] and node.visible then
            table.insert(ids, id)
        end
    end

    return SnapSystem.GetEdges(state, ids, 0, 0)
end

--- 渲染辅助线
---@param nvg userdata
---@param guides table
---@param state table EditorState
---@param lx number 画布区域左上角 X
---@param ly number 画布区域左上角 Y
function SnapSystem.DrawGuides(nvg, guides, state, lx, ly)
    if #guides == 0 then return end

    local CoordTransform = require("ui_editor.interaction.CoordTransform")

    nvgStrokeColor(nvg, nvgRGBA(255, 100, 100, 200))
    nvgStrokeWidth(nvg, 1)

    for _, guide in ipairs(guides) do
        nvgBeginPath(nvg)
        if guide.type == "vertical" then
            local sx = guide.pos * state.canvas_zoom + state.canvas_offset_x + lx
            local sy1 = guide.min * state.canvas_zoom + state.canvas_offset_y + ly
            local sy2 = guide.max * state.canvas_zoom + state.canvas_offset_y + ly
            nvgMoveTo(nvg, sx, sy1 - 10)
            nvgLineTo(nvg, sx, sy2 + 10)
        else
            local sy = guide.pos * state.canvas_zoom + state.canvas_offset_y + ly
            local sx1 = guide.min * state.canvas_zoom + state.canvas_offset_x + lx
            local sx2 = guide.max * state.canvas_zoom + state.canvas_offset_x + lx
            nvgMoveTo(nvg, sx1 - 10, sy)
            nvgLineTo(nvg, sx2 + 10, sy)
        end
        nvgStroke(nvg)
    end
end

return SnapSystem
