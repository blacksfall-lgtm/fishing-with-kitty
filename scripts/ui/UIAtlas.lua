-- ============================================================================
-- UIAtlas: 通用 UI 图集模块
-- ============================================================================
-- 加载 greySheet.png 精灵图集, 提供按名称绘制子图的能力
-- 所有 UI 元素统一从此模块获取, 保证视觉一致性
--
-- 用法:
--   local UIAtlas = require("ui.UIAtlas")
--   UIAtlas.init(nvg)
--   UIAtlas.draw(nvg, "grey_button07", x, y, w, h)
--   UIAtlas.draw9(nvg, "grey_panel", x, y, w, h, 6)  -- 九宫格拉伸
-- ============================================================================

local UIAtlas = {}

-- ============================================================================
-- 内部状态
-- ============================================================================
local img_  = nil   -- NanoVG 图片句柄
local imgW_ = 293   -- 图集像素宽 (已知尺寸, 硬编码)
local imgH_ = 509   -- 图集像素高 (已知尺寸, 硬编码)
local drawDebugOnce_ = false  -- 调试已完成

-- ============================================================================
-- 子图区域 (从 XML atlas 提取, 去掉 .png 后缀)
-- ============================================================================
local regions_ = {
    -- 箭头
    grey_arrowDownGrey    = { x = 78,  y = 498, w = 15, h = 10 },
    grey_arrowDownWhite   = { x = 123, y = 496, w = 15, h = 10 },
    grey_arrowUpGrey      = { x = 108, y = 498, w = 15, h = 10 },
    grey_arrowUpWhite     = { x = 93,  y = 498, w = 15, h = 10 },

    -- 复选框
    grey_box              = { x = 147, y = 433, w = 38, h = 36 },
    grey_boxCheckmark     = { x = 147, y = 469, w = 38, h = 36 },
    grey_boxCross         = { x = 185, y = 433, w = 38, h = 36 },
    grey_boxTick          = { x = 190, y = 198, w = 36, h = 36 },

    -- 宽条按钮 (190~195 x 45~49)
    grey_button00         = { x = 0,   y = 143, w = 190, h = 45 },
    grey_button01         = { x = 0,   y = 188, w = 190, h = 49 },
    grey_button02         = { x = 0,   y = 98,  w = 190, h = 45 },
    grey_button03         = { x = 0,   y = 331, w = 190, h = 49 },
    grey_button04         = { x = 0,   y = 286, w = 190, h = 45 },
    grey_button05         = { x = 0,   y = 0,   w = 195, h = 49 },
    grey_button06         = { x = 0,   y = 49,  w = 191, h = 49 },

    -- 方形按钮 (49x49 / 49x45)
    grey_button07         = { x = 195, y = 0,   w = 49,  h = 49 },
    grey_button08         = { x = 240, y = 49,  w = 49,  h = 49 },
    grey_button09         = { x = 98,  y = 433, w = 49,  h = 45 },
    grey_button10         = { x = 191, y = 49,  w = 49,  h = 49 },
    grey_button11         = { x = 0,   y = 433, w = 49,  h = 45 },
    grey_button12         = { x = 244, y = 0,   w = 49,  h = 49 },
    grey_button13         = { x = 49,  y = 433, w = 49,  h = 45 },

    -- 宽条按钮 (续)
    grey_button14         = { x = 0,   y = 384, w = 190, h = 49 },
    grey_button15         = { x = 0,   y = 237, w = 190, h = 49 },

    -- 勾选/叉号标记
    grey_checkmarkGrey    = { x = 99,  y = 478, w = 21,  h = 20 },
    grey_checkmarkWhite   = { x = 78,  y = 478, w = 21,  h = 20 },
    grey_crossGrey        = { x = 120, y = 478, w = 18,  h = 18 },
    grey_crossWhite       = { x = 190, y = 318, w = 18,  h = 18 },

    -- 圆形
    grey_circle           = { x = 185, y = 469, w = 36,  h = 36 },

    -- 面板 (九宫格拉伸友好)
    grey_panel            = { x = 190, y = 98,  w = 100, h = 100 },

    -- 滑块
    grey_sliderDown       = { x = 190, y = 234, w = 28,  h = 42 },
    grey_sliderEnd        = { x = 138, y = 478, w = 8,   h = 10 },
    grey_sliderHorizontal = { x = 0,   y = 380, w = 190, h = 4  },
    grey_sliderLeft       = { x = 0,   y = 478, w = 39,  h = 31 },
    grey_sliderRight      = { x = 39,  y = 478, w = 39,  h = 31 },
    grey_sliderUp         = { x = 190, y = 276, w = 28,  h = 42 },
    grey_sliderVertical   = { x = 208, y = 318, w = 4,   h = 100 },

    -- 对勾
    grey_tickGrey         = { x = 190, y = 336, w = 17,  h = 17 },
    grey_tickWhite        = { x = 190, y = 353, w = 17,  h = 17 },
}

-- ============================================================================
-- 初始化: 加载图集
-- ============================================================================

