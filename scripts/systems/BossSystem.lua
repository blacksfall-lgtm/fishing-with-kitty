-- ============================================================================
-- BossSystem: 鱼王事件系统
-- ============================================================================
-- 每100秒触发一次鱼王事件:
--   1. 暴风雨渐入 (环境变暗, 海面波动增强, 雨滴特效)
--   2. 鱼王从屏幕边缘进入, 沿直线缓慢穿越
--   3. 玩家滑动命中鱼王可造成固定伤害 (多次命中击杀)
--   4. 鱼王离场 → 暴风雨渐退 → 恢复正常
-- ============================================================================

local GameConfig = require("config.GameConfig")
local GameState  = require("state.GameState")

local BossSystem = {}

-- ============================================================================
-- 配置
-- ============================================================================
local CONFIG = {
    -- 计时
    spawnInterval    = 100,     -- 鱼王间隔 (秒)
    firstDelay       = 80,     -- 首次等待 (秒), 即第20秒触发

    -- 暴风雨
    stormFadeIn      = 2.0,    -- 暴风雨渐入时间
    stormFadeOut     = 2.0,    -- 暴风雨渐退时间
    stormDarkAlpha   = 0.45,   -- 最大暗度 (0~1)
    stormWaveBoost   = 2.2,    -- 波动增强倍率 (暴风雨级别)

    -- 雨滴粒子
    rainCount        = 180,    -- 雨滴数量 (暴风雨级别)
    rainSpeedMin     = 500,    -- 雨速下限 (px/s)
    rainSpeedMax     = 900,    -- 雨速上限
    rainLenMin       = 14,     -- 雨滴线段长度下限
    rainLenMax       = 32,     -- 雨滴线段长度上限
    rainAngle        = 0.20,   -- 雨滴倾斜角度 (弧度, 稍大模拟风吹)
    rainAlpha        = 0.5,    -- 雨滴不透明度

    -- 闪电闪屏
    lightningMinInterval = 2.0,  -- 闪电最小间隔 (秒)
    lightningMaxInterval = 6.0,  -- 闪电最大间隔 (秒)
    lightningFlashDur    = 0.12, -- 单次闪光持续 (秒)
    lightningDoubleChance= 0.4,  -- 双闪概率 (0~1)
    lightningDoublePause = 0.08, -- 双闪间隔 (秒)
    lightningMaxAlpha    = 0.7,  -- 闪光最大不透明度

    -- 鱼王
    bossHp           = 600,    -- 鱼王总生命值
    bossDamage       = 1,      -- 每次命中伤害 (已弃用, 由 calculateSwipeDamage 计算)
    bossSizeMult     = 3.0,    -- 大型鱼尺寸倍率
    bossBaseSize     = 105,    -- 大型鱼最大基准 (px)
    bossSpeed        = 0.04,   -- 穿越速度 (归一化/秒, ~25s穿屏)
    bossAlpha        = 0.85,   -- 鱼王阴影透明度
    bossHitRadius    = 0.7,    -- 碰撞半径 = bossSize * 此值

    -- HP条
    hpBarW           = 80,     -- HP条宽度 (px)
    hpBarH           = 8,      -- HP条高度 (px)
    hpBarOffsetY     = -20,    -- 相对鱼王中心的 Y 偏移 (向上)
    hpBarBgColor     = { 0, 0, 0, 160 },
    hpBarFillColor   = { 220, 50, 50, 255 },
    hpBarBorderColor = { 255, 255, 255, 120 },

    -- 受击闪白
    hitFlashDuration = 0.15,   -- 闪白持续时间
}

-- ============================================================================
-- 状态
-- ============================================================================

---@alias BossPhase "idle"|"storm_fadein"|"boss_active"|"storm_fadeout"

local phase_       = "idle"       ---@type BossPhase
local timer_       = 0            -- 距下次鱼王/当前阶段计时
local stormT_      = 0            -- 暴风雨强度 (0~1)

-- 鱼王实体
local boss_ = nil   -- { x, y, vx, vy, hp, maxHp, size, dir, variant, phase }

-- 雨滴粒子池
local rainDrops_ = {}

-- 受击闪白
local hitFlashTimer_ = 0

-- 闪电闪屏
local lightningTimer_     = 0     -- 距下次闪电的倒计时
local lightningFlashT_    = 0     -- 当前闪光剩余时间 (>0 = 正在闪)
local lightningPhase_     = 0     -- 0=等待, 1=第一闪, 2=暂停, 3=第二闪
local lightningPauseT_    = 0     -- 双闪间隔倒计时
local lightningIsDouble_  = false -- 本次是否双闪

