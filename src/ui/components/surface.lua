local Theme = require("src.ui.theme")
local NineSlice = require("src.ui.nine_slice")

local Surface = {}

function Surface.draw(rect, options)
    options = options or {}

    local color = options.color or Theme.colors.surface
    local shadowColor = options.shadowColor or Theme.colors.surfaceShadow
    local shadowOffset = options.shadowOffset
    if shadowOffset == nil then
        shadowOffset = 3
    end

    local scale = options.scale or Theme.nineSlice.borderScale
    local pressed = options.pressed or false
    local drawShadow = options.shadow ~= false

    local nineSlice = options.nineSlice or NineSlice.getInstance()

    if drawShadow then
        nineSlice:draw(rect.x, rect.y + shadowOffset, rect.w, rect.h, shadowColor, scale)
    end

    local y = rect.y + (pressed and shadowOffset or 0)
    nineSlice:draw(rect.x, y, rect.w, rect.h, color, scale)

    return y
end

return Surface
