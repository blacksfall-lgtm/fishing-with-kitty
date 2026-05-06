-- ============================================================================
-- AffixConfig: 鱼类词条静态配置 (20种词条 = 4稀有度 × 5个)
-- ============================================================================
local AffixConfig = {}

-- ========== 词条稀有度定义 ==========
AffixConfig.RARITY = {
    { id = 1, name = "green",  displayName = "精良", color = {100, 200, 80, 255} },
    { id = 2, name = "blue",   displayName = "稀有", color = {80, 150, 255, 255} },
    { id = 3, name = "purple", displayName = "史诗", color = {180, 80, 255, 255} },
    { id = 4, name = "gold",   displayName = "传说", color = {255, 215, 0, 255} },
}

-- 词条稀有度权重 (绿/蓝/紫/金)
AffixConfig.RARITY_WEIGHTS = { 50, 30, 15, 5 }

-- ========== 词条触发概率 ==========
AffixConfig.ROLL_CHANCE = 0.10       -- 10%概率触发词条
AffixConfig.INITIAL_COUNT = {1, 2}   -- 初始词条数量范围 [min, max]
AffixConfig.MAX_AFFIXES = 8          -- 单条鱼最大词条数

-- ========== 继承参数 (帕鲁式) ==========
AffixConfig.INHERIT = {
    BASE_CHANCE = 0.60,       -- 每条词条被继承的基础概率
    RARITY_BONUS = {          -- 稀有度对继承概率的修正
        [1] = 0.00,           -- 绿色: +0%
        [2] = -0.05,          -- 蓝色: -5%
        [3] = -0.10,          -- 紫色: -10%
        [4] = -0.15,          -- 金色: -15%
    },
    MUTATION_CHANCE = 0.05,   -- 5%概率变异出新词条
}

