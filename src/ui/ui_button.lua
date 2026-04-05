local Scaling = require("src.core.scaling")
local Theme = require("src.ui.theme")
local UiPanel = require("src.ui.ui_panel")

local UiButton = {}

function UiButton.draw(rect, label, options)
    options = options or {}
    local viewportScale = Scaling.getScale()
    if viewportScale <= 0 then
        viewportScale = 1
    end

    local bodyColor = options.bodyColor or Theme.colors.newDayButton.fill
    local borderColor = options.borderColor or Theme.colors.newDayButton.border
    local textColor = options.textColor or Theme.colors.newDayButton.text
    local shadowAlpha = tonumber(options.shadowAlpha) or 0.16
    local isPressed = options.isPressed == true
    local pressOffsetY = tonumber(options.pressOffsetY) or 2
    local drawX = rect.x
    local drawY = rect.y + (isPressed and pressOffsetY or 0)

    if not isPressed and shadowAlpha > 0 then
        UiPanel.drawShadow(drawX, drawY, rect.width, rect.height, {
            alpha = shadowAlpha,
            offsetX = 2,
            offsetY = 2,
            expand = 0,
        })
    end
    UiPanel.drawPanel(drawX, drawY, rect.width, rect.height, {
        bodyColor = bodyColor,
        borderColor = borderColor,
        alpha = tonumber(options.alpha) or 1,
    })

    love.graphics.setFont(options.font or Theme.fonts.uiButton)
    love.graphics.setColor(textColor)
    love.graphics.printf(
        label or "",
        drawX,
        drawY + (rect.height - (love.graphics.getFont():getHeight() / viewportScale)) * 0.5,
        rect.width * viewportScale,
        "center",
        0,
        1 / viewportScale,
        1 / viewportScale
    )
end

return UiButton
