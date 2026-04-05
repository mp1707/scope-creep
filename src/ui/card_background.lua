local Theme = require("src.ui.theme")
local UiPanel = require("src.ui.ui_panel")

local CardBackground = {}

function CardBackground.draw(x, y, width, height, alpha, options)
    options = options or {}

    local bodyColor = options.bodyColor or Theme.cardStyles.default.bodyColor
    local headerColor = options.headerColor
    local headerHeight = tonumber(options.headerHeight) or 0
    local borderColor = options.borderColor or Theme.colors.borderStrong

    UiPanel.drawSurface(x, y, width, height, bodyColor, { alpha = alpha })

    if headerColor and headerHeight > 0 then
        UiPanel.drawTopSurfaceOverlay(
            x,
            y,
            width,
            height,
            headerHeight,
            headerColor,
            {
                alpha = alpha,
                bleedBottom = tonumber(options.headerBleedBottom) or 4,
            }
        )
    end

    UiPanel.drawBorder(x, y, width, height, borderColor, { alpha = alpha })
end

return CardBackground
