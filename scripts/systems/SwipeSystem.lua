-- ============================================================================
-- SwipeSystem: 滑动捕鱼系统
-- ============================================================================
-- 按住屏幕/鼠标左键滑动，碰触鱼影即可捕捞
-- 滑动时白色柔和轨迹跟随手指
-- ============================================================================

local FishSwarmSystem = require("systems.FishSwarmSystem")
local BossSystem      = require("systems.BossSystem")
local RareFishSystem  = require("systems.RareFishSystem")

local SwipeSystem = {}

-- ============================================================================
-- 配置
-- ============================================================================
local CONFIG = {
    TRAIL_MAX_POINTS       = 30,     -- 最大轨迹点数
    TRAIL_MAX_AGE          = 0.35,   -- 点存活时间 (秒)
    TRAIL_FADE_AFTER_RELEASE = 0.25, -- 松手后淡出时间 (秒)
    MIN_MOVE_DIST_SQ       = 9.0,    -- 最小移动距离² (3px, 防抖)
    CATCH_RADIUS_MULT      = 0.6,    -- 碰撞半径 = fish.size * 此值
}

-- ============================================================================
-- 内部状态
-- ============================================================================

---@class TrailPoint
---@field x number   逻辑屏幕坐标 x
---@field y number   逻辑屏幕坐标 y
---@field age number 存在时间 (秒)

local trail_ = {}               -- TrailPoint[]
local isSwiping_ = false        -- 当前是否按住
local caughtThisSwipe_ = {}     -- 本次滑动已捕获的鱼 (防重复)
local catchCallback_ = nil      -- 捕获回调

-- 缓存的屏幕尺寸 (逻辑坐标)
local screenW_ = 0
local screenH_ = 0

-- ============================================================================
-- 工具函数
-- ============================================================================

--- 线段-圆碰撞检测
---@param x1 number 线段起点 x
---@param y1 number 线段起点 y
---@param x2 number 线段终点 x
---@param y2 number 线段终点 y
---@param cx number 圆心 x
---@param cy number 圆心 y
---@param r  number 半径
---@return boolean
local function lineCircleIntersect(x1, y1, x2, y2, cx, cy, r)
    local dx = x2 - x1
    local dy = y2 - y1
    local fx = x1 - cx
    local fy = y1 - cy

    local a = dx * dx + dy * dy
    if a < 0.0001 then
        -- 退化为点
        return (fx * fx + fy * fy) <= r * r
    end

    local b = 2 * (fx * dx + fy * dy)
    local c = fx * fx + fy * fy - r * r
    local disc = b * b - 4 * a * c

    if disc < 0 then return false end

    disc = math.sqrt(disc)
    local t1 = (-b - disc) / (2 * a)
    local t2 = (-b + disc) / (2 * a)

    return (t1 >= 0 and t1 <= 1) or (t2 >= 0 and t2 <= 1)
        or (t1 < 0 and t2 > 1)  -- 线段完全在圆内
end

