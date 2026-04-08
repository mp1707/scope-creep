local Scaling = require("src.core.scaling")
local Theme = require("src.ui.theme")
local UiPanel = require("src.ui.ui_panel")
local PaydayOverlay = require("src.game.ui.payday_overlay")
local GameOverOverlay = require("src.game.ui.gameover_overlay")

local Constants = require("src.app.constants")
local State = require("src.app.state")
local Systems = require("src.app.systems")
local Utils = require("src.app.utils")

local Hud = {}

function Hud.draw(gameX, gameY)
    local viewportScale = Scaling.getScale()
    if viewportScale <= 0 then
        viewportScale = 1
    end

    local scale = 1 / viewportScale
    local headerFont = Theme.fonts.cardHeader or love.graphics.getFont()
    local bodyFont = Theme.fonts.cardBody or headerFont

    local phase = Systems.gameState:getPhase()
    local sprintNumber = Systems.sprint:getSprintNumber()
    local remaining = Systems.sprint:getRemainingTime()
    local speed = Systems.gameState:getSpeedFactor()

    UiPanel.drawPanel(20, 20, 280, 110, {
        bodyColor = { 0.97, 0.94, 0.86, 0.96 },
        borderColor = Theme.palette.ink,
    })

    love.graphics.setFont(headerFont)
    love.graphics.setColor(Theme.palette.ink)
    love.graphics.print(string.format("Sprint %d", sprintNumber), 36, 34, 0, scale, scale)

    love.graphics.setFont(bodyFont)
    love.graphics.print(string.format("Zeit: %s", Utils.formatTime(remaining)), 36, 66, 0, scale, scale)
    love.graphics.print(string.format("State: %s", phase), 36, 88, 0, scale, scale)

    UiPanel.drawPanel(Constants.APP_WIDTH - 260, 20, 240, 88, {
        bodyColor = { 0.97, 0.94, 0.86, 0.96 },
        borderColor = Theme.palette.ink,
    })

    love.graphics.print(string.format("Speed: %dx", speed), Constants.APP_WIDTH - 244, 40, 0, scale, scale)
    love.graphics.print("Space: Pause", Constants.APP_WIDTH - 244, 62, 0, scale, scale)
    love.graphics.print("Enter: Speed", Constants.APP_WIDTH - 244, 84, 0, scale, scale)

    if Systems.gameState:isPayday() then
        local paid, unpaid = 0, 0
        for _, card in ipairs(State.cards) do
            if card.kind == "employee" then
                if card.assignedToPayroll then
                    paid = paid + 1
                else
                    unpaid = unpaid + 1
                end
            end
        end

        PaydayOverlay.draw({
            viewportScale = viewportScale,
            sprintNumber = sprintNumber,
            paidEmployees = paid,
            unpaidEmployees = unpaid,
            nextButtonHovered = PaydayOverlay.isNextButtonHovered(gameX, gameY),
            nextButtonPressed = State.uiState.nextButtonPressed,
        })
    end

    if Systems.gameState:isGameOver() then
        GameOverOverlay.draw(Systems.gameState:getGameOverReason(), viewportScale)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return Hud
