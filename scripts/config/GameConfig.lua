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
    NEARSHORE  = "nearshore",  -- 近海
    OFFSHORE   = "offshore",   -- 外海
    DEEPOCEAN  = "deepocean",  -- 深海
    ABYSS      = "abyss",      -- 深渊
    LEGENDARY  = "legendary",  -- 传说之海
}

GameConfig.ZONE_DISPLAY = {
    nearshore = "近海",
    offshore  = "外海",
    deepocean = "深海",
    abyss     = "深渊",
    legendary = "传说之海",
}

-- ========== 10种鱼配置 (MVP: 6近海+4外海) ==========
GameConfig.FISH = {
    -- 近海 6种
    {
        id = 1, name = "sardine", displayName = "小沙丁鱼", icon = "🐟",
        zone = "nearshore", fishType = "producer", rarity = "common",
        baseValue = 10, catchWeight = 30,
        qualityWeights = { 60, 25, 10, 4, 1 },
        desc = "最常见的近海鱼，新手的好伙伴",
    },
    {
        id = 2, name = "clownfish", displayName = "小丑鱼", icon = "🐠",
        zone = "nearshore", fishType = "producer", rarity = "common",
        baseValue = 18, catchWeight = 25,
        qualityWeights = { 55, 28, 12, 4, 1 },
        desc = "色彩鲜艳的热带鱼",
    },
    {
        id = 3, name = "bubblefish", displayName = "泡泡鱼", icon = "🫧",
        zone = "nearshore", fishType = "accelerator", rarity = "common",
        baseValue = 15, catchWeight = 22,
        qualityWeights = { 58, 26, 11, 4, 1 },
        desc = "会吐泡泡的可爱小鱼",
    },
    {
        id = 4, name = "coralfish", displayName = "珊瑚鱼", icon = "🪸",
        zone = "nearshore", fishType = "amplifier", rarity = "uncommon",
        baseValue = 22, catchWeight = 18,
        qualityWeights = { 55, 27, 12, 5, 1 },
        desc = "珊瑚丛中的增幅鱼",
    },
    {
        id = 5, name = "shellfish", displayName = "贝壳鱼", icon = "🐚",
        zone = "nearshore", fishType = "combo", rarity = "uncommon",
        baseValue = 25, catchWeight = 15,
        qualityWeights = { 52, 28, 13, 5, 2 },
        desc = "带着贝壳的奇特组合鱼",
    },
    {
        id = 6, name = "bluefin", displayName = "蓝鳍鱼", icon = "🐟",
        zone = "nearshore", fishType = "producer", rarity = "rare",
        baseValue = 35, catchWeight = 10,
        qualityWeights = { 50, 28, 14, 6, 2 },
        desc = "近海最有价值的鱼",
    },
    -- 外海 4种
    {
        id = 7, name = "flyingfish", displayName = "飞鱼", icon = "🦅",
        zone = "offshore", fishType = "accelerator", rarity = "uncommon",
        baseValue = 60, catchWeight = 28,
        qualityWeights = { 50, 28, 14, 6, 2 },
        desc = "能飞出水面的加速型鱼",
    },
    {
        id = 8, name = "silverfish", displayName = "银枪鱼", icon = "🗡️",
        zone = "offshore", fishType = "producer", rarity = "rare",
        baseValue = 90, catchWeight = 25,
        qualityWeights = { 48, 28, 15, 7, 2 },
        desc = "外海主力产出鱼",
    },
    {
        id = 9, name = "gemfish", displayName = "宝石鱼", icon = "💎",
        zone = "offshore", fishType = "amplifier", rarity = "epic",
        baseValue = 130, catchWeight = 18,
        qualityWeights = { 45, 28, 16, 8, 3 },
        desc = "闪闪发光的增幅鱼",
    },
    {
        id = 10, name = "octopus", displayName = "章鱼", icon = "🐙",
        zone = "offshore", fishType = "combo", rarity = "epic",
        baseValue = 180, catchWeight = 12,
        qualityWeights = { 42, 28, 17, 9, 4 },
        desc = "高级组合型鱼",
    },
}

