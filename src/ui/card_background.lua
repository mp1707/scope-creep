local Theme = require("src.ui.theme")
local NineSlice = require("src.ui.nine_slice")

local CardBackground = {}

local DEFAULT_CONFIG = {
    path = "assets/handdrawn/borders/cardBorder9slice.png",
    sourceX = 24,
    sourceY = 24,
    sourceWidth = 205,
    sourceHeight = 211,
    sourceLeft = 16,
    sourceRight = 16,
    sourceTop = 16,
    sourceBottom = 16,
    drawLeft = 6,
    drawRight = 6,
    drawTop = 6,
    drawBottom = 6,
}

function CardBackground.getConfig()
    local cardTheme = Theme.card or {}
    local configured = cardTheme.background9slice or {}

    return {
        path = configured.path or DEFAULT_CONFIG.path,
        sourceX = tonumber(configured.sourceX) or DEFAULT_CONFIG.sourceX,
        sourceY = tonumber(configured.sourceY) or DEFAULT_CONFIG.sourceY,
        sourceWidth = tonumber(configured.sourceWidth) or DEFAULT_CONFIG.sourceWidth,
        sourceHeight = tonumber(configured.sourceHeight) or DEFAULT_CONFIG.sourceHeight,
        sourceLeft = tonumber(configured.sourceLeft) or DEFAULT_CONFIG.sourceLeft,
        sourceRight = tonumber(configured.sourceRight) or DEFAULT_CONFIG.sourceRight,
        sourceTop = tonumber(configured.sourceTop) or DEFAULT_CONFIG.sourceTop,
        sourceBottom = tonumber(configured.sourceBottom) or DEFAULT_CONFIG.sourceBottom,
        drawLeft = tonumber(configured.drawLeft) or DEFAULT_CONFIG.drawLeft,
        drawRight = tonumber(configured.drawRight) or DEFAULT_CONFIG.drawRight,
        drawTop = tonumber(configured.drawTop) or DEFAULT_CONFIG.drawTop,
        drawBottom = tonumber(configured.drawBottom) or DEFAULT_CONFIG.drawBottom,
    }
end

function CardBackground.draw(x, y, width, height, alpha)
    local config = CardBackground.getConfig()
    return NineSlice.draw(
        config.path,
        x,
        y,
        width,
        height,
        {
            sourceX = config.sourceX,
            sourceY = config.sourceY,
            sourceWidth = config.sourceWidth,
            sourceHeight = config.sourceHeight,
            left = config.sourceLeft,
            right = config.sourceRight,
            top = config.sourceTop,
            bottom = config.sourceBottom,
            destLeft = config.drawLeft,
            destRight = config.drawRight,
            destTop = config.drawTop,
            destBottom = config.drawBottom,
            alpha = alpha,
        }
    )
end

return CardBackground
