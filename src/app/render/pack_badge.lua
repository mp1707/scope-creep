local Scaling = require("src.core.scaling")
local Theme = require("src.ui.theme")

local PackBadge = {}

function PackBadge.draw(packCard)
    if not packCard or not packCard.packRuntime then
        return
    end

    local remaining = packCard.packRuntime.usesRemaining or 0
    local radius = 19
    local badgeX = packCard.x + packCard.width - 8
    local badgeY = packCard.y + 12
    local alpha = packCard.renderAlpha or 1

    love.graphics.setColor(0.98, 0.95, 0.82, alpha)
    love.graphics.circle("fill", badgeX, badgeY, radius)
    love.graphics.setColor(0.1, 0.16, 0.23, alpha)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", badgeX, badgeY, radius)

    local viewportScale = Scaling.getScale()
    if viewportScale <= 0 then
        viewportScale = 1
    end

    local font = Theme.fonts.cardHeader or love.graphics.getFont()
    love.graphics.setFont(font)

    local label = tostring(remaining)
    local scale = 1 / viewportScale
    local textW = font:getWidth(label) * scale
    local textH = font:getHeight() * scale
    love.graphics.print(label, badgeX - (textW * 0.5), badgeY - (textH * 0.5), 0, scale, scale)

    love.graphics.setColor(1, 1, 1, 1)
end

return PackBadge