-- 回调
local onBossDefeated_ = nil       -- fun(boss)
local onBossEscaped_  = nil       -- fun(boss)

-- 连击计数 (鱼王专属)
local bossCombo_    = 0

-- 命中去重 (每次滑动只命中一次)
local hitThisSwipe_ = false
local lastSwipeId_  = 0           -- 用 SwipeSystem 滑动状态区分

-- ============================================================================
-- 闪电闪屏更新
-- ============================================================================

local function randomLightningInterval()
    return CONFIG.lightningMinInterval + math.random() * (CONFIG.lightningMaxInterval - CONFIG.lightningMinInterval)
end

local function updateLightning(dt)
    if stormT_ <= 0 then
        lightningPhase_ = 0
        return
    end

    if lightningPhase_ == 0 then
        -- 等待阶段: 倒计时触发下一次闪电
        lightningTimer_ = lightningTimer_ - dt * stormT_  -- 暴风雨越强闪电越频繁
        if lightningTimer_ <= 0 then
            -- 触发闪电
            lightningPhase_ = 1
            lightningFlashT_ = CONFIG.lightningFlashDur
            lightningIsDouble_ = math.random() < CONFIG.lightningDoubleChance
            lightningTimer_ = randomLightningInterval()
        end
    elseif lightningPhase_ == 1 then
        -- 第一次闪光
        lightningFlashT_ = lightningFlashT_ - dt
        if lightningFlashT_ <= 0 then
            if lightningIsDouble_ then
                lightningPhase_ = 2
                lightningPauseT_ = CONFIG.lightningDoublePause
            else
                lightningPhase_ = 0
            end
        end
    elseif lightningPhase_ == 2 then
        -- 双闪间暂停
        lightningPauseT_ = lightningPauseT_ - dt
        if lightningPauseT_ <= 0 then
            lightningPhase_ = 3
            lightningFlashT_ = CONFIG.lightningFlashDur * 0.7  -- 第二闪稍短
        end
    elseif lightningPhase_ == 3 then
        -- 第二次闪光
        lightningFlashT_ = lightningFlashT_ - dt
        if lightningFlashT_ <= 0 then
            lightningPhase_ = 0
        end
    end
end

-- ============================================================================
-- 雨滴粒子
-- ============================================================================

local function initRainDrops(screenW, screenH)
    rainDrops_ = {}
    for i = 1, CONFIG.rainCount do
        rainDrops_[i] = {
            x     = math.random() * screenW * 1.2 - screenW * 0.1,
            y     = math.random() * screenH,
            speed = CONFIG.rainSpeedMin + math.random() * (CONFIG.rainSpeedMax - CONFIG.rainSpeedMin),
            len   = CONFIG.rainLenMin + math.random() * (CONFIG.rainLenMax - CONFIG.rainLenMin),
            alpha = 0.2 + math.random() * 0.3,
        }
    end
end

local function updateRainDrops(dt, screenW, screenH)
    local sinA = math.sin(CONFIG.rainAngle)
    local cosA = math.cos(CONFIG.rainAngle)
    for _, d in ipairs(rainDrops_) do
        d.y = d.y + d.speed * cosA * dt
        d.x = d.x + d.speed * sinA * dt
        -- 超出底部重置到顶部
        if d.y > screenH + 20 then
            d.y = -d.len - math.random() * 40
            d.x = math.random() * screenW * 1.2 - screenW * 0.1
            d.speed = CONFIG.rainSpeedMin + math.random() * (CONFIG.rainSpeedMax - CONFIG.rainSpeedMin)
        end
        -- 超出右侧重置
        if d.x > screenW + 20 then
            d.x = -10
        end
    end
end

-- ============================================================================
-- 鱼王生成
-- ============================================================================

