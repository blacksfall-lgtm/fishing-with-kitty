-- ============================================================================
-- WaterScene: 纯 NanoVG 水面渲染系统
-- ============================================================================
-- 层级 (从下到上):
--   1. Base       — 双 UV 滚动水面底色
--   2. Caustic    — 焦散叠加
--   3. FishShadow — 鱼影 atlas
--   4. Ripples    — 水面涟漪圆环
--   5. BoatShadow — 船底深蓝阴影 (贴图)
--   6. BoatWake   — 船尾泡沫 (半月形贴图 + 微粒)
--   7. BoatBase   — 纯船体
--   7.5 SwipeTrail — 滑动捕鱼轨迹
--   8. UI         — 状态文字 / 捕获弹窗
-- ============================================================================
local FishingSystem   = require("systems.FishingSystem")
local FishSwarmSystem = require("systems.FishSwarmSystem")
local SwipeSystem     = require("systems.SwipeSystem")

local WaterScene = {}

-- ============================================================================
-- NanoVG 图片句柄
-- ============================================================================
local imgBaseTile_   = nil
local imgCaustic_    = nil
local imgFishSheet_  = nil
local imgBoatBase_   = nil
local imgBoatShadow_ = nil
local imgBoatWake_   = nil

local baseTileW_     = 0
local baseTileH_     = 0
local fishSheetW_    = 0
local fishSheetH_    = 0
local boatBaseW_     = 0
local boatBaseH_     = 0
local boatShadowW_   = 0
local boatShadowH_   = 0
local boatWakeW_     = 0
local boatWakeH_     = 0

-- ============================================================================
-- 动画状态
-- ============================================================================
local time_ = 0
local imagesLoaded_ = false

-- 鱼影数据现在由 FishSwarmSystem 管理

-- 船尾微粒泡沫 (辅助层, 5~10个小气泡)
local wakeBubbles_ = {}

-- 水面涟漪圆环系统
local ripples_ = {}
local rippleTimer_ = 0
local rippleInterval_ = 2.5  -- 初始间隔, 会在 2~3s 之间随机

-- 特殊状态
local catchTilt_ = 0           -- 咬钩倾斜角 (弧度)
local catchTiltTarget_ = 0     -- 目标倾斜角
local waveIntensity_ = 1.0     -- 波次强度倍率 (1.0=正常, 1.2=波次)

-- 捕获展示
local catchInfo_ = nil
local catchTimer_ = 0

-- ============================================================================
-- 初始化
-- ============================================================================

