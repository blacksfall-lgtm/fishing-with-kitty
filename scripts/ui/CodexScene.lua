-- ============================================================================
-- CodexScene: 图鉴/收集系统 NanoVG 场景
-- 两个标签页: 鱼种图鉴(10种×5品质) / 词条图鉴(4稀有度×5词条)
-- ============================================================================
local GameConfig  = require("config.GameConfig")
local GameState   = require("state.GameState")
local CodexSystem = require("systems.CodexSystem")
local AffixConfig = require("config.AffixConfig")
local WaterRenderer = require("ui.WaterRenderer")
local FormatUtils   = require("utils.FormatUtils")

local CodexScene = {}

-- ============================================================================
-- 状态
-- ============================================================================
local time_ = 0
local clickRects_ = {}

-- 标签页: 1=鱼种图鉴, 2=词条图鉴
local selectedTab_ = 1

-- 滚动
local scrollY_ = 0
local maxScrollY_ = 0

-- toast 提示
local toastMsg_   = ""
local toastTimer_ = 0

-- ============================================================================
-- 初始化
-- ============================================================================

function CodexScene.init(nvg)
    WaterRenderer.init(nvg)
    print("[CodexScene] 初始化完成")
end

function CodexScene.update(dt)
    time_ = time_ + dt
    if toastTimer_ > 0 then
        toastTimer_ = toastTimer_ - dt
    end
end

-- ============================================================================
-- 输入检测
-- ============================================================================

---@return string|nil action  "go_back" | nil
function CodexScene.checkInput()
    if not input:GetMouseButtonPress(MOUSEB_LEFT) then return nil end

    local dpr = graphics:GetDPR()
    local mx = input.mousePosition.x / dpr
    local my = input.mousePosition.y / dpr

    for _, rect in ipairs(clickRects_) do
        if mx >= rect.x and mx <= rect.x + rect.w and
           my >= rect.y and my <= rect.y + rect.h then
            if rect.action == "go_back" then
                return "go_back"
            elseif rect.action and rect.action:sub(1, 4) == "tab_" then
                local tabIdx = tonumber(rect.action:sub(5))
                if tabIdx and tabIdx ~= selectedTab_ then
                    selectedTab_ = tabIdx
                    scrollY_ = 0
                end
                return nil
            elseif rect.action and rect.action:sub(1, 11) == "claim_fish_" then
                local fishId = tonumber(rect.action:sub(12))
                if fishId then
                    local ok = CodexSystem.claimFishReward(fishId)
                    if ok then
                        local reward = GameConfig.CODEX_FISH_REWARD_BY_ID[fishId]
                        CodexScene.showToast("领取奖励: " .. (reward and reward.desc or ""))
                    else
                        CodexScene.showToast("无法领取")
                    end
                end
                return nil
            elseif rect.action and rect.action:sub(1, 12) == "claim_affix_" then
                local rarityId = tonumber(rect.action:sub(13))
                if rarityId then
                    local ok = CodexSystem.claimAffixReward(rarityId)
                    if ok then
                        local reward = GameConfig.CODEX_AFFIX_REWARD_BY_RARITY[rarityId]
                        CodexScene.showToast("领取奖励: " .. (reward and reward.desc or ""))
                    else
                        CodexScene.showToast("无法领取")
                    end
                end
                return nil
            end
        end
    end

    return nil
end

function CodexScene.showToast(msg)
    toastMsg_ = msg
    toastTimer_ = 2.0
end

-- ============================================================================
-- 渲染主函数
-- ============================================================================

