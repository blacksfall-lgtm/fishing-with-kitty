-- ============================================================================
-- IconManager: 统一图标管理器
-- ============================================================================
-- 替代所有 emoji 的核心模块，支持:
-- 1. PNG 图标加载 (nvgCreateImage)
-- 2. NanoVG 程序化 fallback (当图片不存在时)
-- 3. 居中绘制、缩放、透明度控制
--
-- 用法:
--   local IconManager = require("ui.IconManager")
--   IconManager.init(nvg)
--   IconManager.draw(nvg, "coin", x, y, 32, 32)
--   IconManager.drawCentered(nvg, "coin", cx, cy, 32)
-- ============================================================================

local IconManager = {}

-- ============================================================================
-- 图标注册表: name → { path, fallbackChar, fallbackColor }
-- ============================================================================
local registry_ = {}
local imageCache_ = {}  -- name → nvg image handle
local nvg_ = nil
local initialized_ = false

-- ============================================================================
-- 图标路径映射
-- ============================================================================
local ICON_PATHS = {
    -- 鱼类 (256x256)
    fish_sardine    = "image/fish/fish_sardine.png",
    fish_clownfish  = "image/fish/fish_clownfish.png",
    fish_bubblefish = "image/fish/fish_bubblefish.png",
    fish_coralfish  = "image/fish/fish_coralfish.png",
    fish_shellfish  = "image/fish/fish_shellfish.png",
    fish_bluefin    = "image/fish/fish_bluefin.png",
    fish_flyingfish = "image/fish/fish_flyingfish.png",
    fish_silverfish = "image/fish/fish_silverfish.png",
    fish_gemfish    = "image/fish/fish_gemfish.png",
    fish_octopus    = "image/fish/fish_octopus.png",
    -- 稀有鱼类 (11-20)
    fish_swordfish    = "image/fish/fish_swordfish.png",
    fish_seahorse     = "image/fish/fish_seahorse.png",
    fish_anglerfish   = "image/fish/fish_anglerfish.png",
    fish_jellyfish    = "image/fish/fish_jellyfish.png",
    fish_viperfish    = "image/fish/fish_viperfish.png",
    fish_nautilus     = "image/fish/fish_nautilus.png",
    fish_dragonfish   = "image/fish/fish_dragonfish.png",
    fish_glowsquid    = "image/fish/fish_glowsquid.png",
    fish_abysseel     = "image/fish/fish_abysseel.png",
    fish_phantomray   = "image/fish/fish_phantomray.png",
    -- 传说鱼类 (21-30)
    fish_crystalshrimp = "image/fish/fish_crystalshrimp.png",
    fish_shadowwhale   = "image/fish/fish_shadowwhale.png",
    fish_voidcrab      = "image/fish/fish_voidcrab.png",
    fish_abyssjelly    = "image/fish/fish_abyssjelly.png",
    fish_goldendragon  = "image/fish/fish_goldendragon.png",
    fish_phoenixfish   = "image/fish/fish_phoenixfish.png",
    fish_leviathan     = "image/fish/fish_leviathan.png",
    fish_moonfish      = "image/fish/fish_moonfish.png",
    fish_stormturtle   = "image/fish/fish_stormturtle.png",
    fish_cosmicwhale   = "image/fish/fish_cosmicwhale.png",

    -- UI 图标 (128x128) — 已有
    coin            = "image/icons/icon_coin.png",
    lock            = "image/icons/icon_lock.png",
    home            = "image/icons/icon_home.png",
    wave            = "image/icons/icon_wave.png",
    crystal         = "image/icons/icon_crystal.png",
    diamond         = "image/icons/icon_diamond.png",
    anchor          = "image/icons/icon_anchor.png",
    aquarium        = "image/icons/icon_aquarium.png",
    backpack        = "image/icons/icon_backpack.png",
    breeding        = "image/icons/icon_breeding.png",
    codex           = "image/icons/icon_codex.png",
    research        = "image/icons/icon_research.png",
    settings        = "image/icons/icon_settings.png",
    boat_upgrade    = "image/icons/icon_boat_upgrade.png",
    upgrade_arrow   = "image/icons/icon_upgrade_arrow.png",
    plus            = "image/icons/icon_plus.png",

    -- 食物图标
    sushi           = "image/icons/icon_sushi.png",
    sushi_roll      = "image/icons/icon_sushi_roll.png",
    bento           = "image/icons/icon_bento.png",

    -- Tab / 功能图标
    fisher          = "image/icons/icon_fisher.png",
    egg             = "image/icons/icon_egg.png",
    lightning       = "image/icons/icon_lightning.png",
    cat             = "image/icons/icon_cat.png",

    -- 船员图标
    netter          = "image/icons/icon_netter.png",
    harvester       = "image/icons/icon_harvester.png",
    baiter          = "image/icons/icon_baiter.png",

    -- 鱼饵图标
    worm            = "image/icons/icon_worm.png",
    candy_bait      = "image/icons/icon_candy_bait.png",
    shiny_bait      = "image/icons/icon_shiny_bait.png",

    -- 海域图标
    zone_beach      = "image/icons/icon_zone_beach.png",
    zone_ocean      = "image/icons/icon_zone_ocean.png",
    zone_deep       = "image/icons/icon_zone_deep.png",
    zone_abyss      = "image/icons/icon_zone_abyss.png",
    zone_legend     = "image/icons/icon_zone_legend.png",
}

