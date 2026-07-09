-- ============================================================================
-- CatchAnimSystem: 捕获动画系统
-- ============================================================================
-- 流程:
--   1. 鱼影被滑过 → 从鱼群移除 (由 SwipeSystem 回调触发)
--   2. 消失位置出现水花波纹 (扩散圆环, 0.9s)
--   3. 波纹中心跳出一只鱼, 放大→缩小 模拟抛物线飞向木桶 (0.75s)
--   4. 鱼到达木桶时播放"落桶水花" (0.5s)
-- ============================================================================

local CatchAnimSystem = {}

-- ============================================================================
-- 配置
-- ============================================================================
local CONFIG = {
    -- 同心圆涟漪 (出水点)
    ripple = {
        duration   = 0.9,
        startR     = 4,
        endR       = 50,
        rings      = 5,
        ringDelay  = 0.06,
        ringGap    = 8,
    },
    -- 皇冠水花 (出水点)
    splash = {
        count      = 10,
        speed      = 80,
        lifetime   = 0.5,
        dotR       = 2.5,
        pillarH    = 30,
        pillarW    = 6,
        pillarDur  = 0.35,
    },
    -- 鱼飞行动画
    fly = {
        delay      = 0.15,   -- 波纹开始后多久鱼跳出
        duration   = 0.75,   -- 飞行持续时间 (稍加长, 留出落桶感)
        peakScale  = 1.8,    -- 抛物线顶点最大缩放
        endScale   = 0.55,   -- 到达木桶时缩放 (不要太小, 可见)
        arcHeight  = 0.25,   -- 抛物线高度 (屏幕高度比例)
    },
    -- 落桶水花 (木桶位置)
    landing = {
        duration   = 0.5,    -- 落桶水花持续时间
        dotCount   = 8,      -- 水滴数
        dotSpeed   = 50,     -- 水滴速度 (比出水小)
        dotR       = 2.0,    -- 水滴半径
        dotLife    = 0.35,   -- 水滴生命
        ringCount  = 2,      -- 涟漪圈数
        ringEndR   = 20,     -- 涟漪最大半径
    },
}

-- ============================================================================
-- 内部状态
-- ============================================================================

---@class CatchAnim
---@field phase string     "ripple" | "fly" | "done"
---@field time number      动画已经过时间
---@field sx number        捕获屏幕坐标 x
---@field sy number        捕获屏幕坐标 y
---@field tx number        目标 (木桶) 屏幕坐标 x
---@field ty number        目标 (木桶) 屏幕坐标 y
---@field variant number   鱼种 (1~4)
---@field dir number       鱼朝向 (1/-1)
---@field fishSize number  鱼影大小
---@field splashDots table 飞溅点数组 (出水)
---@field screenW number   屏幕逻辑宽
---@field screenH number   屏幕逻辑高
---@field fishImg number|nil  单独鱼图片句柄
---@field fishImgW number|nil 单独鱼图片宽
---@field fishImgH number|nil 单独鱼图片高
---@field landingTriggered boolean 是否已触发落桶水花

local anims_ = {}   -- CatchAnim[]

---@class LandingSplash  落桶水花效果
---@field time number   已经过时间
---@field cx number     木桶屏幕x
---@field cy number     木桶屏幕y
---@field dots table    飞溅水滴

---@type LandingSplash[]
local landingSplashes_ = {}

---@class CoinPopup  金币弹字效果
---@field time number     已经过时间
---@field x number        起始 x
---@field y number        起始 y
---@field amount number   金币数量
---@field duration number 持续时间
local coinPopups_ = {}

-- ============================================================================
-- 工具函数
-- ============================================================================

local function easeOutCubic(t)
    local t1 = 1.0 - t
    return 1.0 - t1 * t1 * t1
end

local function easeInOutQuad(t)
    if t < 0.5 then
        return 2 * t * t
    else
        return 1 - (-2 * t + 2) ^ 2 / 2
    end
end

--- ease-in quad (加速到达)
local function easeInQuad(t)
    return t * t
end