function CodexScene.render(nvg, x, y, w, h)
    clickRects_ = {}

    -- 1) 水面背景
    WaterRenderer.render(nvg, x, y, w, h, time_)

    -- 半透明深色遮罩
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillColor(nvg, nvgRGBA(10, 25, 50, 140))
    nvgFill(nvg)

    -- 2) 顶部 HUD
    CodexScene.renderHUD(nvg, x, y, w, h)

    -- 3) 标签页栏
    local tabTop = y + 46
    local tabH = 34
    CodexScene.renderTabBar(nvg, x, tabTop, w, tabH)

    -- 4) 卡片区域
    local cardTop = tabTop + tabH + 4
    local cardH = h - (cardTop - y) - 8
    if selectedTab_ == 1 then
        CodexScene.renderFishGrid(nvg, x + 8, cardTop, w - 16, cardH)
    else
        CodexScene.renderAffixGrid(nvg, x + 8, cardTop, w - 16, cardH)
    end

    -- 5) Toast
    if toastTimer_ > 0 then
        local alpha = math.min(1, toastTimer_ * 2) * 220
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 16)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        local tw = nvgTextBounds(nvg, 0, 0, toastMsg_)
        local tx = x + w * 0.5
        local ty = y + h * 0.4
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, tx - tw * 0.5 - 16, ty - 14, tw + 32, 28, 14)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, math.floor(alpha * 0.7)))
        nvgFill(nvg)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, math.floor(alpha)))
        nvgText(nvg, tx, ty, toastMsg_)
    end
end

-- ============================================================================
-- 顶部 HUD
-- ============================================================================

function CodexScene.renderHUD(nvg, x, y, w, h)
    -- 半透明顶栏背景
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, 44)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 100))
    nvgFill(nvg)

    -- 返回按钮
    local btnW = 56
    local btnH = 26
    local btnX = x + 8
    local btnY = y + 9

    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, btnX, btnY, btnW, btnH, 8)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 140))
    nvgFill(nvg)

    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 12)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 220))
    nvgText(nvg, btnX + btnW * 0.5, btnY + btnH * 0.5, "← 返回")

    table.insert(clickRects_, {
        x = btnX, y = btnY, w = btnW, h = btnH,
        action = "go_back",
    })

    -- 标题
    nvgFontSize(nvg, 17)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 240, 200, 230))
    nvgText(nvg, x + w * 0.5, btnY + btnH * 0.5, "图鉴")

    -- 总进度
    local fc, ft, ac, at = CodexSystem.getOverallProgress()
    local progressStr = string.format("鱼种 %d/%d  词条 %d/%d", fc, ft, ac, at)
    nvgFontSize(nvg, 11)
    nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(180, 220, 255, 200))
    nvgText(nvg, x + w - 10, btnY + btnH * 0.5, progressStr)
end

-- ============================================================================
-- 标签页栏
-- ============================================================================

function CodexScene.renderTabBar(nvg, x, y, w, h)
    local tabs = {
        { id = 1, label = "鱼种图鉴" },
        { id = 2, label = "词条图鉴" },
    }
    local tabCount = #tabs
    local gap = 4
    local totalGap = gap * (tabCount + 1)
    local tabW = math.floor((w - totalGap) / tabCount)

    for i, tab in ipairs(tabs) do
        local tx = x + gap + (i - 1) * (tabW + gap)
        local ty = y + 3
        local th = h - 6
        local isSelected = (i == selectedTab_)

        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, tx, ty, tabW, th, 8)
        if isSelected then
            nvgFillColor(nvg, nvgRGBA(60, 130, 200, 230))
        else
            nvgFillColor(nvg, nvgRGBA(20, 45, 75, 180))
        end
        nvgFill(nvg)

        -- 选中指示器
        if isSelected then
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, tx + 4, ty + th - 3, tabW - 8, 3, 1.5)
            nvgFillColor(nvg, nvgRGBA(120, 200, 255, 220))
            nvgFill(nvg)
        end

        -- 标签文字
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 13)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        if isSelected then
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, 240))
        else
            nvgFillColor(nvg, nvgRGBA(180, 200, 220, 180))
        end
        nvgText(nvg, tx + tabW * 0.5, ty + th * 0.45, tab.label)

        table.insert(clickRects_, {
            x = tx, y = ty, w = tabW, h = th,
            action = "tab_" .. i,
        })
    end
