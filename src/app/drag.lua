local Constants = require("src.app.constants")
local State = require("src.app.state")
local Utils = require("src.app.utils")
local Queries = require("src.app.cards.queries")
local Stacking = require("src.app.cards.stacking")

local Drag = {}

local clamp = Utils.clamp

function Drag.beginSelection(selection, pointerX, pointerY)
    State.dragState.draggingCards = selection
    State.dragState.dragRootCard = selection[1]

    local selectedByUid = {}
    for _, card in ipairs(selection) do
        selectedByUid[card.uid] = true
    end

    for _, card in ipairs(selection) do
        if card.stackParentId and not selectedByUid[card.stackParentId] then
            card.stackParentId = nil
        end
    end

    for _, card in ipairs(State.cards) do
        if card.stackParentId and selectedByUid[card.stackParentId] and not selectedByUid[card.uid] then
            card.stackParentId = nil
        end
    end

    for _, card in ipairs(selection) do
        card:beginDrag(pointerX, pointerY, true)
    end
end

function Drag.endSelection()
    local dragging = State.dragState.draggingCards
    if #dragging == 0 then
        return
    end

    local rootCard = State.dragState.dragRootCard or dragging[1]

    for _, card in ipairs(dragging) do
        card:endDrag()
    end

    local excluded = {}
    for _, card in ipairs(dragging) do
        excluded[card] = true
    end

    local beforeX = rootCard.targetX
    local beforeY = rootCard.targetY

    Stacking.applyStackSnap(rootCard, excluded)

    local deltaX = rootCard.targetX - beforeX
    local deltaY = rootCard.targetY - beforeY

    if deltaX ~= 0 or deltaY ~= 0 then
        for _, card in ipairs(dragging) do
            if card ~= rootCard then
                card.targetX = clamp(card.targetX + deltaX, 0, Constants.WORLD_WIDTH - (card.width or Constants.CARD_WIDTH))
                card.targetY = clamp(card.targetY + deltaY, 0, Constants.WORLD_HEIGHT - (card.height or Constants.CARD_HEIGHT))
            end
        end
    end

    State.dragState.draggingCards = {}
    State.dragState.dragRootCard = nil
end

function Drag.collectInteractableTargets()
    local dragging = State.dragState.draggingCards
    if #dragging == 0 then
        return nil
    end

    local rootCard = State.dragState.dragRootCard or dragging[1]
    if not rootCard or rootCard.objectType == "booster_pack" then
        return nil
    end

    local excluded = {}
    for _, card in ipairs(dragging) do
        excluded[card] = true
    end

    local targetSet = {}
    local targetList = {}

    for _, candidate in ipairs(State.cards) do
        if not excluded[candidate]
            and Queries.canAttachCard(rootCard, candidate, excluded)
            and Queries.hasRecipeInteraction(rootCard, candidate)
        then
            targetSet[candidate] = true
            table.insert(targetList, candidate)
        end
    end

    if #targetList == 0 then
        return nil
    end

    return { root = rootCard, targets = targetSet, list = targetList }
end

return Drag
