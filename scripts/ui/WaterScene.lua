-- ============================================================================
-- WaterScene: 纯 NanoVG 水面渲染系统
-- ============================================================================
-- 层级 (从下到上):
--   1. Base       — 双 UV 滚动水面底色
--   2. Caustic    — 焦散叠加
--   3. FishShadow — 鱼影 atlas
--   4. Ripples    — 水面涟漪圆环
--   5. BoatShadow — 船底深蓝阴影 (贴图)
--   6. BoatWake   — 船尾泡沫 (半月形贴图 + 微粒)
--   7. BoatBase   — 纯船体
--   7.5 SwipeTrail — 滑动捕鱼轨迹
--   7.8 Dock      — 码头
--   7.85 Seagulls — 海鸥飞行
--   8. UI         — 状态文字 / 捕获弹窗
-- ============================================================================
local FishSwarmSystem = require("systems.FishSwarmSystem")
local SwipeSystem     = require("systems.SwipeSystem")
local CatchAnimSystem = require("systems.CatchAnimSystem")
local BossSystem      = require("systems.BossSystem")
local ComboSystem     = require("systems.ComboSystem")
local RareFishSystem  = require("systems.RareFishSystem")
local UIAtlas         = require("ui.UIAtlas")
local UICore          = require("ui.UICore")
local GameConfig      = require("config.GameConfig")
local GameState       = require("state.GameState")
local EconomySystem   = require("systems.EconomySystem")
local FormatUtils     = require("utils.FormatUtils")

local WaterScene = {}

-- ============================================================================
-- NanoVG 图片句柄
-- ============================================================================
local imgBaseTile_   = nil
local imgCaustic_    = nil
local imgFishSheet_  = nil
local imgBoatBase_   = nil
local imgBoatShadow_ = nil
-- ===== 新增水体分层贴图 =====
local imgSeabed_     = nil   -- 海底贴图 (image/seabed_nearshore.png)
local seabedW_       = 0
local seabedH_       = 0
local imgFishShadow_ = nil   -- 专用鱼影贴图 (Textures/fish_shadow_s.png)
local fishShadowW_   = 0
local fishShadowH_   = 0
local imgSunGlitter_ = nil   -- 阳光散射遮罩 (Textures/sun_glitter_mask.png)
local imgBoatWake_   = nil
local imgBucket_     = nil
local imgDock_       = nil
local imgCat_        = nil
local imgBtnBase_    = nil
local imgAnchor_     = nil
local imgPortraitBg_ = nil   -- 头像底框 (input_square.png)
local imgCurrBg_     = nil   -- 货币条底框 (button_rectangle_line.png)
local imgCoin_       = nil   -- 金币图标
local imgDiamond_    = nil   -- 钻石图标
local imgPlus_       = nil   -- 加号图标
local imgBackpack_   = nil   -- 背包图标
local imgSettings_   = nil   -- 设置图标
local crewPortraits_ = {}    -- 船员头像 { [crewId] = imgHandle }

-- 船只升级按钮
local imgBoatIcon_     = nil   -- 船只图标
local imgUpgradeArrow_ = nil   -- 升级箭头图标
local boatUpgBtnRect_  = { x = 0, y = 0, w = 0, h = 0 }  -- 按钮点击区域

-- 升级弹窗
local showBoatUpgradePopup_ = false
local boatUpgradePopupT_    = 0   -- 动画进度 0→1
local boatUpgCloseRect_     = { x = 0, y = 0, w = 0, h = 0 }
local boatUpgConfirmRect_   = { x = 0, y = 0, w = 0, h = 0 }  -- 渔船升级按钮
local equipUpgRects_        = {}  -- { [equipId] = {x,y,w,h} } 装备升级按钮区域
local equipIcons_           = {}  -- { [equipId] = imgHandle } 装备图标缓存
local equipIconsLoaded_     = false
local upgradePopupScroll_   = 0   -- 弹窗滚动偏移

-- ========== 新鱼发现弹窗 (toast 自动消失) ==========
local showNewFishPopup_     = false
local newFishPopupTimer_    = 0      -- 已显示时长
local newFishPopupDuration_ = 2.5    -- 显示 2.5 秒
local newFishPopupData_     = nil    -- { name, displayName, icon, qualityId }

-- ========== 词条弹窗 (toast 自动消失) ==========
local showAffixPopup_       = false
local affixPopupTimer_      = 0
local affixPopupDuration_   = 3.0    -- 显示 3 秒
local affixPopupData_       = nil    -- { fishName, displayName, affixes, summary, valueMult }

-- ========== 鱼饵选择器 (模态弹窗) ==========
local showBaitSelector_     = false
local baitSelectorT_        = 0   -- 动画进度 0→1
local baitCloseRect_        = { x = 0, y = 0, w = 0, h = 0 }
local baitItemRects_        = {}     -- { [baitId] = {x,y,w,h} }
local baitBtnRect_          = { x = 0, y = 0, w = 0, h = 0 }  -- 底部鱼饵按钮区域

-- 海鸥序列帧
local seagullFrames_ = {}    -- { [1..4] = imgHandle }
local seagullFrameW_ = 0
local seagullFrameH_ = 0


-- 每种鱼的单独图片 (捕获后飞行动画用)
local fishImages_    = {}   -- fishImages_[fishName] = { img=handle, w=N, h=N }

local baseTileW_     = 0
local baseTileH_     = 0
local fishSheetW_    = 0
local fishSheetH_    = 0
local boatBaseW_     = 0
local boatBaseH_     = 0
local boatShadowW_   = 0
local boatShadowH_   = 0
local boatWakeW_     = 0
local boatWakeH_     = 0
local bucketW_       = 0
local bucketH_       = 0
local dockW_         = 0
local dockH_         = 0
local catW_          = 0
local catH_          = 0
local btnBaseW_      = 0
local btnBaseH_      = 0
local anchorW_       = 0
local anchorH_       = 0


-- ============================================================================
-- 动画状态
-- ============================================================================
local time_ = 0
local imagesLoaded_ = false

-- 鱼影数据现在由 FishSwarmSystem 管理

-- 船尾微粒泡沫 (辅助层, 5~10个小气泡)
local wakeBubbles_ = {}

-- 水面涟漪圆环系统
local ripples_ = {}
local rippleTimer_ = 0
local rippleInterval_ = 2.5  -- 初始间隔, 会在 2~3s 之间随机

-- 特殊状态
local waveIntensity_ = 1.0     -- 波次强度倍率 (1.0=正常, 1.2=波次)

-- 返航按钮点击检测
local returnBtnRect_ = { x = 0, y = 0, w = 0, h = 0 }

-- 海鸥飞行系统
local seagulls_       = {}     -- 活跃海鸥数组
local seagullTimer_   = 0      -- 生成计时器
local SEAGULL_SPAWN_MIN   = 4.0   -- 最短生成间隔 (秒)
local SEAGULL_SPAWN_MAX   = 9.0   -- 最长生成间隔
local SEAGULL_SPEED_MIN   = 40    -- 最慢飞行速度 (px/s)
local SEAGULL_SPEED_MAX   = 80    -- 最快飞行速度
local SEAGULL_SIZE_MIN    = 28    -- 最小绘制尺寸
local SEAGULL_SIZE_MAX    = 48    -- 最大绘制尺寸
local SEAGULL_ANIM_FPS    = 5     -- 帧动画速率
local SEAGULL_MAX_COUNT   = 3     -- 同屏最大数量
local seagullNextSpawn_   = 3.0   -- 首次生成延迟

-- 尾浪调试模式
local WAKE_DEBUG = false         -- 开启后显示尾浪渲染范围边框和参数
local wakeOffsetX_  = 2.0        -- 相对船中心的 X 偏移 (px)
local wakeOffsetY_  = 75.0       -- 相对船中心的 Y 偏移 (px)
local wakeScale_    = 1.415      -- 尾浪缩放 (相对船宽倍率)
local wakeAnchorY_  = 0.30       -- 贴图 Y 锚点偏移 (0=顶对齐, 0.5=居中)
local wakeDragMode_ = ""         -- "" | "move" | "scale"
local wakeDragCorner_ = ""       -- "tl"|"tr"|"bl"|"br" 哪个角
local wakeDragStartX_ = 0
local wakeDragStartY_ = 0
local wakeDragStartScale_ = 1.0
local wakeDragStartOffX_ = 0
local wakeDragStartOffY_ = 0
-- 记录上一帧尾浪的屏幕坐标 (用于命中检测)
local wakeScreenRect_ = { x = 0, y = 0, w = 0, h = 0 }

-- 水桶调试模式
local BUCKET_DEBUG = false       -- 开启后显示十字线和坐标, 可拖拽
local bucketOffsetX_ = -0.18    -- 相对船中心的 X 偏移 (占船宽比例, -0.5~0.5)
local bucketOffsetY_ = 0.24     -- 相对船中心的 Y 偏移 (占船高比例, -0.5~0.5)
local bucketScale_   = 0.18     -- 水桶缩放 (占船宽比例)
local bucketDragging_ = false    -- 是否正在拖拽水桶
local bucketScreenX_ = 0         -- 水桶当前屏幕坐标 (用于拖拽命中检测)
local bucketScreenY_ = 0

-- 猫咪参数 (相对船中心偏移, 占船宽比例)
local CAT_DEBUG      = false     -- 调试开关
local catOffsetX_    = -0.014
local catOffsetY_    = -0.029
local catScale_      = 0.646
local catDragMode_   = nil       -- "move" | "scale" | nil
local catDragStartX_ = 0
local catDragStartY_ = 0
local catDragInitOX_ = 0
local catDragInitOY_ = 0
local catDragInitS_  = 0
local catCornerIdx_  = 0

-- ============================================================================
-- 鱼竿 + 鱼线 + 落水波纹系统
-- ============================================================================
local imgRod_    = nil       -- 鱼竿贴图
local rodImgW_   = 0
local rodImgH_   = 0

-- 4根鱼竿位置 (相对船中心, 占船宽/高比例)
-- ox/oy: 竿根位置, side: -1左/+1右 (控制图片翻转和朝向), lineLen: 鱼线长度倍率, phase: 晃动相位
local ROD_TILT_DEG = 35  -- 所有鱼竿统一倾斜角度 (度)
local ROD_TILT_RAD = math.rad(ROD_TILT_DEG)  -- 转弧度

local RODS = {
    { ox = -0.333, oy = -0.123, side = -1, lineLen = 1.6, phase = 0.0  },  -- 左上
    { ox =  0.309, oy = -0.117, side =  1, lineLen = 1.5, phase = 1.2  },  -- 右上
    { ox = -0.297, oy =  0.246, side = -1, lineLen = 1.4, phase = 2.5  },  -- 左下
    { ox =  0.256, oy =  0.261, side =  1, lineLen = 1.3, phase = 3.7  },  -- 右下
}
local ROD_LENGTH   = 0.7    -- 鱼竿长度 (占船宽比例)
local ROD_IMG_SCALE = 0.55  -- 鱼竿图片缩放 (占船宽比例)
-- 图片原始方向: 手柄左侧→竿尖右侧 (约15°仰角)
-- 图片内鱼竿的仰角补偿 (图片本身有约15°的上扬)
local ROD_IMG_ANGLE_OFFSET = math.rad(-15)
-- 图片实际旋转角度 = ROD_TILT_RAD + ROD_IMG_ANGLE_OFFSET = 35°-15° = 20°
local ROD_VISUAL_TILT = ROD_TILT_RAD + ROD_IMG_ANGLE_OFFSET
-- 竿尖在图片宽度中的位置 (左边约15%是手柄区域)
local ROD_TIP_FRACTION = 0.85

--- 计算鱼竿竿尖在船体坐标系中的位置
--- 基于图片实际变换 (ROD_IMG_SCALE * TIP_FRACTION * 旋转角) 精确匹配图片竿尖
---@param rod table  RODS 表中的元素
---@param bs table   boatState_
---@return number tipX, number tipY  竿尖在船体坐标系中的位置
local function calcRodTip(rod, bs)
    local imgW = ROD_IMG_SCALE * bs.drawW
    local tipLen = imgW * ROD_TIP_FRACTION  -- 手柄到竿尖的实际像素距离
    local baseX = rod.ox * bs.drawW
    local baseY = rod.oy * bs.drawH
    -- 匹配 renderFishingRods 中的 NanoVG 变换:
    -- right(side=+1): translate(base) → rotate(-20°) → tip at (tipLen, 0)
    -- left (side=-1): translate(base) → scale(-1,1) → rotate(-20°) → tip at (tipLen, 0)
    local tipX = baseX + rod.side * tipLen * math.cos(ROD_VISUAL_TILT)
    local tipY = baseY - tipLen * math.sin(ROD_VISUAL_TILT)
    return tipX, tipY
end

-- ============================================================================
-- 船员状态查询 (提前定义, 供鱼竿渲染和自动钓鱼使用)
-- ============================================================================

--- 判断指定配置顺序的船员是否已被招募
local function isCrewHired(configIndex)
    local crewId = GameConfig.CREW[configIndex].id
    for _, slot in pairs(GameState.crewSlots) do
        if slot and slot.crewId == crewId then
            return true
        end
    end
    return false
end

--- 按配置顺序统计连续已激活的船员数量
local function getSequentialHiredCount()
    local count = 0
    for i = 1, #GameConfig.CREW do
        if isCrewHired(i) then
            count = count + 1
        else
            break
        end
    end
    return count
end

-- 自动钓鱼配置
local ROD_CATCH_INTERVAL = 5.0       -- 每根鱼竿的自动钓鱼间隔 (秒)
local rodTimers_ = { 0, 0, 0, 0 }   -- 每根鱼竿的计时器

-- 前向声明 (实际定义在 boatState_ 之后)
local getActiveRodCount
local autoFishCatch

-- 鱼竿调试模式
local DEBUG_ROD        = false    -- 调试已关闭
local debugRodIdx_     = nil      -- 正在拖拽的鱼竿索引 (1~4)
local debugRodOffX_    = 0        -- 拖拽偏移
local debugRodOffY_    = 0

-- 鱼线落水波纹
local lineRipples_ = {}     -- { {x,y,age,maxAge,startR,endR}, ... }

-- 船影调试模式
local SHADOW_DEBUG = false       -- 调试开关
local shadowOffsetX_ = -16.0
local shadowOffsetY_ = 41.0
local shadowScale_   = 4.546
local shadowAlpha_   = 1.0
local shadowDragMode_   = nil    -- "move" | "scale" | nil
local shadowDragStartX_ = 0
local shadowDragStartY_ = 0
local shadowDragInitOX_  = 0
local shadowDragInitOY_  = 0
local shadowDragInitS_   = 0
local shadowCornerIdx_   = 0

-- ============================================================================
-- 初始化
-- ============================================================================

function WaterScene.init(nvg)
    -- 基础水面贴图 (平铺)
    imgBaseTile_ = nvgCreateImage(nvg, "Textures/water_base_tile.png",
        NVG_IMAGE_REPEATX | NVG_IMAGE_REPEATY)
    if imgBaseTile_ and imgBaseTile_ > 0 then
        baseTileW_, baseTileH_ = nvgImageSize(nvg, imgBaseTile_)
        print("[WaterScene] base tile: " .. baseTileW_ .. "x" .. baseTileH_)
    end

    -- 焦散贴图 (平铺)
    imgCaustic_ = nvgCreateImage(nvg, "Textures/water_caustic_cyan.png",
        NVG_IMAGE_REPEATX | NVG_IMAGE_REPEATY)
    if imgCaustic_ and imgCaustic_ > 0 then
        print("[WaterScene] caustic loaded")
    end

    -- 鱼影 atlas (4列 × 4行: 4种鱼 × 每种4帧游泳动画, 鱼头朝左)
    imgFishSheet_ = nvgCreateImage(nvg, "image/fish/fish_swim_atlas.png", 0)
    if imgFishSheet_ and imgFishSheet_ > 0 then
        fishSheetW_, fishSheetH_ = nvgImageSize(nvg, imgFishSheet_)
        print("[WaterScene] fish atlas: " .. fishSheetW_ .. "x" .. fishSheetH_)
        -- 防御: nvgImageSize 可能返回错误值(如 16x16), 用已知尺寸兜底
        if fishSheetW_ < 64 or fishSheetH_ < 64 then
            print("[WaterScene] WARNING: fish atlas nvgImageSize returned suspicious " .. fishSheetW_ .. "x" .. fishSheetH_ .. ", using known dimensions")
            fishSheetW_ = 1029
            fishSheetH_ = 768
        end
    end

    -- 纯船体 (俯视角卡通木船)
    imgBoatBase_ = nvgCreateImage(nvg, "image/boat_hull_v2.png", 0)
    if imgBoatBase_ and imgBoatBase_ > 0 then
        boatBaseW_, boatBaseH_ = nvgImageSize(nvg, imgBoatBase_)
        print("[WaterScene] boat base: " .. boatBaseW_ .. "x" .. boatBaseH_)
        -- 防御: nvgImageSize 可能返回错误值(如 16x16), 用已知尺寸兜底
        if boatBaseW_ < 64 or boatBaseH_ < 64 then
            print("[WaterScene] WARNING: nvgImageSize returned suspicious " .. boatBaseW_ .. "x" .. boatBaseH_ .. ", using known dimensions")
            boatBaseW_ = 512
            boatBaseH_ = 1070
        end
    end

    -- ===== 海底贴图 (水体分层背景) =====
    imgSeabed_ = nvgCreateImage(nvg, "image/seabed_nearshore.png", 0)
    if imgSeabed_ and imgSeabed_ > 0 then
        seabedW_, seabedH_ = nvgImageSize(nvg, imgSeabed_)
        if seabedW_ < 32 or seabedH_ < 32 then seabedW_ = 941; seabedH_ = 1672 end
        print("[WaterScene] seabed: " .. seabedW_ .. "x" .. seabedH_)
    else
        print("[WaterScene] WARNING: seabed image not found, using gradient fallback")
    end

    -- 专用鱼影贴图
    imgFishShadow_ = nvgCreateImage(nvg, "Textures/fish_shadow_s.png", 0)
    if imgFishShadow_ and imgFishShadow_ > 0 then
        fishShadowW_, fishShadowH_ = nvgImageSize(nvg, imgFishShadow_)
        if fishShadowW_ < 16 or fishShadowH_ < 16 then fishShadowW_ = 256; fishShadowH_ = 128 end
        print("[WaterScene] fish shadow: " .. fishShadowW_ .. "x" .. fishShadowH_)
    end

    -- 阳光散射遮罩
    imgSunGlitter_ = nvgCreateImage(nvg, "Textures/sun_glitter_mask.png", 0)
    if imgSunGlitter_ and imgSunGlitter_ > 0 then
        print("[WaterScene] sun glitter mask loaded")
    end

    -- 船底阴影
    imgBoatShadow_ = nvgCreateImage(nvg, "image/boat_shadow_true_transparent.png", 0)
    if imgBoatShadow_ and imgBoatShadow_ > 0 then
        boatShadowW_, boatShadowH_ = nvgImageSize(nvg, imgBoatShadow_)
        print("[WaterScene] boat shadow: " .. boatShadowW_ .. "x" .. boatShadowH_)
        if boatShadowW_ < 64 or boatShadowH_ < 64 then
            print("[WaterScene] WARNING: boat shadow nvgImageSize returned suspicious " .. boatShadowW_ .. "x" .. boatShadowH_ .. ", using known dimensions")
            boatShadowW_ = 512
            boatShadowH_ = 512
        end
    end

    -- 船尾泡沫贴图 (半月形, 透明底, 横向 1536x1024)
    imgBoatWake_ = nvgCreateImage(nvg, "image/boat_wake_ref.png", 0)
    if imgBoatWake_ and imgBoatWake_ > 0 then
        boatWakeW_, boatWakeH_ = nvgImageSize(nvg, imgBoatWake_)
        print("[WaterScene] boat wake: " .. boatWakeW_ .. "x" .. boatWakeH_)
        if boatWakeW_ < 64 or boatWakeH_ < 64 then
            print("[WaterScene] WARNING: boat wake nvgImageSize returned suspicious " .. boatWakeW_ .. "x" .. boatWakeH_ .. ", using known dimensions")
            boatWakeW_ = 1536
            boatWakeH_ = 1024
        end
    end

    -- 鱼竿贴图
    imgRod_ = nvgCreateImage(nvg, "image/fishing_rod_20260428044026.png", 0)
    if imgRod_ and imgRod_ > 0 then
        rodImgW_, rodImgH_ = nvgImageSize(nvg, imgRod_)
        print("[WaterScene] fishing rod: " .. rodImgW_ .. "x" .. rodImgH_)
        if rodImgW_ < 16 or rodImgH_ < 16 then
            rodImgW_ = 256
            rodImgH_ = 256
        end
    end

    -- 水桶 (俯视角, 透明底)
    imgBucket_ = nvgCreateImage(nvg, "image/bucket_cartoon_20260426152025.png", 0)
    if imgBucket_ and imgBucket_ > 0 then
        bucketW_, bucketH_ = nvgImageSize(nvg, imgBucket_)
        print("[WaterScene] bucket: " .. bucketW_ .. "x" .. bucketH_)
        if bucketW_ < 16 or bucketH_ < 16 then
            bucketW_ = 256
            bucketH_ = 256
        end
    end

    -- 码头贴图 (屏幕底部装饰)
    imgDock_ = nvgCreateImage(nvg, "image/dock_bottom.png", 0)
    if imgDock_ and imgDock_ > 0 then
        dockW_, dockH_ = nvgImageSize(nvg, imgDock_)
        print("[WaterScene] dock: " .. dockW_ .. "x" .. dockH_)
    end

    imgCat_ = nvgCreateImage(nvg, "image/cat_only_20260426181622.png", NVG_IMAGE_PREMULTIPLIED)
    if imgCat_ and imgCat_ > 0 then
        catW_, catH_ = nvgImageSize(nvg, imgCat_)
        print("[WaterScene] cat: " .. catW_ .. "x" .. catH_)
    end

    imgBtnBase_ = nvgCreateImage(nvg, "image/button_square_depth_line.png", NVG_IMAGE_PREMULTIPLIED)
    if imgBtnBase_ and imgBtnBase_ > 0 then
        btnBaseW_, btnBaseH_ = nvgImageSize(nvg, imgBtnBase_)
        print("[WaterScene] btnBase: " .. btnBaseW_ .. "x" .. btnBaseH_)
    end

    imgPortraitBg_ = nvgCreateImage(nvg, "image/input_square.png", NVG_IMAGE_PREMULTIPLIED)
    if imgPortraitBg_ and imgPortraitBg_ > 0 then
        print("[WaterScene] portraitBg: loaded")
    end

    imgAnchor_ = nvgCreateImage(nvg, "image/icon_anchor.png", NVG_IMAGE_PREMULTIPLIED)
    if imgAnchor_ and imgAnchor_ > 0 then
        anchorW_, anchorH_ = nvgImageSize(nvg, imgAnchor_)
        print("[WaterScene] anchor: " .. anchorW_ .. "x" .. anchorH_)
    end

    -- 货币 HUD 图标
    imgCurrBg_ = nvgCreateImage(nvg, "image/button_rectangle_line.png", NVG_IMAGE_PREMULTIPLIED)
    imgCoin_   = nvgCreateImage(nvg, "image/icon_coin_20260427064921.png", NVG_IMAGE_PREMULTIPLIED)
    imgDiamond_= nvgCreateImage(nvg, "image/icon_diamond_v2_20260427070509.png", NVG_IMAGE_PREMULTIPLIED)
    imgPlus_   = nvgCreateImage(nvg, "image/icon_plus_20260427064347.png", NVG_IMAGE_PREMULTIPLIED)
    imgBackpack_ = nvgCreateImage(nvg, "image/bucket_cartoon_20260426152025.png", NVG_IMAGE_PREMULTIPLIED)
    imgSettings_ = nvgCreateImage(nvg, "image/icon_settings_20260427075642.png", NVG_IMAGE_PREMULTIPLIED)

    -- 船只升级按钮图标
    imgBoatIcon_     = nvgCreateImage(nvg, "image/icon_boat_upgrade_20260428113157.png", NVG_IMAGE_PREMULTIPLIED)
    imgUpgradeArrow_ = nvgCreateImage(nvg, "image/icon_upgrade_arrow_20260428113242.png", NVG_IMAGE_PREMULTIPLIED)

    -- 海鸥序列帧 (4帧翅膀动画)
    local seagullFiles = {
        "image/seagull_frame1_20260427122943.png",
        "image/seagull_frame2_fix_20260427123645.png",
        "image/seagull_frame3_20260427122924.png",
        "image/seagull_frame4_20260427122929.png",
    }
    for i, path in ipairs(seagullFiles) do
        local img = nvgCreateImage(nvg, path, NVG_IMAGE_PREMULTIPLIED)
        if img and img > 0 then
            seagullFrames_[i] = img
            if i == 1 then
                seagullFrameW_, seagullFrameH_ = nvgImageSize(nvg, img)
                if seagullFrameW_ < 16 then seagullFrameW_ = 128 end
                if seagullFrameH_ < 16 then seagullFrameH_ = 128 end
            end
            print("[WaterScene] seagull frame " .. i .. " loaded")
        else
            print("[WaterScene] WARNING: failed to load seagull frame: " .. path)
        end
    end

    -- 船员头像
    for _, crew in ipairs(GameConfig.CREW) do
        if crew.portrait then
            crewPortraits_[crew.id] = nvgCreateImage(nvg, crew.portrait, NVG_IMAGE_PREMULTIPLIED)
        end
    end

    -- 加载10种鱼的单独图片 (捕获飞行动画用)
    local fishImageFiles = {
        sardine   = "image/fish/fish_sardine.png",
        clownfish = "image/fish/fish_clownfish.png",
        bubblefish= "image/fish/fish_bubblefish.png",
        coralfish = "image/fish/fish_coralfish.png",
        shellfish = "image/fish/fish_shellfish.png",
        bluefin   = "image/fish/fish_bluefin.png",
        flyingfish= "image/fish/fish_flyingfish.png",
        silverfish= "image/fish/fish_silverfish.png",
        gemfish   = "image/fish/fish_gemfish.png",
        octopus   = "image/fish/fish_octopus.png",
    }
    for name, path in pairs(fishImageFiles) do
        local img = nvgCreateImage(nvg, path, 0)
        if img and img > 0 then
            local iw, ih = nvgImageSize(nvg, img)
            if iw < 16 or ih < 16 then iw, ih = 256, 256 end
            fishImages_[name] = { img = img, w = iw, h = ih }
            print("[WaterScene] fish image loaded: " .. name .. " (" .. iw .. "x" .. ih .. ")")
        else
            print("[WaterScene] WARNING: failed to load fish image: " .. path)
        end
    end

    imagesLoaded_ = true

    -- 初始化 UI 图集
    UIAtlas.init(nvg)

    -- 初始化鱼群刷新系统
    FishSwarmSystem.init()

    print("[WaterScene] init done")