function WaterScene.init(nvg)
    -- 基础水面贴图 (平铺)
    imgBaseTile_ = nvgCreateImage(nvg, "Textures/water_base_tile.png",
        NVG_IMAGE_REPEATX | NVG_IMAGE_REPEATY)
    if imgBaseTile_ and imgBaseTile_ > 0 then
        baseTileW_, baseTileH_ = nvgImageSize(nvg, imgBaseTile_)
        print("[WaterScene] base tile: " .. baseTileW_ .. "x" .. baseTileH_)
    end

    -- 焦散贴图 (平铺)
    imgCaustic_ = nvgCreateImage(nvg, "Textures/water_caustic_cyan.png",
        NVG_IMAGE_REPEATX | NVG_IMAGE_REPEATY)
    if imgCaustic_ and imgCaustic_ > 0 then
        print("[WaterScene] caustic loaded")
    end

    -- 鱼影 atlas (3列 × 2行 = 6帧游泳动画)
    imgFishSheet_ = nvgCreateImage(nvg, "Textures/fish_shadow_s.png", 0)
    if imgFishSheet_ and imgFishSheet_ > 0 then
        fishSheetW_, fishSheetH_ = nvgImageSize(nvg, imgFishSheet_)
        print("[WaterScene] fish atlas: " .. fishSheetW_ .. "x" .. fishSheetH_)
        -- 防御: nvgImageSize 可能返回错误值(如 16x16), 用已知尺寸兜底
        if fishSheetW_ < 64 or fishSheetH_ < 64 then
            print("[WaterScene] WARNING: fish atlas nvgImageSize returned suspicious " .. fishSheetW_ .. "x" .. fishSheetH_ .. ", using known dimensions")
            fishSheetW_ = 1536
            fishSheetH_ = 1030
        end
    end

    -- 纯船体 (俯视角卡通木船)
    imgBoatBase_ = nvgCreateImage(nvg, "image/boat_hull_v2.png", 0)
    if imgBoatBase_ and imgBoatBase_ > 0 then
        boatBaseW_, boatBaseH_ = nvgImageSize(nvg, imgBoatBase_)
        print("[WaterScene] boat base: " .. boatBaseW_ .. "x" .. boatBaseH_)
        -- 防御: nvgImageSize 可能返回错误值(如 16x16), 用已知尺寸兜底
        if boatBaseW_ < 64 or boatBaseH_ < 64 then
            print("[WaterScene] WARNING: nvgImageSize returned suspicious " .. boatBaseW_ .. "x" .. boatBaseH_ .. ", using known dimensions")
            boatBaseW_ = 512
            boatBaseH_ = 1070
        end
    end

    -- 船底阴影
    imgBoatShadow_ = nvgCreateImage(nvg, "image/boat_shadow_true_transparent.png", 0)
    if imgBoatShadow_ and imgBoatShadow_ > 0 then
        boatShadowW_, boatShadowH_ = nvgImageSize(nvg, imgBoatShadow_)
        print("[WaterScene] boat shadow: " .. boatShadowW_ .. "x" .. boatShadowH_)
        if boatShadowW_ < 64 or boatShadowH_ < 64 then
            print("[WaterScene] WARNING: boat shadow nvgImageSize returned suspicious " .. boatShadowW_ .. "x" .. boatShadowH_ .. ", using known dimensions")
            boatShadowW_ = 512
            boatShadowH_ = 512
        end
    end

    -- 船尾泡沫贴图 (半月形, 透明底)
    imgBoatWake_ = nvgCreateImage(nvg, "image/boat_wake_ref.png", 0)
    if imgBoatWake_ and imgBoatWake_ > 0 then
        boatWakeW_, boatWakeH_ = nvgImageSize(nvg, imgBoatWake_)
        print("[WaterScene] boat wake: " .. boatWakeW_ .. "x" .. boatWakeH_)
        if boatWakeW_ < 64 or boatWakeH_ < 64 then
            print("[WaterScene] WARNING: boat wake nvgImageSize returned suspicious " .. boatWakeW_ .. "x" .. boatWakeH_ .. ", using known dimensions")
            boatWakeW_ = 512
            boatWakeH_ = 512
        end
    end

    imagesLoaded_ = true

    -- 初始化鱼群刷新系统
    FishSwarmSystem.init()

    print("[WaterScene] init done")
end

-- ============================================================================
-- 捕获展示
-- ============================================================================

function WaterScene.showCatch(info)
    catchInfo_ = info
    catchTimer_ = 2.5
    -- 咬钩时船向一侧倾斜 (随机左/右 5~8°)
    local sign = math.random() > 0.5 and 1 or -1
    catchTiltTarget_ = sign * (5.0 + math.random() * 3.0) * (math.pi / 180)
end

--- 外部触发咬钩倾斜 (不显示弹窗, 仅倾斜船体)
---@param angleDeg number|nil 倾斜角度(度), nil 则恢复
function WaterScene.setCatchTilt(angleDeg)
    if angleDeg then
        catchTiltTarget_ = angleDeg * (math.pi / 180)
    else
        catchTiltTarget_ = 0
    end
end

-- ============================================================================
-- 船体状态计算 (供多个层共享)
-- ============================================================================
local boatState_ = {
    cx = 0, cy = 0,       -- 船体中心 (屏幕坐标)
    bobY = 0,             -- 垂直浮动偏移 (px)
    swayX = 0,            -- 水平摇摆偏移 (px)
    rot = 0,              -- 旋转角 (弧度, 含特殊状态)
    drawW = 0, drawH = 0, -- 绘制尺寸
    -- 船影延迟跟随
    shadowBobY = 0,
    shadowSwayX = 0,
    shadowRot = 0,
}

