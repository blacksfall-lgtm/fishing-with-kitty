-- ============================================================================
-- NodeRenderer: 单个节点渲染（按 type 分发）
-- ============================================================================

local NodeRenderer = {}

-- NanoVG 图片缓存 { [path] = nvgImageHandle }
local imageCache_ = {}

--- 获取或创建 NanoVG 图片句柄 (自动缓存)
---@param nvg userdata
---@param path string 图片路径
---@return number handle (0 表示失败)
local function getImage(nvg, path)
    if not path or path == "" then return 0 end
    if imageCache_[path] then return imageCache_[path] end
    local handle = nvgCreateImage(nvg, path, 0)
    if handle and handle > 0 then
        imageCache_[path] = handle
    else
        handle = 0
    end
    return handle
end

--- 解析 #RRGGBB 或 #RRGGBBAA 颜色字符串
---@param hex string
---@return number r, number g, number b, number a
local function parseColor(hex)
    if not hex or #hex < 7 then return 128, 128, 128, 255 end
    local r = tonumber(hex:sub(2, 3), 16) or 128
    local g = tonumber(hex:sub(4, 5), 16) or 128
    local b = tonumber(hex:sub(6, 7), 16) or 128
    local a = 255
    if #hex >= 9 then
        a = tonumber(hex:sub(8, 9), 16) or 255
    end
    return r, g, b, a
end

--- 绘制一个九宫格切片
--- 将源图 (srcX,srcY,srcW,srcH) 区域映射到目标 (dstX,dstY,dstW,dstH)
local function draw9Patch(nvg, handle, imgW, imgH,
                          srcX, srcY, srcW, srcH,
                          dstX, dstY, dstW, dstH, opacity)
    if dstW <= 0 or dstH <= 0 or srcW <= 0 or srcH <= 0 then return end
    local scaleX = dstW / srcW
    local scaleY = dstH / srcH
    local patX = dstX - srcX * scaleX
    local patY = dstY - srcY * scaleY
    local patW = imgW * scaleX
    local patH = imgH * scaleY

    local pat = nvgImagePattern(nvg, patX, patY, patW, patH, 0, handle, opacity)
    nvgBeginPath(nvg)
    nvgRect(nvg, dstX, dstY, dstW, dstH)
    nvgFillPaint(nvg, pat)
    nvgFill(nvg)
end

--- 九宫格渲染：将图片按 slice_border 切成 9 块，四角不拉伸
local function render9Slice(nvg, handle, sx, sy, sw, sh, sliceBorder, opacity, cr)
    local imgW, imgH = nvgImageSize(nvg, handle)
    if imgW <= 0 or imgH <= 0 then return end

    -- 边距不能超过图片尺寸一半
    local b = math.min(sliceBorder, math.floor(imgW / 2), math.floor(imgH / 2))
    if b <= 0 then b = 1 end

    -- 目标边距按比例缩放：保持与源图 border 的视觉比例
    local dbX = b * (sw / imgW)  -- 目标水平边距
    local dbY = b * (sh / imgH)  -- 目标垂直边距
    -- 但也不能超过目标区域的一半
    dbX = math.min(dbX, sw / 2)
    dbY = math.min(dbY, sh / 2)

    nvgSave(nvg)

    -- 如果有圆角，先做裁剪
    if cr and cr > 0 then
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, sx, sy, sw, sh, cr)
        -- NanoVG 没有 clip，用 scissor 近似
        nvgScissor(nvg, sx, sy, sw, sh)
    end

    -- 源区域
    local srcMidW = imgW - b * 2
    local srcMidH = imgH - b * 2

    -- 目标区域
    local dstMidW = sw - dbX * 2
    local dstMidH = sh - dbY * 2

    -- 1. 四角 (不拉伸比例)
    draw9Patch(nvg, handle, imgW, imgH,  0,         0,          b,       b,        sx,          sy,           dbX,     dbY,     opacity) -- 左上
    draw9Patch(nvg, handle, imgW, imgH,  imgW - b,  0,          b,       b,        sx + sw-dbX, sy,           dbX,     dbY,     opacity) -- 右上
    draw9Patch(nvg, handle, imgW, imgH,  0,         imgH - b,   b,       b,        sx,          sy + sh-dbY,  dbX,     dbY,     opacity) -- 左下
    draw9Patch(nvg, handle, imgW, imgH,  imgW - b,  imgH - b,   b,       b,        sx + sw-dbX, sy + sh-dbY,  dbX,     dbY,     opacity) -- 右下

    -- 2. 四边 (单方向拉伸)
    draw9Patch(nvg, handle, imgW, imgH,  b,         0,          srcMidW, b,        sx + dbX,    sy,           dstMidW, dbY,     opacity) -- 上
    draw9Patch(nvg, handle, imgW, imgH,  b,         imgH - b,   srcMidW, b,        sx + dbX,    sy + sh-dbY,  dstMidW, dbY,     opacity) -- 下
    draw9Patch(nvg, handle, imgW, imgH,  0,         b,          b,       srcMidH,  sx,          sy + dbY,     dbX,     dstMidH, opacity) -- 左
    draw9Patch(nvg, handle, imgW, imgH,  imgW - b,  b,          b,       srcMidH,  sx + sw-dbX, sy + dbY,     dbX,     dstMidH, opacity) -- 右

    -- 3. 中心 (双向拉伸)
    draw9Patch(nvg, handle, imgW, imgH,  b,         b,          srcMidW, srcMidH,  sx + dbX,    sy + dbY,     dstMidW, dstMidH, opacity) -- 中

    nvgRestore(nvg)
