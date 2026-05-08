-- ============================================================================
-- EconomyConfig: 数值系统集中配置
-- ============================================================================
-- 所有经济相关的调参数值集中在此文件，方便策划统一调整。
-- 各系统通过 EconomySystem 读取这些配置进行计算。
-- ============================================================================
local EconomyConfig = {}

-- ========== 鱼种稀有度乘数 (species rarity, 每种鱼的固有属性) ==========
EconomyConfig.FISH_RARITY_MULTI = {
    common    = 1.0,
    uncommon  = 1.35,
    rare      = 1.9,
    epic      = 2.8,
    legendary = 4.2,
}

-- ========== 品质价值乘数 (per-catch quality roll, 1~5) ==========
EconomyConfig.QUALITY_VALUE_MULTI = { 1.0, 1.4, 2.2, 4.0, 8.0 }

-- ========== 体型价值乘数 ==========
EconomyConfig.SIZE_VALUE_MULTI = {
    small = 0.7,
    medium = 1.0,
    large = 1.8,
    huge = 3.2,
}

-- ========== 区域基础价值 ==========
EconomyConfig.ZONE_BASE_VALUE = {
    nearshore = 10,
    offshore  = 45,
    deepocean = 180,
    abyss     = 720,
    legendary = 2880,
}

-- ========== 捕获硬币比例 (fishValue 的多少比例转为即时硬币) ==========
EconomyConfig.CATCH_COIN_RATIO = 0.15

-- ========== 区域解锁费用 ==========
EconomyConfig.ZONE_UNLOCK_COST = {
    nearshore = 0,
    offshore  = 500,
    deepocean = 2000,
    abyss     = 8000,
    legendary = 30000,
}

-- ========== 装备费用 ==========
EconomyConfig.EQUIPMENT = {
    rod  = { baseCost = 100, costScale = 1.35 },
    net  = { baseCost = 120, costScale = 1.35 },
    bait = { baseCost = 100, costScale = 1.30 },
    lamp = { baseCost = 150, costScale = 1.40 },
}

-- ========== 水族馆 Buff 基础值 ==========
EconomyConfig.AQUARIUM_BUFF_BASE = {
    producer    = { type = "sushiPrice",   base = 0.04 },
    accelerator = { type = "processSpeed", base = 0.04 },
    amplifier   = { type = "coinMultiplier", base = 0.04 },
    combo       = { type = "comboBonus",   base = 0.06 },
}

-- ========== 水族馆品质 Buff 乘数 ==========
EconomyConfig.AQUARIUM_QUALITY_BUFF_MULTI = { 1.0, 1.3, 1.8, 2.8, 4.5 }

-- ========== 水族馆收入参数 ==========
EconomyConfig.AQUARIUM_INCOME = {
    INTERVAL      = 30,      -- 每30秒结算
    BASE_PER_FISH = 3,       -- 每条鱼基础金币
    VALUE_RATIO   = 0.08,    -- fishValue 的比例加成
}

-- ========== 寿司定价 ==========
EconomyConfig.RECIPE_PRICE_PER_LEVEL = 0.15  -- 每级售价+15%

-- ========== Boss 击败奖励 ==========
EconomyConfig.BOSS_DEFEAT_COIN_BASE = 500

-- ========== 稀有鱼捕获奖励 ==========
EconomyConfig.RARE_FISH_COIN_BASE = 100

-- ========== 船只升级费用 ==========
EconomyConfig.BOAT_LEVELS = {
    { cost = 0,      equipCapLv = 5  },
    { cost = 800,    equipCapLv = 10 },
    { cost = 3000,   equipCapLv = 15 },
    { cost = 8000,   equipCapLv = 20 },
    { cost = 20000,  equipCapLv = 25 },
    { cost = 50000,  equipCapLv = 30 },
    { cost = 120000, equipCapLv = 40 },
    { cost = 300000, equipCapLv = 50 },
    { cost = 700000, equipCapLv = 60 },
    { cost = 1500000,equipCapLv = 99 },
}

return EconomyConfig