--- 创建出水皇冠水花
local function createSplashDots(cx, cy)
    local dots = {}
    local count = CONFIG.splash.count
    for i = 1, count do
        local angle = (i - 1) / count * math.pi * 2 + (math.random() - 0.5) * 0.4
        local spd = CONFIG.splash.speed * (0.6 + math.random() * 0.8)
        dots[i] = {
            x = cx, y = cy,
            vx = math.cos(angle) * spd,
            vy = -math.abs(math.sin(angle)) * spd * 0.8 - 30,
            life = 0,
            maxLife = CONFIG.splash.lifetime * (0.6 + math.random() * 0.8),
            baseR = CONFIG.splash.dotR * (0.6 + math.random() * 0.8),
            tailLen = 3 + math.random() * 4,
        }
    end
    return dots
end

--- 创建落桶水花水滴 (较小, 向四周溅射)
local function createLandingDots(cx, cy)
    local dots = {}
    local cfg = CONFIG.landing
    for i = 1, cfg.dotCount do
        local angle = (i - 1) / cfg.dotCount * math.pi * 2 + (math.random() - 0.5) * 0.5
        local spd = cfg.dotSpeed * (0.5 + math.random() * 1.0)
        dots[i] = {
            x = cx, y = cy,
            vx = math.cos(angle) * spd,
            vy = math.sin(angle) * spd * 0.5 - spd * 0.6,  -- 偏上抛
            life = 0,
            maxLife = cfg.dotLife * (0.6 + math.random() * 0.8),
            baseR = cfg.dotR * (0.6 + math.random() * 0.8),
        }
    end
    return dots
end

-- ============================================================================
-- 公开 API
-- ============================================================================

--- 触发金币弹字 (小鱼被捕获时调用)
---@param screenX number 弹字起始 x (逻辑坐标)
---@param screenY number 弹字起始 y (逻辑坐标)
---@param amount number 金币数量
function CatchAnimSystem.triggerCoinPopup(screenX, screenY, amount)
    coinPopups_[#coinPopups_ + 1] = {
        time     = 0,
        x        = screenX,
        y        = screenY,
        amount   = amount,
        duration = 1.2,
    }
end

