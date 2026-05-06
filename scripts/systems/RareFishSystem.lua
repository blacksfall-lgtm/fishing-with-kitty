-- ============================================================================
-- RareFishSystem: 稀有鱼事件系统
-- ============================================================================
-- 每隔 45~90 秒随机出现一条金色鱼影:
--   - 高速闪过屏幕 (1~2秒可视窗口)
--   - 金色发光效果 (脉冲闪烁)
--   - 命中后必掉 1~2 词条鱼
-- ============================================================================

local GameConfig     = require("config.GameConfig")
local GameState      = require("state.GameState")
local AffixSystem    = require("systems.AffixSystem")
local CodexSystem    = require("systems.CodexSystem")
local ResearchSystem = require("systems.ResearchSystem")

local RareFishSystem = {}

-- ========== 配置 ==========
local CONFIG = {
    -- 刷新间隔
    spawnIntervalMin = 45,
    spawnIntervalMax = 90,
    -- 鱼影存活时间 (可视窗口)
    lifetime         = 1.8,   -- 秒
    -- 鱼影大小
    size             = 70,
    -- 速度倍率 (相对普通鱼)
    speedMult        = 3.0,
    -- 碰撞检测半径倍率
    hitRadiusMult    = 1.2,
    -- 金色发光
    glow = {
        pulseFreq    = 6.0,   -- 脉冲频率
        baseAlpha    = 0.7,   -- 基础透明度
        glowRadius   = 30,    -- 光晕半径
    },
    -- 预告 (出现前的提示)
    warning = {
        duration     = 1.5,   -- 预告持续时间
        text         = "稀有鱼出现!",
    },
}

-- ========== 状态 ==========
local spawnTimer_    = 0       -- 距下次刷新的计时
local nextInterval_  = 60      -- 下次刷新间隔
local rareFish_      = nil     -- 当前稀有鱼 { x, y, vx, vy, life, maxLife, size, dir, variant }
local warningTimer_  = -1      -- 预告计时 (-1=无)
local warningDir_    = 1       -- 预告方向 (1=从左, -1=从右)
local catchResult_   = nil     -- 最近一次捕获结果 (供 main.lua 读取)
local screenW_       = 1
local screenH_       = 1

-- ========== 内部函数 ==========

local function rollNextInterval()
    nextInterval_ = CONFIG.spawnIntervalMin
        + math.random() * (CONFIG.spawnIntervalMax - CONFIG.spawnIntervalMin)
end

local function spawnRareFish()
    -- 随机方向: 从左→右 或 从右→左
    local fromLeft = math.random() > 0.5
    local dir = fromLeft and 1 or -1

    -- 速度: 需要在 lifetime 内穿过屏幕 (~1.2个屏幕宽)
    local crossDist = 1.3  -- 归一化距离
    local speed = crossDist / CONFIG.lifetime

    -- y 位置: 随机在鱼活动区
    local yPos = 0.35 + math.random() * 0.45

    rareFish_ = {
        x       = fromLeft and -0.1 or 1.1,
        y       = yPos,
        vx      = dir * speed,
        vy      = (math.random() - 0.5) * 0.1,  -- 轻微上下漂移
        life    = 0,
        maxLife = CONFIG.lifetime,
        size    = CONFIG.size,
        dir     = dir,
        variant = math.random(1, 4),
        hit     = false,
    }

    print(string.format("[RareFish] 金色稀有鱼出现! dir=%d y=%.2f",
        dir, yPos))
end

-- ========== 公开 API ==========

--- 初始化
function RareFishSystem.init()
    spawnTimer_ = 0
    rareFish_ = nil
    warningTimer_ = -1
    catchResult_ = nil
    rollNextInterval()
    -- 首次出现稍快
    nextInterval_ = math.max(20, nextInterval_ * 0.5)
end

--- 每帧更新
---@param dt number
---@param w number 逻辑屏幕宽
---@param h number 逻辑屏幕高
function RareFishSystem.update(dt, w, h)
    screenW_ = w
    screenH_ = h

    -- 无稀有鱼: 等待刷新
    if not rareFish_ then
        spawnTimer_ = spawnTimer_ + dt

        -- 预告阶段
        if warningTimer_ >= 0 then
            warningTimer_ = warningTimer_ + dt
            if warningTimer_ >= CONFIG.warning.duration then
                warningTimer_ = -1
                spawnRareFish()
            end
        elseif spawnTimer_ >= nextInterval_ then
            -- 开始预告
            warningTimer_ = 0
            warningDir_ = math.random() > 0.5 and 1 or -1
            spawnTimer_ = 0
            rollNextInterval()
        end
        return
    end

    -- 更新稀有鱼位置
    local rf = rareFish_
    rf.life = rf.life + dt
    rf.x = rf.x + rf.vx * dt
    rf.y = rf.y + rf.vy * dt

    -- 存活超时或已出屏 → 消失
    if rf.life >= rf.maxLife or rf.x < -0.2 or rf.x > 1.2 then
        if not rf.hit then
            print("[RareFish] 稀有鱼已逃走!")
        end
        rareFish_ = nil
    end