end

-- ============================================================================
-- 船体状态计算 (供多个层共享)
-- ============================================================================
local boatState_ = {
    cx = 0, cy = 0,       -- 船体中心 (屏幕坐标)
    bobY = 0,             -- 垂直浮动偏移 (px)
    swayX = 0,            -- 水平摇摆偏移 (px)
    rot = 0,              -- 旋转角 (弧度, 含特殊状态)
    drawW = 0, drawH = 0, -- 绘制尺寸
    -- 船影延迟跟随
    shadowBobY = 0,
    shadowSwayX = 0,
    shadowRot = 0,
}

-- 船影延迟参数
local SHADOW_LERP_SPEED = 10.0   -- lerp速度, 值越大跟随越快 (0.1s延迟 ≈ 10)

--- 获取船舱中心坐标 (逻辑屏幕坐标, 含浮动偏移)
---@return number x, number y
function WaterScene.getBoatCenter()
    return boatState_.cx + boatState_.swayX, boatState_.cy + boatState_.bobY
end

-- ============================================================================
-- 自动钓鱼系统: 实际函数定义 (boatState_ 已可用)
-- ============================================================================

--- 获取当前激活的鱼竿数量 (= 已雇佣船员数量, 上限 4)
getActiveRodCount = function()
    return math.min(getSequentialHiredCount(), #RODS)
end

--- 鱼竿竿尖在屏幕坐标系中的位置 (含船体浮动偏移)
local function getRodTipScreen(rodIdx)
    local rod = RODS[rodIdx]
    local bs = boatState_
    if not rod or bs.drawW == 0 then return 0, 0 end
    local tipX, tipY = calcRodTip(rod, bs)
    return bs.cx + bs.swayX + tipX, bs.cy + bs.bobY + tipY
end

--- 自动钓鱼: 选鱼 + 奖励 + 动画
autoFishCatch = function(rodIdx)
    local bs = boatState_
    if bs.drawW == 0 then return end

    local tipScreenX, tipScreenY = getRodTipScreen(rodIdx)

    -- 按当前海域权重随机选鱼
    local zoneFish = GameConfig.FISH_BY_ZONE[GameState.currentZone]
                  or GameConfig.FISH_BY_ZONE["nearshore"]
    local totalWeight = 0
    for _, f in ipairs(zoneFish) do totalWeight = totalWeight + f.catchWeight end
    local roll = math.random() * totalWeight
    local chosenFish = zoneFish[1]
    local acc = 0
    for _, f in ipairs(zoneFish) do
        acc = acc + f.catchWeight
        if roll <= acc then chosenFish = f; break end
    end

    -- 随机品质
    local qWeights = chosenFish.qualityWeights or GameConfig.DEFAULT_QUALITY_WEIGHTS
    local qTotal = 0
    for _, w in ipairs(qWeights) do qTotal = qTotal + w end
    local qRoll = math.random() * qTotal
    local qualityId = 1
    local qAcc = 0
    for i, w in ipairs(qWeights) do
        qAcc = qAcc + w
        if qRoll <= qAcc then qualityId = i; break end
    end

    -- 金币奖励
    local coinValue = math.floor(chosenFish.baseValue
        * (GameConfig.QUALITY[qualityId] and GameConfig.QUALITY[qualityId].multiplier or 1.0))
    GameState:addCoins(coinValue)

    -- 金币弹字动画 (在竿尖位置)
    CatchAnimSystem.triggerCoinPopup(tipScreenX, tipScreenY, coinValue)

    -- 鱼飞向木桶 + 进鱼仓
    local boatX, boatY = WaterScene.getBucketCenter()
    local fishImgInfo = WaterScene.getFishImage(chosenFish.name)
    CatchAnimSystem.trigger(
        tipScreenX, tipScreenY,
        boatX, boatY,
        math.random(1, 3),
        RODS[rodIdx].side,
        40,
        graphics:GetWidth() / graphics:GetDPR(),
        graphics:GetHeight() / graphics:GetDPR(),
        fishImgInfo
    )
    GameState:addFish(chosenFish.id, qualityId, 1)

    print(string.format("[AutoFish] Rod%d → %s 品质%d +%d币",
        rodIdx, chosenFish.displayName, qualityId, coinValue))
end

local function updateBoatState(x, y, w, h)
    -- 基于屏幕短边计算船体尺寸, 横屏竖屏都不会溢出
    local shortSide = math.min(w, h)
    local imgRatio = (boatBaseW_ > 0 and boatBaseH_ > 0) and (boatBaseW_ / boatBaseH_) or 0.478
    -- 船高 = 短边 * 0.55, 船宽按原图比例
    local bh = shortSide * 0.55
    local bw = bh * imgRatio
    boatState_.drawW = bw
    boatState_.drawH = bh
    boatState_.cx = x + w * 0.5
    boatState_.cy = y + h * 0.5

    -- ---- 晃动参数 (设计文档) ----
    -- 垂直浮动: 振幅 6px, 周期 3s
    local bobAmp = 6.0 * waveIntensity_
    local bobPeriod = 3.0
    boatState_.bobY = math.sin(time_ * (2 * math.pi / bobPeriod)) * bobAmp

    -- 水平摇摆: 振幅 3px, 周期 3.5s, 不同相位
    local swayAmp = 3.0 * waveIntensity_
    local swayPeriod = 3.5
    boatState_.swayX = math.sin(time_ * (2 * math.pi / swayPeriod) + 1.3) * swayAmp

    -- 非对称旋转: -2° ~ +1.5°, 周期 2.7s
    -- 用 sin 做基础, 通过偏移和缩放实现非对称: center = (-2+1.5)/2 = -0.25°, range = (2+1.5)/2 = 1.75°
    local rotPeriod = 2.7
    local rotCenter = -0.25 * (math.pi / 180)  -- 偏心
    local rotRange  =  1.75 * (math.pi / 180)  -- 半幅
    local baseRot = rotCenter + math.sin(time_ * (2 * math.pi / rotPeriod) + 0.7) * rotRange * waveIntensity_

    boatState_.rot = baseRot
end

-- ============================================================================
-- 更新
-- ============================================================================

function WaterScene.update(dt)
    time_ = time_ + dt

    -- 鱼群系统更新 (常驻鱼 + 波次)
    FishSwarmSystem.update(dt)

    -- 捕获动画更新
    CatchAnimSystem.update(dt)

    -- ---- 自动钓鱼计时器 ----
    local activeRods = getActiveRodCount()
    for i = 1, activeRods do
        rodTimers_[i] = rodTimers_[i] + dt
        if rodTimers_[i] >= ROD_CATCH_INTERVAL then
            rodTimers_[i] = rodTimers_[i] - ROD_CATCH_INTERVAL
            autoFishCatch(i)
        end
    end
    -- 未激活的鱼竿重置计时器
    for i = activeRods + 1, #RODS do
        rodTimers_[i] = 0
    end

    -- ---- 船影延迟跟随 (0.1s lag via lerp) ----
    local lerpFactor = 1.0 - math.exp(-SHADOW_LERP_SPEED * dt)
    boatState_.shadowBobY  = boatState_.shadowBobY  + (boatState_.bobY  - boatState_.shadowBobY)  * lerpFactor
    boatState_.shadowSwayX = boatState_.shadowSwayX + (boatState_.swayX - boatState_.shadowSwayX) * lerpFactor
    boatState_.shadowRot   = boatState_.shadowRot   + (boatState_.rot   - boatState_.shadowRot)   * lerpFactor

    -- ---- 鱼王系统更新 ----
    local physW = graphics:GetWidth()
    local physH = graphics:GetHeight()
    local dpr = graphics:GetDPR()
    BossSystem.update(dt, physW / dpr, physH / dpr)

    -- ---- 波次强度: 有波次鱼时 +20%, 鱼王暴风雨时额外增强 ----
    local hasWave = FishSwarmSystem.isWaveActive and FishSwarmSystem.isWaveActive() or false
    local targetIntensity = hasWave and 1.2 or 1.0
    -- 暴风雨增强: stormT_ 0~1 → 额外增强 0~60% (叠加到波次强度)
    local stormBoost = BossSystem.getStormIntensity() * (BossSystem.getConfig().stormWaveBoost - 1.0)
    targetIntensity = targetIntensity + stormBoost
    waveIntensity_ = waveIntensity_ + (targetIntensity - waveIntensity_) * (1.0 - math.exp(-3.0 * dt))

    -- ---- 水面涟漪圆环生成 (每 2~3 秒) ----
    rippleTimer_ = rippleTimer_ + dt
    if rippleTimer_ >= rippleInterval_ then
        rippleTimer_ = 0
        rippleInterval_ = 2.0 + math.random() * 1.0  -- 2~3s
        -- 在船底左右随机位置生成涟漪
        table.insert(ripples_, {
            age = 0,
            maxAge = 1.5,                              -- 1.5s 扩散
            startR = 4,                                -- 起始半径
            endR = 30 * waveIntensity_,                -- 终止半径
            offsetX = (math.random() - 0.5) * 20,      -- 相对船中心偏移
            offsetY = (math.random() - 0.3) * 15,
        })
    end

    -- 更新涟漪, 限制最大 3 层叠加
    local i = 1
    while i <= #ripples_ do
        ripples_[i].age = ripples_[i].age + dt
        if ripples_[i].age >= ripples_[i].maxAge then
            table.remove(ripples_, i)
        else
            i = i + 1
        end
    end
    -- 如果超过 3 层, 移除最旧的
    while #ripples_ > 3 do
        table.remove(ripples_, 1)
    end

    -- ---- 船尾微粒泡沫 (5~10 个, 轻微向后漂移) ----
    -- 补充到目标数量
    local bs = boatState_
    while #wakeBubbles_ < 7 do
        wakeBubbles_[#wakeBubbles_ + 1] = {
            age = 0,
            maxAge = 0.4 + math.random() * 0.4,       -- 0.4~0.8s
            -- 相对船尾的初始偏移
            ox = (math.random() - 0.5) * bs.drawW * 0.4,
            oy = math.random() * 6,                    -- 0~6px 向后
            r  = 1.0 + math.random() * 2.0,            -- 半径 1~3px
            drift = 4 + math.random() * 8,             -- 向后漂移 4~12 px/s
            baseAlpha = 0.2 + math.random() * 0.2,    -- 初始透明度 0.2~0.4
        }
    end
    -- 更新
    i = 1
    while i <= #wakeBubbles_ do
        local b = wakeBubbles_[i]
        b.age = b.age + dt
        if b.age >= b.maxAge then
            table.remove(wakeBubbles_, i)
        else
            i = i + 1
        end
    end

    -- ---- 鱼线落水波纹更新 ----
    WaterScene.updateLineRipples(dt)

    -- ---- 海鸥飞行系统 ----
    WaterScene.updateSeagulls(dt)

    -- ---- 尾浪拖拽 (调试模式) ----
    if WAKE_DEBUG then
        WaterScene.updateWakeDrag(dt)
    end

    -- ---- 水桶拖拽 (调试模式) ----
    if BUCKET_DEBUG then
        WaterScene.updateBucketDrag(dt)
    end

    -- ---- 猫咪拖拽 (调试模式) ----
    if CAT_DEBUG then
        WaterScene.updateCatDrag(dt)
    end

    -- ---- 船影拖拽 (调试模式) ----
    if SHADOW_DEBUG then
        WaterScene.updateShadowDrag()
    end

    -- ---- 鱼竿拖拽 (调试模式) ----
    if DEBUG_ROD then
        WaterScene.updateRodDrag()
    end

    -- ---- Toast 弹窗计时器 ----
    if showNewFishPopup_ then
        newFishPopupTimer_ = newFishPopupTimer_ + dt
        if newFishPopupTimer_ >= newFishPopupDuration_ then
            showNewFishPopup_ = false
            newFishPopupData_ = nil
        end
    end
    if showAffixPopup_ then
        affixPopupTimer_ = affixPopupTimer_ + dt
        if affixPopupTimer_ >= affixPopupDuration_ then
            showAffixPopup_ = false
            affixPopupData_ = nil
        end
    end

    -- ---- 模态弹窗缩放动画 ----
    local POPUP_ANIM_SPEED = 1.0 / 0.25  -- 0.25s 完成
    if showBoatUpgradePopup_ then
        boatUpgradePopupT_ = math.min(1.0, boatUpgradePopupT_ + dt * POPUP_ANIM_SPEED)
    else
        boatUpgradePopupT_ = 0
    end
    if showBaitSelector_ then
        baitSelectorT_ = math.min(1.0, baitSelectorT_ + dt * POPUP_ANIM_SPEED)
    else
        baitSelectorT_ = 0
    end

end

-- ============================================================================
-- 主渲染入口
-- ============================================================================

function WaterScene.render(nvg, x, y, w, h)
    if not imagesLoaded_ then return end

    updateBoatState(x, y, w, h)

    -- ── 水下底层 ──────────────────────────────────────────────────
    -- 0.0 seabed (海底贴图 cover fill, 静态)
    WaterScene.renderSeabed(nvg, x, y, w, h)
    -- 0.1 fish_shadow (水下鱼影, 必须在水色罩之前)
    WaterScene.renderFishShadows(nvg, x, y, w, h)
    -- 0.12 rare_fish 水下阴影 (在水色罩之前)
    RareFishSystem.render(nvg, x, y, w, h, time_)
    -- 0.14 boss 水下鱼王阴影 (在水色罩之前; HP条由 renderBossHP 单独绘制到 UI 层)
    BossSystem.renderBoss(nvg, x, y, w, h, imgFishSheet_, fishSheetW_, fishSheetH_, time_)

    -- ── 水体覆盖层 ────────────────────────────────────────────────
    -- 0.2 water_tint (蓝绿水色罩 + 右上光雾)
    WaterScene.renderWaterTint(nvg, x, y, w, h)
    -- 0.3 depth_overlay (浅海/深海色彩叠加)
    WaterScene.renderDepthOverlay(nvg, x, y, w, h)
    -- 0.4 surface_flow (双层低alpha滚动水纹)
    WaterScene.renderSurfaceFlow(nvg, x, y, w, h)
    -- 0.6 caustic (焦散高光 additive)
    WaterScene.renderCaustic(nvg, x, y, w, h)

    -- ── 水面层 ────────────────────────────────────────────────────
    -- 0.75 sun_sparkles (右上阳光碎闪 additive)
    WaterScene.renderSunSparkles(nvg, x, y, w, h)
    -- 0.8 catch_ripple (捕获水花波纹)
    CatchAnimSystem.renderRipples(nvg)
    -- 0.9 ripples (普通水面涟漪圆环)
    WaterScene.renderRipples(nvg, x, y, w, h)
    -- 1.0 line_ripples (鱼线落水波纹)
    WaterScene.renderLineRipples(nvg, x, y, w, h)
    -- 1.1 boat_wake_ring (船周围环形水波)
    WaterScene.renderBoatWakeRing(nvg, x, y, w, h)

    -- ── 船体层 ────────────────────────────────────────────────────
    -- 5. boat_shadow
    WaterScene.renderBoatShadow(nvg, x, y, w, h)
    -- 7. boat_base (船体最上层)
    WaterScene.renderBoatBase(nvg, x, y, w, h)
    -- 7.02 fishing_rods (鱼竿+鱼线, 在船体上层)
    WaterScene.renderFishingRods(nvg, x, y, w, h)
    -- 7.05 cat (猫咪, 跟随船体)
    WaterScene.renderCat(nvg, x, y, w, h)
    -- 7.1 bucket (水桶, 跟随船体)
    WaterScene.renderBucket(nvg, x, y, w, h)
    -- 7.3 flying_fish (捕获后跳出飞向船舱的鱼)
    CatchAnimSystem.renderFlyingFish(nvg, imgFishSheet_, fishSheetW_, fishSheetH_)
    -- 7.4 landing_splash (鱼落桶水花)
    CatchAnimSystem.renderLandingSplash(nvg)
    -- 7.45 coin_popup (金币弹字, 小鱼捕获反馈)
    CatchAnimSystem.renderCoinPopups(nvg)
    -- 7.46 combo_popup (连击计数弹字)
    ComboSystem.render(nvg)
    -- 7.5 swipe_trail (滑动轨迹)
    SwipeSystem.render(nvg, x, y, w, h)
    -- 7.8 dock (码头, 屏幕底部装饰)
    WaterScene.renderDock(nvg, x, y, w, h)
    -- 7.85 seagulls (海鸥飞行, 在码头上方、UI 下方)
    WaterScene.renderSeagulls(nvg, x, y, w, h)
    -- 7.88 storm overlay (暴风雨全屏压暗, 在雨滴之下)
    BossSystem.renderStormOverlay(nvg, x, y, w, h)
    -- 7.9 rain (暴风雨雨滴粒子, 在 UI 之下)
    BossSystem.renderRain(nvg, x, y, w, h)
    -- 7.95 lightning flash (闪电闪屏, 在雨滴之上)
    BossSystem.renderLightningFlash(nvg, x, y, w, h)
    -- 8. currency HUD (左上角金币/钻石)
    WaterScene.renderCurrencyHUD(nvg, x, y, w, h)
    -- 8.05 crew list (货币条下方, 左侧)
    WaterScene.renderCrewList(nvg, x, y, w, h)
    -- 8.1 return button (返航按钮, 右下角)
    WaterScene.renderReturnBtn(nvg, x, y, w, h)
    -- 8.2 top-right buttons (背包/设置, 右上角)
    WaterScene.renderTopRightBtns(nvg, x, y, w, h)
    -- 8.3 bait button (鱼饵按钮, 左下角)
    WaterScene.renderBaitBtn(nvg, x, y, w, h)

    -- ========== 弹窗层 (在所有 HUD 之上) ==========
    -- 9.0 升级弹窗
    WaterScene.renderBoatUpgradePopup(nvg, x, y, w, h)
    -- 9.1 鱼饵选择器
    WaterScene.renderBaitSelector(nvg, x, y, w, h)
    -- 9.5 新鱼发现 toast (最上层, 不遮挡其他)
    WaterScene.renderNewFishPopup(nvg, x, y, w, h)
    -- 9.6 词条 toast
    WaterScene.renderAffixPopup(nvg, x, y, w, h)
end

-- ============================================================================
-- Layer 0: Seabed — 海底静态贴图 (cover fill)
-- ============================================================================

function WaterScene.renderSeabed(nvg, x, y, w, h)
    if imgSeabed_ and imgSeabed_ > 0 and seabedW_ > 0 and seabedH_ > 0 then
        -- cover fill: 等比缩放覆盖全屏, 居中裁切
        local scale  = math.max(w / seabedW_, h / seabedH_)
        local drawW  = seabedW_ * scale
        local drawH  = seabedH_ * scale
        local drawX  = x + (w - drawW) * 0.5
        local drawY  = y + (h - drawH) * 0.5
        local pat = nvgImagePattern(nvg, drawX, drawY, drawW, drawH, 0, imgSeabed_, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, x, y, w, h)
        nvgFillPaint(nvg, pat)
        nvgFill(nvg)
    else
        -- 降级: 深蓝渐变
        local grad = nvgLinearGradient(nvg, x, y, x, y + h,
            nvgRGBA(8, 60, 110, 255), nvgRGBA(4, 35, 70, 255))
        nvgBeginPath(nvg)
        nvgRect(nvg, x, y, w, h)
        nvgFillPaint(nvg, grad)
        nvgFill(nvg)
    end
end

-- ============================================================================
-- Layer 0.2: WaterTint — 蓝绿半透叠色 + 右上阳光高光
-- ============================================================================

function WaterScene.renderWaterTint(nvg, x, y, w, h)
    -- 全局轻微提亮蓝层
    local base = nvgLinearGradient(nvg, x, y, x, y + h,
        nvgRGBA(80, 220, 245, 16), nvgRGBA(75, 215, 238, 16))
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillPaint(nvg, base)
    nvgFill(nvg)

    -- 主色调: 亮蓝(顶) → 干净浅海蓝绿(底)
    local grad = nvgLinearGradient(nvg, x, y, x, y + h,
        nvgRGBA(58, 210, 248, 36), nvgRGBA(78, 223, 212, 46))
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillPaint(nvg, grad)
    nvgFill(nvg)

    -- 右上角阳光薄雾 #CFE8FF = rgb(207,232,255), alpha 60
    local hlX = x + w * 0.80
    local hlY = y + h * 0.05
    local hlR = math.min(w, h) * 0.65
    local hl = nvgRadialGradient(nvg, hlX, hlY, hlR * 0.03, hlR,
        nvgRGBA(207, 232, 255, 60), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillPaint(nvg, hl)
    nvgFill(nvg)
end

-- ============================================================================
-- Layer 0.4: SurfaceFlow — 双层低 alpha 滚动水纹 (替代原 renderBase 滚动层)
-- ============================================================================

function WaterScene.renderSurfaceFlow(nvg, x, y, w, h)
    if not imgBaseTile_ or imgBaseTile_ <= 0 then return end

    local minDim = math.min(w, h)

    nvgSave(nvg)
    nvgGlobalCompositeBlendFunc(nvg, NVG_SRC_ALPHA, NVG_ONE_MINUS_SRC_ALPHA)

    -- 第1层: 较大tile, 向右下漂移, alpha 0.09
    local tile1 = minDim / 0.45
    local f1x =  0.005 * tile1 * time_
    local f1y =  0.010 * tile1 * time_
    local pat1 = nvgImagePattern(nvg, x + f1x, y + f1y, tile1, tile1, 0, imgBaseTile_, 1.0)
    nvgGlobalAlpha(nvg, 0.09)
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillPaint(nvg, pat1)
    nvgFill(nvg)

    -- 第2层: 较小tile, 反向漂移, alpha 0.04
    local tile2 = minDim / 0.70
    local f2x = -0.003 * tile2 * time_
    local f2y =  0.007 * tile2 * time_
    local pat2 = nvgImagePattern(nvg, x + f2x, y + f2y, tile2, tile2, 0, imgBaseTile_, 1.0)
    nvgGlobalAlpha(nvg, 0.04)
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillPaint(nvg, pat2)
    nvgFill(nvg)

    nvgRestore(nvg)
end

-- ============================================================================
-- Layer 0.6: DepthOverlay — 多点辐射渐变模拟深浅变化
-- ============================================================================

function WaterScene.renderDepthOverlay(nvg, x, y, w, h)
    -- g1: 左下浅海区 — 扩大加强, 热带浅海亮青绿
    local r1 = w * 0.80
    local g1 = nvgRadialGradient(nvg, x + w * 0.18, y + h * 0.76, r1 * 0.04, r1,
        nvgRGBA(96, 235, 215, 84), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(nvg); nvgRect(nvg, x, y, w, h)
    nvgFillPaint(nvg, g1); nvgFill(nvg)

    -- g2: 船周围局部清透亮区
    local r2 = w * 0.24
    local g2 = nvgRadialGradient(nvg, x + w * 0.50, y + h * 0.60, r2 * 0.04, r2,
        nvgRGBA(90, 228, 240, 26), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(nvg); nvgRect(nvg, x, y, w, h)
    nvgFillPaint(nvg, g2); nvgFill(nvg)

    -- g3: 中部深水层次 (极轻)
    local r3 = math.min(w, h) * 0.38
    local g3 = nvgRadialGradient(nvg, x + w * 0.50, y + h * 0.60, r3 * 0.05, r3,
        nvgRGBA(0, 120, 190, 11), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(nvg); nvgRect(nvg, x, y, w, h)
    nvgFillPaint(nvg, g3); nvgFill(nvg)

    -- g4: 右侧深水层次 (极轻)
    local r4 = math.min(w, h) * 0.32
    local g4 = nvgRadialGradient(nvg, x + w * 0.80, y + h * 0.52, r4 * 0.06, r4,
        nvgRGBA(0, 145, 210, 13), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(nvg); nvgRect(nvg, x, y, w, h)
    nvgFillPaint(nvg, g4); nvgFill(nvg)
end

-- ============================================================================
-- Layer 2.5: SunSparkles — 右上区域阳光闪光点 (加法混合)
-- ============================================================================

-- 预生成 160 条碎光的静态数据 (避免每帧构建 table)
local sunSparkleData_ = nil
local function buildSunSparkleData()
    if sunSparkleData_ then return end
    -- 使用线性同余伪随机, 保证每次相同
    local function lcg(s) return (s * 1664525 + 1013904223) % (2^32) end
    local seed = 42
    local data = {}
    -- 分三段密度: 右上角极密(0.55-1.0 x, 0.0-0.25 y) x120条
    --              中右(0.40-0.80 x, 0.15-0.40 y) x30条
    --              散落(0.30-0.70 x, 0.25-0.50 y) x10条
    local regions = {
        { n=120, x0=0.52, x1=1.00, y0=0.00, y1=0.28 },
        { n= 30, x0=0.38, x1=0.82, y0=0.18, y1=0.42 },
        { n= 10, x0=0.28, x1=0.68, y0=0.28, y1=0.50 },
    }
    for _, reg in ipairs(regions) do
        for _ = 1, reg.n do
            seed = lcg(seed)
            local rx = reg.x0 + (seed / (2^32)) * (reg.x1 - reg.x0)
            seed = lcg(seed)
            local ry = reg.y0 + (seed / (2^32)) * (reg.y1 - reg.y0)
            seed = lcg(seed)
            local sp = seed / (2^32) * 12.0   -- phase seed 0~12
            seed = lcg(seed)
            -- 线段长: 右上角越长 (rx+ry 越大越亮区)
            local lenBase = 4.0 + (seed / (2^32)) * 6.0
            seed = lcg(seed)
            -- 微小倾斜角 (-8~8度 radians)
            local tilt = ((seed / (2^32)) - 0.5) * 0.28
            -- 颜色变体: 冷白(#CFE8FF) 或 暖金(#FFE8CC)
            seed = lcg(seed)
            local colVar = (seed / (2^32)) > 0.55 and 1 or 2
            data[#data + 1] = { rx=rx, ry=ry, sp=sp, lenBase=lenBase, tilt=tilt, colVar=colVar }
        end
    end
    sunSparkleData_ = data
end

function WaterScene.renderSunSparkles(nvg, x, y, w, h)
    buildSunSparkleData()

    nvgSave(nvg)
    nvgGlobalCompositeBlendFunc(nvg, NVG_SRC_ALPHA, NVG_ONE)

    local t = time_
    for _, sp in ipairs(sunSparkleData_) do
        local sx = x + sp.rx * w
        local sy = y + sp.ry * h

        -- 闪烁 alpha: 0.10 ~ 0.55, 各自独立节奏
        local flicker = 0.32 + 0.23 * math.sin(t * 1.9 + sp.sp * 4.1)
                              + 0.05 * math.sin(t * 3.7 + sp.sp * 2.3)
        flicker = math.max(0.02, flicker)

        -- 水平短线长度随闪烁变化
        local lineLen = sp.lenBase * (0.7 + 0.3 * math.sin(t * 1.3 + sp.sp * 1.7))
        lineLen = math.max(1.5, lineLen)

        -- 颜色: 冷白 #CFE8FF(207,232,255) / 暖金 #FFE8CC(255,232,204)
        local r, g, b
        if sp.colVar == 1 then r, g, b = 207, 232, 255
        else                   r, g, b = 255, 232, 204 end

        -- 线宽: 靠近右上角越细越密
        local lw = 0.55 + 0.35 * (1.0 - sp.rx * 0.5)

        nvgSave(nvg)
        nvgGlobalAlpha(nvg, flicker)
        nvgTranslate(nvg, sx, sy)
        nvgRotate(nvg, sp.tilt)

        nvgStrokeColor(nvg, nvgRGBA(r, g, b, 230))
        nvgStrokeWidth(nvg, lw)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, -lineLen, 0)
        nvgLineTo(nvg,  lineLen, 0)
        nvgStroke(nvg)

        -- 极短垂直点缀线 (1/4 长), 增加闪光感
        if lineLen > 4.0 then
            local vLen = lineLen * 0.28
            nvgStrokeColor(nvg, nvgRGBA(r, g, b, 140))
            nvgStrokeWidth(nvg, lw * 0.7)
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, 0, -vLen); nvgLineTo(nvg, 0, vLen)
            nvgStroke(nvg)
        end

        nvgRestore(nvg)
    end

    nvgRestore(nvg)
end

-- ============================================================================
-- Layer 1: Base — 双层 UV 滚动水面底色
-- ============================================================================

function WaterScene.renderBase(nvg, x, y, w, h)
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillColor(nvg, nvgRGBA(30, 85, 130, 255))
    nvgFill(nvg)

    if not imgBaseTile_ or imgBaseTile_ <= 0 then return end

    local minDim = math.min(w, h)
    local tile1 = minDim / 0.55
    local flow1X = 0.006 * tile1 * time_
    local flow1Y = 0.012 * tile1 * time_

    local pat1 = nvgImagePattern(nvg,
        x + flow1X, y + flow1Y, tile1, tile1, 0, imgBaseTile_, 1.0)
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillPaint(nvg, pat1)
    nvgFill(nvg)

    local tile2 = minDim / 0.75
    local flow2X = -0.004 * tile2 * time_
    local flow2Y =  0.008 * tile2 * time_

    nvgSave(nvg)
    nvgGlobalAlpha(nvg, 0.3)
    local pat2 = nvgImagePattern(nvg,
        x + flow2X, y + flow2Y, tile2, tile2, 0, imgBaseTile_, 1.0)
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillPaint(nvg, pat2)
    nvgFill(nvg)
    nvgRestore(nvg)

    -- 暴风雨海面反馈: 深色叠加 + 闪电提亮
    local stormI = BossSystem.getStormIntensity()
    if stormI > 0.01 then
        -- 暴风雨时水面变深: 深蓝绿色叠加
        local darkAlpha = stormI * 0.25
        nvgBeginPath(nvg)
        nvgRect(nvg, x, y, w, h)
        nvgFillColor(nvg, nvgRGBA(5, 15, 35, math.floor(darkAlpha * 255)))
        nvgFill(nvg)

        -- 闪电瞬间: 水面泛白光 (模拟闪电照亮海面)
        local flashI = BossSystem.getLightningFlash()
        if flashI > 0.01 then
            local flashAlpha = flashI * 0.18
            nvgBeginPath(nvg)
            nvgRect(nvg, x, y, w, h)
            nvgFillColor(nvg, nvgRGBA(200, 210, 240, math.floor(flashAlpha * 255)))
            nvgFill(nvg)
        end
    end
end

-- ============================================================================
-- Layer 2: Caustic (轻微焦散, 保留水面质感)
-- ============================================================================

function WaterScene.renderCaustic(nvg, x, y, w, h)
    if not imgCaustic_ or imgCaustic_ <= 0 then return end

    local minDim = math.min(w, h)
    local tileC1 = minDim / 1.35   -- 原 1.8, 调大 tile 让光斑更疏朗
    local flowC1X = -0.008 * tileC1 * time_
    local flowC1Y =  0.005 * tileC1 * time_
    local tileC2 = minDim / 2.0    -- 原 2.5, 第二层缩小
    local flowC2X =  0.006 * tileC2 * time_
    local flowC2Y = -0.007 * tileC2 * time_

    local patC1 = nvgImagePattern(nvg,
        x + flowC1X, y + flowC1Y, tileC1, tileC1, 0, imgCaustic_, 1.0)
    local patC2 = nvgImagePattern(nvg,
        x + flowC2X, y + flowC2Y, tileC2, tileC2, 0, imgCaustic_, 1.0)

    nvgSave(nvg)
    nvgGlobalCompositeBlendFunc(nvg, NVG_SRC_ALPHA, NVG_ONE)
    nvgGlobalAlpha(nvg, 0.26)   -- 原 0.22, 提升可见度

    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillPaint(nvg, patC1)
    nvgFill(nvg)

    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillPaint(nvg, patC2)
    nvgFill(nvg)

    nvgRestore(nvg)
end

-- ============================================================================
-- Layer 3: 鱼影
-- ============================================================================

function WaterScene.renderFishShadows(nvg, x, y, w, h)
    if not imgFishSheet_ or imgFishSheet_ <= 0 or fishSheetW_ == 0 then return end

    local allFish = FishSwarmSystem.getAllFish()
    if #allFish == 0 then return end

    -- atlas 布局: 4列 × 4行
    -- 朝向: 第1排鱼头朝左, 第2~4排鱼头朝右
    local cols, rows  = 4, 4
    local cellW       = fishSheetW_ / cols
    local cellH       = fishSheetH_ / rows
    -- ping-pong: 0,1,2,3,2,1 (6步无跳变)
    local pingPong    = { 0, 1, 2, 3, 2, 1 }
    local pingPongLen = #pingPong
    local animFps     = 2

    for _, f in ipairs(allFish) do
        local fx = x + f.x * w
        local fy = y + f.y * h
        local s  = f.size
        local t  = time_ + f.phase
        -- alpha 控制在 0.12~0.22 范围, 避免鱼影过浓遮挡海底
        local fishAlpha = math.min(0.22, math.max(0.12, f.alpha or 0.18))

        if fx < x - s or fx > x + w + s or fy < y - s or fy > y + h + s then
            goto continue_shadow
        end

        -- 低频折射扭曲 (降低频率避免抖动感)
        local distortMult = f.isWave and 0.4 or 0.7
        local distortStr  = math.min(w, h) * 0.009 * distortMult
        local distX = math.sin(t * 0.65 + f.phase * 1.8) * distortStr
                    + math.sin(t * 1.30 + f.phase * 0.9) * distortStr * 0.4
        local distY = math.cos(t * 0.55 + f.phase * 1.5) * distortStr * 0.6
                    + math.cos(t * 1.10 + f.phase * 0.7) * distortStr * 0.25

        if f.isWave and f.jitterAmp then
            distX = distX + math.sin(t * 2.0 + f.jitterPhase) * f.jitterAmp * w
            distY = distY + math.cos(t * 1.7 + f.jitterPhase) * f.jitterAmp * h * 0.5
        end

        -- 非均匀缩放 + 旋转扭曲 (小幅度化)
        local scaleX  = 1.0 + math.sin(t * 0.65 + f.phase) * 0.05
        local scaleY  = 1.0 + math.cos(t * 0.50 + f.phase) * 0.04
        local rotWarp = math.sin(t * 0.80 + f.phase * 0.6) * 0.025
        local fvx = f.vx or 0; local fvy = f.vy or 0
        local tilt = math.atan(fvy, math.abs(fvx) + 0.0001)

        local ppIdx = math.floor(t * animFps) % pingPongLen + 1
        local col   = pingPong[ppIdx]
        local row   = (f.variant or 1) - 1
        local scale = s / cellW
        local drawH = cellH * scale

        -- 朝向修正: 第1排朝左(atlasFlip=1), 第2~4排朝右(atlasFlip=-1)
        -- nvgScale X = -f.dir * atlasFlip * scaleX
        -- dir=1(右行): 第1排 X=-1(翻转对齐), 第2-4排 X=1(原向)
        local atlasFlip = (f.variant == 1) and 1 or -1

        -- ── pass1: 主阴影 ─────────────────────────────────────────────────
        nvgSave(nvg)
        nvgGlobalAlpha(nvg, fishAlpha * 0.75)
        nvgTranslate(nvg, fx + distX, fy + distY)
        nvgRotate(nvg, rotWarp + tilt * f.dir)
        nvgScale(nvg, -f.dir * atlasFlip * scaleX, scaleY)

        local pat1 = nvgImagePattern(nvg,
            -col * cellW * scale - s * 0.5,
            -row * cellH * scale - drawH * 0.5,
            fishSheetW_ * scale, fishSheetH_ * scale,
            0, imgFishSheet_, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, -s * 0.5, -drawH * 0.5, s, drawH)
        nvgFillPaint(nvg, pat1)
        nvgFill(nvg)
        nvgRestore(nvg)

        -- ── pass2: 折射副影 (轻微偏移, 1/3 透明度) ────────────────────────
        local blurOffX = distortStr * 0.55 * math.sin(t * 0.8 + f.phase)
        local blurOffY = distortStr * 0.35 * math.cos(t * 1.1 + f.phase)
        nvgSave(nvg)
        nvgGlobalAlpha(nvg, fishAlpha * 0.25)
        nvgTranslate(nvg, fx + distX + blurOffX, fy + distY + blurOffY)
        nvgRotate(nvg, -rotWarp * 0.5 + tilt * f.dir)
        nvgScale(nvg, -f.dir * atlasFlip * scaleX * 1.08, scaleY * 0.92)

        local pat2 = nvgImagePattern(nvg,
            -col * cellW * scale - s * 0.5,
            -row * cellH * scale - drawH * 0.5,
            fishSheetW_ * scale, fishSheetH_ * scale,
            0, imgFishSheet_, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, -s * 0.5, -drawH * 0.5, s, drawH)
        nvgFillPaint(nvg, pat2)
        nvgFill(nvg)
        nvgRestore(nvg)

        ::continue_shadow::
    end
end

-- ============================================================================
-- Layer 1.1: BoatWakeRing — 船周椭圆形涟漪圈 (冷蓝白, 加法混合)
-- ============================================================================

function WaterScene.renderBoatWakeRing(nvg, x, y, w, h)
    local bs = boatState_
    if not bs then return end

    local cx = bs.cx + (bs.swayX or 0)
    local cy = bs.cy + (bs.bobY  or 0)

    -- 3 个持续扩散的椭圆环, 错开相位
    local numRings = 3
    local ringPeriod = 2.8  -- 每圈循环周期 (秒)
    local maxRx = w * 0.22  -- 最大水平半径
    local maxRy = h * 0.06  -- 最大垂直半径 (扁椭圆)

    nvgSave(nvg)
    nvgGlobalCompositeBlendFunc(nvg, NVG_SRC_ALPHA, NVG_ONE)

    for i = 1, numRings do
        -- 错开相位, 使三个环匀速循环
        local phase = ((time_ + (i - 1) * ringPeriod / numRings) % ringPeriod) / ringPeriod
        -- alpha: 从 0.30 线性衰减到 0, 中间略微抬高
        local alpha = 0.30 * (1.0 - phase) * math.sin(phase * math.pi)
        alpha = math.max(0, alpha)
        if alpha < 0.005 then goto continue_ring end

        local rx = maxRx * (0.25 + 0.75 * phase)  -- 从小到大
        local ry = maxRy * (0.25 + 0.75 * phase)

        -- 线宽: 扩散时变细
        local lw = 1.8 * (1.0 - phase * 0.6)

        nvgSave(nvg)
        nvgGlobalAlpha(nvg, alpha)
        nvgTranslate(nvg, cx, cy)

        -- 椭圆描边: 冷蓝白 #D8ECFF(216,236,255)
        nvgStrokeColor(nvg, nvgRGBA(216, 236, 255, 220))
        nvgStrokeWidth(nvg, lw)
        nvgBeginPath(nvg)
        nvgEllipse(nvg, 0, 0, rx, ry)
        nvgStroke(nvg)

        -- 外加一条更淡的宽环 (模拟扩散光晕)
        nvgStrokeColor(nvg, nvgRGBA(207, 232, 255, 80))
        nvgStrokeWidth(nvg, lw * 2.5)
        nvgBeginPath(nvg)
        nvgEllipse(nvg, 0, 0, rx * 1.06, ry * 1.06)
        nvgStroke(nvg)

        nvgRestore(nvg)
        ::continue_ring::
    end

    nvgRestore(nvg)
end

-- ============================================================================
-- Layer 4: 水面涟漪圆环
-- 每 2~3s 一个, 1.5s 扩散, alpha 淡出, 2~3 层叠加
-- ============================================================================

function WaterScene.renderRipples(nvg, x, y, w, h)
    if #ripples_ == 0 then return end

    local bs = boatState_
    local rippleCX = bs.cx + bs.swayX
    local rippleCY = bs.cy + bs.bobY

    nvgSave(nvg)
    for _, r in ipairs(ripples_) do
        local progress = r.age / r.maxAge  -- 0→1
        local radius = r.startR + (r.endR - r.startR) * progress
        -- alpha: 0.25 → 0, 使用 ease-out 曲线让消失更自然
        local alpha = 0.25 * (1.0 - progress * progress)

        if alpha < 0.005 then goto continue end

        nvgBeginPath(nvg)
        nvgCircle(nvg, rippleCX + r.offsetX, rippleCY + r.offsetY, radius)
        nvgStrokeColor(nvg, nvgRGBA(180, 220, 255, math.floor(alpha * 255)))
        nvgStrokeWidth(nvg, 1.2 + (1.0 - progress) * 0.8)  -- 线宽从 2 → 1.2
        nvgStroke(nvg)

        ::continue::
    end
    nvgRestore(nvg)
end

-- ============================================================================
-- Layer 5: 船底阴影 (贴图 + 调试拖拽)
-- ============================================================================

--- 更新阴影拖拽交互
function WaterScene.updateShadowDrag()
    if not SHADOW_DEBUG then return end

    local bs = boatState_
    if bs.drawW == 0 then return end

    local pressed  = input:GetMouseButtonPress(MOUSEB_LEFT)
    local down     = input:GetMouseButtonDown(MOUSEB_LEFT)
    local mx       = input.mousePosition.x / graphics:GetDPR()
    local my       = input.mousePosition.y / graphics:GetDPR()

    -- 保持阴影贴图自身宽高比，以船体宽度为基准缩放
    local aspect = (boatShadowW_ > 0 and boatShadowH_ > 0)
        and (boatShadowH_ / boatShadowW_) or 1.0
    local drawW = bs.drawW * shadowScale_
    local drawH = drawW * aspect
    local cx = bs.cx + shadowOffsetX_
    local cy = bs.cy + shadowOffsetY_

    local left   = cx - drawW * 0.5
    local top    = cy - drawH * 0.5
    local right  = cx + drawW * 0.5
    local bottom = cy + drawH * 0.5

    if pressed then
        -- 检查四角 (20px 热区)
        local corners = {
            { x = left,  y = top },
            { x = right, y = top },
            { x = left,  y = bottom },
            { x = right, y = bottom },
        }
        local hitCorner = false
        for i, c in ipairs(corners) do
            if math.abs(mx - c.x) < 20 and math.abs(my - c.y) < 20 then
                shadowDragMode_   = "scale"
                shadowDragStartX_ = mx
                shadowDragStartY_ = my
                shadowDragInitS_  = shadowScale_
                shadowCornerIdx_  = i
                hitCorner = true
                break
            end
        end
        -- 否则检查中心区域
        if not hitCorner and mx >= left and mx <= right and my >= top and my <= bottom then
            shadowDragMode_   = "move"
            shadowDragStartX_ = mx
            shadowDragStartY_ = my
            shadowDragInitOX_ = shadowOffsetX_
            shadowDragInitOY_ = shadowOffsetY_
        end
    end

    if down and shadowDragMode_ then
        local dx = mx - shadowDragStartX_
        local dy = my - shadowDragStartY_
        if shadowDragMode_ == "move" then
            shadowOffsetX_ = shadowDragInitOX_ + dx
            shadowOffsetY_ = shadowDragInitOY_ + dy
        elseif shadowDragMode_ == "scale" then
            local dist = math.sqrt(dx * dx + dy * dy)
            local sign = (dx + dy > 0) and 1 or -1
            shadowScale_ = math.max(0.3, shadowDragInitS_ + sign * dist * 0.005)
        end
    else
        shadowDragMode_ = nil
    end
end

function WaterScene.renderBoatShadow(nvg, x, y, w, h)
    if not imgBoatShadow_ or imgBoatShadow_ <= 0 then return end

    local bs = boatState_

    -- 保持阴影贴图自身宽高比
    local aspect = (boatShadowW_ > 0 and boatShadowH_ > 0)
        and (boatShadowH_ / boatShadowW_) or 1.0
    local drawW = bs.drawW * shadowScale_
    local drawH = drawW * aspect

    local sBobY  = bs.shadowBobY
    local sSwayX = bs.shadowSwayX
    local sRot   = bs.shadowRot

    nvgSave(nvg)
    nvgTranslate(nvg, bs.cx + sSwayX + shadowOffsetX_, bs.cy + sBobY + shadowOffsetY_)
    nvgRotate(nvg, sRot * 0.5)
    nvgGlobalAlpha(nvg, shadowAlpha_)

    local pat = nvgImagePattern(nvg,
        -drawW * 0.5, -drawH * 0.5,
        drawW, drawH, 0, imgBoatShadow_, 1.0)
    nvgBeginPath(nvg)
    nvgRect(nvg, -drawW * 0.5, -drawH * 0.5, drawW, drawH)
    nvgFillPaint(nvg, pat)
    nvgFill(nvg)

    -- 调试框
    if SHADOW_DEBUG then
        -- 绿色边框
        nvgBeginPath(nvg)
        nvgRect(nvg, -drawW * 0.5, -drawH * 0.5, drawW, drawH)
        nvgStrokeColor(nvg, nvgRGBA(0, 255, 0, 200))
        nvgStrokeWidth(nvg, 2)
        nvgStroke(nvg)

        -- 红色十字
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, -8, 0); nvgLineTo(nvg, 8, 0)
        nvgMoveTo(nvg, 0, -8); nvgLineTo(nvg, 0, 8)
        nvgStrokeColor(nvg, nvgRGBA(255, 0, 0, 255))
        nvgStrokeWidth(nvg, 2)
        nvgStroke(nvg)

        -- 四角蓝色方块
        local hw, hh = drawW * 0.5, drawH * 0.5
        local corners = { {-hw,-hh}, {hw,-hh}, {-hw,hh}, {hw,hh} }
        for i, c in ipairs(corners) do
            local isActive = (shadowDragMode_ == "scale" and shadowCornerIdx_ == i)
            nvgBeginPath(nvg)
            nvgRect(nvg, c[1] - 6, c[2] - 6, 12, 12)
            nvgFillColor(nvg, isActive and nvgRGBA(255, 165, 0, 255) or nvgRGBA(0, 120, 255, 255))
            nvgFill(nvg)
        end
    end

    nvgRestore(nvg)

    -- 调试信息 (屏幕左上角)
    if SHADOW_DEBUG then
        nvgSave(nvg)
        nvgResetTransform(nvg)

        nvgBeginPath(nvg)
        nvgRect(nvg, 0, 0, 360, 50)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 180))
        nvgFill(nvg)

        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 14)
        nvgFillColor(nvg, nvgRGBA(255, 255, 0, 255))
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgText(nvg, 8, 6, string.format(
            "[Shadow] scale=%.3f offX=%.1f offY=%.1f alpha=%.2f",
            shadowScale_, shadowOffsetX_, shadowOffsetY_, shadowAlpha_))
        local status = shadowDragMode_ or "idle"
        nvgText(nvg, 8, 26, string.format("drag: %s | size: %.0fx%.0f", status, drawW, drawH))

        nvgRestore(nvg)
    end
end

-- ============================================================================
-- Layer 6: 船尾浪花主层 (加法混合贴图, 无粒子/无扩散)
-- ============================================================================

-- ============================================================================
-- 尾浪拖拽交互 (调试模式)
-- 中心区域拖拽 = 移动位置; 四角拖拽 = 缩放大小
-- ============================================================================

function WaterScene.updateWakeDrag(dt)
    local bs = boatState_
    if bs.drawW == 0 then return end

    -- 获取逻辑坐标输入
    local dpr = graphics:GetDPR()
    local pressing = false
    local rawX, rawY = 0, 0

    if input:GetNumTouches() > 0 then
        local touch = input:GetTouch(0)
        pressing = true
        rawX = touch.position.x
        rawY = touch.position.y
    elseif input:GetMouseButtonDown(MOUSEB_LEFT) then
        pressing = true
        local pos = input:GetMousePosition()
        rawX = pos.x
        rawY = pos.y
    end

    local logX = rawX / dpr
    local logY = rawY / dpr

    local wr = wakeScreenRect_
    local cornerSize = 18  -- 角把手命中半径

    if pressing then
        if wakeDragMode_ == "" then
            -- 检测命中: 先检查四角, 再检查中心
            local corners = {
                { id = "tl", x = wr.x,          y = wr.y },
                { id = "tr", x = wr.x + wr.w,   y = wr.y },
                { id = "bl", x = wr.x,          y = wr.y + wr.h },
                { id = "br", x = wr.x + wr.w,   y = wr.y + wr.h },
            }

            for _, c in ipairs(corners) do
                local dx = logX - c.x
                local dy = logY - c.y
                if dx * dx + dy * dy <= cornerSize * cornerSize then
                    wakeDragMode_ = "scale"
                    wakeDragCorner_ = c.id
                    wakeDragStartX_ = logX
                    wakeDragStartY_ = logY
                    wakeDragStartScale_ = wakeScale_
                    break
                end
            end

            -- 没命中角 → 检查中心区域
            if wakeDragMode_ == "" then
                if logX >= wr.x and logX <= wr.x + wr.w
                   and logY >= wr.y and logY <= wr.y + wr.h then
                    wakeDragMode_ = "move"
                    wakeDragStartX_ = logX
                    wakeDragStartY_ = logY
                    wakeDragStartOffX_ = wakeOffsetX_
                    wakeDragStartOffY_ = wakeOffsetY_
                end
            end
        end

        -- 执行拖拽
        if wakeDragMode_ == "move" then
            wakeOffsetX_ = wakeDragStartOffX_ + (logX - wakeDragStartX_)
            wakeOffsetY_ = wakeDragStartOffY_ + (logY - wakeDragStartY_)
        elseif wakeDragMode_ == "scale" then
            -- 用拖拽距离的变化来缩放
            local cx = wr.x + wr.w * 0.5
            local cy = wr.y + wr.h * 0.5
            local distStart = math.sqrt((wakeDragStartX_ - cx) ^ 2 + (wakeDragStartY_ - cy) ^ 2)
            local distNow   = math.sqrt((logX - cx) ^ 2 + (logY - cy) ^ 2)
            if distStart > 5 then
                local ratio = distNow / distStart
                wakeScale_ = math.max(0.3, math.min(3.0, wakeDragStartScale_ * ratio))
            end
        end
    else
        -- 松手: 打印最终参数
        if wakeDragMode_ ~= "" then
            print(string.format("[WakeDebug] 最终参数 offX=%.1f offY=%.1f scale=%.3f anchorY=%.2f",
                wakeOffsetX_, wakeOffsetY_, wakeScale_, wakeAnchorY_))
            wakeDragMode_ = ""
            wakeDragCorner_ = ""
        end
    end
end

function WaterScene.renderBoatWake(nvg, x, y, w, h)
    local bs = boatState_
    if not imgBoatWake_ or imgBoatWake_ <= 0 then return end

    -- 位置: 船中心 + 可调偏移
    local wakeCX = bs.cx + bs.swayX + wakeOffsetX_
    local wakeCY = bs.cy + bs.bobY + wakeOffsetY_

    -- 缩放: 使用可调 wakeScale_, 轻微呼吸 ±2%
    local breathScale = 1.0 + math.sin(time_ * 2.0) * 0.02
    local drawW = bs.drawW * wakeScale_ * breathScale
    local drawH = drawW * (boatWakeH_ / boatWakeW_)

    -- 透明度: 0.8 ± 0.1 → 范围 0.7 ~ 0.9
    local wakeAlpha = 0.8 + math.sin(time_ * 2.0) * 0.1

    nvgSave(nvg)
    nvgTranslate(nvg, wakeCX, wakeCY)
    nvgRotate(nvg, bs.rot)

    -- 透明 PNG: 普通 Alpha Blend, 保留贴图原本透明边缘
    nvgGlobalAlpha(nvg, wakeAlpha)

    -- 贴图绘制区域 (局部坐标), anchorY 可调
    local rxL = -drawW * 0.5
    local ryT = -drawH * wakeAnchorY_
    local rxW = drawW
    local rxH = drawH

    local pat = nvgImagePattern(nvg,
        rxL, ryT,
        rxW, rxH, 0, imgBoatWake_, 1.0)

    nvgBeginPath(nvg)
    nvgRect(nvg, rxL, ryT, rxW, rxH)
    nvgFillPaint(nvg, pat)
    nvgFill(nvg)

    -- ---- 调试: 尾浪范围 + 拖拽把手 ----
    if WAKE_DEBUG then
        nvgGlobalAlpha(nvg, 1.0)

        -- 记录屏幕坐标 (考虑 translate + rotate, 简化: 忽略微小旋转)
        wakeScreenRect_.x = wakeCX + rxL
        wakeScreenRect_.y = wakeCY + ryT
        wakeScreenRect_.w = rxW
        wakeScreenRect_.h = rxH

        -- 绿色边框: 贴图绘制区域
        local borderColor = wakeDragMode_ == "move"
            and nvgRGBA(255, 200, 0, 255)
            or nvgRGBA(0, 255, 100, 200)
        nvgBeginPath(nvg)
        nvgRect(nvg, rxL, ryT, rxW, rxH)
        nvgStrokeColor(nvg, borderColor)
        nvgStrokeWidth(nvg, wakeDragMode_ == "move" and 2.5 or 1.5)
        nvgStroke(nvg)

        -- 红色十字: 锚点
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, -12, 0)
        nvgLineTo(nvg, 12, 0)
        nvgMoveTo(nvg, 0, -12)
        nvgLineTo(nvg, 0, 12)
        nvgStrokeColor(nvg, nvgRGBA(255, 50, 50, 220))
        nvgStrokeWidth(nvg, 2)
        nvgStroke(nvg)

        -- 四角缩放把手
        local hs = 6  -- 把手半径
        local corners = {
            { id = "tl", x = rxL,       y = ryT },
            { id = "tr", x = rxL + rxW, y = ryT },
            { id = "bl", x = rxL,       y = ryT + rxH },
            { id = "br", x = rxL + rxW, y = ryT + rxH },
        }
        for _, c in ipairs(corners) do
            local isActive = (wakeDragMode_ == "scale" and wakeDragCorner_ == c.id)
            nvgBeginPath(nvg)
            nvgRect(nvg, c.x - hs, c.y - hs, hs * 2, hs * 2)
            if isActive then
                nvgFillColor(nvg, nvgRGBA(255, 100, 0, 255))
            else
                nvgFillColor(nvg, nvgRGBA(0, 200, 255, 220))
            end
            nvgFill(nvg)
            nvgBeginPath(nvg)
            nvgRect(nvg, c.x - hs, c.y - hs, hs * 2, hs * 2)
            nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, 200))
            nvgStrokeWidth(nvg, 1)
            nvgStroke(nvg)
        end

        -- 参数文字 → 固定在屏幕左上角 (需要先还原 transform)
        nvgRestore(nvg)  -- 还原 translate/rotate
        nvgSave(nvg)     -- 重新 save, 在屏幕坐标系绘制

        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 13)
        nvgTextAlign(nvg, NVG_ALIGN_LEFT | NVG_ALIGN_TOP)

        -- 半透明背景条
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, 6, 6, 280, wakeDragMode_ ~= "" and 62 or 48, 4)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 180))
        nvgFill(nvg)

        nvgFillColor(nvg, nvgRGBA(255, 255, 0, 240))
        nvgText(nvg, 12, 10,
            string.format("[Wake] scale=%.3f  offX=%.1f  offY=%.1f",
                wakeScale_, wakeOffsetX_, wakeOffsetY_))
        nvgText(nvg, 12, 28,
            string.format("anchorY=%.2f  wake=%.0fx%.0f  alpha=%.2f",
                wakeAnchorY_, drawW, drawH, wakeAlpha))

        -- 拖拽状态提示
        if wakeDragMode_ ~= "" then
            nvgFillColor(nvg, nvgRGBA(255, 200, 0, 255))
            local modeText = wakeDragMode_ == "move" and ">> 拖拽移动中..." or (">> 缩放中 [" .. wakeDragCorner_ .. "]")
            nvgText(nvg, 12, 46, modeText)
        end
    end

    nvgRestore(nvg)