--- 触发一次捕获动画
function CatchAnimSystem.trigger(screenX, screenY, targetX, targetY, variant, dir, fishSize, w, h, fishImgInfo)
    local anim = {
        phase      = "ripple",
        time       = 0,
        sx         = screenX,
        sy         = screenY,
        tx         = targetX,
        ty         = targetY,
        variant    = variant or 1,
        dir        = dir or 1,
        fishSize   = fishSize or 40,
        splashDots = createSplashDots(screenX, screenY),
        screenW    = w,
        screenH    = h,
        fishImg    = fishImgInfo and fishImgInfo.img or nil,
        fishImgW   = fishImgInfo and fishImgInfo.w or nil,
        fishImgH   = fishImgInfo and fishImgInfo.h or nil,
        landingTriggered = false,
    }
    anims_[#anims_ + 1] = anim
end

--- 每帧更新
function CatchAnimSystem.update(dt)
    -- 更新主动画
    local i = 1
    while i <= #anims_ do
        local a = anims_[i]
        a.time = a.time + dt

        -- 更新出水飞溅点
        for _, d in ipairs(a.splashDots) do
            if d.life < d.maxLife then
                d.life = d.life + dt
                d.x = d.x + d.vx * dt
                d.y = d.y + d.vy * dt
                d.vy = d.vy + 120 * dt
            end
        end

        -- 阶段转换
        if a.phase == "ripple" then
            if a.time >= CONFIG.ripple.duration + 0.2 then
                a.phase = "done"
            end
        end

        -- 检测鱼飞行是否结束 → 触发落桶水花
        local flyStart = CONFIG.fly.delay
        local flyEnd = flyStart + CONFIG.fly.duration
        if a.time >= flyEnd and not a.landingTriggered then
            a.landingTriggered = true
            -- 生成落桶水花
            landingSplashes_[#landingSplashes_ + 1] = {
                time = 0,
                cx   = a.tx,
                cy   = a.ty,
                dots = createLandingDots(a.tx, a.ty),
            }
        end

        -- 清理已完成
        local totalDuration = math.max(CONFIG.ripple.duration + 0.2, flyEnd + 0.05)
        if a.time >= totalDuration then
            table.remove(anims_, i)
        else
            i = i + 1
        end
    end

    -- 更新金币弹字
    local k = 1
    while k <= #coinPopups_ do
        local cp = coinPopups_[k]
        cp.time = cp.time + dt
        if cp.time >= cp.duration then
            ---@diagnostic disable-next-line: param-type-mismatch
            table.remove(coinPopups_, k)
        else
            k = k + 1
        end
    end

    -- 更新落桶水花
    local j = 1
    while j <= #landingSplashes_ do
        local ls = landingSplashes_[j]
        ls.time = ls.time + dt
        -- 更新水滴
        for _, d in ipairs(ls.dots) do
            if d.life < d.maxLife then
                d.life = d.life + dt
                d.x = d.x + d.vx * dt
                d.y = d.y + d.vy * dt
                d.vy = d.vy + 100 * dt  -- 重力
            end
        end
        if ls.time >= CONFIG.landing.duration then
            ---@diagnostic disable-next-line: param-type-mismatch
            table.remove(landingSplashes_, j)
        else
            j = j + 1
        end
    end
end

--- 是否有动画正在播放
function CatchAnimSystem.isPlaying()
    return #anims_ > 0 or #landingSplashes_ > 0 or #coinPopups_ > 0
end

--- 获取当前动画数量
function CatchAnimSystem.getCount()
    return #anims_
end

-- ============================================================================
-- 渲染: 出水波纹层
-- ============================================================================

function CatchAnimSystem.renderRipples(nvg)
    for _, a in ipairs(anims_) do
        local t = a.time
        local cfg = CONFIG.ripple
        local splashCfg = CONFIG.splash

        if t > cfg.duration + 0.2 then goto continue end

        local progress = math.min(1.0, t / cfg.duration)

        -- 1. 同心圆涟漪
        for ring = 1, cfg.rings do
            local ringDelay = (ring - 1) * cfg.ringDelay
            local ringT = t - ringDelay
            if ringT < 0 then goto nextRing end

            local ringDuration = cfg.duration - ringDelay
            local ringProgress = math.min(1.0, ringT / ringDuration)
            local baseR = cfg.startR + (cfg.endR - cfg.startR) * easeOutCubic(ringProgress)
            local radius = baseR + (ring - 1) * cfg.ringGap * (0.3 + ringProgress * 0.7)

            local ringAlphaMax = 0.55 - (ring - 1) * 0.08
            local alpha
            if ringProgress < 0.15 then
                alpha = ringProgress / 0.15 * ringAlphaMax
            else
                alpha = ringAlphaMax * (1.0 - (ringProgress - 0.15) / 0.85)
            end
            alpha = math.max(0, alpha)

            local lineW = (1.8 - (ring - 1) * 0.2) * (1.0 - ringProgress * 0.5)
            lineW = math.max(0.5, lineW)

            local b = math.floor(200 + (ring - 1) * 10)
            nvgBeginPath(nvg)
            nvgCircle(nvg, a.sx, a.sy, radius)
            nvgStrokeColor(nvg, nvgRGBA(180, 220, b, math.floor(alpha * 255)))
            nvgStrokeWidth(nvg, lineW)
            nvgStroke(nvg)

            ::nextRing::
        end

        -- 2. 中心水柱
        local pillarT = t / splashCfg.pillarDur
        if pillarT < 1.0 then
            local pillarProgress
            if pillarT < 0.3 then
                pillarProgress = pillarT / 0.3
            else
                pillarProgress = 1.0 - (pillarT - 0.3) / 0.7
            end
            local ph = splashCfg.pillarH * easeOutCubic(pillarProgress)
            local pw = splashCfg.pillarW * (0.8 + pillarProgress * 0.2)
            local pillarAlpha = (1.0 - pillarT) * 0.7

            nvgSave(nvg)
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, a.sx - pw * 0.5, a.sy)
            nvgLineTo(nvg, a.sx - pw * 0.25, a.sy - ph)
            nvgLineTo(nvg, a.sx + pw * 0.25, a.sy - ph)
            nvgLineTo(nvg, a.sx + pw * 0.5, a.sy)
            nvgClosePath(nvg)
            nvgFillColor(nvg, nvgRGBA(200, 235, 255, math.floor(pillarAlpha * 255)))
            nvgFill(nvg)

            nvgBeginPath(nvg)
            nvgCircle(nvg, a.sx, a.sy - ph, pw * 0.35)
            nvgFillColor(nvg, nvgRGBA(220, 245, 255, math.floor(pillarAlpha * 200)))
            nvgFill(nvg)
            nvgRestore(nvg)
        end

        -- 3. 弧形飞溅水滴
        for _, d in ipairs(a.splashDots) do
            if d.life < d.maxLife then
                local lifeRatio = d.life / d.maxLife
                local dAlpha = (1.0 - lifeRatio)
                dAlpha = dAlpha * dAlpha
                local dR = d.baseR * (1.0 - lifeRatio * 0.4)

                nvgSave(nvg)
                nvgTranslate(nvg, d.x, d.y)

                local speed = math.sqrt(d.vx * d.vx + d.vy * d.vy)
                if speed > 10 then
                    local tailX = -d.vx / speed * d.tailLen * (1.0 - lifeRatio)
                    local tailY = -d.vy / speed * d.tailLen * (1.0 - lifeRatio)
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, 0, 0)
                    nvgLineTo(nvg, tailX, tailY)
                    nvgStrokeColor(nvg, nvgRGBA(200, 235, 255, math.floor(dAlpha * 120)))
                    nvgStrokeWidth(nvg, dR * 0.8)
                    nvgLineCap(nvg, NVG_ROUND)
                    nvgStroke(nvg)
                end

                nvgBeginPath(nvg)
                nvgCircle(nvg, 0, 0, dR)
                nvgFillColor(nvg, nvgRGBA(210, 240, 255, math.floor(dAlpha * 200)))
                nvgFill(nvg)

                nvgBeginPath(nvg)
                nvgCircle(nvg, -dR * 0.2, -dR * 0.2, dR * 0.4)
                nvgFillColor(nvg, nvgRGBA(255, 255, 255, math.floor(dAlpha * 150)))
                nvgFill(nvg)

                nvgRestore(nvg)
            end
        end

        -- 4. 中心水花圈
        if t < 0.4 then
            local baseAlpha = (1.0 - t / 0.4) * 0.5
            local baseR = 8 + t / 0.4 * 12
            nvgBeginPath(nvg)
            nvgEllipse(nvg, a.sx, a.sy, baseR, baseR * 0.5)
            nvgStrokeColor(nvg, nvgRGBA(200, 235, 255, math.floor(baseAlpha * 255)))
            nvgStrokeWidth(nvg, 1.5)
            nvgStroke(nvg)
            nvgFillColor(nvg, nvgRGBA(200, 235, 255, math.floor(baseAlpha * 80)))
            nvgFill(nvg)
        end

        ::continue::
    end