--- 添加轨迹点
local function addTrailPoint(x, y)
    trail_[#trail_ + 1] = { x = x, y = y, age = 0 }
    -- 限制最大点数
    while #trail_ > CONFIG.TRAIL_MAX_POINTS do
        table.remove(trail_, 1)
    end
end

--- 检测新线段与鱼的碰撞
local function checkFishCollision(x2, y2, x1, y1)
    local allFish = FishSwarmSystem.getAllFish()

    for _, fish in ipairs(allFish) do
        if fish.isCatchable and not caughtThisSwipe_[fish] then
            -- 鱼的归一化坐标 → 逻辑屏幕坐标
            local fx = fish.x * screenW_
            local fy = fish.y * screenH_
            local radius = fish.size * CONFIG.CATCH_RADIUS_MULT

            if lineCircleIntersect(x1, y1, x2, y2, fx, fy, radius) then
                caughtThisSwipe_[fish] = true
                if catchCallback_ then
                    catchCallback_(fish)
                end
            end
        end
    end

    -- 鱼王命中检测
    BossSystem.checkHit(x1, y1, x2, y2, screenW_, screenH_)

    -- 稀有鱼命中检测
    if RareFishSystem.checkHit(x1, y1, x2, y2, screenW_, screenH_) then
        local result = RareFishSystem.processCapture()
        if result and catchCallback_ then
            -- 通知 main.lua 处理稀有鱼捕获结果
            -- 使用特殊标记让 main.lua 区分
            catchCallback_({
                isRareFish   = true,
                rareResult   = result,
                x            = result.screenX / screenW_,
                y            = result.screenY / screenH_,
                size         = 70,
                sizeTier     = "large",
                variant      = 1,
                dir          = 1,
                phase        = 0,
            })
        end
    end
end

-- ============================================================================
-- 公开 API
-- ============================================================================

--- 初始化
function SwipeSystem.init()
    trail_ = {}
    isSwiping_ = false
    caughtThisSwipe_ = {}
    catchCallback_ = nil
    print("[SwipeSystem] init done")
end

--- 注册捕获回调
---@param callback fun(fish: table)
function SwipeSystem.setCatchCallback(callback)
    catchCallback_ = callback
end

--- 是否正在滑动
---@return boolean
function SwipeSystem.isSwiping()
    return isSwiping_
end

--- 每帧更新: 轮询输入、管理轨迹、碰撞检测
---@param dt number
---@param w number  逻辑屏幕宽
---@param h number  逻辑屏幕高
---@param dpr number 设备像素比
function SwipeSystem.update(dt, w, h, dpr)
    screenW_ = w
    screenH_ = h

    -- 1. 老化已有轨迹点
    for i = 1, #trail_ do
        trail_[i].age = trail_[i].age + dt
    end

    -- 2. 移除过期点
    while #trail_ > 0 and trail_[1].age > CONFIG.TRAIL_MAX_AGE do
        table.remove(trail_, 1)
    end

    -- 3. 轮询输入 (触摸优先)
    local pressing = false
    local rawX, rawY = 0, 0

    if input:GetNumTouches() > 0 then
        local touch = input:GetTouch(0)  -- 0-based 索引
        pressing = true
        rawX = touch.position.x
        rawY = touch.position.y
    elseif input:GetMouseButtonDown(MOUSEB_LEFT) then
        pressing = true
        local pos = input:GetMousePosition()
        rawX = pos.x
        rawY = pos.y
    end

    -- 4. 物理像素 → 逻辑坐标 (模式 B)
    local logX = rawX / dpr
    local logY = rawY / dpr

    -- 5. 状态转换
    if pressing and not isSwiping_ then
        -- 开始滑动
        isSwiping_ = true
        trail_ = {}
        caughtThisSwipe_ = {}
        addTrailPoint(logX, logY)
    elseif pressing and isSwiping_ then
        -- 继续滑动: 超过最小距离才加点 (防抖)
        local last = trail_[#trail_]
        if last then
            local dx = logX - last.x
            local dy = logY - last.y
            if dx * dx + dy * dy >= CONFIG.MIN_MOVE_DIST_SQ then
                addTrailPoint(logX, logY)
                checkFishCollision(logX, logY, last.x, last.y)
            end
        end
    elseif not pressing and isSwiping_ then
        -- 松手: 轨迹保留, 自然淡出
        isSwiping_ = false
    end
end

--- 渲染滑动轨迹 (在 WaterScene 中调用)
---@param nvg userdata NanoVG 上下文
---@param x number 视口 x
---@param y number 视口 y
---@param w number 视口宽
---@param h number 视口高
function SwipeSystem.render(nvg, x, y, w, h)
    if #trail_ < 2 then return end

    -- 构建路径的辅助函数
    local function buildPath()
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, trail_[1].x, trail_[1].y)
        for i = 2, #trail_ do
            nvgLineTo(nvg, trail_[i].x, trail_[i].y)
        end
    end

    -- 整体透明度: 松手后逐渐淡出
    local globalAlpha = 1.0
    if not isSwiping_ and #trail_ > 0 then
        local newestAge = trail_[#trail_].age
        globalAlpha = math.max(0, 1.0 - newestAge / CONFIG.TRAIL_FADE_AFTER_RELEASE)
    end
    if globalAlpha < 0.01 then return end

    nvgSave(nvg)
    nvgLineCap(nvg, NVG_ROUND)
    nvgLineJoin(nvg, NVG_ROUND)

    -- 5 层递减宽度 + 递增 alpha, 实现柔和发光边缘
    local layers = {
        { width = 20, r = 180, g = 210, b = 255, alpha = 10  },  -- 外层微蓝光晕
        { width = 14, r = 200, g = 225, b = 255, alpha = 20  },
        { width = 10, r = 220, g = 235, b = 255, alpha = 35  },
        { width = 7,  r = 240, g = 245, b = 255, alpha = 60  },
        { width = 4,  r = 255, g = 255, b = 255, alpha = 120 },  -- 核心亮白
    }

    for _, layer in ipairs(layers) do
        buildPath()
        local a = math.floor(layer.alpha * globalAlpha)
        nvgStrokeColor(nvg, nvgRGBA(layer.r, layer.g, layer.b, a))
        nvgStrokeWidth(nvg, layer.width)
        nvgStroke(nvg)
    end

    -- 最内层细亮芯线
    buildPath()
    nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, math.floor(200 * globalAlpha)))
    nvgStrokeWidth(nvg, 2.0)
    nvgStroke(nvg)

    nvgRestore(nvg)
end

return SwipeSystem
