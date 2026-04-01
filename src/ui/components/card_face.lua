local Surface = require("src.ui.components.surface")

local CardFace = {}

local function drawWrappedClamped(theme, text, x, y, width, align, font, color, maxLines)
    text = tostring(text or "")
    maxLines = maxLines or 1
    love.graphics.setFont(font)
    local _, wrapped = font:getWrap(text, width)
    if not wrapped or #wrapped == 0 then
        wrapped = { "" }
    end

    local lines = {}
    local count = math.min(maxLines, #wrapped)
    for i = 1, count do
        lines[#lines + 1] = wrapped[i]
    end
    local clippedText = table.concat(lines, "\n")
    theme:drawTextWrappedWithShadow(clippedText, x, y, width, align, font, color)
    return count * font:getHeight()
end

local function drawCardShell(theme, rect, accentColor, shadowOffset)
    local borderColor = {
        math.max(0, accentColor[1] * 0.72),
        math.max(0, accentColor[2] * 0.72),
        math.max(0, accentColor[3] * 0.72),
        1,
    }

    return Surface.draw(rect, {
        color = { 0.97, 0.94, 0.87, 1 },
        shadowOffset = shadowOffset or 3,
        radius = 14,
        borderColor = borderColor,
        borderWidth = 3,
    })
end

function CardFace.drawFeature(theme, feature, rect, options)
    options = options or {}
    local cardY = drawCardShell(theme, rect, feature.color, options.shadowOffset)

    local topH = math.floor(rect.h * 0.26)
    love.graphics.setColor(feature.color)
    love.graphics.rectangle("fill", rect.x + 5, cardY + 5, rect.w - 10, topH, 10, 10)
    love.graphics.setColor(1, 1, 1, 0.18)
    love.graphics.rectangle("fill", rect.x + 10, cardY + 9, rect.w - 20, math.max(10, topH * 0.34), 8, 8)

    local workText = ""
    if options.mode == "board" and feature.remainingWork and feature.totalWork then
        workText = tostring(feature.remainingWork) .. " / " .. tostring(feature.totalWork) .. " work"
    else
        local getPenalty = options.getTechDebtWorkPenalty
        local penalty = getPenalty and getPenalty() or 0
        workText = tostring((feature.baseWork or 0) + penalty) .. " work"
    end

    local formatMoney = options.formatMoney or function(v) return tostring(v) end
    local badgeText = formatMoney(feature.baseValue or feature.value or 0)
    if options.mode == "board" and feature.remainingWork and feature.remainingWork > 0 then
        badgeText = tostring(feature.remainingWork)
    end

    local labelFont = theme.fonts.tiny
    local titleFont = theme.fonts.small
    if rect.w < 154 or rect.h < 196 then
        titleFont = theme.fonts.tiny
    end

    local bodyPad = 10
    local contentW = rect.w - bodyPad * 2
    local topTextY = cardY + 12
    local titleY = cardY + topH + 10
    local badgeW = math.min(88, math.max(64, math.floor(rect.w * 0.42)))
    local badgeH = 34
    local badgeX = rect.x + rect.w - badgeW - 8
    local badgeY = cardY + rect.h - badgeH - 8

    drawWrappedClamped(theme, workText, rect.x + bodyPad, topTextY, contentW, "left", labelFont, theme.colors.text, 1)
    drawWrappedClamped(theme, feature.name or "", rect.x + bodyPad, titleY, contentW, "center", titleFont, theme.colors.text, 2)

    local tinyW = math.max(30, badgeX - (rect.x + bodyPad) - 8)
    drawWrappedClamped(theme, "tiny label", rect.x + bodyPad, badgeY + (badgeH - labelFont:getHeight()) * 0.5, tinyW, "left", labelFont, theme.colors.textDim, 1)

    love.graphics.setColor(0.15, 0.16, 0.25, 1)
    love.graphics.rectangle("fill", badgeX, badgeY, badgeW, badgeH, 10, 10)
    theme:drawTextCenteredWithShadow(badgeText, badgeX + 2, badgeY + (badgeH - labelFont:getHeight()) * 0.5, badgeW - 4, labelFont, { 0.97, 0.95, 0.91, 1 })

    love.graphics.setColor(1, 1, 1, 1)
    return cardY
end

function CardFace.drawSupport(theme, card, rect, options)
    options = options or {}
    local cardY = drawCardShell(theme, rect, card.color, options.shadowOffset)

    local topH = math.floor(rect.h * 0.24)
    love.graphics.setColor(card.color)
    love.graphics.rectangle("fill", rect.x + 5, cardY + 5, rect.w - 10, topH, 10, 10)
    love.graphics.setColor(1, 1, 1, 0.2)
    love.graphics.rectangle("fill", rect.x + 10, cardY + 9, rect.w - 20, math.max(10, topH * 0.34), 8, 8)

    local labelFont = theme.fonts.tiny
    local titleFont = theme.fonts.small
    if rect.w < 154 or rect.h < 196 then
        titleFont = theme.fonts.tiny
    end

    local bodyPad = 10
    local contentW = rect.w - bodyPad * 2

    if card.header then
        drawWrappedClamped(theme, card.header, rect.x + bodyPad, cardY + 12, contentW, "left", labelFont, theme.colors.text, 1)
    end

    drawWrappedClamped(theme, card.name or "", rect.x + bodyPad, cardY + topH + 10, contentW, "left", titleFont, theme.colors.text, 2)
    drawWrappedClamped(theme, card.description or "", rect.x + bodyPad, cardY + rect.h - 54, contentW, "center", labelFont, theme.colors.textDim, 2)

    love.graphics.setColor(1, 1, 1, 1)
    return cardY
end

return CardFace
