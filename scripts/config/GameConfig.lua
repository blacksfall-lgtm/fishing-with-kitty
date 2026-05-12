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

-- ========== 30种鱼配置 (每海域6种) ==========
GameConfig.FISH = {
    -- ====== 近海 nearshore (id 1-6) ======
    {
        id = 1, name = "sardine", displayName = "小沙丁鱼", icon = "fish_sardine",
        zone = "nearshore", fishType = "producer", rarity = "common",
        baseValue = 10, catchWeight = 30,
        qualityWeights = { 60, 25, 10, 4, 1 },
        desc = "最常见的近海鱼，新手的好伙伴",
    },
    {
        id = 2, name = "clownfish", displayName = "小丑鱼", icon = "fish_clownfish",
        zone = "nearshore", fishType = "producer", rarity = "common",
        baseValue = 18, catchWeight = 25,
        qualityWeights = { 55, 28, 12, 4, 1 },
        desc = "色彩鲜艳的热带鱼",
    },
    {
        id = 3, name = "bubblefish", displayName = "泡泡鱼", icon = "fish_bubblefish",
        zone = "nearshore", fishType = "accelerator", rarity = "common",
        baseValue = 15, catchWeight = 22,
        qualityWeights = { 58, 26, 11, 4, 1 },
        desc = "会吐泡泡的可爱小鱼",
    },
    {
        id = 4, name = "coralfish", displayName = "珊瑚鱼", icon = "fish_coralfish",
        zone = "nearshore", fishType = "amplifier", rarity = "uncommon",
        baseValue = 22, catchWeight = 18,
        qualityWeights = { 55, 27, 12, 5, 1 },
        desc = "珊瑚丛中的增幅鱼",
    },
    {
        id = 5, name = "shellfish", displayName = "贝壳鱼", icon = "fish_shellfish",
        zone = "nearshore", fishType = "combo", rarity = "uncommon",
        baseValue = 25, catchWeight = 15,
        qualityWeights = { 52, 28, 13, 5, 2 },
        desc = "带着贝壳的奇特组合鱼",
    },
    {
        id = 6, name = "bluefin", displayName = "蓝鳍鱼", icon = "fish_bluefin",
        zone = "nearshore", fishType = "producer", rarity = "rare",
        baseValue = 35, catchWeight = 10,
        qualityWeights = { 50, 28, 14, 6, 2 },
        desc = "近海最有价值的鱼",
    },
    -- ====== 外海 offshore (id 7-12) ======
    {
        id = 7, name = "flyingfish", displayName = "飞鱼", icon = "fish_flyingfish",
        zone = "offshore", fishType = "accelerator", rarity = "uncommon",
        baseValue = 60, catchWeight = 28,
        qualityWeights = { 50, 28, 14, 6, 2 },
        desc = "能飞出水面的加速型鱼",
    },
    {
        id = 8, name = "silverfish", displayName = "银枪鱼", icon = "fish_silverfish",
        zone = "offshore", fishType = "producer", rarity = "rare",
        baseValue = 90, catchWeight = 25,
        qualityWeights = { 48, 28, 15, 7, 2 },
        desc = "外海主力产出鱼",
    },
    {
        id = 9, name = "gemfish", displayName = "宝石鱼", icon = "fish_gemfish",
        zone = "offshore", fishType = "amplifier", rarity = "epic",
        baseValue = 130, catchWeight = 18,
        qualityWeights = { 45, 28, 16, 8, 3 },
        desc = "闪闪发光的增幅鱼",
    },
    {
        id = 10, name = "octopus", displayName = "章鱼", icon = "fish_octopus",
        zone = "offshore", fishType = "combo", rarity = "epic",
        baseValue = 180, catchWeight = 12,
        qualityWeights = { 42, 28, 17, 9, 4 },
        desc = "高级组合型鱼",
    },
    {
        id = 11, name = "swordfish", displayName = "旗鱼", icon = "fish_swordfish",
        zone = "offshore", fishType = "producer", rarity = "common",
        baseValue = 55, catchWeight = 26,
        qualityWeights = { 52, 27, 14, 5, 2 },
        desc = "带着长嘴的高速猎手",
    },
    {
        id = 12, name = "seahorse", displayName = "海马", icon = "fish_seahorse",
        zone = "offshore", fishType = "accelerator", rarity = "uncommon",
        baseValue = 70, catchWeight = 20,
        qualityWeights = { 48, 28, 15, 7, 2 },
        desc = "直立游泳的优雅小鱼",
    },
    -- ====== 深海 deepocean (id 13-18) ======
    {
        id = 13, name = "anglerfish", displayName = "灯笼鱼", icon = "fish_anglerfish",
        zone = "deepocean", fishType = "producer", rarity = "uncommon",
        baseValue = 200, catchWeight = 28,
        qualityWeights = { 45, 28, 16, 8, 3 },
        desc = "头顶发光灯笼的深海鱼",
    },
    {
        id = 14, name = "jellyfish", displayName = "水母鱼", icon = "fish_jellyfish",
        zone = "deepocean", fishType = "accelerator", rarity = "uncommon",
        baseValue = 220, catchWeight = 25,
        qualityWeights = { 44, 28, 16, 9, 3 },
        desc = "半透明的优雅深海舞者",
    },
    {
        id = 15, name = "viperfish", displayName = "蝰蛇鱼", icon = "fish_viperfish",
        zone = "deepocean", fishType = "amplifier", rarity = "rare",
        baseValue = 280, catchWeight = 20,
        qualityWeights = { 42, 27, 18, 9, 4 },
        desc = "长着尖牙的深海猎手",
    },
    {
        id = 16, name = "nautilus", displayName = "鹦鹉螺", icon = "fish_nautilus",
        zone = "deepocean", fishType = "combo", rarity = "rare",
        baseValue = 320, catchWeight = 16,
        qualityWeights = { 40, 28, 18, 10, 4 },
        desc = "远古活化石，组合效果极强",
    },
    {
        id = 17, name = "dragonfish", displayName = "龙鱼", icon = "fish_dragonfish",
        zone = "deepocean", fishType = "producer", rarity = "epic",
        baseValue = 400, catchWeight = 13,
        qualityWeights = { 38, 27, 19, 11, 5 },
        desc = "深海之龙，价值极高",
    },
    {
        id = 18, name = "glowsquid", displayName = "荧光鱿", icon = "fish_glowsquid",
        zone = "deepocean", fishType = "accelerator", rarity = "epic",
        baseValue = 350, catchWeight = 15,
        qualityWeights = { 40, 27, 18, 10, 5 },
        desc = "全身散发荧光的深海鱿鱼",
    },
    -- ====== 深渊 abyss (id 19-24) ======
    {
        id = 19, name = "abysseel", displayName = "深渊鳗", icon = "fish_abysseel",
        zone = "abyss", fishType = "producer", rarity = "rare",
        baseValue = 600, catchWeight = 26,
        qualityWeights = { 38, 27, 19, 11, 5 },
        desc = "深渊裂谷中蜿蜒的长鳗",
    },
    {
        id = 20, name = "phantomray", displayName = "幻影鳐", icon = "fish_phantomray",
        zone = "abyss", fishType = "accelerator", rarity = "rare",
        baseValue = 650, catchWeight = 22,
        qualityWeights = { 36, 27, 20, 12, 5 },
        desc = "如幽灵般滑行的深渊鳐鱼",
    },
    {
        id = 21, name = "crystalshrimp", displayName = "水晶虾", icon = "fish_crystalshrimp",
        zone = "abyss", fishType = "amplifier", rarity = "epic",
        baseValue = 750, catchWeight = 18,
        qualityWeights = { 34, 26, 21, 13, 6 },
        desc = "身体如水晶般透明的深渊虾",
    },
    {
        id = 22, name = "shadowwhale", displayName = "暗影鲸", icon = "fish_shadowwhale",
        zone = "abyss", fishType = "combo", rarity = "epic",
        baseValue = 900, catchWeight = 14,
        qualityWeights = { 32, 26, 22, 14, 6 },
        desc = "深渊之中的巨型暗影",
    },
    {
        id = 23, name = "voidcrab", displayName = "虚空蟹", icon = "fish_voidcrab",
        zone = "abyss", fishType = "producer", rarity = "uncommon",
        baseValue = 550, catchWeight = 24,
        qualityWeights = { 40, 27, 18, 10, 5 },
        desc = "坚甲如铁的深渊螃蟹",
    },
    {
        id = 24, name = "abyssjelly", displayName = "深渊海蜇", icon = "fish_abyssjelly",
        zone = "abyss", fishType = "accelerator", rarity = "rare",
        baseValue = 700, catchWeight = 20,
        qualityWeights = { 36, 27, 20, 12, 5 },
        desc = "散发诡异光芒的巨型海蜇",
    },
    -- ====== 传说之海 legendary (id 25-30) ======
    {
        id = 25, name = "goldendragon", displayName = "金龙鱼", icon = "fish_goldendragon",
        zone = "legendary", fishType = "producer", rarity = "epic",
        baseValue = 1500, catchWeight = 24,
        qualityWeights = { 30, 25, 22, 15, 8 },
        desc = "传说中的黄金巨龙",
    },
    {
        id = 26, name = "phoenixfish", displayName = "凤凰鱼", icon = "fish_phoenixfish",
        zone = "legendary", fishType = "accelerator", rarity = "epic",
        baseValue = 1600, catchWeight = 20,
        qualityWeights = { 28, 25, 23, 16, 8 },
        desc = "浴火重生的传说之鱼",
    },
    {
        id = 27, name = "leviathan", displayName = "利维坦", icon = "fish_leviathan",
        zone = "legendary", fishType = "amplifier", rarity = "legendary",
        baseValue = 2000, catchWeight = 15,
        qualityWeights = { 25, 24, 24, 17, 10 },
        desc = "海洋深处的终极巨兽",
    },
    {
        id = 28, name = "moonfish", displayName = "月光鱼", icon = "fish_moonfish",
        zone = "legendary", fishType = "combo", rarity = "legendary",
        baseValue = 1800, catchWeight = 16,
        qualityWeights = { 26, 24, 23, 17, 10 },
        desc = "月光下才会出现的神秘之鱼",
    },
    {
        id = 29, name = "stormturtle", displayName = "风暴龟", icon = "fish_stormturtle",
        zone = "legendary", fishType = "producer", rarity = "rare",
        baseValue = 1200, catchWeight = 22,
        qualityWeights = { 32, 25, 22, 14, 7 },
        desc = "能引发海上风暴的巨型海龟",
    },
    {
        id = 30, name = "cosmicwhale", displayName = "星辰鲸", icon = "fish_cosmicwhale",
        zone = "legendary", fishType = "amplifier", rarity = "legendary",
        baseValue = 2500, catchWeight = 10,
        qualityWeights = { 22, 23, 25, 18, 12 },
        desc = "承载星辰的宇宙巨鲸，最稀有的传说",
    },
}

