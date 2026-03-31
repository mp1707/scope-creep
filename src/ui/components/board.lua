local Surface = require("src.ui.components.surface")

local Board = {}

local function drawDeveloperPlaceholder(theme, rect, name, work)
    local y = Surface.draw(rect, {
        color = theme.colors.surface2,
        shadowOffset = 3,
    })

    love.graphics.setColor(1, 1, 1, 0.9)

    local headX = rect.x + rect.w * 0.50
    local headY = y + rect.h * 0.38
    local headR = rect.w * 0.18

    love.graphics.circle("line", headX, headY, headR)
    love.graphics.arc("line", "open", headX, headY + rect.h * 0.15, rect.w * 0.28, math.pi * 1.05, math.pi * 1.95)

    theme:drawTextRightWithShadow(tostring(work) .. " work", rect.x, y + 10, rect.w - 8, theme.fonts.small, { 1, 1, 1, 1 })
    theme:drawTextCenteredWithShadow(name, rect.x, y + rect.h - 44, rect.w, theme.fonts.large, { 0.90, 0.20, 0.18, 1 })
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawSlot(theme, rect)
    Surface.draw(rect, {
        color = theme.colors.surface3,
        shadowOffset = 2,
    })
end

local function drawFeatureCardInBoard(theme, rect, feature, highlight, formatMoney)
    Surface.draw(rect, {
        color = feature.color,
        shadowOffset = 3,
    })

    theme:drawTextWrappedWithShadow(feature.name, rect.x + 8, rect.y + rect.h * 0.34, rect.w - 16, "center", theme.fonts.small, theme.colors.text)

    local bottomText = formatMoney(feature.value)
    if feature.remainingWork > 0 then
        bottomText = tostring(feature.remainingWork) .. " / " .. tostring(feature.totalWork) .. " Work"
    end
    theme:drawTextWrappedWithShadow(bottomText, rect.x + 8, rect.y + rect.h - 36, rect.w - 16, "center", theme.fonts.tiny, theme.colors.text)

    if highlight then
        love.graphics.setColor(theme.colors.highlight)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", rect.x - 2, rect.y - 2, rect.w + 4, rect.h + 4, 10, 10)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

local function drawShipButton(theme, rect)
    local y = Surface.draw(rect, {
        color = theme.colors.success,
        shadowOffset = 3,
    })
    theme:drawTextCenteredWithShadow("Ship!", rect.x, y + rect.h * 0.21, rect.w, theme.fonts.normal, theme.colors.text)
end

function Board.draw(theme, game, layout, formatMoney)
    local labels = { "in progress", "testing", "ready for rollout", "done!" }
    local firstRow = layout.rows[1]
    local cols = {
        firstRow.inProgressRect,
        firstRow.testingRect,
        firstRow.rolloutRect,
        firstRow.doneRect,
    }

    local headerFont = theme.fonts.small
    local labelY = firstRow.inProgressRect.y - headerFont:getHeight() - 6
    if labelY < 8 then
        labelY = 8
    end

    for i, rect in ipairs(cols) do
        theme:drawTextCenteredWithShadow(labels[i], rect.x, labelY, rect.w, headerFont, theme.colors.text)
    end

    for i, row in ipairs(game.rows) do
        local lrow = layout.rows[i]

        drawDeveloperPlaceholder(theme, lrow.devRect, row.developer.name, row.developer.baseWork)

        drawSlot(theme, lrow.inProgressRect)
        drawSlot(theme, lrow.testingRect)
        drawSlot(theme, lrow.rolloutRect)
        drawSlot(theme, lrow.doneRect)

        if row.inProgress then
            local margin = 5
            local rect = {
                x = lrow.inProgressRect.x + margin,
                y = lrow.inProgressRect.y + margin,
                w = lrow.inProgressRect.w - margin * 2,
                h = lrow.inProgressRect.h - margin * 2,
            }
            drawFeatureCardInBoard(theme, rect, row.inProgress, game.pendingSupport ~= nil, formatMoney)
            lrow.inProgressCardRect = rect
        else
            lrow.inProgressCardRect = nil
        end

        if row.testing then
            local margin = 5
            local rect = {
                x = lrow.testingRect.x + margin,
                y = lrow.testingRect.y + margin,
                w = lrow.testingRect.w - margin * 2,
                h = lrow.testingRect.h - margin * 2,
            }
            drawFeatureCardInBoard(theme, rect, row.testing, false, formatMoney)
            lrow.testingCardRect = rect
        else
            lrow.testingCardRect = nil
        end

        if row.rollout then
            local margin = 5
            local rect = {
                x = lrow.rolloutRect.x + margin,
                y = lrow.rolloutRect.y + margin,
                w = lrow.rolloutRect.w - margin * 2,
                h = lrow.rolloutRect.h - margin * 2,
            }
            drawFeatureCardInBoard(theme, rect, row.rollout, false, formatMoney)

            local shipRect = {
                x = rect.x + 12,
                y = rect.y + rect.h - 48,
                w = rect.w - 24,
                h = 38,
            }
            drawShipButton(theme, shipRect)

            lrow.rolloutCardRect = rect
            lrow.shipButtonRect = shipRect
        else
            lrow.rolloutCardRect = nil
            lrow.shipButtonRect = nil
        end

        if row.done then
            local margin = 5
            local rect = {
                x = lrow.doneRect.x + margin,
                y = lrow.doneRect.y + margin,
                w = lrow.doneRect.w - margin * 2,
                h = lrow.doneRect.h - margin * 2,
            }
            drawFeatureCardInBoard(theme, rect, row.done, false, formatMoney)
        end

        if row.doneFlash and row.doneFlash > 0 then
            love.graphics.setColor(0.20, 0.84, 0.67, row.doneFlash)
            love.graphics.rectangle("line", lrow.doneRect.x - 2, lrow.doneRect.y - 2, lrow.doneRect.w + 4, lrow.doneRect.h + 4, 8, 8)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
end

return Board