end

--- 在节点区域内绘制 bg_image (如果有)
--- 支持两种模式: fill (拉伸填充) 和 9slice (九宫格)
---@return boolean 是否绘制了图片
local function renderBgImage(nvg, node, sx, sy, sw, sh)
    local imgPath = node.style.bg_image
    if not imgPath or imgPath == "" then return false end
    local handle = getImage(nvg, imgPath)
    if handle <= 0 then return false end

    local opacity = node.style.opacity or 1.0
    local cr = node.style.corner_radius or 0
    local mode = node.style.bg_image_mode or "fill"

    if mode == "9slice" then
        local sliceBorder = node.style.slice_border or 8
        render9Slice(nvg, handle, sx, sy, sw, sh, sliceBorder, opacity, cr)
        return true
    end

    -- fill/stretch: 图片拉伸填满整个节点区域
    nvgSave(nvg)

    local pat = nvgImagePattern(nvg, sx, sy, sw, sh, 0, handle, opacity)
    nvgBeginPath(nvg)
    if cr > 0 then
        nvgRoundedRect(nvg, sx, sy, sw, sh, cr)
    else
        nvgRect(nvg, sx, sy, sw, sh)
    end
    nvgFillPaint(nvg, pat)
    nvgFill(nvg)

    nvgRestore(nvg)
    return true
end

--- 渲染面板类型节点
local function renderPanel(nvg, node, sx, sy, sw, sh)
    local style = node.style
    local cr = style.corner_radius or 0

    -- 背景
    nvgBeginPath(nvg)
    if cr > 0 then
        nvgRoundedRect(nvg, sx, sy, sw, sh, cr)
    else
        nvgRect(nvg, sx, sy, sw, sh)
    end
    local r, g, b, a = parseColor(style.bg_color)
    a = math.floor(a * (style.opacity or 1.0))
    nvgFillColor(nvg, nvgRGBA(r, g, b, a))
    nvgFill(nvg)

    -- 边框
    local bw = style.border_width or 0
    if bw > 0 then
        nvgBeginPath(nvg)
        if cr > 0 then
            nvgRoundedRect(nvg, sx, sy, sw, sh, cr)
        else
            nvgRect(nvg, sx, sy, sw, sh)
        end
        local br, bg2, bb, ba = parseColor(style.border_color)
        ba = math.floor(ba * (style.opacity or 1.0))
        nvgStrokeColor(nvg, nvgRGBA(br, bg2, bb, ba))
        nvgStrokeWidth(nvg, bw)
        nvgStroke(nvg)
    end
end

