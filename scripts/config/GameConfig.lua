-- ============================================================================
-- GameConfig: 全部游戏静态数据配置
-- ============================================================================
local GameConfig = {}

-- ========== 游戏常量 ==========
GameConfig.TITLE = "钓鱼大亨"
GameConfig.AUTO_SAVE_INTERVAL = 30  -- 自动存档间隔(秒)
GameConfig.FISH_HOLD_CAPACITY = 50  -- 初始鱼仓容量
GameConfig.INITIAL_COINS = 100     -- 初始金币

-- ========== 品质定义 ==========
GameConfig.QUALITY = {
    { id = 1, name = "white",  displayName = "普通", color = {200, 200, 200, 255}, multiplier = 1.0,  icon = "" },
    { id = 2, name = "green",  displayName = "优良", color = {100, 200, 80, 255},  multiplier = 1.5,  icon = "" },
    { id = 3, name = "blue",   displayName = "稀有", color = {80, 150, 255, 255},  multiplier = 2.5,  icon = "" },
    { id = 4, name = "purple", displayName = "史诗", color = {180, 80, 255, 255},  multiplier = 5.0,  icon = "" },
    { id = 5, name = "gold",   displayName = "传说", color = {255, 215, 0, 255},   multiplier = 10.0, icon = "" },
}

-- 品质权重 (白/绿/蓝/紫/金)
GameConfig.DEFAULT_QUALITY_WEIGHTS = { 60, 25, 10, 4, 1 }

-- ========== 鱼类型定义 ==========
GameConfig.FISH_TYPE = {
    PRODUCER    = "producer",    -- 产出型: 提升寿司售价
    ACCELERATOR = "accelerator", -- 加速型: 提升生产速度
    AMPLIFIER   = "amplifier",   -- 增幅型: 提升收益倍率
    COMBO       = "combo",       -- 组合型: 触发特殊效果
}

-- ========== 海域定义 ==========
GameConfig.ZONE = {
    NEARSHORE = "nearshore", -- 近海
    OFFSHORE  = "offshore",  -- 外海
}

GameConfig.ZONE_DISPLAY = {
    nearshore = "近海",
    offshore  = "外海",
}

-- ========== 10种鱼配置 (MVP: 6近海+4外海) ==========
GameConfig.FISH = {
    -- 近海 6种
    {
        id = 1, name = "sardine", displayName = "小沙丁鱼", icon = "🐟",
        zone = "nearshore", fishType = "producer",
        baseValue = 10, catchWeight = 30,
        qualityWeights = { 60, 25, 10, 4, 1 },
        desc = "最常见的近海鱼，新手的好伙伴",
    },
    {
        id = 2, name = "clownfish", displayName = "小丑鱼", icon = "🐠",
        zone = "nearshore", fishType = "producer",
        baseValue = 18, catchWeight = 25,
        qualityWeights = { 55, 28, 12, 4, 1 },
        desc = "色彩鲜艳的热带鱼",
    },
    {
        id = 3, name = "bubblefish", displayName = "泡泡鱼", icon = "🫧",
        zone = "nearshore", fishType = "accelerator",
        baseValue = 15, catchWeight = 22,
        qualityWeights = { 58, 26, 11, 4, 1 },
        desc = "会吐泡泡的可爱小鱼",
    },
    {
        id = 4, name = "coralfish", displayName = "珊瑚鱼", icon = "🪸",
        zone = "nearshore", fishType = "amplifier",
        baseValue = 22, catchWeight = 18,
        qualityWeights = { 55, 27, 12, 5, 1 },
        desc = "珊瑚丛中的增幅鱼",
    },
    {
        id = 5, name = "shellfish", displayName = "贝壳鱼", icon = "🐚",
        zone = "nearshore", fishType = "combo",
        baseValue = 25, catchWeight = 15,
        qualityWeights = { 52, 28, 13, 5, 2 },
        desc = "带着贝壳的奇特组合鱼",
    },
    {
        id = 6, name = "bluefin", displayName = "蓝鳍鱼", icon = "🐟",
        zone = "nearshore", fishType = "producer",
        baseValue = 35, catchWeight = 10,
        qualityWeights = { 50, 28, 14, 6, 2 },
        desc = "近海最有价值的鱼",
    },
    -- 外海 4种
    {
        id = 7, name = "flyingfish", displayName = "飞鱼", icon = "🦅",
        zone = "offshore", fishType = "accelerator",
        baseValue = 60, catchWeight = 28,
        qualityWeights = { 50, 28, 14, 6, 2 },
        desc = "能飞出水面的加速型鱼",
    },
    {
        id = 8, name = "silverfish", displayName = "银枪鱼", icon = "🗡️",
        zone = "offshore", fishType = "producer",
        baseValue = 90, catchWeight = 25,
        qualityWeights = { 48, 28, 15, 7, 2 },
        desc = "外海主力产出鱼",
    },
    {
        id = 9, name = "gemfish", displayName = "宝石鱼", icon = "💎",
        zone = "offshore", fishType = "amplifier",
        baseValue = 130, catchWeight = 18,
        qualityWeights = { 45, 28, 16, 8, 3 },
        desc = "闪闪发光的增幅鱼",
    },
    {
        id = 10, name = "octopus", displayName = "章鱼", icon = "🐙",
        zone = "offshore", fishType = "combo",
        baseValue = 180, catchWeight = 12,
        qualityWeights = { 42, 28, 17, 9, 4 },
        desc = "高级组合型鱼",
    },
}

