local Scaling = require("src.core.scaling")
local Theme = require("src.ui.theme")
local Systems = require("src.app.systems")
local Utils = require("src.app.utils")

local FiredLabels = {}

function FiredLabels.draw()
    local labels = Systems.payday:getFiredLabels()
    if not labels then
        return
    end

    local viewportScale = Scaling.getScale()
    if viewportScale <= 0 then
        viewportScale = 1
    end

    local font = Theme.fonts.cardHeader or love.graphics.getFont()
    love.graphics.setFont(font)

    for _, label in ipairs(labels) do
        local progress = Utils.clamp(label.elapsed / label.duration, 0, 1)
        local alpha = 1 - progress
        local drawX = label.x
        local drawY = label.y - (progress * 28)

        love.graphics.push()
        love.graphics.translate(drawX, drawY)
        love.graphics.rotate(-0.32)
        love.graphics.setColor(0.8, 0.08, 0.08, alpha)
        local scale = 1 / viewportScale
        local text = label.text or "gekündigt"
        local textW = font:getWidth(text) * scale
        local textH = font:getHeight() * scale
        love.graphics.print(text, -(textW * 0.5), -(textH * 0.5), 0, scale, scale)
        love.graphics.pop()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return FiredLabels