-- 快速查找表
GameConfig.FISH_BY_ID = {}
GameConfig.FISH_BY_ZONE = { nearshore = {}, offshore = {}, deepocean = {}, abyss = {}, legendary = {} }
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

-- ========== 菜谱等级系统 ==========
GameConfig.RECIPE_MAX_LEVEL = 10
--- 每级售价加成 (level 1 = +0%, level 2 = +15%, level 3 = +30%, ...)
GameConfig.RECIPE_PRICE_PER_LEVEL = 0.15
--- 升级费用 = baseCost * level^1.4
GameConfig.RECIPE_UPGRADE_BASE_COST = { 100, 150, 200, 500, 800 }  -- 按 recipeId 索引

--- 获取菜谱升级金币费用
function GameConfig.getRecipeUpgradeCost(recipeId, currentLevel)
    local base = GameConfig.RECIPE_UPGRADE_BASE_COST[recipeId] or 200
    return math.floor(base * currentLevel ^ 1.4)
end

--- 获取菜谱升级所需鱼材料 (与制作配方同类鱼, 数量随等级递增)
--- @return table[] {{fishId, count, displayName, icon}, ...}
function GameConfig.getRecipeUpgradeFish(recipeId, currentLevel)
    local recipe = GameConfig.SUSHI_BY_ID[recipeId]
    if not recipe then return {} end
    local result = {}
    for _, ing in ipairs(recipe.ingredients) do
        local fish = GameConfig.FISH_BY_ID[ing.fishId]
        table.insert(result, {
            fishId = ing.fishId,
            count  = ing.count * (currentLevel + 1),
            displayName = fish and fish.displayName or "???",
            icon   = fish and fish.icon or "🐟",
        })
    end
    return result
end

--- 获取菜谱等级售价倍率
function GameConfig.getRecipePriceMultiplier(level)
    return 1 + (level - 1) * GameConfig.RECIPE_PRICE_PER_LEVEL
end

