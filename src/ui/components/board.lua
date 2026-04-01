local Surface = require("src.ui.components.surface")
local CardFace = require("src.ui.components.card_face")

local Board = {}

local function drawCenteredLabel(theme, text, x, y, width, font, color)
    theme:drawTextCenteredWithShadow(text, x, y, width, font, color)
end

local function drawBoardBackdrop(theme, game, layout, labelY)
    local firstRow = layout.rows[1]
    local lastRow = layout.rows[#layout.rows]
    if not firstRow or not lastRow then
        return
    end

    local devCol = firstRow.devRect
    local firstCol = firstRow.inProgressRect
    local lastCol = firstRow.doneRect
    local x = devCol.x - 14
    local y = labelY - 14
    local w = (lastCol.x + lastCol.w) - x + 14
    local h = (lastRow.doneRect.y + lastRow.doneRect.h) - y + 14

    local panelY = Surface.draw({ x = x, y = y, w = w, h = h }, {
        color = theme.colors.boardBackdrop,
        shadowOffset = 5,
        radius = 24,
        borderColor = theme.colors.boardDivider,
        borderWidth = 2,
    })

    love.graphics.setColor(theme.colors.boardDivider)
    local devSeparatorX = firstCol.x - 10
    love.graphics.line(devSeparatorX, panelY + 22, devSeparatorX, panelY + h - 22)

    for i = 1, #game.rows - 1 do
        local row = layout.rows[i]
        local nextRow = layout.rows[i + 1]
        local dividerY = math.floor((row.inProgressRect.y + row.inProgressRect.h + nextRow.inProgressRect.y) * 0.5)
        love.graphics.line(x + 16, dividerY, x + w - 16, dividerY)
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
    return panelY
end

local function drawDeveloperPlaceholder(theme, rect, name, work)
    local y = Surface.draw(rect, {
        color = theme.colors.surface,
        shadowOffset = 2,
        radius = 16,
        borderColor = { 0.21, 0.18, 0.16, 1 },
        borderWidth = 2.2,
    })

    local avatarRect = {
        x = rect.x + 8,
        y = y + 8,
        w = rect.w - 16,
        h = math.max(38, math.floor(rect.h * 0.44)),
    }
    love.graphics.setColor(0.95, 0.75, 0.48, 1)
    love.graphics.rectangle("fill", avatarRect.x, avatarRect.y, avatarRect.w, avatarRect.h, 10, 10)
    love.graphics.setColor(0.20, 0.16, 0.14, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", avatarRect.x, avatarRect.y, avatarRect.w, avatarRect.h, 10, 10)
    love.graphics.setLineWidth(1)

    local nameFont = theme.fonts.small
    if rect.w < 124 or rect.h < 138 then
        nameFont = theme.fonts.tiny
    end

    theme:drawTextCenteredWithShadow("dev", avatarRect.x, avatarRect.y + (avatarRect.h - theme.fonts.tiny:getHeight()) * 0.5, avatarRect.w, theme.fonts.tiny, theme.colors.text)
    theme:drawTextCenteredWithShadow(name, rect.x + 6, y + rect.h - 62, rect.w - 12, nameFont, theme.colors.text)
    theme:drawTextCenteredWithShadow(tostring(work) .. " work", rect.x + 6, y + rect.h - 34, rect.w - 12, theme.fonts.tiny, theme.colors.textDim)

    love.graphics.setColor(1, 1, 1, 1)
end

local function drawSlot(theme, rect)
    Surface.draw(rect, {
        color = theme.colors.boardLane,
        shadowOffset = 0,
        radius = 14,
        borderColor = { 0.58, 0.60, 0.77, 0.32 },
        borderWidth = 2,
    })
end

local function drawFeatureCardInBoard(theme, rect, feature, highlight, formatMoney)
    CardFace.drawFeature(theme, feature, rect, {
        mode = "board",
        shadowOffset = 3,
        formatMoney = formatMoney,
    })

    if highlight then
        love.graphics.setColor(theme.colors.highlight)
        love.graphics.setLineWidth(4)
        love.graphics.rectangle("line", rect.x - 2, rect.y - 2, rect.w + 4, rect.h + 4, 12, 12)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

local function drawShipButton(theme, rect)
    local y = Surface.draw(rect, {
        color = theme.colors.success,
        shadowOffset = 2,
        radius = 10,
    })
    theme:drawTextCenteredWithShadow("Ship", rect.x, y + (rect.h - theme.fonts.tiny:getHeight()) * 0.5, rect.w, theme.fonts.tiny, theme.colors.text)
end

local function drawColumnHeader(theme, rect, label, color, y)
    local shortLabel = label
    if rect.w < 118 then
        if label == "In Progress" then shortLabel = "Doing" end
        if label == "Testing" then shortLabel = "Test" end
        if label == "Rollout" then shortLabel = "Roll" end
        if label == "Shipped" then shortLabel = "Ship" end
    end

    local headerRect = {
        x = rect.x + 2,
        y = y,
        w = rect.w - 4,
        h = rect.w < 118 and 40 or 46,
    }

    local drawY = Surface.draw(headerRect, {
        color = color,
        shadowOffset = 2,
        radius = 24,
        borderColor = { 0.16, 0.12, 0.16, 0.85 },
        borderWidth = 2.2,
    })

    local headerFont = theme.fonts.small
    if headerRect.w < 148 then
        headerFont = theme.fonts.tiny
    end
    drawCenteredLabel(theme, shortLabel, headerRect.x, drawY + (headerRect.h - headerFont:getHeight()) * 0.5, headerRect.w, headerFont, { 0.13, 0.10, 0.10, 1 })
end

function Board.draw(theme, game, layout, formatMoney)
    local labels = { "In Progress", "Testing", "Rollout", "Shipped" }
    local labelColors = {
        theme.colors.laneInProgress,
        theme.colors.laneTesting,
        theme.colors.laneRollout,
        theme.colors.laneDone,
    }

    local firstRow = layout.rows[1]
    local cols = {
        firstRow.inProgressRect,
        firstRow.testingRect,
        firstRow.rolloutRect,
        firstRow.doneRect,
    }

    local labelY = firstRow.inProgressRect.y - 58
    if labelY < 10 then
        labelY = 10
    end

    drawBoardBackdrop(theme, game, layout, labelY)

    for i, rect in ipairs(cols) do
        drawColumnHeader(theme, rect, labels[i], labelColors[i], labelY)
    end

    for i, row in ipairs(game.rows) do
        local lrow = layout.rows[i]

        drawDeveloperPlaceholder(theme, lrow.devRect, row.developer.name, row.developer.baseWork)

        drawSlot(theme, lrow.inProgressRect)
        drawSlot(theme, lrow.testingRect)
        drawSlot(theme, lrow.rolloutRect)
        drawSlot(theme, lrow.doneRect)

        if row.inProgress then
            local rect = {
                x = lrow.inProgressRect.x,
                y = lrow.inProgressRect.y,
                w = lrow.inProgressRect.w,
                h = lrow.inProgressRect.h,
            }
            drawFeatureCardInBoard(theme, rect, row.inProgress, game.pendingSupport ~= nil, formatMoney)
            lrow.inProgressCardRect = rect
        else
            lrow.inProgressCardRect = nil
        end

        if row.testing then
            local rect = {
                x = lrow.testingRect.x,
                y = lrow.testingRect.y,
                w = lrow.testingRect.w,
                h = lrow.testingRect.h,
            }
            drawFeatureCardInBoard(theme, rect, row.testing, false, formatMoney)
            lrow.testingCardRect = rect
        else
            lrow.testingCardRect = nil
        end

        if row.rollout then
            local rect = {
                x = lrow.rolloutRect.x,
                y = lrow.rolloutRect.y,
                w = lrow.rolloutRect.w,
                h = lrow.rolloutRect.h,
            }
            drawFeatureCardInBoard(theme, rect, row.rollout, false, formatMoney)

            local shipRect = {
                x = rect.x + 10,
                y = rect.y + rect.h - 46,
                w = rect.w - 20,
                h = 34,
            }
            drawShipButton(theme, shipRect)

            lrow.rolloutCardRect = rect
            lrow.shipButtonRect = shipRect
        else
            lrow.rolloutCardRect = nil
            lrow.shipButtonRect = nil
        end

        if row.done then
            local rect = {
                x = lrow.doneRect.x,
                y = lrow.doneRect.y,
                w = lrow.doneRect.w,
                h = lrow.doneRect.h,
            }
            drawFeatureCardInBoard(theme, rect, row.done, false, formatMoney)
        end

        if row.doneFlash and row.doneFlash > 0 then
            love.graphics.setColor(0.20, 0.84, 0.67, row.doneFlash)
            love.graphics.setLineWidth(4)
            love.graphics.rectangle("line", lrow.doneRect.x - 2, lrow.doneRect.y - 2, lrow.doneRect.w + 4, lrow.doneRect.h + 4, 10, 10)
            love.graphics.setLineWidth(1)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
end

return Board
