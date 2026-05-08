-- ============================================================================
-- FishSwarmSystem: 鱼群刷新系统（直线波次版）
-- ============================================================================
-- 平时: 6~12 条常驻鱼影, 直线穿越屏幕
-- 波次: 每60秒刷一波, 80~100条鱼 (全部可捕获)
--       长条形队列, 直线穿越屏幕
-- ============================================================================

local GameConfig     = require("config.GameConfig")
local GameState      = require("state.GameState")
local ResearchSystem = require("systems.ResearchSystem")

local FishSwarmSystem = {}

-- ============================================================================
-- 配置
-- ============================================================================
-- 三档鱼影尺寸
local FISH_SIZES = {
    small  = { min = 30,  max = 40  },
    medium = { min = 55,  max = 70  },
    large  = { min = 85,  max = 105 },
}

local CONFIG = {
    ambient = {
        minCount = 6,
        maxCount = 12,
        vxBase   = 0.25,     -- 横穿屏幕约4秒
        vyBase   = 0.20,     -- 纵穿屏幕约5秒
        yMin     = 0.30,     -- 鱼活动区域上界
        yMax     = 0.95,     -- 鱼活动区域下界
    },
    wave = {
        interval       = 60,     -- 波次间隔 (秒)
        visualMin      = 80,     -- 波次鱼最少
        visualMax      = 100,    -- 波次鱼最多 (全部可捕获)
        crossTimeMin   = 15,     -- 穿越屏幕最短时间
        crossTimeMax   = 15,     -- 穿越屏幕最长时间
        formWidthMin   = 0.55,   -- 鱼群宽度 (屏幕比例)
        formWidthMax   = 0.55,
        formLengthMin  = 1.00,   -- 鱼群长度 (屏幕比例)
        formLengthMax  = 1.00,
    },
}

--- 随机选取一个尺寸档位 (根据当前鱼饵的 sizeWeights)
---@return number size 鱼影像素尺寸
---@return string sizeTier "small"|"medium"|"large"
local function pickAmbientSize()
    -- 读取当前鱼饵的尺寸权重
    local baitId = GameState.currentBait or "normal"
    local baitCfg = GameConfig.BAIT_BY_ID[baitId]
    local weights = baitCfg and baitCfg.sizeWeights
        or { small = 1.0, medium = 0, large = 0 }

    local roll = math.random()
    local tier, tierName
    local wSmall  = weights.small  or 0
    local wMedium = weights.medium or 0
    if roll < wSmall then
        tier = FISH_SIZES.small;  tierName = "small"
    elseif roll < wSmall + wMedium then
        tier = FISH_SIZES.medium; tierName = "medium"
    else
        tier = FISH_SIZES.large;  tierName = "large"
    end
    return tier.min + math.random() * (tier.max - tier.min), tierName
end

-- ============================================================================
-- 状态
-- ============================================================================
local ambientFish_   = {}
local waveFish_      = {}
local waveTimer_     = 0
local waveActive_    = false
local ambientTarget_ = 8

-- ============================================================================
-- 工具函数
-- ============================================================================
local function randRange(min, max)
    return min + math.random() * (max - min)
end

local function randInt(min, max)
    return math.random(min, max)
end

--- 三角分布 [-1, 1], 中心密集
local function triangularRand()
    return math.random() + math.random() - 1.0
end

--- 近似高斯 [-1, 1], 中心更密集
local function gaussRand()
    return ((math.random() + math.random() + math.random()) / 3 - 0.5) * 2
end

-- ============================================================================
-- 常驻鱼创建 (直线穿越: 屏幕外→屏幕外)
-- ============================================================================

