local Hand = {}

local function drawSupportCardText(theme, card, x, y, w, h)
    if card.header then
        theme:drawTextWrappedWithShadow(card.header, x + 8, y + 8, w - 16, "left", theme.fonts.tiny, theme.colors.text)
    end

    theme:drawTextWrappedWithShadow(card.name, x + 10, y + h * 0.38, w - 20, "center", theme.fonts.small, theme.colors.text)

    local desc = card.description or ""
    local textY = y + h - 56
    theme:drawTextWrappedWithShadow(desc, x + 10, textY, w - 20, "center", theme.fonts.tiny, theme.colors.text)
end

local function drawCard(theme, game, layout, card, index, getTechDebtWorkPenalty, formatMoney)
    local hand = layout.hand

    local breathingScale = 1 + math.sin(game.time * 2.4 + index * 0.37) * 0.012
    local breathingY = math.sin(game.time * 2.4 + index * 0.62) * 1.8

    local finalScale = card.scale * breathingScale

    local cx = card.x + hand.cardW * 0.5
    local cy = card.y + hand.cardH * 0.5 + breathingY

    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(card.rotation + card.tiltY)
    love.graphics.scale(finalScale, finalScale)
    love.graphics.shear(card.tiltX, 0)

    local x = -hand.cardW * 0.5
    local y = -hand.cardH * 0.5
    local w = hand.cardW
    local h = hand.cardH

    local borderColor = { 0.20, 0.20, 0.22, 1 }

    if game.selectedCardId == card.id then
        borderColor = { 0.15, 0.45, 0.85, 1 }
    end

    if card.isPendingTarget then
        borderColor = { 0.17, 0.76, 0.44, 1 }
    end

    love.graphics.setColor(card.color)
    love.graphics.rectangle("fill", x, y, w, h, 10, 10)

    love.graphics.setColor(borderColor)
    love.graphics.setLineWidth(card.isPendingTarget and 4 or 2)
    love.graphics.rectangle("line", x, y, w, h, 10, 10)
    love.graphics.setLineWidth(1)

    if card.kind == "feature" then
        local workText = tostring(card.baseWork + getTechDebtWorkPenalty()) .. " Work"
        theme:drawTextWrappedWithShadow(workText, x + 10, y + 8, w - 20, "left", theme.fonts.tiny, theme.colors.text)
        theme:drawTextWrappedWithShadow(card.name, x + 10, y + h * 0.42, w - 20, "center", theme.fonts.small, theme.colors.text)
        theme:drawTextWrappedWithShadow(formatMoney(card.baseValue), x + 10, y + h - 42, w - 20, "center", theme.fonts.small, theme.colors.text)
    else
        drawSupportCardText(theme, card, x, y, w, h)
    end

    if game.pendingSupport and game.pendingSupport.cardId == card.id then
        theme:drawTextCenteredWithShadow("Select a feature", x, y - 20, w, theme.fonts.small, { 0.15, 0.58, 0.35, 1 })
    end

    love.graphics.pop()
end

function Hand.draw(theme, game, layout, getTechDebtWorkPenalty, formatMoney)
    for i, card in ipairs(game.hand) do
        if not (game.drag and game.drag.card and game.drag.card.id == card.id and game.drag.isDragging) then
            drawCard(theme, game, layout, card, i, getTechDebtWorkPenalty, formatMoney)
        end
    end

    if game.drag and game.drag.card and game.drag.isDragging then
        drawCard(theme, game, layout, game.drag.card, #game.hand + 1, getTechDebtWorkPenalty, formatMoney)
    end
end

return Hand