end

-- ============================================================================
-- Layer 6: 吃水感 — 船边缘外扩 2~3px 深蓝透明色
-- alpha 0.12~0.2, 让船看起来坐在水里
-- ============================================================================

function WaterScene.renderDraftEffect(nvg, x, y, w, h)
    local bs = boatState_

    -- 用一个比船体大 2~3px 的深蓝半透明圆角矩形模拟吃水线
    local expand = 2.5  -- 外扩像素
    local draftW = bs.drawW + expand * 2
    local draftH = bs.drawH + expand * 2
    -- alpha 微微波动 0.12~0.2
    local draftAlpha = 0.16 + math.sin(time_ * 1.8) * 0.04

    nvgSave(nvg)
    nvgTranslate(nvg, bs.cx + bs.swayX, bs.cy + bs.bobY)
    nvgRotate(nvg, bs.rot)
    nvgGlobalAlpha(nvg, draftAlpha)

    nvgBeginPath(nvg)
    -- 圆角让边缘更自然
    nvgRoundedRect(nvg, -draftW * 0.5, -draftH * 0.5, draftW, draftH, 6)
    nvgFillColor(nvg, nvgRGBA(10, 25, 60, 255))
    nvgFill(nvg)

    nvgRestore(nvg)
end

-- ============================================================================
-- Layer 7.8: 码头 (屏幕底部装饰, 贴底对齐)
-- ============================================================================

