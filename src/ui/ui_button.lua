local Scaling = require("src.core.scaling")
local Theme = require("src.ui.theme")
local UiPanel = require("src.ui.ui_panel")
local UiShadow = require("src.ui.ui_shadow")

local UiButton = {}

local function darkenColor(color, amount)
    local factor = 1 - math.max(0, math.min(1, amount or 0))
    local alpha = color[4] or 1
    return {
        color[1] * factor,
        color[2] * factor,
        color[3] * factor,
        alpha,
    }
end

function UiButton.draw(rect, label, options)
    options = options or {}
    local viewportScale = Scaling.getScale()
    if viewportScale <= 0 then
        viewportScale = 1
    end

    local bodyColor = options.bodyColor or Theme.colors.newDayButton.fill
    local borderColor = options.borderColor or Theme.colors.newDayButton.border
    local textColor = options.textColor or Theme.colors.newDayButton.text
    local isHovered = options.isHovered == true
    local isPressed = options.isPressed == true
    local isInset = isHovered or isPressed
    local hoverBodyColor = options.hoverBodyColor
        or Theme.colors.newDayButton.fillHover
        or darkenColor(bodyColor, 0.05)
    local pressedBodyColor = options.pressedBodyColor
        or Theme.colors.newDayButton.fillPressed
        or darkenColor(hoverBodyColor, 0.05)
    local drawBodyColor = bodyColor
    if isPressed then
        drawBodyColor = pressedBodyColor
    elseif isHovered then
        drawBodyColor = hoverBodyColor
    end

    local pressOffsetY = tonumber(options.pressOffsetY) or 2
    local drawX = rect.x
    local drawY = rect.y + (isInset and pressOffsetY or 0)

    local shadowRole = isInset and "buttonInset" or "buttonRaised"
    local shadowOptions = UiShadow.get(shadowRole, {
        alpha = tonumber(options.shadowAlpha),
    })
    if (shadowOptions.alpha or 0) > 0 then
        UiPanel.drawShadow(drawX, drawY, rect.width, rect.height, shadowOptions)
    end

    UiPanel.drawPanel(drawX, drawY, rect.width, rect.height, {
        bodyColor = drawBodyColor,
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
