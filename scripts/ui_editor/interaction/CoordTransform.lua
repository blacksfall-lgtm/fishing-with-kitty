-- ============================================================================
-- CoordTransform: 屏幕坐标 ↔ 画布坐标转换
-- ============================================================================

local CoordTransform = {}

--- 屏幕坐标 → 画布坐标
---@param state table EditorState
---@param sx number 屏幕 X（相对于画布区域左上角）
---@param sy number 屏幕 Y（相对于画布区域左上角）
---@return number cx, number cy 画布坐标
function CoordTransform.ScreenToCanvas(state, sx, sy)
    local cx = (sx - state.canvas_offset_x) / state.canvas_zoom
    local cy = (sy - state.canvas_offset_y) / state.canvas_zoom
    return cx, cy
end

--- 画布坐标 → 屏幕坐标
---@param state table EditorState
---@param cx number 画布 X
---@param cy number 画布 Y
---@return number sx, number sy 屏幕坐标（相对于画布区域左上角）
function CoordTransform.CanvasToScreen(state, cx, cy)
    local sx = cx * state.canvas_zoom + state.canvas_offset_x
    local sy = cy * state.canvas_zoom + state.canvas_offset_y
    return sx, sy
end

--- 画布尺寸 → 屏幕尺寸
---@param state table EditorState
---@param w number
---@param h number
---@return number sw, number sh
function CoordTransform.CanvasSizeToScreen(state, w, h)
    return w * state.canvas_zoom, h * state.canvas_zoom
end

return CoordTransform
