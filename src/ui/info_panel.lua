local Theme = require("src.ui.theme")

local InfoPanel = {}

-- Sidebar sits to the right of the board (board right edge: 60 + 1455 = 1515)
local P = {
    x = 1540,
    y = 84,
    w = 330,
    gap = 20,
    goalH = 392,
    techH = 116,
    controlH = 348,
}

-- Hardcoded values for visual design pass
local M = {
    businessGoal = "4000$",
    current = "500$",
    techDebt = 0.42,
    day = 4,
    totalDays = 5,
}

local function drawCenteredText(font, text, x, y, w, color)
    love.graphics.setFont(font)
    love.graphics.setColor(color)
    local textX = math.floor(x + (w - font:getWidth(text)) * 0.5)
    love.graphics.print(text, textX, math.floor(y))
end

local function drawCard(x, y, w, h, rx)
    local c = Theme.colors

    love.graphics.setColor(c.sidebarCardShadow)
    love.graphics.rectangle("fill", x + 4, y + 4, w, h, rx)

    love.graphics.setColor(c.sidebarCard)
    love.graphics.rectangle("fill", x, y, w, h, rx)

    love.graphics.setColor(c.sidebarInk)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", x, y, w, h, rx)
    love.graphics.setLineWidth(1)
end

local function drawGoalCard(x, y, w, h)
    local c = Theme.colors
    local f = Theme.fonts

    drawCard(x, y, w, h, 16)

    local labelY = y + 24
    drawCenteredText(f.sidebarLabel, "Business Goal", x, labelY, w, c.sidebarInk)

    local goalY = labelY + f.sidebarLabel:getHeight() - 4
    drawCenteredText(f.sidebarBigNumber, M.businessGoal, x, goalY, w, c.sidebarInk)

    local dividerY = goalY + f.sidebarBigNumber:getHeight() + 14
    love.graphics.setColor(c.sidebarDivider)
    love.graphics.setLineWidth(3)
    love.graphics.line(x + 26, dividerY, x + w - 26, dividerY)
    love.graphics.setLineWidth(1)

    local currentLabelY = dividerY + 16
    drawCenteredText(f.sidebarSmallLabel, "Current", x, currentLabelY, w, c.sidebarInk)

    local currentValueY = currentLabelY + f.sidebarSmallLabel:getHeight() - 8
    drawCenteredText(f.sidebarBigNumber, M.current, x, currentValueY, w, c.sidebarInk)
end

local function drawTechDebtCard(x, y, w, h)
    local c = Theme.colors
    local f = Theme.fonts

    drawCard(x, y, w, h, 16)

    local pct = math.floor(M.techDebt * 100 + 0.5)
    local pctText = string.format("%d%%", pct)

    love.graphics.setFont(f.sidebarTech)
    love.graphics.setColor(c.sidebarInk)
    love.graphics.print("Tech Debt", x + 20, y + 14)
    love.graphics.print(pctText, math.floor(x + w - 20 - f.sidebarTech:getWidth(pctText)), y + 14)

    local barX, barY = x + 20, y + 66
    local barW, barH = w - 40, 28

    love.graphics.setColor(c.techDebtTrack)
    love.graphics.rectangle("fill", barX, barY, barW, barH, 12)
    love.graphics.setColor(c.sidebarInk)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", barX, barY, barW, barH, 12)
    love.graphics.setLineWidth(1)

    local fillW = math.max(0, math.floor((barW - 6) * M.techDebt))
    love.graphics.setColor(c.techDebtFill)
    love.graphics.rectangle("fill", barX + 3, barY + 3, fillW, barH - 6, 9)
end

local function drawDaySquares(x, y)
    local c = Theme.colors
    local size = 42
    local gap = 14

    for i = 1, M.totalDays do
        local color = c.dayPending
        if i < M.day then
            color = c.dayDone
        elseif i == M.day then
            color = c.dayCurrent
        end

        local sx = x + (i - 1) * (size + gap)
        love.graphics.setColor(color)
        love.graphics.rectangle("fill", sx, y, size, size, 8)
        love.graphics.setColor(c.sidebarInk)
        love.graphics.setLineWidth(4)
        love.graphics.rectangle("line", sx, y, size, size, 8)
        love.graphics.setLineWidth(1)
    end
end

local function drawActionButton(x, y, w, h, label, fillColor)
    local c = Theme.colors
    local font = Theme.fonts.sidebarButton

    love.graphics.setColor(fillColor)
    love.graphics.rectangle("fill", x, y, w, h, 14)

    love.graphics.setColor(c.sidebarInk)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", x, y, w, h, 14)
    love.graphics.setLineWidth(1)

    drawCenteredText(font, label, x, y + (h - font:getHeight()) * 0.5 - 1, w, c.sidebarInk)
end

local function drawControlCard(x, y, w, h)
    local c = Theme.colors
    local f = Theme.fonts

    drawCard(x, y, w, h, 16)

    local dayText = string.format("day %d/%d", M.day, M.totalDays)
    love.graphics.setFont(f.sidebarDay)
    love.graphics.setColor(c.sidebarInk)
    love.graphics.print(dayText, math.floor(x + w - 20 - f.sidebarDay:getWidth(dayText)), y + 18)

    drawDaySquares(x + 20, y + 78)

    local btnX = x + 20
    local btnW = w - 40
    local btnH = 72
    local firstBtnY = y + 150

    drawActionButton(btnX, firstBtnY, btnW, btnH, "End day", c.endDayFill)
    drawActionButton(btnX, firstBtnY + btnH + 22, btnW, btnH, "Discard", c.discardFill)
end

function InfoPanel.load()
end

function InfoPanel.update()
end

function InfoPanel.draw()
    local x = P.x
    local y = P.y
    local w = P.w

    drawGoalCard(x, y, w, P.goalH)

    local techY = y + P.goalH + P.gap
    drawTechDebtCard(x, techY, w, P.techH)

    local controlY = techY + P.techH + P.gap
    drawControlCard(x, controlY, w, P.controlH)
end

return InfoPanel