local function spawnBoss()
    local size = CONFIG.bossBaseSize * CONFIG.bossSizeMult  -- ~315px

    -- 随机选择进入方向 (只用水平: 左→右 或 右→左)
    local side = math.random(1, 2)
    local startX, startY, vx, vy, dir

    if side == 1 then
        -- 左→右
        startX = -0.15
        vx = CONFIG.bossSpeed
        dir = 1
    else
        -- 右→左
        startX = 1.15
        vx = -CONFIG.bossSpeed
        dir = -1
    end

    -- Y 位置: 屏幕中下部 (0.4~0.7)
    startY = 0.4 + math.random() * 0.3
    vy = (math.random() - 0.5) * 0.005  -- 微微上下偏移

    boss_ = {
        x       = startX,
        y       = startY,
        vx      = vx,
        vy      = vy,
        hp      = CONFIG.bossHp,
        maxHp   = CONFIG.bossHp,
        size    = size,
        dir     = dir,
        variant = math.random(1, 4),  -- atlas 鱼种
        phase   = math.random() * 6.28,
    }

    hitFlashTimer_ = 0
    hitThisSwipe_ = false
    bossCombo_ = 0

    print(string.format("[BossSystem] 鱼王生成! HP=%d, 方向=%s, Y=%.2f, size=%.0f",
        boss_.maxHp, side == 1 and "左→右" or "右→左", startY, size))
end

-- ============================================================================
-- 公开 API
-- ============================================================================

--- 初始化
function BossSystem.init()
    phase_ = "idle"
    timer_ = CONFIG.spawnInterval - CONFIG.firstDelay  -- 第一次快速触发
    stormT_ = 0
    boss_ = nil
    rainDrops_ = {}
    hitFlashTimer_ = 0
    lightningTimer_ = randomLightningInterval()
    lightningPhase_ = 0
    lightningFlashT_ = 0
    print("[BossSystem] init done, 首次鱼王将在 " .. CONFIG.firstDelay .. "s 后出现")
end

--- 注册回调
function BossSystem.setCallbacks(onDefeated, onEscaped)
    onBossDefeated_ = onDefeated
    onBossEscaped_ = onEscaped
end

--- 鱼王是否在场
function BossSystem.isActive()
    return phase_ ~= "idle"
end

--- 获取暴风雨强度 (0~1, 供 WaterScene 调整波动)
function BossSystem.getStormIntensity()
    return stormT_
end

--- 获取鱼王数据 (渲染用)
function BossSystem.getBoss()
    return boss_
end

--- 获取配置 (渲染用)
function BossSystem.getConfig()
    return CONFIG
end

--- 获取受击闪白进度 (0=无, 0~1=闪白中)
function BossSystem.getHitFlash()
    if hitFlashTimer_ > 0 then
        return hitFlashTimer_ / CONFIG.hitFlashDuration
    end
    return 0
end

--- 获取鱼王连击数
function BossSystem.getCombo()
    return bossCombo_
end

--- 根据连击数获取鱼王伤害倍率
function BossSystem.getComboMultiplier(comboCount)
    local multiplier = 1.0
    for _, tier in ipairs(GameConfig.FISH_KING_COMBO) do
        if comboCount >= tier.minCombo then
            multiplier = tier.multiplier
        end
    end
    return multiplier
end

--- 计算一次划击对鱼王的伤害
function BossSystem.calculateSwipeDamage(shipTechLevel, comboCount)
    local baseDamage = GameConfig.FISH_KING_DAMAGE[shipTechLevel] or 15
    local comboMultiplier = BossSystem.getComboMultiplier(comboCount)
    return math.floor(baseDamage * comboMultiplier)
end

--- 对鱼王造成伤害
---@return boolean 是否成功命中
function BossSystem.damageBoss(amount)
    if not boss_ or phase_ ~= "boss_active" then return false end

    boss_.hp = boss_.hp - (amount or CONFIG.bossDamage)
    hitFlashTimer_ = CONFIG.hitFlashDuration

    print(string.format("[BossSystem] 鱼王受击! HP: %d/%d", boss_.hp, boss_.maxHp))

    if boss_.hp <= 0 then
        boss_.hp = 0
        -- 击败! 进入淡出
        phase_ = "storm_fadeout"
        timer_ = 0
        print("[BossSystem] 鱼王被击败!")
        if onBossDefeated_ then
            onBossDefeated_(boss_)
        end
    end

    return true
end