end

--- 检测滑动线段是否命中稀有鱼
---@param x1 number 线段起点x (逻辑坐标)
---@param y1 number 线段起点y (逻辑坐标)
---@param x2 number 线段终点x (逻辑坐标)
---@param y2 number 线段终点y (逻辑坐标)
---@param w number 屏幕逻辑宽
---@param h number 屏幕逻辑高
---@return boolean 是否命中
function RareFishSystem.checkHit(x1, y1, x2, y2, w, h)
    if not rareFish_ or rareFish_.hit then return false end

    local rf = rareFish_
    local fx = rf.x * w
    local fy = rf.y * h
    local radius = rf.size * CONFIG.hitRadiusMult

    -- 线段-圆碰撞检测
    local dx, dy = x2 - x1, y2 - y1
    local fx1, fy1 = fx - x1, fy - y1
    local lenSq = dx * dx + dy * dy
    if lenSq < 0.001 then
        local dist = math.sqrt(fx1 * fx1 + fy1 * fy1)
        if dist <= radius then
            rf.hit = true
            return true
        end
        return false
    end
    local t = math.max(0, math.min(1, (fx1 * dx + fy1 * dy) / lenSq))
    local closestX = x1 + t * dx
    local closestY = y1 + t * dy
    local distSq = (fx - closestX)^2 + (fy - closestY)^2
    if distSq <= radius * radius then
        rf.hit = true
        return true
    end
    return false
end

