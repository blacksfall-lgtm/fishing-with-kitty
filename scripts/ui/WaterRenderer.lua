-- ============================================================================
-- WaterRenderer: 可复用的水面渲染模块
-- 从 WaterScene 提取的双层 UV 滚动水面 + 焦散叠加
-- ============================================================================

local WaterRenderer = {}

-- NanoVG 图片句柄
local imgBaseTile_ = nil
local imgCaustic_  = nil

--- 初始化：加载水面纹理
function WaterRenderer.init(nvg)
    imgBaseTile_ = nvgCreateImage(nvg, "Textures/water_base_tile.png",
        NVG_IMAGE_REPEATX + NVG_IMAGE_REPEATY + NVG_IMAGE_PREMULTIPLIED)
    imgCaustic_ = nvgCreateImage(nvg, "Textures/water_caustic_cyan.png",
        NVG_IMAGE_REPEATX + NVG_IMAGE_REPEATY + NVG_IMAGE_PREMULTIPLIED)
    print("[WaterRenderer] 纹理加载完成")
end

--- 渲染水面底色 + 焦散
---@param nvg userdata NanoVG 上下文
---@param x number 左上角 X
---@param y number 左上角 Y
---@param w number 宽度
---@param h number 高度
---@param time number 累计时间(秒)
function WaterRenderer.render(nvg, x, y, w, h, time)
    -- 1) 深蓝底色
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillColor(nvg, nvgRGBA(30, 85, 130, 255))
    nvgFill(nvg)

    -- 2) 双层 UV 滚动水面
    if imgBaseTile_ and imgBaseTile_ > 0 then
        local minDim = math.min(w, h)
        -- 第一层：正向漂移
        local tile1 = minDim / 0.55
        local flow1X = 0.006 * tile1 * time
        local flow1Y = 0.012 * tile1 * time
        local pat1 = nvgImagePattern(nvg,
            x + flow1X, y + flow1Y, tile1, tile1, 0, imgBaseTile_, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, x, y, w, h)
        nvgFillPaint(nvg, pat1)
        nvgFill(nvg)

        -- 第二层：反向漂移，半透明叠加
        local tile2 = minDim / 0.75
        local flow2X = -0.004 * tile2 * time
        local flow2Y =  0.008 * tile2 * time
        nvgSave(nvg)
        nvgGlobalAlpha(nvg, 0.3)
        local pat2 = nvgImagePattern(nvg,
            x + flow2X, y + flow2Y, tile2, tile2, 0, imgBaseTile_, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, x, y, w, h)
        nvgFillPaint(nvg, pat2)
        nvgFill(nvg)
        nvgRestore(nvg)
    end

    -- 3) 焦散叠加 (additive blend)
    if imgCaustic_ and imgCaustic_ > 0 then
        local minDim = math.min(w, h)
        local tileC1 = minDim / 1.8
        local flowC1X = -0.008 * tileC1 * time
        local flowC1Y =  0.005 * tileC1 * time
        local tileC2 = minDim / 2.5
        local flowC2X =  0.006 * tileC2 * time
        local flowC2Y = -0.007 * tileC2 * time

        local patC1 = nvgImagePattern(nvg,
            x + flowC1X, y + flowC1Y, tileC1, tileC1, 0, imgCaustic_, 1.0)
        local patC2 = nvgImagePattern(nvg,
            x + flowC2X, y + flowC2Y, tileC2, tileC2, 0, imgCaustic_, 1.0)

        nvgSave(nvg)
        nvgGlobalCompositeBlendFunc(nvg, NVG_SRC_ALPHA, NVG_ONE)
        nvgGlobalAlpha(nvg, 0.15)

        nvgBeginPath(nvg)
        nvgRect(nvg, x, y, w, h)
        nvgFillPaint(nvg, patC1)
        nvgFill(nvg)

        nvgBeginPath(nvg)
        nvgRect(nvg, x, y, w, h)
        nvgFillPaint(nvg, patC2)
        nvgFill(nvg)

        nvgRestore(nvg)
    end
end

return WaterRenderer