function WaterScene.renderDock(nvg, x, y, w, h)
    if not imgDock_ or imgDock_ <= 0 or dockW_ == 0 then return end

    -- 码头宽度 = 屏幕宽度, 高度按比例缩放
    local drawW = w
    local scale = drawW / dockW_
    local drawH = dockH_ * scale

    -- 贴底对齐
    local drawX = x
    local drawY = y + h - drawH

    nvgSave(nvg)
    local pat = nvgImagePattern(nvg, drawX, drawY, drawW, drawH, 0, imgDock_, 1.0)
    nvgBeginPath(nvg)
    nvgRect(nvg, drawX, drawY, drawW, drawH)
    nvgFillPaint(nvg, pat)
    nvgFill(nvg)
    nvgRestore(nvg)
end

-- ============================================================================
-- Layer 7.85: 海鸥飞行系统
-- ============================================================================

--- 生成一只新海鸥
---@param screenW number 逻辑屏幕宽
---@param screenH number 逻辑屏幕高
local function spawnSeagull(screenW, screenH)
    -- 随机飞行方向: 1=从左往右, -1=从右往左
    local dir = math.random() > 0.5 and 1 or -1
    local size = SEAGULL_SIZE_MIN + math.random() * (SEAGULL_SIZE_MAX - SEAGULL_SIZE_MIN)
    local speed = SEAGULL_SPEED_MIN + math.random() * (SEAGULL_SPEED_MAX - SEAGULL_SPEED_MIN)

    -- 起始位置: 屏幕外侧
    local startX
    if dir > 0 then
        startX = -size  -- 从左侧进入
    else
        startX = screenW + size  -- 从右侧进入
    end
    -- Y 位置: 屏幕上半部 (10%~45%), 海鸥在天空飞
    local startY = screenH * (0.10 + math.random() * 0.35)

    -- 轻微的 Y 轴波动 (模拟飞行起伏)
    local bobAmp = 3 + math.random() * 5      -- 上下幅度 3~8px
    local bobFreq = 0.8 + math.random() * 0.6 -- 频率 0.8~1.4 Hz

    table.insert(seagulls_, {
        x = startX,
        y = startY,
        dir = dir,
        speed = speed,
        size = size,
        bobAmp = bobAmp,
        bobFreq = bobFreq,
        phase = math.random() * math.pi * 2,  -- 随机初始相位
        age = 0,
        alpha = 0,  -- 淡入
    })