--- 初始化 UI 图集 (在 NanoVG 上下文创建后调用一次)
---@param nvg userdata NanoVG 上下文
---@return boolean 是否加载成功
function UIAtlas.init(nvg)
    img_ = nvgCreateImage(nvg, "image/greySheet.png", 0)
    print(string.format("[UIAtlas] nvgCreateImage returned: %s", tostring(img_)))
    if img_ and img_ > 0 then
        imgW_, imgH_ = nvgImageSize(nvg, img_)
        print(string.format("[UIAtlas] nvgImageSize raw: %s x %s", tostring(imgW_), tostring(imgH_)))
        -- 防御: nvgImageSize 可能返回错误值
        if not imgW_ or not imgH_ or imgW_ < 64 or imgH_ < 64 then
            imgW_ = 293
            imgH_ = 509
            print("[UIAtlas] WARNING: using fallback dimensions 293x509")
        end
        -- 统计区域数
        local count = 0
        for _ in pairs(regions_) do count = count + 1 end
        print(string.format("[UIAtlas] loaded greySheet %dx%d, %d subtextures", imgW_, imgH_, count))
        return true
    else
        print("[UIAtlas] WARNING: failed to load greySheet.png, handle=" .. tostring(img_))
        return false
    end
end

-- ============================================================================
-- 查询 API
-- ============================================================================

--- 获取子图区域数据
---@param name string 子图名称 (如 "grey_button07")
---@return table|nil  { x, y, w, h }
function UIAtlas.getRegion(name)
    return regions_[name]
end

--- 获取图集句柄 (高级用法)
---@return userdata|nil img
---@return number width
---@return number height
function UIAtlas.getImage()
    return img_, imgW_, imgH_
end

--- 图集是否可用
---@return boolean
function UIAtlas.isLoaded()
    return img_ ~= nil and img_ > 0
end

-- ============================================================================
-- 绘制 API
-- ============================================================================

--- 绘制子图到指定位置和尺寸
--- 利用 NanoVG 图案平铺 + 模运算确保 pattern origin 在屏幕空间始终 >= 0
--- 解决: 本引擎 NanoVG pattern origin 为屏幕负坐标时不渲染的问题
---@param nvg userdata  NanoVG 上下文
---@param name string   子图名称
---@param dx number     目标 x
---@param dy number     目标 y
---@param dw number?    目标宽 (nil 则使用原始宽)
---@param dh number?    目标高 (nil 则使用原始高)
---@param alpha number? 透明度 0~1 (默认 1.0)
function UIAtlas.draw(nvg, name, dx, dy, dw, dh, alpha)
    if not img_ or img_ <= 0 then return end

    local r = regions_[name]
    if not r then
        print("[UIAtlas] WARNING: unknown region '" .. tostring(name) .. "'")
        return
    end

    dw = dw or r.w
    dh = dh or r.h

    -- 首次 draw 时打印调试信息
    if drawDebugOnce_ then
        drawDebugOnce_ = false
        print(string.format("[UIAtlas] draw debug: name=%s r={x=%d,y=%d,w=%d,h=%d} dw=%.1f dh=%.1f imgW=%d imgH=%d img=%s",
            name, r.x, r.y, r.w, r.h, dw, dh, imgW_, imgH_, tostring(img_)))
    end

    local scale = dw / r.w

    nvgSave(nvg)
    if alpha and alpha < 1.0 then
        nvgGlobalAlpha(nvg, alpha)
    end

    -- 坐标平移到绘制位置 (屏幕正坐标)
    nvgTranslate(nvg, dx, dy)

    -- 关键修复: 利用 NanoVG 图案平铺 (tiling) 特性
    -- 原始 pattern offset 为负值 (子区域偏移), 用 % 模运算转为正值
    -- Lua 5.4 的 % 对负数返回正结果 (与除数同号)
    local tileW = imgW_ * scale
    local tileH = imgH_ * scale
    local patOx = (-r.x * scale) % tileW  -- 始终 >= 0
    local patOy = (-r.y * scale) % tileH  -- 始终 >= 0

    local pat = nvgImagePattern(nvg,
        patOx, patOy,
        tileW, tileH,
        0, img_, 1.0)

    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, dw, dh)
    nvgFillPaint(nvg, pat)
    nvgFill(nvg)

    nvgRestore(nvg)
end

--- 绘制子图 (圆角矩形裁剪)
---@param nvg userdata
---@param name string
---@param dx number
---@param dy number
---@param dw number
---@param dh number
---@param radius number  圆角半径
---@param alpha number?
function UIAtlas.drawRounded(nvg, name, dx, dy, dw, dh, radius, alpha)
    if not img_ or img_ <= 0 then return end

    local r = regions_[name]
    if not r then return end

    dw = dw or r.w
    dh = dh or r.h

    local scale = dw / r.w

    nvgSave(nvg)
    if alpha and alpha < 1.0 then
        nvgGlobalAlpha(nvg, alpha)
    end

    -- 与 draw 一致: translate + 模运算确保 pattern origin 非负
    nvgTranslate(nvg, dx, dy)

    local tileW = imgW_ * scale
    local tileH = imgH_ * scale
    local patOx = (-r.x * scale) % tileW
    local patOy = (-r.y * scale) % tileH

    local pat = nvgImagePattern(nvg,
        patOx, patOy,
        tileW, tileH,
        0, img_, 1.0)

    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, 0, 0, dw, dh, radius)
    nvgFillPaint(nvg, pat)
    nvgFill(nvg)

    nvgRestore(nvg)
end

--- 绘制子图 (居中于指定点)
---@param nvg userdata
---@param name string
---@param cx number 中心 x
---@param cy number 中心 y
---@param dw number? 目标宽
---@param dh number? 目标高
---@param alpha number?
function UIAtlas.drawCentered(nvg, name, cx, cy, dw, dh, alpha)
    local r = regions_[name]
    if not r then return end
    dw = dw or r.w
    dh = dh or r.h
    UIAtlas.draw(nvg, name, cx - dw * 0.5, cy - dh * 0.5, dw, dh, alpha)
end

return UIAtlas
