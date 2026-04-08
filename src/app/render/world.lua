local Theme = require("src.ui.theme")

local Camera = require("src.app.camera")
local State = require("src.app.state")
local Systems = require("src.app.systems")
local Background = require("src.app.background")
local Queries = require("src.app.cards.queries")
local Drag = require("src.app.drag")
local CardsRender = require("src.app.render.cards")
local WorkBars = require("src.app.render.work_bars")
local FiredLabels = require("src.app.render.fired_labels")

local World = {}

local function drawCardLayer(dragFocus)
    local nonTargetAlpha = (Theme.colors.dragFocus or {}).nonTargetCardAlpha or 0.3

    if dragFocus then
        for _, card in ipairs(State.cards) do
            if not Queries.isCardDragging(card) and not dragFocus.targets[card] then
                CardsRender.drawCardWithEffects(card, nonTargetAlpha)
            end
        end
        CardsRender.drawDragTargetGlow(dragFocus.list, 1)
        for _, card in ipairs(State.cards) do
            if not Queries.isCardDragging(card) and dragFocus.targets[card] then
                CardsRender.drawCardWithEffects(card)
            end
        end
    else
        for _, card in ipairs(State.cards) do
            if not Queries.isCardDragging(card) then
                CardsRender.drawCardWithEffects(card)
            end
        end
    end

    WorkBars.draw(Systems.work:getActiveJobs())

    for _, card in ipairs(State.cards) do
        if Queries.isCardDragging(card) then
            CardsRender.drawCardWithEffects(card)
        end
    end
end

function World.draw()
    local dragFocus = Drag.collectInteractableTargets()

    love.graphics.push()
    love.graphics.scale(Camera.zoom, Camera.zoom)
    love.graphics.translate(-Camera.x, -Camera.y)

    Background.draw()
    drawCardLayer(dragFocus)
    FiredLabels.draw()

    love.graphics.pop()
end

return World
