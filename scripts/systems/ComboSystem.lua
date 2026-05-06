-- ============================================================================
-- ComboSystem: 连击反馈系统
-- ============================================================================
-- 连续切鱼时:
--   1. 连击计数 + 倍率文字弹出
--   2. 画面震动 (强度随连击递增)
--   3. 金币奖励倍率递增
-- ============================================================================

local ComboSystem = {}

-- ========== 配置 ==========
local CONFIG = {
    -- 连击时间窗口: 两次捕鱼间隔超过此值则断连
    timeWindow   = 2.5,
    -- 倍率阶梯 {连击数阈值, 倍率}
    multipliers  = {
        { 2,  1.2 },
        { 4,  1.5 },
        { 6,  2.0 },
        { 10, 3.0 },
        { 15, 5.0 },
    },
    -- 震屏
    shake = {
        baseMag     = 2.0,   -- 基础震幅 (像素)
        comboScale  = 0.8,   -- 每连击增加的震幅
        maxMag      = 12.0,  -- 最大震幅
        decay       = 8.0,   -- 衰减速度 (越大衰减越快)
        freq        = 35.0,  -- 震动频率
    },
    -- 弹字
    popup = {
        duration = 1.5,     -- 显示时长
        floatY   = 80,      -- 上浮距离
        fontSize = 36,      -- 基础字号
    },
}

-- ========== 状态 ==========
local comboCount_   = 0      -- 当前连击数
local comboTimer_   = 0      -- 距上次捕获的时间
local isActive_     = false  -- 连击是否激活中

-- 震屏状态
local shakeTime_    = 0      -- 当前震动计时
local shakeMag_     = 0      -- 当前震动幅度
local shakeOffsetX_ = 0      -- 当前帧偏移 x
local shakeOffsetY_ = 0      -- 当前帧偏移 y

-- 弹字列表
---@class ComboPopup
---@field time number
---@field x number
---@field y number
---@field combo number
---@field mult number
local popups_ = {}

-- ========== 内部函数 ==========

--- 根据连击数查表获取倍率
local function getMultiplierForCombo(count)
    local mult = 1.0
    for _, entry in ipairs(CONFIG.multipliers) do
        if count >= entry[1] then
            mult = entry[2]
        end
    end
    return mult
end

--- 触发震屏
local function triggerShake(combo)
    local cfg = CONFIG.shake
    shakeMag_ = math.min(cfg.baseMag + combo * cfg.comboScale, cfg.maxMag)
    shakeTime_ = 0
end

-- ========== 公开 API ==========

--- 每次捕获鱼时调用
---@param screenX number 捕获位置 x (逻辑坐标)
---@param screenY number 捕获位置 y (逻辑坐标)
function ComboSystem.onCatch(screenX, screenY)
    comboTimer_ = 0
    comboCount_ = comboCount_ + 1
    isActive_ = true

    if comboCount_ >= 2 then
        local mult = getMultiplierForCombo(comboCount_)
        -- 添加弹字
        popups_[#popups_ + 1] = {
            time  = 0,
            x     = screenX,
            y     = screenY,
            combo = comboCount_,
            mult  = mult,
        }
        -- 触发震屏
        triggerShake(comboCount_)

        print(string.format("[Combo] x%d 连击! 倍率 %.1fx", comboCount_, mult))
    end
end

--- 获取当前连击的金币倍率
---@return number
function ComboSystem.getMultiplier()
    if comboCount_ < 2 then return 1.0 end
    return getMultiplierForCombo(comboCount_)
end

--- 获取当前连击数
---@return number
function ComboSystem.getCount()
    return comboCount_
end

--- 获取当前帧的震屏偏移
---@return number offsetX, number offsetY
function ComboSystem.getShakeOffset()
    return shakeOffsetX_, shakeOffsetY_
end