-- 船影延迟参数
local SHADOW_LERP_SPEED = 10.0   -- lerp速度, 值越大跟随越快 (0.1s延迟 ≈ 10)

local function updateBoatState(x, y, w, h)
    -- 基于屏幕短边计算船体尺寸, 横屏竖屏都不会溢出
    local shortSide = math.min(w, h)
    local imgRatio = (boatBaseW_ > 0 and boatBaseH_ > 0) and (boatBaseW_ / boatBaseH_) or 0.478
    -- 船高 = 短边 * 0.55, 船宽按原图比例
    local bh = shortSide * 0.55
    local bw = bh * imgRatio
    boatState_.drawW = bw
    boatState_.drawH = bh
    boatState_.cx = x + w * 0.5
    boatState_.cy = y + h * 0.5

    -- ---- 晃动参数 (设计文档) ----
    -- 垂直浮动: 振幅 6px, 周期 3s
    local bobAmp = 6.0 * waveIntensity_
    local bobPeriod = 3.0
    boatState_.bobY = math.sin(time_ * (2 * math.pi / bobPeriod)) * bobAmp

    -- 水平摇摆: 振幅 3px, 周期 3.5s, 不同相位
    local swayAmp = 3.0 * waveIntensity_
    local swayPeriod = 3.5
    boatState_.swayX = math.sin(time_ * (2 * math.pi / swayPeriod) + 1.3) * swayAmp

    -- 非对称旋转: -2° ~ +1.5°, 周期 2.7s
    -- 用 sin 做基础, 通过偏移和缩放实现非对称: center = (-2+1.5)/2 = -0.25°, range = (2+1.5)/2 = 1.75°
    local rotPeriod = 2.7
    local rotCenter = -0.25 * (math.pi / 180)  -- 偏心
    local rotRange  =  1.75 * (math.pi / 180)  -- 半幅
    local baseRot = rotCenter + math.sin(time_ * (2 * math.pi / rotPeriod) + 0.7) * rotRange * waveIntensity_

    -- 叠加咬钩倾斜
    boatState_.rot = baseRot + catchTilt_
end

-- ============================================================================
-- 更新
-- ============================================================================

