-- ============================================================================
-- 钓鱼大亨 - 入口文件 (纯 NanoVG 渲染，无 UI 库)
-- ============================================================================
local GameConfig      = require("config.GameConfig")
local GameState       = require("state.GameState")
local SaveManager     = require("state.SaveManager")
local FishSwarmSystem = require("systems.FishSwarmSystem")
local IndustrySystem  = require("systems.IndustrySystem")
local BreedingSystem  = require("systems.BreedingSystem")
local AquariumSystem  = require("systems.AquariumSystem")
local WaterScene      = require("ui.WaterScene")
local IndustryScene   = require("ui.IndustryScene")
local BreedingScene   = require("ui.BreedingScene")
local AquariumScene   = require("ui.AquariumScene")
local ResearchScene   = require("ui.ResearchScene")
local CodexScene      = require("ui.CodexScene")
local SwipeSystem     = require("systems.SwipeSystem")
local CatchAnimSystem = require("systems.CatchAnimSystem")
local BossSystem      = require("systems.BossSystem")
local AffixSystem     = require("systems.AffixSystem")
local ResearchSystem  = require("systems.ResearchSystem")
local CodexSystem     = require("systems.CodexSystem")
local ComboSystem     = require("systems.ComboSystem")
local RareFishSystem  = require("systems.RareFishSystem")
local DropSystem      = require("systems.DropSystem")
local RewardSystem    = require("systems.RewardSystem")
local DebugMode       = require("debug.DebugMode")

---@type NVGContextWrapper
local vg_ = nil
local fontSans_ = -1

-- 屏幕切换: "fishing" | "industry" | "breeding" | "aquarium" | "research" | "codex"
local currentScreen_ = "fishing"

-- ============================================================================
-- 生命周期
-- ============================================================================

function Start()
    graphics.windowTitle = GameConfig.TITLE
    print("=== " .. GameConfig.TITLE .. " 启动 ===")

    -- 创建 NanoVG 上下文
    vg_ = nvgCreate(1)
    fontSans_ = nvgCreateFont(vg_, "sans", "Fonts/MiSans-Regular.ttf")

    -- 初始化游戏数据
    local loaded = SaveManager:load()
    if not loaded then
        GameState:initNewGame()
        print("[Main] 开始新游戏")
    end

    -- 初始化场景
    WaterScene.init(vg_)
    IndustryScene.init(vg_)
    BreedingScene.init(vg_)
    AquariumScene.init(vg_)
    ResearchScene.init(vg_)
    CodexScene.init(vg_)

    -- 初始化稀有鱼系统
    RareFishSystem.init()

    -- 初始化滑动捕鱼系统
    SwipeSystem.init()

    -- 设置 RewardSystem UI 回调
    RewardSystem.setCallbacks({
        showAffixPopup  = function(popup) WaterScene.showAffixPopup(popup) end,
        showNewFishPopup = function(popup) WaterScene.showNewFishPopup(popup) end,
        getFishImage    = function(name) return WaterScene.getFishImage(name) end,
        getBucketCenter = function() return WaterScene.getBucketCenter() end,
    })

    SwipeSystem.setCatchCallback(function(fish)
        -- 获取逻辑屏幕尺寸
        local physW = graphics:GetWidth()
        local physH = graphics:GetHeight()
        local dpr = graphics:GetDPR()
        local w = physW / dpr
        local h = physH / dpr

        -- ========== 稀有鱼特殊处理 ==========
        if fish.isRareFish and fish.rareResult then
            local r = fish.rareResult

            -- 使用 DropSystem 生成掉落 (替代 RareFishSystem.processCapture 中的硬编码)
            local catchResult = DropSystem.generateRareFishDrop({
                zone = GameState.currentZone,
            })

            -- 统一奖励发放
            RewardSystem.grantCatchReward(catchResult, {
                screenX = r.screenX,
                screenY = r.screenY,
                w = w, h = h,
                variant = 1, dir = 1, size = 70,
            })

            print(string.format("[Catch] 稀有鱼捕获! %s 品质%d +%d币 词条[%s]",
                catchResult.displayName, catchResult.qualityId,
                catchResult.coinValue, catchResult.summary))
            return
        end

        -- ========== 普通捕获 ==========
        local sizeTier = fish.sizeTier or "small"
        local fishScreenX = fish.x * w
        local fishScreenY = fish.y * h

        -- 1. 从鱼群中移除 (鱼影消失)
        FishSwarmSystem.removeFish(fish)

        -- 2. 连击系统 (仅波次鱼触发)
        local comboMult = 1.0
        if fish.isWave then
            ComboSystem.onCatch(fishScreenX, fishScreenY)
            comboMult = ComboSystem.getMultiplier()
        end

        -- 3. 使用 DropSystem 生成掉落
        local catchResult = DropSystem.generateCatchResult({
            zone         = GameState.currentZone,
            sizeTier     = sizeTier,
            qualityBoost = ResearchSystem.getQualityBoost(),
            comboMult    = comboMult,
        })

        -- 4. 统一奖励发放
        RewardSystem.grantCatchReward(catchResult, {
            screenX = fishScreenX,
            screenY = fishScreenY,
            w = w, h = h,
            variant = fish.variant or 1,
            dir     = fish.dir or 1,
            size    = fish.size or 40,
        })

        print(string.format("[Catch] %s(%s) 品质%d %s +%d币 (总计 %d)",
            catchResult.displayName, catchResult.fishName,
            catchResult.qualityId, sizeTier,
            catchResult.coinValue, GameState.coins))
    end)

    -- 初始化鱼王系统
    BossSystem.init()
    BossSystem.setCallbacks(
        function(boss)
            -- 使用 DropSystem 生成 Boss 掉落
            local catchResult = DropSystem.generateBossDrop({
                zone = GameState.currentZone,
                bossVariant = boss.variant or 1,
            })

            -- 获取逻辑屏幕尺寸
            local physW = graphics:GetWidth()
            local physH = graphics:GetHeight()
            local dpr = graphics:GetDPR()
            local w = physW / dpr
            local h = physH / dpr

            -- 统一奖励发放
            RewardSystem.grantCatchReward(catchResult, {
                screenX = w * 0.5,
                screenY = h * 0.4,
                w = w, h = h,
                variant = boss.variant or 1,
                dir = 1, size = 80,
            })

            print(string.format("[BossEvent] 鱼王被击败! %s 品质%d +%d币 词条[%s]",
                catchResult.displayName, catchResult.qualityId,
                catchResult.coinValue, catchResult.summary))
        end,
        function(boss)
            -- 鱼王逃跑
            print("[BossEvent] 鱼王逃跑了! 下次再接再厉")
        end
    )

    -- 初始化调试模式 (F12 切换)
    DebugMode.init()

    -- 订阅事件
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
    SubscribeToEvent(vg_, "NanoVGRender", "HandleNanoVGRender")

    print("=== 初始化完成 ===")
    print("[提示] Ctrl+D=调试UI模式  Ctrl+E=打开编辑器  ESC=返回")