-- ========== 4种船员类型 ==========
GameConfig.CREW = {
    {
        id = 1, type = "fisher", displayName = "钓鱼手", icon = "🎣",
        portrait = "image/crew_fisher_20260427080355.png",
        desc = "提升自动捕鱼速度",
        baseBonus = 0.15,       -- 基础: 捕鱼速度+15%
        bonusPerLevel = 0.03,   -- 每级+3%
        upgradeCostBase = 200,
        upgradeCostScale = 1.5,
    },
    {
        id = 2, type = "netter", displayName = "捞网手", icon = "🥅",
        portrait = "image/crew_netter_20260427080343.png",
        desc = "有概率额外捕获一条鱼",
        baseBonus = 0.10,       -- 基础: 10%双倍捕获概率
        bonusPerLevel = 0.02,
        upgradeCostBase = 300,
        upgradeCostScale = 1.5,
    },
    {
        id = 3, type = "harvester", displayName = "收获手", icon = "📦",
        portrait = "image/crew_harvester_20260427080344.png",
        desc = "提升鱼仓容量",
        baseBonus = 10,         -- 基础: 容量+10
        bonusPerLevel = 5,
        upgradeCostBase = 250,
        upgradeCostScale = 1.5,
    },
    {
        id = 4, type = "baiter", displayName = "饵料手", icon = "🧪",
        portrait = "image/crew_baiter_20260427080359.png",
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
    MAX_SLOTS = 16,          -- 最大养殖槽
    INITIAL_SLOTS = 4,       -- 初始槽位
    BASE_PRODUCE_TIME = 180, -- 基础产出时间(秒)
    QUALITY_TIME_MULTI = { 1.0, 1.3, 1.8, 2.5, 4.0 },  -- 品质越高产出越慢
    SLOT_UNLOCK_COST = {     -- 每个槽解锁费用 (前4个免费)
        0, 0, 0, 0,
        1000, 1500, 2000, 3000,
        4000, 5000, 7000, 10000,
        15000, 20000, 30000, 50000,
    },
}

-- 鱼图片映射 (fishName → 图片路径)
GameConfig.FISH_IMAGE = {
    sardine    = "image/fish_sardine_20260426161404.png",
    clownfish  = "image/fish_clownfish_20260426154607.png",
    bubblefish = "image/fish_bubblefish_20260426161340.png",
    coralfish  = "image/fish_coralfish_20260426154605.png",
    shellfish  = "image/fish_shellfish_20260426154603.png",
    bluefin    = "image/fish_bluefin_20260426155456.png",
    flyingfish = "image/fish_flyingfish_20260426155458.png",
    silverfish = "image/fish_silverfish_20260426155454.png",
    gemfish    = "image/fish_gemfish_20260426155453.png",
    octopus    = "image/fish_octopus_20260426155724.png",
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
    -- 金币收入配置
    INCOME = {
        INTERVAL = 30,        -- 每30秒结算一次
        BASE_PER_FISH = 5,    -- 每条鱼基础金币
        VALUE_RATIO = 0.1,    -- baseValue 的比例加成
    },
}

-- ========== 船只升级 ==========
-- 渔船等级：决定所有装备的等级上限
GameConfig.BOAT = {
    MAX_LEVEL = 10,
    -- 每级属性: { cost, equipCapLv = 装备等级上限, desc }
    LEVELS = {
        { cost = 0,     equipCapLv = 5,  desc = "破旧小渔船" },
        { cost = 500,   equipCapLv = 10, desc = "修缮渔船" },
        { cost = 1500,  equipCapLv = 15, desc = "结实木船" },
        { cost = 4000,  equipCapLv = 20, desc = "快速帆船" },
        { cost = 10000, equipCapLv = 25, desc = "远洋渔船" },
        { cost = 25000, equipCapLv = 30, desc = "钢壳渔轮" },
        { cost = 60000, equipCapLv = 40, desc = "现代渔船" },
        { cost = 150000,equipCapLv = 50, desc = "高速拖网船" },
        { cost = 350000,equipCapLv = 60, desc = "旗舰捕鱼船" },
        { cost = 800000,equipCapLv = 99, desc = "传奇海王号" },
    },
}

-- ========== 鱼王伤害 (按船科技等级) ==========
-- 索引 = boatLevel (1~10), [0] 为保底默认值
GameConfig.FISH_KING_DAMAGE = {
    [0]  = 10,
    [1]  = 10,
    [2]  = 15,
    [3]  = 17,
    [4]  = 19,
    [5]  = 22,
    [6]  = 25,
    [7]  = 30,
    [8]  = 34,
    [9]  = 39,
    [10] = 45,
}

--- 获取当前船等级对鱼王的伤害
function GameConfig.getFishKingDamage(boatLevel)
    return GameConfig.FISH_KING_DAMAGE[boatLevel] or GameConfig.FISH_KING_DAMAGE[0]
end

-- ========== 鱼王连击倍率 ==========
GameConfig.FISH_KING_COMBO = {
    { minCombo = 0,  multiplier = 1.00 },
    { minCombo = 5,  multiplier = 1.15 },
    { minCombo = 10, multiplier = 1.35 },
    { minCombo = 15, multiplier = 1.60 },
    { minCombo = 20, multiplier = 1.90 },
}

--- 根据连击数获取鱼王伤害倍率
function GameConfig.getFishKingComboMult(comboCount)
    local mult = 1.0
    for _, entry in ipairs(GameConfig.FISH_KING_COMBO) do
        if comboCount >= entry.minCombo then
            mult = entry.multiplier
        end
    end
    return mult
end

-- ========== 装备升级 ==========
-- 4种装备: 鱼竿/渔网/鱼饵/鱼灯, 等级上限由渔船等级决定
GameConfig.EQUIP = {
    -- 装备列表 (顺序即UI显示顺序)
    LIST = {
        {
            id = "rod",
            displayName = "鱼竿",
            desc = "自动钓鱼速度",
            icon = "image/fishing_rod_20260428044026.png",
            -- 升级费用 = baseCost * level^costScale
            baseCost = 100,
            costScale = 1.35,
            -- 每级效果: fishSpeed = 1.0 + level * bonusPerLv
            bonusPerLv = 0.08,
            bonusDesc = function(lv) return string.format("×%.1f", 1.0 + lv * 0.08) end,
        },
        {
            id = "net",
            displayName = "渔网",
            desc = "捕获价值",
            icon = "image/equip_net_20260428114735.png",
            baseCost = 120,
            costScale = 1.35,
            bonusPerLv = 0.06,
            bonusDesc = function(lv) return string.format("+%d%%", lv * 6) end,
        },
        {
            id = "bait",
            displayName = "鱼饵",
            desc = "鱼最大数量",
            icon = "image/bucket_cartoon_20260426152025.png",
            baseCost = 100,
            costScale = 1.30,
            bonusPerLv = 3,
            bonusDesc = function(lv) return string.format("+%d", lv * 3) end,
        },
        {
            id = "lamp",
            displayName = "鱼灯",
            desc = "定向捕鱼",
            icon = "image/equip_lamp_20260428114727.png",
            baseCost = 150,
            costScale = 1.40,
            bonusPerLv = 0.03,
            bonusDesc = function(lv) return string.format("+%d%%", lv * 3) end,
        },
    },
}

--- 获取装备等级上限 (由渔船等级决定)
function GameConfig.getEquipLevelCap(boatLevel)
    local info = GameConfig.BOAT.LEVELS[boatLevel]
    return info and info.equipCapLv or 5
end

-- 快速查找表
GameConfig.EQUIP_BY_ID = {}
for _, eq in ipairs(GameConfig.EQUIP.LIST) do
    GameConfig.EQUIP_BY_ID[eq.id] = eq
end

-- ========== 鱼饵配置 ==========
-- 鱼饵决定鱼影的尺寸分布: small=仅金币, medium/large=入背包
GameConfig.BAIT = {
    {
        id = "normal", displayName = "普通鱼饵", icon = "🪱",
        desc = "只能吸引小鱼",
        sizeWeights = { small = 1.0, medium = 0, large = 0 },
        unlockBaitLevel = 1,  -- bait 装备等级 >= 1 即可用(初始)
    },
    {
        id = "sweet", displayName = "香甜鱼饵", icon = "🍬",
        desc = "有几率吸引中型鱼",
        sizeWeights = { small = 0.85, medium = 0.15, large = 0 },
        unlockBaitLevel = 3,  -- bait 装备等级 >= 3
    },
    {
        id = "shiny", displayName = "闪光鱼饵", icon = "✨",
        desc = "能吸引中型甚至大型鱼",
        sizeWeights = { small = 0.75, medium = 0.20, large = 0.05 },
        unlockBaitLevel = 5,  -- bait 装备等级 >= 5
    },
}

-- 快速查找
GameConfig.BAIT_BY_ID = {}
for _, bait in ipairs(GameConfig.BAIT) do
    GameConfig.BAIT_BY_ID[bait.id] = bait
end

--- 判断鱼饵是否已解锁
--- @param baitId string
--- @return boolean
function GameConfig.isBaitUnlocked(baitId)
    local bait = GameConfig.BAIT_BY_ID[baitId]
    if not bait then return false end
    local GameState = require("state.GameState")
    return (GameState.equipLevels.bait or 1) >= bait.unlockBaitLevel
end

-- ========== 研发系统 ==========
GameConfig.RESEARCH_CATEGORIES = {
    { id = "fishing",  displayName = "捕鱼", icon = "🎣" },
    { id = "industry", displayName = "产业", icon = "🍣" },
    { id = "aquarium", displayName = "鱼缸", icon = "🐠" },
    { id = "breeding", displayName = "养殖", icon = "🐣" },
}

GameConfig.RESEARCH = {
    -- ====== 捕鱼 (3项) ======
    {
        key = "fish_density", category = "fishing",
        displayName = "鱼群密度", icon = "🐟",
        desc = "提升常驻鱼影数量",
        maxLevel = 8, effectType = "multiply",
        baseEffect = 1.0, effectPerLevel = 0.15,  -- Lv1=×1.15, Lv8=×2.20
        baseCost = 200, costScale = 1.6,
    },
    {
        key = "wave_interval", category = "fishing",
        displayName = "波次频率", icon = "🌊",
        desc = "缩短鱼群波次间隔",
        maxLevel = 6, effectType = "multiply",
        baseEffect = 1.0, effectPerLevel = -0.08,  -- 减少, Lv6=×0.52
        baseCost = 300, costScale = 1.7,
        floorPercent = 0.50,  -- 最低50%
    },
    {
        key = "hold_capacity", category = "fishing",
        displayName = "鱼仓扩容", icon = "📦",
        desc = "增加鱼仓最大容量",
        maxLevel = 8, effectType = "add",
        baseEffect = 0, effectPerLevel = 10,  -- 每级+10容量
        baseCost = 150, costScale = 1.5,
    },
    -- ====== 产业 (3项) ======
    {
        key = "sushi_price", category = "industry",
        displayName = "寿司溢价", icon = "💰",
        desc = "提升寿司售价",
        maxLevel = 8, effectType = "multiply",
        baseEffect = 1.0, effectPerLevel = 0.10,  -- Lv8=×1.80
        baseCost = 250, costScale = 1.6,
    },
    {
        key = "synthesis_speed", category = "industry",
        displayName = "合成加速", icon = "⚡",
        desc = "加快寿司合成速度",
        maxLevel = 6, effectType = "multiply",
        baseEffect = 1.0, effectPerLevel = 0.15,  -- Lv6=×1.90
        baseCost = 300, costScale = 1.7,
    },
    {
        key = "npc_frequency", category = "industry",
        displayName = "客流量", icon = "🐱",
        desc = "缩短NPC到来间隔",
        maxLevel = 6, effectType = "multiply",
        baseEffect = 1.0, effectPerLevel = -0.08,
        baseCost = 350, costScale = 1.7,
        floorPercent = 0.50,
    },
    -- ====== 鱼缸 (2项) ======
    {
        key = "aquarium_income", category = "aquarium",
        displayName = "鱼缸收益", icon = "💎",
        desc = "提升鱼缸金币产出",
        maxLevel = 8, effectType = "multiply",
        baseEffect = 1.0, effectPerLevel = 0.12,  -- Lv8=×1.96
        baseCost = 300, costScale = 1.6,
    },
    {
        key = "aquarium_slots", category = "aquarium",
        displayName = "鱼缸扩建", icon = "🏠",
        desc = "增加鱼缸最大槽位",
        maxLevel = 4, effectType = "add",
        baseEffect = 0, effectPerLevel = 2,  -- 每级+2槽
        baseCost = 500, costScale = 2.0,
    },
    -- ====== 养殖 (3项) ======
    {
        key = "breed_speed", category = "breeding",
        displayName = "繁殖加速", icon = "⏱️",
        desc = "加快养殖产出速度",
        maxLevel = 6, effectType = "multiply",
        baseEffect = 1.0, effectPerLevel = 0.15,  -- Lv6=×1.90
        baseCost = 300, costScale = 1.7,
    },
    {
        key = "breed_slots", category = "breeding",
        displayName = "养殖扩建", icon = "🏗️",
        desc = "增加养殖最大槽位",
        maxLevel = 4, effectType = "add",
        baseEffect = 0, effectPerLevel = 2,
        baseCost = 500, costScale = 2.0,
    },
    {
        key = "quality_boost", category = "fishing",
        displayName = "品质提升", icon = "⭐",
        desc = "捕鱼时高品质概率提升",
        maxLevel = 5, effectType = "add",
        baseEffect = 0, effectPerLevel = 1,  -- 每级+1 (权重偏移值)
        baseCost = 400, costScale = 1.8,
    },
}

-- 快速查找表
GameConfig.RESEARCH_BY_KEY = {}
GameConfig.RESEARCH_BY_CATEGORY = {}
for _, cat in ipairs(GameConfig.RESEARCH_CATEGORIES) do
    GameConfig.RESEARCH_BY_CATEGORY[cat.id] = {}
end
for _, r in ipairs(GameConfig.RESEARCH) do
    GameConfig.RESEARCH_BY_KEY[r.key] = r
    table.insert(GameConfig.RESEARCH_BY_CATEGORY[r.category], r)
end

-- ========== 图鉴/收集系统 ==========
-- 集齐某鱼种全5品质后的永久奖励
GameConfig.CODEX_FISH_REWARDS = {
    { fishId = 1,  rewardType = "coinBonus",    value = 0.03, desc = "金币+3%" },
    { fishId = 2,  rewardType = "coinBonus",    value = 0.04, desc = "金币+4%" },
    { fishId = 3,  rewardType = "processSpeed", value = 0.05, desc = "合成速度+5%" },
    { fishId = 4,  rewardType = "sushiPrice",   value = 0.04, desc = "寿司售价+4%" },
    { fishId = 5,  rewardType = "comboBonus",   value = 0.05, desc = "组合加成+5%" },
    { fishId = 6,  rewardType = "coinBonus",    value = 0.05, desc = "金币+5%" },
    { fishId = 7,  rewardType = "processSpeed", value = 0.06, desc = "合成速度+6%" },
    { fishId = 8,  rewardType = "sushiPrice",   value = 0.06, desc = "寿司售价+6%" },
    { fishId = 9,  rewardType = "comboBonus",   value = 0.08, desc = "组合加成+8%" },
    { fishId = 10, rewardType = "coinBonus",    value = 0.08, desc = "金币+8%" },
}
-- 快速查找
GameConfig.CODEX_FISH_REWARD_BY_ID = {}
for _, r in ipairs(GameConfig.CODEX_FISH_REWARDS) do
    GameConfig.CODEX_FISH_REWARD_BY_ID[r.fishId] = r
end

-- 集齐某稀有度全部词条后的永久奖励
GameConfig.CODEX_AFFIX_REWARDS = {
    { rarityId = 1, rewardType = "catchValue",    value = 0.05, desc = "捕获价值+5%" },
    { rarityId = 2, rewardType = "affixChance",   value = 0.02, desc = "词条概率+2%" },
    { rarityId = 3, rewardType = "breedMutation", value = 0.02, desc = "突变概率+2%" },
    { rarityId = 4, rewardType = "allBonus",      value = 0.05, desc = "全属性+5%" },
}
GameConfig.CODEX_AFFIX_REWARD_BY_RARITY = {}
for _, r in ipairs(GameConfig.CODEX_AFFIX_REWARDS) do
    GameConfig.CODEX_AFFIX_REWARD_BY_RARITY[r.rarityId] = r
end

-- ========== 养殖品质突变 ==========
GameConfig.BREED_MUTATION = {
    BASE_CHANCE = 0.05,     -- 基础突变概率5%
    MAX_QUALITY = 5,        -- 最大品质(金色)不可突变
    -- 各品质的突变概率因子: 品质越高突变越难
    QUALITY_FACTOR = { 1.0, 0.8, 0.6, 0.4, 0 },
}

-- ========== 产业系统 ==========
GameConfig.INDUSTRY = {
    UPGRADE_PRICE_BONUS = 0.15,  -- 每级售价+15%

    -- 合成队列（待处理区）
    SYNTHESIS_BASE_TIME = 5,     -- 基础合成时间(秒)
    QUEUE_MAX_SLOTS = 8,         -- 待处理区最大槽位
    QUEUE_INITIAL_SLOTS = 3,     -- 初始解锁槽位数
    QUEUE_SLOT_UNLOCK_COST = {   -- 每个槽解锁费用（前3个免费）
        0, 0, 0,
        500, 1000, 2000, 4000, 8000,
    },
}

return GameConfig
