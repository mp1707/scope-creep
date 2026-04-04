local Theme = {}

Theme.colors = {
    background = { 0.98, 0.97, 0.94, 1 },
    text       = { 0, 0, 0, 1 },
}

Theme.fonts = {}
Theme.fontScale = nil
Theme.card = {
    icon = {
        bodySize = 60,
    },
    feature = {
        valuePadding = 8,
        indicatorPadding = 8,
    },
}

local FONT_DEFS = {
    default = { path = "assets/fonts/PatrickHand-Regular.ttf", size = 32 },
    title = { path = "assets/fonts/PatrickHand-Regular.ttf", size = 96 },
    cardHeader = { path = "assets/fonts/PatrickHand-Regular.ttf", size = 20 },
    cardBody = { path = "assets/fonts/PatrickHand-Regular.ttf", size = 16 },
    uiButton = { path = "assets/fonts/PatrickHand-Regular.ttf", size = 22 },
}

local function quantizeScale(value)
    local scale = tonumber(value) or 1
    if scale <= 0 then
        scale = 1
    end
    return math.floor(scale * 100 + 0.5) / 100
end

function Theme.load(viewScale)
    local scale = quantizeScale(viewScale)
    if Theme.fontScale == scale and next(Theme.fonts) then
        love.graphics.setFont(Theme.fonts.default)
        return
    end

    Theme.fontScale = scale
    for key, definition in pairs(FONT_DEFS) do
        local fontSize = math.max(1, math.floor(definition.size * scale + 0.5))
        local font = love.graphics.newFont(definition.path, fontSize)
        font:setFilter("linear", "linear")
        Theme.fonts[key] = font
    end

    love.graphics.setFont(Theme.fonts.default)
end

return Theme
