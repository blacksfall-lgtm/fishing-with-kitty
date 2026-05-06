-- ============================================================================
-- Defaults: 各组件类型的默认属性
-- ============================================================================

local Defaults = {}

--- 各类型的默认尺寸和样式
Defaults.TypeDefaults = {
    panel = {
        name   = "面板",
        width  = 200,
        height = 150,
        style  = {
            bg_color      = "#2A2A3AFF",
            border_color  = "#555566FF",
            border_width  = 1,
            corner_radius = 4,
            opacity       = 1.0,
            bg_image_mode = "fill",    -- "fill" | "9slice"
            slice_border  = 8,         -- 九宫格边距 (源图像素)
        },
    },
    button = {
        name   = "按钮",
        width  = 120,
        height = 40,
        style  = {
            bg_color      = "#4A90D9FF",
            border_color  = "#3A70B0FF",
            border_width  = 1,
            corner_radius = 6,
            text          = "按钮",
            font_size     = 14,
            font_color    = "#FFFFFFFF",
            text_align    = "center",
            opacity       = 1.0,
            bg_image_mode = "fill",
            slice_border  = 8,
        },
    },
    text = {
        name   = "文本",
        width  = 160,
        height = 30,
        style  = {
            bg_color      = "#00000000",
            border_color  = "#00000000",
            border_width  = 0,
            corner_radius = 0,
            text          = "文本内容",
            font_size     = 16,
            font_color    = "#EEEEEEFF",
            text_align    = "left",
            opacity       = 1.0,
        },
    },
    image = {
        name   = "图片",
        width  = 100,
        height = 100,
        style  = {
            bg_color      = "#3A3A4AFF",
            border_color  = "#555566FF",
            border_width  = 1,
            corner_radius = 0,
            bg_image      = "",
            opacity       = 1.0,
            bg_image_mode = "fill",
            slice_border  = 8,
        },
    },
    slider = {
        name   = "滑块",
        width  = 200,
        height = 30,
        style  = {
            bg_color      = "#3A3A4AFF",
            border_color  = "#555566FF",
            border_width  = 1,
            corner_radius = 4,
            opacity       = 1.0,
        },
    },
}

--- 获取某类型的默认属性
---@param nodeType string
---@return table defaults {name, width, height, style}
function Defaults.Get(nodeType)
    local def = Defaults.TypeDefaults[nodeType]
    if not def then
        -- fallback
        return {
            name   = nodeType,
            width  = 100,
            height = 60,
            style  = {
                bg_color      = "#333344FF",
                border_color  = "#555566FF",
                border_width  = 1,
                corner_radius = 0,
                opacity       = 1.0,
            },
        }
    end

    -- 深拷贝样式避免共享引用
    local styleCopy = {}
    for k, v in pairs(def.style) do
        styleCopy[k] = v
    end

    return {
        name   = def.name,
        width  = def.width,
        height = def.height,
        style  = styleCopy,
    }
end

--- 获取所有可用组件类型列表
---@return table list {{type, name, icon}, ...}
function Defaults.GetTypeList()
    return {
        { type = "panel",  name = "面板",  icon = "□" },
        { type = "button", name = "按钮",  icon = "▣" },
        { type = "text",   name = "文本",  icon = "T" },
        { type = "image",  name = "图片",  icon = "▨" },
        { type = "slider", name = "滑块",  icon = "─" },
    }
end

return Defaults
