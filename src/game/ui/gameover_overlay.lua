local GameOverOverlay = {}

local Theme = require("src.ui.theme")
local UiPanel = require("src.ui.ui_panel")

local APP_WIDTH = 1920
local APP_HEIGHT = 1080

local REASON_TEXT = {
    data_leak = "Data leak. You got sued.",
    no_team_left = "No team left.",
    unknown = "Game Over.",
}

function GameOverOverlay.draw(reason, viewportScale)
    viewportScale = viewportScale or 1
    if viewportScale <= 0 then
        viewportScale = 1
    end

    love.graphics.setColor(0, 0, 0, 0.72)
    love.graphics.rectangle("fill", 0, 0, APP_WIDTH, APP_HEIGHT)

    local panelWidth = 620
    local panelHeight = 260
    local panelX = (APP_WIDTH - panelWidth) * 0.5
    local panelY = (APP_HEIGHT - panelHeight) * 0.5

    UiPanel.drawPanel(panelX, panelY, panelWidth, panelHeight, {
        bodyColor = { 1, 0.92, 0.92, 0.98 },
        borderColor = Theme.palette.ink,
    })

    local titleFont = Theme.fonts.default or love.graphics.getFont()
    local bodyFont = Theme.fonts.cardHeader or titleFont
    local scale = 1 / viewportScale

    love.graphics.setFont(titleFont)
    love.graphics.setColor(Theme.palette.ink)
    love.graphics.printf(
        "Game Over",
        panelX,
        panelY + 40,
        panelWidth * viewportScale,
        "center",
        0,
        scale,
        scale
    )

    love.graphics.setFont(bodyFont)
    local reasonText = REASON_TEXT[reason or ""] or REASON_TEXT.unknown
    love.graphics.printf(
        reasonText,
        panelX + 30,
        panelY + 130,
        (panelWidth - 60) * viewportScale,
        "center",
        0,
        scale,
        scale
    )

    love.graphics.setColor(1, 1, 1, 1)
end

return GameOverOverlay