end

-- ============================================================================
-- 鱼种图鉴网格
-- ============================================================================

function CodexScene.renderFishGrid(nvg, gx, gy, gw, gh)
    -- 面板背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, gx, gy, gw, gh, 10)
    nvgFillColor(nvg, nvgRGBA(5, 20, 45, 180))
    nvgFill(nvg)

    local pad = 8
    local cardGap = 8
    local cardH = 82

    nvgSave(nvg)
    nvgScissor(nvg, gx, gy, gw, gh)

    local fishList = GameConfig.FISH
    local contentH = #fishList * (cardH + cardGap) - cardGap + pad * 2
    maxScrollY_ = math.max(0, contentH - gh)
    scrollY_ = math.max(0, math.min(scrollY_, maxScrollY_))

    for idx, fish in ipairs(fishList) do
        local cx = gx + pad
        local cy = gy + pad + (idx - 1) * (cardH + cardGap) - scrollY_
        local cw = gw - pad * 2

        if cy + cardH < gy or cy > gy + gh then
            goto continue
        end

        CodexScene.renderFishCard(nvg, cx, cy, cw, cardH, fish)

        ::continue::
    end

    nvgRestore(nvg)
end

-- ============================================================================
-- 单张鱼种卡片
-- ============================================================================

function CodexScene.renderFishCard(nvg, cx, cy, cw, ch, fish)
    local collected, total = CodexSystem.getFishProgress(fish.id)
    local isComplete = collected >= total
    local rewardClaimed = CodexSystem.isFishRewardClaimed(fish.id)
    local reward = GameConfig.CODEX_FISH_REWARD_BY_ID[fish.id]

    -- 卡片背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, cx, cy, cw, ch, 10)
    if isComplete then
        nvgFillColor(nvg, nvgRGBA(25, 60, 40, 200))
    else
        nvgFillColor(nvg, nvgRGBA(20, 45, 80, 200))
    end
    nvgFill(nvg)

    -- 完成度左侧条
    if collected > 0 then
        local barH = ch * (collected / total)
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cx, cy + ch - barH, 4, barH, 2)
        if isComplete then
            nvgFillColor(nvg, nvgRGBA(80, 220, 120, 220))
        else
            nvgFillColor(nvg, nvgRGBA(80, 160, 220, 200))
        end
        nvgFill(nvg)
    end

    -- === 左区: 鱼图标 + 名称 ===
    local iconX = cx + 14
    local iconY = cy + 10

    -- 图标背景圆
    nvgBeginPath(nvg)
    nvgCircle(nvg, iconX + 16, iconY + 16, 18)
    if isComplete then
        nvgFillColor(nvg, nvgRGBA(40, 100, 60, 180))
    else
        nvgFillColor(nvg, nvgRGBA(30, 60, 100, 180))
    end
    nvgFill(nvg)

    -- 鱼图标 emoji
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 22)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 230))
    nvgText(nvg, iconX + 16, iconY + 16, fish.icon)

    -- 鱼名称
    local nameX = iconX + 40
    nvgFontSize(nvg, 14)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    if isComplete then
        nvgFillColor(nvg, nvgRGBA(100, 230, 140, 240))
    else
        nvgFillColor(nvg, nvgRGBA(220, 235, 255, 230))
    end
    nvgText(nvg, nameX, cy + 10, fish.displayName)

    -- 进度标签
    nvgFontSize(nvg, 10)
    if isComplete then
        nvgFillColor(nvg, nvgRGBA(255, 215, 0, 230))
    else
        nvgFillColor(nvg, nvgRGBA(150, 190, 230, 200))
    end
    local nameW = nvgTextBounds(nvg, 0, 0, fish.displayName)
    nvgFontSize(nvg, 14)
    nameW = nvgTextBounds(nvg, 0, 0, fish.displayName)
    nvgFontSize(nvg, 10)
    local progressLabel = isComplete and "已完成" or (collected .. "/" .. total)
    nvgText(nvg, nameX + nameW + 6, cy + 13, progressLabel)

    -- 描述
    nvgFontSize(nvg, 11)
    nvgFillColor(nvg, nvgRGBA(160, 185, 210, 180))
    nvgText(nvg, nameX, cy + 28, fish.desc)

    -- === 品质点 (5个) ===
    local dotStartX = nameX
    local dotY = cy + 46
    local dotSize = 10
    local dotGap = 6

    for q = 1, #GameConfig.QUALITY do
        local quality = GameConfig.QUALITY[q]
        local dx = dotStartX + (q - 1) * (dotSize + dotGap)
        local hasQ = CodexSystem.hasFishQuality(fish.id, q)

        nvgBeginPath(nvg)
        nvgCircle(nvg, dx + dotSize * 0.5, dotY + dotSize * 0.5, dotSize * 0.5)

        if hasQ then
            -- 已收集: 品质颜色实心
            local c = quality.color
            nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], 230))
        else
            -- 未收集: 暗色空心
            nvgFillColor(nvg, nvgRGBA(40, 55, 75, 150))
        end
        nvgFill(nvg)

        -- 未收集: 加边框
        if not hasQ then
            nvgStrokeColor(nvg, nvgRGBA(60, 80, 110, 150))
            nvgStrokeWidth(nvg, 1)
            nvgStroke(nvg)
        end

        -- 品质名称标签(小字)
        nvgFontSize(nvg, 8)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        if hasQ then
            local c = quality.color
            nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], 180))
        else
            nvgFillColor(nvg, nvgRGBA(80, 100, 130, 120))
        end
        nvgText(nvg, dx + dotSize * 0.5, dotY + dotSize + 2, quality.displayName)
    end

    -- === 右区: 奖励 + 领取按钮 ===
    local btnW = 76
    local btnH = 26
    local btnX = cx + cw - btnW - 10
    local btnY = cy + ch - btnH - 10

    -- 奖励描述
    if reward then
        nvgFontSize(nvg, 10)
        nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(180, 200, 230, 160))
        nvgText(nvg, cx + cw - 10, cy + 10, "奖励: " .. reward.desc)
    end

    if rewardClaimed then
        -- 已领取
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, btnX, btnY, btnW, btnH, 8)
        nvgFillColor(nvg, nvgRGBA(40, 100, 60, 180))
        nvgFill(nvg)

        nvgFontSize(nvg, 12)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(100, 220, 140, 220))
        nvgText(nvg, btnX + btnW * 0.5, btnY + btnH * 0.5, "已领取 ✓")
    elseif isComplete then
        -- 可领取: 亮色呼吸
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, btnX, btnY, btnW, btnH, 8)
        local pulse = 0.85 + 0.15 * math.sin(time_ * 2.5)
        nvgFillColor(nvg, nvgRGBA(50, 180, 100, math.floor(220 * pulse)))
        nvgFill(nvg)

        nvgStrokeColor(nvg, nvgRGBA(100, 230, 140, 120))
        nvgStrokeWidth(nvg, 1)
        nvgStroke(nvg)

        nvgFontSize(nvg, 12)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 240))
        nvgText(nvg, btnX + btnW * 0.5, btnY + btnH * 0.5, "领取奖励")

        table.insert(clickRects_, {
            x = btnX, y = btnY, w = btnW, h = btnH,
            action = "claim_fish_" .. fish.id,
        })
    else
        -- 未完成: 灰暗
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, btnX, btnY, btnW, btnH, 8)
        nvgFillColor(nvg, nvgRGBA(40, 55, 75, 150))
        nvgFill(nvg)

        nvgFontSize(nvg, 11)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(100, 120, 150, 150))
        nvgText(nvg, btnX + btnW * 0.5, btnY + btnH * 0.5, "未完成")
    end
