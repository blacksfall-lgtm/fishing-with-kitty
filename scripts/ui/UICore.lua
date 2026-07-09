-- ============================================================================
-- UICore: 设计坐标系、颜色体系、公共绘制函数
-- 设计分辨率 1080 x 2400（竖屏）
-- 主题：海洋青蓝色系（猫猫钓鱼记）
-- ============================================================================
local UICore = {}

UICore.DESIGN_W = 1080
UICore.DESIGN_H = 2400

-- 当前缩放比（每帧由 beginDesign 更新）
local scaleX_ = 1.0
local scaleY_ = 1.0

-- ============================================================================
-- 初始化
-- ============================================================================
function UICore.init(nvg)
    nvgCreateFont(nvg, "sans", "Fonts/MiSans-Regular.ttf")
end

-- ============================================================================
-- 帧开始：建立设计坐标系（非等比，适合 HUD/UI 元素定位）
-- 在 nvgBeginFrame 之后调用，所有绘制使用 1080x2400 坐标
-- ============================================================================
function UICore.beginDesign(nvg, w, h)
    scaleX_ = w / UICore.DESIGN_W
    scaleY_ = h / UICore.DESIGN_H
    nvgSave(nvg)
    nvgScale(nvg, scaleX_, scaleY_)
end

-- ============================================================================
-- 帧开始：等比缩放（以宽度锁定，适合世界/场景渲染）
-- 返回：设计空间中实际可见的屏幕高度
-- ============================================================================
function UICore.beginDesignW(nvg, w, h)
    scaleX_ = w / UICore.DESIGN_W
    scaleY_ = scaleX_
    nvgSave(nvg)
    nvgScale(nvg, scaleX_, scaleY_)
    return h / scaleX_
end

function UICore.endDesign(nvg)
    nvgRestore(nvg)
end

-- ============================================================================
-- 坐标转换：屏幕逻辑坐标 → 设计坐标（用于输入处理）
-- ============================================================================
function UICore.toDesign(sx, sy)
    return sx / scaleX_, sy / scaleY_
end

function UICore.getScale()
    return scaleX_, scaleY_
end

-- ============================================================================
-- 颜色体系（海洋青蓝主题 - 猫猫钓鱼记）
-- ============================================================================

-- 面板深海蓝（主面板背景）
UICore.C_PANEL       = { 12,  48,  95 }
-- 面板内底浅蓝（内容区背景）
UICore.C_PANEL_BG    = { 195, 228, 255 }
-- 面板标题色（亮白蓝）
UICore.C_TITLE       = { 235, 248, 255 }
-- 属性条青蓝
UICore.C_ATTR_BAR    = { 52, 148, 210 }
-- 描边深色（文字描边/面板外边框）
UICore.C_STROKE      = {  5,  18,  55 }
-- HUD 文字描边（纯黑）
UICore.C_STROKE_HUD  = {  0,   0,   0 }
-- 金币金黄
UICore.C_COIN        = { 255, 220,  40 }
-- 宝石青（分隔线/边框高亮）
UICore.C_GEM         = {  60, 210, 248 }
-- 遮罩黑
UICore.C_MASK_COLOR  = {  0,   0,   0 }
-- 按钮激活高亮
UICore.C_BTN_ACTIVE  = { 28,  88, 168 }
-- 危险/警告红
UICore.C_DANGER      = { 220,  50,  50 }

-- 品质色（6级，与 SKILL.md 一致）
UICore.QUALITY_COLORS = {
    { 181, 181, 181 },   -- 1 普通 灰
    { 162, 255, 148 },   -- 2 优质 绿
    { 114, 242, 245 },   -- 3 稀有 青
    { 239, 121, 255 },   -- 4 史诗 紫
    { 255, 237,   0 },   -- 5 传说 金
    { 255,   0,   0 },   -- 6 至臻 红
}

UICore.QUALITY_NAMES = { "普通", "优质", "稀有", "史诗", "传说", "至臻" }

function UICore.qualityColor(q)
    return UICore.QUALITY_COLORS[math.max(1, math.min(6, q or 1))]
end

function UICore.qualityName(q)
    return UICore.QUALITY_NAMES[math.max(1, math.min(6, q or 1))]
end

-- 快捷颜色构造
function UICore.rgba(c, a)
    return nvgRGBA(c[1], c[2], c[3], a or 255)
end

-- ============================================================================
-- 字号层级（对应 SKILL.md 规范）
-- ============================================================================
UICore.FS_SUPER     = 120  -- 全屏标题
UICore.FS_LARGE     = 80   -- 章节名
UICore.FS_HEADING   = 58   -- 面板标题、按钮文字
UICore.FS_BODY      = 48   -- 武器名、波次、品质文字
UICore.FS_SMALL     = 38   -- 属性值、描述
UICore.FS_TINY      = 34   -- 商店描述、标签

