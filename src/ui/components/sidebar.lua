local Surface = require("src.ui.components.surface")

local Sidebar = {}

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function drawCenteredLabel(theme, text, x, y, width, font, color)
    theme:drawTextCenteredWithShadow(text, x, y, width, font, color)
end

local function pickBestGoalValueFont(theme, text, maxWidth, maxHeight)
    local candidates = {
        theme.fonts.huge,
        theme.fonts.display,
        theme.fonts.large,
        theme.fonts.normal,
        theme.fonts.small,
    }

    for _, font in ipairs(candidates) do
        if font:getWidth(text) <= maxWidth and font:getHeight() <= maxHeight then
            return font
        end
    end
    return theme.fonts.tiny
end

local function drawMeterRow(theme, x, y, w, h, label, valueText, valuePercent, fillColor, bgColor)
    local rowY = Surface.draw({ x = x, y = y, w = w, h = h }, {
        color = theme.colors.surface,
        shadowOffset = 2,
        radius = 14,
        borderColor = { 0.18, 0.16, 0.15, 1 },
        borderWidth = 2,
    })

    local rowFont = theme.fonts.small
    if h <= 62 then
        rowFont = theme.fonts.tiny
    end

    local textY = rowY + math.max(6, math.floor((h - rowFont:getHeight() - 10) * 0.45))
    theme:drawTextWithShadow(label, x + 12, textY, rowFont, theme.colors.text)
    theme:drawTextRightWithShadow(valueText, x, textY, w - 12, rowFont, theme.colors.text)

    if valuePercent ~= nil then
        local barX = x + 14
        local barY = rowY + h - 14
        local barW = w - 28
        local barH = 8

        love.graphics.setColor(bgColor)
        love.graphics.rectangle("fill", barX, barY, barW, barH, 4, 4)

        local fillW = math.floor(barW * clamp(valuePercent, 0, 1))
        if fillW > 0 then
            love.graphics.setColor(fillColor)
            love.graphics.rectangle("fill", barX, barY, fillW, barH, 4, 4)
        end

        love.graphics.setColor(1, 1, 1, 1)
    end
end

