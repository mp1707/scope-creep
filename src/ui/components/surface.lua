local Theme = require("src.ui.theme")

local Surface = {}

local function drawSketchPanel(x, y, w, h, radius, fillColor, borderColor, borderWidth)
    love.graphics.setColor(fillColor)
    love.graphics.rectangle("fill", x, y, w, h, radius, radius)

    love.graphics.setColor(1, 1, 1, 0.09)
    love.graphics.rectangle("fill", x + 3, y + 3, w - 6, math.max(10, h * 0.18), math.max(4, radius - 2), math.max(4, radius - 2))

    love.graphics.setColor(borderColor)
    love.graphics.setLineWidth(borderWidth)
    love.graphics.rectangle("line", x, y, w, h, radius, radius)

    love.graphics.setColor(Theme.colors.inkSoft)
    love.graphics.setLineWidth(math.max(1, borderWidth - 0.75))
    love.graphics.rectangle("line", x + 2, y + 1, w - 4, h - 3, math.max(4, radius - 2), math.max(4, radius - 2))

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function Surface.draw(rect, options)
    options = options or {}

    local color = options.color or Theme.colors.surface
    local shadowColor = options.shadowColor or Theme.colors.surfaceShadow
    local shadowOffset = options.shadowOffset
    if shadowOffset == nil then
        shadowOffset = 4
    end

    local radius = options.radius or 16
    local borderColor = options.borderColor or Theme.colors.ink
    local borderWidth = options.borderWidth or 2.5
    local pressed = options.pressed or false
    local drawShadow = options.shadow ~= false

    if drawShadow then
        love.graphics.setColor(shadowColor)
        love.graphics.rectangle("fill", rect.x + 1, rect.y + shadowOffset, rect.w, rect.h, radius, radius)
        love.graphics.setColor(1, 1, 1, 1)
    end

    local y = rect.y + (pressed and shadowOffset or 0)
    drawSketchPanel(rect.x, y, rect.w, rect.h, radius, color, borderColor, borderWidth)

    return y
end

return Surface