--- 渲染按钮类型节点
local function renderButton(nvg, node, sx, sy, sw, sh)
    -- 底色面板 → 图片叠加（透明 PNG 会透出底色）
    renderPanel(nvg, node, sx, sy, sw, sh)
    renderBgImage(nvg, node, sx, sy, sw, sh)

    -- 文本
    local style = node.style
    local text = style.text or ""
    if text ~= "" then
        local fr, fg, fb, fa = parseColor(style.font_color)
        fa = math.floor(fa * (style.opacity or 1.0))
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, style.font_size or 14)

        local align = NVG_ALIGN_MIDDLE
        local textX = sx + sw / 2
        if style.text_align == "left" then
            align = align + NVG_ALIGN_LEFT
            textX = sx + 8
        elseif style.text_align == "right" then
            align = align + NVG_ALIGN_RIGHT
            textX = sx + sw - 8
        else
            align = align + NVG_ALIGN_CENTER
        end

        nvgTextAlign(nvg, align)
        nvgFillColor(nvg, nvgRGBA(fr, fg, fb, fa))
        nvgText(nvg, textX, sy + sh / 2, text)
    end
end

--- 渲染文本类型节点
local function renderText(nvg, node, sx, sy, sw, sh)
    local style = node.style

    -- 背景（如果有）
    local r, g, b, a = parseColor(style.bg_color)
    if a > 0 then
        renderPanel(nvg, node, sx, sy, sw, sh)
    end

    -- 文本
    local text = style.text or ""
    if text ~= "" then
        local fr, fg, fb, fa2 = parseColor(style.font_color)
        fa2 = math.floor(fa2 * (style.opacity or 1.0))
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, style.font_size or 16)

        local align = NVG_ALIGN_MIDDLE
        local textX = sx + 4
        if style.text_align == "center" then
            align = align + NVG_ALIGN_CENTER
            textX = sx + sw / 2
        elseif style.text_align == "right" then
            align = align + NVG_ALIGN_RIGHT
            textX = sx + sw - 4
        else
            align = align + NVG_ALIGN_LEFT
        end

        nvgTextAlign(nvg, align)
        nvgFillColor(nvg, nvgRGBA(fr, fg, fb, fa2))
        nvgText(nvg, textX, sy + sh / 2, text)
    end
end

--- 渲染图片类型节点
local function renderImage(nvg, node, sx, sy, sw, sh)
    -- 底色面板
    renderPanel(nvg, node, sx, sy, sw, sh)
    -- 叠加图片，无图片时显示占位符
    if not renderBgImage(nvg, node, sx, sy, sw, sh) then
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 20)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(150, 150, 160, 180))
        nvgText(nvg, sx + sw / 2, sy + sh / 2, "▨")
    end
end

--- 渲染滑块类型节点
local function renderSlider(nvg, node, sx, sy, sw, sh)
    renderPanel(nvg, node, sx, sy, sw, sh)

    -- 轨道
    local trackH = 4
    local trackY = sy + sh / 2 - trackH / 2
    local margin = 8
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, sx + margin, trackY, sw - margin * 2, trackH, 2)
    nvgFillColor(nvg, nvgRGBA(80, 80, 100, 200))
    nvgFill(nvg)

    -- 填充
    local fillW = (sw - margin * 2) * 0.5
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, sx + margin, trackY, fillW, trackH, 2)
    nvgFillColor(nvg, nvgRGBA(74, 144, 217, 220))
    nvgFill(nvg)

    -- 滑块圆点
    local thumbX = sx + margin + fillW
    nvgBeginPath(nvg)
    nvgCircle(nvg, thumbX, sy + sh / 2, 6)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 240))
    nvgFill(nvg)
end

-- 渲染器分发表
local renderers = {
    panel  = renderPanel,
    button = renderButton,
    text   = renderText,
    image  = renderImage,
    slider = renderSlider,
}

--- 渲染单个节点
---@param nvg userdata
---@param node table EditorNode
---@param sx number 屏幕坐标 X
---@param sy number 屏幕坐标 Y
---@param sw number 屏幕尺寸 W (width * zoom)
---@param sh number 屏幕尺寸 H (height * zoom)
function NodeRenderer.Draw(nvg, node, sx, sy, sw, sh)
    if not node.visible then return end

    local fn = renderers[node.type]
    if fn then
        fn(nvg, node, sx, sy, sw, sh)
    else
        -- 未知类型用默认渲染
        renderPanel(nvg, node, sx, sy, sw, sh)
    end
end

--- 暴露颜色解析工具
NodeRenderer.parseColor = parseColor

return NodeRenderer
