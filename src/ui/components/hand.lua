local CardTransformRenderer = require("src.ui.card_transform_renderer")
local CardFace = require("src.ui.components.card_face")

local Hand = {}

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
            local rect = { x = x, y = y, w = drawW, h = drawH }
            if card.kind == "feature" then
                CardFace.drawFeature(theme, card, rect, {
                    mode = "hand",
                    shadowOffset = 4,
                    getTechDebtWorkPenalty = getTechDebtWorkPenalty,
                    formatMoney = formatMoney,
                })
            else
                CardFace.drawSupport(theme, card, rect, {
                    shadowOffset = 4,
                })
            end

            if game.selectedCardId == card.id then
                love.graphics.setColor(theme.colors.cardSelected)
                love.graphics.setLineWidth(4)
                love.graphics.rectangle("line", x - 2, y - 2, drawW + 4, drawH + 4, 14, 14)
                love.graphics.setLineWidth(1)
                love.graphics.setColor(1, 1, 1, 1)
            end
        end,
    })

    if game.pendingSupport and game.pendingSupport.cardId == card.id then
        theme:drawTextCenteredWithShadow("Select a feature", card.x, card.y + breathingY - 30, w, theme.fonts.tiny, theme.colors.cardTarget)
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