end

--- 更新海鸥飞行
function WaterScene.updateSeagulls(dt)
    if #seagullFrames_ < 4 then return end

    local dpr = graphics:GetDPR()
    local screenW = graphics:GetWidth() / dpr
    local screenH = graphics:GetHeight() / dpr

    -- 生成计时器
    seagullTimer_ = seagullTimer_ + dt
    if seagullTimer_ >= seagullNextSpawn_ and #seagulls_ < SEAGULL_MAX_COUNT then
        spawnSeagull(screenW, screenH)
        seagullTimer_ = 0
        seagullNextSpawn_ = SEAGULL_SPAWN_MIN + math.random() * (SEAGULL_SPAWN_MAX - SEAGULL_SPAWN_MIN)
    end

    -- 更新每只海鸥
    local i = 1
    while i <= #seagulls_ do
        local g = seagulls_[i]
        g.age = g.age + dt
        g.x = g.x + g.dir * g.speed * dt

        -- 淡入 (前 0.5s)
        if g.age < 0.5 then
            g.alpha = g.age / 0.5
        else
            g.alpha = 1.0
        end

        -- 检查是否飞出屏幕 (加上淡出区)
        local outOfScreen = false
        if g.dir > 0 and g.x > screenW + g.size * 2 then
            outOfScreen = true
        elseif g.dir < 0 and g.x < -g.size * 2 then
            outOfScreen = true
        end

        if outOfScreen then
            table.remove(seagulls_, i)
        else
            i = i + 1
        end
    end
end

--- 渲染海鸥
function WaterScene.renderSeagulls(nvg, x, y, w, h)
    if #seagullFrames_ < 4 or #seagulls_ == 0 then return end

    -- ping-pong 序列: 1,2,3,4,3,2 (平滑翅膀循环)
    local pingPong = { 1, 2, 3, 4, 3, 2 }
    local ppLen = #pingPong

    for _, g in ipairs(seagulls_) do
        -- 帧动画
        local frameIdx = math.floor(g.age * SEAGULL_ANIM_FPS) % ppLen + 1
        local imgHandle = seagullFrames_[pingPong[frameIdx]]
        if not imgHandle or imgHandle <= 0 then goto continue end

        -- Y 轴飞行起伏
        local bobY = math.sin(g.age * g.bobFreq * math.pi * 2 + g.phase) * g.bobAmp

        local drawSize = g.size
        local drawH = drawSize * (seagullFrameH_ / seagullFrameW_)
        local drawX = g.x - drawSize * 0.5
        local drawY = g.y + bobY - drawH * 0.5

        nvgSave(nvg)
        nvgGlobalAlpha(nvg, g.alpha * 0.9)

        -- 素材头朝上, 旋转90°让头朝飞行方向
        nvgTranslate(nvg, g.x, g.y + bobY)
        if g.dir > 0 then
            nvgRotate(nvg, math.pi * 0.5)   -- 顺时针90°, 头朝右
        else
            nvgRotate(nvg, -math.pi * 0.5)  -- 逆时针90°, 头朝左
        end

        local pat = nvgImagePattern(nvg,
            -drawSize * 0.5, -drawH * 0.5,
            drawSize, drawH, 0, imgHandle, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, -drawSize * 0.5, -drawH * 0.5, drawSize, drawH)
        nvgFillPaint(nvg, pat)
        nvgFill(nvg)

        nvgRestore(nvg)

        ::continue::
    end
end

-- ============================================================================
-- Layer 8: 货币 HUD (左上角)
-- ============================================================================

--- 绘制单个货币条: [图标] 数字文本 [+]  (海洋青蓝风格)
---@param nvg userdata
---@param bx number    条左上角 x
---@param by number    条左上角 y
---@param bw number    条宽
---@param bh number    条高
---@param imgIcon userdata  货币图标句柄
---@param text string       格式化后的数字
---@param showPlus boolean  是否显示加号(钻石条)
local function drawCurrencyBar(nvg, bx, by, bw, bh, imgIcon, text, showPlus)
    local r = bh * 0.38
    -- 深蓝渐变底板
    UICore.fillRRectGrad(nvg, bx, by, bw, bh, r,
        { 8, 40, 90 }, 210,
        { 5, 25, 65 }, 230)
    -- 青蓝描边
    UICore.strokeRRect(nvg, bx, by, bw, bh, r, UICore.C_GEM, 1.2, 120)

    local iconSize = bh * 0.78
    local iconY = by + (bh - iconSize) * 0.5
    local iconX = bx + 4

    -- 货币图标
    if imgIcon and imgIcon > 0 then
        local pat = nvgImagePattern(nvg, iconX, iconY, iconSize, iconSize, 0, imgIcon, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, iconX, iconY, iconSize, iconSize)
        nvgFillPaint(nvg, pat)
        nvgFill(nvg)
    end

    -- 数字文本（描边白字）
    local textX = iconX + iconSize + 4
    local cx = showPlus and (textX + (bx + bw - 18 - textX) * 0.5) or (textX + (bx + bw - textX) * 0.5)
    UICore.strokeText(nvg, text, cx, by + bh * 0.5,
        bh * 0.5, UICore.C_TITLE, UICore.C_STROKE, 2,
        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 加号按钮 (右侧, 仅钻石条)
    if showPlus and imgPlus_ and imgPlus_ > 0 then
        local plusSize = bh * 0.68
        local plusX = bx + bw - plusSize - 2
        local plusY = by + (bh - plusSize) * 0.5
        local pat = nvgImagePattern(nvg, plusX, plusY, plusSize, plusSize, 0, imgPlus_, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, plusX, plusY, plusSize, plusSize)
        nvgFillPaint(nvg, pat)
        nvgFill(nvg)
    end
end

function WaterScene.renderCurrencyHUD(nvg, x, y, w, h)
    local margin = 10
    local barH = 38
    local barW = 118
    local gap = 8

    local bx = x + margin
    local by = y + margin

    -- 金币条
    local coinText = FormatUtils.formatNumber(GameState.coins)
    drawCurrencyBar(nvg, bx, by, barW, barH, imgCoin_, coinText, false)

    -- 钻石条
    local dx = bx + barW + gap
    local diamondText = FormatUtils.formatNumber(GameState.diamonds)
    drawCurrencyBar(nvg, dx, by, barW, barH, imgDiamond_, diamondText, true)
end

-- ============================================================================
-- Layer 8.05: 船员列表 (货币条下方, 左侧纵向排列)
-- ============================================================================

--- 九宫格绘制: 将图片 imgHandle(srcW x srcH) 拉伸到 (dx,dy,dw,dh)
--- inset = 四边保留的像素数 (角不拉伸, 边只单向拉伸, 中间双向拉伸)
local function drawNinePatch(nvg, imgHandle, srcW, srcH, dx, dy, dw, dh, inset, alpha)
    if not imgHandle or imgHandle <= 0 then return end
    alpha = alpha or 1.0

    nvgSave(nvg)  -- 保护外部状态

    local L = inset          -- 左边保留
    local R = inset          -- 右边保留
    local T = inset          -- 上边保留
    local B = inset          -- 下边保留
    local midSrcW = srcW - L - R   -- 源中间宽
    local midSrcH = srcH - T - B   -- 源中间高
    local midDstW = dw - L - R     -- 目标中间宽
    local midDstH = dh - T - B     -- 目标中间高

    -- 3x3 区块: {srcX, srcY, srcW, srcH, dstX, dstY, dstW, dstH}
    local patches = {
        -- 上排: 左上角 | 上边 | 右上角
        { 0,         0,         L,       T,       dx,          dy,           L,        T       },
        { L,         0,         midSrcW, T,       dx + L,      dy,           midDstW,  T       },
        { srcW - R,  0,         R,       T,       dx + dw - R, dy,           R,        T       },
        -- 中排: 左边 | 中心 | 右边
        { 0,         T,         L,       midSrcH, dx,          dy + T,       L,        midDstH },
        { L,         T,         midSrcW, midSrcH, dx + L,      dy + T,       midDstW,  midDstH },
        { srcW - R,  T,         R,       midSrcH, dx + dw - R, dy + T,       R,        midDstH },
        -- 下排: 左下角 | 下边 | 右下角
        { 0,         srcH - B,  L,       B,       dx,          dy + dh - B,  L,        B       },
        { L,         srcH - B,  midSrcW, B,       dx + L,      dy + dh - B,  midDstW,  B       },
        { srcW - R,  srcH - B,  R,       B,       dx + dw - R, dy + dh - B,  R,        B       },
    }

    -- overlap: 相邻 patch 重叠 0.5px 消除拼接缝隙
    local ov = 0.5
    for _, p in ipairs(patches) do
        local sx, sy, sw, sh = p[1], p[2], p[3], p[4]
        local ddx, ddy, ddw, ddh = p[5], p[6], p[7], p[8]
        if ddw > 0 and ddh > 0 and sw > 0 and sh > 0 then
            nvgSave(nvg)
            -- 缩放: 让源区域填满目标区域
            local scaleX = ddw / sw
            local scaleY = ddh / sh
            -- pattern origin: 让源图片的 (sx,sy) 对齐到屏幕 (ddx,ddy)
            local patX = ddx - sx * scaleX
            local patY = ddy - sy * scaleY
            local pat = nvgImagePattern(nvg, patX, patY, srcW * scaleX, srcH * scaleY, 0, imgHandle, alpha)
            -- 绘制区域略微扩展, 消除相邻 patch 间的亚像素缝隙
            nvgBeginPath(nvg)
            nvgRect(nvg, ddx - ov, ddy - ov, ddw + ov * 2, ddh + ov * 2)
            nvgFillPaint(nvg, pat)
            nvgFill(nvg)
            nvgRestore(nvg)
        end
    end

    nvgRestore(nvg)  -- 恢复外部状态 (包括 scissor)
end

function WaterScene.renderCrewList(nvg, x, y, w, h)
    local hiredCount = getSequentialHiredCount()
    local visibleCount = hiredCount
    if visibleCount <= 0 then return end

    -- 布局参数 (对齐货币条左边距)
    local margin = 10
    local startX = x + margin + 10  -- 与货币条左侧对齐
    local startY = y + margin + 36 + 8   -- 货币条: margin + barH(36) + 间距(8)

    local cardW = 52
    local portraitSize = 40
    local gap = 6
    local textSize = 9

    for i = 1, visibleCount do
        local crewCfg = GameConfig.CREW[i]
        local hired = isCrewHired(i)
        local imgHandle = crewPortraits_[crewCfg.id]

        local cardX = startX
        local cardY = startY + (i - 1) * (cardW + 14 + gap)
        local cardH = cardW + 14   -- 肖像区 + 文字区

        -- 卡片背景: 直接拉伸 button_square_depth_line.png (尺寸接近, 无需九宫格)
        if imgBtnBase_ and imgBtnBase_ > 0 then
            local bgAlpha = 1.0
            local pat = nvgImagePattern(nvg, cardX, cardY, cardW, cardH, 0, imgBtnBase_, bgAlpha)
            nvgBeginPath(nvg)
            nvgRect(nvg, cardX, cardY, cardW, cardH)
            nvgFillPaint(nvg, pat)
            nvgFill(nvg)
        end

        -- 肖像区域
        local px = cardX + (cardW - portraitSize) * 0.5
        local py = cardY + 4
        local portraitPad = 3
        local portraitInner = portraitSize - portraitPad * 2

        -- 头像底框: 直接拉伸 input_square.png
        if imgPortraitBg_ and imgPortraitBg_ > 0 then
            local framAlpha = 1.0
            local pat = nvgImagePattern(nvg, px, py, portraitSize, portraitSize, 0, imgPortraitBg_, framAlpha)
            nvgBeginPath(nvg)
            nvgRect(nvg, px, py, portraitSize, portraitSize)
            nvgFillPaint(nvg, pat)
            nvgFill(nvg)
        end

        if imgHandle and imgHandle > 0 then
            -- 绘制肖像 (在底框内部, 留出边距)
            local alpha = 1.0
            local pat = nvgImagePattern(nvg, px + portraitPad, py + portraitPad, portraitInner, portraitInner, 0, imgHandle, alpha)
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, px + portraitPad, py + portraitPad, portraitInner, portraitInner, 3)
            nvgFillPaint(nvg, pat)
            nvgFill(nvg)

            -- 未激活: 灰色蒙版 (暂时隐藏)
            -- if not hired then
            --     nvgBeginPath(nvg)
            --     nvgRoundedRect(nvg, px + portraitPad, py + portraitPad, portraitInner, portraitInner, 3)
            --     nvgFillColor(nvg, nvgRGBA(30, 35, 50, 140))
            --     nvgFill(nvg)
            -- end
        end

        -- 名称文字（描边白字）
        UICore.strokeText(nvg, crewCfg.displayName,
            cardX + cardW * 0.5, py + portraitSize + 3 + textSize * 0.5,
            textSize, UICore.C_TITLE, UICore.C_STROKE, 2,
            NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    end
end

-- ============================================================================
-- Layer 8.1: 返航按钮 (右下角)
-- ============================================================================
function WaterScene.renderReturnBtn(nvg, x, y, w, h)
    local btnSize = 58
    local margin = 12
    local btnX = x + w - btnSize - margin
    local btnY = y + h - btnSize - margin

    returnBtnRect_.x = btnX
    returnBtnRect_.y = btnY
    returnBtnRect_.w = btnSize
    returnBtnRect_.h = btnSize

    local r = 12
    -- 深蓝渐变底板
    UICore.fillRRectGrad(nvg, btnX, btnY, btnSize, btnSize, r,
        { 10, 50, 110 }, 220,
        {  6, 30,  80 }, 240)
    -- 青蓝描边
    UICore.strokeRRect(nvg, btnX, btnY, btnSize, btnSize, r, UICore.C_GEM, 1.5, 150)

    -- 图标 + 文字整体居中
    local iconSize = 22
    local labelH = 12
    local gap = 2
    local totalH = iconSize + gap + labelH
    local startY = btnY + (btnSize - totalH) * 0.5 - 1
    local cx = btnX + btnSize * 0.5

    if imgAnchor_ and imgAnchor_ > 0 then
        local ix = cx - iconSize * 0.5
        local iy = startY
        local pat = nvgImagePattern(nvg, ix, iy, iconSize, iconSize, 0, imgAnchor_, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, ix, iy, iconSize, iconSize)
        nvgFillPaint(nvg, pat)
        nvgFill(nvg)
    else
        UICore.strokeText(nvg, "⚓", cx, startY + iconSize * 0.5,
            18, UICore.C_TITLE, UICore.C_STROKE, 2,
            NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    end

    UICore.strokeText(nvg, "返回", cx, startY + iconSize + gap + labelH * 0.5,
        labelH, UICore.C_TITLE, UICore.C_STROKE, 2,
        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
end

-- ============================================================================
-- Layer 8.2: 右上角按钮 (背包 / 设置)
-- ============================================================================

---@param nvg any
---@param bx number 按钮左上角X
---@param by number 按钮左上角Y
---@param size number 按钮尺寸
---@param imgIcon any 图标句柄
local function drawSquareIconBtn(nvg, bx, by, size, imgIcon)
    local r = size * 0.22
    UICore.fillRRectGrad(nvg, bx, by, size, size, r,
        { 10, 50, 110 }, 210,
        {  6, 30,  80 }, 230)
    UICore.strokeRRect(nvg, bx, by, size, size, r, UICore.C_GEM, 1.2, 120)
    -- 图标居中
    if imgIcon and imgIcon > 0 then
        local iconSize = size * 0.58
        local ix = bx + (size - iconSize) * 0.5
        local iy = by + (size - iconSize) * 0.5
        local pat = nvgImagePattern(nvg, ix, iy, iconSize, iconSize, 0, imgIcon, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, ix, iy, iconSize, iconSize)
        nvgFillPaint(nvg, pat)
        nvgFill(nvg)
    end
end

function WaterScene.renderTopRightBtns(nvg, x, y, w, h)
    local btnSize = 36
    local margin = 10
    local gap = 8
    -- 设置按钮 (最右)
    local sx = x + w - btnSize - margin
    local sy = y + margin
    drawSquareIconBtn(nvg, sx, sy, btnSize, imgSettings_)
    -- 背包按钮 (设置左侧)
    local bx = sx - btnSize - gap
    drawSquareIconBtn(nvg, bx, sy, btnSize, imgBackpack_)
end

-- ============================================================================
-- Layer 8.15: 船只升级按钮 (返航按钮左侧, 卡片样式)
-- ============================================================================

function WaterScene.renderBoatUpgradeBtn(nvg, x, y, w, h)
    local boatLv = GameState.boatLevel or 1
    local boatCfg = GameConfig.BOAT

    -- 卡片尺寸: 左侧正方形图标区 + 右侧箭头区
    local cardH = 58
    local iconW = cardH          -- 左侧正方形
    local arrowW = cardH * 0.6   -- 右侧箭头区
    local cardW = iconW + arrowW
    local margin = 12
    local gap = 10

    -- 水平居中
    local cardX = x + (w - cardW) * 0.5
    local cardY = y + h - cardH - margin

    boatUpgBtnRect_.x = cardX
    boatUpgBtnRect_.y = cardY
    boatUpgBtnRect_.w = cardW
    boatUpgBtnRect_.h = cardH

    -- === 左侧: 暖黄色背景 + 船只图标 + 等级标签 ===
    local r = 8
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, cardX, cardY, iconW, cardH, r)
    nvgFillColor(nvg, nvgRGBA(245, 215, 130, 240))
    nvgFill(nvg)

    -- 船只图标
    if imgBoatIcon_ and imgBoatIcon_ > 0 then
        local icoSize = iconW * 0.65
        local ix = cardX + (iconW - icoSize) * 0.5
        local iy = cardY + (cardH - icoSize) * 0.5 - 4
        local pat = nvgImagePattern(nvg, ix, iy, icoSize, icoSize, 0, imgBoatIcon_, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, ix, iy, icoSize, icoSize)
        nvgFillPaint(nvg, pat)
        nvgFill(nvg)
    end

    -- 等级标签 (左下角)
    local lblW = 26
    local lblH = 16
    local lblX = cardX + 3
    local lblY = cardY + cardH - lblH - 3
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, lblX, lblY, lblW, lblH, 4)
    nvgFillColor(nvg, nvgRGBA(60, 60, 60, 200))
    nvgFill(nvg)
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 11)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 240))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(nvg, lblX + lblW * 0.5, lblY + lblH * 0.5, "L" .. boatLv)

    -- === 右侧: 浅灰色背景 + 升级箭头 ===
    local arrowX = cardX + iconW
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, arrowX, cardY, arrowW, cardH, r)
    nvgFillColor(nvg, nvgRGBA(235, 235, 240, 240))
    nvgFill(nvg)

    if imgUpgradeArrow_ and imgUpgradeArrow_ > 0 then
        local arrSize = arrowW * 0.6
        local ax = arrowX + (arrowW - arrSize) * 0.5
        local ay = cardY + (cardH - arrSize) * 0.5
        local pat = nvgImagePattern(nvg, ax, ay, arrSize, arrSize, 0, imgUpgradeArrow_, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, ax, ay, arrSize, arrSize)
        nvgFillPaint(nvg, pat)
        nvgFill(nvg)
    else
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 22)
        nvgFillColor(nvg, nvgRGBA(220, 120, 40, 240))
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgText(nvg, arrowX + arrowW * 0.5, cardY + cardH * 0.5, "⬆")
    end

    -- === 右上角等级徽章 (可升级时显示) ===
    if boatLv < boatCfg.MAX_LEVEL then
        local nextCost = boatCfg.LEVELS[boatLv + 1].cost
        if GameState.coins >= nextCost then
            local badgeR = 10
            local badgeCX = cardX + cardW - 2
            local badgeCY = cardY - 2
            nvgBeginPath(nvg)
            nvgCircle(nvg, badgeCX, badgeCY, badgeR)
            nvgFillColor(nvg, nvgRGBA(230, 80, 40, 255))
            nvgFill(nvg)
            nvgFontFace(nvg, "sans")
            nvgFontSize(nvg, 11)
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgText(nvg, badgeCX, badgeCY, "!")
        end
    end

    -- 整体卡片描边
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, cardX, cardY, cardW, cardH, r)
    nvgStrokeColor(nvg, nvgRGBA(180, 170, 150, 120))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)
end

-- ============================================================================
-- Layer 9: 升级弹窗 (渔船等级 + 4种装备)
-- ============================================================================

--- 懒加载装备图标
local function ensureEquipIcons(nvg)
    if equipIconsLoaded_ then return end
    equipIconsLoaded_ = true
    for _, eq in ipairs(GameConfig.EQUIP.LIST) do
        local img = nvgCreateImage(nvg, eq.icon, NVG_IMAGE_PREMULTIPLIED)
        equipIcons_[eq.id] = img
        if img and img > 0 then
            print("[UpgradePopup] 加载装备图标: " .. eq.id)
        end
    end
end

