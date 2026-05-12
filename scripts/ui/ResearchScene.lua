-- ============================================================================
-- ResearchScene: 研发系统 NanoVG 场景
-- 标签页切换(捕鱼/产业/鱼缸/养殖) + 卡片网格 + 升级交互
-- ============================================================================
local GameConfig      = require("config.GameConfig")
local GameState       = require("state.GameState")
local ResearchSystem  = require("systems.ResearchSystem")
local WaterRenderer   = require("ui.WaterRenderer")
local FormatUtils     = require("utils.FormatUtils")

local ResearchScene = {}

-- ============================================================================
-- 状态
-- ============================================================================
local time_ = 0
local clickRects_ = {}

-- 当前选中的分类索引 (1-4)
local selectedTab_ = 1

-- toast 提示
local toastMsg_   = ""
local toastTimer_ = 0

-- 滚动 (卡片区域)
local scrollY_ = 0
local maxScrollY_ = 0

-- ============================================================================
-- 初始化
-- ============================================================================

function ResearchScene.init(nvg)
    WaterRenderer.init(nvg)
    print("[ResearchScene] 初始化完成")
end

function ResearchScene.update(dt)
    time_ = time_ + dt
    if toastTimer_ > 0 then
        toastTimer_ = toastTimer_ - dt
    end
end

-- ============================================================================
-- 输入检测
-- ============================================================================

---@return string|nil action  "go_back" | nil
function ResearchScene.checkInput()
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
                    scrollY_ = 0  -- 切换标签时重置滚动
                end
                return nil
            elseif rect.action and rect.action:sub(1, 8) == "upgrade_" then
                local key = rect.action:sub(9)
                local ok, err = ResearchSystem.upgrade(key)
                if ok then
                    local cfg = GameConfig.RESEARCH_BY_KEY[key]
                    ResearchScene.showToast(cfg.displayName .. " 升级成功!")
                else
                    ResearchScene.showToast(err or "升级失败")
                end
                return nil
            end
        end
    end

    return nil
end

function ResearchScene.showToast(msg)
    toastMsg_ = msg
    toastTimer_ = 2.0
end

-- ============================================================================
-- 渲染主函数
-- ============================================================================

function ResearchScene.render(nvg, x, y, w, h)
    clickRects_ = {}

    -- 1) 水面背景
    WaterRenderer.render(nvg, x, y, w, h, time_)

    -- 半透明深色遮罩
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillColor(nvg, nvgRGBA(10, 25, 50, 140))
    nvgFill(nvg)

    -- 2) 顶部 HUD
    ResearchScene.renderHUD(nvg, x, y, w, h)

    -- 3) 标签页栏
    local tabTop = y + 46
    local tabH = 34
    ResearchScene.renderTabBar(nvg, x, tabTop, w, tabH)

    -- 4) 卡片网格区域
    local cardTop = tabTop + tabH + 4
    local cardH = h - (cardTop - y) - 8
    ResearchScene.renderCardGrid(nvg, x + 8, cardTop, w - 16, cardH)

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

function ResearchScene.renderHUD(nvg, x, y, w, h)
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
    nvgText(nvg, x + w * 0.5, btnY + btnH * 0.5, "研发中心")

    -- 金币
    nvgFontSize(nvg, 12)
    nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 215, 0, 230))
    nvgText(nvg, x + w - 10, btnY + btnH * 0.5,
        FormatUtils.formatNumber(GameState.coins) .. " 金币")
end

-- ============================================================================
-- 标签页栏
-- ============================================================================

function ResearchScene.renderTabBar(nvg, x, y, w, h)
    local cats = GameConfig.RESEARCH_CATEGORIES
    local tabCount = #cats
    local gap = 4
    local totalGap = gap * (tabCount + 1)
    local tabW = math.floor((w - totalGap) / tabCount)

    for i, cat in ipairs(cats) do
        local tx = x + gap + (i - 1) * (tabW + gap)
        local ty = y + 3
        local th = h - 6
        local isSelected = (i == selectedTab_)

        -- 标签背景
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, tx, ty, tabW, th, 8)
        if isSelected then
            nvgFillColor(nvg, nvgRGBA(60, 130, 200, 230))
        else
            nvgFillColor(nvg, nvgRGBA(20, 45, 75, 180))
        end
        nvgFill(nvg)

        -- 选中指示器（底部亮线）
        if isSelected then
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, tx + 4, ty + th - 3, tabW - 8, 3, 1.5)
            nvgFillColor(nvg, nvgRGBA(120, 200, 255, 220))
            nvgFill(nvg)
        end

        -- 标签文字 (icon + 名称)
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 12)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        if isSelected then
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, 240))
        else
            nvgFillColor(nvg, nvgRGBA(180, 200, 220, 180))
        end
        nvgText(nvg, tx + tabW * 0.5, ty + th * 0.45, cat.icon .. " " .. cat.displayName)

        -- 点击区域
        table.insert(clickRects_, {
            x = tx, y = ty, w = tabW, h = th,
            action = "tab_" .. i,
        })
    end