--- 处理稀有鱼捕获: 生成词条鱼奖励
---@return table|nil 捕获结果 {fishId, qualityId, affixes, displayName, uid, summary, valueMult, screenX, screenY}
function RareFishSystem.processCapture()
    if not rareFish_ or not rareFish_.hit then return nil end

    local rf = rareFish_
    local screenX = rf.x * screenW_
    local screenY = rf.y * screenH_

    -- 根据当前海域随机选鱼种
    local zoneFish = GameConfig.FISH_BY_ZONE[GameState.currentZone]
        or GameConfig.FISH_BY_ZONE["nearshore"]
    local chosenFish = zoneFish[math.random(1, #zoneFish)]

    -- 品质: 偏高品质 (稀有鱼给更好的品质)
    local weights = chosenFish.qualityWeights or GameConfig.DEFAULT_QUALITY_WEIGHTS
    local boosted = {}
    for i, w in ipairs(weights) do
        -- 高品质权重提升 50%
        if i >= 3 then
            boosted[i] = w * 1.5
        else
            boosted[i] = w
        end
    end
    local totalW = 0
    for _, w in ipairs(boosted) do totalW = totalW + w end
    local roll = math.random() * totalW
    local qualityId = 1
    local acc = 0
    for i, w in ipairs(boosted) do
        acc = acc + w
        if roll <= acc then qualityId = i; break end
    end

    -- 必定 1~2 词条
    local affixes = AffixSystem.rollGuaranteedAffixes(1, 2)

    -- 图鉴记录
    CodexSystem.recordCatch(chosenFish.id, qualityId, affixes)

    -- 入仓
    local holdCap = GameConfig.FISH_HOLD_CAPACITY + ResearchSystem.getHoldCapacityBonus()
    if GameState:getTotalFishInHold() < holdCap then
        GameState:addFish(chosenFish.id, qualityId, 1)
    end

    -- 词条个体鱼
    local uid = GameState:addIndividualFish(chosenFish.id, qualityId, affixes)
    local summary = AffixSystem.getAffixSummary(affixes)
    local valueMult = AffixSystem.calcValueMultiplier(affixes)

    print(string.format("[RareFish] 捕获稀有鱼! uid=%d %s 品质%d 词条×%d [%s]",
        uid, chosenFish.displayName, qualityId, #affixes, summary))

    -- 清除稀有鱼
    rareFish_ = nil

    return {
        fishId      = chosenFish.id,
        qualityId   = qualityId,
        affixes     = affixes,
        displayName = chosenFish.displayName,
        fishName    = chosenFish.name,
        uid         = uid,
        summary     = summary,
        valueMult   = valueMult,
        screenX     = screenX,
        screenY     = screenY,
    }
end

--- 是否有稀有鱼正在屏幕上
---@return boolean
function RareFishSystem.isActive()
    return rareFish_ ~= nil and not rareFish_.hit
end

--- 获取稀有鱼数据 (渲染用)
---@return table|nil
function RareFishSystem.getRareFish()
    return rareFish_
end

--- 是否在预告阶段
---@return boolean, number timer (0~1 进度)
function RareFishSystem.isWarning()
    if warningTimer_ >= 0 then
        return true, warningTimer_ / CONFIG.warning.duration
    end
    return false, 0
end

--- 渲染稀有鱼影 (在鱼影层之上调用)
---@param nvg userdata
---@param x number 画布x
---@param y number 画布y
---@param w number 画布宽
---@param h number 画布高
---@param time number 全局时间 (用于动画)
function RareFishSystem.render(nvg, x, y, w, h, time)
    -- 渲染预告文字
    if warningTimer_ >= 0 then
        local progress = warningTimer_ / CONFIG.warning.duration
        -- 脉冲透明度
        local pulse = 0.5 + 0.5 * math.sin(progress * math.pi * 6)
        local alpha = pulse * (1.0 - progress * 0.3)

        nvgSave(nvg)
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 28)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

        -- 发光背景
        nvgFontBlur(nvg, 6)
        nvgFillColor(nvg, nvgRGBA(255, 215, 0, math.floor(alpha * 180)))
        nvgText(nvg, x + w * 0.5, y + h * 0.25, CONFIG.warning.text)

        nvgFontBlur(nvg, 0)
        nvgFillColor(nvg, nvgRGBA(255, 240, 100, math.floor(alpha * 255)))
        nvgText(nvg, x + w * 0.5, y + h * 0.25, CONFIG.warning.text)
        nvgRestore(nvg)
    end

    -- 渲染稀有鱼
    if not rareFish_ or rareFish_.hit then return end
    local rf = rareFish_

    local fx = x + rf.x * w
    local fy = y + rf.y * h
    local sz = rf.size

    -- 剩余时间比例
    local lifeRatio = rf.life / rf.maxLife

    -- 金色脉冲
    local glowCfg = CONFIG.glow
    local pulse = glowCfg.baseAlpha + (1.0 - glowCfg.baseAlpha)
        * math.abs(math.sin(time * glowCfg.pulseFreq))

    -- 1. 外层光晕 (大圆, 金色)
    local glowR = sz * 0.8 + glowCfg.glowRadius
    local glowPaint = nvgRadialGradient(nvg,
        fx, fy, sz * 0.3, glowR,
        nvgRGBA(255, 215, 0, math.floor(pulse * 100)),
        nvgRGBA(255, 215, 0, 0))
    nvgBeginPath(nvg)
    nvgCircle(nvg, fx, fy, glowR)
    nvgFillPaint(nvg, glowPaint)
    nvgFill(nvg)

    -- 2. 鱼影本体 (金色椭圆)
    nvgSave(nvg)
    nvgTranslate(nvg, fx, fy)

    -- 朝向翻转
    local scaleX = rf.dir
    nvgScale(nvg, scaleX, 1)

    -- 鱼体
    nvgBeginPath(nvg)
    nvgEllipse(nvg, 0, 0, sz * 0.5, sz * 0.28)
    nvgFillColor(nvg, nvgRGBA(255, 200, 30, math.floor(pulse * 220)))
    nvgFill(nvg)

    -- 尾巴
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, -sz * 0.4, 0)
    nvgLineTo(nvg, -sz * 0.7, -sz * 0.2)
    nvgLineTo(nvg, -sz * 0.7, sz * 0.2)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(255, 180, 0, math.floor(pulse * 200)))
    nvgFill(nvg)

    -- 眼睛
    nvgBeginPath(nvg)
    nvgCircle(nvg, sz * 0.25, -sz * 0.05, sz * 0.06)
    nvgFillColor(nvg, nvgRGBA(80, 40, 0, math.floor(pulse * 255)))
    nvgFill(nvg)

    -- 闪光星星 (高光点)
    local starAngle = time * 3.0
    local starR = sz * 0.12
    nvgBeginPath(nvg)
    nvgCircle(nvg, sz * 0.1 + math.cos(starAngle) * 3, -sz * 0.12, starR * pulse)
    nvgFillColor(nvg, nvgRGBA(255, 255, 220, math.floor(pulse * 200)))
    nvgFill(nvg)

    nvgRestore(nvg)

    -- 3. 倒计时进度条 (鱼下方)
    local barW = sz * 0.8
    local barH = 4
    local barX = fx - barW * 0.5
    local barY = fy + sz * 0.35
    local remaining = 1.0 - lifeRatio

    -- 背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, barX, barY, barW, barH, 2)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 120))
    nvgFill(nvg)

    -- 前景 (红→绿渐变)
    local barColor
    if remaining > 0.5 then
        barColor = nvgRGBA(80, 255, 80, 220)
    elseif remaining > 0.25 then
        barColor = nvgRGBA(255, 200, 50, 220)
    else
        barColor = nvgRGBA(255, 60, 60, 220)
    end
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, barX, barY, barW * remaining, barH, 2)
    nvgFillColor(nvg, barColor)
    nvgFill(nvg)
end

--- 手动触发 (调试用)
function RareFishSystem.forceSpawn()
    warningTimer_ = -1
    spawnRareFish()
end

return RareFishSystem