-- ============================================================================
-- Fallback 字符映射 (当图片不存在时用 NanoVG 文字渲染)
-- ============================================================================
local FALLBACK = {
    -- 鱼类
    fish_sardine    = { char = "沙", color = {100, 200, 255} },
    fish_clownfish  = { char = "丑", color = {255, 160,  60} },
    fish_bubblefish = { char = "泡", color = {150, 220, 255} },
    fish_coralfish  = { char = "珊", color = {255, 120, 150} },
    fish_shellfish  = { char = "贝", color = {255, 200, 150} },
    fish_bluefin    = { char = "蓝", color = { 60, 140, 255} },
    fish_flyingfish = { char = "飞", color = {100, 230, 200} },
    fish_silverfish = { char = "银", color = {200, 210, 220} },
    fish_gemfish    = { char = "宝", color = {180, 130, 255} },
    fish_octopus    = { char = "章", color = {200,  80, 160} },
    -- 稀有鱼类
    fish_swordfish    = { char = "旗", color = { 80, 160, 230} },
    fish_seahorse     = { char = "马", color = {255, 180,  80} },
    fish_anglerfish   = { char = "灯", color = { 60,  80, 120} },
    fish_jellyfish    = { char = "母", color = {220, 150, 255} },
    fish_viperfish    = { char = "蝰", color = {130,  60, 180} },
    fish_nautilus     = { char = "螺", color = {255, 180, 120} },
    fish_dragonfish   = { char = "龙", color = { 80, 200, 120} },
    fish_glowsquid    = { char = "鱿", color = {100, 120, 255} },
    fish_abysseel     = { char = "鳗", color = { 40,  60, 100} },
    fish_phantomray   = { char = "鳐", color = {180, 160, 230} },
    -- 传说鱼类
    fish_crystalshrimp = { char = "晶", color = {200, 240, 255} },
    fish_shadowwhale   = { char = "鲸", color = { 60,  40, 120} },
    fish_voidcrab      = { char = "蟹", color = {100,  40, 180} },
    fish_abyssjelly    = { char = "蜇", color = { 80,  60, 160} },
    fish_goldendragon  = { char = "金", color = {255, 215,  50} },
    fish_phoenixfish   = { char = "凤", color = {255, 120,  60} },
    fish_leviathan     = { char = "怪", color = { 40,  80, 160} },
    fish_moonfish      = { char = "月", color = {220, 230, 255} },
    fish_stormturtle   = { char = "龟", color = { 80, 200, 160} },
    fish_cosmicwhale   = { char = "宙", color = { 60,  80, 200} },

    -- UI 图标
    coin            = { char = "币", color = {255, 215,  50} },
    lock            = { char = "锁", color = {150, 170, 200} },
    home            = { char = "屋", color = {100, 180, 230} },
    wave            = { char = "浪", color = { 80, 160, 240} },
    crystal         = { char = "晶", color = {180, 100, 255} },
    diamond         = { char = "钻", color = {140, 200, 255} },
    anchor          = { char = "锚", color = {120, 140, 160} },
    aquarium        = { char = "缸", color = { 60, 180, 220} },
    backpack        = { char = "包", color = {180, 140, 100} },
    breeding        = { char = "殖", color = {255, 180, 120} },
    codex           = { char = "鉴", color = {180, 200, 140} },
    research        = { char = "研", color = {100, 200, 180} },
    settings        = { char = "设", color = {160, 170, 180} },
    boat_upgrade    = { char = "船", color = {120, 160, 200} },
    upgrade_arrow   = { char = "升", color = {100, 230, 120} },
    plus            = { char = "+",  color = {200, 220, 240} },
    sushi           = { char = "寿", color = {255, 160, 120} },
    sushi_roll      = { char = "卷", color = {255, 180, 150} },
    bento           = { char = "盒", color = {200, 160, 120} },

    -- 研究/功能图标
    star            = { char = "星", color = {255, 220, 100} },
    sparkle         = { char = "闪", color = {255, 255, 180} },
    cat             = { char = "猫", color = {255, 200, 150} },
    pin             = { char = "钉", color = {255, 100,  80} },
    book            = { char = "书", color = {180, 160, 120} },
    microscope      = { char = "镜", color = {150, 200, 230} },
    egg             = { char = "蛋", color = {255, 230, 180} },
    lightning       = { char = "电", color = {255, 240, 100} },
    clock           = { char = "时", color = {180, 200, 220} },
    build           = { char = "建", color = {200, 170, 130} },
    target          = { char = "标", color = {255, 120, 100} },
    money           = { char = "金", color = {255, 215,  50} },

    -- 船员
    fisher          = { char = "钓", color = {100, 180, 230} },
    netter          = { char = "网", color = {120, 200, 160} },
    harvester       = { char = "收", color = {200, 180, 140} },
    baiter          = { char = "饵", color = {180, 150, 230} },

    -- 鱼饵
    worm            = { char = "虫", color = {180, 130, 100} },
    candy_bait      = { char = "糖", color = {255, 160, 200} },
    shiny_bait      = { char = "闪", color = {255, 240, 150} },

    -- 海域
    zone_beach      = { char = "滩", color = {255, 220, 150} },
    zone_ocean      = { char = "洋", color = { 80, 160, 230} },
    zone_deep       = { char = "深", color = { 40, 100, 180} },
    zone_abyss      = { char = "渊", color = { 80,  60, 150} },
    zone_legend     = { char = "传", color = {255, 200,  80} },
}

