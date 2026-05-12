-- ============================================================================
-- BreedingScreen: 养殖界面 - 放入鱼→定时产出同种鱼
-- ============================================================================
local UI = require("urhox-libs/UI")
local GameConfig     = require("config.GameConfig")
local GameState      = require("state.GameState")
local BreedingSystem = require("systems.BreedingSystem")
local FormatUtils    = require("utils.FormatUtils")

local BreedingScreen = {}

local screenRoot_
local slotsPanel_
local fishSelectPanel_
local selectedSlot_ = nil  -- 当前选择要放鱼的槽位

--- 构建养殖界面
function BreedingScreen.build()
    slotsPanel_ = UI.Panel {
        id = "breedingSlots",
        width = "100%",
        gap = 8,
    }

    fishSelectPanel_ = UI.Panel {
        id = "fishSelectPanel",
        visible = false,
        width = "100%",
        padding = 12,
        gap = 6,
        backgroundColor = { 25, 40, 65, 240 },
        borderRadius = 8,
        borderWidth = 1,
        borderColor = { 80, 120, 180, 200 },
    }

    screenRoot_ = UI.Panel {
        id = "breedingScreen",
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
                            UI.Label {
                                text = "养殖场",
                                fontSize = 18,
                                fontWeight = "bold",
                                fontColor = { 150, 230, 200, 255 },
                            },
                            UI.Label {
                                text = "放入鱼后会定时产出同种同品质的鱼",
                                fontSize = 11,
                                fontColor = { 130, 150, 180, 255 },
                            },
                            slotsPanel_,
                            UI.Divider { color = { 50, 70, 100, 200 } },
                            fishSelectPanel_,
                        }
                    }
                }
            }
        }
    }

    BreedingScreen.refreshSlots()
    return screenRoot_
end

--- 刷新养殖槽
function BreedingScreen.refreshSlots()
    if not slotsPanel_ then return end
    slotsPanel_:ClearChildren()

    for i = 1, GameConfig.BREEDING.MAX_SLOTS do
        local unlocked = (i <= GameState.unlockedBreedingSlots)
        local slot = GameState.breedingSlots[i]
        local slotIndex = i

        if not unlocked then
            local cost = GameConfig.BREEDING.SLOT_UNLOCK_COST[i] or 0
            slotsPanel_:AddChild(UI.Panel {
                width = "100%",
                height = 70,
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
                        text = "锁定",
                        fontSize = 20,
                    },
                    UI.Button {
                        text = "解锁 (" .. FormatUtils.formatNumber(cost) .. " 金币)",
                        fontSize = 11,
                        height = 30,
                        backgroundColor = { 60, 100, 70, 255 },
                        onClick = function()
                            local ok, err = BreedingSystem:unlockSlot()
                            if ok then
                                BreedingScreen.refreshSlots()
                            else
                                print("[BreedingScreen] " .. (err or "解锁失败"))
                            end
                        end,
                    },
                }
            })
        elseif slot then
            -- 有鱼在养殖
            local fishCfg = GameConfig.FISH_BY_ID[slot.fishId]
            local qualityCfg = GameConfig.QUALITY[slot.qualityId]
            local progress = BreedingSystem:getSlotProgress(i)
            local remaining = BreedingSystem:getSlotRemainingTime(i)

            slotsPanel_:AddChild(UI.Panel {
                width = "100%",
                padding = 10,
                flexDirection = "column",
                gap = 6,
                backgroundColor = { 25, 50, 45, 220 },
                borderRadius = 8,
                borderWidth = 1,
                borderColor = { qualityCfg.color[1], qualityCfg.color[2], qualityCfg.color[3], 150 },
                children = {
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "space-between",
                        alignItems = "center",
                        children = {
                            UI.Label {
                                text = fishCfg.icon .. " " .. fishCfg.displayName .. " [" .. qualityCfg.displayName .. "]",
                                fontSize = 13,
                                fontColor = { qualityCfg.color[1], qualityCfg.color[2], qualityCfg.color[3], 255 },
                            },
                            UI.Button {
                                text = "取出",
                                fontSize = 10,
                                height = 26,
                                width = 50,
                                backgroundColor = { 120, 60, 60, 255 },
                                onClick = function()
                                    BreedingSystem:removeFish(slotIndex)
                                    BreedingScreen.refreshSlots()
                                end,
                            },
                        }
                    },
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "space-between",
                        alignItems = "center",
                        children = {
                            UI.ProgressBar {
                                id = "breedProgress_" .. slotIndex,
                                value = progress,
                                flexGrow = 1,
                                height = 6,
                                backgroundColor = { 20, 30, 50, 200 },
                                fillColor = "#66BB6A",
                                borderRadius = 3,
                                marginRight = 8,
                            },
                            UI.Label {
                                id = "breedTime_" .. slotIndex,
                                text = FormatUtils.formatTime(remaining),
                                fontSize = 11,
                                fontColor = { 150, 200, 170, 255 },
                            },
                        }
                    },
                }
            })
        else
            -- 空闲槽
            slotsPanel_:AddChild(UI.Panel {
                width = "100%",
                height = 70,
                justifyContent = "center",
                alignItems = "center",
                backgroundColor = { 25, 35, 55, 200 },
                borderRadius = 8,
                borderWidth = 1,
                borderColor = { 50, 70, 100, 100 },
                children = {
                    UI.Button {
                        text = "➕ 放入鱼",
                        fontSize = 12,
                        height = 34,
                        backgroundColor = { 50, 90, 130, 255 },
                        onClick = function()
                            selectedSlot_ = slotIndex
                            BreedingScreen.showFishSelector()
                        end,
                    },
                }
            })
        end
    end