--- 每帧更新
---@param dt number
---@param screenW number 逻辑屏幕宽
---@param screenH number 逻辑屏幕高
function BossSystem.update(dt, screenW, screenH)
    -- 受击闪白计时
    if hitFlashTimer_ > 0 then
        hitFlashTimer_ = hitFlashTimer_ - dt
        if hitFlashTimer_ < 0 then hitFlashTimer_ = 0 end
    end

    -- 闪电更新
    updateLightning(dt)

    -- ================================================================
    -- 阶段状态机
    -- ================================================================
    if phase_ == "idle" then
        timer_ = timer_ + dt
        if timer_ >= CONFIG.spawnInterval then
            timer_ = 0
            phase_ = "storm_fadein"
            stormT_ = 0
            initRainDrops(screenW, screenH)
            print("[BossSystem] 暴风雨来临...")
        end

    elseif phase_ == "storm_fadein" then
        timer_ = timer_ + dt
        stormT_ = math.min(1.0, timer_ / CONFIG.stormFadeIn)
        updateRainDrops(dt, screenW, screenH)

        if timer_ >= CONFIG.stormFadeIn then
            phase_ = "boss_active"
            timer_ = 0
            spawnBoss()
        end

    elseif phase_ == "boss_active" then
        timer_ = timer_ + dt
        stormT_ = 1.0
        updateRainDrops(dt, screenW, screenH)

        -- 移动鱼王
        if boss_ then
            boss_.x = boss_.x + boss_.vx * dt
            boss_.y = boss_.y + boss_.vy * dt
            boss_.phase = boss_.phase + dt

            -- 检测鱼王是否离开屏幕
            if boss_.x < -0.25 or boss_.x > 1.25 then
                print("[BossSystem] 鱼王逃跑!")
                if onBossEscaped_ then
                    onBossEscaped_(boss_)
                end
                phase_ = "storm_fadeout"
                timer_ = 0
            end
        end

    elseif phase_ == "storm_fadeout" then
        timer_ = timer_ + dt
        stormT_ = math.max(0, 1.0 - timer_ / CONFIG.stormFadeOut)
        updateRainDrops(dt, screenW, screenH)

        if timer_ >= CONFIG.stormFadeOut then
            phase_ = "idle"
            timer_ = 0
            stormT_ = 0
            boss_ = nil
            rainDrops_ = {}
            print("[BossSystem] 暴风雨结束, 恢复正常捕鱼")
        end
    end
end

-- ============================================================================
-- 碰撞检测: 滑动轨迹线段 vs 鱼王
-- ============================================================================

--- 线段-圆碰撞 (复用 SwipeSystem 的逻辑)
local function lineCircleIntersect(x1, y1, x2, y2, cx, cy, r)
    local dx = x2 - x1
    local dy = y2 - y1
    local fx = x1 - cx
    local fy = y1 - cy
    local a = dx * dx + dy * dy
    if a < 0.0001 then
        return (fx * fx + fy * fy) <= r * r
    end
    local b = 2 * (fx * dx + fy * dy)
    local c = fx * fx + fy * fy - r * r
    local disc = b * b - 4 * a * c
    if disc < 0 then return false end
    disc = math.sqrt(disc)
    local t1 = (-b - disc) / (2 * a)
    local t2 = (-b + disc) / (2 * a)
    return (t1 >= 0 and t1 <= 1) or (t2 >= 0 and t2 <= 1) or (t1 < 0 and t2 > 1)
end

--- 检测滑动线段是否命中鱼王
---@param x1 number 线段起点 x (逻辑坐标)
---@param y1 number 线段起点 y
---@param x2 number 线段终点 x
---@param y2 number 线段终点 y
---@param screenW number 逻辑屏幕宽
---@param screenH number 逻辑屏幕高
---@return boolean 是否命中
function BossSystem.checkHit(x1, y1, x2, y2, screenW, screenH)
    if not boss_ or phase_ ~= "boss_active" then return false end

    local bx = boss_.x * screenW
    local by = boss_.y * screenH
    local radius = boss_.size * CONFIG.bossHitRadius

    if lineCircleIntersect(x1, y1, x2, y2, bx, by, radius) then
        bossCombo_ = bossCombo_ + 1
        local shipTech = GameState.boatLevel or 1
        local finalDmg = BossSystem.calculateSwipeDamage(shipTech, bossCombo_)
        print(string.format("[BossSystem] 连击 %d, 倍率 x%.2f, 伤害 %d",
            bossCombo_, BossSystem.getComboMultiplier(bossCombo_), finalDmg))
        return BossSystem.damageBoss(finalDmg)
    end

    return false
end

-- ============================================================================
-- 渲染: 暴风雨暗幕 (在所有鱼影之上, 船之下)
-- ============================================================================

function BossSystem.renderStormOverlay(nvg, x, y, w, h)
    if stormT_ <= 0 then return end

    local alpha = CONFIG.stormDarkAlpha * stormT_
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillColor(nvg, nvgRGBA(10, 15, 30, math.floor(alpha * 255)))
    nvgFill(nvg)