--- 创建一条常驻鱼
---@param initialSpawn boolean true=初始化散布在屏幕内, false=从边缘进入
local function createAmbientFish(initialSpawn)
    local cfg = CONFIG.ambient
    local speedMult = randRange(0.8, 1.2)  -- ±20% 个体差异

    local startX, startY, exitX, exitY

    if initialSpawn then
        -- 初始化: 随机放在屏幕内, 朝随机出口运动
        startX = randRange(0.10, 0.90)
        startY = randRange(cfg.yMin, cfg.yMax)
        local exitSide = randInt(1, 4)
        if exitSide == 1 then
            exitX = -0.12;  exitY = randRange(0.05, 0.95)
        elseif exitSide == 2 then
            exitX = 1.12;   exitY = randRange(0.05, 0.95)
        elseif exitSide == 3 then
            exitX = randRange(0.10, 0.90); exitY = -0.12
        else
            exitX = randRange(0.10, 0.90); exitY = 1.12
        end
    else
        -- 后续补充: 从一侧边缘进入, 穿越到对侧/另一侧
        local side = randInt(1, 4)
        if side == 1 then      -- 左 → 右
            startX = -0.12;  startY = randRange(0.05, 0.95)
            exitX  =  1.12;  exitY  = randRange(0.05, 0.95)
        elseif side == 2 then  -- 右 → 左
            startX =  1.12;  startY = randRange(0.05, 0.95)
            exitX  = -0.12;  exitY  = randRange(0.05, 0.95)
        elseif side == 3 then  -- 上 → 下
            startX = randRange(0.10, 0.90); startY = -0.12
            exitX  = randRange(0.10, 0.90); exitY  = 1.12
        else                   -- 下 → 上
            startX = randRange(0.10, 0.90); startY = 1.12
            exitX  = randRange(0.10, 0.90); exitY  = -0.12
        end
    end

    -- 位移与穿越时间
    local dx = exitX - startX
    local dy = exitY - startY
    local absDx = math.abs(dx)
    local absDy = math.abs(dy)

    -- 以较长轴所需时间为基准, 保持 ~4s 水平 / ~5s 垂直
    local txNeed = (absDx > 0.01) and (absDx / cfg.vxBase) or 0
    local tyNeed = (absDy > 0.01) and (absDy / cfg.vyBase) or 0
    local crossTime = math.max(txNeed, tyNeed) / speedMult
    crossTime = math.max(crossTime, 1.0)  -- 最低 1 秒

    local vx = dx / crossTime
    local vy = dy / crossTime

    -- 朝向: 按水平速度分量决定翻转
    local fishDir
    if math.abs(vx) > 0.01 then
        fishDir = (vx > 0) and 1 or -1
    else
        fishDir = (math.random() > 0.5) and 1 or -1
    end

    local fishSize, sizeTier = pickAmbientSize()

    return {
        x       = startX,
        y       = startY,
        vx      = vx,
        vy      = vy,
        size    = fishSize,
        sizeTier = sizeTier,
        variant = randInt(1, 4),
        dir     = fishDir,
        phase   = math.random() * 6.28,
        isWave     = false,
        isCatchable = true,    -- 常驻鱼全部可捕获
        alpha   = 0.6,
    }
end

-- ============================================================================
-- 波次方向定义
-- ============================================================================
local WAVE_DIRS = {
    { vx =  1,     vy =  0     },   -- 左 → 右
    { vx = -1,     vy =  0     },   -- 右 → 左
    { vx =  0,     vy =  1     },   -- 上 → 下
    { vx =  0.707, vy =  0.707 },   -- 左上 → 右下
    { vx = -0.707, vy =  0.707 },   -- 右上 → 左下
}