function WaterScene.update(dt)
    time_ = time_ + dt

    -- 鱼群系统更新 (常驻鱼 + 波次)
    FishSwarmSystem.update(dt)

    -- ---- 船影延迟跟随 (0.1s lag via lerp) ----
    local lerpFactor = 1.0 - math.exp(-SHADOW_LERP_SPEED * dt)
    boatState_.shadowBobY  = boatState_.shadowBobY  + (boatState_.bobY  - boatState_.shadowBobY)  * lerpFactor
    boatState_.shadowSwayX = boatState_.shadowSwayX + (boatState_.swayX - boatState_.shadowSwayX) * lerpFactor
    boatState_.shadowRot   = boatState_.shadowRot   + (boatState_.rot   - boatState_.shadowRot)   * lerpFactor

    -- ---- 特殊状态: 咬钩倾斜平滑 ----
    local tiltLerp = 1.0 - math.exp(-8.0 * dt)
    catchTilt_ = catchTilt_ + (catchTiltTarget_ - catchTilt_) * tiltLerp

    -- ---- 波次强度: 有波次鱼时 +20% ----
    local hasWave = FishSwarmSystem.isWaveActive and FishSwarmSystem.isWaveActive() or false
    local targetIntensity = hasWave and 1.2 or 1.0
    waveIntensity_ = waveIntensity_ + (targetIntensity - waveIntensity_) * (1.0 - math.exp(-3.0 * dt))

    -- ---- 水面涟漪圆环生成 (每 2~3 秒) ----
    rippleTimer_ = rippleTimer_ + dt
    if rippleTimer_ >= rippleInterval_ then
        rippleTimer_ = 0
        rippleInterval_ = 2.0 + math.random() * 1.0  -- 2~3s
        -- 在船底左右随机位置生成涟漪
        table.insert(ripples_, {
            age = 0,
            maxAge = 1.5,                              -- 1.5s 扩散
            startR = 4,                                -- 起始半径
            endR = 30 * waveIntensity_,                -- 终止半径
            offsetX = (math.random() - 0.5) * 20,      -- 相对船中心偏移
            offsetY = (math.random() - 0.3) * 15,
        })
    end

    -- 更新涟漪, 限制最大 3 层叠加
    local i = 1
    while i <= #ripples_ do
        ripples_[i].age = ripples_[i].age + dt
        if ripples_[i].age >= ripples_[i].maxAge then
            table.remove(ripples_, i)
        else
            i = i + 1
        end
    end
    -- 如果超过 3 层, 移除最旧的
    while #ripples_ > 3 do
        table.remove(ripples_, 1)
    end

    -- ---- 船尾微粒泡沫 (5~10 个, 轻微向后漂移) ----
    -- 补充到目标数量
    local bs = boatState_
    while #wakeBubbles_ < 7 do
        wakeBubbles_[#wakeBubbles_ + 1] = {
            age = 0,
            maxAge = 0.4 + math.random() * 0.4,       -- 0.4~0.8s
            -- 相对船尾的初始偏移
            ox = (math.random() - 0.5) * bs.drawW * 0.4,
            oy = math.random() * 6,                    -- 0~6px 向后
            r  = 1.0 + math.random() * 2.0,            -- 半径 1~3px
            drift = 4 + math.random() * 8,             -- 向后漂移 4~12 px/s
            baseAlpha = 0.2 + math.random() * 0.2,    -- 初始透明度 0.2~0.4
        }
    end
    -- 更新
    i = 1
    while i <= #wakeBubbles_ do
        local b = wakeBubbles_[i]
        b.age = b.age + dt
        if b.age >= b.maxAge then
            table.remove(wakeBubbles_, i)
        else
            i = i + 1
        end
    end

    -- 捕获倒计时
    if catchTimer_ > 0 then
        catchTimer_ = catchTimer_ - dt
        if catchTimer_ <= 0 then
            catchInfo_ = nil
            -- 咬钩结束, 恢复倾斜
            catchTiltTarget_ = 0
        end
    end
end

-- ============================================================================
-- 主渲染入口
-- ============================================================================

function WaterScene.render(nvg, x, y, w, h)
    if not imagesLoaded_ then return end

    updateBoatState(x, y, w, h)

    -- 1. water_base
    WaterScene.renderBase(nvg, x, y, w, h)
    -- 2. caustic
    WaterScene.renderCaustic(nvg, x, y, w, h)
    -- 3. fish_shadow
    WaterScene.renderFishShadows(nvg, x, y, w, h)
    -- 4. ripples (水面涟漪圆环, 在船影下方)
    WaterScene.renderRipples(nvg, x, y, w, h)
    -- 5. boat_shadow
    WaterScene.renderBoatShadow(nvg, x, y, w, h)
    -- 6. boat_wake (水面层, 在船体下方)
    WaterScene.renderBoatWake(nvg, x, y, w, h)
    -- 7. boat_base (船体最上层)
    WaterScene.renderBoatBase(nvg, x, y, w, h)
    -- 7.5 swipe_trail (滑动轨迹)
    SwipeSystem.render(nvg, x, y, w, h)
    -- 8. UI
    WaterScene.renderUI(nvg, x, y, w, h)
end

-- ============================================================================
-- Layer 1: Base — 双层 UV 滚动水面底色
-- ============================================================================