end

-- ============================================================================
-- 渲染: 落桶水花 (在船体/木桶上方)
-- ============================================================================

function CatchAnimSystem.renderLandingSplash(nvg)
    local lcfg = CONFIG.landing

    for _, ls in ipairs(landingSplashes_) do
        local t = ls.time

        -- 1. 涟漪圈 (小, 快速扩散)
        for ring = 1, lcfg.ringCount do
            local ringDelay = (ring - 1) * 0.05
            local ringT = t - ringDelay
            if ringT < 0 then goto nextRing end

            local ringProgress = math.min(1.0, ringT / (lcfg.duration * 0.8))
            local radius = 3 + lcfg.ringEndR * easeOutCubic(ringProgress)
                         + (ring - 1) * 6

            local alphaMax = 0.5 - (ring - 1) * 0.15
            local alpha
            if ringProgress < 0.2 then
                alpha = ringProgress / 0.2 * alphaMax
            else
                alpha = alphaMax * (1.0 - (ringProgress - 0.2) / 0.8)
            end
            alpha = math.max(0, alpha)

            local lineW = (1.5 - (ring - 1) * 0.3) * (1.0 - ringProgress * 0.5)
            lineW = math.max(0.4, lineW)

            nvgBeginPath(nvg)
            nvgCircle(nvg, ls.cx, ls.cy, radius)
            nvgStrokeColor(nvg, nvgRGBA(180, 220, 240, math.floor(alpha * 255)))
            nvgStrokeWidth(nvg, lineW)
            nvgStroke(nvg)

            ::nextRing::
        end

        -- 2. 中心水花圆 (小白圆, 快闪)
        if t < 0.15 then
            local flashAlpha = (1.0 - t / 0.15) * 0.6
            local flashR = 4 + t / 0.15 * 8
            nvgBeginPath(nvg)
            nvgCircle(nvg, ls.cx, ls.cy, flashR)
            nvgFillColor(nvg, nvgRGBA(220, 245, 255, math.floor(flashAlpha * 255)))
            nvgFill(nvg)
        end

        -- 3. 飞溅水滴
        for _, d in ipairs(ls.dots) do
            if d.life < d.maxLife then
                local lifeRatio = d.life / d.maxLife
                local dAlpha = (1.0 - lifeRatio)
                dAlpha = dAlpha * dAlpha
                local dR = d.baseR * (1.0 - lifeRatio * 0.5)

                nvgBeginPath(nvg)
                nvgCircle(nvg, d.x, d.y, dR)
                nvgFillColor(nvg, nvgRGBA(210, 240, 255, math.floor(dAlpha * 200)))
                nvgFill(nvg)

                -- 高光
                if dR > 1.0 then
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, d.x - dR * 0.2, d.y - dR * 0.2, dR * 0.35)
                    nvgFillColor(nvg, nvgRGBA(255, 255, 255, math.floor(dAlpha * 120)))
                    nvgFill(nvg)
                end
            end
        end
    end
