-- ============================================================================
-- AquariumScreen: 鱼缸界面 - 放入鱼获得全局Buff加成
-- ============================================================================
local UI = require("urhox-libs/UI")
local GameConfig      = require("config.GameConfig")
local GameState       = require("state.GameState")
local AquariumSystem  = require("systems.AquariumSystem")
local FormatUtils     = require("utils.FormatUtils")

local AquariumScreen = {}

local screenRoot_
local slotsPanel_
local buffPanel_
local fishSelectPanel_
local selectedSlot_ = nil

--- 构建鱼缸界面
function AquariumScreen.build()
    -- Buff展示
    buffPanel_ = UI.Panel {
        id = "buffPanel",
        width = "100%",
        flexDirection = "row",
        flexWrap = "wrap",
        gap = 8,
    }

    -- 鱼缸槽位
    slotsPanel_ = UI.Panel {
        id = "aquariumSlots",
        width = "100%",
        gap = 6,
    }

    -- 鱼选择面板
    fishSelectPanel_ = UI.Panel {
        id = "aquaFishSelect",
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
        id = "aquariumScreen",
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
                                text = "🏠 观赏鱼缸",
                                fontSize = 18,
                                fontWeight = "bold",
                                fontColor = { 180, 200, 255, 255 },
                            },
                            UI.Label {
                                text = "放入鱼获得全局加成效果",
                                fontSize = 11,
                                fontColor = { 130, 150, 180, 255 },
                            },
                            -- Buff汇总
                            UI.Label {
                                text = "当前加成",
                                fontSize = 13,
                                fontWeight = "bold",
                                fontColor = { 180, 200, 230, 255 },
                            },
                            buffPanel_,
                            UI.Divider { color = { 50, 70, 100, 200 } },
                            -- 鱼缸槽位
                            UI.Label {
                                text = "鱼缸槽位",
                                fontSize = 13,
                                fontWeight = "bold",
                                fontColor = { 180, 200, 230, 255 },
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

    AquariumScreen.refreshBuffs()
    AquariumScreen.refreshSlots()
    return screenRoot_
end

--- 刷新Buff展示
function AquariumScreen.refreshBuffs()
    if not buffPanel_ then return end
    buffPanel_:ClearChildren()

    local buffs = AquariumSystem:getBuffSummary()
    for _, buff in ipairs(buffs) do
        local valueText = string.format("+%.0f%%", buff.value * 100)
        local hasValue = buff.value > 0
        buffPanel_:AddChild(UI.Panel {
            flexGrow = 1,
            flexBasis = 0,
            minWidth = 80,
            padding = 8,
            alignItems = "center",
            gap = 2,
            backgroundColor = hasValue
                and { 30, 55, 50, 220 } or { 30, 35, 50, 200 },
            borderRadius = 8,
            borderWidth = 1,
            borderColor = hasValue
                and { 60, 140, 100, 150 } or { 50, 55, 70, 100 },
            children = {
                UI.Label {
                    text = buff.icon,
                    fontSize = 18,
                },
                UI.Label {
                    text = buff.name,
                    fontSize = 10,
                    fontColor = { 160, 180, 210, 255 },
                },
                UI.Label {
                    text = valueText,
                    fontSize = 13,
                    fontWeight = "bold",
                    fontColor = hasValue
                        and { 100, 220, 150, 255 } or { 100, 110, 130, 200 },
                },
            }
        })
    end
end

--- 刷新鱼缸槽位
function AquariumScreen.refreshSlots()
    if not slotsPanel_ then return end
    slotsPanel_:ClearChildren()

    for i = 1, GameConfig.AQUARIUM.MAX_SLOTS do
        local unlocked = (i <= GameState.unlockedAquariumSlots)
        local slot = GameState.aquariumSlots[i]
        local slotIndex = i

        if not unlocked then
            local cost = GameConfig.AQUARIUM.SLOT_UNLOCK_COST[i] or 0
            slotsPanel_:AddChild(UI.Panel {
                width = "100%",
                height = 50,
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
                        text = "🔒 " .. FormatUtils.formatNumber(cost) .. "💰",
                        fontSize = 11,
                        fontColor = { 120, 120, 140, 255 },
                    },
                    UI.Button {
                        text = "解锁",
                        fontSize = 10,
                        height = 26,
                        width = 48,
                        backgroundColor = { 60, 100, 70, 255 },
                        onClick = function()
                            local ok, err = AquariumSystem:unlockSlot()
                            if ok then
                                AquariumScreen.refreshSlots()
                            else
                                print("[AquariumScreen] " .. (err or "解锁失败"))
                            end
                        end,
                    },
                }
            })
        elseif slot then
            local fishCfg = GameConfig.FISH_BY_ID[slot.fishId]
            local qualityCfg = GameConfig.QUALITY[slot.qualityId]
            local buffDef = GameConfig.AQUARIUM.BUFF_PER_TYPE[fishCfg.fishType]
            local qualityMulti = GameConfig.AQUARIUM.QUALITY_BUFF_MULTI[slot.qualityId] or 1
            local buffValue = buffDef and (buffDef.base * qualityMulti) or 0

            slotsPanel_:AddChild(UI.Panel {
                width = "100%",
                height = 50,
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "space-between",
                paddingHorizontal = 10,
                backgroundColor = { 25, 45, 55, 220 },
                borderRadius = 8,
                borderWidth = 1,
                borderColor = { qualityCfg.color[1], qualityCfg.color[2], qualityCfg.color[3], 120 },
                children = {
                    UI.Label {
                        text = string.format("%s %s [%s] +%.0f%%",
                            fishCfg.icon, fishCfg.displayName,
                            qualityCfg.displayName, buffValue * 100),
                        fontSize = 12,
                        fontColor = { qualityCfg.color[1], qualityCfg.color[2], qualityCfg.color[3], 255 },
                    },
                    UI.Button {
                        text = "取出",
                        fontSize = 10,
                        height = 26,
                        width = 48,
                        backgroundColor = { 120, 60, 60, 255 },
                        onClick = function()
                            AquariumSystem:removeFish(slotIndex)
                            AquariumScreen.refreshSlots()
                            AquariumScreen.refreshBuffs()
                        end,
                    },
                }
            })
        else
            slotsPanel_:AddChild(UI.Panel {
                width = "100%",
                height = 50,
                justifyContent = "center",
                alignItems = "center",
                backgroundColor = { 25, 35, 55, 200 },
                borderRadius = 8,
                borderWidth = 1,
                borderColor = { 50, 70, 100, 100 },
                children = {
                    UI.Button {
                        text = "➕ 放入鱼",
                        fontSize = 11,
                        height = 30,
                        backgroundColor = { 50, 80, 120, 255 },
                        onClick = function()
                            selectedSlot_ = slotIndex
                            AquariumScreen.showFishSelector()
                        end,
                    },
                }
            })
        end
    end
