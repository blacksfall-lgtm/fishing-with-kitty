-- ============================================================================
-- IndustryScreen: 产业界面 - 寿司加工 + 配方列表 + 加工槽
-- ============================================================================
local UI = require("urhox-libs/UI")
local GameConfig     = require("config.GameConfig")
local GameState      = require("state.GameState")
local IndustrySystem = require("systems.IndustrySystem")
local FormatUtils    = require("utils.FormatUtils")

local IndustryScreen = {}

local screenRoot_
local slotsPanel_
local recipesPanel_
local statsLabel_

--- 构建产业界面
function IndustryScreen.build()
    -- 加工槽面板
    slotsPanel_ = UI.Panel {
        id = "processSlots",
        width = "100%",
        gap = 8,
    }

    -- 配方列表
    recipesPanel_ = UI.Panel {
        id = "recipesPanel",
        width = "100%",
        gap = 6,
    }

    -- 统计信息
    statsLabel_ = UI.Label {
        text = IndustryScreen.getStatsText(),
        fontSize = 11,
        fontColor = { 150, 170, 200, 255 },
        textAlign = "center",
        whiteSpace = "normal",
    }

    screenRoot_ = UI.Panel {
        id = "industryScreen",
        width = "100%",
        height = "100%",
        flexDirection = "column",
        children = {
            UI.ScrollView {
                width = "100%",
                flexGrow = 1,
                flexBasis = 0,
                children = {
                    UI.Panel {
                        width = "100%",
                        padding = 12,
                        gap = 16,
                        children = {
                            -- 标题
                            UI.Label {
                                text = "寿司加工",
                                fontSize = 18,
                                fontWeight = "bold",
                                fontColor = { 255, 220, 150, 255 },
                            },
                            -- 加工槽
                            UI.Label {
                                text = "加工槽",
                                fontSize = 13,
                                fontWeight = "bold",
                                fontColor = { 180, 200, 230, 255 },
                            },
                            slotsPanel_,
                            -- 分隔
                            UI.Divider { color = { 50, 70, 100, 200 } },
                            -- 配方列表标题
                            UI.Label {
                                text = "配方",
                                fontSize = 13,
                                fontWeight = "bold",
                                fontColor = { 180, 200, 230, 255 },
                            },
                            recipesPanel_,
                            -- 统计
                            UI.Divider { color = { 50, 70, 100, 200 } },
                            statsLabel_,
                        }
                    }
                }
            }
        }
    }

    -- 初始化加工槽和配方列表
    IndustryScreen.refreshSlots()
    IndustryScreen.refreshRecipes()

    return screenRoot_
end

--- 刷新加工槽UI
function IndustryScreen.refreshSlots()
    if not slotsPanel_ then return end
    slotsPanel_:ClearChildren()

    for i = 1, GameConfig.INDUSTRY.MAX_SLOTS do
        local unlocked = (i <= GameState.unlockedIndustrySlots)
        local slot = GameState.processingSlots[i]

        if not unlocked then
            -- 锁定槽
            local cost = GameConfig.INDUSTRY.SLOT_UNLOCK_COST[i] or 0
            slotsPanel_:AddChild(UI.Panel {
                width = "100%",
                height = 60,
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "center",
                gap = 8,
                backgroundColor = { 30, 35, 50, 200 },
                borderRadius = 8,
                borderWidth = 1,
                borderColor = { 60, 60, 80, 150 },
                children = {
                    UI.Label {
                        text = "解锁 (" .. FormatUtils.formatNumber(cost) .. " 金币)",
                        fontSize = 12,
                        fontColor = { 120, 120, 140, 255 },
                    },
                }
            })
        elseif slot then
            -- 加工中
            local recipe = GameConfig.SUSHI_BY_ID[slot.recipeId]
            local progress = IndustrySystem:getSlotProgress(i)
            local remaining = IndustrySystem:getSlotRemainingTime(i)
            local slotIndex = i

            slotsPanel_:AddChild(UI.Panel {
                width = "100%",
                padding = 10,
                flexDirection = "column",
                gap = 4,
                backgroundColor = { 30, 50, 80, 220 },
                borderRadius = 8,
                borderWidth = 1,
                borderColor = { 60, 100, 160, 150 },
                children = {
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "space-between",
                        children = {
                            UI.Label {
                                text = recipe.icon .. " " .. recipe.displayName,
                                fontSize = 13,
                                fontColor = { 220, 230, 255, 255 },
                            },
                            UI.Label {
                                id = "slotTime_" .. slotIndex,
                                text = FormatUtils.formatTime(remaining),
                                fontSize = 12,
                                fontColor = { 150, 200, 255, 255 },
                            },
                        }
                    },
                    UI.ProgressBar {
                        id = "slotProgress_" .. slotIndex,
                        value = progress,
                        width = "100%",
                        height = 6,
                        backgroundColor = { 20, 30, 50, 200 },
                        fillColor = "#4FC3F7",
                        borderRadius = 3,
                    },
                }
            })
        else
            -- 空闲槽
            slotsPanel_:AddChild(UI.Panel {
                width = "100%",
                height = 60,
                justifyContent = "center",
                alignItems = "center",
                backgroundColor = { 25, 35, 55, 200 },
                borderRadius = 8,
                borderWidth = 1,
                borderColor = { 50, 70, 100, 100 },
                children = {
                    UI.Label {
                        text = "空闲",
                        fontSize = 12,
                        fontColor = { 100, 120, 150, 180 },
                    },
                }
            })
        end
    end