-- ============================================================================
-- 描边文字（16方向圆形偏移）
-- align 默认居中，sw 默认 3
-- ============================================================================
function UICore.strokeText(nvg, text, x, y, fontSize, fillC, strokeC, sw, align)
    align = align or (NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    sw    = sw    or 3
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, fontSize)
    nvgTextAlign(nvg, align)
    -- 描边层（16方向）
    nvgFillColor(nvg, nvgRGBA(strokeC[1], strokeC[2], strokeC[3], 255))
    for i = 0, 15 do
        local a = i * math.pi / 8
        nvgText(nvg, x + math.cos(a) * sw, y + math.sin(a) * sw, text)
    end
    -- 填充层
    nvgFillColor(nvg, nvgRGBA(fillC[1], fillC[2], fillC[3], 255))
    nvgText(nvg, x, y, text)
end

-- 带透明度版本
function UICore.strokeTextA(nvg, text, x, y, fontSize, fillC, fillA, strokeC, sw, align)
    align = align or (NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    sw    = sw    or 3
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, fontSize)
    nvgTextAlign(nvg, align)
    nvgFillColor(nvg, nvgRGBA(strokeC[1], strokeC[2], strokeC[3], math.floor(fillA * 0.8)))
    for i = 0, 15 do
        local a = i * math.pi / 8
        nvgText(nvg, x + math.cos(a) * sw, y + math.sin(a) * sw, text)
    end
    nvgFillColor(nvg, nvgRGBA(fillC[1], fillC[2], fillC[3], fillA))
    nvgText(nvg, x, y, text)
end

-- ============================================================================
-- 常用图形助手
-- ============================================================================

--- 填充圆角矩形
function UICore.fillRRect(nvg, x, y, w, h, r, c, alpha)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, r)
    nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], alpha or 255))
    nvgFill(nvg)
end

--- 描边圆角矩形
function UICore.strokeRRect(nvg, x, y, w, h, r, c, lw, alpha)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, r)
    nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], alpha or 255))
    nvgStrokeWidth(nvg, lw or 2)
    nvgStroke(nvg)
end

--- 渐变填充圆角矩形（垂直）
function UICore.fillRRectGrad(nvg, x, y, w, h, r, cTop, aTop, cBot, aBot)
    local grad = nvgLinearGradient(nvg, x, y, x, y + h,
        nvgRGBA(cTop[1], cTop[2], cTop[3], aTop),
        nvgRGBA(cBot[1], cBot[2], cBot[3], aBot))
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, r)
    nvgFillPaint(nvg, grad)
    nvgFill(nvg)
end

--- 标准面板背景（深色背景 + 亮色边框）
function UICore.drawPanel(nvg, x, y, w, h, r)
    r = r or 20
    -- 深色主背景
    UICore.fillRRectGrad(nvg, x, y, w, h, r,
        { 12, 55, 108 }, 245,
        {  8, 38,  82 }, 250)
    -- 边框高亮
    UICore.strokeRRect(nvg, x, y, w, h, r, UICore.C_GEM, 2, 140)
end

--- 标准面板标题栏
function UICore.drawPanelTitle(nvg, x, y, w, title)
    local th = 76
    UICore.fillRRectGrad(nvg, x, y, w, th, 0,
        { 20, 72, 140 }, 220,
        { 12, 52, 110 }, 200)
    UICore.strokeText(nvg, title,
        x + w * 0.5, y + th * 0.5,
        UICore.FS_HEADING, UICore.C_TITLE, UICore.C_STROKE, 5,
        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    return th
end

--- 全屏黑色遮罩
function UICore.drawMask(nvg, alpha)
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, UICore.DESIGN_W, UICore.DESIGN_H)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, alpha or 160))
    nvgFill(nvg)
end

--- 绘制图片（中心坐标）
function UICore.drawImage(nvg, img, cx, cy, w, h, alpha)
    if not img or img <= 0 then return end
    local pat = nvgImagePattern(nvg, cx - w * 0.5, cy - h * 0.5, w, h, 0, img, alpha or 1.0)
    nvgBeginPath(nvg)
    nvgRect(nvg, cx - w * 0.5, cy - h * 0.5, w, h)
    nvgFillPaint(nvg, pat)
    nvgFill(nvg)
end

--- 绘制图片（左上角坐标）
function UICore.drawImageTL(nvg, img, x, y, w, h, alpha)
    if not img or img <= 0 then return end
    local pat = nvgImagePattern(nvg, x, y, w, h, 0, img, alpha or 1.0)
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillPaint(nvg, pat)
    nvgFill(nvg)
end

--- 绘制进度条（带 scissor 裁剪）
function UICore.drawProgressBar(nvg, x, y, w, h, r, percent,
                                bgC, bgA, fillC, fillA)
    percent = math.max(0, math.min(1, percent))
    -- 底层背景
    UICore.fillRRect(nvg, x, y, w, h, r, bgC, bgA)
    -- 前景（scissor 裁剪宽度）
    if percent > 0 then
        nvgSave(nvg)
        nvgScissor(nvg, x, y, w * percent, h)
        UICore.fillRRect(nvg, x, y, w, h, r, fillC, fillA)
        nvgRestore(nvg)
    end