--- 每帧更新
---@param dt number
function ComboSystem.update(dt)
    -- 连击计时
    if isActive_ then
        comboTimer_ = comboTimer_ + dt
        if comboTimer_ >= CONFIG.timeWindow then
            -- 连击断裂
            if comboCount_ >= 2 then
                print(string.format("[Combo] 连击断裂 (最高 x%d)", comboCount_))
            end
            comboCount_ = 0
            comboTimer_ = 0
            isActive_ = false
        end
    end

    -- 震屏衰减
    if shakeMag_ > 0.1 then
        shakeTime_ = shakeTime_ + dt
        local decay = math.exp(-CONFIG.shake.decay * shakeTime_)
        local mag = shakeMag_ * decay
        local freq = CONFIG.shake.freq
        shakeOffsetX_ = mag * math.sin(freq * shakeTime_)
        shakeOffsetY_ = mag * math.cos(freq * shakeTime_ * 1.3)
        if decay < 0.01 then
            shakeMag_ = 0
            shakeOffsetX_ = 0
            shakeOffsetY_ = 0
        end
    else
        shakeOffsetX_ = 0
        shakeOffsetY_ = 0
    end

    -- 弹字更新
    local i = 1
    while i <= #popups_ do
        popups_[i].time = popups_[i].time + dt
        if popups_[i].time >= CONFIG.popup.duration then
            table.remove(popups_, i)
        else
            i = i + 1
        end
    end
end

--- 渲染连击弹字 (在 coin popup 同层调用)
---@param nvg userdata NanoVG上下文
function ComboSystem.render(nvg)
    for _, p in ipairs(popups_) do
        local t = p.time / CONFIG.popup.duration  -- 0→1
        local cfg = CONFIG.popup

        -- 上浮
        local floatY = p.y - cfg.floatY * t

        -- 透明度: 前70%全显，后30%淡出
        local alpha
        if t < 0.7 then
            alpha = 1.0
        else
            alpha = 1.0 - (t - 0.7) / 0.3
        end

        -- 缩放: 弹出效果
        local scale
        if t < 0.1 then
            scale = 0.3 + t / 0.1 * 1.2   -- 0.3→1.5
        elseif t < 0.25 then
            scale = 1.5 - (t - 0.1) / 0.15 * 0.5  -- 1.5→1.0
        else
            scale = 1.0
        end

        -- 字号随连击增大
        local fontSize = cfg.fontSize + math.min(p.combo, 15) * 1.5

        -- 颜色: 连击越高越红
        local r, g, b
        if p.combo < 4 then
            r, g, b = 255, 230, 80    -- 金黄
        elseif p.combo < 8 then
            r, g, b = 255, 160, 40    -- 橙色
        elseif p.combo < 12 then
            r, g, b = 255, 80, 40     -- 红橙
        else
            r, g, b = 255, 50, 50     -- 大红
        end

        local text = string.format("x%d!", p.combo)
        local subText = string.format("%.1f倍", p.mult)

        nvgSave(nvg)
        nvgTranslate(nvg, p.x, floatY)
        nvgScale(nvg, scale, scale)
        nvgGlobalAlpha(nvg, alpha)

        -- 主连击文字
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, fontSize)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

        -- 描边
        nvgFontBlur(nvg, 4)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, math.floor(alpha * 200)))
        nvgText(nvg, 0, 0, text)

        -- 正文
        nvgFontBlur(nvg, 0)
        nvgFillColor(nvg, nvgRGBA(r, g, b, math.floor(alpha * 255)))
        nvgText(nvg, 0, 0, text)

        -- 倍率副文字 (在下方)
        nvgFontSize(nvg, 18)
        nvgFontBlur(nvg, 3)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, math.floor(alpha * 160)))
        nvgText(nvg, 0, fontSize * 0.55, subText)
        nvgFontBlur(nvg, 0)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, math.floor(alpha * 230)))
        nvgText(nvg, 0, fontSize * 0.55, subText)

        nvgRestore(nvg)
    end
end

return ComboSystem