--- 绘制绿色进度条
local function drawProgressBar(nvg, px, py, pw, ph, current, max, radius)
    radius = radius or 4
    -- 底色 (暗绿/棕)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, px, py, pw, ph, radius)
    nvgFillColor(nvg, nvgRGBA(120, 100, 60, 180))
    nvgFill(nvg)
    -- 进度 (绿色渐变)
    local ratio = math.min(current / math.max(max, 1), 1.0)
    if ratio > 0 then
        local fillW = math.max(pw * ratio, ph)  -- 至少跟高度一样宽，避免圆角问题
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, px, py, fillW, ph, radius)
        local gp = nvgLinearGradient(nvg, px, py, px, py + ph,
            nvgRGBA(140, 200, 60, 255), nvgRGBA(100, 170, 40, 255))
        nvgFillPaint(nvg, gp)
        nvgFill(nvg)
    end
    -- 进度文字
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, ph * 0.75)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 240))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(nvg, px + pw * 0.5, py + ph * 0.5,
        string.format("%d/%d", current, max))
end

--- 绘制绿色升级按钮 (带金币图标)
local function drawUpgradeBtn(nvg, bx, by, bw, bh, cost, canAfford, coinImg)
    local r = 6
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, bx, by, bw, bh, r)
    if canAfford then
        local gp = nvgLinearGradient(nvg, bx, by, bx, by + bh,
            nvgRGBA(130, 200, 60, 255), nvgRGBA(100, 170, 40, 255))
        nvgFillPaint(nvg, gp)
    else
        nvgFillColor(nvg, nvgRGBA(160, 160, 160, 200))
    end
    nvgFill(nvg)
    -- 描边
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, bx, by, bw, bh, r)
    nvgStrokeColor(nvg, canAfford and nvgRGBA(80, 140, 30, 200) or nvgRGBA(120, 120, 120, 120))
    nvgStrokeWidth(nvg, 1.2)
    nvgStroke(nvg)
    -- 小绿色箭头(右上角)
    if canAfford then
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 10)
        nvgFillColor(nvg, nvgRGBA(60, 140, 30, 255))
        nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        nvgText(nvg, bx + bw - 3, by - 10, "▲")
    end
    -- 金币图标 + 费用文字
    local iconS = bh * 0.5
    local textStr = FormatUtils.formatNumber(cost)
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, bh * 0.38)
    local tw = nvgTextBounds(nvg, 0, 0, textStr)
    local totalW = iconS + 3 + tw
    local startX = bx + (bw - totalW) * 0.5
    -- 金币图标
    if coinImg and coinImg > 0 then
        local pat = nvgImagePattern(nvg, startX, by + (bh - iconS) * 0.5, iconS, iconS, 0, coinImg, 1.0)
        nvgBeginPath(nvg)
        nvgCircle(nvg, startX + iconS * 0.5, by + bh * 0.5, iconS * 0.5)
        nvgFillPaint(nvg, pat)
        nvgFill(nvg)
    else
        nvgBeginPath(nvg)
        nvgCircle(nvg, startX + iconS * 0.5, by + bh * 0.5, iconS * 0.45)
        nvgFillColor(nvg, nvgRGBA(255, 200, 50, 255))
        nvgFill(nvg)
    end
    -- 文字
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 250))
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgText(nvg, startX + iconS + 3, by + bh * 0.5, textStr)
end

function WaterScene.renderBoatUpgradePopup(nvg, x, y, w, h)
    if not showBoatUpgradePopup_ then return end
    ensureEquipIcons(nvg)

    local boatLv = GameState.boatLevel or 1
    local boatCfg = GameConfig.BOAT
    local curInfo = boatCfg.LEVELS[boatLv]
    local isBoatMax = (boatLv >= boatCfg.MAX_LEVEL)
    local equipCapLv = GameConfig.getEquipLevelCap(boatLv)

    -- ===== 动画进度 =====
    local t = UICore.easeOutCubic(boatUpgradePopupT_)
    local maskAlpha = math.floor(t * 150)

    -- 半透明遮罩
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillColor(nvg, nvgRGBA(0, 0, 10, maskAlpha))
    nvgFill(nvg)

    if t <= 0 then return end

    -- 弹窗尺寸
    local popW = math.min(w * 0.88, 320)
    local popH = math.min(h * 0.82, 520)
    local popCX = x + w * 0.5
    local popCY = y + h * 0.5
    local pad = 12

    -- 缩放动画变换
    local scale = 0.85 + 0.15 * t
    nvgGlobalAlpha(nvg, t)
    nvgSave(nvg)
    nvgTranslate(nvg, popCX, popCY)
    nvgScale(nvg, scale, scale)
    nvgTranslate(nvg, -popW * 0.5, -popH * 0.5)

    -- 以 (0, 0) 为左上角绘制弹窗
    local px, py = 0, 0
    local popR = 12
    local innerW = popW - pad * 2

    -- ===== 深海蓝面板 =====
    UICore.drawPanel(nvg, px, py, popW, popH, popR)

    -- ===== 标题栏 =====
    local titleBarH = UICore.drawPanelTitle(nvg, px, py, popW, "升级")

    -- ===== 关闭按钮 (右上角 X) =====
    local closeSize = 30
    local closeX = px + popW - closeSize - 2
    local closeY = py + 2
    -- 存储实际屏幕坐标 (变换后)
    boatUpgCloseRect_.x = popCX + (closeX - popW * 0.5) * scale
    boatUpgCloseRect_.y = popCY + (closeY - popH * 0.5) * scale
    boatUpgCloseRect_.w = closeSize * scale
    boatUpgCloseRect_.h = closeSize * scale
    -- X 圆形
    nvgBeginPath(nvg)
    nvgCircle(nvg, closeX + closeSize * 0.5, closeY + closeSize * 0.5, closeSize * 0.42)
    nvgFillColor(nvg, nvgRGBA(200, 70, 50, 230))
    nvgFill(nvg)
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 16)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 250))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(nvg, closeX + closeSize * 0.5, closeY + closeSize * 0.5, "✕")

    -- ===== 区域1: 渔船等级卡片 =====
    local secY = py + titleBarH + 4
    local boatCardH = 90
    local boatCardX = px + pad
    local boatCardY = secY

    UICore.fillRRectGrad(nvg, boatCardX, boatCardY, innerW, boatCardH, 8,
        {8, 30, 75}, 200, {5, 20, 55}, 220)
    UICore.strokeRRect(nvg, boatCardX, boatCardY, innerW, boatCardH, 8,
        UICore.C_GEM, 1.0, 80)

    -- "渔船等级" 标签
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 11)
    nvgFillColor(nvg, nvgRGBA(UICore.C_GEM[1], UICore.C_GEM[2], UICore.C_GEM[3], 200))
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgText(nvg, boatCardX + 10, boatCardY + 7, "渔船等级")

    -- 等级徽章 (宝石蓝圆)
    local badgeR = 16
    local badgeCX = boatCardX + 10 + badgeR
    local badgeCY = boatCardY + 28 + badgeR
    UICore.fillRRectGrad(nvg, badgeCX - badgeR, badgeCY - badgeR,
        badgeR * 2, badgeR * 2, badgeR,
        {30, 120, 220}, 255, {15, 80, 170}, 255)
    UICore.strokeRRect(nvg, badgeCX - badgeR, badgeCY - badgeR,
        badgeR * 2, badgeR * 2, badgeR, UICore.C_GEM, 1.5, 200)
    UICore.strokeText(nvg, tostring(boatLv),
        badgeCX, badgeCY, 15,
        UICore.C_TITLE, UICore.C_STROKE, 2,
        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- Lv.X 文字
    UICore.strokeText(nvg, "Lv." .. boatLv,
        badgeCX + badgeR + 6, badgeCY - 5, 13,
        UICore.C_GEM, UICore.C_STROKE, 1.5,
        NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)

    -- 进度条
    local leftW = innerW * 0.55
    local barX = badgeCX + badgeR + 6
    local barY = badgeCY + 9
    local barW = boatCardX + leftW - barX - 6
    local barH = 12
    if not isBoatMax then
        local nextCost = boatCfg.LEVELS[boatLv + 1].cost
        local progress = math.min(GameState.coins, nextCost)
        UICore.drawProgressBar(nvg, barX, barY, barW, barH, 4,
            progress / nextCost,
            {5, 20, 55}, 200, UICore.C_GEM, 220)
    else
        UICore.drawProgressBar(nvg, barX, barY, barW, barH, 4,
            1.0, {5, 20, 55}, 200, UICore.C_GEM, 220)
    end

    -- 提示文字
    UICore.strokeTextA(nvg,
        isBoatMax and "已达最高等级!" or "升级渔船可提升装备等级上限",
        boatCardX + 10, boatCardY + boatCardH - 11, 9,
        UICore.C_GEM, 170, UICore.C_STROKE, 1,
        NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)

    -- 右侧: 船只图片
    local boatImgSize = boatCardH - 16
    local boatImgX = boatCardX + leftW
    local boatImgY = boatCardY + 8
    if imgBoatIcon_ and imgBoatIcon_ > 0 then
        UICore.drawImageTL(nvg, imgBoatIcon_, boatImgX, boatImgY, boatImgSize, boatImgSize, 1.0)
    end

    -- 渔船升级按钮
    boatUpgConfirmRect_.x = 0; boatUpgConfirmRect_.y = 0
    boatUpgConfirmRect_.w = 0; boatUpgConfirmRect_.h = 0
    if not isBoatMax then
        local rightAreaW = innerW - leftW
        local bbW = rightAreaW - 8
        local bbH = 22
        local bbX = boatCardX + leftW + (rightAreaW - bbW) * 0.5
        local bbY = boatCardY + boatCardH - bbH - 4
        -- 存储实际屏幕坐标
        boatUpgConfirmRect_.x = popCX + (bbX - popW * 0.5) * scale
        boatUpgConfirmRect_.y = popCY + (bbY - popH * 0.5) * scale
        boatUpgConfirmRect_.w = bbW * scale
        boatUpgConfirmRect_.h = bbH * scale
        local nextCost = boatCfg.LEVELS[boatLv + 1].cost
        local canAfford = GameState.coins >= nextCost
        drawUpgradeBtn(nvg, bbX, bbY, bbW, bbH, nextCost, canAfford, imgCoin_)
    end

    -- ===== 分隔线: 装备升级 =====
    local divY = boatCardY + boatCardH + 8
    -- 渐变分隔线
    local divPaint = nvgLinearGradient(nvg,
        px + pad, divY, px + popW - pad, divY,
        nvgRGBA(UICore.C_GEM[1], UICore.C_GEM[2], UICore.C_GEM[3], 0),
        nvgRGBA(UICore.C_GEM[1], UICore.C_GEM[2], UICore.C_GEM[3], 100))
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, px + pad + 8, divY)
    nvgLineTo(nvg, px + popW - pad - 8, divY)
    nvgStrokePaint(nvg, divPaint)
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    UICore.strokeText(nvg, "装备升级",
        px + popW * 0.5, divY, 12,
        UICore.C_GEM, UICore.C_STROKE, 1.5,
        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- ===== 区域2: 4个装备行 =====
    local rowH = 68
    local rowGap = 5
    local rowStartY = divY + 14

    for idx, eq in ipairs(GameConfig.EQUIP.LIST) do
        local eqLv = GameState.equipLevels[eq.id] or 1
        local isEqMax = (eqLv >= equipCapLv)
        local upgCost = EconomySystem.calcEquipUpgradeCost(eq.id, eqLv)

        local rowY = rowStartY + (idx - 1) * (rowH + rowGap)
        local rowX = px + pad
        local rowW = innerW

        -- 行底色 (深蓝渐变卡片)
        UICore.fillRRectGrad(nvg, rowX, rowY, rowW, rowH, 8,
            {8, 35, 80}, 190, {5, 22, 58}, 210)
        UICore.strokeRRect(nvg, rowX, rowY, rowW, rowH, 8,
            UICore.C_GEM, 0.8, 60)

        -- 左侧: 装备图标 (深海蓝底圆角方块)
        local icoSize = rowH - 16
        local icoX = rowX + 8
        local icoY = rowY + (rowH - icoSize) * 0.5
        UICore.fillRRectGrad(nvg, icoX, icoY, icoSize, icoSize, 8,
            {15, 55, 120}, 200, {10, 38, 90}, 220)
        UICore.strokeRRect(nvg, icoX, icoY, icoSize, icoSize, 8,
            UICore.C_GEM, 1.0, 100)
        local eqImg = equipIcons_[eq.id]
        if eqImg and eqImg > 0 then
            local imgPad = 4
            UICore.drawImageTL(nvg, eqImg,
                icoX + imgPad, icoY + imgPad,
                icoSize - imgPad * 2, icoSize - imgPad * 2, 1.0)
        end

        -- 中间: 装备名 + 描述 + 等级 + 进度条
        local textX = icoX + icoSize + 8
        local midW = rowW * 0.35
        -- 装备名
        UICore.strokeText(nvg, eq.displayName,
            textX, rowY + 10, 13,
            UICore.C_TITLE, UICore.C_STROKE, 2,
            NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        -- 描述
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 9)
        nvgFillColor(nvg, nvgRGBA(UICore.C_GEM[1], UICore.C_GEM[2], UICore.C_GEM[3], 160))
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgText(nvg, textX, rowY + 26, eq.desc)

        -- 等级
        local lvX = textX + midW
        UICore.strokeText(nvg, "Lv." .. eqLv,
            lvX, rowY + 10, 13,
            UICore.C_GEM, UICore.C_STROKE, 1.5,
            NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

        -- 进度条
        local pBarX = textX
        local pBarY = rowY + rowH - 18
        local pBarW = lvX + 28 - textX
        local pBarH = 10
        UICore.drawProgressBar(nvg, pBarX, pBarY, pBarW, pBarH, 3,
            eqLv / math.max(1, equipCapLv),
            {5, 20, 55}, 180, UICore.C_GEM, 210)

        -- 右侧: 升级按钮
        local btnW = 64
        local btnH = 28
        local btnX = rowX + rowW - btnW - 8
        local btnY = rowY + (rowH - btnH) * 0.5

        equipUpgRects_[eq.id] = equipUpgRects_[eq.id] or { x = 0, y = 0, w = 0, h = 0 }

        if isEqMax then
            equipUpgRects_[eq.id].x = 0; equipUpgRects_[eq.id].y = 0
            equipUpgRects_[eq.id].w = 0; equipUpgRects_[eq.id].h = 0
            UICore.strokeTextA(nvg, "已满级",
                btnX + btnW * 0.5, btnY + btnH * 0.5, 11,
                UICore.C_GEM, 140, UICore.C_STROKE, 1,
                NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        else
            -- 存储实际屏幕坐标
            equipUpgRects_[eq.id].x = popCX + (btnX - popW * 0.5) * scale
            equipUpgRects_[eq.id].y = popCY + (btnY - popH * 0.5) * scale
            equipUpgRects_[eq.id].w = btnW * scale
            equipUpgRects_[eq.id].h = btnH * scale
            local canAfford = GameState.coins >= upgCost
            drawUpgradeBtn(nvg, btnX, btnY, btnW, btnH, upgCost, canAfford, imgCoin_)
        end
    end

    -- ===== 底部提示 =====
    local tipY = py + popH - 14
    UICore.strokeTextA(nvg, "升级装备可提升钓鱼效率，帮助你捕获更多高价值的鱼！",
        px + popW * 0.5, tipY, 9,
        UICore.C_GEM, 130, UICore.C_STROKE, 1,
        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    nvgRestore(nvg)
    nvgGlobalAlpha(nvg, 1.0)
end

--- 检测船只升级按钮是否被点击
---@return boolean
function WaterScene.isBoatUpgradeBtnClicked()
    if showBoatUpgradePopup_ then return false end
    if not input:GetMouseButtonPress(MOUSEB_LEFT) then return false end
    local dpr = graphics:GetDPR()
    local pos = input:GetMousePosition()
    local lx = pos.x / dpr
    local ly = pos.y / dpr
    local r = boatUpgBtnRect_
    return lx >= r.x and lx <= r.x + r.w
       and ly >= r.y and ly <= r.y + r.h
end

--- 打开升级弹窗
function WaterScene.openBoatUpgradePopup()
    showBoatUpgradePopup_ = true
end

--- 处理弹窗内点击 (关闭/渔船升级/装备升级)
---@return string|nil action "close"|"upgrade"|nil
function WaterScene.handleBoatUpgradePopupInput()
    if not showBoatUpgradePopup_ then return nil end
    if not input:GetMouseButtonPress(MOUSEB_LEFT) then return nil end

    local dpr = graphics:GetDPR()
    local pos = input:GetMousePosition()
    local lx = pos.x / dpr
    local ly = pos.y / dpr

    -- 检测关闭按钮
    local c = boatUpgCloseRect_
    if lx >= c.x and lx <= c.x + c.w and ly >= c.y and ly <= c.y + c.h then
        showBoatUpgradePopup_ = false
        return "close"
    end

    -- 检测渔船升级按钮
    local u = boatUpgConfirmRect_
    if u.w > 0 and lx >= u.x and lx <= u.x + u.w and ly >= u.y and ly <= u.y + u.h then
        local boatLv = GameState.boatLevel or 1
        local boatCfg = GameConfig.BOAT
        if boatLv < boatCfg.MAX_LEVEL then
            local nextCost = boatCfg.LEVELS[boatLv + 1].cost
            if GameState:spendCoins(nextCost) then
                GameState.boatLevel = boatLv + 1
                print(string.format("[BoatUpgrade] 渔船升级到 Lv.%d: %s",
                    GameState.boatLevel, boatCfg.LEVELS[GameState.boatLevel].desc))
            else
                print("[BoatUpgrade] 金币不足")
            end
        end
        return "upgrade"
    end

    -- 检测4个装备升级按钮
    for _, eq in ipairs(GameConfig.EQUIP.LIST) do
        local r = equipUpgRects_[eq.id]
        if r and r.w > 0 and lx >= r.x and lx <= r.x + r.w and ly >= r.y and ly <= r.y + r.h then
            local eqLv = GameState.equipLevels[eq.id] or 1
            local capLv = GameConfig.getEquipLevelCap(GameState.boatLevel or 1)
            if eqLv < capLv then
                local cost = EconomySystem.calcEquipUpgradeCost(eq.id, eqLv)
                if GameState:spendCoins(cost) then
                    GameState.equipLevels[eq.id] = eqLv + 1
                    print(string.format("[EquipUpgrade] %s 升级到 Lv.%d",
                        eq.displayName, eqLv + 1))
                else
                    print(string.format("[EquipUpgrade] %s 金币不足", eq.displayName))
                end
            end
            return "upgrade"
        end
    end

    -- 点击弹窗外区域关闭 — 检测是否点在弹窗内部
    -- 弹窗区域由渲染时的 popX/popY/popW/popH 确定，这里简单用遮罩关闭
    showBoatUpgradePopup_ = false
    return "close"
end

--- 弹窗是否打开
function WaterScene.isBoatUpgradePopupOpen()
    return showBoatUpgradePopup_
end

-- ============================================================================
-- Layer 4.5: 鱼线落水波纹 (水面上, 船影下方)
-- ============================================================================

--- 更新鱼线落水波纹 (持续在落水点生成同心圆)
function WaterScene.updateLineRipples(dt)
    local bs = boatState_
    if bs.drawW == 0 then return end

    -- 更新现有波纹
    local i = 1
    while i <= #lineRipples_ do
        lineRipples_[i].age = lineRipples_[i].age + dt
        if lineRipples_[i].age >= lineRipples_[i].maxAge then
            table.remove(lineRipples_, i)
        else
            i = i + 1
        end
    end

    -- 为每根鱼竿的落水点持续生成波纹 (交替生成, 每0.8s一根)
    -- 只为激活的鱼竿 (已雇佣船员) 生成落水波纹
    local activeRods = getActiveRodCount()
    for idx = 1, activeRods do
        local rod = RODS[idx]
        -- 每根竿子独立计时, 通过 phase 错开
        local rodTimer = (time_ + rod.phase * 0.8) % 1.2
        if rodTimer < dt * 1.5 then  -- 刚过周期起点时生成
            -- 计算落水点 (屏幕坐标)
            local rodLen = ROD_LENGTH * bs.drawW
            local lineLen = rod.lineLen * rodLen

            -- 竿尖 (船体坐标系)
            local tipX, tipY = calcRodTip(rod, bs)
            -- 鱼线末端 (从竿尖向外+向下延伸)
            local lineDirX = rod.side
            local endX = tipX + lineDirX * lineLen * 0.3
            local endY = tipY + lineLen * 0.5

            -- 转换到屏幕坐标
            local cr = math.cos(bs.rot)
            local sr = math.sin(bs.rot)
            local sx = (endX * cr - endY * sr) + bs.cx + bs.swayX
            local sy = (endX * sr + endY * cr) + bs.cy + bs.bobY

            table.insert(lineRipples_, {
                x = sx, y = sy,
                age = 0,
                maxAge = 2.0 + math.random() * 0.5,
                startR = 2,
                endR = 14 + math.random() * 6,
            })
        end
    end

    -- 限制最大波纹数
    while #lineRipples_ > 16 do
        table.remove(lineRipples_, 1)
    end
end

--- 渲染鱼线落水波纹
function WaterScene.renderLineRipples(nvg, x, y, w, h)
    if #lineRipples_ == 0 then return end

    nvgSave(nvg)
    for _, r in ipairs(lineRipples_) do
        local progress = r.age / r.maxAge
        local radius = r.startR + (r.endR - r.startR) * progress
        -- 透明度: 淡入后淡出
        local alpha
        if progress < 0.1 then
            alpha = progress / 0.1 * 0.3
        else
            alpha = 0.3 * (1.0 - (progress - 0.1) / 0.9)
        end
        alpha = alpha * alpha  -- ease-out

        if alpha < 0.005 then goto continue end

        nvgBeginPath(nvg)
        nvgCircle(nvg, r.x, r.y, radius)
        nvgStrokeColor(nvg, nvgRGBA(200, 230, 255, math.floor(alpha * 255)))
        nvgStrokeWidth(nvg, 0.8 + (1.0 - progress) * 0.6)
        nvgStroke(nvg)

        -- 第二圈 (稍小, 更淡)
        if radius > 5 then
            nvgBeginPath(nvg)
            nvgCircle(nvg, r.x, r.y, radius * 0.55)
            nvgStrokeColor(nvg, nvgRGBA(220, 240, 255, math.floor(alpha * 0.5 * 255)))
            nvgStrokeWidth(nvg, 0.5 + (1.0 - progress) * 0.4)
            nvgStroke(nvg)
        end

        ::continue::
    end
    nvgRestore(nvg)
end

-- ============================================================================
-- Layer 7.02: 鱼竿 + 鱼线 (船体上方)
-- ============================================================================

--- 渲染鱼竿 (贴图) 和鱼线 (贝塞尔曲线), 数量 = 已雇佣船员数
function WaterScene.renderFishingRods(nvg, x, y, w, h)
    local bs = boatState_
    if bs.drawW == 0 then return end

    local activeRods = getActiveRodCount()
    if activeRods == 0 then return end

    local hasRodImg = imgRod_ and imgRod_ > 0
    local rodLen = ROD_LENGTH * bs.drawW
    local imgAspect = (rodImgW_ > 0 and rodImgH_ > 0) and (rodImgH_ / rodImgW_) or 1.0

    nvgSave(nvg)
    -- 变换到船体坐标系
    nvgTranslate(nvg, bs.cx + bs.swayX, bs.cy + bs.bobY)
    nvgRotate(nvg, bs.rot)

    for idx = 1, activeRods do
        local rod = RODS[idx]
        -- 竿根位置 (船边缘)
        local baseX = rod.ox * bs.drawW
        local baseY = rod.oy * bs.drawH

        -- 竿尖位置: 向 side 方向水平外伸 + 向上 35°
        local tipX, tipY = calcRodTip(rod, bs)

        -- ---- 绘制鱼竿 (图片) ----
        if hasRodImg then
            local imgW = ROD_IMG_SCALE * bs.drawW
            local imgH = imgW * imgAspect

            nvgSave(nvg)
            nvgTranslate(nvg, baseX, baseY)

            -- 图片原始: 手柄左→竿尖右, 约15°仰角
            -- 目标: 竿尖向上倾斜 ROD_TILT_DEG(35°)
            -- 右侧(side=+1): 直接旋转 -(35-15)° = -20° 使竿尖从15°上升到35°
            -- 左侧(side=-1): 先水平翻转 nvgScale(-1,1), 再同样旋转
            if rod.side < 0 then
                nvgScale(nvg, -1, 1)  -- 水平镜像: 手柄右→竿尖左
            end
            -- 旋转补偿: 从图片自带的15°仰角 → 目标35°
            nvgRotate(nvg, -(ROD_TILT_RAD + ROD_IMG_ANGLE_OFFSET))

            -- 图片绘制: 手柄端在原点附近 (左侧15%为手柄区, 垂直居中)
            local anchorX = -imgW * 0.15
            local anchorY = -imgH * 0.5
            local pat = nvgImagePattern(nvg,
                anchorX, anchorY,
                imgW, imgH, 0, imgRod_, 1.0)
            nvgBeginPath(nvg)
            nvgRect(nvg, anchorX, anchorY, imgW, imgH)
            nvgFillPaint(nvg, pat)
            nvgFill(nvg)

            -- 调试框
            if DEBUG_ROD then
                nvgBeginPath(nvg)
                nvgRect(nvg, anchorX, anchorY, imgW, imgH)
                nvgStrokeColor(nvg, nvgRGBA(0, 255, 0, 180))
                nvgStrokeWidth(nvg, 1.0)
                nvgStroke(nvg)
            end

            nvgRestore(nvg)
        end

        -- ---- 绘制鱼线 (从竿尖到水面, 贝塞尔曲线 + 晃动) ----
        local lineLen = rod.lineLen * rodLen

        -- 鱼线末端: 从竿尖继续向外+向下延伸
        local lineDirX = rod.side  -- 水平方向 (左/右)
        local lineDirY = 1.0       -- 向下 (鱼线自然下垂到水面)
        local endX = tipX + lineDirX * lineLen * 0.3
        local endY = tipY + lineDirY * lineLen * 0.5

        -- 晃动
        local swayFreq1 = 1.8 + idx * 0.3
        local swayFreq2 = 2.3 + idx * 0.2
        local swayAmp = lineLen * 0.08 * waveIntensity_
        local sway1 = math.sin(time_ * swayFreq1 + rod.phase) * swayAmp
        local sway2 = math.sin(time_ * swayFreq2 + rod.phase + 1.5) * swayAmp * 0.7

        -- 控制点 (自然垂弧 + 摆动)
        local cp1X = tipX + lineDirX * lineLen * 0.1 + sway1
        local cp1Y = tipY + lineLen * 0.15 + math.abs(sway1) * 0.3
        local cp2X = tipX + lineDirX * lineLen * 0.2 + sway2
        local cp2Y = tipY + lineLen * 0.35

        nvgBeginPath(nvg)
        nvgMoveTo(nvg, tipX, tipY)
        nvgBezierTo(nvg, cp1X, cp1Y, cp2X, cp2Y, endX, endY)
        nvgStrokeColor(nvg, nvgRGBA(60, 60, 60, 140))
        nvgStrokeWidth(nvg, 0.8)
        nvgStroke(nvg)

        -- 鱼线末端小浮标 (红白圆点)
        nvgBeginPath(nvg)
        nvgCircle(nvg, endX, endY, 2.5)
        nvgFillColor(nvg, nvgRGBA(220, 50, 30, 200))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgCircle(nvg, endX, endY, 1.2)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 220))
        nvgFill(nvg)

        -- 调试: 竿根红点 + 竿尖蓝点
        if DEBUG_ROD then
            nvgBeginPath(nvg)
            nvgCircle(nvg, baseX, baseY, 4)
            nvgFillColor(nvg, nvgRGBA(255, 0, 0, 200))
            nvgFill(nvg)

            nvgBeginPath(nvg)
            nvgCircle(nvg, tipX, tipY, 3)
            nvgFillColor(nvg, nvgRGBA(0, 100, 255, 200))
            nvgFill(nvg)
        end
    end

    nvgRestore(nvg)

    -- 调试信息面板 (屏幕坐标, 在船体变换之外)
    if DEBUG_ROD then
        WaterScene.renderRodDebugInfo(nvg, x, y, w, h)
    end
end

--- 渲染鱼竿调试信息面板 (屏幕中部, 避免被上下 UI 遮挡)
function WaterScene.renderRodDebugInfo(nvg, x, y, w, h)
    local panelH = 90
    local panelY = y + (h - panelH) * 0.5  -- 屏幕垂直居中
    nvgBeginPath(nvg)
    nvgRect(nvg, x, panelY, w, panelH)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 180))
    nvgFill(nvg)

    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 11)
    nvgFillColor(nvg, nvgRGBA(0, 255, 0, 255))
    nvgTextAlign(nvg, NVG_ALIGN_LEFT | NVG_ALIGN_TOP)

    local ly = panelY + 4
    for idx, rod in ipairs(RODS) do
        local label = string.format("Rod%d: ox=%.3f oy=%.3f side=%d",
            idx, rod.ox, rod.oy, rod.side)
        local mark = (debugRodIdx_ == idx) and " [DRAG]" or ""
        nvgText(nvg, x + 6, ly, label .. mark)
        ly = ly + 14
    end
    nvgText(nvg, x + 6, ly, string.format("TILT=%d°  ROD_LEN=%.2f  IMG_SCALE=%.2f",
        ROD_TILT_DEG, ROD_LENGTH, ROD_IMG_SCALE))