end

--- 刷新配方列表
function IndustryScreen.refreshRecipes()
    if not recipesPanel_ then return end
    recipesPanel_:ClearChildren()

    for _, recipe in ipairs(GameConfig.SUSHI) do
        -- 检查材料
        local hasIngredients = GameState:hasIngredientsForRecipe(recipe)
        local ingredientText = {}
        for _, ing in ipairs(recipe.ingredients) do
            local fish = GameConfig.FISH_BY_ID[ing.fishId]
            local count = GameState:getFishCount(ing.fishId)
            local color = count >= ing.count and "✅" or "❌"
            table.insert(ingredientText,
                string.format("%s %s %d/%d", color, fish.displayName, count, ing.count))
        end

        local sellPrice = IndustrySystem:getSellPrice(recipe.id)
        local recipeId = recipe.id

        recipesPanel_:AddChild(UI.Panel {
            width = "100%",
            padding = 10,
            flexDirection = "column",
            gap = 6,
            backgroundColor = hasIngredients
                and { 25, 50, 40, 220 } or { 25, 30, 45, 200 },
            borderRadius = 8,
            borderWidth = 1,
            borderColor = hasIngredients
                and { 60, 140, 100, 150 } or { 50, 55, 70, 100 },
            children = {
                -- 名称行
                UI.Panel {
                    flexDirection = "row",
                    justifyContent = "space-between",
                    alignItems = "center",
                    children = {
                        UI.Label {
                            text = recipe.icon .. " " .. recipe.displayName,
                            fontSize = 14,
                            fontWeight = "bold",
                            fontColor = { 220, 230, 255, 255 },
                        },
                        UI.Label {
                            text = FormatUtils.formatNumber(sellPrice) .. " 金币",
                            fontSize = 12,
                            fontColor = { 255, 215, 0, 230 },
                        },
                    }
                },
                -- 材料
                UI.Label {
                    text = table.concat(ingredientText, "  "),
                    fontSize = 11,
                    fontColor = { 160, 180, 210, 255 },
                    whiteSpace = "normal",
                },
                -- 加工按钮
                UI.Button {
                    text = "加工 " .. recipe.processTime .. "s",
                    fontSize = 11,
                    height = 30,
                    disabled = not hasIngredients,
                    backgroundColor = hasIngredients
                        and { 40, 120, 80, 255 } or { 50, 55, 70, 255 },
                    onClick = function()
                        local ok, err = IndustrySystem:startProcessing(recipeId)
                        if ok then
                            IndustryScreen.refreshSlots()
                            IndustryScreen.refreshRecipes()
                        else
                            print("[IndustryScreen] " .. (err or "加工失败"))
                        end
                    end,
                },
            }
        })
    end
end

--- 每帧更新
function IndustryScreen.update(dt)
    -- 更新进度条和时间
    for i = 1, GameState.unlockedIndustrySlots do
        local slot = GameState.processingSlots[i]
        if slot then
            local progressWidget = screenRoot_:FindById("slotProgress_" .. i)
            if progressWidget then
                progressWidget:SetValue(IndustrySystem:getSlotProgress(i))
            end
            local timeWidget = screenRoot_:FindById("slotTime_" .. i)
            if timeWidget then
                timeWidget:SetText(FormatUtils.formatTime(IndustrySystem:getSlotRemainingTime(i)))
            end
        end
    end

    -- 检查加工完成，刷新UI
    local needRefresh = false
    for i = 1, GameState.unlockedIndustrySlots do
        if not GameState.processingSlots[i] then
            local progressWidget = screenRoot_:FindById("slotProgress_" .. i)
            if progressWidget then
                needRefresh = true
            end
        end
    end
    if needRefresh then
        IndustryScreen.refreshSlots()
        IndustryScreen.refreshRecipes()
    end

    -- 刷新统计
    if statsLabel_ then
        statsLabel_:SetText(IndustryScreen.getStatsText())
    end
end

function IndustryScreen.getStatsText()
    return string.format("已售出 %d 份寿司 | 总收入 %s 金币",
        GameState.totalSushiSold,
        FormatUtils.formatNumber(GameState.totalCoinsEarned))
end

return IndustryScreen