end

-- ============================================================================
-- 渲染: 鱼王阴影 (在暗幕上方, 使用 fish atlas)
-- ============================================================================

function BossSystem.renderBoss(nvg, x, y, w, h, imgFishSheet, sheetW, sheetH, time)
    if not boss_ or (phase_ ~= "boss_active" and phase_ ~= "storm_fadeout") then return end
    if not imgFishSheet or imgFishSheet <= 0 or sheetW == 0 then return end

    -- 鱼王在 storm_fadeout 阶段: 如果被击败则已消失, 如果逃跑则继续显示渐隐
    local bossAlpha = CONFIG.bossAlpha
    if phase_ == "storm_fadeout" then
        -- 击败后快速消失
        if boss_.hp <= 0 then
            bossAlpha = bossAlpha * math.max(0, 1.0 - timer_ / 0.5)
            if bossAlpha <= 0 then return end
        else
            bossAlpha = bossAlpha * stormT_
        end
    end

    -- 受击闪白
    local flashAlpha = 0
    if hitFlashTimer_ > 0 then
        flashAlpha = hitFlashTimer_ / CONFIG.hitFlashDuration
    end

    local bx = x + boss_.x * w
    local by = y + boss_.y * h
    local s = boss_.size
    local t = time + boss_.phase

    -- atlas 参数 (4x4)
    local cols, rows = 4, 4
    local cellW = sheetW / cols
    local cellH = sheetH / rows

    -- 帧动画 (ping-pong, 减慢: 1fps → 巨型鱼缓慢摆尾)
    local pingPong = { 0, 1, 2, 3, 2, 1 }
    local ppIdx = math.floor(t * 1.0) % #pingPong + 1
    local col = pingPong[ppIdx]
    local row = (boss_.variant or 1) - 1

    -- 水面折射扭曲 (减弱, 体型大)
    local distortStrength = math.min(w, h) * 0.006
    local distX = math.sin(t * 0.8) * distortStrength
    local distY = math.cos(t * 0.6) * distortStrength * 0.5

    local scale = s / cellW
    local drawH = cellH * scale
    local scaleWarp = 1.0 + math.sin(t * 0.5) * 0.02

    nvgSave(nvg)
    nvgGlobalAlpha(nvg, bossAlpha)
    nvgTranslate(nvg, bx + distX, by + distY)

    -- atlas 方向修正
    local atlasFlip = (boss_.variant == 1) and 1 or -1
    nvgScale(nvg, -boss_.dir * atlasFlip * scaleWarp, scaleWarp)

    local pat = nvgImagePattern(nvg,
        -col * cellW * scale - s * 0.5,
        -row * cellH * scale - drawH * 0.5,
        sheetW * scale, sheetH * scale,
        0, imgFishSheet, 1.0)

    nvgBeginPath(nvg)
    nvgRect(nvg, -s * 0.5, -drawH * 0.5, s, drawH)
    nvgFillPaint(nvg, pat)
    nvgFill(nvg)

    -- 受击闪白叠加
    if flashAlpha > 0 then
        nvgBeginPath(nvg)
        nvgRect(nvg, -s * 0.5, -drawH * 0.5, s, drawH)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, math.floor(flashAlpha * 180)))
        nvgFill(nvg)
    end

    nvgRestore(nvg)

    -- HP 条 (屏幕空间, 不受鱼王旋转影响)
    BossSystem.renderHpBar(nvg, bx + distX, by + distY, s)
end

-- ============================================================================
-- 渲染: HP 条 (跟随鱼王)
-- ============================================================================