-- ============================================================================
-- 初始化
-- ============================================================================

--- 初始化图标管理器 (在 NanoVG 上下文创建后调用一次)
---@param nvg userdata NanoVG 上下文
function IconManager.init(nvg)
    nvg_ = nvg
    initialized_ = true
    imageCache_ = {}
    print("[IconManager] initialized")
end

-- ============================================================================
-- 内部: 获取或加载图标
-- ============================================================================

local function getImage(name)
    -- 已缓存
    if imageCache_[name] ~= nil then
        return imageCache_[name]  -- 可能为 0 (加载失败)
    end

    -- 查找路径
    local path = ICON_PATHS[name]
    if not path then
        imageCache_[name] = 0
        return 0
    end

    -- 加载图片
    if nvg_ then
        local img = nvgCreateImage(nvg_, path, 0)
        if img and img > 0 then
            imageCache_[name] = img
            return img
        end
    end

    imageCache_[name] = 0
    return 0
end

-- ============================================================================
-- 程序化 fallback 绘制
-- ============================================================================

local function drawFallback(nvg, name, x, y, w, h, alpha)
    local fb = FALLBACK[name]
    if not fb then
        -- 完全未知图标，画一个灰色占位方块
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, x, y, w, h, math.min(w, h) * 0.15)
        nvgFillColor(nvg, nvgRGBA(100, 120, 140, math.floor((alpha or 1.0) * 150)))
        nvgFill(nvg)
        return
    end

    local a = math.floor((alpha or 1.0) * 255)
    local c = fb.color

    -- 绘制圆角背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, math.min(w, h) * 0.2)
    nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], math.floor(a * 0.25)))
    nvgFill(nvg)

    -- 绘制文字
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, math.min(w, h) * 0.65)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], a))
    nvgText(nvg, x + w * 0.5, y + h * 0.5, fb.char)