end

--- 显示鱼选择面板
function AquariumScreen.showFishSelector()
    if not fishSelectPanel_ then return end
    fishSelectPanel_:ClearChildren()
    fishSelectPanel_:SetVisible(true)

    fishSelectPanel_:AddChild(UI.Panel {
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        children = {
            UI.Label {
                text = "选择鱼放入鱼缸槽位 " .. selectedSlot_,
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
                local buffDef = GameConfig.AQUARIUM.BUFF_PER_TYPE[fishCfg.fishType]
                local qualityMulti = GameConfig.AQUARIUM.QUALITY_BUFF_MULTI[qualityId] or 1
                local buffValue = buffDef and (buffDef.base * qualityMulti) or 0
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
                            text = string.format("%s %s [%s] x%d  (+%.0f%%)",
                                fishCfg.icon, fishCfg.displayName,
                                qualityCfg.displayName, count, buffValue * 100),
                            fontSize = 11,
                            fontColor = { qualityCfg.color[1], qualityCfg.color[2], qualityCfg.color[3], 255 },
                        },
                        UI.Button {
                            text = "放入",
                            fontSize = 10,
                            height = 26,
                            width = 48,
                            backgroundColor = { 40, 100, 120, 255 },
                            onClick = function()
                                if selectedSlot_ then
                                    local ok, err = AquariumSystem:placeFish(selectedSlot_, fid, qid)
                                    if ok then
                                        fishSelectPanel_:SetVisible(false)
                                        selectedSlot_ = nil
                                        AquariumScreen.refreshSlots()
                                        AquariumScreen.refreshBuffs()
                                    else
                                        print("[AquariumScreen] " .. (err or "放入失败"))
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

--- 每帧更新（鱼缸界面无需频繁刷新）
function AquariumScreen.update(dt)
    -- 鱼缸是静态的，不需要每帧更新
end

return AquariumScreen