end

-- ============================================================================
-- 词条图鉴网格
-- ============================================================================

function CodexScene.renderAffixGrid(nvg, gx, gy, gw, gh)
    -- 面板背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, gx, gy, gw, gh, 10)
    nvgFillColor(nvg, nvgRGBA(5, 20, 45, 180))
    nvgFill(nvg)

    local pad = 8
    local sectionGap = 10

    nvgSave(nvg)
    nvgScissor(nvg, gx, gy, gw, gh)

    -- 计算内容总高度
    local sectionHeaderH = 30
    local affixRowH = 26
    local rewardRowH = 32
    local sectionPad = 6
    local totalContentH = pad
    for _, rarity in ipairs(AffixConfig.RARITY) do
        local affixes = AffixConfig.AFFIXES_BY_RARITY[rarity.id]
        local rows = affixes and #affixes or 0
        totalContentH = totalContentH + sectionHeaderH + rows * affixRowH + rewardRowH + sectionPad + sectionGap
    end
    totalContentH = totalContentH - sectionGap + pad

    maxScrollY_ = math.max(0, totalContentH - gh)
    scrollY_ = math.max(0, math.min(scrollY_, maxScrollY_))

    local curY = gy + pad - scrollY_

    for _, rarity in ipairs(AffixConfig.RARITY) do
        local affixes = AffixConfig.AFFIXES_BY_RARITY[rarity.id]
        if not affixes then goto nextRarity end

        local collected, total = CodexSystem.getAffixProgress(rarity.id)
        local isComplete = collected >= total
        local rewardClaimed = CodexSystem.isAffixRewardClaimed(rarity.id)

        -- 跳过不可见区域
        local sectionH = sectionHeaderH + #affixes * affixRowH + rewardRowH + sectionPad
        if curY + sectionH < gy then
            curY = curY + sectionH + sectionGap
            goto nextRarity
        end
        if curY > gy + gh then
            goto done
        end

        -- === 段标题 ===
        local rc = rarity.color
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, gx + pad, curY, gw - pad * 2, sectionHeaderH, 6)
        if isComplete then
            nvgFillColor(nvg, nvgRGBA(rc[1], rc[2], rc[3], 60))
        else
            nvgFillColor(nvg, nvgRGBA(20, 40, 70, 180))
        end
        nvgFill(nvg)

        -- 左侧颜色条
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, gx + pad, curY, 4, sectionHeaderH, 2)
        nvgFillColor(nvg, nvgRGBA(rc[1], rc[2], rc[3], 220))
        nvgFill(nvg)

        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 14)
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(rc[1], rc[2], rc[3], 240))
        nvgText(nvg, gx + pad + 12, curY + sectionHeaderH * 0.5, rarity.displayName .. "词条")

        -- 进度
        nvgFontSize(nvg, 11)
        nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        if isComplete then
            nvgFillColor(nvg, nvgRGBA(255, 215, 0, 230))
        else
            nvgFillColor(nvg, nvgRGBA(180, 200, 220, 180))
        end
        nvgText(nvg, gx + gw - pad - 8, curY + sectionHeaderH * 0.5,
            collected .. "/" .. total)

        curY = curY + sectionHeaderH + 2

        -- === 词条列表 ===
        for _, affix in ipairs(affixes) do
            local hasAffix = CodexSystem.hasAffix(affix.id)
            local rowY = curY
            local rowW = gw - pad * 2 - 8

            -- 行背景 (交替)
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, gx + pad + 4, rowY, rowW, affixRowH - 2, 4)
            if hasAffix then
                nvgFillColor(nvg, nvgRGBA(rc[1], rc[2], rc[3], 30))
            else
                nvgFillColor(nvg, nvgRGBA(15, 30, 55, 120))
            end
            nvgFill(nvg)

            -- 发现状态图标
            nvgFontSize(nvg, 12)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            local iconCx = gx + pad + 18
            local rowMidY = rowY + (affixRowH - 2) * 0.5
            if hasAffix then
                nvgFillColor(nvg, nvgRGBA(100, 230, 140, 230))
                nvgText(nvg, iconCx, rowMidY, "✓")
            else
                nvgFillColor(nvg, nvgRGBA(80, 100, 130, 150))
                nvgText(nvg, iconCx, rowMidY, "?")
            end

            -- 词条名称
            nvgFontSize(nvg, 12)
            nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            if hasAffix then
                nvgFillColor(nvg, nvgRGBA(rc[1], rc[2], rc[3], 230))
                nvgText(nvg, gx + pad + 32, rowMidY, affix.displayName)
            else
                nvgFillColor(nvg, nvgRGBA(80, 100, 130, 150))
                nvgText(nvg, gx + pad + 32, rowMidY, "???")
            end

            -- 描述/效果
            if hasAffix then
                nvgFontSize(nvg, 10)
                nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                nvgFillColor(nvg, nvgRGBA(160, 185, 210, 170))
                nvgText(nvg, gx + gw - pad - 10, rowMidY, affix.desc)
            end

            curY = curY + affixRowH
        end

        -- === 奖励行 ===
        local reward = GameConfig.CODEX_AFFIX_REWARD_BY_RARITY[rarity.id]
        local rwY = curY + 2
        local rwW = gw - pad * 2 - 8

        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, gx + pad + 4, rwY, rwW, rewardRowH - 2, 4)
        nvgFillColor(nvg, nvgRGBA(20, 40, 65, 160))
        nvgFill(nvg)

        -- 奖励描述
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 11)
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(180, 200, 230, 180))
        local rewardDesc = reward and ("集齐奖励: " .. reward.desc) or "集齐奖励"
        nvgText(nvg, gx + pad + 14, rwY + (rewardRowH - 2) * 0.5, rewardDesc)

        -- 领取按钮
        local abW = 64
        local abH = 22
        local abX = gx + gw - pad - abW - 10
        local abY = rwY + (rewardRowH - 2 - abH) * 0.5

        if rewardClaimed then
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, abX, abY, abW, abH, 6)
            nvgFillColor(nvg, nvgRGBA(40, 100, 60, 180))
            nvgFill(nvg)
            nvgFontSize(nvg, 11)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg, nvgRGBA(100, 220, 140, 220))
            nvgText(nvg, abX + abW * 0.5, abY + abH * 0.5, "已领 ✓")
        elseif isComplete then
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, abX, abY, abW, abH, 6)
            local pulse = 0.85 + 0.15 * math.sin(time_ * 2.5)
            nvgFillColor(nvg, nvgRGBA(50, 180, 100, math.floor(220 * pulse)))
            nvgFill(nvg)
            nvgStrokeColor(nvg, nvgRGBA(100, 230, 140, 120))
            nvgStrokeWidth(nvg, 1)
            nvgStroke(nvg)
            nvgFontSize(nvg, 11)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, 240))
            nvgText(nvg, abX + abW * 0.5, abY + abH * 0.5, "领取")

            table.insert(clickRects_, {
                x = abX, y = abY, w = abW, h = abH,
                action = "claim_affix_" .. rarity.id,
            })
        else
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, abX, abY, abW, abH, 6)
            nvgFillColor(nvg, nvgRGBA(40, 55, 75, 150))
            nvgFill(nvg)
            nvgFontSize(nvg, 11)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg, nvgRGBA(100, 120, 150, 150))
            nvgText(nvg, abX + abW * 0.5, abY + abH * 0.5, "未完成")
        end

        curY = curY + rewardRowH + sectionPad + sectionGap

        ::nextRarity::
    end
    ::done::

    nvgRestore(nvg)
end

return CodexScene