end

--- 鱼竿拖拽调试 (每帧调用)
function WaterScene.updateRodDrag()
    if not DEBUG_ROD then return end

    local bs = boatState_
    if bs.drawW == 0 then return end

    local dpr = graphics:GetDPR()
    local mx = input.mousePosition.x / dpr
    local my = input.mousePosition.y / dpr
    local pressed = input:GetMouseButtonPress(MOUSEB_LEFT)
    local down    = input:GetMouseButtonDown(MOUSEB_LEFT)

    if pressed then
        -- 将鼠标坐标转换到船体本地坐标
        local localX = mx - (bs.cx + bs.swayX)
        local localY = my - (bs.cy + bs.bobY)
        -- 逆旋转
        local cr = math.cos(-bs.rot)
        local sr = math.sin(-bs.rot)
        local lx = localX * cr - localY * sr
        local ly = localX * sr + localY * cr

        -- 命中检测: 找最近的竿根
        local hitR = 20  -- 命中半径
        for idx, rod in ipairs(RODS) do
            local rx = rod.ox * bs.drawW
            local ry = rod.oy * bs.drawH
            local dx = lx - rx
            local dy = ly - ry
            if dx * dx + dy * dy < hitR * hitR then
                debugRodIdx_ = idx
                debugRodOffX_ = rod.ox - lx / bs.drawW
                debugRodOffY_ = rod.oy - ly / bs.drawH
                break
            end
        end
    elseif down and debugRodIdx_ then
        -- 拖拽中: 更新位置
        local localX = mx - (bs.cx + bs.swayX)
        local localY = my - (bs.cy + bs.bobY)
        local cr = math.cos(-bs.rot)
        local sr = math.sin(-bs.rot)
        local lx = localX * cr - localY * sr
        local ly = localX * sr + localY * cr

        RODS[debugRodIdx_].ox = lx / bs.drawW + debugRodOffX_
        RODS[debugRodIdx_].oy = ly / bs.drawH + debugRodOffY_
    else
        -- 松手: 打印最终结果
        if debugRodIdx_ then
            print("======== ROD DEBUG RESULT ========")
            for idx, rod in ipairs(RODS) do
                print(string.format("  Rod%d: ox=%.3f, oy=%.3f, side=%d", idx, rod.ox, rod.oy, rod.side))
            end
            print("==================================")
            debugRodIdx_ = nil
        end
    end
end

-- ============================================================================
-- Layer 7: 船体 (居中, 浮动, 微旋转)
-- ============================================================================

function WaterScene.renderBoatBase(nvg, x, y, w, h)
    if not imgBoatBase_ or imgBoatBase_ <= 0 then return end

    local bs = boatState_

    nvgSave(nvg)
    nvgTranslate(nvg, bs.cx + bs.swayX, bs.cy + bs.bobY)
    nvgRotate(nvg, bs.rot)

    local pat = nvgImagePattern(nvg,
        -bs.drawW * 0.5, -bs.drawH * 0.5,
        bs.drawW, bs.drawH, 0, imgBoatBase_, 1.0)
    nvgBeginPath(nvg)
    nvgRect(nvg, -bs.drawW * 0.5, -bs.drawH * 0.5, bs.drawW, bs.drawH)
    nvgFillPaint(nvg, pat)
    nvgFill(nvg)

    nvgRestore(nvg)
end

-- ============================================================================
-- Layer 7.05: Cat — 船上的猫咪
-- ============================================================================
function WaterScene.renderCat(nvg, x, y, w, h)
    if not imgCat_ or imgCat_ <= 0 then return end
    if catW_ < 1 or catH_ < 1 then return end

    local bs = boatState_
    local catSize = bs.drawW * catScale_
    local catDrawH = catSize * (catH_ / catW_)

    local localX = catOffsetX_ * bs.drawW
    local localY = catOffsetY_ * bs.drawH

    nvgSave(nvg)
    nvgTranslate(nvg, bs.cx + bs.swayX, bs.cy + bs.bobY)
    nvgRotate(nvg, bs.rot)

    local pat = nvgImagePattern(nvg,
        localX - catSize * 0.5, localY - catDrawH * 0.5,
        catSize, catDrawH, 0, imgCat_, 1.0)
    nvgBeginPath(nvg)
    nvgRect(nvg, localX - catSize * 0.5, localY - catDrawH * 0.5, catSize, catDrawH)
    nvgFillPaint(nvg, pat)
    nvgFill(nvg)

    -- 调试边框 + 角标
    if CAT_DEBUG then
        local lx = localX - catSize * 0.5
        local ly = localY - catDrawH * 0.5
        nvgBeginPath(nvg)
        nvgRect(nvg, lx, ly, catSize, catDrawH)
        nvgStrokeColor(nvg, nvgRGBA(0, 255, 0, 180))
        nvgStrokeWidth(nvg, 2)
        nvgStroke(nvg)

        -- 四角缩放手柄
        local cr = 6
        local corners = {
            { lx,             ly },
            { lx + catSize,   ly },
            { lx,             ly + catDrawH },
            { lx + catSize,   ly + catDrawH },
        }
        for _, c in ipairs(corners) do
            nvgBeginPath(nvg)
            nvgCircle(nvg, c[1], c[2], cr)
            nvgFillColor(nvg, nvgRGBA(0, 255, 0, 220))
            nvgFill(nvg)
        end
    end

    nvgRestore(nvg)

    -- 调试 HUD (屏幕空间)
    if CAT_DEBUG then
        local dpr = graphics:GetDPR()
        local sw = graphics:GetWidth() / dpr
        local hudY = 60
        nvgSave(nvg)
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 14)
        nvgFillColor(nvg, nvgRGBA(0, 255, 0, 255))
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        local info = string.format(
            "[Cat] offX=%.3f offY=%.3f scale=%.3f | size: %dx%d | drag: %s",
            catOffsetX_, catOffsetY_, catScale_,
            math.floor(catSize), math.floor(catDrawH),
            catDragMode_ or "idle")
        nvgText(nvg, 8, hudY, info)
        nvgRestore(nvg)
    end
end

--- 猫咪拖拽更新 (调试模式)
function WaterScene.updateCatDrag(dt)
    if not CAT_DEBUG then return false end
    local bs = boatState_
    if bs.drawW == 0 then return false end

    local dpr = graphics:GetDPR()
    local pressing = false
    local rawX, rawY = 0, 0

    if input:GetNumTouches() > 0 then
        local touch = input:GetTouch(0)
        pressing = true
        rawX = touch.position.x
        rawY = touch.position.y
    elseif input:GetMouseButtonDown(MOUSEB_LEFT) then
        pressing = true
        local pos = input:GetMousePosition()
        rawX = pos.x
        rawY = pos.y
    end

    local logX = rawX / dpr
    local logY = rawY / dpr

    -- 猫咪在屏幕上的中心坐标
    local catSize = bs.drawW * catScale_
    local catDrawH = catSize * (catH_ / catW_)
    local localX = catOffsetX_ * bs.drawW
    local localY = catOffsetY_ * bs.drawH
    local cosR = math.cos(bs.rot)
    local sinR = math.sin(bs.rot)
    local rx = localX * cosR - localY * sinR
    local ry = localX * sinR + localY * cosR
    local screenCX = bs.cx + bs.swayX + rx
    local screenCY = bs.cy + bs.bobY + ry

    if pressing then
        if not catDragMode_ then
            -- 检测四角缩放
            local halfW = catSize * 0.5
            local halfH = catDrawH * 0.5
            local corners = {
                { screenCX - halfW, screenCY - halfH },
                { screenCX + halfW, screenCY - halfH },
                { screenCX - halfW, screenCY + halfH },
                { screenCX + halfW, screenCY + halfH },
            }
            local cornerHit = 20
            for i, c in ipairs(corners) do
                local dx = logX - c[1]
                local dy = logY - c[2]
                if dx * dx + dy * dy <= cornerHit * cornerHit then
                    catDragMode_ = "scale"
                    catCornerIdx_ = i
                    catDragStartX_ = logX
                    catDragStartY_ = logY
                    catDragInitS_ = catScale_
                    break
                end
            end
            -- 检测中心拖拽
            if not catDragMode_ then
                local dx = logX - screenCX
                local dy = logY - screenCY
                local hitR = math.max(catSize, catDrawH) * 0.6
                if dx * dx + dy * dy <= hitR * hitR then
                    catDragMode_ = "move"
                    catDragStartX_ = logX
                    catDragStartY_ = logY
                    catDragInitOX_ = catOffsetX_
                    catDragInitOY_ = catOffsetY_
                end
            end
        end

        if catDragMode_ == "move" then
            local dx = logX - catDragStartX_
            local dy = logY - catDragStartY_
            -- 反旋转到船局部坐标
            local cosR2 = math.cos(-bs.rot)
            local sinR2 = math.sin(-bs.rot)
            local ldx = dx * cosR2 - dy * sinR2
            local ldy = dx * sinR2 + dy * cosR2
            catOffsetX_ = catDragInitOX_ + ldx / bs.drawW
            catOffsetY_ = catDragInitOY_ + ldy / bs.drawH
        elseif catDragMode_ == "scale" then
            local dy = logY - catDragStartY_
            catScale_ = math.max(0.05, catDragInitS_ - dy * 0.002)
        end
    else
        if catDragMode_ then
            print(string.format("[Cat] offX=%.3f offY=%.3f scale=%.3f",
                catOffsetX_, catOffsetY_, catScale_))
            catDragMode_ = nil
        end
    end

    return catDragMode_ ~= nil
end

-- ============================================================================
-- 水桶拖拽逻辑 (调试模式)
-- ============================================================================

--- 计算水桶在屏幕上的中心坐标 (考虑船体平移+旋转)
local function calcBucketScreenPos()
    local bs = boatState_
    -- 船体局部偏移
    local localX = bucketOffsetX_ * bs.drawW
    local localY = bucketOffsetY_ * bs.drawH
    -- 旋转后的偏移
    local cosR = math.cos(bs.rot)
    local sinR = math.sin(bs.rot)
    local rx = localX * cosR - localY * sinR
    local ry = localX * sinR + localY * cosR
    -- 加上船体世界位置 (含浮动)
    return bs.cx + bs.swayX + rx, bs.cy + bs.bobY + ry
end

function WaterScene.updateBucketDrag(dt)
    local bs = boatState_
    if bs.drawW == 0 then return end

    -- 获取逻辑坐标输入
    local dpr = graphics:GetDPR()
    local pressing = false
    local rawX, rawY = 0, 0

    if input:GetNumTouches() > 0 then
        local touch = input:GetTouch(0)
        pressing = true
        rawX = touch.position.x
        rawY = touch.position.y
    elseif input:GetMouseButtonDown(MOUSEB_LEFT) then
        pressing = true
        local pos = input:GetMousePosition()
        rawX = pos.x
        rawY = pos.y
    end

    local logX = rawX / dpr
    local logY = rawY / dpr

    -- 计算水桶屏幕位置
    local bsx, bsy = calcBucketScreenPos()
    bucketScreenX_ = bsx
    bucketScreenY_ = bsy

    -- 命中检测半径 (水桶大小的一半 + 余量)
    local hitR = bs.drawW * bucketScale_ * 0.6

    if pressing then
        if not bucketDragging_ then
            -- 检测点击是否命中水桶
            local dx = logX - bsx
            local dy = logY - bsy
            if dx * dx + dy * dy <= hitR * hitR then
                bucketDragging_ = true
            end
        end

        if bucketDragging_ then
            -- 将屏幕坐标转换回船体局部坐标
            -- 1. 减去船体世界位置
            local relX = logX - (bs.cx + bs.swayX)
            local relY = logY - (bs.cy + bs.bobY)
            -- 2. 反旋转
            local cosR = math.cos(-bs.rot)
            local sinR = math.sin(-bs.rot)
            local localX = relX * cosR - relY * sinR
            local localY = relX * sinR + relY * cosR
            -- 3. 转为比例
            bucketOffsetX_ = localX / bs.drawW
            bucketOffsetY_ = localY / bs.drawH
        end
    else
        if bucketDragging_ then
            -- 松手: 打印最终坐标
            print(string.format("[BucketDebug] 最终位置 offX=%.3f offY=%.3f scale=%.3f",
                bucketOffsetX_, bucketOffsetY_, bucketScale_))
            bucketDragging_ = false
        end
    end
end

--- 是否正在拖拽水桶 (供外部系统查询, 避免与 SwipeSystem 冲突)
---@return boolean
function WaterScene.isBucketDragging()
    return BUCKET_DEBUG and bucketDragging_
end

--- 获取水桶屏幕中心坐标 (捕获动画目标点)
---@return number x, number y
function WaterScene.getBucketCenter()
    return calcBucketScreenPos()
end

--- 获取鱼种单独图片信息 (捕获动画用)
---@param fishName string 鱼种名称 (如 "sardine", "clownfish")
---@return table|nil  { img=handle, w=N, h=N } 或 nil
function WaterScene.getFishImage(fishName)
    return fishImages_[fishName]
end

-- ============================================================================
-- Layer 7.1: 水桶 (跟随船体晃动, 调试模式显示十字线)
-- ============================================================================