end

--- 显示鱼选择面板
function BreedingScreen.showFishSelector()
    if not fishSelectPanel_ then return end
    fishSelectPanel_:ClearChildren()
    fishSelectPanel_:SetVisible(true)

    fishSelectPanel_:AddChild(UI.Panel {
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        children = {
            UI.Label {
                text = "选择鱼放入槽位 " .. selectedSlot_,
                fontSize = 13,
                fontWeight = "bold",
                fontColor = { 200, 220, 255, 255 },
            },
            UI.Button {
                text = "✕",
                fontSize = 14,
                width = 30,
                height = 30,
                backgroundColor = { 100, 50, 50, 255 },
                onClick = function()
                    fishSelectPanel_:SetVisible(false)
                    selectedSlot_ = nil
                end,
            },
        }
    })

    -- 列出背包中所有鱼
    local hasFish = false
    for key, count in pairs(GameState.fishInventory) do
        if count > 0 then
            hasFish = true
            local parts = {}
            for part in key:gmatch("[^_]+") do
                table.insert(parts, part)
            end
            local fishId = tonumber(parts[1])
            local qualityId = tonumber(parts[2])
            local fishCfg = GameConfig.FISH_BY_ID[fishId]
            local qualityCfg = GameConfig.QUALITY[qualityId]
            if fishCfg and qualityCfg then
                local fid, qid = fishId, qualityId
                fishSelectPanel_:AddChild(UI.Panel {
                    width = "100%",
                    height = 40,
                    flexDirection = "row",
                    alignItems = "center",
                    justifyContent = "space-between",
                    paddingHorizontal = 8,
                    backgroundColor = { 30, 45, 65, 200 },
                    borderRadius = 6,
                    children = {
                        UI.Label {
                            text = string.format("%s %s [%s] x%d",
                                fishCfg.icon, fishCfg.displayName, qualityCfg.displayName, count),
                            fontSize = 12,
                            fontColor = { qualityCfg.color[1], qualityCfg.color[2], qualityCfg.color[3], 255 },
                        },
                        UI.Button {
                            text = "放入",
                            fontSize = 10,
                            height = 26,
                            width = 48,
                            backgroundColor = { 40, 110, 80, 255 },
                            onClick = function()
                                if selectedSlot_ then
                                    local ok, err = BreedingSystem:placeFish(selectedSlot_, fid, qid)
                                    if ok then
                                        fishSelectPanel_:SetVisible(false)
                                        selectedSlot_ = nil
                                        BreedingScreen.refreshSlots()
                                    else
                                        print("[BreedingScreen] " .. (err or "放入失败"))
                                    end
                                end
                            end,
                        },
                    }
                })
            end
        end
    end

    if not hasFish then
        fishSelectPanel_:AddChild(UI.Label {
            text = "背包中没有鱼，去钓鱼吧!",
            fontSize = 12,
            fontColor = { 150, 150, 170, 200 },
            marginTop = 8,
        })
    end
end

--- 每帧更新
function BreedingScreen.update(dt)
    for i = 1, GameState.unlockedBreedingSlots do
        local slot = GameState.breedingSlots[i]
        if slot then
            local progressWidget = screenRoot_:FindById("breedProgress_" .. i)
            if progressWidget then
                progressWidget:SetValue(BreedingSystem:getSlotProgress(i))
            end
            local timeWidget = screenRoot_:FindById("breedTime_" .. i)
            if timeWidget then
                timeWidget:SetText(FormatUtils.formatTime(BreedingSystem:getSlotRemainingTime(i)))
            end
        end
    end
end

return BreedingScreen