end

-- ============================================================================
-- 公共 API
-- ============================================================================

--- 绘制图标 (左上角定位)
---@param nvg userdata NanoVG 上下文
---@param name string 图标名称
---@param x number 左上角 x
---@param y number 左上角 y
---@param w number 绘制宽度
---@param h number 绘制高度
---@param alpha number? 透明度 0~1 (默认 1.0)
function IconManager.draw(nvg, name, x, y, w, h, alpha)
    local img = getImage(name)
    if img > 0 then
        -- 使用图片渲染
        local a = alpha or 1.0
        local iw, ih = nvgImageSize(nvg, img)
        if iw and ih and iw > 0 and ih > 0 then
            local pat = nvgImagePattern(nvg, x, y, w, h, 0, img, a)
            nvgBeginPath(nvg)
            nvgRect(nvg, x, y, w, h)
            nvgFillPaint(nvg, pat)
            nvgFill(nvg)
        else
            drawFallback(nvg, name, x, y, w, h, alpha)
        end
    else
        drawFallback(nvg, name, x, y, w, h, alpha)
    end
end

--- 绘制图标 (居中于指定点)
---@param nvg userdata
---@param name string 图标名称
---@param cx number 中心 x
---@param cy number 中心 y
---@param size number 图标尺寸 (宽=高)
---@param alpha number?
function IconManager.drawCentered(nvg, name, cx, cy, size, alpha)
    IconManager.draw(nvg, name, cx - size * 0.5, cy - size * 0.5, size, size, alpha)
end

--- 绘制圆角图标 (左上角定位)
---@param nvg userdata
---@param name string
---@param x number
---@param y number
---@param w number
---@param h number
---@param radius number 圆角半径
---@param alpha number?
function IconManager.drawRounded(nvg, name, x, y, w, h, radius, alpha)
    local img = getImage(name)
    if img > 0 then
        local a = alpha or 1.0
        local pat = nvgImagePattern(nvg, x, y, w, h, 0, img, a)
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, x, y, w, h, radius)
        nvgFillPaint(nvg, pat)
        nvgFill(nvg)
    else
        drawFallback(nvg, name, x, y, w, h, alpha)
    end
end

--- 检查图标图片是否可用 (非 fallback)
---@param name string
---@return boolean
function IconManager.hasImage(name)
    return getImage(name) > 0
end

--- 获取 fallback 信息
---@param name string
---@return table|nil { char, color }
function IconManager.getFallback(name)
    return FALLBACK[name]
end

--- 注册自定义图标路径
---@param name string
---@param path string
---@param fallback table? { char, color }
function IconManager.register(name, path, fallback)
    ICON_PATHS[name] = path
    if fallback then
        FALLBACK[name] = fallback
    end
    -- 清除缓存以便重新加载
    imageCache_[name] = nil
end

--- 清除所有缓存 (场景切换时调用)
function IconManager.clearCache()
    imageCache_ = {}
end

--- 是否已初始化
---@return boolean
function IconManager.isReady()
    return initialized_
end

return IconManager
