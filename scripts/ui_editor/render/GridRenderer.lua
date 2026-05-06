-- ============================================================================
-- GridRenderer: 画布网格背景渲染
-- ============================================================================

local GridRenderer = {}

--- 渲染网格背景
---@param nvg userdata NanoVG 上下文
---@param state table EditorState
---@param canvasW number 画布可视区域宽度（基准像素）
---@param canvasH number 画布可视区域高度（基准像素）
---@param offsetX number 画布区域左上角屏幕 X
---@param offsetY number 画布区域左上角屏幕 Y
function GridRenderer.Draw(nvg, state, canvasW, canvasH, offsetX, offsetY)
    local zoom = state.canvas_zoom
    local gridSize = 20 * zoom

    if gridSize < 4 then return end -- 缩放太小不画网格

    local ox = state.canvas_offset_x % gridSize
    local oy = state.canvas_offset_y % gridSize

    -- 细网格线
    nvgBeginPath(nvg)
    local alpha = math.floor(math.min(255, 40 * (gridSize / 20)))

    local x = ox
    while x <= canvasW do
        nvgMoveTo(nvg, offsetX + x, offsetY)
        nvgLineTo(nvg, offsetX + x, offsetY + canvasH)
        x = x + gridSize
    end
    local y = oy
    while y <= canvasH do
        nvgMoveTo(nvg, offsetX, offsetY + y)
        nvgLineTo(nvg, offsetX + canvasW, offsetY + y)
        y = y + gridSize
    end

    nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, alpha))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)

    -- 粗网格线（每 5 格）
    local majorGridSize = gridSize * 5
    if majorGridSize >= 20 then
        local majorAlpha = math.floor(math.min(255, 60 * (majorGridSize / 100)))
        local mox = state.canvas_offset_x % majorGridSize
        local moy = state.canvas_offset_y % majorGridSize

        nvgBeginPath(nvg)
        x = mox
        while x <= canvasW do
            nvgMoveTo(nvg, offsetX + x, offsetY)
            nvgLineTo(nvg, offsetX + x, offsetY + canvasH)
            x = x + majorGridSize
        end
        y = moy
        while y <= canvasH do
            nvgMoveTo(nvg, offsetX, offsetY + y)
            nvgLineTo(nvg, offsetX + canvasW, offsetY + y)
            y = y + majorGridSize
        end

        nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, majorAlpha))
        nvgStrokeWidth(nvg, 1)
        nvgStroke(nvg)
    end
end

return GridRenderer