-- ============================================================================
-- 生成波次
-- ============================================================================
local function spawnWave()
    local wcfg = CONFIG.wave

    -- 随机方向
    local dirInfo = WAVE_DIRS[randInt(1, #WAVE_DIRS)]
    local vx, vy = dirInfo.vx, dirInfo.vy
    local len = math.sqrt(vx * vx + vy * vy)
    vx, vy = vx / len, vy / len

    -- 垂直方向 (用于队形宽度展开)
    local perpX, perpY = -vy, vx

    -- 队形参数
    local formWidth  = randRange(wcfg.formWidthMin, wcfg.formWidthMax)
    local formLength = randRange(wcfg.formLengthMin, wcfg.formLengthMax)
    local crossTime  = randRange(wcfg.crossTimeMin, wcfg.crossTimeMax)

    -- 速度: 需穿过 (1 + formLength) 距离
    local speed = (1.0 + formLength) / crossTime

    -- 入口中心点 (在屏幕外)
    local centerX, centerY
    local margin = formLength * 0.5 + 0.15

    if math.abs(vx) > 0.5 and math.abs(vy) < 0.3 then
        -- 水平方向
        centerX = (vx > 0) and -margin or (1.0 + margin)
        centerY = randRange(0.35, 0.70)
    elseif math.abs(vy) > 0.5 and math.abs(vx) < 0.3 then
        -- 垂直方向
        centerX = randRange(0.25, 0.75)
        centerY = (vy > 0) and -margin or (1.0 + margin)
    else
        -- 对角线
        centerX = (vx > 0) and -margin or (1.0 + margin)
        centerY = (vy > 0) and -margin or (1.0 + margin)
    end

    -- 鱼数量 (全部可捕获)
    local total = randInt(wcfg.visualMin, wcfg.visualMax)

    waveFish_ = {}

    for i = 1, total do
        -- 队形内位置 (三角分布 + 高斯分布 → 中心密集)
        local along  = triangularRand() * formLength * 0.5
        local across = gaussRand() * formWidth * 0.5

        -- 轻微弯曲: 沿主轴正弦偏移
        local curve = math.sin(along / formLength * math.pi * 2) * formWidth * 0.12
        across = across + curve

        local spawnX = centerX + along * vx + across * perpX
        local spawnY = centerY + along * vy + across * perpY

        -- 个体速度差异 (±7%)
        local speedMult = randRange(0.93, 1.07)

        -- 视觉朝向
        local fishDir
        if math.abs(vx) > 0.1 then
            fishDir = (vx > 0) and 1 or -1
        else
            fishDir = (math.random() > 0.5) and 1 or -1
        end

        -- 波次鱼混合三档尺寸 (全部可捕获)
        local fishSize, sizeTier = pickAmbientSize()

        waveFish_[#waveFish_ + 1] = {
            x       = spawnX,
            y       = spawnY,
            vx      = vx * speed * speedMult,
            vy      = vy * speed * speedMult,
            size    = fishSize,
            sizeTier = sizeTier,
            variant = randInt(1, 4),
            dir     = fishDir,
            phase   = math.random() * 6.28,
            isWave     = true,
            isCatchable = true,
            alpha   = 0.7,
            -- 个体抖动 (渲染时叠加)
            jitterPhase = math.random() * 6.28,
            jitterAmp   = randRange(0.001, 0.004),
        }
    end

    waveActive_ = true
    print(string.format(
        "[FishSwarm] 波次生成: %d条鱼 (全部可捕获), 方向=(%.2f,%.2f), 穿越时间=%.1fs",
        total, vx, vy, crossTime))
end

-- ============================================================================
-- 公开 API
-- ============================================================================

--- 初始化鱼群系统
function FishSwarmSystem.init()
    local baseTarget = randInt(CONFIG.ambient.minCount, CONFIG.ambient.maxCount)
    ambientTarget_ = math.floor(baseTarget * ResearchSystem.getDensityBonus())
    ambientFish_ = {}
    for i = 1, ambientTarget_ do
        ambientFish_[i] = createAmbientFish(true)  -- 初始散布在屏幕内
    end

    waveFish_   = {}
    waveTimer_  = 50     -- 首波仅等10秒, 之后恢复60秒间隔
    waveActive_ = false

    print("[FishSwarm] 初始化: " .. ambientTarget_ .. " 条常驻鱼影")
end

--- 每帧更新
function FishSwarmSystem.update(dt)
    local cfg = CONFIG.ambient

    -- ================================================================
    -- 更新常驻鱼 (直线穿越, 无转向)
    -- ================================================================
    local i = 1
    while i <= #ambientFish_ do
        local f = ambientFish_[i]

        -- 直线移动
        f.x = f.x + f.vx * dt
        f.y = f.y + f.vy * dt
        f.phase = f.phase + dt

        -- 超出屏幕边界则移除 (基于实际屏幕边缘, 非活动区域)
        if f.x < -0.15 or f.x > 1.15
        or f.y < -0.15 or f.y > 1.15 then
            table.remove(ambientFish_, i)
        else
            i = i + 1
        end
    end

    -- 补充常驻鱼到目标数量 (从边缘进入)
    while #ambientFish_ < ambientTarget_ do
        ambientFish_[#ambientFish_ + 1] = createAmbientFish(false)
    end

    -- ================================================================
    -- 波次计时 (研发: 波次频率缩短间隔)
    -- ================================================================
    if not waveActive_ then
        waveTimer_ = waveTimer_ + dt
        local effectiveInterval = CONFIG.wave.interval * ResearchSystem.getWaveIntervalMultiplier()
        if waveTimer_ >= effectiveInterval then
            waveTimer_ = 0
            spawnWave()
        end
    end

    -- ================================================================
    -- 更新波次鱼
    -- ================================================================
    if waveActive_ then
        i = 1
        while i <= #waveFish_ do
            local f = waveFish_[i]
            f.x = f.x + f.vx * dt
            f.y = f.y + f.vy * dt
            f.phase = f.phase + dt

            -- 超出屏幕范围则移除 (留较大余量等队尾离开)
            if f.x < -6.0 or f.x > 7.0 or f.y < -6.0 or f.y > 7.0 then
                table.remove(waveFish_, i)
            else
                i = i + 1
            end
        end

        -- 所有鱼离开 → 波次结束
        if #waveFish_ == 0 then
            waveActive_ = false
            print("[FishSwarm] 波次结束")
        end
    end
end

--- 获取所有鱼 (常驻 + 波次)
---@return table[]
function FishSwarmSystem.getAllFish()
    local all = {}
    for _, f in ipairs(ambientFish_) do
        all[#all + 1] = f
    end
    for _, f in ipairs(waveFish_) do
        all[#all + 1] = f
    end
    return all
end

--- 获取可捕获鱼列表
---@return table[]
function FishSwarmSystem.getCatchableFish()
    local result = {}
    for _, f in ipairs(waveFish_) do
        if f.isCatchable then
            result[#result + 1] = f
        end
    end
    return result
end

--- 是否有波次正在进行
function FishSwarmSystem.isWaveActive()
    return waveActive_
end

--- 距离下一波次的秒数
function FishSwarmSystem.getNextWaveIn()
    if waveActive_ then return 0 end
    local effectiveInterval = CONFIG.wave.interval * ResearchSystem.getWaveIntervalMultiplier()
    return math.max(0, effectiveInterval - waveTimer_)
end

--- 当前总鱼数
function FishSwarmSystem.getFishCount()
    return #ambientFish_ + #waveFish_
end

--- 从鱼群中移除指定鱼 (捕获时调用)
---@param fish table 要移除的鱼对象引用
---@return boolean 是否成功移除
function FishSwarmSystem.removeFish(fish)
    for i, f in ipairs(ambientFish_) do
        if f == fish then
            table.remove(ambientFish_, i)
            return true
        end
    end
    for i, f in ipairs(waveFish_) do
        if f == fish then
            table.remove(waveFish_, i)
            return true
        end
    end
    return false
end

--- 手动触发波次 (快捷键用)
function FishSwarmSystem.forceWave()
    if waveActive_ then
        -- 强制结束当前波次，立即刷新
        waveFish_ = {}
        waveActive_ = false
        print("[FishSwarm] 强制结束当前波次，重新生成")
    end
    waveTimer_ = 0
    spawnWave()
    return true
end

return FishSwarmSystem
