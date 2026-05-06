-- ============================================================================
-- SelectionOverlay: 选中高亮 + 缩放手柄渲染
-- ============================================================================

local SelectionOverlay = {}

local HANDLE_SIZE = 8   -- 手柄尺寸
local HANDLE_HALF = 4   -- 半径

--- 渲染选中高亮边框
---@param nvg userdata
---@param sx number 屏幕坐标 X
---@param sy number 屏幕坐标 Y
---@param sw number 屏幕宽度
---@param sh number 屏幕高度
function SelectionOverlay.DrawHighlight(nvg, sx, sy, sw, sh)
    -- 选中蓝色边框
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, sw, sh)
    nvgStrokeColor(nvg, nvgRGBA(59, 130, 246, 220))
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)

    -- 半透明填充
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, sw, sh)
    nvgFillColor(nvg, nvgRGBA(59, 130, 246, 15))
    nvgFill(nvg)
end

--- 渲染 8 个缩放手柄
---@param nvg userdata
---@param sx number
---@param sy number
---@param sw number
---@param sh number
function SelectionOverlay.DrawHandles(nvg, sx, sy, sw, sh)
    local positions = SelectionOverlay.GetHandlePositions(sx, sy, sw, sh)

    for _, pos in ipairs(positions) do
        -- 白色填充 + 蓝色边框
        nvgBeginPath(nvg)
        nvgRect(nvg, pos.x - HANDLE_HALF, pos.y - HANDLE_HALF, HANDLE_SIZE, HANDLE_SIZE)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
        nvgFill(nvg)
        nvgStrokeColor(nvg, nvgRGBA(59, 130, 246, 255))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)
    end
end

--- 获取 8 个手柄的屏幕位置
---@return table handles [{name, x, y}, ...]
function SelectionOverlay.GetHandlePositions(sx, sy, sw, sh)
    local cx = sx + sw / 2
    local cy = sy + sh / 2
    return {
        { name = "tl", x = sx,      y = sy      },
        { name = "t",  x = cx,      y = sy      },
        { name = "tr", x = sx + sw, y = sy      },
        { name = "l",  x = sx,      y = cy      },
        { name = "r",  x = sx + sw, y = cy      },
        { name = "bl", x = sx,      y = sy + sh },
        { name = "b",  x = cx,      y = sy + sh },
        { name = "br", x = sx + sw, y = sy + sh },
    }
end

--- 命中检测某个手柄
---@param mx number 鼠标屏幕 X
---@param my number 鼠标屏幕 Y
---@param sx number 节点屏幕 X
---@param sy number 节点屏幕 Y
---@param sw number 节点屏幕 W
---@param sh number 节点屏幕 H
---@return string|nil handleName
function SelectionOverlay.HitTestHandle(mx, my, sx, sy, sw, sh)
    local positions = SelectionOverlay.GetHandlePositions(sx, sy, sw, sh)
    local hitRadius = HANDLE_HALF + 3  -- 比视觉稍大一点方便点击

    for _, pos in ipairs(positions) do
        if math.abs(mx - pos.x) <= hitRadius and math.abs(my - pos.y) <= hitRadius then
            return pos.name
        end
    end
    return nil
end

--- 渲染框选矩形
---@param nvg userdata
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
function SelectionOverlay.DrawSelectBox(nvg, x1, y1, x2, y2)
    local rx = math.min(x1, x2)
    local ry = math.min(y1, y2)
    local rw = math.abs(x2 - x1)
    local rh = math.abs(y2 - y1)

    -- 半透明填充
    nvgBeginPath(nvg)
    nvgRect(nvg, rx, ry, rw, rh)
    nvgFillColor(nvg, nvgRGBA(59, 130, 246, 30))
    nvgFill(nvg)

    -- 虚线边框效果（用实线模拟）
    nvgStrokeColor(nvg, nvgRGBA(59, 130, 246, 180))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
end

return SelectionOverlay
