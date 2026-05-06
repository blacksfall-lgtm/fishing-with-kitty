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
    SwipeSystem.setCatchCallback(function(fish)
        -- ========== 稀有鱼特殊处理 (已在 RareFishSystem.processCapture 中完成入仓) ==========
        if fish.isRareFish and fish.rareResult then
            local r = fish.rareResult
            local physW = graphics:GetWidth()
            local physH = graphics:GetHeight()
            local dpr = graphics:GetDPR()
            local w = physW / dpr
            local h = physH / dpr

            -- 金币奖励 (大额)
            local coinValue = 100
            ComboSystem.onCatch(r.screenX, r.screenY)
            local comboMult = ComboSystem.getMultiplier()
            if comboMult > 1.0 then
                coinValue = math.floor(coinValue * comboMult)
            end
            GameState:addCoins(coinValue)
            CatchAnimSystem.triggerCoinPopup(r.screenX, r.screenY, coinValue)

            -- 显示词条弹窗
            WaterScene.showAffixPopup({
                fishName    = r.fishName,
                displayName = r.displayName,
                affixes     = r.affixes,
                summary     = r.summary,
                valueMult   = r.valueMult,
                isRareFish  = true,
            })

            print(string.format("[Catch] 稀有鱼捕获! %s 品质%d +%d币 词条[%s]",
                r.displayName, r.qualityId, coinValue, r.summary))
            return
        end

        -- 根据当前海域筛选对应鱼种，按权重随机选择
        local zoneFish = GameConfig.FISH_BY_ZONE[GameState.currentZone] or GameConfig.FISH_BY_ZONE["nearshore"]
        local totalWeight = 0
        for _, f in ipairs(zoneFish) do totalWeight = totalWeight + f.catchWeight end
        local roll = math.random() * totalWeight
        local chosenFish = zoneFish[1]
        local acc = 0
        for _, f in ipairs(zoneFish) do
            acc = acc + f.catchWeight
            if roll <= acc then chosenFish = f; break end
        end

        -- 随机品质 (研发: 品质提升增加高品质权重)
        local qWeights = chosenFish.qualityWeights or GameConfig.DEFAULT_QUALITY_WEIGHTS
        local qualityBoost = ResearchSystem.getQualityBoost()
        local adjustedWeights = {}
        for i, w in ipairs(qWeights) do
            adjustedWeights[i] = w
        end
        -- 品质提升: 每级将1点权重从品质1转移到更高品质
        if qualityBoost > 0 and #adjustedWeights >= 3 then
            local shift = qualityBoost
            local available = math.max(0, adjustedWeights[1] - 1)
            shift = math.min(shift, available)
            adjustedWeights[1] = adjustedWeights[1] - shift
            -- 均匀分配给品质3/4/5
            local highTiers = math.max(1, #adjustedWeights - 2)
            for i = 3, #adjustedWeights do
                adjustedWeights[i] = adjustedWeights[i] + shift / highTiers
            end
        end
        local qTotal = 0
        for _, w in ipairs(adjustedWeights) do qTotal = qTotal + w end
        local qRoll = math.random() * qTotal
        local qualityId = 1
        local qAcc = 0
        for i, w in ipairs(adjustedWeights) do
            qAcc = qAcc + w
            if qRoll <= qAcc then qualityId = i; break end
        end

        local sizeTier = fish.sizeTier or "small"

        print(string.format("[Catch] %s(%s) 品质%d tier=%s pos=(%.2f,%.2f)",
            chosenFish.displayName, chosenFish.name, qualityId, sizeTier,
            fish.x or 0, fish.y or 0))

        -- 获取逻辑屏幕尺寸
        local physW = graphics:GetWidth()
        local physH = graphics:GetHeight()
        local dpr = graphics:GetDPR()
        local w = physW / dpr
        local h = physH / dpr

        -- 鱼影屏幕坐标
        local fishScreenX = fish.x * w
        local fishScreenY = fish.y * h

        -- 水桶目标坐标
        local boatX, boatY = WaterScene.getBucketCenter()

        -- 1. 从鱼群中移除 (鱼影消失)
        FishSwarmSystem.removeFish(fish)

        -- 2. 按鱼影大小给金币: 小鱼1 中鱼5 大鱼25
        local sizeBaseValue = (sizeTier == "large" and 25) or (sizeTier == "medium" and 5) or 1
        local coinValue = math.floor(sizeBaseValue
            * (GameConfig.QUALITY[qualityId] and GameConfig.QUALITY[qualityId].multiplier or 1.0))

        -- 连击系统: 记录捕获 + 应用连击倍率
        ComboSystem.onCatch(fishScreenX, fishScreenY)
        local comboMult = ComboSystem.getMultiplier()
        if comboMult > 1.0 then
            coinValue = math.floor(coinValue * comboMult)
        end

        GameState:addCoins(coinValue)
        CatchAnimSystem.triggerCoinPopup(fishScreenX, fishScreenY, coinValue)

        -- 3. 中大鱼额外飞向渔船 + 进鱼仓 (研发: 鱼仓扩容)
        local holdCap = GameConfig.FISH_HOLD_CAPACITY + ResearchSystem.getHoldCapacityBonus()
        if sizeTier ~= "small" and GameState:getTotalFishInHold() < holdCap then
            local fishImgInfo = WaterScene.getFishImage(chosenFish.name)
            CatchAnimSystem.trigger(
                fishScreenX, fishScreenY,
                boatX, boatY,
                fish.variant or 1,
                fish.dir or 1,
                fish.size or 40,
                w, h,
                fishImgInfo
            )
            GameState:addFish(chosenFish.id, qualityId, 1)

            -- 图鉴记录 (品质收集)
            CodexSystem.recordCatch(chosenFish.id, qualityId, nil)

            -- 新鱼发现检测
            if not GameState.discoveredFish[chosenFish.id] then
                GameState.discoveredFish[chosenFish.id] = true
                WaterScene.showNewFishPopup({
                    name = chosenFish.name,
                    displayName = chosenFish.displayName,
                    icon = chosenFish.icon or "🐟",
                    qualityId = qualityId,
                })
            end

            -- 词条系统: 10%概率生成词条鱼
            local affixes = AffixSystem.rollAffixes(chosenFish.id, qualityId)
            if affixes then
                -- 图鉴记录词条
                CodexSystem.recordCatch(chosenFish.id, qualityId, affixes)
                local uid = GameState:addIndividualFish(chosenFish.id, qualityId, affixes)
                local summary = AffixSystem.getAffixSummary(affixes)
                local valueMult = AffixSystem.calcValueMultiplier(affixes)
                print(string.format("[Affix] 词条鱼! uid=%d %s 品质%d 词条[%s] ×%.0f%%价值",
                    uid, chosenFish.displayName, qualityId, summary,
                    valueMult * 100))
                -- 显示词条弹窗
                WaterScene.showAffixPopup({
                    fishName = chosenFish.name,
                    displayName = chosenFish.displayName,
                    affixes = affixes,
                    summary = summary,
                    valueMult = valueMult,
                })
            end

            print(string.format("[Catch] %s鱼→鱼仓+金币 %s 品质%d +%d币 (总计 %d)",
                sizeTier == "medium" and "中" or "大",
                chosenFish.displayName, qualityId, coinValue, GameState.coins))
        elseif sizeTier ~= "small" then
            -- 鱼仓已满, 中大鱼只给金币
            print(string.format("[Catch] 鱼仓已满! %s鱼仅获金币 +%d (总计 %d)",
                sizeTier == "medium" and "中" or "大", coinValue, GameState.coins))
        else
            print(string.format("[Catch] 小鱼→金币 +%d (总计 %d)", coinValue, GameState.coins))
        end
    end)

    -- 初始化鱼王系统
    BossSystem.init()
    BossSystem.setCallbacks(
        function(boss)
            -- 鱼王被击败: 奖励金币
            local reward = 500
            GameState:addCoins(reward)
            print(string.format("[BossEvent] 鱼王被击败! 奖励 %d 金币 (总计 %d)", reward, GameState.coins))

            -- 鱼王必掉词条鱼 (2-4条词条)
            local bossVariant = boss.variant or 1
            -- variant 1~4 对应鱼种 id 7~10 (外海鱼)
            local fishId = math.min(bossVariant + 6, 10)
            local chosenFish = GameConfig.FISH_BY_ID[fishId]
            if chosenFish then
                -- 按鱼种品质权重随机品质
                local weights = chosenFish.qualityWeights or GameConfig.DEFAULT_QUALITY_WEIGHTS
                local qualityId = 1
                local totalW = 0
                for _, w in ipairs(weights) do totalW = totalW + w end
                local roll = math.random() * totalW
                local acc = 0
                for qi, w in ipairs(weights) do
                    acc = acc + w
                    if roll <= acc then qualityId = qi; break end
                end
                -- 必定生成 2~4 词条
                local affixes = AffixSystem.rollGuaranteedAffixes(2, 4)
                -- 记录图鉴
                CodexSystem.recordCatch(fishId, qualityId, affixes)
                -- 添加词条鱼到个体鱼列表
                local uid = GameState:addIndividualFish(fishId, qualityId, affixes)
                -- 普通鱼仓也加一条
                GameState:addFish(fishId, qualityId, 1)
                local summary = AffixSystem.getAffixSummary(affixes)
                local valueMult = AffixSystem.calcValueMultiplier(affixes)
                print(string.format("[BossEvent] 词条鱼掉落! uid=%d %s 品质%d 词条×%d [%s] 价值×%.0f%%",
                    uid, chosenFish.displayName, qualityId, #affixes, summary, valueMult * 100))
                -- 显示词条弹窗
                WaterScene.showAffixPopup({
                    fishName = chosenFish.name,
                    displayName = chosenFish.displayName,
                    affixes = affixes,
                    summary = summary,
                    valueMult = valueMult,
                    isBossDrop = true,
                })
            end
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