function WaterScene.renderBase(nvg, x, y, w, h)
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillColor(nvg, nvgRGBA(30, 85, 130, 255))
    nvgFill(nvg)

    if not imgBaseTile_ or imgBaseTile_ <= 0 then return end

    local minDim = math.min(w, h)
    local tile1 = minDim / 0.55
    local flow1X = 0.006 * tile1 * time_
    local flow1Y = 0.012 * tile1 * time_

    local pat1 = nvgImagePattern(nvg,
        x + flow1X, y + flow1Y, tile1, tile1, 0, imgBaseTile_, 1.0)
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillPaint(nvg, pat1)
    nvgFill(nvg)

    local tile2 = minDim / 0.75
    local flow2X = -0.004 * tile2 * time_
    local flow2Y =  0.008 * tile2 * time_

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

-- ============================================================================
-- Layer 2: Caustic (轻微焦散, 保留水面质感)
-- ============================================================================

function WaterScene.renderCaustic(nvg, x, y, w, h)
    if not imgCaustic_ or imgCaustic_ <= 0 then return end

    local minDim = math.min(w, h)
    local tileC1 = minDim / 1.8
    local flowC1X = -0.008 * tileC1 * time_
    local flowC1Y =  0.005 * tileC1 * time_
    local tileC2 = minDim / 2.5
    local flowC2X =  0.006 * tileC2 * time_
    local flowC2Y = -0.007 * tileC2 * time_

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

-- ============================================================================
-- Layer 3: 鱼影
-- ============================================================================

function WaterScene.renderFishShadows(nvg, x, y, w, h)
    if not imgFishSheet_ or imgFishSheet_ <= 0 or fishSheetW_ == 0 then return end

    -- atlas 布局: 3列 × 2行 = 6帧游泳序列帧 (同一种鱼, 鱼头朝左)
    local cols, rows = 3, 2
    local cellW = fishSheetW_ / cols
    local cellH = fishSheetH_ / rows

    -- ping-pong 序列: 0,1,2,3,4,5,4,3,2,1 (10帧一循环, 无跳变)
    local pingPong = { 0, 1, 2, 3, 4, 5, 4, 3, 2, 1 }
    local pingPongLen = #pingPong

    -- 帧动画参数
    local animFps = 2     -- 每秒 2 帧, 缓慢柔和摆尾

    local allFish = FishSwarmSystem.getAllFish()

    for _, f in ipairs(allFish) do
        local fx = x + f.x * w
        local fy = y + f.y * h
        local s = f.size
        local t = time_ + f.phase
        local fishAlpha = f.alpha or 0.35

        -- 跳过屏幕外的鱼 (性能优化)
        if fx < x - s or fx > x + w + s or fy < y - s or fy > y + h + s then
            goto continue
        end

        -- 水面折射扭曲 (波次鱼减弱, 它们移动更快)
        local distortMult = f.isWave and 0.5 or 1.0
        local distortStrength = math.min(w, h) * 0.012 * distortMult
        local distX = math.sin(t * 1.2 + f.phase * 2.0) * distortStrength
                    + math.sin(t * 2.5 + f.phase * 1.3) * distortStrength * 0.4
        local distY = math.cos(t * 1.0 + f.phase * 1.7) * distortStrength * 0.6
                    + math.cos(t * 2.1 + f.phase * 0.8) * distortStrength * 0.3

        -- 波次鱼个体抖动
        if f.isWave and f.jitterAmp then
            distX = distX + math.sin(t * 2.0 + f.jitterPhase) * f.jitterAmp * w
            distY = distY + math.cos(t * 1.7 + f.jitterPhase) * f.jitterAmp * h * 0.5
        end

        local warp = math.sin(t * 1.5) * 0.03
        local scaleWarp = 1.0 + math.sin(t * 0.8) * 0.04

        -- 根据速度方向计算倾斜角度，让鱼面朝运动方向
        local fvx = f.vx or 0
        local fvy = f.vy or 0
        local tilt = math.atan(fvy, math.abs(fvx) + 0.0001)

        -- 帧动画: ping-pong 循环, 避免首尾跳变
        local ppIdx = math.floor(t * animFps) % pingPongLen + 1  -- Lua 1-based
        local frameIdx = pingPong[ppIdx]
        local col = frameIdx % cols
        local row = math.floor(frameIdx / cols)

        local scale = s / cellW
        local drawH = cellH * scale

        nvgSave(nvg)
        nvgGlobalAlpha(nvg, fishAlpha)
        nvgTranslate(nvg, fx + distX, fy + distY)
        nvgRotate(nvg, warp + tilt * f.dir)
        -- 鱼头朝左: dir=1(向右游)翻转, dir=-1(向左游)不翻转
        nvgScale(nvg, f.dir * scaleWarp, scaleWarp)

        local pat = nvgImagePattern(nvg,
            -col * cellW * scale - s * 0.5,
            -row * cellH * scale - drawH * 0.5,
            fishSheetW_ * scale, fishSheetH_ * scale,
            0, imgFishSheet_, 1.0)

        nvgBeginPath(nvg)
        nvgRect(nvg, -s * 0.5, -drawH * 0.5, s, drawH)
        nvgFillPaint(nvg, pat)
        nvgFill(nvg)
        nvgRestore(nvg)

        ::continue::
    end
