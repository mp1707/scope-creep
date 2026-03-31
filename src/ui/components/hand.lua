local Surface = require("src.ui.components.surface")
local CardTransformRenderer = require("src.ui.card_transform_renderer")

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

    local w = hand.cardW
    local h = hand.cardH

    CardTransformRenderer.draw({
        x = card.x,
        y = card.y + breathingY,
        width = w,
        height = h,
        rotation = card.rotation + card.tiltY,
        scale = finalScale,
        shearX = card.tiltX,
        padding = 8,
        drawFn = function(x, y, drawW, drawH, _)
            local cardY = Surface.draw({ x = x, y = y, w = drawW, h = drawH }, {
                color = card.color,
                shadowOffset = 4,
            })

            if card.kind == "feature" then
                local workText = tostring(card.baseWork + getTechDebtWorkPenalty()) .. " Work"
                theme:drawTextWrappedWithShadow(workText, x + 10, cardY + 8, drawW - 20, "left", theme.fonts.tiny, theme.colors.text)
                theme:drawTextWrappedWithShadow(card.name, x + 10, cardY + drawH * 0.42, drawW - 20, "center", theme.fonts.small, theme.colors.text)
                theme:drawTextWrappedWithShadow(formatMoney(card.baseValue), x + 10, cardY + drawH - 42, drawW - 20, "center", theme.fonts.small, theme.colors.text)
            else
                drawSupportCardText(theme, card, x, cardY, drawW, drawH)
            end
        end,
    })

    if game.pendingSupport and game.pendingSupport.cardId == card.id then
        theme:drawTextCenteredWithShadow("Select a feature", card.x, card.y + breathingY - 20, w, theme.fonts.small, { 0.15, 0.58, 0.35, 1 })
    end
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