end

--- 品质着色图片
function UICore.drawQualityImage(nvg, img, cx, cy, w, h, quality, alpha)
    if not img or img <= 0 then return end
    alpha = alpha or 1.0
    local qc = UICore.qualityColor(quality)
    local pat = nvgImagePattern(nvg, cx - w * 0.5, cy - h * 0.5, w, h, 0, img, alpha)
    pat.innerColor = nvgRGBA(qc[1], qc[2], qc[3], math.floor(alpha * 255))
    nvgBeginPath(nvg)
    nvgRect(nvg, cx - w * 0.5, cy - h * 0.5, w, h)
    nvgFillPaint(nvg, pat)
    nvgFill(nvg)
end

--- 标准 Toast（设计坐标空间内）
function UICore.drawToast(nvg, msg, timer, maxTimer)
    if timer <= 0 then return end
    local alpha = math.min(1, timer * 3) * math.min(1, (maxTimer - (maxTimer - timer)) * 4)
    alpha = math.min(1, timer * 2)

    nvgSave(nvg)
    nvgGlobalAlpha(nvg, alpha)

    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, UICore.FS_SMALL)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    local tw = nvgTextBounds(nvg, 0, 0, msg)
    local tx = UICore.DESIGN_W * 0.5
    local ty = UICore.DESIGN_H * 0.42

    UICore.fillRRect(nvg, tx - tw * 0.5 - 40, ty - 32, tw + 80, 64, 16,
        { 0, 0, 0 }, 200)
    UICore.strokeRRect(nvg, tx - tw * 0.5 - 40, ty - 32, tw + 80, 64, 16,
        UICore.C_GEM, 1.5, 160)
    UICore.strokeText(nvg, msg, tx, ty,
        UICore.FS_SMALL, UICore.C_TITLE, UICore.C_STROKE, 3,
        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    nvgRestore(nvg)
end

-- ============================================================================
-- 弹窗容器（遮罩 + 缩放淡入动画）
-- t: 0→1 动画进度，调用方控制
-- 返回：panelX, panelY（面板左上角，设计坐标）
-- ============================================================================
function UICore.beginPopup(nvg, t, cx, cy, pw, ph)
    -- 背景遮罩
    local maskAlpha = math.floor(t * 160)
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, UICore.DESIGN_W, UICore.DESIGN_H)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, maskAlpha))
    nvgFill(nvg)

    -- 缩放淡入（0.25s easeOutCubic: 85% → 100%）
    local scale = 0.85 + 0.15 * t
    nvgGlobalAlpha(nvg, t)
    nvgSave(nvg)
    nvgTranslate(nvg, cx, cy)
    nvgScale(nvg, scale, scale)
    nvgTranslate(nvg, -pw * 0.5, -ph * 0.5)

    return 0, 0  -- 已经translate过，面板从(0,0)开始
end

function UICore.endPopup(nvg)
    nvgRestore(nvg)
    nvgGlobalAlpha(nvg, 1.0)
end

-- ============================================================================
-- 缓动函数
-- ============================================================================
function UICore.easeOutCubic(t)
    t = math.max(0, math.min(1, t))
    t = 1 - t
    return 1 - t * t * t
end

function UICore.easeOutBack(t)
    t = math.max(0, math.min(1, t))
    local c1 = 1.70158
    local c3 = c1 + 1
    return 1 + c3 * (t - 1)^3 + c1 * (t - 1)^2
end

function UICore.easeOutBounce(t)
    t = math.max(0, math.min(1, t))
    local n1 = 7.5625
    local d1 = 2.75
    if t < 1 / d1 then
        return n1 * t * t
    elseif t < 2 / d1 then
        t = t - 1.5 / d1
        return n1 * t * t + 0.75
    elseif t < 2.5 / d1 then
        t = t - 2.25 / d1
        return n1 * t * t + 0.9375
    else
        t = t - 2.625 / d1
        return n1 * t * t + 0.984375
    end
end

-- ============================================================================
-- 返回按钮（左上角标准样式）
-- ============================================================================
function UICore.drawBackButton(nvg, x, y, w, h)
    w = w or 120
    h = h or 80
    UICore.fillRRect(nvg, x, y, w, h, 14, UICore.C_PANEL, 220)
    UICore.strokeRRect(nvg, x, y, w, h, 14, UICore.C_GEM, 1.5, 160)
    UICore.strokeText(nvg, "‹ 返回",
        x + w * 0.5, y + h * 0.5,
        UICore.FS_SMALL, UICore.C_TITLE, UICore.C_STROKE, 3,
        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
end

return UICore