end

-- ============================================================================
-- Layer 4: 水面涟漪圆环
-- 每 2~3s 一个, 1.5s 扩散, alpha 淡出, 2~3 层叠加
-- ============================================================================

function WaterScene.renderRipples(nvg, x, y, w, h)
    if #ripples_ == 0 then return end

    local bs = boatState_
    local rippleCX = bs.cx + bs.swayX
    local rippleCY = bs.cy + bs.bobY

    nvgSave(nvg)
    for _, r in ipairs(ripples_) do
        local progress = r.age / r.maxAge  -- 0→1
        local radius = r.startR + (r.endR - r.startR) * progress
        -- alpha: 0.25 → 0, 使用 ease-out 曲线让消失更自然
        local alpha = 0.25 * (1.0 - progress * progress)

        if alpha < 0.005 then goto continue end

        nvgBeginPath(nvg)
        nvgCircle(nvg, rippleCX + r.offsetX, rippleCY + r.offsetY, radius)
        nvgStrokeColor(nvg, nvgRGBA(180, 220, 255, math.floor(alpha * 255)))
        nvgStrokeWidth(nvg, 1.2 + (1.0 - progress) * 0.8)  -- 线宽从 2 → 1.2
        nvgStroke(nvg)

        ::continue::
    end
    nvgRestore(nvg)
end

-- ============================================================================
-- Layer 5: 船底阴影
-- scale = 1.2 (宽高统一), 位置: 船中心向下偏移 6px
-- alpha = 0.45, 深蓝色调 (使用延迟跟随参数)
-- ============================================================================

function WaterScene.renderBoatShadow(nvg, x, y, w, h)
    local bs = boatState_

    local shadowW = bs.drawW * 1.2
    local shadowH = bs.drawH * 1.2

    -- 使用延迟跟随的参数, 实现 0.1s lag
    local sBobY  = bs.shadowBobY
    local sSwayX = bs.shadowSwayX
    local sRot   = bs.shadowRot

    if imgBoatShadow_ and imgBoatShadow_ > 0 then
        nvgSave(nvg)
        -- 船中心 + 延迟浮动/摇摆 + 向下偏移 6px
        nvgTranslate(nvg, bs.cx + sSwayX, bs.cy + sBobY + 6)
        nvgRotate(nvg, sRot * 0.5)
        nvgGlobalAlpha(nvg, 0.45)

        local pat = nvgImagePattern(nvg,
            -shadowW * 0.5, -shadowH * 0.5,
            shadowW, shadowH, 0, imgBoatShadow_, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, -shadowW * 0.5, -shadowH * 0.5, shadowW, shadowH)
        nvgFillPaint(nvg, pat)
        nvgFill(nvg)

        nvgRestore(nvg)
    else
        -- 备用: 程序化深蓝椭圆
        nvgSave(nvg)
        nvgTranslate(nvg, bs.cx + sSwayX, bs.cy + sBobY + 6)
        nvgRotate(nvg, sRot * 0.5)
        nvgGlobalAlpha(nvg, 0.45)
        nvgBeginPath(nvg)
        nvgEllipse(nvg, 0, 0, shadowW * 0.5, shadowH * 0.5)
        nvgFillColor(nvg, nvgRGBA(8, 25, 65, 255))
        nvgFill(nvg)
        nvgRestore(nvg)
    end