-- 快速查找表
GameConfig.FISH_BY_ID = {}
GameConfig.FISH_BY_ZONE = { nearshore = {}, offshore = {} }
for _, fish in ipairs(GameConfig.FISH) do
    GameConfig.FISH_BY_ID[fish.id] = fish
    table.insert(GameConfig.FISH_BY_ZONE[fish.zone], fish)
end

-- ========== 5个寿司配方 ==========
GameConfig.SUSHI = {
    {
        id = 1, name = "sardine_sushi", displayName = "沙丁鱼寿司", icon = "🍣",
        zone = "nearshore",
        ingredients = { {fishId = 1, count = 3} },  -- 小沙丁鱼x3
        processTime = 5, basePrice = 60,
        desc = "最基础的寿司",
    },
    {
        id = 2, name = "clown_roll", displayName = "小丑鱼卷", icon = "🍥",
        zone = "nearshore",
        ingredients = { {fishId = 2, count = 2}, {fishId = 3, count = 1} },  -- 小丑鱼x2+泡泡鱼x1
        processTime = 8, basePrice = 120,
        desc = "色彩缤纷的鱼卷",
    },
    {
        id = 3, name = "coral_nigiri", displayName = "珊瑚鱼握寿司", icon = "🍣",
        zone = "nearshore",
        ingredients = { {fishId = 4, count = 2}, {fishId = 1, count = 2} },  -- 珊瑚鱼x2+小沙丁鱼x2
        processTime = 12, basePrice = 180,
        desc = "精致的握寿司",
    },
    {
        id = 4, name = "flying_sushi", displayName = "飞鱼寿司", icon = "🍱",
        zone = "offshore",
        ingredients = { {fishId = 7, count = 2}, {fishId = 8, count = 1} },  -- 飞鱼x2+银枪鱼x1
        processTime = 30, basePrice = 700,
        desc = "外海特色寿司",
    },
    {
        id = 5, name = "gem_roll", displayName = "宝石鱼卷", icon = "🍱",
        zone = "offshore",
        ingredients = { {fishId = 9, count = 1}, {fishId = 8, count = 2} },  -- 宝石鱼x1+银枪鱼x2
        processTime = 45, basePrice = 1200,
        desc = "闪耀的高级鱼卷",
    },
}

GameConfig.SUSHI_BY_ID = {}
for _, sushi in ipairs(GameConfig.SUSHI) do
    GameConfig.SUSHI_BY_ID[sushi.id] = sushi
end

-- ========== 3种饵料 ==========
GameConfig.BAIT = {
    {
        id = 1, name = "basic", displayName = "基础鱼饵", icon = "🪱",
        cost = 0,  -- 免费
        modifiers = {},  -- 无加成
        desc = "通用饵料，无特殊效果",
    },
    {
        id = 2, name = "shrimp", displayName = "虾肉饵", icon = "🦐",
        cost = 50,
        modifiers = { producer = 1.5 },  -- 产出型鱼概率x1.5
        desc = "吸引产出型鱼",
    },
    {
        id = 3, name = "seaweed", displayName = "海藻饵", icon = "🌿",
        cost = 80,
        modifiers = { amplifier = 1.5, qualityBoost = 0.1 },  -- 增幅型x1.5, 品质提升10%
        desc = "吸引增幅型鱼，提升品质概率",
    },
}

