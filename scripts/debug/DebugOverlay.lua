-- ============================================================================
-- DebugOverlay: 调试模式高亮覆盖层
-- 在游戏画面上方绘制 UI 区域高亮框，支持点击选中
-- ============================================================================

local UI = require("urhox-libs/UI")
local WaterScene = require("ui.WaterScene")

local DebugOverlay = UI.Widget:Extend("DebugOverlay")

function DebugOverlay:Init(props)
    props = props or {}
    props.width = "100%"
    props.height = "100%"
    props.pointerEvents = "auto"
    props.backgroundColor = { 0, 0, 0, 0 }  -- 透明背景

    UI.Widget.Init(self, props)

    self.selectedRegion_ = nil   -- 当前选中的区域
    self.hoveredRegion_ = nil    -- 当前悬停的区域
    self.onRegionSelected = props.onRegionSelected  -- 选中回调
end

function DebugOverlay:Render(nvg)
    local layout = self:GetLayout()
    if not layout then return end

    -- 获取当前所有 UI 区域
    local regions = WaterScene.getUIRegions()

    -- 绘制所有区域的高亮框
    for _, region in ipairs(regions) do
        local isSelected = self.selectedRegion_ and self.selectedRegion_.name == region.name
        local isHovered = self.hoveredRegion_ and self.hoveredRegion_.name == region.name

        nvgBeginPath(nvg)
        nvgRect(nvg, region.x, region.y, region.w, region.h)

        if isSelected then
            -- 选中: 蓝色填充 + 粗边框
            nvgFillColor(nvg, nvgRGBA(30, 120, 255, 50))
            nvgFill(nvg)
            nvgStrokeColor(nvg, nvgRGBA(30, 120, 255, 220))
            nvgStrokeWidth(nvg, 2.5)
            nvgStroke(nvg)
        elseif isHovered then
            -- 悬停: 绿色填充 + 边框
            nvgFillColor(nvg, nvgRGBA(80, 220, 120, 40))
            nvgFill(nvg)
            nvgStrokeColor(nvg, nvgRGBA(80, 220, 120, 200))
            nvgStrokeWidth(nvg, 2.0)
            nvgStroke(nvg)
        else
            -- 普通: 半透明白边框
            nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, 120))
            nvgStrokeWidth(nvg, 1.0)
            nvgStroke(nvg)
        end

        -- 绘制区域名称标签
        nvgFontSize(nvg, 11)
        nvgFontFace(nvg, "sans")
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

        -- 标签背景
        local labelY = region.y - 16
        if labelY < 2 then labelY = region.y + 2 end
        local tw = nvgTextBounds(nvg, 0, 0, region.name)
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, region.x, labelY, tw + 8, 14, 3)
        if isSelected then
            nvgFillColor(nvg, nvgRGBA(30, 120, 255, 200))
        elseif isHovered then
            nvgFillColor(nvg, nvgRGBA(80, 220, 120, 180))
        else
            nvgFillColor(nvg, nvgRGBA(0, 0, 0, 160))
        end
        nvgFill(nvg)

        -- 标签文字
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 230))
        nvgText(nvg, region.x + 4, labelY + 1, region.name)
    end

    -- 底部状态栏
    local physW = graphics:GetWidth()
    local dpr = graphics:GetDPR()
    local logW = physW / dpr
    local logH = graphics:GetHeight() / dpr

    nvgBeginPath(nvg)
    nvgRect(nvg, 0, logH - 28, logW, 28)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 180))
    nvgFill(nvg)

    nvgFontSize(nvg, 13)
    nvgFontFace(nvg, "sans")
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(100, 220, 255, 230))

    local statusText = "[DEBUG] Ctrl+D=退出  Ctrl+E=编辑器"
    if self.selectedRegion_ then
        statusText = statusText .. string.format("  | 选中: %s (%.0f,%.0f %0.fx%.0f)",
            self.selectedRegion_.name,
            self.selectedRegion_.x, self.selectedRegion_.y,
            self.selectedRegion_.w, self.selectedRegion_.h)
    end
    nvgText(nvg, 8, logH - 14, statusText)
end

function DebugOverlay:OnPointerDown(event)
    local layout = self:GetLayout()
    if not layout then return end
    local lx = event.x - layout.x
    local ly = event.y - layout.y

    -- 检测点击了哪个区域
    local regions = WaterScene.getUIRegions()
    local hit = nil
    for _, region in ipairs(regions) do
        if lx >= region.x and lx <= region.x + region.w
           and ly >= region.y and ly <= region.y + region.h then
            hit = region
        end
    end

    self.selectedRegion_ = hit
    if hit and self.onRegionSelected then
        self.onRegionSelected(hit)
    end
end

function DebugOverlay:OnPointerMove(event)
    local layout = self:GetLayout()
    if not layout then return end
    local lx = event.x - layout.x
    local ly = event.y - layout.y

    local regions = WaterScene.getUIRegions()
    local hit = nil
    for _, region in ipairs(regions) do
        if lx >= region.x and lx <= region.x + region.w
           and ly >= region.y and ly <= region.y + region.h then
            hit = region
        end
    end
    self.hoveredRegion_ = hit
end

--- 获取当前选中的区域
function DebugOverlay:GetSelectedRegion()
    return self.selectedRegion_
end

--- 清除选中
function DebugOverlay:ClearSelection()
    self.selectedRegion_ = nil
end

return DebugOverlay
