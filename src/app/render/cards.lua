local Theme = require("src.ui.theme")
local UiPanel = require("src.ui.ui_panel")
local Constants = require("src.app.constants")
local State = require("src.app.state")
local Systems = require("src.app.systems")
local Utils = require("src.app.utils")
local Queries = require("src.app.cards.queries")
local PackBadge = require("src.app.render.pack_badge")

local Cards = {}

local clamp = Utils.clamp

function Cards.drawCardWithEffects(card, alphaMultiplier)
    local alpha = (card.renderAlpha or 1) * (alphaMultiplier or 1)

    if Systems.gameState:isPayday() and not Queries.isPayrollCard(card) then
        alpha = alpha * 0.28
    end

    if card.dimmed then
        alpha = alpha * 0.55
    end

    card:draw(Theme.fonts.cardHeader, {
        alpha = alpha,
        bodyFont = Theme.fonts.cardBody,
        valueFont = Theme.fonts.cardBody,
    })

    if card.objectType == "booster_pack" then
        PackBadge.draw(card)
    end
end

function Cards.drawDragFocusBackdrop(strength)
    local focusColors = Theme.colors.dragFocus or {}
    local backdropColor = focusColors.backdrop or { 0.08, 0.1, 0.12, 0.18 }
    Utils.setColorWithAlpha(backdropColor, strength or 1)
    love.graphics.rectangle("fill", 0, 0, Constants.WORLD_WIDTH, Constants.WORLD_HEIGHT)
    love.graphics.setColor(1, 1, 1, 1)
end

function Cards.drawDragTargetGlow(targetCards, glowStrength)
    if not targetCards or #targetCards == 0 then
        return
    end

    local strength = clamp(glowStrength or 1, 0, 1.25)
    local focusColors = Theme.colors.dragFocus or {}
    local pulse = 0.5 + (0.5 * math.sin((State.time or 0) * 3.2))
    local glowPrimary = focusColors.glowPrimary or Theme.palette.featureHeader
    local glowSecondary = focusColors.glowSecondary or Theme.palette.featureBody

    for _, card in ipairs(targetCards) do
        local outerPad = 40 + (pulse * 7)
        local midPad = 24 + (pulse * 5)
        local innerPad = 12 + (pulse * 3)

        UiPanel.drawSurface(
            card.x - outerPad, card.y - outerPad,
            card.width + (outerPad * 2), card.height + (outerPad * 2),
            glowPrimary, { alpha = (0.12 + (pulse * 0.05)) * strength }
        )
        UiPanel.drawSurface(
            card.x - midPad, card.y - midPad,
            card.width + (midPad * 2), card.height + (midPad * 2),
            glowSecondary, { alpha = (0.17 + (pulse * 0.08)) * strength }
        )
        UiPanel.drawSurface(
            card.x - innerPad, card.y - innerPad,
            card.width + (innerPad * 2), card.height + (innerPad * 2),
            glowPrimary, { alpha = (0.22 + (pulse * 0.1)) * strength }
        )
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return Cards