GameConfig.BAIT_BY_ID = {}
for _, bait in ipairs(GameConfig.BAIT) do
    GameConfig.BAIT_BY_ID[bait.id] = bait
end

-- ========== 4种船员类型 ==========
GameConfig.CREW = {
    {
        id = 1, type = "fisher", displayName = "钓鱼手", icon = "🎣",
        desc = "提升自动捕鱼速度",
        baseBonus = 0.15,       -- 基础: 捕鱼速度+15%
        bonusPerLevel = 0.03,   -- 每级+3%
        upgradeCostBase = 200,
        upgradeCostScale = 1.5,
    },
    {
        id = 2, type = "netter", displayName = "捞网手", icon = "🥅",
        desc = "有概率额外捕获一条鱼",
        baseBonus = 0.10,       -- 基础: 10%双倍捕获概率
        bonusPerLevel = 0.02,
        upgradeCostBase = 300,
        upgradeCostScale = 1.5,
    },
    {
        id = 3, type = "harvester", displayName = "收获手", icon = "📦",
        desc = "提升鱼仓容量",
        baseBonus = 10,         -- 基础: 容量+10
        bonusPerLevel = 5,
        upgradeCostBase = 250,
        upgradeCostScale = 1.5,
    },
    {
        id = 4, type = "baiter", displayName = "饵料手", icon = "🧪",
        desc = "有概率不消耗饵料",
        baseBonus = 0.10,       -- 基础: 10%不消耗饵料
        bonusPerLevel = 0.02,
        upgradeCostBase = 350,
        upgradeCostScale = 1.5,
    },
}

GameConfig.CREW_BY_ID = {}
GameConfig.CREW_BY_TYPE = {}
for _, crew in ipairs(GameConfig.CREW) do
    GameConfig.CREW_BY_ID[crew.id] = crew
    GameConfig.CREW_BY_TYPE[crew.type] = crew
end

-- ========== 养殖系统 ==========
GameConfig.BREEDING = {
    MAX_SLOTS = 4,           -- 最大养殖槽
    INITIAL_SLOTS = 2,       -- 初始槽位
    BASE_PRODUCE_TIME = 60,  -- 基础产出时间(秒)
    QUALITY_TIME_MULTI = { 1.0, 1.3, 1.8, 2.5, 4.0 },  -- 品质越高产出越慢
    SLOT_UNLOCK_COST = { 0, 0, 2000, 5000 },  -- 第3/4槽解锁费用
}

-- ========== 鱼缸系统 ==========
GameConfig.AQUARIUM = {
    MAX_SLOTS = 8,
    INITIAL_SLOTS = 5,
    SLOT_UNLOCK_COST = { 0, 0, 0, 0, 0, 3000, 6000, 10000 },
    -- Buff基础值(每条鱼)
    BUFF_PER_TYPE = {
        producer    = { type = "sushiPrice",     base = 0.05 },  -- 寿司售价+5%
        accelerator = { type = "processSpeed",   base = 0.05 },  -- 生产速度+5%
        amplifier   = { type = "coinMultiplier", base = 0.05 },  -- 金币倍率+5%
        combo       = { type = "comboBonus",     base = 0.08 },  -- 组合加成+8%
    },
    -- 品质对Buff的倍率
    QUALITY_BUFF_MULTI = { 1.0, 1.3, 1.8, 3.0, 5.0 },
}

-- ========== 产业系统 ==========
GameConfig.INDUSTRY = {
    MAX_SLOTS = 3,       -- 最多同时加工3个寿司
    INITIAL_SLOTS = 1,   -- 初始1个加工位
    SLOT_UNLOCK_COST = { 0, 1000, 5000 },
    UPGRADE_PRICE_BONUS = 0.15,  -- 每级售价+15%
}

-- ========== 捕鱼系统 ==========
GameConfig.FISHING = {
    CAST_TIME = 0.5,         -- 抛竿动画时间
    MIN_WAIT_TIME = 1.5,     -- 最短等待时间
    MAX_WAIT_TIME = 4.0,     -- 最长等待时间
    REEL_TIME = 0.8,         -- 收杆时间
    CATCH_DISPLAY_TIME = 1.5, -- 展示钓到的鱼时间
    AUTO_FISH_INTERVAL = 3.0, -- 自动捕鱼间隔(秒)
}

return GameConfig
