-- ============================================================================
-- UIManager: 单页面布局（MVP: 仅顶部货币栏 + 内容区）
-- ============================================================================
local UI = require("urhox-libs/UI")
local GameState   = require("state.GameState")
local FormatUtils = require("utils.FormatUtils")

local UIManager = {}

local root_ = nil
local coinsLabel_ = nil

--- 初始化UI
function UIManager:init(screenBuilders)
    local fishingScreen = screenBuilders.fishing()

    root_ = UI.Panel {
        id = "gameRoot",
        width = "100%",
        height = "100%",
        flexDirection = "column",
        backgroundColor = { 15, 25, 45, 255 },
        children = {
            -- 顶部货币栏
            self:buildCurrencyBar(),
            -- 钓鱼界面（填满剩余空间）
            fishingScreen,
        }
    }

    UI.SetRoot(root_)
    print("[UIManager] UI初始化完成")
end

--- 构建货币栏
function UIManager:buildCurrencyBar()
    coinsLabel_ = UI.Label {
        id = "coinsLabel",
        text = FormatUtils.formatNumber(GameState.coins) .. " 金币",
        fontSize = 16,
        fontWeight = "bold",
        fontColor = { 255, 215, 0, 255 },
    }

    return UI.SafeAreaView {
        width = "100%",
        children = {
            UI.Panel {
                width = "100%",
                height = 44,
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "space-between",
                paddingHorizontal = 16,
                backgroundColor = { 10, 20, 40, 200 },
                children = {
                    UI.Label {
                        text = "钓鱼大亨",
                        fontSize = 15,
                        fontWeight = "bold",
                        fontColor = { 200, 220, 255, 255 },
                    },
                    coinsLabel_,
                }
            }
        }
    }
end

--- 刷新货币显示
function UIManager:refreshCoins()
    if coinsLabel_ then
        coinsLabel_:SetText(FormatUtils.formatNumber(GameState.coins) .. " 金币")
    end
end

return UIManager