end

-- ============================================================================
-- Layer 6: 船尾泡沫 (半月形贴图 + 微粒气泡)
-- ============================================================================

function WaterScene.renderBoatWake(nvg, x, y, w, h)
    local bs = boatState_
    local wakeCX = bs.cx + bs.swayX
    local wakeCY = bs.cy + bs.bobY + bs.drawH * 0.45 + 10  -- 向后偏移 10px

    -- ---- 主贴图: 半月形泡沫 (多层叠加 + 加法混合增强) ----
    if imgBoatWake_ and imgBoatWake_ > 0 then
        local breathScale = 1.0 + math.sin(time_ * 2.0) * 0.03
        local drawW = bs.drawW * 0.85 * breathScale
        local drawH = drawW * (boatWakeH_ / boatWakeW_)

        nvgSave(nvg)
        nvgTranslate(nvg, wakeCX, wakeCY)

        -- 底层: 加法混合, 大范围柔光 (alpha 高, 让淡贴图叠出亮度)
        nvgGlobalCompositeBlendFunc(nvg, NVG_SRC_ALPHA, NVG_ONE)

        local pat = nvgImagePattern(nvg,
            -drawW * 0.5, -drawH * 0.5,
            drawW, drawH, 0, imgBoatWake_, 1.0)

        -- 叠 3 层, 逐层缩小, 中心更亮
        local layers = {
            { s = 1.0,  a = 0.6 },
            { s = 0.85, a = 0.5 },
            { s = 0.7,  a = 0.4 },
        }
        for _, L in ipairs(layers) do
            local lw = drawW * L.s
            local lh = drawH * L.s
            nvgGlobalAlpha(nvg, L.a)
            local lp = nvgImagePattern(nvg,
                -lw * 0.5, -lh * 0.5,
                lw, lh, 0, imgBoatWake_, 1.0)
            nvgBeginPath(nvg)
            nvgRect(nvg, -lw * 0.5, -lh * 0.5, lw, lh)
            nvgFillPaint(nvg, lp)
            nvgFill(nvg)
        end

        nvgRestore(nvg)
    end

    -- ---- 微粒气泡: 小圆点, 轻微向后漂移 ----
    for _, b in ipairs(wakeBubbles_) do
        local life = b.age / b.maxAge  -- 0→1
        local bAlpha = b.baseAlpha * (1.0 - life)
        if bAlpha < 0.01 then goto continueBubble end

        local bx = wakeCX + b.ox
        local by = wakeCY + b.oy + b.age * b.drift  -- 轻微向后

        nvgBeginPath(nvg)
        nvgCircle(nvg, bx, by, b.r * (1.0 - life * 0.3))
        nvgFillColor(nvg, nvgRGBA(220, 235, 255, math.floor(bAlpha * 255)))
        nvgFill(nvg)

        ::continueBubble::
    end
end

-- ============================================================================
-- Layer 6: 吃水感 — 船边缘外扩 2~3px 深蓝透明色
-- alpha 0.12~0.2, 让船看起来坐在水里
-- ============================================================================

function WaterScene.renderDraftEffect(nvg, x, y, w, h)
    local bs = boatState_

    -- 用一个比船体大 2~3px 的深蓝半透明圆角矩形模拟吃水线
    local expand = 2.5  -- 外扩像素
    local draftW = bs.drawW + expand * 2
    local draftH = bs.drawH + expand * 2
    -- alpha 微微波动 0.12~0.2
    local draftAlpha = 0.16 + math.sin(time_ * 1.8) * 0.04

    nvgSave(nvg)
    nvgTranslate(nvg, bs.cx + bs.swayX, bs.cy + bs.bobY)
    nvgRotate(nvg, bs.rot)
    nvgGlobalAlpha(nvg, draftAlpha)

    nvgBeginPath(nvg)
    -- 圆角让边缘更自然
    nvgRoundedRect(nvg, -draftW * 0.5, -draftH * 0.5, draftW, draftH, 6)
    nvgFillColor(nvg, nvgRGBA(10, 25, 60, 255))
    nvgFill(nvg)

    nvgRestore(nvg)