end

function Stop()
    SaveManager:save()
    if vg_ then
        nvgDelete(vg_)
        vg_ = nil
    end
    print("=== 游戏退出 ===")
end

-- ============================================================================
-- 帧更新
-- ============================================================================

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- 调试模式更新
    DebugMode.update(dt)

    -- 游戏逻辑: GAME 和 DEBUG 模式下继续运行
    if DebugMode.shouldUpdateGame() then
        GameState.playTime = GameState.playTime + dt
        SaveManager:update(dt)

        -- 后台系统始终更新 (不受当前屏幕影响)
        IndustrySystem:update(dt)
        BreedingSystem:update(dt)
        AquariumSystem:update(dt)

        if currentScreen_ == "fishing" then
            -- 连击系统 + 稀有鱼系统更新
            ComboSystem.update(dt)
            local physWF = graphics:GetWidth()
            local physHF = graphics:GetHeight()
            local dprF = graphics:GetDPR()
            RareFishSystem.update(dt, physWF / dprF, physHF / dprF)

            WaterScene.update(dt)

            -- 仅 GAME 模式处理游戏输入 (DEBUG 模式下输入归 overlay)
            if DebugMode.shouldProcessGameInput() then
                local physW = graphics:GetWidth()
                local physH = graphics:GetHeight()
                local dpr = graphics:GetDPR()

                -- 优先处理模态弹窗输入 (升级弹窗/鱼饵选择器)
                if WaterScene.isBoatUpgradePopupOpen() then
                    WaterScene.handleBoatUpgradePopupInput()
                elseif WaterScene.isBaitSelectorOpen() then
                    WaterScene.handleBaitSelectorInput()
                else
                    -- 滑动捕鱼 (拖拽水桶时跳过)
                    if not WaterScene.isBucketDragging() then
                        SwipeSystem.update(dt, physW / dpr, physH / dpr, dpr)
                    end

                    -- 检测鱼饵按钮
                    if WaterScene.isBaitBtnClicked() then
                        WaterScene.toggleBaitSelector()
                    end

                    -- 检测升级按钮
                    if WaterScene.isBoatUpgradeBtnClicked() then
                        WaterScene.openBoatUpgradePopup()
                    end

                    -- 检测返航按钮
                    if WaterScene.isReturnBtnClicked() then
                        currentScreen_ = "industry"
                        print("[Main] 切换到产业界面")
                    end
                end
            end

        elseif currentScreen_ == "industry" then
            IndustryScene.update(dt)

            if DebugMode.shouldProcessGameInput() then
                local action = IndustryScene.checkInput()
                if action == "go_fishing" then
                    currentScreen_ = "fishing"
                    print("[Main] 切换到钓鱼界面")
                elseif action == "go_breeding" then
                    currentScreen_ = "breeding"
                    print("[Main] 切换到养殖界面")
                elseif action == "go_aquarium" then
                    currentScreen_ = "aquarium"
                    print("[Main] 切换到鱼缸界面")
                elseif action == "go_research" then
                    currentScreen_ = "research"
                    print("[Main] 切换到研发界面")
                elseif action == "go_codex" then
                    currentScreen_ = "codex"
                    print("[Main] 切换到图鉴界面")
                end
            end

        elseif currentScreen_ == "research" then
            ResearchScene.update(dt)

            if DebugMode.shouldProcessGameInput() then
                local action = ResearchScene.checkInput()
                if action == "go_back" then
                    currentScreen_ = "industry"
                    print("[Main] 研发→返回产业界面")
                end
            end

        elseif currentScreen_ == "breeding" then
            BreedingScene.update(dt)

            if DebugMode.shouldProcessGameInput() then
                local action = BreedingScene.checkInput()
                if action == "go_back" then
                    currentScreen_ = "industry"
                    print("[Main] 养殖→返回产业界面")
                end
            end

        elseif currentScreen_ == "aquarium" then
            AquariumScene.update(dt)

            if DebugMode.shouldProcessGameInput() then
                local action = AquariumScene.checkInput()
                if action == "go_back" then
                    currentScreen_ = "industry"
                    print("[Main] 鱼缸→返回产业界面")
                end
            end

        elseif currentScreen_ == "codex" then
            CodexScene.update(dt)

            if DebugMode.shouldProcessGameInput() then
                local action = CodexScene.checkInput()
                if action == "go_back" then
                    currentScreen_ = "industry"
                    print("[Main] 图鉴→返回产业界面")
                end
            end
        end
    end
