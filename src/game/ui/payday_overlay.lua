local PaydayOverlay = {}

local Theme = require("src.ui.theme")
local UiPanel = require("src.ui.ui_panel")
local UiButton = require("src.ui.ui_button")

local APP_WIDTH = 1920
local APP_HEIGHT = 1080

local buttonRect = {
    x = (APP_WIDTH * 0.5) - 120,
    y = APP_HEIGHT - 140,
    width = 240,
    height = 56,
}

local function pointInRect(x, y, rect)
    if not x or not y then
        return false
    end
    return x >= rect.x and x <= (rect.x + rect.width)
        and y >= rect.y and y <= (rect.y + rect.height)
end

function PaydayOverlay.getNextButtonRect()
    return buttonRect
end

function PaydayOverlay.isNextButtonHovered(gameX, gameY)
    return pointInRect(gameX, gameY, buttonRect)
end

function PaydayOverlay.draw(model)
    local viewportScale = model.viewportScale or 1
    if viewportScale <= 0 then
        viewportScale = 1
    end

    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", 0, 0, APP_WIDTH, APP_HEIGHT)

    local panelWidth = 520
    local panelHeight = 190
    local panelX = (APP_WIDTH - panelWidth) * 0.5
    local panelY = 56

    UiPanel.drawPanel(panelX, panelY, panelWidth, panelHeight, {
        bodyColor = { 0.98, 0.94, 0.84, 0.98 },
        borderColor = Theme.palette.ink,
    })

    local headerFont = Theme.fonts.cardHeader or love.graphics.getFont()
    local bodyFont = Theme.fonts.cardBody or headerFont

    local scale = 1 / viewportScale

    love.graphics.setFont(headerFont)
    love.graphics.setColor(Theme.palette.ink)
    love.graphics.printf(
        "Payday",
        panelX,
        panelY + 18,
        panelWidth * viewportScale,
        "center",
        0,
        scale,
        scale
    )

    love.graphics.setFont(bodyFont)
    local lines = {
        string.format("Sprint %d beendet", model.sprintNumber or 1),
        string.format("Bezahlte Mitarbeitende: %d", model.paidEmployees or 0),
        string.format("Unbezahlte Mitarbeitende: %d", model.unpaidEmployees or 0),
        "Nur Stack mit exakt 1 Employee + 1 Money zählt.",
    }

    for i, line in ipairs(lines) do
        love.graphics.printf(
            line,
            panelX + 24,
            panelY + 58 + ((i - 1) * 26),
            (panelWidth - 48) * viewportScale,
            "left",
            0,
            scale,
            scale
        )
    end

    UiButton.draw(buttonRect, "Nächster Sprint", {
        isHovered = model.nextButtonHovered,
        isPressed = model.nextButtonPressed,
    })

    love.graphics.setColor(1, 1, 1, 1)
end

return PaydayOverlay