end

-- ============================================================================
-- 渲染: 金币弹字层 (在飞行鱼上方)
-- ============================================================================

function CatchAnimSystem.renderCoinPopups(nvg)
    for _, cp in ipairs(coinPopups_) do
        local t = cp.time / cp.duration  -- 0→1

        -- 位置: 从捕获点上浮 60px
        local floatY = cp.y - 60 * easeOutCubic(t)

        -- 透明度: 前80%全显示, 后20%淡出
        local alpha
        if t < 0.8 then
            alpha = 1.0
        else
            alpha = 1.0 - (t - 0.8) / 0.2
        end

        -- 缩放: 弹出效果
        local scale
        if t < 0.15 then
            scale = 0.5 + easeOutCubic(t / 0.15) * 0.7  -- 0.5→1.2
        elseif t < 0.3 then
            scale = 1.2 - (t - 0.15) / 0.15 * 0.2       -- 1.2→1.0
        else
            scale = 1.0
        end

        local text = string.format("$ %d", cp.amount)

        nvgSave(nvg)
        nvgTranslate(nvg, cp.x, floatY)
        nvgScale(nvg, scale, scale)
        nvgGlobalAlpha(nvg, alpha)

        -- 文字设置
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 22)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

        -- 描边 (深色轮廓)
        nvgFontBlur(nvg, 3)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, math.floor(alpha * 160)))
        nvgText(nvg, 0, 0, text)

        -- 正文 (白色)
        nvgFontBlur(nvg, 0)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, math.floor(alpha * 255)))
        nvgText(nvg, 0, 0, text)

        nvgRestore(nvg)
    end
end

-- ============================================================================
-- 渲染: 鱼跳出飞行层
-- ============================================================================