function WaterScene.renderBucket(nvg, x, y, w, h)
    if not imgBucket_ or imgBucket_ <= 0 then return end

    local bs = boatState_

    -- 水桶尺寸
    local bkSize = bs.drawW * bucketScale_
    local bkDrawW = bkSize
    local bkDrawH = bkSize * (bucketH_ / bucketW_)

    -- 水桶在船体局部坐标的偏移 (相对船中心)
    local localX = bucketOffsetX_ * bs.drawW
    local localY = bucketOffsetY_ * bs.drawH

    nvgSave(nvg)
    -- 跟随船体: 先平移到船中心, 再旋转, 再偏移到水桶位置
    nvgTranslate(nvg, bs.cx + bs.swayX, bs.cy + bs.bobY)
    nvgRotate(nvg, bs.rot)
    nvgTranslate(nvg, localX, localY)

    -- 绘制水桶
    local pat = nvgImagePattern(nvg,
        -bkDrawW * 0.5, -bkDrawH * 0.5,
        bkDrawW, bkDrawH, 0, imgBucket_, 1.0)
    nvgBeginPath(nvg)
    nvgRect(nvg, -bkDrawW * 0.5, -bkDrawH * 0.5, bkDrawW, bkDrawH)
    nvgFillPaint(nvg, pat)
    nvgFill(nvg)

    -- 调试模式: 十字线 + 坐标文字 + 拖拽高亮
    if BUCKET_DEBUG then
        -- 拖拽时: 绿色高亮边框
        if bucketDragging_ then
            nvgBeginPath(nvg)
            nvgRect(nvg, -bkDrawW * 0.5 - 2, -bkDrawH * 0.5 - 2, bkDrawW + 4, bkDrawH + 4)
            nvgStrokeColor(nvg, nvgRGBA(0, 255, 100, 200))
            nvgStrokeWidth(nvg, 2)
            nvgStroke(nvg)
        end

        -- 红色十字线
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, -15, 0)
        nvgLineTo(nvg, 15, 0)
        nvgMoveTo(nvg, 0, -15)
        nvgLineTo(nvg, 0, 15)
        nvgStrokeColor(nvg, nvgRGBA(255, 50, 50, 200))
        nvgStrokeWidth(nvg, 2)
        nvgStroke(nvg)

        -- 坐标文字
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 12)
        nvgTextAlign(nvg, NVG_ALIGN_LEFT | NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(255, 255, 0, 230))
        local info = string.format("offX=%.2f offY=%.2f scale=%.2f",
            bucketOffsetX_, bucketOffsetY_, bucketScale_)
        nvgText(nvg, 10, -20, info)

        -- 拖拽状态提示
        if bucketDragging_ then
            nvgFillColor(nvg, nvgRGBA(0, 255, 100, 230))
            nvgText(nvg, 10, -6, "拖拽中...")
        end
    end

    nvgRestore(nvg)
end

-- ============================================================================
-- 返航按钮点击检测
-- ============================================================================

--- 检测返航按钮是否被点击
---@return boolean
function WaterScene.isReturnBtnClicked()
    if not input:GetMouseButtonPress(MOUSEB_LEFT) then
        return false
    end
    local dpr = graphics:GetDPR()
    local pos = input:GetMousePosition()
    local logX = pos.x / dpr
    local logY = pos.y / dpr
    local r = returnBtnRect_
    return logX >= r.x and logX <= r.x + r.w
       and logY >= r.y and logY <= r.y + r.h
end

--- 获取当前所有 UI 可交互区域 (调试模式用)
--- @return table[] { {name=string, x=number, y=number, w=number, h=number}, ... }
--- 获取 UI 界面分组列表 (层级结构, 编辑器用)
--- @param filterName string|nil  如果传入名称，只返回包含该名称的组
--- @return table[] groups  每个 group = { name, nodeType, x, y, w, h, style, children[] }
function WaterScene.getUIRegions(filterName)
    local physW = graphics:GetWidth()
    local physH = graphics:GetHeight()
    local dpr   = graphics:GetDPR()
    local logW  = physW / dpr
    local logH  = physH / dpr

    local groups = {}

    -- ====== 组1: 钓鱼HUD (常驻底部按钮) ======
    local hudChildren = {}
    local r = returnBtnRect_
    if r.w > 0 then
        table.insert(hudChildren, {
            name = "返航按钮", x = r.x, y = r.y, w = r.w, h = r.h,
            nodeType = "button",
            bg_image = "image/button_square_depth_line.png",
            bg_color = "#DCDCe6C8", corner_radius = 5,
            text = "返航", font_size = 11,
        })
    end
    r = boatUpgBtnRect_
    if r.w > 0 then
        table.insert(hudChildren, {
            name = "船只升级", x = r.x, y = r.y, w = r.w, h = r.h,
            nodeType = "button",
            bg_image = "image/icon_boat_upgrade_20260428113157.png",
            bg_color = "#F5D782F0", corner_radius = 8,
            text = "升级", font_size = 11,
        })
    end
    if #hudChildren > 0 then
        table.insert(groups, {
            name = "钓鱼HUD",
            nodeType = "panel",
            x = 0, y = 0, w = logW, h = logH,
            bg_color = "#00000000", corner_radius = 0,
            children = hudChildren,
        })
    end

    -- ====== 组2: 船只升级弹窗 (仅弹窗打开时) ======
    if showBoatUpgradePopup_ then
        local popW = math.min(logW * 0.88, 320)
        local popH = math.min(logH * 0.82, 520)
        local popX = (logW - popW) * 0.5
        local popY = (logH - popH) * 0.5

        local popChildren = {}
        r = boatUpgCloseRect_
        if r.w > 0 then
            table.insert(popChildren, {
                name = "弹窗关闭", x = r.x - popX, y = r.y - popY, w = r.w, h = r.h,
                nodeType = "button",
                bg_color = "#C83232E6", corner_radius = 12,
                text = "×", font_size = 16,
            })
        end
        r = boatUpgConfirmRect_
        if r.w > 0 then
            table.insert(popChildren, {
                name = "升级确认", x = r.x - popX, y = r.y - popY, w = r.w, h = r.h,
                nodeType = "button",
                bg_image = "image/button_rectangle_depth_line.png",
                bg_color = "#4A90D9FF", corner_radius = 6,
                text = "升级", font_size = 14,
            })
        end
        for eqId, eqR in pairs(equipUpgRects_) do
            if eqR.w > 0 then
                table.insert(popChildren, {
                    name = "装备升级:" .. eqId,
                    x = eqR.x - popX, y = eqR.y - popY, w = eqR.w, h = eqR.h,
                    nodeType = "button",
                    bg_image = "image/icon_upgrade_arrow_20260428113242.png",
                    bg_color = "#3A7A3AFF", corner_radius = 6,
                    text = "升级", font_size = 11,
                })
            end
        end
        table.insert(groups, {
            name = "船只升级弹窗",
            nodeType = "panel",
            x = popX, y = popY, w = popW, h = popH,
            bg_color = "#FCF8EBF0", corner_radius = 12,
            children = popChildren,
        })
    end

    -- 按名称过滤: 匹配组名或子元素名
    if filterName then
        for _, g in ipairs(groups) do
            if g.name == filterName then return { g } end
            for _, c in ipairs(g.children or {}) do
                if c.name == filterName then return { g } end
            end
        end
        return {}  -- 没找到匹配
    end

    return groups
end

-- ============================================================================
-- Layer 8.3: 鱼饵按钮 (左下角, 码头上方)
-- ============================================================================

function WaterScene.renderBaitBtn(nvg, x, y, w, h)
    local btnW = 52
    local btnH = 52
    local margin = 12
    local bx = x + margin
    local by = y + h - btnH - margin - 50  -- 码头上方

    baitBtnRect_.x = bx
    baitBtnRect_.y = by
    baitBtnRect_.w = btnW
    baitBtnRect_.h = btnH

    local r = 12
    -- 深蓝渐变底板
    UICore.fillRRectGrad(nvg, bx, by, btnW, btnH, r,
        { 14, 65, 140 }, 220,
        {  8, 42, 100 }, 240)
    -- 青蓝描边
    UICore.strokeRRect(nvg, bx, by, btnW, btnH, r, UICore.C_GEM, 1.5, 160)

    local cx = bx + btnW * 0.5
    -- 当前鱼饵图标（描边）
    local baitCfg = GameConfig.BAIT_BY_ID[GameState.currentBait or "normal"]
    local icon = baitCfg and baitCfg.icon or "🪱"
    UICore.strokeText(nvg, icon, cx, by + btnH * 0.38,
        22, UICore.C_TITLE, UICore.C_STROKE, 2,
        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 标签文字（描边）
    UICore.strokeText(nvg, "鱼饵", cx, by + btnH * 0.79,
        10, UICore.C_GEM, UICore.C_STROKE, 1.5,
        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
end

-- ============================================================================
-- Layer 9.1: 鱼饵选择器弹窗 (模态)
-- ============================================================================

function WaterScene.renderBaitSelector(nvg, x, y, w, h)
    if not showBaitSelector_ then return end

    -- ===== 动画进度 =====
    local t = UICore.easeOutCubic(baitSelectorT_)
    local maskAlpha = math.floor(t * 140)

    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillColor(nvg, nvgRGBA(0, 0, 10, maskAlpha))
    nvgFill(nvg)

    if t <= 0 then return end

    local itemCount = #GameConfig.BAIT
    local itemH = 60
    local headerH = 44
    local footerH = 18
    local popW = math.min(w * 0.85, 300)
    local popH = headerH + itemCount * itemH + footerH + 12
    local popCX = x + w * 0.5
    local popCY = y + h * 0.5
    local pad = 10

    -- 缩放动画变换
    local scale = 0.85 + 0.15 * t
    nvgGlobalAlpha(nvg, t)
    nvgSave(nvg)
    nvgTranslate(nvg, popCX, popCY)
    nvgScale(nvg, scale, scale)
    nvgTranslate(nvg, -popW * 0.5, -popH * 0.5)

    local px, py = 0, 0
    local popR = 12

    -- ===== 深海蓝面板 =====
    UICore.drawPanel(nvg, px, py, popW, popH, popR)

    -- ===== 标题栏 =====
    local titleBarH = UICore.drawPanelTitle(nvg, px, py, popW, "选择鱼饵")

    -- ===== 关闭按钮 =====
    local closeSize = 28
    local closeX = px + popW - closeSize - 4
    local closeY = py + 6
    baitCloseRect_.x = popCX + (closeX - popW * 0.5) * scale
    baitCloseRect_.y = popCY + (closeY - popH * 0.5) * scale
    baitCloseRect_.w = closeSize * scale
    baitCloseRect_.h = closeSize * scale
    nvgBeginPath(nvg)
    nvgCircle(nvg, closeX + closeSize * 0.5, closeY + closeSize * 0.5, closeSize * 0.4)
    nvgFillColor(nvg, nvgRGBA(200, 70, 50, 230))
    nvgFill(nvg)
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 14)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 240))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(nvg, closeX + closeSize * 0.5, closeY + closeSize * 0.5, "✕")

    -- ===== 鱼饵列表 =====
    baitItemRects_ = {}
    local curBait = GameState.currentBait or "normal"
    local listY = py + titleBarH + 4

    for i, bait in ipairs(GameConfig.BAIT) do
        local iy = listY + (i - 1) * itemH
        local ix = px + pad
        local iw = popW - pad * 2
        local ih = itemH - 6

        -- 存储屏幕坐标
        baitItemRects_[bait.id] = {
            x = popCX + (ix - popW * 0.5) * scale,
            y = popCY + (iy - popH * 0.5) * scale,
            w = iw * scale,
            h = ih * scale
        }

        local unlocked = GameConfig.isBaitUnlocked(bait.id)
        local isSelected = (bait.id == curBait)

        -- 行卡片底色
        if isSelected then
            UICore.fillRRectGrad(nvg, ix, iy, iw, ih, 8,
                {15, 70, 160}, 230, {10, 50, 130}, 245)
            UICore.strokeRRect(nvg, ix, iy, iw, ih, 8, UICore.C_GEM, 2.0, 220)
        elseif unlocked then
            UICore.fillRRectGrad(nvg, ix, iy, iw, ih, 8,
                {8, 38, 90}, 200, {5, 25, 65}, 215)
            UICore.strokeRRect(nvg, ix, iy, iw, ih, 8, UICore.C_GEM, 0.8, 60)
        else
            UICore.fillRRect(nvg, ix, iy, iw, ih, 8, {8, 20, 50}, 140)
            UICore.strokeRRect(nvg, ix, iy, iw, ih, 8, {40, 80, 120}, 0.8, 60)
        end

        -- 图标
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 24)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        if unlocked then
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, 230))
        else
            nvgFillColor(nvg, nvgRGBA(100, 130, 160, 150))
        end
        nvgText(nvg, ix + 24, iy + ih * 0.5, bait.icon)

        -- 名称
        local nameC = unlocked and UICore.C_TITLE or {80, 110, 140}
        UICore.strokeText(nvg, bait.displayName,
            ix + 48, iy + 9, 13,
            nameC, UICore.C_STROKE, 2,
            NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

        -- 描述
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 10)
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        if unlocked then
            nvgFillColor(nvg, nvgRGBA(UICore.C_GEM[1], UICore.C_GEM[2], UICore.C_GEM[3], 170))
        else
            nvgFillColor(nvg, nvgRGBA(80, 110, 140, 150))
        end
        nvgText(nvg, ix + 48, iy + 26, bait.desc)

        -- 右侧状态标签
        if isSelected then
            UICore.strokeTextA(nvg, "✔ 使用中",
                ix + iw - 8, iy + ih * 0.5, 11,
                UICore.C_GEM, 255, UICore.C_STROKE, 1.5,
                NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        elseif unlocked then
            UICore.strokeTextA(nvg, "可选择",
                ix + iw - 8, iy + ih * 0.5, 11,
                {140, 200, 255}, 200, UICore.C_STROKE, 1,
                NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        else
            UICore.strokeTextA(nvg, "Lv." .. bait.unlockBaitLevel .. " 解锁",
                ix + iw - 8, iy + ih * 0.5, 10,
                {100, 140, 180}, 160, UICore.C_STROKE, 1,
                NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        end
    end

    -- 底部提示
    UICore.strokeTextA(nvg, "升级鱼饵装备可解锁更高级的鱼饵",
        px + popW * 0.5, py + popH - 10, 9,
        UICore.C_GEM, 120, UICore.C_STROKE, 1,
        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    nvgRestore(nvg)
    nvgGlobalAlpha(nvg, 1.0)
end

-- ============================================================================
-- Layer 9.5: 新鱼发现 Toast (屏幕上方, 自动消失)
-- ============================================================================

function WaterScene.renderNewFishPopup(nvg, x, y, w, h)
    if not showNewFishPopup_ or not newFishPopupData_ then return end

    local progress = newFishPopupTimer_ / newFishPopupDuration_
    local slideIn = math.min(1.0, newFishPopupTimer_ / 0.3)
    local fadeOut = progress > 0.8 and (1.0 - (progress - 0.8) / 0.2) or 1.0
    local alpha = fadeOut

    if alpha < 0.01 then return end

    local data = newFishPopupData_
    local toastW = math.min(w * 0.7, 240)
    local toastH = 56
    local toastX = x + (w - toastW) * 0.5
    local targetY = y + 60
    local toastY = targetY - (1.0 - slideIn) * 30
    local a = math.floor(alpha * 255)

    nvgSave(nvg)
    nvgGlobalAlpha(nvg, alpha)

    -- 底板 (深海蓝渐变 + 宝石蓝边框)
    UICore.fillRRectGrad(nvg, toastX, toastY, toastW, toastH, 10,
        {20, 60, 120}, 240, {12, 38, 85}, 250)
    UICore.strokeRRect(nvg, toastX, toastY, toastW, toastH, 10,
        UICore.C_GEM, 1.5, a)

    -- ★ 新发现！标题
    UICore.strokeText(nvg, "★ 新鱼种发现！",
        toastX + toastW * 0.5, toastY + 13, 11,
        {255, 220, 100}, UICore.C_STROKE, 2,
        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 鱼名 + 图标
    local fishIcon = data.icon or "🐟"
    local fishName = data.displayName or "未知"
    local qualityName = ""
    if data.qualityId and GameConfig.QUALITY[data.qualityId] then
        qualityName = GameConfig.QUALITY[data.qualityId].displayName .. " "
    end
    UICore.strokeText(nvg, fishIcon .. " " .. qualityName .. fishName,
        toastX + toastW * 0.5, toastY + toastH * 0.65, 17,
        UICore.C_TITLE, UICore.C_STROKE, 2,
        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    nvgRestore(nvg)
end

-- ============================================================================
-- Layer 9.6: 词条 Toast (新鱼发现 toast 下方, 自动消失)
-- ============================================================================

function WaterScene.renderAffixPopup(nvg, x, y, w, h)
    if not showAffixPopup_ or not affixPopupData_ then return end

    local progress = affixPopupTimer_ / affixPopupDuration_
    local slideIn = math.min(1.0, affixPopupTimer_ / 0.3)
    local fadeOut = progress > 0.8 and (1.0 - (progress - 0.8) / 0.2) or 1.0
    local alpha = fadeOut

    if alpha < 0.01 then return end

    local data = affixPopupData_
    local toastW = math.min(w * 0.75, 260)
    local toastH = 62
    local toastX = x + (w - toastW) * 0.5
    local baseY = showNewFishPopup_ and (y + 130) or (y + 60)
    local toastY = baseY - (1.0 - slideIn) * 30
    local a = math.floor(alpha * 255)

    nvgSave(nvg)
    nvgGlobalAlpha(nvg, alpha)

    -- 底板 (深蓝青色渐变 + 宝石蓝边框, 统一海洋风)
    UICore.fillRRectGrad(nvg, toastX, toastY, toastW, toastH, 10,
        {10, 55, 110}, 240, {6, 35, 80}, 250)
    UICore.strokeRRect(nvg, toastX, toastY, toastW, toastH, 10,
        UICore.C_GEM, 1.5, a)

    -- ✦ 词条鱼！标题
    UICore.strokeText(nvg, "✦ 词条鱼！",
        toastX + toastW * 0.5, toastY + 13, 11,
        {200, 240, 255}, UICore.C_STROKE, 2,
        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 鱼名
    UICore.strokeText(nvg, data.displayName or "未知",
        toastX + toastW * 0.5, toastY + 31, 14,
        UICore.C_TITLE, UICore.C_STROKE, 2,
        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 词条摘要 + 价值倍率
    local summary = data.summary or ""
    local multStr = data.valueMult and string.format(" (×%.0f%%)", data.valueMult * 100) or ""
    UICore.strokeTextA(nvg, summary .. multStr,
        toastX + toastW * 0.5, toastY + toastH - 11, 11,
        UICore.C_GEM, 220, UICore.C_STROKE, 1.5,
        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    nvgRestore(nvg)
end

-- ============================================================================
-- 弹窗/选择器 公共 API
-- ============================================================================

--- 显示新鱼发现弹窗
---@param fishData table { name, displayName, icon, qualityId }
function WaterScene.showNewFishPopup(fishData)
    showNewFishPopup_ = true
    newFishPopupTimer_ = 0
    newFishPopupData_ = fishData
    print(string.format("[NewFish] 弹窗: %s", fishData.displayName or "?"))
end

--- 显示词条弹窗
---@param data table { fishName, displayName, affixes, summary, valueMult }
function WaterScene.showAffixPopup(data)
    showAffixPopup_ = true
    affixPopupTimer_ = 0
    affixPopupData_ = data
    print(string.format("[Affix] 弹窗: %s [%s]", data.displayName or "?", data.summary or ""))
end

--- 切换鱼饵选择器
function WaterScene.toggleBaitSelector()
    showBaitSelector_ = not showBaitSelector_
end

--- 鱼饵选择器是否打开
---@return boolean
function WaterScene.isBaitSelectorOpen()
    return showBaitSelector_
end

--- 鱼饵按钮是否被点击
---@return boolean
function WaterScene.isBaitBtnClicked()
    if showBaitSelector_ or showBoatUpgradePopup_ then return false end
    if not input:GetMouseButtonPress(MOUSEB_LEFT) then return false end
    local dpr = graphics:GetDPR()
    local pos = input:GetMousePosition()
    local lx = pos.x / dpr
    local ly = pos.y / dpr
    local r = baitBtnRect_
    return lx >= r.x and lx <= r.x + r.w
       and ly >= r.y and ly <= r.y + r.h
end

--- 处理鱼饵选择器点击
---@return string|nil action "close"|"select"|nil
function WaterScene.handleBaitSelectorInput()
    if not showBaitSelector_ then return nil end
    if not input:GetMouseButtonPress(MOUSEB_LEFT) then return nil end

    local dpr = graphics:GetDPR()
    local pos = input:GetMousePosition()
    local lx = pos.x / dpr
    local ly = pos.y / dpr

    -- 关闭按钮
    local c = baitCloseRect_
    if lx >= c.x and lx <= c.x + c.w and ly >= c.y and ly <= c.y + c.h then
        showBaitSelector_ = false
        return "close"
    end

    -- 鱼饵项
    for baitId, r in pairs(baitItemRects_) do
        if lx >= r.x and lx <= r.x + r.w and ly >= r.y and ly <= r.y + r.h then
            if GameConfig.isBaitUnlocked(baitId) then
                GameState.currentBait = baitId
                showBaitSelector_ = false
                print(string.format("[Bait] 切换鱼饵: %s", baitId))
                return "select"
            else
                print(string.format("[Bait] %s 未解锁", baitId))
                return nil
            end
        end
    end

    -- 点击弹窗外关闭
    showBaitSelector_ = false
    return "close"
end

--- 任意弹窗是否打开 (用于输入冲突保护)
---@return boolean
function WaterScene.isAnyPopupOpen()
    return showBoatUpgradePopup_ or showBaitSelector_
end

return WaterScene