function Sidebar.draw(theme, game, layout, formatMoney, getDaysRemaining)
    local sb = layout.sidebar.rect

    Surface.draw(sb, {
        color = theme.colors.boardBackdrop,
        shadowOffset = 6,
        radius = 24,
        borderColor = theme.colors.boardDivider,
        borderWidth = 2,
    })

    local pad = 14
    local chipH = 66
    local chipW = math.floor((sb.w - pad * 3) * 0.5)

    local chip1Y = Surface.draw({ x = sb.x + pad, y = sb.y + pad, w = chipW, h = chipH }, {
        color = theme.colors.chipA,
        shadowOffset = 2,
        radius = 14,
    })
    drawCenteredLabel(theme, "Release " .. tostring(game.release), sb.x + pad, chip1Y + 16, chipW, theme.fonts.small, theme.colors.text)

    local chip2X = sb.x + pad * 2 + chipW
    local chip2Y = Surface.draw({ x = chip2X, y = sb.y + pad, w = chipW, h = chipH }, {
        color = theme.colors.chipB,
        shadowOffset = 2,
        radius = 14,
    })
    drawCenteredLabel(theme, "Sprint " .. tostring(game.sprint), chip2X, chip2Y + 16, chipW, theme.fonts.small, theme.colors.text)

    local goalY = sb.y + pad + chipH + 12
    local rowCount = game.phase == "sprint" and 4 or 2
    local rowH = 68
    local rowGap = 10
    local buttonH = 58
    local staticH = chipH + 12 + (rowCount * rowH + (rowCount - 1) * rowGap) + 12 + buttonH
    local availableForGoal = sb.h - pad * 2 - staticH
    local goalH = math.max(128, math.min(220, availableForGoal))

    if goalH <= 170 then
        rowH = 62
        staticH = chipH + 12 + (rowCount * rowH + (rowCount - 1) * rowGap) + 12 + buttonH
        availableForGoal = sb.h - pad * 2 - staticH
        goalH = math.max(120, math.min(200, availableForGoal))
    end

    if goalH <= 130 then
        rowH = 56
        staticH = chipH + 12 + (rowCount * rowH + (rowCount - 1) * rowGap) + 12 + buttonH
        availableForGoal = sb.h - pad * 2 - staticH
        goalH = math.max(108, math.min(180, availableForGoal))
    end

    local goalDrawY = Surface.draw({ x = sb.x + pad, y = goalY, w = sb.w - pad * 2, h = goalH }, {
        color = theme.colors.goalSurface,
        shadowOffset = 3,
        radius = 18,
    })

    local goalTextColor = { 0.15, 0.12, 0.10, 1 }
    local goalTitleFont = goalH <= 178 and theme.fonts.normal or theme.fonts.large
    local goalSubFont = goalH <= 178 and theme.fonts.small or theme.fonts.normal

    local goalW = sb.w - pad * 2
    local moneyText = formatMoney(game.businessGoal)
    local innerPadTop = math.max(10, math.floor(goalH * 0.08))
    local innerPadBottom = math.max(10, math.floor(goalH * 0.08))
    local sectionGap = math.max(8, math.floor(goalH * 0.06))

    local titleY = goalDrawY + innerPadTop
    local subY = goalDrawY + goalH - innerPadBottom - goalSubFont:getHeight()
    local valueTop = titleY + goalTitleFont:getHeight() + sectionGap
    local valueBottom = subY - sectionGap
    local valueH = math.max(18, valueBottom - valueTop)

    local goalValueFont = pickBestGoalValueFont(theme, moneyText, goalW - 24, valueH)
    local valueY = valueTop + math.floor((valueH - goalValueFont:getHeight()) * 0.5)

    drawCenteredLabel(theme, "Sprint Goal", sb.x + pad, titleY, goalW, goalTitleFont, goalTextColor)
    theme:drawTextCenteredWithShadow(moneyText, sb.x + pad, valueY, goalW, goalValueFont, goalTextColor)
    drawCenteredLabel(theme, "Revenue target", sb.x + pad, subY, goalW, goalSubFont, goalTextColor)

    local rowY = goalY + goalH + 12

    drawMeterRow(theme, sb.x + pad, rowY, sb.w - pad * 2, rowH, "Revenue", formatMoney(game.revenue), game.revenue / game.businessGoal, theme.colors.meterRevenueFill, theme.colors.meterRevenueBg)
    rowY = rowY + rowH + 10

    if game.phase == "sprint" then
        drawMeterRow(theme, sb.x + pad, rowY, sb.w - pad * 2, rowH, "Burnout", tostring(game.burnout) .. "%", game.burnout / 100, theme.colors.meterBurnoutFill, theme.colors.meterBurnoutBg)
        rowY = rowY + rowH + 10

        drawMeterRow(theme, sb.x + pad, rowY, sb.w - pad * 2, rowH, "Tech Debt", tostring(game.techDebt) .. "%", game.techDebt / 100, theme.colors.meterDebtFill, theme.colors.meterDebtBg)
        rowY = rowY + rowH + 10
    end

    drawMeterRow(theme, sb.x + pad, rowY, sb.w - pad * 2, rowH, "Days Left", tostring(getDaysRemaining()), nil, theme.colors.meterDaysFill, theme.colors.meterRevenueBg)
    rowY = rowY + rowH + 12

    local mockButtonW = math.floor((sb.w - pad * 3) * 0.5)
    local mockButtonH = 58

    local settingsY = Surface.draw({ x = sb.x + pad, y = rowY, w = mockButtonW, h = mockButtonH }, {
        color = theme.colors.surface,
        shadowOffset = 2,
        radius = 12,
    })
    local infoX = sb.x + pad * 2 + mockButtonW
    local infoY = Surface.draw({ x = infoX, y = rowY, w = mockButtonW, h = mockButtonH }, {
        color = theme.colors.surface,
        shadowOffset = 2,
        radius = 12,
    })

    drawCenteredLabel(theme, "Settings", sb.x + pad, settingsY + (mockButtonH - theme.fonts.small:getHeight()) * 0.5, mockButtonW, theme.fonts.small, theme.colors.text)
    drawCenteredLabel(theme, "Info", infoX, infoY + (mockButtonH - theme.fonts.small:getHeight()) * 0.5, mockButtonW, theme.fonts.small, theme.colors.text)

    local backlog = layout.sidebar.backlogRect
    local stackOffset = 6
    for i = 3, 1, -1 do
        Surface.draw({
            x = backlog.x + i * stackOffset,
            y = backlog.y - i * stackOffset,
            w = backlog.w,
            h = backlog.h,
        }, {
            color = theme.colors.surfaceMuted,
            shadow = false,
            radius = 10,
        })
    end

    local backlogY = Surface.draw(backlog, {
        color = theme.colors.surface,
        shadowOffset = 3,
        radius = 10,
    })

    theme:drawTextCenteredWithShadow(tostring(#game.deck), backlog.x, backlogY + backlog.h * 0.48, backlog.w, theme.fonts.display, theme.colors.text)
    theme:drawTextCenteredWithShadow("Backlog", backlog.x, backlog.y - 76, backlog.w, theme.fonts.normal, theme.colors.text)
end

return Sidebar