function CatchAnimSystem.renderFlyingFish(nvg, imgFishSheet, sheetW, sheetH)
    for _, a in ipairs(anims_) do
        local flyCfg = CONFIG.fly
        local flyStart = flyCfg.delay
        local flyEnd = flyStart + flyCfg.duration

        if a.time < flyStart or a.time >= flyEnd then goto continue end

        local flyT = (a.time - flyStart) / flyCfg.duration  -- 0→1

        -- 位置: 前80%匀速飞行, 后20%加速冲向木桶 (落桶感)
        local easeT
        if flyT < 0.8 then
            easeT = easeInOutQuad(flyT / 0.8) * 0.85  -- 前80%时间走85%路程
        else
            local tailT = (flyT - 0.8) / 0.2  -- 0→1
            easeT = 0.85 + easeInQuad(tailT) * 0.15   -- 后20%加速冲完剩余15%
        end

        local px = a.sx + (a.tx - a.sx) * easeT
        local py = a.sy + (a.ty - a.sy) * easeT

        -- 抛物线高度: 在前70%有弧度, 后30%直冲下去
        local arcT = math.min(flyT / 0.7, 1.0)
        local arcOffset = -4 * arcT * (arcT - 1.0) * a.screenH * flyCfg.arcHeight
        -- 后30%弧度衰减, 让鱼"砸"向木桶
        if flyT > 0.7 then
            local fadeArc = 1.0 - (flyT - 0.7) / 0.3
            arcOffset = arcOffset * fadeArc
        end
        py = py - arcOffset

        -- 缩放: 弹出→高点→缓缩→落桶时微弹
        local scale
        if flyT < 0.3 then
            -- 弹出放大
            local st = flyT / 0.3
            scale = 1.0 + (flyCfg.peakScale - 1.0) * easeOutCubic(st)
        elseif flyT < 0.85 then
            -- 缓慢缩小
            local st = (flyT - 0.3) / 0.55
            scale = flyCfg.peakScale + (flyCfg.endScale - flyCfg.peakScale) * st
        else
            -- 最后15%: 微微压扁 (squash, 落桶感)
            local st = (flyT - 0.85) / 0.15
            scale = flyCfg.endScale * (1.0 - st * 0.3)  -- 再缩小30%
        end

        -- 透明度: 保持可见直到最后一刻
        local alpha
        if flyT < 0.08 then
            alpha = flyT / 0.08  -- 快速淡入
        elseif flyT > 0.92 then
            alpha = (1.0 - flyT) / 0.08  -- 最后8%才淡出 (落入桶中)
        else
            alpha = 1.0
        end

        -- 旋转: 后半段鱼向下旋转, 模拟落入感
        local fishRot = 0
        if flyT > 0.6 then
            local rotT = (flyT - 0.6) / 0.4
            fishRot = rotT * rotT * 0.4  -- 最多旋转约23度
        end

        nvgSave(nvg)
        nvgGlobalAlpha(nvg, alpha)
        nvgTranslate(nvg, px, py)

        -- ============================================================
        -- 优先使用单独鱼图片
        -- ============================================================
        if a.fishImg and a.fishImg > 0 and a.fishImgW and a.fishImgW > 0 then
            local imgW = a.fishImgW
            local imgH = a.fishImgH
            local imgRatio = imgH / imgW
            local drawW = a.fishSize * scale
            local drawH = drawW * imgRatio

            -- squash 效果: 最后压扁 (宽变大, 高变小)
            local squashX, squashY = 1.0, 1.0
            if flyT > 0.85 then
                local sq = (flyT - 0.85) / 0.15
                squashX = 1.0 + sq * 0.2   -- 横向拉宽
                squashY = 1.0 - sq * 0.25  -- 纵向压扁
            end

            nvgRotate(nvg, fishRot * a.dir)
            nvgScale(nvg, a.dir * squashX, squashY)

            local pat = nvgImagePattern(nvg,
                -drawW * 0.5, -drawH * 0.5,
                drawW, drawH, 0, a.fishImg, 1.0)
            nvgBeginPath(nvg)
            nvgRect(nvg, -drawW * 0.5, -drawH * 0.5, drawW, drawH)
            nvgFillPaint(nvg, pat)
            nvgFill(nvg)
        -- ============================================================
        -- 降级: 使用 atlas
        -- ============================================================
        elseif imgFishSheet and imgFishSheet > 0 and sheetW > 0 then
            local cols, rows = 4, 4
            local cellW = sheetW / cols
            local cellH = sheetH / rows
            local col = 0
            local row = (a.variant or 1) - 1

            local atlasFlip = (a.variant == 1) and 1 or -1
            nvgRotate(nvg, fishRot * a.dir)
            nvgScale(nvg, -a.dir * atlasFlip * scale, scale)

            local baseImgScale = a.fishSize / cellW
            local baseDrawH = cellH * baseImgScale

            local pat = nvgImagePattern(nvg,
                -col * cellW * baseImgScale - a.fishSize * 0.5,
                -row * cellH * baseImgScale - baseDrawH * 0.5,
                sheetW * baseImgScale, sheetH * baseImgScale,
                0, imgFishSheet, 1.0)

            nvgBeginPath(nvg)
            nvgRect(nvg, -a.fishSize * 0.5, -baseDrawH * 0.5, a.fishSize, baseDrawH)
            nvgFillPaint(nvg, pat)
            nvgFill(nvg)
        end

        nvgRestore(nvg)

        ::continue::
    end
end

return CatchAnimSystem