end

-- ============================================================================
-- Layer 7: 船体 (居中, 浮动, 微旋转)
-- ============================================================================

function WaterScene.renderBoatBase(nvg, x, y, w, h)
    if not imgBoatBase_ or imgBoatBase_ <= 0 then return end

    local bs = boatState_

    nvgSave(nvg)
    nvgTranslate(nvg, bs.cx + bs.swayX, bs.cy + bs.bobY)
    nvgRotate(nvg, bs.rot)

    local pat = nvgImagePattern(nvg,
        -bs.drawW * 0.5, -bs.drawH * 0.5,
        bs.drawW, bs.drawH, 0, imgBoatBase_, 1.0)
    nvgBeginPath(nvg)
    nvgRect(nvg, -bs.drawW * 0.5, -bs.drawH * 0.5, bs.drawW, bs.drawH)
    nvgFillPaint(nvg, pat)
    nvgFill(nvg)

    nvgRestore(nvg)
end

-- ============================================================================
-- Layer 8: UI — 状态文字 / 捕获弹窗
-- ============================================================================

function WaterScene.renderUI(nvg, x, y, w, h)
    local state = FishingSystem.state

    local statusTexts = {
        idle    = "按 空格 / F 抛竿",
        casting = "抛竿中...",
        waiting = "等待咬钩...",
        reeling = "有鱼上钩!",
        caught  = "钓到了!",
    }
    local statusText = statusTexts[state] or ""

    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 18)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER | NVG_ALIGN_BOTTOM)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 120))
    nvgText(nvg, x + w * 0.5 + 1, y + h - 19, statusText)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 220))
    nvgText(nvg, x + w * 0.5, y + h - 20, statusText)

    if catchInfo_ and catchTimer_ > 0 then
        WaterScene.renderCatchPopup(nvg, x, y, w, h)
    end
end

-- ============================================================================
-- 捕获弹窗渲染
-- ============================================================================

function WaterScene.renderCatchPopup(nvg, x, y, w, h)
    local info = catchInfo_
    if not info then return end

    local alpha = 1.0
    if catchTimer_ < 0.5 then alpha = catchTimer_ / 0.5 end
    local a = math.floor(alpha * 255)

    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, math.floor(a * 0.3)))
    nvgFill(nvg)

    local cardW = math.min(w * 0.75, 260)
    local cardH = 120
    local cx = x + w * 0.5 - cardW * 0.5
    local cy = y + h * 0.5 - cardH * 0.5

    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, cx, cy, cardW, cardH, 16)
    nvgFillColor(nvg, nvgRGBA(15, 40, 80, math.floor(a * 0.92)))
    nvgFill(nvg)

    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, cx, cy, cardW, cardH, 16)
    nvgStrokeColor(nvg, nvgRGBA(80, 160, 255, math.floor(a * 0.6)))
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)

    local qc = info.qualityData.color
    local value = math.floor(info.fishData.baseValue * info.qualityData.multiplier)

    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 20)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER | NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(qc[1], qc[2], qc[3], a))
    nvgText(nvg, x + w * 0.5, cy + 35,
        info.fishData.icon .. " " .. info.fishData.displayName)

    nvgFontSize(nvg, 14)
    nvgFillColor(nvg, nvgRGBA(200, 220, 240, a))
    nvgText(nvg, x + w * 0.5, cy + 65,
        info.qualityData.displayName .. "  " .. value)

    nvgFontSize(nvg, 11)
    nvgFillColor(nvg, nvgRGBA(150, 170, 200, math.floor(a * 0.6)))
    nvgText(nvg, x + w * 0.5, cy + cardH - 15, "自动关闭...")
end

return WaterScene