end

-- ============================================================================
-- 卡片网格
-- ============================================================================

function ResearchScene.renderCardGrid(nvg, gx, gy, gw, gh)
    -- 面板背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, gx, gy, gw, gh, 10)
    nvgFillColor(nvg, nvgRGBA(5, 20, 45, 180))
    nvgFill(nvg)

    -- 获取当前分类的研发项
    local catId = GameConfig.RESEARCH_CATEGORIES[selectedTab_]
    if not catId then return end
    local items = GameConfig.RESEARCH_BY_CATEGORY[catId.id]
    if not items or #items == 0 then
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 14)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(150, 170, 200, 160))
        nvgText(nvg, gx + gw * 0.5, gy + gh * 0.5, "暂无研发项目")
        return
    end

    -- 卡片参数
    local pad = 8
    local cardGap = 8
    local cardH = 88  -- 每张卡片高度

    -- 裁剪区域
    nvgSave(nvg)
    nvgScissor(nvg, gx, gy, gw, gh)

    local contentH = #items * (cardH + cardGap) - cardGap + pad * 2
    maxScrollY_ = math.max(0, contentH - gh)
    scrollY_ = math.max(0, math.min(scrollY_, maxScrollY_))

    for idx, research in ipairs(items) do
        local cx = gx + pad
        local cy = gy + pad + (idx - 1) * (cardH + cardGap) - scrollY_
        local cw = gw - pad * 2

        -- 超出可见范围跳过
        if cy + cardH < gy or cy > gy + gh then
            goto continue
        end

        ResearchScene.renderCard(nvg, cx, cy, cw, cardH, research)

        ::continue::
    end

    nvgRestore(nvg)
end

-- ============================================================================
-- 单张研发卡片
-- ============================================================================

