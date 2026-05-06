-- ============================================================================
-- CanvasWidget: 编辑器画布自定义控件
-- 职责: 渲染网格 + 节点 + 选中高亮，处理鼠标交互
-- 集成: 命令系统 / 缩放拖拽 / 吸附系统 / 辅助线
-- ============================================================================

local UI = require("urhox-libs/UI")
local GridRenderer     = require("ui_editor.render.GridRenderer")
local NodeRenderer     = require("ui_editor.render.NodeRenderer")
local SelectionOverlay = require("ui_editor.render.SelectionOverlay")
local CoordTransform   = require("ui_editor.interaction.CoordTransform")
local HitTest          = require("ui_editor.interaction.HitTest")
local CommandManager   = require("ui_editor.commands.CommandManager")
local MoveCommand      = require("ui_editor.commands.MoveCommand")
local ResizeCommand    = require("ui_editor.commands.ResizeCommand")
local SnapSystem       = require("ui_editor.interaction.SnapSystem")

local CanvasWidget = UI.Widget:Extend("CanvasWidget")

--- 缩放手柄方向到 dx/dy 影响的映射
local HANDLE_DIR = {
    tl = { dx = -1, dy = -1 },
    t  = { dx =  0, dy = -1 },
    tr = { dx =  1, dy = -1 },
    l  = { dx = -1, dy =  0 },
    r  = { dx =  1, dy =  0 },
    bl = { dx = -1, dy =  1 },
    b  = { dx =  0, dy =  1 },
    br = { dx =  1, dy =  1 },
}

function CanvasWidget:Init(props)
    props = props or {}
    props.backgroundColor = props.backgroundColor or { 18, 18, 28, 255 }
    props.pointerEvents = "auto"
    props.overflow = "hidden"

    UI.Widget.Init(self, props)

    ---@type table EditorState (injected from main)
    self.editorState_ = props.editorState

    -- 拖拽状态
    self.isPanning_     = false
    self.panStartX_     = 0
    self.panStartY_     = 0
    self.panStartOffX_  = 0
    self.panStartOffY_  = 0

    -- 移动节点的拖拽
    self.isDraggingNode_ = false
    self.dragNodeStartPositions_ = {}  -- {[id] = {x, y}}
    self.dragStartCX_ = 0
    self.dragStartCY_ = 0
    self.hasDragMoved_ = false  -- 是否真正移动了（避免点击时生成命令）

    -- 缩放拖拽
    self.isResizing_ = false
    self.resizeHandle_ = nil
    self.resizeNodeId_ = nil
    self.resizeOriginal_ = nil  -- {x, y, w, h}
    self.resizeStartCX_ = 0
    self.resizeStartCY_ = 0

    -- 框选
    self.isBoxSelecting_ = false
    self.boxStartSX_ = 0
    self.boxStartSY_ = 0
    self.boxEndSX_   = 0
    self.boxEndSY_   = 0

    -- 吸附辅助线（每帧更新）
    self.snapGuides_ = {}
end

--- 获取画布区域的屏幕位置和尺寸
function CanvasWidget:getCanvasRect()
    local l = self:GetAbsoluteLayout()
    return l.x, l.y, l.w, l.h
end

-- ========== 渲染 ==========

function CanvasWidget:Render(nvg)
    local l = self:GetAbsoluteLayout()
    local state = self.editorState_
    if not state then return end

    -- 裁剪到画布区域
    nvgSave(nvg)
    nvgIntersectScissor(nvg, l.x, l.y, l.w, l.h)

    -- 1. 背景
    nvgBeginPath(nvg)
    nvgRect(nvg, l.x, l.y, l.w, l.h)
    nvgFillColor(nvg, nvgRGBA(18, 18, 28, 255))
    nvgFill(nvg)

    -- 2. 网格
    GridRenderer.Draw(nvg, state, l.w, l.h, l.x, l.y)

    -- 3. 所有节点（按渲染顺序）
    local ordered = state:getRenderOrder()
    for _, nodeId in ipairs(ordered) do
        local node = state.nodes[nodeId]
        if node and node.visible then
            local ax, ay = state:getAbsolutePosition(nodeId)
            local sx, sy = CoordTransform.CanvasToScreen(state, ax, ay)
            local sw, sh = CoordTransform.CanvasSizeToScreen(state, node.width, node.height)
            sx = sx + l.x
            sy = sy + l.y
            NodeRenderer.Draw(nvg, node, sx, sy, sw, sh)
        end
    end

    -- 4. 选中高亮 + 手柄
    for _, selId in ipairs(state.selection) do
        local node = state.nodes[selId]
        if node then
            local ax, ay = state:getAbsolutePosition(selId)
            local sx, sy = CoordTransform.CanvasToScreen(state, ax, ay)
            local sw, sh = CoordTransform.CanvasSizeToScreen(state, node.width, node.height)
            sx = sx + l.x
            sy = sy + l.y
            SelectionOverlay.DrawHighlight(nvg, sx, sy, sw, sh)
            -- 单选时显示手柄
            if #state.selection == 1 then
                SelectionOverlay.DrawHandles(nvg, sx, sy, sw, sh)
            end
        end
    end

    -- 5. 吸附辅助线
    if #self.snapGuides_ > 0 then
        SnapSystem.DrawGuides(nvg, self.snapGuides_, state, l.x, l.y)
    end

    -- 6. 框选矩形
    if self.isBoxSelecting_ then
        SelectionOverlay.DrawSelectBox(nvg,
            self.boxStartSX_, self.boxStartSY_,
            self.boxEndSX_, self.boxEndSY_)
    end

    -- 7. 状态信息
    self:renderStatusBar(nvg, l)

    nvgRestore(nvg)