-- ========== 20种词条定义 ==========
-- sizeScale: 对鱼外观大小的影响倍率
-- colorTint: 对鱼颜色的RGBA偏移 (叠加)
-- valueBonus: 对鱼价值的加成比例
AffixConfig.AFFIXES = {
    -- ===== 绿色 (稀有度1): 基础词条 =====
    {
        id = 1, name = "sturdy", displayName = "强壮",
        rarity = 1, sizeScale = 1.08, valueBonus = 0.05,
        colorTint = {10, 0, 0, 0},
        desc = "体型略大，价值+5%",
    },
    {
        id = 2, name = "swift", displayName = "迅捷",
        rarity = 1, sizeScale = 0.95, valueBonus = 0.08,
        colorTint = {0, 10, 20, 0},
        desc = "体型纤细，价值+8%",
    },
    {
        id = 3, name = "vibrant", displayName = "鲜艳",
        rarity = 1, sizeScale = 1.0, valueBonus = 0.10,
        colorTint = {20, 10, 0, 0},
        desc = "色彩鲜艳，价值+10%",
    },
    {
        id = 4, name = "hardy", displayName = "坚韧",
        rarity = 1, sizeScale = 1.05, valueBonus = 0.07,
        colorTint = {0, 0, 0, 0},
        desc = "体质强健，价值+7%",
    },
    {
        id = 5, name = "calm", displayName = "沉静",
        rarity = 1, sizeScale = 1.0, valueBonus = 0.15,
        colorTint = {0, 0, 15, 0},
        desc = "性格温和，价值+15%",
    },

    -- ===== 蓝色 (稀有度2): 进阶词条 =====
    {
        id = 6, name = "shimmering", displayName = "闪光",
        rarity = 2, sizeScale = 1.0, valueBonus = 0.18,
        colorTint = {15, 20, 30, 0},
        desc = "鳞片闪烁微光，价值+18%",
    },
    {
        id = 7, name = "giant", displayName = "巨大",
        rarity = 2, sizeScale = 1.15, valueBonus = 0.20,
        colorTint = {5, 0, 0, 0},
        desc = "体型巨大，价值+20%",
    },
    {
        id = 8, name = "graceful", displayName = "优雅",
        rarity = 2, sizeScale = 0.92, valueBonus = 0.25,
        colorTint = {10, 5, 25, 0},
        desc = "姿态优雅，价值+25%",
    },
    {
        id = 9, name = "ancient", displayName = "古老",
        rarity = 2, sizeScale = 1.10, valueBonus = 0.22,
        colorTint = {0, -5, -10, 0},
        desc = "来自远古血脉，价值+22%",
    },
    {
        id = 10, name = "fertile", displayName = "多产",
        rarity = 2, sizeScale = 1.05, valueBonus = 0.15,
        colorTint = {0, 15, 5, 0},
        desc = "繁殖力强，价值+15%",
    },

    -- ===== 紫色 (稀有度3): 稀有词条 =====
    {
        id = 11, name = "radiant", displayName = "辉光",
        rarity = 3, sizeScale = 1.05, valueBonus = 0.35,
        colorTint = {25, 20, 40, 0},
        desc = "散发柔和光芒，价值+35%",
    },
    {
        id = 12, name = "colossal", displayName = "巨兽",
        rarity = 3, sizeScale = 1.25, valueBonus = 0.40,
        colorTint = {10, 0, 0, 0},
        desc = "体型极其庞大，价值+40%",
    },
    {
        id = 13, name = "phantom", displayName = "幻影",
        rarity = 3, sizeScale = 0.90, valueBonus = 0.50,
        colorTint = {-10, 5, 30, 0},
        desc = "若隐若现如幻影，价值+50%",
    },
    {
        id = 14, name = "blessed", displayName = "祝福",
        rarity = 3, sizeScale = 1.0, valueBonus = 0.45,
        colorTint = {20, 25, 10, 0},
        desc = "受到海神祝福，价值+45%",
    },
    {
        id = 15, name = "electric", displayName = "雷电",
        rarity = 3, sizeScale = 1.0, valueBonus = 0.60,
        colorTint = {30, 30, 0, 0},
        desc = "周身电弧缠绕，价值+60%",
    },

    -- ===== 金色 (稀有度4): 传说词条 =====
    {
        id = 16, name = "celestial", displayName = "天界",
        rarity = 4, sizeScale = 1.10, valueBonus = 0.70,
        colorTint = {30, 25, 50, 0},
        desc = "来自天界的神鱼，价值+70%",
    },
    {
        id = 17, name = "titan", displayName = "泰坦",
        rarity = 4, sizeScale = 1.30, valueBonus = 0.80,
        colorTint = {15, 5, 0, 0},
        desc = "泰坦般的巨大体型，价值+80%",
    },
    {
        id = 18, name = "mythic", displayName = "神话",
        rarity = 4, sizeScale = 1.0, valueBonus = 1.00,
        colorTint = {35, 20, 45, 0},
        desc = "神话中的传说之鱼，价值+100%",
    },
    {
        id = 19, name = "eternal", displayName = "永恒",
        rarity = 4, sizeScale = 1.0, valueBonus = 0.90,
        colorTint = {0, 20, 40, 0},
        desc = "超越时间的存在，价值+90%",
    },
    {
        id = 20, name = "primordial", displayName = "原初",
        rarity = 4, sizeScale = 1.20, valueBonus = 1.20,
        colorTint = {40, 30, 20, 0},
        desc = "万物起源之鱼，价值+120%",
    },
}

-- ========== 快速查找表 ==========
AffixConfig.AFFIX_BY_ID = {}
AffixConfig.AFFIXES_BY_RARITY = { {}, {}, {}, {} }
for _, affix in ipairs(AffixConfig.AFFIXES) do
    AffixConfig.AFFIX_BY_ID[affix.id] = affix
    table.insert(AffixConfig.AFFIXES_BY_RARITY[affix.rarity], affix)
end

return AffixConfig