function ResearchScene.renderCard(nvg, cx, cy, cw, ch, research)
    local level = ResearchSystem.getLevel(research.key)
    local isMax = level >= research.maxLevel
    local canUpgrade = ResearchSystem.canUpgrade(research.key)
    local cost = ResearchSystem.getUpgradeCost(research.key)
    local effect = ResearchSystem.getEffect(research.key)

    -- 卡片背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, cx, cy, cw, ch, 10)
    if isMax then
        nvgFillColor(nvg, nvgRGBA(25, 60, 40, 200))  -- 满级绿色调
    else
        nvgFillColor(nvg, nvgRGBA(20, 45, 80, 200))
    end
    nvgFill(nvg)

    -- 左侧等级条
    if level > 0 then
        local barH = ch * (level / research.maxLevel)
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cx, cy + ch - barH, 4, barH, 2)
        if isMax then
            nvgFillColor(nvg, nvgRGBA(80, 220, 120, 220))
        else
            nvgFillColor(nvg, nvgRGBA(80, 160, 220, 200))
        end
        nvgFill(nvg)
    end

    -- === 左区域: 图标 + 名称 + 描述 ===
    local iconX = cx + 14
    local iconY = cy + 14

    -- 图标背景圆
    nvgBeginPath(nvg)
    nvgCircle(nvg, iconX + 16, iconY + 16, 18)
    if isMax then
        nvgFillColor(nvg, nvgRGBA(40, 100, 60, 180))
    else
        nvgFillColor(nvg, nvgRGBA(30, 60, 100, 180))
    end
    nvgFill(nvg)

    -- 图标
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 22)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 230))
    nvgText(nvg, iconX + 16, iconY + 16, research.icon)

    -- 名称
    local nameX = iconX + 40
    nvgFontSize(nvg, 14)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    if isMax then
        nvgFillColor(nvg, nvgRGBA(100, 230, 140, 240))
    else
        nvgFillColor(nvg, nvgRGBA(220, 235, 255, 230))
    end
    nvgText(nvg, nameX, cy + 12, research.displayName)

    -- 等级标签
    nvgFontSize(nvg, 11)
    local levelStr = "Lv." .. level .. "/" .. research.maxLevel
    if isMax then
        levelStr = "MAX"
        nvgFillColor(nvg, nvgRGBA(255, 215, 0, 230))
    else
        nvgFillColor(nvg, nvgRGBA(150, 190, 230, 200))
    end
    local nameWidth = nvgTextBounds(nvg, 0, 0, research.displayName)
    nvgFontSize(nvg, 14)
    nameWidth = nvgTextBounds(nvg, 0, 0, research.displayName)
    nvgFontSize(nvg, 10)
    nvgText(nvg, nameX + nameWidth + 6, cy + 15, levelStr)

    -- 描述
    nvgFontSize(nvg, 11)
    nvgFillColor(nvg, nvgRGBA(160, 185, 210, 180))
    nvgText(nvg, nameX, cy + 30, research.desc)

    -- === 中区域: 当前效果值 ===
    local effectStr = ResearchScene.formatEffect(research, level, effect)
    local nextStr = nil
    if not isMax then
        local nextEffect = research.baseEffect + research.effectPerLevel * (level + 1)
        if research.floorPercent and nextEffect < research.floorPercent then
            nextEffect = research.floorPercent
        end
        nextStr = ResearchScene.formatEffect(research, level + 1, nextEffect)
    end

    nvgFontSize(nvg, 11)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(140, 170, 210, 180))
    nvgText(nvg, nameX, cy + 46, "当前:")

    -- 当前效果值 (亮色)
    nvgFillColor(nvg, nvgRGBA(100, 220, 180, 230))
    local labelW = nvgTextBounds(nvg, 0, 0, "当前:")
    nvgText(nvg, nameX + labelW + 4, cy + 46, effectStr)

    -- 下一级效果预览
    if nextStr then
        local curW = nvgTextBounds(nvg, 0, 0, effectStr)
        nvgFillColor(nvg, nvgRGBA(120, 150, 180, 150))
        nvgText(nvg, nameX + labelW + 4 + curW + 6, cy + 46, "→")
        local arrowW = nvgTextBounds(nvg, 0, 0, "→")
        nvgFillColor(nvg, nvgRGBA(180, 230, 140, 220))
        nvgText(nvg, nameX + labelW + 4 + curW + 6 + arrowW + 4, cy + 46, nextStr)
    end

    -- === 右区域: 升级按钮 ===
    local btnW = 80
    local btnH = 30
    local btnX = cx + cw - btnW - 10
    local btnY = cy + ch - btnH - 10

    if isMax then
        -- 满级标签
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, btnX, btnY, btnW, btnH, 8)
        nvgFillColor(nvg, nvgRGBA(40, 100, 60, 180))
        nvgFill(nvg)

        nvgFontSize(nvg, 12)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(100, 220, 140, 220))
        nvgText(nvg, btnX + btnW * 0.5, btnY + btnH * 0.5, "已满级 ✓")
    else
        -- 升级按钮
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, btnX, btnY, btnW, btnH, 8)
        if canUpgrade then
            -- 可升级: 亮蓝色 + 微弱呼吸
            local pulse = 0.85 + 0.15 * math.sin(time_ * 2.5)
            local alpha = math.floor(220 * pulse)
            nvgFillColor(nvg, nvgRGBA(50, 130, 210, alpha))
        else
            -- 不可升级: 灰暗
            nvgFillColor(nvg, nvgRGBA(40, 55, 75, 180))
        end
        nvgFill(nvg)

        -- 按钮边框
        if canUpgrade then
            nvgStrokeColor(nvg, nvgRGBA(100, 180, 255, 120))
            nvgStrokeWidth(nvg, 1)
            nvgStroke(nvg)
        end

        -- 费用文字
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 11)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        if canUpgrade then
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, 240))
        else
            nvgFillColor(nvg, nvgRGBA(130, 140, 160, 180))
        end
        nvgText(nvg, btnX + btnW * 0.5, btnY + btnH * 0.5,
            FormatUtils.formatNumber(cost) .. " 金币")

        -- 点击区域
        table.insert(clickRects_, {
            x = btnX, y = btnY, w = btnW, h = btnH,
            action = "upgrade_" .. research.key,
        })
    end

    -- === 等级进度点 ===
    local dotY = cy + ch - 14
    local dotStartX = cx + 14
    local dotSize = 5
    local dotGap = 3
    -- 最多显示maxLevel个点
    local maxDots = math.min(research.maxLevel, 10)
    for i = 1, maxDots do
        local dx = dotStartX + (i - 1) * (dotSize + dotGap)
        nvgBeginPath(nvg)
        nvgCircle(nvg, dx + dotSize * 0.5, dotY, dotSize * 0.5)
        if i <= level then
            if isMax then
                nvgFillColor(nvg, nvgRGBA(100, 230, 140, 230))
            else
                nvgFillColor(nvg, nvgRGBA(80, 180, 255, 220))
            end
        else
            nvgFillColor(nvg, nvgRGBA(50, 70, 100, 150))
        end
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 效果值格式化
-- ============================================================================

function ResearchScene.formatEffect(research, level, effect)
    if level == 0 then
        if research.effectType == "multiply" then
            return "×1.00"
        else
            return "+0"
        end
    end

    if research.effectType == "multiply" then
        if research.effectPerLevel < 0 then
            -- 减少型 (波次间隔、NPC频率) 显示为百分比
            return string.format("×%.2f", effect)
        else
            return string.format("×%.2f", effect)
        end
    else
        -- 加法型 (容量、槽位、权重)
        return "+" .. tostring(math.floor(effect))
    end
end

return ResearchScene
