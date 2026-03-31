local Sidebar = {}

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function drawMeterRow(theme, x, y, w, h, label, valueText, valuePercent, fillColor, bgColor)
    love.graphics.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, w, h, 14, 14)

    if valuePercent ~= nil then
        local fillW = math.floor(w * clamp(valuePercent, 0, 1))
        if fillW > 0 then
            love.graphics.setColor(fillColor)
            if fillW >= h then
                love.graphics.rectangle("fill", x, y, fillW, h, 14, 14)
            else
                love.graphics.rectangle("fill", x, y, fillW, h)
            end
        end
    end

    theme:drawTextWithShadow(label, x + 16, y + h * 0.18, theme.fonts.normal, theme.colors.text)
    theme:drawTextRightWithShadow(valueText, x, y + h * 0.18, w - 14, theme.fonts.normal, theme.colors.text)
end

function Sidebar.draw(theme, game, layout, formatMoney, getDaysRemaining)
    local sb = layout.sidebar.rect

    love.graphics.setColor(0.84, 0.85, 0.87, 1)
    love.graphics.rectangle("line", sb.x, sb.y, sb.w, sb.h)

    local pad = 14
    local chipH = 64
    local chipW = math.floor((sb.w - pad * 3) * 0.5)

    love.graphics.setColor(0.55, 0.88, 0.91, 1)
    love.graphics.rectangle("fill", sb.x + pad, sb.y + pad, chipW, chipH, 16, 16)
    theme:drawTextCenteredWithShadow("Release " .. tostring(game.release), sb.x + pad, sb.y + pad + 18, chipW, theme.fonts.normal, theme.colors.text)

    love.graphics.setColor(0.62, 0.82, 0.98, 1)
    love.graphics.rectangle("fill", sb.x + pad * 2 + chipW, sb.y + pad, chipW, chipH, 16, 16)
    theme:drawTextCenteredWithShadow("Sprint " .. tostring(game.sprint), sb.x + pad * 2 + chipW, sb.y + pad + 18, chipW, theme.fonts.normal, theme.colors.text)

    local goalY = sb.y + pad + chipH + 12
    local goalH = 208

    love.graphics.setColor(0.72, 0.66, 0.92, 1)
    love.graphics.rectangle("fill", sb.x + pad, goalY, sb.w - pad * 2, goalH, 30, 30)

    theme:drawTextCenteredWithShadow("Business Goal", sb.x + pad, goalY + 26, sb.w - pad * 2, theme.fonts.large, { 0.13, 0.11, 0.19, 1 })
    theme:drawTextCenteredWithShadow(formatMoney(game.businessGoal), sb.x + pad, goalY + 88, sb.w - pad * 2, theme.fonts.huge, { 0.13, 0.11, 0.19, 1 })
    theme:drawTextCenteredWithShadow("Revenue", sb.x + pad, goalY + 156, sb.w - pad * 2, theme.fonts.large, { 0.13, 0.11, 0.19, 1 })

    local rowY = goalY + goalH + 12
    local rowH = 64

    drawMeterRow(theme, sb.x + pad, rowY, sb.w - pad * 2, rowH, "Revenue", formatMoney(game.revenue), game.revenue / game.businessGoal, { 0.96, 0.80, 0.22, 1 }, { 0.95, 0.88, 0.64, 1 })
    rowY = rowY + rowH + 10

    if game.phase == "sprint" then
        drawMeterRow(theme, sb.x + pad, rowY, sb.w - pad * 2, rowH, "Burnout", tostring(game.burnout) .. "%", game.burnout / 100, { 0.96, 0.50, 0.50, 1 }, { 0.94, 0.77, 0.77, 1 })
        rowY = rowY + rowH + 10

        drawMeterRow(theme, sb.x + pad, rowY, sb.w - pad * 2, rowH, "Tech Debt", tostring(game.techDebt) .. "%", game.techDebt / 100, { 0.99, 0.54, 0.05, 1 }, { 0.95, 0.82, 0.64, 1 })
        rowY = rowY + rowH + 10
    end

    drawMeterRow(theme, sb.x + pad, rowY, sb.w - pad * 2, rowH, "Days", tostring(getDaysRemaining()), nil, { 0.61, 0.84, 0.67, 1 }, { 0.61, 0.84, 0.67, 1 })
    rowY = rowY + rowH + 12

    local mockButtonW = math.floor((sb.w - pad * 3) * 0.5)
    local mockButtonH = 58

    love.graphics.setColor(0.76, 0.79, 0.82, 1)
    love.graphics.rectangle("fill", sb.x + pad, rowY, mockButtonW, mockButtonH, 14, 14)
    love.graphics.rectangle("fill", sb.x + pad * 2 + mockButtonW, rowY, mockButtonW, mockButtonH, 14, 14)

    local labelY = rowY + (mockButtonH - theme.fonts.small:getHeight()) * 0.5
    theme:drawTextCenteredWithShadow("Settings", sb.x + pad, labelY, mockButtonW, theme.fonts.small, theme.colors.text)
    theme:drawTextCenteredWithShadow("Info", sb.x + pad * 2 + mockButtonW, labelY, mockButtonW, theme.fonts.small, theme.colors.text)

    local backlog = layout.sidebar.backlogRect
    local stackOffset = 6
    love.graphics.setColor(0.12, 0.12, 0.14, 1)
    for i = 3, 1, -1 do
        love.graphics.rectangle("line", backlog.x + i * stackOffset, backlog.y - i * stackOffset, backlog.w, backlog.h)
    end

    love.graphics.setColor(0.92, 0.92, 0.93, 1)
    love.graphics.rectangle("fill", backlog.x, backlog.y, backlog.w, backlog.h)
    love.graphics.setColor(0.12, 0.12, 0.14, 1)
    love.graphics.rectangle("line", backlog.x, backlog.y, backlog.w, backlog.h)

    theme:drawTextCenteredWithShadow(tostring(#game.deck), backlog.x, backlog.y + backlog.h * 0.35, backlog.w, theme.fonts.huge, theme.colors.text)
    theme:drawTextCenteredWithShadow("Backlog", backlog.x, backlog.y - 78, backlog.w, theme.fonts.normal, theme.colors.text)
end

return Sidebar