function BossSystem.renderHpBar(nvg, bx, by, bossSize)
    if not boss_ then return end

    local barW = CONFIG.hpBarW
    local barH = CONFIG.hpBarH
    local barX = bx - barW * 0.5
    local barY = by - bossSize * 0.3 + CONFIG.hpBarOffsetY  -- 在鱼王上方

    local hpRatio = boss_.hp / boss_.maxHp

    nvgSave(nvg)

    -- 背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, barX - 1, barY - 1, barW + 2, barH + 2, 3)
    local bg = CONFIG.hpBarBgColor
    nvgFillColor(nvg, nvgRGBA(bg[1], bg[2], bg[3], bg[4]))
    nvgFill(nvg)

    -- 血量填充
    if hpRatio > 0 then
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, barX, barY, barW * hpRatio, barH, 2)
        -- 颜色随血量变化: 绿→黄→红
        local r, g, b
        if hpRatio > 0.5 then
            -- 绿→黄
            local t = (hpRatio - 0.5) / 0.5
            r = math.floor(255 * (1 - t) + 80 * t)
            g = 200
            b = 50
        else
            -- 黄→红
            local t = hpRatio / 0.5
            r = 220
            g = math.floor(200 * t + 50 * (1 - t))
            b = 50
        end
        nvgFillColor(nvg, nvgRGBA(r, g, b, 230))
        nvgFill(nvg)
    end

    -- 边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, barX - 1, barY - 1, barW + 2, barH + 2, 3)
    local bc = CONFIG.hpBarBorderColor
    nvgStrokeColor(nvg, nvgRGBA(bc[1], bc[2], bc[3], bc[4]))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)

    -- HP 文字 (小字)
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 10)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 200))
    nvgText(nvg, bx, barY + barH * 0.5,
        string.format("%d/%d", boss_.hp, boss_.maxHp))

    nvgRestore(nvg)
end

-- ============================================================================
-- 渲染: 雨滴粒子 (最上层, 在 UI 之下)
-- ============================================================================

function BossSystem.renderRain(nvg, x, y, w, h)
    if stormT_ <= 0 or #rainDrops_ == 0 then return end

    local sinA = math.sin(CONFIG.rainAngle)
    local cosA = math.cos(CONFIG.rainAngle)

    nvgSave(nvg)
    nvgLineCap(nvg, NVG_ROUND)

    for _, d in ipairs(rainDrops_) do
        local alpha = d.alpha * stormT_ * CONFIG.rainAlpha
        if alpha < 0.01 then goto continue end

        local endX = d.x + sinA * d.len
        local endY = d.y + cosA * d.len

        nvgBeginPath(nvg)
        nvgMoveTo(nvg, d.x, d.y)
        nvgLineTo(nvg, endX, endY)
        nvgStrokeColor(nvg, nvgRGBA(180, 200, 220, math.floor(alpha * 255)))
        nvgStrokeWidth(nvg, 1.2 + d.len * 0.03)  -- 长雨滴更粗
        nvgStroke(nvg)

        ::continue::
    end

    nvgRestore(nvg)
end

-- ============================================================================
-- 渲染: 闪电闪屏 (全屏白色闪光, 在雨滴之上)
-- ============================================================================

function BossSystem.renderLightningFlash(nvg, x, y, w, h)
    if lightningPhase_ == 0 then return end
    if lightningPhase_ == 2 then return end  -- 双闪间暂停不闪

    -- 闪光进度: 从 1→0 衰减
    local dur = CONFIG.lightningFlashDur
    if lightningPhase_ == 3 then dur = dur * 0.7 end
    local progress = math.max(0, lightningFlashT_ / dur)
    -- 使用 ease-out 曲线让闪光快速出现、缓慢消退
    local alpha = CONFIG.lightningMaxAlpha * progress * progress * stormT_

    if alpha < 0.01 then return end

    -- 主闪光: 偏冷白色
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillColor(nvg, nvgRGBA(220, 225, 255, math.floor(alpha * 255)))
    nvgFill(nvg)

    -- 第二闪稍微偏蓝, 更弱
    if lightningPhase_ == 3 then
        local alpha2 = alpha * 0.3
        nvgBeginPath(nvg)
        nvgRect(nvg, x, y, w, h)
        nvgFillColor(nvg, nvgRGBA(150, 180, 255, math.floor(alpha2 * 255)))
        nvgFill(nvg)
    end
end

--- 获取闪电闪光强度 (0~1, 供 WaterScene 做海面反馈)
function BossSystem.getLightningFlash()
    if lightningPhase_ == 1 or lightningPhase_ == 3 then
        local dur = CONFIG.lightningFlashDur
        if lightningPhase_ == 3 then dur = dur * 0.7 end
        return math.max(0, lightningFlashT_ / dur) * stormT_
    end
    return 0
end

--- 快捷键: 手动触发鱼王 (调试用)
function BossSystem.forceSpawn()
    if phase_ ~= "idle" then
        -- 强制结束当前事件
        phase_ = "idle"
        boss_ = nil
        rainDrops_ = {}
        stormT_ = 0
    end
    timer_ = CONFIG.spawnInterval  -- 立即触发
    print("[BossSystem] 手动触发鱼王事件")
end

return BossSystem