-- 快速查找表
GameConfig.FISH_BY_ID = {}
GameConfig.FISH_BY_ZONE = { nearshore = {}, offshore = {}, deepocean = {}, abyss = {}, legendary = {} }
for _, fish in ipairs(GameConfig.FISH) do
    GameConfig.FISH_BY_ID[fish.id] = fish
    table.insert(GameConfig.FISH_BY_ZONE[fish.zone], fish)
end

-- ========== 25个食物配方 (每海域5个) ==========
GameConfig.SUSHI = {
    -- ====== 近海 nearshore (id 1-5) ======
    {
        id = 1, name = "sardine_sushi", displayName = "沙丁鱼寿司", icon = "sushi",
        zone = "nearshore",
        ingredients = { {fishId = 1, count = 3} },
        processTime = 5, basePrice = 60,
        desc = "最基础的寿司",
    },
    {
        id = 2, name = "clown_roll", displayName = "小丑鱼卷", icon = "sushi_roll",
        zone = "nearshore",
        ingredients = { {fishId = 2, count = 2}, {fishId = 3, count = 1} },
        processTime = 8, basePrice = 120,
        desc = "色彩缤纷的鱼卷",
    },
    {
        id = 3, name = "coral_nigiri", displayName = "珊瑚鱼握寿司", icon = "sushi",
        zone = "nearshore",
        ingredients = { {fishId = 4, count = 2}, {fishId = 1, count = 2} },
        processTime = 12, basePrice = 180,
        desc = "精致的握寿司",
    },
    {
        id = 4, name = "shell_tempura", displayName = "贝壳天妇罗", icon = "sushi",
        zone = "nearshore",
        ingredients = { {fishId = 5, count = 2}, {fishId = 3, count = 1} },
        processTime = 10, basePrice = 150,
        desc = "外酥里嫩的贝壳天妇罗",
    },
    {
        id = 5, name = "bluefin_sashimi", displayName = "蓝鳍刺身", icon = "bento",
        zone = "nearshore",
        ingredients = { {fishId = 6, count = 2}, {fishId = 2, count = 1} },
        processTime = 15, basePrice = 220,
        desc = "近海极品刺身拼盘",
    },
    -- ====== 外海 offshore (id 6-10) ======
    {
        id = 6, name = "flying_sushi", displayName = "飞鱼寿司", icon = "bento",
        zone = "offshore",
        ingredients = { {fishId = 7, count = 2}, {fishId = 8, count = 1} },
        processTime = 30, basePrice = 700,
        desc = "外海特色寿司",
    },
    {
        id = 7, name = "gem_roll", displayName = "宝石鱼卷", icon = "bento",
        zone = "offshore",
        ingredients = { {fishId = 9, count = 1}, {fishId = 8, count = 2} },
        processTime = 45, basePrice = 1200,
        desc = "闪耀的高级鱼卷",
    },
    {
        id = 8, name = "octopus_takoyaki", displayName = "章鱼小丸子", icon = "sushi",
        zone = "offshore",
        ingredients = { {fishId = 10, count = 2}, {fishId = 11, count = 1} },
        processTime = 35, basePrice = 950,
        desc = "外酥内嫩的章鱼小丸子",
    },
    {
        id = 9, name = "sword_steak", displayName = "旗鱼排", icon = "bento",
        zone = "offshore",
        ingredients = { {fishId = 11, count = 3} },
        processTime = 25, basePrice = 600,
        desc = "厚切旗鱼牛排",
    },
    {
        id = 10, name = "seahorse_soup", displayName = "海马养生汤", icon = "sushi",
        zone = "offshore",
        ingredients = { {fishId = 12, count = 2}, {fishId = 7, count = 1} },
        processTime = 40, basePrice = 800,
        desc = "滋补养生的海马汤",
    },
    -- ====== 深海 deepocean (id 11-15) ======
    {
        id = 11, name = "angler_hotpot", displayName = "灯笼鱼火锅", icon = "bento",
        zone = "deepocean",
        ingredients = { {fishId = 13, count = 2}, {fishId = 14, count = 1} },
        processTime = 60, basePrice = 2000,
        desc = "深海风味的鲜美火锅",
    },
    {
        id = 12, name = "jelly_dessert", displayName = "水母果冻", icon = "sushi",
        zone = "deepocean",
        ingredients = { {fishId = 14, count = 3} },
        processTime = 50, basePrice = 1800,
        desc = "Q弹透明的水母甜品",
    },
    {
        id = 13, name = "viper_skewer", displayName = "蝰蛇鱼串烧", icon = "sushi",
        zone = "deepocean",
        ingredients = { {fishId = 15, count = 2}, {fishId = 13, count = 1} },
        processTime = 55, basePrice = 2200,
        desc = "炭烤深海鱼串",
    },
    {
        id = 14, name = "nautilus_risotto", displayName = "鹦鹉螺炖饭", icon = "bento",
        zone = "deepocean",
        ingredients = { {fishId = 16, count = 1}, {fishId = 18, count = 1} },
        processTime = 70, basePrice = 2800,
        desc = "远古风味的浓郁炖饭",
    },
    {
        id = 15, name = "dragon_feast", displayName = "龙鱼盛宴", icon = "bento",
        zone = "deepocean",
        ingredients = { {fishId = 17, count = 1}, {fishId = 15, count = 1}, {fishId = 18, count = 1} },
        processTime = 90, basePrice = 4000,
        desc = "深海三鲜的终极盛宴",
    },
    -- ====== 深渊 abyss (id 16-20) ======
    {
        id = 16, name = "abyss_eel_bowl", displayName = "深渊鳗鱼饭", icon = "bento",
        zone = "abyss",
        ingredients = { {fishId = 19, count = 2}, {fishId = 23, count = 1} },
        processTime = 100, basePrice = 6000,
        desc = "浓汁慢烤的深渊鳗鱼",
    },
    {
        id = 17, name = "phantom_carpaccio", displayName = "幻影鳐薄切", icon = "sushi",
        zone = "abyss",
        ingredients = { {fishId = 20, count = 2}, {fishId = 24, count = 1} },
        processTime = 90, basePrice = 5500,
        desc = "入口即化的幻影刺身",
    },
    {
        id = 18, name = "crystal_cocktail", displayName = "水晶虾鸡尾酒", icon = "sushi",
        zone = "abyss",
        ingredients = { {fishId = 21, count = 2}, {fishId = 20, count = 1} },
        processTime = 80, basePrice = 5000,
        desc = "晶莹剔透的深渊开胃菜",
    },
    {
        id = 19, name = "shadow_stew", displayName = "暗影鲸炖菜", icon = "bento",
        zone = "abyss",
        ingredients = { {fishId = 22, count = 1}, {fishId = 19, count = 1} },
        processTime = 120, basePrice = 7500,
        desc = "需要两天慢炖的巨鲸料理",
    },
    {
        id = 20, name = "void_platter", displayName = "虚空拼盘", icon = "bento",
        zone = "abyss",
        ingredients = { {fishId = 23, count = 2}, {fishId = 24, count = 2} },
        processTime = 110, basePrice = 7000,
        desc = "深渊甲壳与海蜇的豪华拼盘",
    },
    -- ====== 传说之海 legendary (id 21-25) ======
    {
        id = 21, name = "golden_sashimi", displayName = "金龙刺身", icon = "bento",
        zone = "legendary",
        ingredients = { {fishId = 25, count = 2}, {fishId = 29, count = 1} },
        processTime = 150, basePrice = 15000,
        desc = "金光闪闪的极品刺身",
    },
    {
        id = 22, name = "phoenix_grill", displayName = "凤凰烤鱼", icon = "bento",
        zone = "legendary",
        ingredients = { {fishId = 26, count = 2}, {fishId = 25, count = 1} },
        processTime = 160, basePrice = 18000,
        desc = "浴火烹制的传说料理",
    },
    {
        id = 23, name = "leviathan_soup", displayName = "利维坦浓汤", icon = "bento",
        zone = "legendary",
        ingredients = { {fishId = 27, count = 1}, {fishId = 30, count = 1} },
        processTime = 200, basePrice = 25000,
        desc = "传说巨兽的终极浓汤",
    },
    {
        id = 24, name = "moonlight_set", displayName = "月光套餐", icon = "bento",
        zone = "legendary",
        ingredients = { {fishId = 28, count = 1}, {fishId = 26, count = 1}, {fishId = 29, count = 1} },
        processTime = 180, basePrice = 22000,
        desc = "月下三味的梦幻套餐",
    },
    {
        id = 25, name = "cosmic_banquet", displayName = "星辰宴", icon = "bento",
        zone = "legendary",
        ingredients = { {fishId = 30, count = 1}, {fishId = 27, count = 1}, {fishId = 28, count = 1} },
        processTime = 240, basePrice = 35000,
        desc = "集齐星辰之力的终极宴席",
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
--- 升级费用 = baseCost * level^1.4 (按 recipeId 索引, 共25项)
GameConfig.RECIPE_UPGRADE_BASE_COST = {
    -- 近海 (1-5)
    100, 150, 200, 180, 250,
    -- 外海 (6-10)
    500, 800, 700, 450, 600,
    -- 深海 (11-15)
    1500, 1200, 1600, 2000, 3000,
    -- 深渊 (16-20)
    4500, 4000, 3800, 5500, 5000,
    -- 传说 (21-25)
    10000, 12000, 18000, 15000, 25000,
}

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
            icon   = fish and fish.icon or "fish_sardine",
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
        id = 1, type = "fisher", displayName = "钓鱼手", icon = "fisher",
        portrait = "image/crew_fisher_20260427080355.png",
        desc = "提升自动捕鱼速度",
        baseBonus = 0.15,       -- 基础: 捕鱼速度+15%
        bonusPerLevel = 0.03,   -- 每级+3%
        upgradeCostBase = 200,
        upgradeCostScale = 1.5,
    },
    {
        id = 2, type = "netter", displayName = "捞网手", icon = "netter",
        portrait = "image/crew_netter_20260427080343.png",
        desc = "有概率额外捕获一条鱼",
        baseBonus = 0.10,       -- 基础: 10%双倍捕获概率
        bonusPerLevel = 0.02,
        upgradeCostBase = 300,
        upgradeCostScale = 1.5,
    },
    {
        id = 3, type = "harvester", displayName = "收获手", icon = "harvester",
        portrait = "image/crew_harvester_20260427080344.png",
        desc = "提升鱼仓容量",
        baseBonus = 10,         -- 基础: 容量+10
        bonusPerLevel = 5,
        upgradeCostBase = 250,
        upgradeCostScale = 1.5,
    },
    {
        id = 4, type = "baiter", displayName = "饵料手", icon = "baiter",
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

-- 鱼图片映射 (fishName → 图片路径), 缺图用 placeholder
local FISH_PLACEHOLDER = "image/fish/fish_sardine.png"
GameConfig.FISH_IMAGE = {
    -- 近海 (1-6) — 已有图片
    sardine       = "image/fish/fish_sardine.png",
    clownfish     = "image/fish/fish_clownfish.png",
    bubblefish    = "image/fish/fish_bubblefish.png",
    coralfish     = "image/fish/fish_coralfish.png",
    shellfish     = "image/fish/fish_shellfish.png",
    bluefin       = "image/fish/fish_bluefin.png",
    -- 外海 (7-12) — 前4条已有图片
    flyingfish    = "image/fish/fish_flyingfish.png",
    silverfish    = "image/fish/fish_silverfish.png",
    gemfish       = "image/fish/fish_gemfish.png",
    octopus       = "image/fish/fish_octopus.png",
    swordfish     = FISH_PLACEHOLDER,  -- TODO: 生成旗鱼图片
    seahorse      = FISH_PLACEHOLDER,  -- TODO: 生成海马图片
    -- 深海 (13-18)
    anglerfish    = FISH_PLACEHOLDER,  -- TODO: 生成灯笼鱼图片
    jellyfish     = FISH_PLACEHOLDER,  -- TODO: 生成水母鱼图片
    viperfish     = FISH_PLACEHOLDER,  -- TODO: 生成蝰蛇鱼图片
    nautilus      = FISH_PLACEHOLDER,  -- TODO: 生成鹦鹉螺图片
    dragonfish    = FISH_PLACEHOLDER,  -- TODO: 生成龙鱼图片
    glowsquid     = FISH_PLACEHOLDER,  -- TODO: 生成荧光鱿图片
    -- 深渊 (19-24)
    abysseel      = FISH_PLACEHOLDER,  -- TODO: 生成深渊鳗图片
    phantomray    = FISH_PLACEHOLDER,  -- TODO: 生成幻影鳐图片
    crystalshrimp = FISH_PLACEHOLDER,  -- TODO: 生成水晶虾图片
    shadowwhale   = FISH_PLACEHOLDER,  -- TODO: 生成暗影鲸图片
    voidcrab      = FISH_PLACEHOLDER,  -- TODO: 生成虚空蟹图片
    abyssjelly    = FISH_PLACEHOLDER,  -- TODO: 生成深渊海蜇图片
    -- 传说 (25-30)
    goldendragon  = FISH_PLACEHOLDER,  -- TODO: 生成金龙鱼图片
    phoenixfish   = FISH_PLACEHOLDER,  -- TODO: 生成凤凰鱼图片
    leviathan     = FISH_PLACEHOLDER,  -- TODO: 生成利维坦图片
    moonfish      = FISH_PLACEHOLDER,  -- TODO: 生成月光鱼图片
    stormturtle   = FISH_PLACEHOLDER,  -- TODO: 生成风暴龟图片
    cosmicwhale   = FISH_PLACEHOLDER,  -- TODO: 生成星辰鲸图片
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
        id = "normal", displayName = "普通鱼饵", icon = "worm",
        desc = "只能吸引小鱼",
        sizeWeights = { small = 1.0, medium = 0, large = 0 },
        unlockBaitLevel = 1,  -- bait 装备等级 >= 1 即可用(初始)
    },
    {
        id = "sweet", displayName = "香甜鱼饵", icon = "candy_bait",
        desc = "有几率吸引中型鱼",
        sizeWeights = { small = 0.85, medium = 0.15, large = 0 },
        unlockBaitLevel = 3,  -- bait 装备等级 >= 3
    },
    {
        id = "shiny", displayName = "闪光鱼饵", icon = "shiny_bait",
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
    { id = "fishing",  displayName = "捕鱼", icon = "fisher" },
    { id = "industry", displayName = "产业", icon = "sushi" },
    { id = "aquarium", displayName = "鱼缸", icon = "aquarium" },
    { id = "breeding", displayName = "养殖", icon = "egg" },
}

GameConfig.RESEARCH = {
    -- ====== 捕鱼 (3项) ======
    {
        key = "fish_density", category = "fishing",
        displayName = "鱼群密度", icon = "fish_sardine",
        desc = "提升常驻鱼影数量",
        maxLevel = 8, effectType = "multiply",
        baseEffect = 1.0, effectPerLevel = 0.15,  -- Lv1=×1.15, Lv8=×2.20
        baseCost = 200, costScale = 1.6,
    },
    {
        key = "wave_interval", category = "fishing",
        displayName = "波次频率", icon = "wave",
        desc = "缩短鱼群波次间隔",
        maxLevel = 6, effectType = "multiply",
        baseEffect = 1.0, effectPerLevel = -0.08,  -- 减少, Lv6=×0.52
        baseCost = 300, costScale = 1.7,
        floorPercent = 0.50,  -- 最低50%
    },
    {
        key = "hold_capacity", category = "fishing",
        displayName = "鱼仓扩容", icon = "harvester",
        desc = "增加鱼仓最大容量",
        maxLevel = 8, effectType = "add",
        baseEffect = 0, effectPerLevel = 10,  -- 每级+10容量
        baseCost = 150, costScale = 1.5,
    },
    -- ====== 产业 (3项) ======
    {
        key = "sushi_price", category = "industry",
        displayName = "寿司溢价", icon = "coin",
        desc = "提升寿司售价",
        maxLevel = 8, effectType = "multiply",
        baseEffect = 1.0, effectPerLevel = 0.10,  -- Lv8=×1.80
        baseCost = 250, costScale = 1.6,
    },
    {
        key = "synthesis_speed", category = "industry",
        displayName = "合成加速", icon = "lightning",
        desc = "加快寿司合成速度",
        maxLevel = 6, effectType = "multiply",
        baseEffect = 1.0, effectPerLevel = 0.15,  -- Lv6=×1.90
        baseCost = 300, costScale = 1.7,
    },
    {
        key = "npc_frequency", category = "industry",
        displayName = "客流量", icon = "cat",
        desc = "缩短NPC到来间隔",
        maxLevel = 6, effectType = "multiply",
        baseEffect = 1.0, effectPerLevel = -0.08,
        baseCost = 350, costScale = 1.7,
        floorPercent = 0.50,
    },
    -- ====== 鱼缸 (2项) ======
    {
        key = "aquarium_income", category = "aquarium",
        displayName = "鱼缸收益", icon = "diamond",
        desc = "提升鱼缸金币产出",
        maxLevel = 8, effectType = "multiply",
        baseEffect = 1.0, effectPerLevel = 0.12,  -- Lv8=×1.96
        baseCost = 300, costScale = 1.6,
    },
    {
        key = "aquarium_slots", category = "aquarium",
        displayName = "鱼缸扩建", icon = "home",
        desc = "增加鱼缸最大槽位",
        maxLevel = 4, effectType = "add",
        baseEffect = 0, effectPerLevel = 2,  -- 每级+2槽
        baseCost = 500, costScale = 2.0,
    },
    -- ====== 养殖 (3项) ======
    {
        key = "breed_speed", category = "breeding",
        displayName = "繁殖加速", icon = "clock",
        desc = "加快养殖产出速度",
        maxLevel = 6, effectType = "multiply",
        baseEffect = 1.0, effectPerLevel = 0.15,  -- Lv6=×1.90
        baseCost = 300, costScale = 1.7,
    },
    {
        key = "breed_slots", category = "breeding",
        displayName = "养殖扩建", icon = "build",
        desc = "增加养殖最大槽位",
        maxLevel = 4, effectType = "add",
        baseEffect = 0, effectPerLevel = 2,
        baseCost = 500, costScale = 2.0,
    },
    {
        key = "quality_boost", category = "fishing",
        displayName = "品质提升", icon = "star",
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
-- 集齐某鱼种全5品质后的永久奖励 (30条鱼)
GameConfig.CODEX_FISH_REWARDS = {
    -- 近海 (1-6)
    { fishId = 1,  rewardType = "coinBonus",    value = 0.03, desc = "金币+3%" },
    { fishId = 2,  rewardType = "coinBonus",    value = 0.04, desc = "金币+4%" },
    { fishId = 3,  rewardType = "processSpeed", value = 0.05, desc = "合成速度+5%" },
    { fishId = 4,  rewardType = "sushiPrice",   value = 0.04, desc = "寿司售价+4%" },
    { fishId = 5,  rewardType = "comboBonus",   value = 0.05, desc = "组合加成+5%" },
    { fishId = 6,  rewardType = "coinBonus",    value = 0.05, desc = "金币+5%" },
    -- 外海 (7-12)
    { fishId = 7,  rewardType = "processSpeed", value = 0.06, desc = "合成速度+6%" },
    { fishId = 8,  rewardType = "sushiPrice",   value = 0.06, desc = "寿司售价+6%" },
    { fishId = 9,  rewardType = "comboBonus",   value = 0.08, desc = "组合加成+8%" },
    { fishId = 10, rewardType = "coinBonus",    value = 0.08, desc = "金币+8%" },
    { fishId = 11, rewardType = "sushiPrice",   value = 0.05, desc = "寿司售价+5%" },
    { fishId = 12, rewardType = "processSpeed", value = 0.07, desc = "合成速度+7%" },
    -- 深海 (13-18)
    { fishId = 13, rewardType = "coinBonus",    value = 0.10, desc = "金币+10%" },
    { fishId = 14, rewardType = "processSpeed", value = 0.08, desc = "合成速度+8%" },
    { fishId = 15, rewardType = "sushiPrice",   value = 0.08, desc = "寿司售价+8%" },
    { fishId = 16, rewardType = "comboBonus",   value = 0.10, desc = "组合加成+10%" },
    { fishId = 17, rewardType = "coinBonus",    value = 0.12, desc = "金币+12%" },
    { fishId = 18, rewardType = "processSpeed", value = 0.10, desc = "合成速度+10%" },
    -- 深渊 (19-24)
    { fishId = 19, rewardType = "sushiPrice",   value = 0.10, desc = "寿司售价+10%" },
    { fishId = 20, rewardType = "processSpeed", value = 0.12, desc = "合成速度+12%" },
    { fishId = 21, rewardType = "comboBonus",   value = 0.12, desc = "组合加成+12%" },
    { fishId = 22, rewardType = "coinBonus",    value = 0.15, desc = "金币+15%" },
    { fishId = 23, rewardType = "sushiPrice",   value = 0.08, desc = "寿司售价+8%" },
    { fishId = 24, rewardType = "processSpeed", value = 0.10, desc = "合成速度+10%" },
    -- 传说 (25-30)
    { fishId = 25, rewardType = "coinBonus",    value = 0.18, desc = "金币+18%" },
    { fishId = 26, rewardType = "processSpeed", value = 0.15, desc = "合成速度+15%" },
    { fishId = 27, rewardType = "comboBonus",   value = 0.18, desc = "组合加成+18%" },
    { fishId = 28, rewardType = "allBonus",     value = 0.10, desc = "全属性+10%" },
    { fishId = 29, rewardType = "sushiPrice",   value = 0.15, desc = "寿司售价+15%" },
    { fishId = 30, rewardType = "allBonus",     value = 0.15, desc = "全属性+15%" },
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
