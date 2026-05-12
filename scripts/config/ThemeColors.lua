-- ============================================================================
-- ThemeColors: 统一卡通海洋风配色方案
-- ============================================================================
-- 所有 UI 面板、文字、按钮颜色统一从此模块获取
-- 风格: 圆润卡通海洋风 - 治愈、清爽、可爱、轻微立体感
-- ============================================================================

local ThemeColors = {}

-- ========== 主色板 ==========

-- 背景色 (面板/弹窗)
ThemeColors.BG_PRIMARY     = {  35,  80, 130, 230 }  -- 深海蓝 (主面板)
ThemeColors.BG_SECONDARY   = {  45, 100, 155, 220 }  -- 中蓝 (次级面板)
ThemeColors.BG_LIGHT       = {  65, 130, 190, 200 }  -- 浅海蓝 (卡片)
ThemeColors.BG_OVERLAY     = {  15,  40,  70, 180 }  -- 遮罩层
ThemeColors.BG_DARK        = {  20,  50,  90, 240 }  -- 深色背景

-- 天空/渐变色
ThemeColors.SKY_TOP        = { 100, 180, 240, 255 }  -- 天空顶部
ThemeColors.SKY_BOTTOM     = { 150, 210, 250, 255 }  -- 天空底部
ThemeColors.WATER_TOP      = {  40, 120, 200, 255 }  -- 水面顶
ThemeColors.WATER_BOTTOM   = {  15,  60, 120, 255 }  -- 水面底

-- 按钮色
ThemeColors.BTN_PRIMARY    = {  60, 180, 120, 255 }  -- 绿色主按钮
ThemeColors.BTN_PRIMARY_HL = {  80, 210, 140, 255 }  -- 绿色高亮
ThemeColors.BTN_SECONDARY  = {  80, 150, 230, 255 }  -- 蓝色次按钮
ThemeColors.BTN_SECONDARY_HL = { 100, 170, 245, 255 }
ThemeColors.BTN_DANGER     = { 230,  90,  80, 255 }  -- 红色危险
ThemeColors.BTN_DISABLED   = { 120, 130, 140, 200 }  -- 灰色禁用
ThemeColors.BTN_GOLD       = { 255, 200,  50, 255 }  -- 金色特殊

-- 文字色
ThemeColors.TEXT_WHITE      = { 255, 255, 255, 255 }
ThemeColors.TEXT_LIGHT      = { 220, 235, 250, 255 }  -- 浅白 (正文)
ThemeColors.TEXT_DIM        = { 160, 185, 210, 220 }  -- 暗白 (次要)
ThemeColors.TEXT_DARK       = {  30,  55,  80, 255 }  -- 深色文字
ThemeColors.TEXT_GOLD       = { 255, 220, 100, 255 }  -- 金色高亮
ThemeColors.TEXT_GREEN      = { 100, 230, 120, 255 }  -- 绿色 (正面)
ThemeColors.TEXT_RED        = { 255, 100,  90, 255 }  -- 红色 (负面)

-- 边框/分隔
ThemeColors.BORDER_LIGHT   = { 100, 170, 230, 100 }  -- 浅蓝边框
ThemeColors.BORDER_MEDIUM  = {  70, 140, 200, 150 }  -- 中蓝边框
ThemeColors.DIVIDER        = {  80, 150, 220, 80  }  -- 分隔线

-- ========== 品质色 ==========
ThemeColors.QUALITY = {
    { 200, 200, 200, 255 },  -- 普通 (灰白)
    { 100, 220,  80, 255 },  -- 优良 (绿)
    {  80, 160, 255, 255 },  -- 稀有 (蓝)
    { 190, 100, 255, 255 },  -- 史诗 (紫)
    { 255, 215,  50, 255 },  -- 传说 (金)
}

-- 品质边框色 (更亮的版本)
ThemeColors.QUALITY_BORDER = {
    { 180, 180, 180, 180 },
    { 120, 240, 100, 200 },
    { 100, 180, 255, 200 },
    { 210, 130, 255, 200 },
    { 255, 230,  80, 220 },
}

-- 品质背景色 (暗淡版)
ThemeColors.QUALITY_BG = {
    {  80,  80,  80, 120 },
    {  40,  90,  35, 120 },
    {  30,  60, 110, 120 },
    {  70,  30, 100, 120 },
    { 100,  85,  15, 120 },
}

-- ========== 功能色 ==========
ThemeColors.COIN           = { 255, 215,  50, 255 }  -- 金币
ThemeColors.DIAMOND        = { 140, 200, 255, 255 }  -- 钻石
ThemeColors.EXP            = { 100, 230, 180, 255 }  -- 经验
ThemeColors.BUFF_POSITIVE  = { 100, 230, 120, 255 }  -- 正面Buff
ThemeColors.BUFF_NEGATIVE  = { 255, 100,  90, 255 }  -- 负面Buff

-- ========== 海域配色 ==========
ThemeColors.ZONE = {
    nearshore = {  80, 180, 230, 255 },  -- 近海: 浅蓝
    offshore  = {  50, 130, 200, 255 },  -- 外海: 中蓝
    deepocean = {  30,  80, 160, 255 },  -- 深海: 深蓝
    abyss     = {  50,  40, 120, 255 },  -- 深渊: 暗紫
    legendary = { 180, 140,  50, 255 },  -- 传说: 金色
}

-- ========== 工具函数 ==========

--- 将颜色表转为 nvgRGBA 调用参数
---@param c table {r, g, b, a}
---@return number, number, number, number
function ThemeColors.unpack(c)
    return c[1], c[2], c[3], c[4] or 255
end

--- 获取品质颜色 (1~5)
---@param qualityId number
---@return table
function ThemeColors.getQualityColor(qualityId)
    return ThemeColors.QUALITY[qualityId] or ThemeColors.QUALITY[1]
end

--- 获取品质边框颜色
---@param qualityId number
---@return table
function ThemeColors.getQualityBorder(qualityId)
    return ThemeColors.QUALITY_BORDER[qualityId] or ThemeColors.QUALITY_BORDER[1]
end

--- 获取品质背景色
---@param qualityId number
---@return table
function ThemeColors.getQualityBG(qualityId)
    return ThemeColors.QUALITY_BG[qualityId] or ThemeColors.QUALITY_BG[1]
end

--- 创建半透明版本
---@param c table {r,g,b,a}
---@param alpha number 0~255
---@return table
function ThemeColors.withAlpha(c, alpha)
    return { c[1], c[2], c[3], alpha }
end

--- 创建亮度调整版本
---@param c table {r,g,b,a}
---@param factor number >1变亮, <1变暗
---@return table
function ThemeColors.brightness(c, factor)
    return {
        math.min(255, math.floor(c[1] * factor)),
        math.min(255, math.floor(c[2] * factor)),
        math.min(255, math.floor(c[3] * factor)),
        c[4] or 255,
    }
end

return ThemeColors