end

-- ============================================================================
-- NanoVG 渲染
-- ============================================================================

function HandleNanoVGRender(eventType, eventData)
    if not vg_ then return end

    -- 模式 B: 系统逻辑分辨率 + DPR
    local physW = graphics:GetWidth()
    local physH = graphics:GetHeight()
    local dpr = graphics:GetDPR()
    local w = physW / dpr
    local h = physH / dpr

    nvgBeginFrame(vg_, w, h, dpr)
    if currentScreen_ == "fishing" then
        -- 连击震屏偏移
        local shakeX, shakeY = ComboSystem.getShakeOffset()
        WaterScene.render(vg_, shakeX, shakeY, w, h)
    elseif currentScreen_ == "industry" then
        IndustryScene.render(vg_, 0, 0, w, h)
    elseif currentScreen_ == "breeding" then
        BreedingScene.render(vg_, 0, 0, w, h)
    elseif currentScreen_ == "aquarium" then
        AquariumScene.render(vg_, 0, 0, w, h)
    elseif currentScreen_ == "research" then
        ResearchScene.render(vg_, 0, 0, w, h)
    elseif currentScreen_ == "codex" then
        CodexScene.render(vg_, 0, 0, w, h)
    end
    nvgEndFrame(vg_)
end

-- ============================================================================
-- 输入
-- ============================================================================

---@param eventType string
---@param eventData KeyDownEventData
function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()
    local ctrl = input:GetQualifierDown(QUAL_CTRL)

    -- 调试模式按键优先处理 (F12/F5/ESC + 编辑器快捷键)
    if DebugMode.handleKeyDown(key, ctrl) then
        return
    end

    -- 以下仅在 GAME 模式下处理
    if not DebugMode.isGameMode() then return end

    if key == KEY_S then
        SaveManager:save()
    end
    if key == KEY_W then
        FishSwarmSystem.forceWave()
    end
    if key == KEY_B then
        BossSystem.forceSpawn()
    end
    if key == KEY_R then
        RareFishSystem.forceSpawn()
    end
end