end

--- 渲染底部状态栏
function CanvasWidget:renderStatusBar(nvg, l)
    local state = self.editorState_
    local barH = 24
    local barY = l.y + l.h - barH

    nvgBeginPath(nvg)
    nvgRect(nvg, l.x, barY, l.w, barH)
    nvgFillColor(nvg, nvgRGBA(30, 30, 45, 220))
    nvgFill(nvg)

    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 11)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(180, 180, 200, 200))

    local zoomPct = math.floor(state.canvas_zoom * 100)
    local cmdInfo = CommandManager.GetInfo(state)
    local info = string.format("缩放: %d%%  |  节点: %d  |  选中: %d  |  撤销: %d  重做: %d",
        zoomPct, self:countNodes(), #state.selection, cmdInfo.undoCount, cmdInfo.redoCount)
    nvgText(nvg, l.x + 8, barY + barH / 2, info)
end

function CanvasWidget:countNodes()
    local count = 0
    for _ in pairs(self.editorState_.nodes) do
        count = count + 1
    end
    return count - 1  -- 不计根节点
end

-- ========== 鼠标交互 ==========

--- 指针按下
function CanvasWidget:OnPointerDown(event)
    local state = self.editorState_
    local l = self:GetAbsoluteLayout()

    print(string.format("[CanvasWidget] OnPointerDown button=%s event.x=%.1f event.y=%.1f layout={x=%.1f y=%.1f w=%.1f h=%.1f} MOUSEB_LEFT=%s MOUSEB_MIDDLE=%s",
        tostring(event.button), event.x, event.y, l.x, l.y, l.w, l.h,
        tostring(MOUSEB_LEFT), tostring(MOUSEB_MIDDLE)))

    local localX = event.x - l.x
    local localY = event.y - l.y

    -- 中键拖拽画布
    if event.button == MOUSEB_MIDDLE then
        self.isPanning_ = true
        self.panStartX_ = event.x
        self.panStartY_ = event.y
        self.panStartOffX_ = state.canvas_offset_x
        self.panStartOffY_ = state.canvas_offset_y
        event:StopPropagation()
        return
    end

    -- 左键
    if event.button == MOUSEB_LEFT then
        local cx, cy = CoordTransform.ScreenToCanvas(state, localX, localY)
        local shiftDown = input:GetQualifierDown(QUAL_SHIFT)

        print(string.format("[CanvasWidget] LEFT click: local=(%.1f,%.1f) canvas=(%.1f,%.1f) zoom=%.2f offset=(%.1f,%.1f)",
            localX, localY, cx, cy, state.canvas_zoom, state.canvas_offset_x, state.canvas_offset_y))

        -- 检测手柄点击（只有单选时）
        if #state.selection == 1 then
            local selNode = state.nodes[state.selection[1]]
            if selNode and not selNode.locked then
                local ax, ay = state:getAbsolutePosition(selNode.id)
                local sx, sy = CoordTransform.CanvasToScreen(state, ax, ay)
                local sw, sh = CoordTransform.CanvasSizeToScreen(state, selNode.width, selNode.height)
                sx = sx + l.x
                sy = sy + l.y
                local handle = SelectionOverlay.HitTestHandle(event.x, event.y, sx, sy, sw, sh)
                if handle then
                    -- 开始缩放拖拽
                    self.isResizing_ = true
                    self.resizeHandle_ = handle
                    self.resizeNodeId_ = selNode.id
                    self.resizeStartCX_ = cx
                    self.resizeStartCY_ = cy
                    self.resizeOriginal_ = {
                        x = selNode.x, y = selNode.y,
                        w = selNode.width, h = selNode.height,
                    }
                    event:StopPropagation()
                    return
                end
            end
        end

        -- 检测节点点击
        local hitId = HitTest.FindNodeAt(state, cx, cy)

        print(string.format("[CanvasWidget] HitTest result: hitId=%s, nodeCount=%d, selCount=%d",
            tostring(hitId), self:countNodes(), #state.selection))

        if hitId then
            -- 检查是否锁定
            local hitNode = state.nodes[hitId]
            if hitNode and hitNode.locked then
                -- 锁定节点不可拖拽，但可以选中
                if shiftDown then
                    state:toggleSelection(hitId)
                else
                    state:selectNode(hitId)
                end
                event:StopPropagation()
                return
            end

            if shiftDown then
                state:toggleSelection(hitId)
            else
                if not state:isSelected(hitId) then
                    state:selectNode(hitId)
                end
            end

            -- 开始拖拽移动
            self.isDraggingNode_ = true
            self.hasDragMoved_ = false
            self.dragStartCX_ = cx
            self.dragStartCY_ = cy
            self.dragNodeStartPositions_ = {}
            for _, sid in ipairs(state.selection) do
                local sn = state.nodes[sid]
                if sn and not sn.locked then
                    self.dragNodeStartPositions_[sid] = { x = sn.x, y = sn.y }
                end
            end
        else
            -- 点击空白处
            if not shiftDown then
                state:clearSelection()
            end
            -- 开始框选
            self.isBoxSelecting_ = true
            self.boxStartSX_ = event.x
            self.boxStartSY_ = event.y
            self.boxEndSX_ = event.x
            self.boxEndSY_ = event.y
        end

        event:StopPropagation()
    end
end

--- 指针移动
function CanvasWidget:OnPointerMove(event)
    local state = self.editorState_
    local l = self:GetAbsoluteLayout()

    -- 画布平移
    if self.isPanning_ then
        local dx = event.x - self.panStartX_
        local dy = event.y - self.panStartY_
        state.canvas_offset_x = self.panStartOffX_ + dx
        state.canvas_offset_y = self.panStartOffY_ + dy
        return
    end

    -- 节点拖拽移动（拖拽期间直接修改位置，释放时创建命令）
    if self.isDraggingNode_ then
        local localX = event.x - l.x
        local localY = event.y - l.y
        local cx, cy = CoordTransform.ScreenToCanvas(state, localX, localY)
        local rawDx = cx - self.dragStartCX_
        local rawDy = cy - self.dragStartCY_

        -- 忽略微小移动
        if not self.hasDragMoved_ then
            if math.abs(rawDx) < 1 and math.abs(rawDy) < 1 then
                return
            end
            self.hasDragMoved_ = true
        end

        -- 吸附
        local movingIds = {}
        for sid, _ in pairs(self.dragNodeStartPositions_) do
            table.insert(movingIds, sid)
        end
        local snapDx, snapDy, guides = SnapSystem.CalcSnap(state, movingIds, rawDx, rawDy)
        self.snapGuides_ = guides

        -- 应用位置
        for sid, orig in pairs(self.dragNodeStartPositions_) do
            local node = state.nodes[sid]
            if node then
                node.x = orig.x + snapDx
                node.y = orig.y + snapDy
            end
        end
        return
    end

    -- 缩放拖拽
    if self.isResizing_ then
        local localX = event.x - l.x
        local localY = event.y - l.y
        local cx, cy = CoordTransform.ScreenToCanvas(state, localX, localY)
        local dcx = cx - self.resizeStartCX_
        local dcy = cy - self.resizeStartCY_

        local node = state.nodes[self.resizeNodeId_]
        if node then
            local orig = self.resizeOriginal_
            local dir = HANDLE_DIR[self.resizeHandle_]
            if dir then
                local newX = orig.x
                local newY = orig.y
                local newW = orig.w
                local newH = orig.h

                -- X 方向
                if dir.dx == -1 then
                    newX = orig.x + dcx
                    newW = orig.w - dcx
                elseif dir.dx == 1 then
                    newW = orig.w + dcx
                end

                -- Y 方向
                if dir.dy == -1 then
                    newY = orig.y + dcy
                    newH = orig.h - dcy
                elseif dir.dy == 1 then
                    newH = orig.h + dcy
                end

                -- 最小尺寸限制
                local MIN_SIZE = 10
                if newW < MIN_SIZE then
                    if dir.dx == -1 then
                        newX = orig.x + orig.w - MIN_SIZE
                    end
                    newW = MIN_SIZE
                end
                if newH < MIN_SIZE then
                    if dir.dy == -1 then
                        newY = orig.y + orig.h - MIN_SIZE
                    end
                    newH = MIN_SIZE
                end

                node.x = newX
                node.y = newY
                node.width = newW
                node.height = newH
            end
        end
        return
    end

    -- 框选拖拽
    if self.isBoxSelecting_ then
        self.boxEndSX_ = event.x
        self.boxEndSY_ = event.y
        return
    end
end

--- 指针释放
function CanvasWidget:OnPointerUp(event)
    local state = self.editorState_
    local l = self:GetAbsoluteLayout()

    -- 结束画布平移
    if self.isPanning_ and event.button == MOUSEB_MIDDLE then
        self.isPanning_ = false
        return
    end

    if event.button == MOUSEB_LEFT then
        -- 结束节点拖拽 → 创建 MoveCommand
        if self.isDraggingNode_ then
            self.isDraggingNode_ = false
            self.snapGuides_ = {}  -- 清除辅助线

            if self.hasDragMoved_ then
                -- 计算实际偏移
                local firstId = nil
                local dx, dy = 0, 0
                local nodeIds = {}
                for sid, orig in pairs(self.dragNodeStartPositions_) do
                    local node = state.nodes[sid]
                    if node then
                        if not firstId then
                            dx = node.x - orig.x
                            dy = node.y - orig.y
                            firstId = sid
                        end
                        table.insert(nodeIds, sid)
                    end
                end

                if firstId and (math.abs(dx) > 0.01 or math.abs(dy) > 0.01) then
                    -- 先恢复到原始位置，再由命令执行移动
                    for sid, orig in pairs(self.dragNodeStartPositions_) do
                        local node = state.nodes[sid]
                        if node then
                            node.x = orig.x
                            node.y = orig.y
                        end
                    end
                    local cmd = MoveCommand.New(nodeIds, dx, dy, self.dragNodeStartPositions_)
                    CommandManager.Execute(state, cmd)
                end
            end

            self.dragNodeStartPositions_ = {}
            self.hasDragMoved_ = false
        end

        -- 结束缩放拖拽 → 创建 ResizeCommand
        if self.isResizing_ then
            self.isResizing_ = false
            local node = state.nodes[self.resizeNodeId_]
            local orig = self.resizeOriginal_
            if node and orig then
                local newRect = { x = node.x, y = node.y, w = node.width, h = node.height }
                local changed = (orig.x ~= newRect.x) or (orig.y ~= newRect.y)
                    or (orig.w ~= newRect.w) or (orig.h ~= newRect.h)

                if changed then
                    -- 恢复到原始值，由命令执行
                    node.x = orig.x
                    node.y = orig.y
                    node.width = orig.w
                    node.height = orig.h
                    local cmd = ResizeCommand.New(self.resizeNodeId_, orig, newRect)
                    CommandManager.Execute(state, cmd)
                end
            end
            self.resizeHandle_ = nil
            self.resizeNodeId_ = nil
            self.resizeOriginal_ = nil
        end

        -- 结束框选
        if self.isBoxSelecting_ then
            self.isBoxSelecting_ = false
            local localX1 = self.boxStartSX_ - l.x
            local localY1 = self.boxStartSY_ - l.y
            local localX2 = self.boxEndSX_ - l.x
            local localY2 = self.boxEndSY_ - l.y
            local cx1, cy1 = CoordTransform.ScreenToCanvas(state, localX1, localY1)
            local cx2, cy2 = CoordTransform.ScreenToCanvas(state, localX2, localY2)
            local ids = HitTest.FindNodesInRect(state, cx1, cy1, cx2, cy2)
            if #ids > 0 then
                state.selection = ids
            end
        end
    end
end

--- 鼠标滚轮缩放
function CanvasWidget:OnWheel(dx, dy)
    local state = self.editorState_
    local l = self:GetAbsoluteLayout()

    local mx = input:GetMousePosition().x
    local my = input:GetMousePosition().y
    local dpr = graphics:GetDPR()
    mx = mx / dpr
    my = my / dpr

    local localX = mx - l.x
    local localY = my - l.y

    -- 缩放前的画布坐标
    local cxBefore, cyBefore = CoordTransform.ScreenToCanvas(state, localX, localY)

    -- 缩放
    local zoomFactor = 1.1
    if dy > 0 then
        state.canvas_zoom = math.min(4.0, state.canvas_zoom * zoomFactor)
    elseif dy < 0 then
        state.canvas_zoom = math.max(0.25, state.canvas_zoom / zoomFactor)
    end

    -- 缩放后让鼠标指向的画布点不动
    local sxAfter, syAfter = CoordTransform.CanvasToScreen(state, cxBefore, cyBefore)
    state.canvas_offset_x = state.canvas_offset_x + (localX - sxAfter)
    state.canvas_offset_y = state.canvas_offset_y + (localY - syAfter)
end

return CanvasWidget
