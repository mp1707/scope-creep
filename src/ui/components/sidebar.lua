local Surface = require("src.ui.components.surface")

local Sidebar = {}

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function drawMeterRow(theme, x, y, w, h, label, valueText, valuePercent, fillColor, bgColor)
    local rowY = Surface.draw({ x = x, y = y, w = w, h = h }, {
        color = bgColor,
        shadowOffset = 3,
    })

    if valuePercent ~= nil then
        local fillW = math.floor(w * clamp(valuePercent, 0, 1))
        if fillW > 0 then
            local fillRect = {
                x = x,
                y = rowY,
                w = fillW,
                h = h,
            }
            Surface.draw(fillRect, {
                color = fillColor,
                shadow = false,
            })
        end
    end

    theme:drawTextWithShadow(label, x + 16, rowY + h * 0.18, theme.fonts.normal, theme.colors.text)
    theme:drawTextRightWithShadow(valueText, x, rowY + h * 0.18, w - 14, theme.fonts.normal, theme.colors.text)
end

function Sidebar.draw(theme, game, layout, formatMoney, getDaysRemaining)
    local sb = layout.sidebar.rect

    Surface.draw(sb, {
        color = theme.colors.surface2,
        shadowOffset = 4,
    })

    local pad = 14
    local chipH = 64
    local chipW = math.floor((sb.w - pad * 3) * 0.5)

    local chip1Y = Surface.draw({ x = sb.x + pad, y = sb.y + pad, w = chipW, h = chipH }, {
        color = theme.colors.chipA,
        shadowOffset = 3,
    })
    theme:drawTextCenteredWithShadow("Release " .. tostring(game.release), sb.x + pad, chip1Y + 18, chipW, theme.fonts.normal, theme.colors.text)

    local chip2X = sb.x + pad * 2 + chipW
    local chip2Y = Surface.draw({ x = chip2X, y = sb.y + pad, w = chipW, h = chipH }, {
        color = theme.colors.chipB,
        shadowOffset = 3,
    })
    theme:drawTextCenteredWithShadow("Sprint " .. tostring(game.sprint), chip2X, chip2Y + 18, chipW, theme.fonts.normal, theme.colors.text)

    local goalY = sb.y + pad + chipH + 12
    local goalH = 208

    local goalDrawY = Surface.draw({ x = sb.x + pad, y = goalY, w = sb.w - pad * 2, h = goalH }, {
        color = theme.colors.goalSurface,
        shadowOffset = 4,
    })

    local goalTextColor = { 0.13, 0.11, 0.19, 1 }
    theme:drawTextCenteredWithShadow("Business Goal", sb.x + pad, goalDrawY + 26, sb.w - pad * 2, theme.fonts.large, goalTextColor)
    theme:drawTextCenteredWithShadow(formatMoney(game.businessGoal), sb.x + pad, goalDrawY + 88, sb.w - pad * 2, theme.fonts.giant, goalTextColor)
    theme:drawTextCenteredWithShadow("Revenue", sb.x + pad, goalDrawY + 156, sb.w - pad * 2, theme.fonts.large, goalTextColor)

    local rowY = goalY + goalH + 12
    local rowH = 64

    drawMeterRow(theme, sb.x + pad, rowY, sb.w - pad * 2, rowH, "Revenue", formatMoney(game.revenue), game.revenue / game.businessGoal, theme.colors.meterRevenueFill, theme.colors.meterRevenueBg)
    rowY = rowY + rowH + 10

    if game.phase == "sprint" then
        drawMeterRow(theme, sb.x + pad, rowY, sb.w - pad * 2, rowH, "Burnout", tostring(game.burnout) .. "%", game.burnout / 100, theme.colors.meterBurnoutFill, theme.colors.meterBurnoutBg)
        rowY = rowY + rowH + 10

        drawMeterRow(theme, sb.x + pad, rowY, sb.w - pad * 2, rowH, "Tech Debt", tostring(game.techDebt) .. "%", game.techDebt / 100, theme.colors.meterDebtFill, theme.colors.meterDebtBg)
        rowY = rowY + rowH + 10
    end

    drawMeterRow(theme, sb.x + pad, rowY, sb.w - pad * 2, rowH, "Days", tostring(getDaysRemaining()), nil, theme.colors.meterDaysFill, theme.colors.meterDaysFill)
    rowY = rowY + rowH + 12

    local mockButtonW = math.floor((sb.w - pad * 3) * 0.5)
    local mockButtonH = 58

    local settingsY = Surface.draw({ x = sb.x + pad, y = rowY, w = mockButtonW, h = mockButtonH }, {
        color = theme.colors.surfaceMuted,
        shadowOffset = 3,
    })
    local infoX = sb.x + pad * 2 + mockButtonW
    local infoY = Surface.draw({ x = infoX, y = rowY, w = mockButtonW, h = mockButtonH }, {
        color = theme.colors.surfaceMuted,
        shadowOffset = 3,
    })

    local labelY = settingsY + (mockButtonH - theme.fonts.small:getHeight()) * 0.5
    theme:drawTextCenteredWithShadow("Settings", sb.x + pad, labelY, mockButtonW, theme.fonts.small, theme.colors.text)
    theme:drawTextCenteredWithShadow("Info", infoX, infoY + (mockButtonH - theme.fonts.small:getHeight()) * 0.5, mockButtonW, theme.fonts.small, theme.colors.text)

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
        })
    end

    local backlogY = Surface.draw(backlog, {
        color = theme.colors.surface,
        shadowOffset = 3,
    })

    theme:drawTextCenteredWithShadow(tostring(#game.deck), backlog.x, backlogY + backlog.h * 0.35, backlog.w, theme.fonts.giant, theme.colors.text)
    theme:drawTextCenteredWithShadow("Backlog", backlog.x, backlog.y - 78, backlog.w, theme.fonts.normal, theme.colors.text)
end

return Sidebar
